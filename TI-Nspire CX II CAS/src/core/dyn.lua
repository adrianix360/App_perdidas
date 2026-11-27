--[[
dyn.lua - Dinamica de fluidos (ampliacion de examenes IC-605): perfiles de
velocidad, continuidad y Bernoulli, cantidad de movimiento y tanques no
permanentes. Motor puro (sin UI), todo en SI. Convenciones del port: ver
core/hydro.lua (el error se devuelve primero; las salidas van en la tabla `r`
que se pasa vacia; las entradas complejas van en la tabla `p`).

Codigos de error: DYN_OK 0, DYN_ERR_ARG 1 (dato invalido), DYN_ERR_EXPR 2
(expresion mal escrita), DYN_ERR_NONFINITE 3 (la expresion dio NaN o infinito),
DYN_ERR_NOFLOW 4 (energia insuficiente: no hay flujo), DYN_ERR_STEPS 5 (la
integracion no termina). dyn_err_text(err) -> texto.

API PUBLICA
  dyn_compile(str, vars) -> err, fn, msg
        Compila una expresion de usuario. vars = {"y"} o {"t","y"}...; fn(...)
        recibe los valores en ese orden. Operadores + - * / ^ y parentesis,
        multiplicacion implicita (2y, 8pi, 2(y+1)), constante pi y las
        funciones sin cos tan asin acos atan sqrt exp ln log abs. (ui/expr.lua
        no tiene variables ni funciones; por eso este evaluador propio, que
        usa las mismas reglas de numeros, signo y potencia.)
  dyn_simpson(f, a, b, n) -> integral    n par (si es impar se suma 1)
  dyn_power_channel(umax, nexp, h) -> u(y)           u = umax (y/h)^n
  dyn_power_pipe(umax, m, k, r0) -> u(r)             u = umax (1 - (r/r0)^m)^k

  D1 dyn_profile_channel(p, r) -> err
        p: b h u(fn de y) nu Lc [n=400] [power={umax,n}: formulas cerradas]    r: Q A V alfa beta umax Vumax Re Lc
           mdot_rho1 (Q), n, prof{y,u}
     dyn_profile_pipe(p, r) -> err
        p: r0 u(fn de r) nu Lc [n=400] [power={umax,m,k}: cerradas]
        r: igual (A = pi r0^2); r.exact = true si uso formulas cerradas
  D2 dyn_continuity(p, r) -> err
        p: Q  o  vol y time;  rho;  D = {D1..D4}    r: Q mdot V{} A{}
     dyn_discharge(p, r) -> err      descarga libre de un tanque
        p: g rho z0 zs d (boquilla) D (conducto) pts = { {z=, D=}, ... }
        r: Vs Q mdot hv pts = { {z, D, V, p, hp, hv}, ... } warn{}
     dyn_bernoulli(p, r) -> err      tramo 1 -> 2
        p: g rho p1 D1 z1 V1|Q D2 z2 hL rhom
        r: Q V1 V2 A1 A2 p1 p2 dp h1 h2 hmano (si rhom) hpiez
  D3 dyn_elbow(p, r) -> err          codo o reduccion en un plano
        p: g rho D1 D2 theta(grad) V1|Q p1 dz (= z2 - z1) hL p2 (opc.)
        r: Q V1 V2 A1 A2 p1 p2 F1 F2 M1 M2 Rx Ry R ang Ax Ay
        Convencion: (Rx, Ry) = fuerza que el FLUIDO ejerce sobre el codo
        (x = direccion de la entrada, y a 90 grados antihorario); los
        anclajes deben hacer la contraria: (Ax, Ay) = (-Rx, -Ry). Se desprecia
        el peso del fluido y del codo.
     dyn_jets(p, r) -> err           chorros que sostienen un peso
        p: g rho N d alpha(grad respecto a la vertical) D mass H eta
        r: V2 V1 Q Qjet W A1 A2 p1 p0 HB Pot Pshaft
  D4 dyn_tank(p, r) -> err           tanque de area constante, RK4 adaptativo
        p: A y0 zs qe(fn de t | numero) y una de
             qs(fn de t,y)   o   Cd + a (+ g) = Torricelli Cd a sqrt(2g(y-zs))
           at (area del tubo, opc.) ; objetivo: tf (nivel en t = tf) o
           ytarget (tiempo hasta ese nivel) [tmax = 1e6 s]
        r: status ("level" "target" "equilibrium" "tmax") reached t_end y_end
           Qe0 Qs0 v0 dydt0 dvdt0 Qe_end Qs_end v_end y_eq steps
           samples = {n, t[], y[], qe[], qs[]}
]]

local D = {}

local sqrt, sin, cos, abs, pi = math.sqrt, math.sin, math.cos, math.abs, math.pi
local huge = math.huge

D.DYN_OK, D.DYN_ERR_ARG, D.DYN_ERR_EXPR, D.DYN_ERR_NONFINITE = 0, 1, 2, 3
D.DYN_ERR_NOFLOW, D.DYN_ERR_STEPS = 4, 5
local OK, E_ARG, E_EXPR, E_NONF, E_NOFLOW, E_STEPS = 0, 1, 2, 3, 4, 5

local err_text = { [0] = "OK", "Dato invalido", "Expresion mal escrita",
  "La expresion no es un numero finito", "Energia insuficiente: no hay flujo",
  "La integracion no termina" }
function D.dyn_err_text(e) return err_text[e] or "Error" end

local function finite(x) return type(x) == "number" and x == x and x - x == 0 end

-- =============================================================== expresiones
local funcs = {
  sin = sin, cos = cos, tan = math.tan, asin = math.asin, acos = math.acos,
  atan = math.atan, sqrt = sqrt, exp = math.exp, ln = math.log, log = math.log10,
  abs = abs,
}

local function tokenize(s)
  s = s:gsub("\226\136\146", "-"):gsub("\225\180\135", "E"):gsub("\207\128", "pi")
  s = s:gsub("\195\151", "*"):gsub("\195\183", "/")
  local tk, i, n = {}, 1, #s
  while i <= n do
    local c = s:sub(i, i)
    if c == " " then
      i = i + 1
    elseif c:match("[%d%.]") then
      local a, b = s:find("^%d*%.?%d*", i)
      local j = b
      local e1, e2 = s:find("^[eE][%+%-]?%d+", j + 1)
      if e1 then j = e2 end
      local txt = s:sub(i, j)
      local v = tonumber((txt:gsub("^%.", "0.")))
      if txt == "." or v == nil then return nil end
      tk[#tk + 1] = { k = "n", v = v }
      i = j + 1
    elseif c:match("%a") then
      local a, b = s:find("^%a+", i)
      tk[#tk + 1] = { k = "id", v = s:sub(a, b):lower() }
      i = b + 1
    elseif c:match("[%+%-%*/%^%(%)]") then
      tk[#tk + 1] = { k = c }
      i = i + 1
    else
      return nil
    end
  end
  return tk
end

-- -> err, fn, msg
function D.dyn_compile(str, vars)
  str = tostring(str or "")
  local tk = tokenize(str)
  if not tk then return E_EXPR, nil, "Caracter no valido" end
  if #tk == 0 then return E_EXPR, nil, "Expresion vacia" end
  vars = vars or {}
  local idx = {}
  for i, nm in ipairs(vars) do idx[nm] = i end
  local vals = {}
  local pos = 1
  local bad
  local parse_expr, parse_unary

  local function peek() return tk[pos] and tk[pos].k end
  local function node_const(v) return function() return v end end

  local function parse_primary()
    local t = tk[pos]
    if not t then bad = bad or "Expresion incompleta"; return node_const(0) end
    if t.k == "n" then
      pos = pos + 1
      return node_const(t.v)
    elseif t.k == "(" then
      pos = pos + 1
      local e = parse_expr()
      if peek() ~= ")" then bad = bad or "Falta )"; return e end
      pos = pos + 1
      return e
    elseif t.k == "id" then
      pos = pos + 1
      local nm = t.v
      if funcs[nm] then
        if peek() ~= "(" then bad = bad or ("Falta ( tras " .. nm); return node_const(0) end
        pos = pos + 1
        local e = parse_expr()
        if peek() ~= ")" then bad = bad or "Falta )"; return e end
        pos = pos + 1
        local f = funcs[nm]
        return function() return f(e()) end
      elseif nm == "pi" then
        return node_const(pi)
      elseif idx[nm] then
        local i = idx[nm]
        return function() return vals[i] end
      end
      bad = bad or ("Variable desconocida: " .. nm)
      return node_const(0)
    end
    bad = bad or "Sintaxis"
    return node_const(0)
  end

  local function parse_power()
    local b = parse_primary()
    if peek() == "^" then
      pos = pos + 1
      local x = parse_unary()
      return function()
        local bv, xv = b(), x()
        if bv < 0 and xv ~= math.floor(xv) then return 0 / 0 end
        return bv ^ xv
      end
    end
    return b
  end

  parse_unary = function()
    local c = peek()
    if c == "-" or c == "+" then
      pos = pos + 1
      local e = parse_unary()
      if c == "-" then return function() return -e() end end
      return e
    end
    return parse_power()
  end

  local function parse_term()
    local a = parse_unary()
    while not bad do
      local c = peek()
      if c == "*" or c == "/" then
        pos = pos + 1
        local b = parse_unary()
        local x = a
        if c == "*" then a = function() return x() * b() end
        else a = function() return x() / b() end end
      elseif c == "n" or c == "id" or c == "(" then   -- multiplicacion implicita
        local b = parse_unary()
        local x = a
        a = function() return x() * b() end
      else
        break
      end
    end
    return a
  end

  parse_expr = function()
    local a = parse_term()
    while not bad do
      local c = peek()
      if c ~= "+" and c ~= "-" then break end
      pos = pos + 1
      local b = parse_term()
      local x = a
      if c == "+" then a = function() return x() + b() end
      else a = function() return x() - b() end end
    end
    return a
  end

  local root = parse_expr()
  if not bad and pos <= #tk then bad = "Sobra texto al final" end
  if bad then return E_EXPR, nil, bad end
  local nv = #vars
  local fn
  if nv == 0 then fn = function() return root() end
  elseif nv == 1 then fn = function(a) vals[1] = a; return root() end
  elseif nv == 2 then fn = function(a, b) vals[1] = a; vals[2] = b; return root() end
  else fn = function(a, b, c) vals[1] = a; vals[2] = b; vals[3] = c; return root() end end
  -- prueba rapida de sintaxis/forma con valores de ejemplo
  return OK, fn, nil
end

-- ================================================================ integracion
function D.dyn_simpson(f, a, b, n)
  n = n or 200
  if n % 2 == 1 then n = n + 1 end
  local h = (b - a) / n
  local s = f(a) + f(b)
  for i = 1, n - 1 do s = s + ((i % 2 == 1) and 4 or 2) * f(a + i * h) end
  return s * h / 3
end

function D.dyn_power_channel(umax, nexp, h)
  return function(y) return umax * (y / h) ^ nexp end
end

function D.dyn_power_pipe(umax, m, k, r0)
  return function(r)
    local x = 1 - (r / r0) ^ m
    if x < 0 then x = 0 end
    return umax * x ^ k
  end
end

-- ================================================================ D1 perfiles
-- Muestras de u en n+1 puntos y pesos de Simpson. wfun(x) = peso geometrico
-- (b para canal, 2 pi r para tuberia). Devuelve err, integrales I1 I2 I3, umax
local function profile_core(uf, x1, wfun, n, r)
  if n % 2 == 1 then n = n + 1 end
  local h = x1 / n
  local I1, I2, I3, umax = 0, 0, 0, -huge
  for i = 0, n do
    local x = i * h
    local u = uf(x)
    if not finite(u) then return E_NONF end
    local w = (i == 0 or i == n) and 1 or ((i % 2 == 1) and 4 or 2)
    w = w * wfun(x)
    I1 = I1 + w * u
    I2 = I2 + w * u * u
    I3 = I3 + w * u * u * u
    if u > umax then umax = u end
  end
  r.n = n
  return OK, I1 * h / 3, I2 * h / 3, I3 * h / 3, umax
end

local function profile_finish(p, A, I1, I2, I3, umax, r)
  r.Q = I1
  r.I2, r.I3 = I2, I3
  r.A = A
  if not (I1 > 0) then return E_NOFLOW end
  r.V = I1 / A
  r.alfa = I3 / (A * r.V ^ 3)
  r.beta = I2 / (A * r.V ^ 2)
  r.umax = umax
  r.Vumax = r.V / umax
  r.Lc = p.Lc
  if p.nu and p.nu > 0 and p.Lc and p.Lc > 0 then r.Re = r.V * p.Lc / p.nu else r.Re = nil end
  return OK
end

-- log-gamma (Lanczos) y funcion beta, para las formulas cerradas de la tuberia
local function lgamma(x)
  local c = { 0.99999999999980993, 676.5203681218851, -1259.1392167224028,
    771.32342877765313, -176.61502916214059, 12.507343278686905,
    -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7 }
  x = x - 1
  local a = c[1]
  local t = x + 7.5
  for i = 1, 8 do a = a + c[i + 1] / (x + i) end
  return 0.5 * math.log(2 * pi) + (x + 0.5) * math.log(t) - t + math.log(a)
end
local function beta(a, b) return math.exp(lgamma(a) + lgamma(b) - lgamma(a + b)) end

function D.dyn_profile_channel(p, r)
  if not (p.b > 0) or not (p.h > 0) or type(p.u) ~= "function" then return E_ARG end
  local b, h = p.b, p.h
  local e, I1, I2, I3, umax
  if p.power then
    -- u = umax (y/h)^n : integrales cerradas  Ij = umax^j b h / (n j + 1)
    local um, n = p.power.umax, p.power.n
    if not (um > 0) or not (n > 0) then return E_ARG end
    I1 = um * b * h / (n + 1)
    I2 = um * um * b * h / (2 * n + 1)
    I3 = um ^ 3 * b * h / (3 * n + 1)
    umax = um
    r.exact, r.n = true, nil
    r.power = { umax = um, n = n }
  else
    e, I1, I2, I3, umax = profile_core(p.u, h, function() return b end, p.n or 400, r)
    if e ~= OK then return e end
  end
  e = profile_finish(p, b * h, I1, I2, I3, umax, r)
  if e ~= OK then return e end
  r.prof = { y = {}, u = {} }
  for i = 0, 5 do
    r.prof.y[i + 1] = h * i / 5
    r.prof.u[i + 1] = p.u(h * i / 5)
  end
  return OK
end

function D.dyn_profile_pipe(p, r)
  if not (p.r0 > 0) or type(p.u) ~= "function" then return E_ARG end
  local r0 = p.r0
  local e, I1, I2, I3, umax
  if p.power then
    -- u = umax (1-(r/r0)^m)^k : Ij = 2 pi r0^2 umax^j B(2/m, j k + 1) / m
    local um, m, k = p.power.umax, p.power.m, p.power.k
    if not (um > 0) or not (m > 0) or not (k >= 0) then return E_ARG end
    local c = 2 * pi * r0 * r0 / m
    I1 = c * um * beta(2 / m, k + 1)
    I2 = c * um ^ 2 * beta(2 / m, 2 * k + 1)
    I3 = c * um ^ 3 * beta(2 / m, 3 * k + 1)
    umax = um
    r.exact, r.n = true, nil
    r.power = { umax = um, m = m, k = k }
  else
    e, I1, I2, I3, umax = profile_core(p.u, r0, function(x) return 2 * pi * x end, p.n or 400, r)
    if e ~= OK then return e end
  end
  e = profile_finish(p, pi * r0 * r0, I1, I2, I3, umax, r)
  if e ~= OK then return e end
  r.prof = { y = {}, u = {} }
  for i = 0, 5 do
    r.prof.y[i + 1] = r0 * i / 5
    r.prof.u[i + 1] = p.u(r0 * i / 5)
  end
  return OK
end

-- ======================================================= D2 continuidad/Bernoulli
local function area(Dm) return pi * Dm * Dm / 4 end
D.dyn_area = area

function D.dyn_continuity(p, r)
  local Q = p.Q
  if not (Q and Q > 0) then
    if p.vol and p.time and p.vol > 0 and p.time > 0 then Q = p.vol / p.time else return E_ARG end
  end
  if not (p.rho > 0) then return E_ARG end
  r.Q = Q
  r.mdot = p.rho * Q
  r.A, r.V = {}, {}
  local n = 0
  for i = 1, 4 do
    local d = p.D and p.D[i]
    if d then
      if not (d > 0) then return E_ARG end
      r.A[i] = area(d)
      r.V[i] = Q / r.A[i]
      n = n + 1
    end
  end
  r.nD = n
  return OK
end

function D.dyn_discharge(p, r)
  local g, rho = p.g, p.rho
  if not (g > 0) or not (rho > 0) or not (p.d > 0) or not (p.D > 0) then return E_ARG end
  local H = p.z0 - p.zs
  if not (H > 0) then return E_NOFLOW end
  r.H = H
  r.Vs = sqrt(2 * g * H)
  r.As = area(p.d)
  r.Q = r.Vs * r.As
  r.mdot = rho * r.Q
  r.pts = {}
  r.warn = {}
  for i, q in ipairs(p.pts or {}) do
    local Dm = q.D or p.D
    if not (Dm > 0) then return E_ARG end
    local V = r.Q / area(Dm)
    local hv = V * V / (2 * g)
    local pp = rho * g * (p.z0 - q.z - hv)
    r.pts[i] = { z = q.z, D = Dm, V = V, hv = hv, p = pp, hp = pp / (rho * g) }
    if pp < -101325 then
      r.warn[#r.warn + 1] = "Punto " .. i .. ": p absoluta negativa (cavitacion)"
    end
  end
  return OK
end

function D.dyn_bernoulli(p, r)
  local g, rho = p.g, p.rho
  if not (g > 0) or not (rho > 0) or not (p.D1 > 0) or not (p.D2 > 0) then return E_ARG end
  local A1, A2 = area(p.D1), area(p.D2)
  local Q = p.Q
  if not (Q and Q > 0) then
    if p.V1 and p.V1 > 0 then Q = p.V1 * A1 else return E_ARG end
  end
  local hL = p.hL or 0
  if hL < 0 then return E_ARG end
  local p1 = p.p1 or 0
  r.Q, r.A1, r.A2 = Q, A1, A2
  r.V1, r.V2 = Q / A1, Q / A2
  r.p1 = p1
  r.p2 = p1 + rho * (r.V1 ^ 2 - r.V2 ^ 2) / 2 + rho * g * (p.z1 - p.z2) - rho * g * hL
  r.dp = p1 - r.p2
  r.h1 = p1 / (rho * g) + r.V1 ^ 2 / (2 * g) + p.z1
  r.h2 = r.p2 / (rho * g) + r.V2 ^ 2 / (2 * g) + p.z2
  -- diferencia piezometrica (p + rho g z) entre 1 y 2
  r.dpiez = (p1 + rho * g * p.z1) - (r.p2 + rho * g * p.z2)
  if p.rhom then
    if not (p.rhom > rho) then return E_ARG end
    r.hmano = r.dpiez / ((p.rhom - rho) * g)
  end
  return OK
end

-- ================================================================= D3 momentum
function D.dyn_elbow(p, r)
  local g, rho = p.g, p.rho
  if not (g > 0) or not (rho > 0) or not (p.D1 > 0) or not (p.D2 > 0) then return E_ARG end
  local th = (p.theta or 0) * pi / 180
  local A1, A2 = area(p.D1), area(p.D2)
  local Q = p.Q
  if not (Q and Q > 0) then
    if p.V1 and p.V1 > 0 then Q = p.V1 * A1 else return E_ARG end
  end
  r.Q, r.A1, r.A2 = Q, A1, A2
  r.V1, r.V2 = Q / A1, Q / A2
  r.p1 = p.p1 or 0
  if p.p2 ~= nil then
    r.p2 = p.p2
    r.p2_given = true
  else
    r.p2 = r.p1 + rho * (r.V1 ^ 2 - r.V2 ^ 2) / 2 - rho * g * ((p.dz or 0) + (p.hL or 0))
    r.p2_given = false
  end
  local ct, st = cos(th), sin(th)
  r.th = th
  r.F1 = r.p1 * A1                   -- fuerza de presion en la entrada
  r.F2 = r.p2 * A2                   -- fuerza de presion en la salida
  r.mdot = rho * Q
  r.M1x = r.mdot * r.V1              -- flujo de cantidad de movimiento
  r.M2x = r.mdot * r.V2 * ct
  r.M2y = r.mdot * r.V2 * st
  -- fuerza del fluido sobre el codo
  r.Rx = r.F1 - r.F2 * ct - (r.M2x - r.M1x)
  r.Ry = -r.F2 * st - r.M2y
  r.R = sqrt(r.Rx * r.Rx + r.Ry * r.Ry)
  r.ang = math.atan2 and math.atan2(r.Ry, r.Rx) * 180 / pi or math.atan(r.Ry / r.Rx) * 180 / pi
  r.Ax, r.Ay = -r.Rx, -r.Ry
  return OK
end

function D.dyn_jets(p, r)
  local g, rho = p.g, p.rho
  local N = p.N
  if not (g > 0) or not (rho > 0) or not (N >= 1) or not (p.d > 0) or not (p.D > 0) or
      not (p.mass > 0) or not (p.H >= 0) then return E_ARG end
  local al = (p.alpha or 0) * pi / 180
  local A1, A2 = area(p.D), area(p.d)
  local W = p.mass * g
  local k = N * A2 / A1                         -- V1 = k V2 (continuidad)
  r.k = k
  r.ca = cos(al)
  -- p1 A1 + rho A1 V1^2 + N rho A2 V2^2 cos(alpha) = W,  p1 = rho (V2^2 - V1^2)/2
  local coef = rho * (A1 * (1 - k * k) / 2 + A1 * k * k + N * A2 * r.ca)
  if not (coef > 0) then return E_ARG end
  r.coef = coef
  r.V2 = sqrt(W / coef)
  r.V1 = k * r.V2
  r.Qjet = A2 * r.V2
  r.Q = N * r.Qjet
  r.W, r.A1, r.A2 = W, A1, A2
  r.p1 = rho * (r.V2 ^ 2 - r.V1 ^ 2) / 2
  r.p0 = r.p1 + rho * g * p.H
  r.HB = r.p0 / (rho * g) + r.V1 ^ 2 / (2 * g)
  r.Pot = rho * g * r.Q * r.HB
  if p.eta and p.eta > 0 then r.Pshaft = r.Pot / p.eta end
  return OK
end

-- ================================================================== D4 tanque
local function rk4(f, t, y, h)
  local k1 = f(t, y)
  local k2 = f(t + h / 2, y + h / 2 * k1)
  local k3 = f(t + h / 2, y + h / 2 * k2)
  local k4 = f(t + h, y + h * k3)
  return y + h / 6 * (k1 + 2 * k2 + 2 * k3 + k4)
end

function D.dyn_tank(p, r)
  local A = p.A
  if not (A and A > 0) or not finite(p.y0) then return E_ARG end
  local g = p.g or 9.81
  local zs = p.zs or 0
  local qe = p.qe
  if type(qe) ~= "function" then
    local c = qe or 0
    qe = function() return c end
  end
  local qs, torr
  if type(p.qs) == "function" then
    qs = p.qs
  elseif p.Cd and p.a and p.Cd > 0 and p.a > 0 then
    torr = true
    local ca = p.Cd * p.a
    qs = function(_, y)
      local hh = y - zs
      if hh < 0 then hh = 0 end
      return ca * sqrt(2 * g * hh)
    end
  else
    return E_ARG
  end
  local mode, T, target
  if p.ytarget ~= nil then
    if not finite(p.ytarget) then return E_ARG end
    mode, target, T = "target", p.ytarget, p.tmax or 1e6
  else
    if not (p.tf and p.tf > 0) then return E_ARG end
    mode, T = "level", p.tf
  end
  if not (T > 0) then return E_ARG end
  local bad = false
  local function f(t, y)
    local v = (qe(t) - qs(t, y)) / A
    if not finite(v) then bad = true; return 0 end
    return v
  end
  local at = p.at or (torr and p.a) or nil

  local t, y = 0, p.y0
  r.status = (mode == "level") and "level" or "tmax"
  r.reached = (mode == "level")
  r.Qe0, r.Qs0 = qe(0), qs(0, y)
  if not finite(r.Qe0) or not finite(r.Qs0) then return E_NONF end
  r.dydt0 = (r.Qe0 - r.Qs0) / A
  if at then r.v0 = r.Qs0 / at end
  if torr and r.Qs0 > 0 and r.v0 then r.dvdt0 = g / r.v0 * r.dydt0 end

  local S = { n = 0, t = {}, y = {}, qe = {}, qs = {} }
  local stride, cnt = 1, 0
  local function rec(tt, yy, force)
    cnt = cnt + 1
    if not force and cnt % stride ~= 0 then return end
    local n = S.n + 1
    S.n = n
    S.t[n], S.y[n] = tt, yy
    S.qe[n], S.qs[n] = qe(tt), qs(tt, yy)
    if n >= 2000 and not force then            -- decima: conserva un punto de cada dos
      local m = 0
      for i = 1, n, 2 do
        m = m + 1
        S.t[m], S.y[m], S.qe[m], S.qs[m] = S.t[i], S.y[i], S.qe[i], S.qs[i]
      end
      for i = m + 1, n do S.t[i], S.y[i], S.qe[i], S.qs[i] = nil, nil, nil, nil end
      S.n = m
      stride = stride * 2
    end
  end
  rec(0, y, true)

  local hmax = T / 20
  local h = T / 1000
  local steps, still = 0, 0
  local dir = (target and p.y0 > target) and -1 or 1
  local done = false
  if mode == "target" and abs(p.y0 - target) < 1e-9 then
    done = true
    r.status, r.reached = "target", true
  end
  while not done and t < T do
    steps = steps + 1
    if steps > 60000 then return E_STEPS end
    if h > hmax then h = hmax end
    if h > T - t then h = T - t end
    local y1 = rk4(f, t, y, h)
    local ym = rk4(f, t, y, h / 2)
    local y2 = rk4(f, t + h / 2, ym, h / 2)
    if bad then return E_NONF end
    local e = abs(y2 - y1) / 15
    local tol = 1e-9 * (1 + abs(y))
    if e <= tol or h < T * 1e-12 then
      local yn = y2 + (y2 - y1) / 15
      local crossed = false
      if mode == "target" then
        if dir < 0 then crossed = (yn <= target) else crossed = (yn >= target) end
      end
      if crossed then
        local lo, hi = 0, h
        for _ = 1, 60 do
          local mid = (lo + hi) / 2
          local ym2 = rk4(f, t, y, mid)
          local c2
          if dir < 0 then c2 = (ym2 <= target) else c2 = (ym2 >= target) end
          if c2 then hi = mid else lo = mid end
        end
        t = t + (lo + hi) / 2
        y = target
        done = true
        r.status, r.reached = "target", true
        rec(t, y, true)
      elseif mode == "target" and abs(yn - target) < 1e-9 then
        t = t + h
        y = target
        done = true
        r.status, r.reached = "target", true
        rec(t, y, true)
      else
        t = t + h
        y = yn
        rec(t, y, false)
        if abs(f(t, y)) < 1e-10 then still = still + 1 else still = 0 end
        if still >= 3 then
          r.status = "equilibrium"
          if mode == "level" then
            r.reached = true
            t = T
            rec(t, y, true)
          else
            r.reached = false
          end
          done = true
        end
        if not done then
          local fac = (e > 0) and 0.9 * (tol / e) ^ 0.2 or 4
          if fac > 4 then fac = 4 end
          h = h * fac
        end
      end
    else
      h = h * math.max(0.1, 0.9 * (tol / e) ^ 0.2)
    end
  end
  if bad then return E_NONF end
  if not done and mode == "target" then r.status, r.reached = "tmax", false end
  r.steps = steps
  r.t_end, r.y_end = t, y
  r.Qe_end, r.Qs_end = qe(t), qs(t, y)
  if at then r.v_end = r.Qs_end / at end
  if torr and r.Qe_end and r.Qe_end > 0 then
    r.y_eq = zs + (r.Qe_end / (p.Cd * p.a)) ^ 2 / (2 * g)
  end
  if S.t[S.n] ~= t then rec(t, y, true) end
  r.samples = S
  return OK
end

return D
