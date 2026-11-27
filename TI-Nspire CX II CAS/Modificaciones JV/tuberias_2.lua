platform.apiLevel = '2.4'
--------------------------------------------------------------------
-- TUBERIAS 2  -  App Lua para TI-Nspire CX II-T CAS
-- PERDIDAS v2.1 completo (traducido del programa en C de la TI-84 CE):
-- tipos A B D C F E I, sistemas G, Calcular f, memoria de calculo paso
-- a paso, grafica de LE y LP, Mis casos, biblioteca, ajustes y ayuda;
-- FLUJOS v2.1 completo: arrastre y sustentacion (AR-1 a AR-4, placa y
-- Stokes, catalogo de CD con ilustraciones 3D), vertedores y orificios
-- (VE-1 a VE-8) y canales y medicion (EX-1 a EX-4);
-- + el programa original "Tuberias hf + hL".
-- Unidades en pantalla: Q l/s, D y ks mm, L/H/cotas m, nu m2/s.
-- Precision: cada valor intermedio se redondea antes del paso siguiente
-- (como a mano): |x| >= 1 con 3 decimales; |x| < 1 en cientifica con 3
-- decimales (1.116E-2). Todo se muestra con ese mismo formato.
-- Teclas: flechas mover | enter aceptar | esc volver | del borrar
--         clear vaciar | en resultados: 1 MEMORIA, 2 GRAFICO, 3 GUARDAR
--------------------------------------------------------------------

local pi, sqrt, abs, floor = math.pi, math.sqrt, math.abs, math.floor
local fmt = string.format
function log10(x) return math.log(x) / math.log(10) end

local W, H = 318, 212

-- valores escritos en los formularios (compartidos entre pantallas)
local MEM, TOG = {}, {}

-- ============================ AJUSTES ============================
local CFG = {
  g = 9.81, gamma = 9810.0, nu = 1.0e-6, tol = 1.0e-5,
  re_lam = 2000.0, re_turb = 4000.0, ld_limit = 4000.0,
  v_min = 0.3, v_max = 5.0, hm_ratio = 0.3, max_iter = 200,
  pv = 2339.0, dec = 6,
  rho_air = 1.2, nu_air = 1.5e-5, cd_weir = 0.6, knot = 1.85, mano = 0, buoy = 0,
}
local NU = CFG.nu   -- viscosidad del calculo en curso
local METODOS = {"Colebrook-White", "Swamee-Jain", "Haaland", "Goudar-Sonnad"}
function metodo() return (TOG.met or 1) - 1 end

local EPS, BISR, SECR, SECMAX = 1e-12, 1e-12, 1e-10, 12
local LAM, TRANS, TURB = 0, 1, 2
local REGN = {[0] = "laminar", [1] = "transicion", [2] = "turbulento"}

local ERR = {
  D = "D debe ser mayor que 0", L = "L debe ser mayor que 0",
  Q = "Q debe ser mayor que 0", NU = "nu debe ser mayor que 0",
  KS = "ks no puede ser negativo", K = "Suma K no puede ser negativa",
  NOFLOW = "H <= 0: no hay flujo por gravedad",
  ETA = "Eficiencia debe estar en (0, 1]", NOCONV = "No convergio",
  NOROOT = "Sin solucion en el rango buscado",
  HV = "Carga insuficiente: hace falta bomba", HT = "Carga neta <= 0",
  HF = "hf <= 0: revisar datos", LIST = "Ningun diametro de la lista alcanza",
  NET = "Sistema mal definido", CH = "C_H debe ser mayor que 0",
}
function herr(m) error(m, 0) end

-- ===================== REDONDEO A 3 DECIMALES =====================
-- Cada valor intermedio se redondea antes de usarse en el paso siguiente,
-- como al hacerlo a mano:
--   |x| >= 1 : 3 decimales fijos          (1385304.123, 30.395)
--   |x| <  1 : cientifica con 3 decimales  (1.116E-2, 1.020E-6)
function r3(x)
  if type(x) ~= "number" or x ~= x or x == 0 or x == math.huge or x == -math.huge then
    return x
  end
  local s = (x < 0) and -1 or 1
  local a = abs(x)
  if a >= 1 then return s * floor(a * 1000 + 0.5) / 1000 end
  local e = floor(log10(a))
  local m = floor(a / 10 ^ e * 1000 + 0.5) / 1000
  if m >= 10 then m = m / 10; e = e + 1 end
  if m < 1 then m = m * 10; e = e - 1 end
  local r = s * m * 10 ^ e
  if abs(r) >= 1 then return s * floor(abs(r) * 1000 + 0.5) / 1000 end
  return r
end
local RD = r3

-- D (m) y Q (m3/s) se redondean en las unidades de trabajo: 3 decimales
-- en mm y en l/s (resolucion 0.001 mm y 0.001 l/s)
function rmm(x)
  if type(x) ~= "number" or x ~= x then return x end
  return floor(x * 1e6 + 0.5) / 1e6
end
rls = rmm

-- ===================== MOTOR HIDRAULICO =====================
function area(D) return RD(pi * D * D / 4) end
function logclear(lg) if lg then for i = #lg, 1, -1 do lg[i] = nil end end end
function logrow(lg, ...) if lg then lg[#lg + 1] = {...} end end

-- Colebrook-White por sustitucion sobre x = 1/sqrt(f), f1 = 0.0001.
-- Cada x se redondea; termina cuando x se repite (o entra en ciclo).
function cw_iter(Re, a, lg)
  local x, xp2, it = 100.0, nil, 0
  logclear(lg)
  logrow(lg, 1, RD(1 / (x * x)))
  for i = 1, 60 do
    local xn = RD(-2 * log10(a + 2.51 * x / Re))
    it = i
    logrow(lg, i + 1, RD(1 / (xn * xn)))
    if xn == x or xn == xp2 then x = xn; break end
    xp2 = x
    x = xn
  end
  return RD(1 / (x * x)), it
end

function regime_of(Re)
  if Re < CFG.re_lam then return LAM end
  if Re <= CFG.re_turb then return TRANS end
  return TURB
end

-- devuelve f, regimen, iteraciones
function friction(Re, ksD, m)
  if not (Re > 0) then herr(ERR.Q) end
  if not (ksD >= 0) then herr(ERR.KS) end
  if Re < CFG.re_lam then return RD(64 / Re), LAM, 0 end
  local reg = (Re <= CFG.re_turb) and TRANS or TURB
  local a = RD(ksD / 3.7)
  if m == 1 then
    local t = log10(a + 5.74 / Re ^ 0.9)
    return RD(0.25 / (t * t)), reg, 0
  elseif m == 2 then
    local x = RD(-1.8 * log10(a ^ 1.11 + 6.9 / Re))
    return RD(1 / (x * x)), reg, 0
  elseif m == 3 then
    local Cg = RD(0.124 * Re * ksD + math.log(0.4587 * Re))
    local x = RD(0.8686 * math.log(0.4587 * Re / ((Cg - 0.31) ^ (Cg / (Cg + 1)))))
    return RD(1 / (x * x)), reg, 0
  end
  local f, it = cw_iter(Re, a, nil)
  return f, reg, it
end

-- los 4 metodos a la vez (Calcular f)
function fric_all(Re, ksD, lg)
  local t = {f = {}, dpct = {}, out = {false, false, false, false}, iters = 0}
  local reg
  for m = 0, 3 do
    local f
    f, reg = friction(Re, ksD, m)
    t.f[m + 1] = f
  end
  t.regime = reg
  logclear(lg)
  if reg ~= LAM then
    t.f[1], t.iters = cw_iter(Re, RD(ksD / 3.7), lg)
    t.out[1] = ksD > 0.05
    t.out[2] = Re < 4000 or Re > 1e8 or ksD < 1e-6 or ksD > 1e-2
    t.out[3] = Re < 4000 or Re > 1e8 or ksD > 0.05
    t.out[4] = Re < 4000 or ksD > 0.05
  end
  for m = 1, 4 do t.dpct[m] = RD(100 * (t.f[m] - t.f[1]) / t.f[1]) end
  return t
end

function check_pipe(p)
  if not (p.D > 0) then herr(ERR.D) end
  if not (p.L > 0) then herr(ERR.L) end
  if not (p.K >= 0) then herr(ERR.K) end
  if not (p.ff >= 0) then herr(ERR.KS) end
  if p.ff > 0 then return end
  if not (p.ks >= 0) then herr(ERR.KS) end
  if not (NU > 0) then herr(ERR.NU) end
end

function state_warn(s, p)
  local w = {}
  if p.ff <= 0 then
    if s.regime == LAM then w.lam = true
    elseif s.regime == TRANS then w.trans = true end
    if s.ksD > 0.05 then w.ksd = true end
    if metodo() == 1 and s.regime ~= LAM and
       (s.Re < 4000 or s.Re > 1e8 or s.ksD < 1e-6 or s.ksD > 1e-2) then
      w.sj = true
    end
  end
  if s.v > CFG.v_max then w.vhigh = true end
  if s.v < CFG.v_min then w.vlow = true end
  if s.hm > CFG.hm_ratio * s.hf then w.hm = true end
  if p.K > 0 and s.LD > CFG.ld_limit then w.ld = true end
  return w
end

-- Tipo A: estado de un tubo con caudal dado (cada paso redondeado)
function pipe_state(p, Q)
  check_pipe(p)
  if not (Q > 0) then herr(ERR.Q) end
  local s = {Q = rls(Q)}
  s.A = area(p.D)
  s.v = RD(s.Q / s.A)
  s.Re = RD(s.v * p.D / NU)
  s.ksD = RD(p.ks / p.D)
  s.LD = RD(p.L / p.D)
  s.hv2g = RD(s.v * s.v / (2 * CFG.g))
  if p.ff > 0 then
    s.f, s.f_iters, s.regime = RD(p.ff), 0, regime_of(s.Re)
  else
    s.f, s.regime, s.f_iters = friction(s.Re, s.ksD, metodo())
  end
  s.hf = RD(s.f * s.LD * s.hv2g)
  s.hm = RD(p.K * s.hv2g)
  s.hT = RD(s.hf + s.hm)
  s.warn = state_warn(s, p)
  return s
end

function hT_of_v(p, v)
  if not (v > 0) then return 0 end
  local f = p.ff
  local Re = RD(v * p.D / NU)
  if not (f > 0) then
    local ok, ff = pcall(friction, Re, RD(p.ks / p.D), metodo())
    if not ok then return 0 end
    f = ff
  end
  local hv = RD(v * v / (2 * CFG.g))
  return RD(RD(f * RD(p.L / p.D) * hv) + RD(p.K * hv))
end

function solve_v_bisection(p, H, lg)
  local lo, hi, it = 0, 1.0, 0
  while hT_of_v(p, hi) < H do
    if it > 40 then herr(ERR.NOROOT) end
    lo = hi
    hi = hi * 2
    it = it + 1
  end
  local n = 0
  for i = 1, 200 do
    n = i
    local mid = RD(0.5 * (lo + hi))
    local g = RD(hT_of_v(p, mid) - H)
    logrow(lg, i, lo, hi, mid, g)
    if g == 0 then lo, hi = mid, mid; break end
    if g > 0 then hi = mid else lo = mid end
    local nm = RD(0.5 * (lo + hi))
    if g == 0 or nm == lo or nm == hi then break end
  end
  return RD(0.5 * (lo + hi)), n
end

-- velocidad de la formula del curso dado hf
function v_course(p, hf)
  local g2 = 2 * CFG.g
  local arg = RD(p.ks / (3.7 * p.D) +
                2.51 * NU * sqrt(p.L) / sqrt(g2 * p.D * p.D * p.D * hf))
  return RD(-sqrt(4 * g2 * p.D * hf / p.L) * log10(arg))
end

-- raiz x > 0 de a x^p + b x^q = H (Newton, solo arranque)
function pow_root(a, p, b, q, H)
  local x = (H / a) ^ (1 / p)
  for _ = 1, 8 do
    local t1 = a * x ^ p
    local t2 = b * x ^ q
    x = x - x * (t1 + t2 - H) / (p * t1 + q * t2)
  end
  return RD(x)
end

-- secante protegida (tipos B y D); termina cuando x se repite
function secant(fn, s, x, k, lo, hi, sg, lg)
  local xp, Fp = x, 0
  logclear(lg)
  for i = 0, SECMAX + 1 do
    local ok, o0, o1, o2 = fn(s, x)
    if not ok then return false end
    logrow(lg, i, x, o0, o1, o2)
    if o2 == 0 or (i > 1 and x == xp) then
      return true, (i > 1) and (i - 1) or 0, x
    end
    local n
    if i > 0 then
      if o2 == Fp then n = x else n = x - o2 * (x - xp) / (o2 - Fp) end
    elseif k > 0 then n = k * x
    else n = x - o2 end
    n = s.Q and rmm(n) or RD(n)
    if not (n > lo and n < hi) then n = s.Q and rmm(0.5 * (lo + hi)) or RD(0.5 * (lo + hi)) end
    if o2 * sg > 0 then lo = x else hi = x end
    xp = x
    Fp = o2
    x = n
  end
  return false
end

-- Hazen-Williams
function hw_hf(Q, D, L, CH)
  if not (Q > 0 and D > 0 and L > 0 and CH > 0) then return 0 end
  return RD(10.675 * L * Q ^ 1.852 / (CH ^ 1.852 * D ^ 4.87))
end
function hw_q(Hh, D, L, CH)
  if not (Hh > 0 and D > 0 and L > 0 and CH > 0) then return 0 end
  return RD((Hh * CH ^ 1.852 * D ^ 4.87 / (10.675 * L)) ^ (1 / 1.852))
end

function fB(s, hf)
  local v = v_course(s.p, hf)
  local hm = RD(s.p.K * v * v / (2 * CFG.g))
  return v > 0, v, hm, RD(hf + hm - s.H)
end

-- Tipo B: caudal maximo. o = {CH = arranque HW, secant = bool}
function qmax(p, Hh, o, lg)
  logclear(lg)
  local r = {iters = 0, course_ok = false, hw = false, Q0 = 0, hf1 = Hh, solver = "bis"}
  check_pipe(p)
  if not (Hh > 0) then herr(ERR.NOFLOW) end
  local A = area(p.D)
  local g2 = 2 * CFG.g
  local v = 0
  local sec = o and o.secant
  if p.ff > 0 then
    v = RD(sqrt(g2 * Hh / (p.ff * RD(p.L / p.D) + p.K)))
    r.solver = "direct"
    r.iters = 1
  elseif metodo() == 0 then
    if o and o.CH and o.CH > 0 then
      r.Q0 = pow_root(hw_hf(1, p.D, p.L, o.CH), 1.852, p.K / (g2 * A * A), 2.0, Hh)
      r.hf1 = hw_hf(r.Q0, p.D, p.L, o.CH)
      if r.hf1 > 0 and r.hf1 < Hh then
        r.hw = true
        v = RD(r.Q0 / A)
        logrow(lg, 0, r.hf1, v, RD(p.K * v * v / g2), r.hf1)
      else
        r.hf1 = Hh
      end
    end
    local hf = r.hf1
    if sec then
      local ok, it, root = secant(fB, {p = p, H = Hh}, hf, 0, 0, Hh, -1, lg)
      if ok then
        r.iters = it
        hf = root
        v = v_course(p, hf)
        r.course_ok = true
      end
    else
      local hfp2 = nil
      for i = 1, CFG.max_iter do
        v = v_course(p, hf)
        if not (v > 0) then break end
        local hm = RD(p.K * v * v / g2)
        local hfn = RD(Hh - hm)
        logrow(lg, i, hf, v, hm, hfn)
        r.iters = i
        if not (hfn > 0) then break end
        if abs(hfn - hf) <= CFG.tol + EPS * hf or hfn == hfp2 then
          v = v_course(p, hfn)
          r.course_ok = true
          break
        end
        hfp2 = hf
        hf = hfn
      end
    end
    if r.course_ok and v * p.D / NU < CFG.re_lam then r.course_ok = false end
    if r.course_ok then r.solver = sec and "sec" or "course" end
  end
  if r.solver == "bis" then
    logclear(lg)
    v, r.iters = solve_v_bisection(p, Hh, lg)
  end
  r.st = pipe_state(p, rls(v * A))
  if r.solver == "bis" and metodo() == 0 and p.ff <= 0 then r.st.warn.fb = true end
  return r
end

-- Tipo C: bomba y turbina
function pump(p, Q, Hs, eta)
  if not (eta > 0 and eta <= 1) then herr(ERR.ETA) end
  local r = {st = pipe_state(p, Q)}
  r.Hm = RD(Hs + r.st.hT)
  r.Pn = RD(CFG.gamma * r.st.Q * r.Hm)
  r.Pb = RD(r.Pn / eta)
  if not (r.Hm > 0) then herr(ERR.HT) end
  return r
end
function turbine(p, Q, Ha, eta)
  if not (eta > 0 and eta <= 1) then herr(ERR.ETA) end
  local r = {st = pipe_state(p, Q)}
  r.Hm = RD(Ha - r.st.hT)
  r.Pb = RD(CFG.gamma * r.st.Q * r.Hm)
  r.Pn = RD(eta * r.Pb)
  if not (r.Hm > 0) then herr(ERR.HT) end
  return r
end

function copypipe(p) return {D = p.D, L = p.L, ks = p.ks, K = p.K, ff = p.ff} end

function hT_of_D(p, D, Q)
  local q = copypipe(p)
  q.D = D
  local ok, s = pcall(pipe_state, q, Q)
  if not ok then return -1 end
  return s.hT
end

function fD(s, D)
  local v = RD(s.Q / area(D))
  local h = hT_of_D(s.p, D, s.Q)
  return h > 0, v, h, RD(h - s.H)
end

function vp_fn(Hh, hf, K)
  if not (K > 0) or not (Hh > hf) then return 0 end
  return RD(sqrt(2 * CFG.g * (Hh - hf) / K))
end

-- Tipo F: valvula de control (devuelve tambien si hv < 0)
function valve(p, Q, Ha)
  local r = {st = pipe_state(p, Q)}
  r.hv = RD(Ha - r.st.hT)
  r.Kv = RD(2 * CFG.g * r.hv / (r.st.v * r.st.v))
  return r
end

-- Tipo D: diseno del diametro
function design(p, Qd, Hh, list, o, lg)
  logclear(lg)
  local q = copypipe(p)
  q.ff = 0
  local lo, hi = 0.001, 20.0
  local r = {D_exact = 0, D_com = 0, idx = nil, vp = 0, warn = {}, iters = 0,
             D0 = 0, solver = "bis", hw = false, fb = false}
  q.D = 1.0
  check_pipe(q)
  if not (Qd > 0) then herr(ERR.Q) end
  if not (Hh > 0) then herr(ERR.NOFLOW) end
  if hT_of_D(q, hi, Qd) > Hh or hT_of_D(q, lo, Qd) < Hh then herr(ERR.NOROOT) end
  if o and (o.secant or (o.CH and o.CH > 0)) then
    local k8 = 8 * Qd * Qd / (pi * pi * CFG.g)
    r.hw = (o.CH or 0) > 0
    local a, pp
    if r.hw then a, pp = hw_hf(Qd, 1, q.L, o.CH), -4.87
    else a, pp = 0.02 * q.L * k8, -5.0 end
    r.D0 = pow_root(a, pp, q.K * k8, -4.0, Hh)
    local ok, it, root = secant(fD, {p = q, Q = Qd, H = Hh}, r.D0, 1.02, lo, hi, 1, lg)
    if ok then
      r.solver = "sec"
      r.iters = it
      r.D_exact = root
    else
      r.fb = true
      logclear(lg)
    end
  end
  if r.solver == "bis" then
    local n = 0
    for i = 1, 200 do
      n = i
      local mid = rmm(sqrt(lo * hi))
      local g = RD(hT_of_D(q, mid, Qd) - Hh)
      logrow(lg, i, lo, hi, mid, g)
      if g == 0 then lo, hi = mid, mid; break end
      if g > 0 then lo = mid else hi = mid end
      local nm = rmm(sqrt(lo * hi))
      if g == 0 or nm == lo or nm == hi then break end
    end
    r.iters = n
    r.D_exact = rmm(0.5 * (lo + hi))
  end
  q.D = r.D_exact
  local ok, st = pcall(pipe_state, q, Qd)
  if ok then r.st_exact = st end
  if not list or #list == 0 then return r end
  for i, d in ipairs(list) do
    if d >= r.D_exact and (r.idx == nil or d < r.D_com) then
      r.D_com = d
      r.idx = i
    end
  end
  if not r.idx then herr(ERR.LIST) end
  q.D = r.D_com
  r.st_com = pipe_state(q, Qd)
  r.qmax = qmax(q, Hh, o, nil)
  if r.st_com.hm > CFG.hm_ratio * r.st_com.hf then
    r.warn.hm = true
    r.vp = vp_fn(Hh, r.st_com.hf, q.K)
  end
  return r
end

-- Tipo E: calibracion de ks. dz = z1 - z2; dp = p1/g - p2/g
function calibrate(D, L, Q, K, dz, dp)
  if not (D > 0) then herr(ERR.D) end
  if not (L > 0) then herr(ERR.L) end
  if not (Q > 0) then herr(ERR.Q) end
  if not (K >= 0) then herr(ERR.K) end
  if not (NU > 0) then herr(ERR.NU) end
  local r = {warn = {}}
  r.A = area(D)
  r.v = RD(Q / r.A)
  r.hm = RD(K * r.v * r.v / (2 * CFG.g))
  r.htot = RD(dz + dp)
  r.hf = RD(r.htot - r.hm)
  r.Re = RD(r.v * D / NU)
  if not (r.hf > 0) then herr(ERR.HF) end
  r.f = RD(2 * CFG.g * D * r.hf / (L * r.v * r.v))
  local sf = RD(sqrt(r.f))
  r.ks = RD(3.7 * D * (10 ^ (-1 / (2 * sf)) - 2.51 / (r.Re * sf)))
  r.ksD = RD(r.ks / D)
  if r.Re < CFG.re_lam then r.warn.lam = true
  elseif r.Re <= CFG.re_turb then r.warn.trans = true end
  if r.ks < 0 then r.warn.ksneg = true
  elseif r.ksD > 0.05 then r.warn.ksd = true end
  return r
end

function pressure_head(head_up, HB, v, hl, w)
  local p = RD(head_up + HB - RD(v * v / (2 * CFG.g)) - hl)
  if p < 0 then w.pneg = true end
  if p < -101325 / CFG.gamma then w.cav = true end
  return p
end

-- ---------- Tipo G: redes serie / paralelo ----------
function net_new() return {nodes = {}, root = 0, outer = 0, res_q = 0, res_h = 0} end

function net_add_pipe(n, L, D, f, ks, K)
  n.nodes[#n.nodes + 1] = {type = "pipe", pipe = {L = L, D = D, ff = f, ks = ks, K = K},
                           f = f, M = 0, Mf = 0, Mk = 0, Q = 0, h = 0}
  n.root = #n.nodes
  return #n.nodes
end

function net_add_group(n, typ, kids)
  n.nodes[#n.nodes + 1] = {type = typ, kids = kids, M = 0, Q = 0, h = 0}
  n.root = #n.nodes
  return #n.nodes
end

function module_coef() return RD(8 / (pi * pi * CFG.g)) end

function net_reduce(n, idx, depth)
  if depth > 16 then herr(ERR.NET) end
  local nd = n.nodes[idx]
  if nd.type == "pipe" then
    local D = nd.pipe.D
    local k0 = module_coef()
    nd.Mf = RD(k0 * nd.f * nd.pipe.L / D ^ 5)
    nd.Mk = RD(k0 * nd.pipe.K / D ^ 4)
    nd.M = RD(nd.Mf + nd.Mk)
    return
  end
  local s = 0
  for _, c in ipairs(nd.kids) do
    net_reduce(n, c, depth + 1)
    local M = n.nodes[c].M
    if nd.type == "ser" then
      s = s + M
    else
      if not (M > 0) then herr(ERR.NET) end
      s = s + RD(1 / sqrt(M))
    end
  end
  if nd.type == "ser" then nd.M = RD(s) else nd.M = RD(1 / (s * s)) end
end

function net_dist(n, idx, Q, depth)
  local nd = n.nodes[idx]
  nd.Q = rls(Q)
  nd.h = RD(nd.M * nd.Q * nd.Q)
  if nd.type == "pipe" or depth > 16 then return end
  local sq, sh = 0, 0
  for _, c in ipairs(nd.kids) do
    local ch = n.nodes[c]
    if nd.type == "ser" then net_dist(n, c, nd.Q, depth + 1)
    else net_dist(n, c, rls(sqrt(nd.h / ch.M)), depth + 1) end
    sq = sq + ch.Q
    sh = sh + ch.h
    if nd.type == "par" then
      local d = abs(ch.h - nd.h)
      if d > n.res_h then n.res_h = d end
    end
  end
  local d
  if nd.type == "ser" then
    d = abs(sh - nd.h)
    if d > n.res_h then n.res_h = d end
  else
    d = abs(sq - nd.Q)
    if d > n.res_q then n.res_q = d end
  end
  n.res_q, n.res_h = RD(n.res_q), RD(n.res_h)
end

function net_solve(n, Hh)
  if #n.nodes == 0 then herr(ERR.NET) end
  if not (Hh > 0) then herr(ERR.NOFLOW) end
  local autof = false
  for _, nd in ipairs(n.nodes) do
    if nd.type == "pipe" then
      check_pipe(nd.pipe)
      if nd.pipe.ff > 0 then nd.f = RD(nd.pipe.ff)
      else nd.f = 0.02; autof = true end
    end
  end
  local conv = false
  local sig1, sig2 = nil, nil
  for it = 1, 50 do
    n.res_q, n.res_h = 0, 0
    net_reduce(n, n.root, 0)
    net_dist(n, n.root, RD(sqrt(Hh / n.nodes[n.root].M)), 0)
    n.outer = it
    if not autof then conv = true; break end
    local ch = 0
    local sig = ""
    for _, nd in ipairs(n.nodes) do
      if nd.type == "pipe" and not (nd.pipe.ff > 0) then
        local fnew = friction(RD(nd.Q / area(nd.pipe.D) * nd.pipe.D / NU),
                              RD(nd.pipe.ks / nd.pipe.D), metodo())
        if abs(fnew - nd.f) > ch * nd.f then ch = abs(fnew - nd.f) / nd.f end
        nd.f = fnew
        sig = sig .. numstr(fnew) .. ";"
      end
    end
    if ch <= 10 * EPS or sig == sig2 then conv = true; break end
    sig2 = sig1
    sig1 = sig
  end
  if autof and not conv then herr(ERR.NOCONV) end
end

function net_solve_back(n, k, Qk)
  if not (Qk > 0) then herr(ERR.Q) end
  Qk = RD(Qk)
  local h, hp2 = 1.0, nil
  for it = 0, 49 do
    net_solve(n, h)
    local q = n.nodes[k].Q
    if not (q > 0) then herr(ERR.NET) end
    if it > 0 and (q == Qk or abs(q - Qk) <= 10 * EPS * Qk) then break end
    local hn = RD(h * (Qk / q) * (Qk / q))
    if hn == h or hn == hp2 then h = hn; net_solve(n, h); break end
    hp2 = h
    h = hn
  end
  return h
end

-- =========================== DATOS ===========================
local MATERIALES = {
  {"PVC y CPVC", 0.0015, 150}, {"PEAD (polietileno)", 0.007, 150},
  {"Vidrio", 0.0003, 0}, {"Asbesto cemento", 0.03, 140},
  {"Fibra vidrio (GRP)", 0.03, 150}, {"Acero comercial", 0.045, 0},
  {"Concreto centrifug.", 0.12, 0}, {"H. fundido asfalt.", 0.12, 0},
  {"Hierro fundido", 0.15, 130}, {"Hierro galvanizado", 0.15, 120},
  {"Arcilla vitrificada", 0.15, 100}, {"Hierro ductil", 0.25, 140},
  {"Concreto", 0.30, 0}, {"Acero liso (C_H)", -1, 130},
  {"Acero soldado (C_H)", -1, 120}, {"Acero bridas (C_H)", -1, 110},
  {"Concreto liso (C_H)", -1, 140}, {"Concreto rug. (C_H)", -1, 120},
  {"Cobre/laton (C)", 0.0015, 0}, {"Acero inox. (C)", 0.002, 0},
  {"Hule alisado (C)", 0.01, 0}, {"Hierro forjado (C)", 0.046, 0},
  {"Hierro fundido (C)", 0.26, 0}, {"Duela de madera (C)", 0.5, 0},
}

local ACCESORIOS = {
  {"Entrada borde recto", 0.5}, {"Entrada redondeada", 0.2},
  {"Entrada saliente", 0.8}, {"Entrada muy redond.", 0.04},
  {"Salida a tanque", 1.0}, {"Codo 90 embridado", 0.3},
  {"Codo 90 roscado", 0.9}, {"Codo 90 esquina", 1.1},
  {"Codo 90 esq. alabes", 0.2}, {"Codo 45 roscado", 0.4},
  {"Retorno 180 embrid.", 0.2}, {"Retorno 180 roscado", 1.5},
  {"Te deriv. embridada", 1.0}, {"Te deriv. roscada", 2.0},
  {"Te linea embridada", 0.2}, {"Te linea roscada", 0.9},
  {"Union roscada", 0.08}, {"V. globo abierta (C)", 10},
  {"V. angulo abierta", 5}, {"V. bola abierta", 0.05},
  {"V. charnela", 2}, {"V. compuerta (C)", 0.2},
  {"V. compuerta 1/4 c.", 0.3}, {"V. compuerta 1/2 c.", 2.1},
  {"V. compuerta 3/4 c.", 17}, {"V. check (curso)", 0.8},
  {"V. compuerta (curso)", 0.15}, {"V. mariposa (curso)", 0.2},
  {"V. globo (curso)", 4.0}, {"V. esferica (curso)", 0.2},
}

local PRESETS_K = {
  {"PVC 200 mm (pag. 51)", {{"Entrada borde recto", 1, 0.5}, {"V. compuerta", 3, 0.15},
    {"Uniones", 167, 0.01}, {"Codo 45", 12, 0.18}, {"Codo 90", 6, 0.32}}},
  {"Examen 2025 P1", {{"Entrada", 1, 0.5}, {"Salida", 1, 1.0}, {"Codo 90", 4, 1.10},
    {"Codo 45", 10, 0.30}, {"V. compuerta", 3, 0.3}, {"V. de boya", 1, 3.0}}},
  {"Examen 2019 P4", {{"Filtro", 1, 8.0}, {"Codo 90", 4, 0.5}, {"Valvula D", 1, 1.0},
    {"Te", 1, 0.7}, {"Cruz", 1, 0.7}, {"Fluviometro", 1, 6.0}, {"Valvula L", 1, 3.0}}},
  {"Examen 2017 P4", {{"Codo 90", 3, 0.2}, {"Codo 45", 2, 0.1}, {"Retencion c/rejilla", 1, 2.0}}},
  {"Examen 2018 P1a", {{"Entrada", 1, 0.8}, {"V. mariposa 30 grad", 1, 10}}},
  {"Examen 2018 P1b", {{"Entrada borde recto", 1, 0.5}, {"V. mariposa abierta", 1, 0.2}}},
}

-- nombre, T (C), rho, nu, pv
local FLUIDOS = {
  {"Agua  5 C (std)", 5, 1000.0, 1.519e-6, 872}, {"Agua 10 C (std)", 10, 999.7, 1.307e-6, 1228},
  {"Agua 15 C (std)", 15, 999.1, 1.139e-6, 1706}, {"Agua 20 C (std)", 20, 998.2, 1.004e-6, 2339},
  {"Agua 25 C (std)", 25, 997.0, 0.893e-6, 3169}, {"Agua 30 C (std)", 30, 995.7, 0.801e-6, 4246},
  {"Agua 40 C (std)", 40, 992.2, 0.658e-6, 7384}, {"Curso: 2025, T4", 0, 0, 1.0e-6, 0},
  {"Curso: 2017-2019", 0, 0, 1.007e-6, 0}, {"Curso: 2024 P1", 0, 0, 1.02e-6, 0},
  {"Curso: ej. 4", 0, 0, 1.14e-6, 0}, {"Curso: hojas", 0, 0, 1.17e-6, 0},
  {"Aire (curso)", 0, 1.2, 1.5e-5, 0}, {"Aire 15 C (std)", 15, 1.225, 1.46e-5, 0},
  {"Aire 20 C (std)", 20, 1.204, 1.516e-5, 0},
}

local DIAMETROS = {
  {"PVC examen 2025", {53.21, 64.45, 78.44, 100.84, 148.46, 193.28, 240.95, 285.75, 358.64}},
  {"Nominal 2024 200-500", {200, 250, 300, 350, 400, 450, 500}},
  {"Pract.3/Ej.5 150-400", {150, 200, 250, 300, 350, 400}},
  {"Practica 2 50-300", {50, 75, 100, 150, 300}},
  {"General 50-1500", {50, 75, 100, 150, 200, 250, 300, 350, 400, 450, 500, 600,
                       700, 800, 900, 1000, 1200, 1500}},
}

-- ===================== FORMATO DE NUMEROS =====================
-- Igual que numfmt.c de la TI-84: 7 cifras significativas, ceros finales
-- fuera, notacion cientifica fuera de [1E-4, 1E7).
local SIG = 7

function put_scaled(u, nd)
  local s = fmt("%.0f", u)
  if #s <= nd then s = string.rep("0", nd - #s + 1) .. s end
  local ip = s:sub(1, #s - nd)
  local fp = s:sub(#s - nd + 1)
  fp = fp:gsub("0+$", "")
  if fp ~= "" then return ip .. "." .. fp end
  return ip
end

function fmt_real(x, dec)
  if x == nil then return "0" end
  if x ~= x or x == math.huge or x == -math.huge then return "ERR" end
  local neg = ""
  if x < 0 then neg = "-"; x = -x end
  if x == 0 then return "0" end
  local a = x
  local function sci()
    local e = 0
    while a >= 10 do a = a / 10; e = e + 1 end
    while a < 1 do a = a * 10; e = e - 1 end
    local nd = math.min(dec, SIG - 2)
    local u = floor(a * 10 ^ nd + 0.5)
    if u >= 10 ^ (nd + 1) then u = floor(u / 10); e = e + 1 end
    return neg .. put_scaled(u, nd) .. "E" .. fmt("%d", e)
  end
  if a >= 1e7 or a < 1e-4 then return sci() end
  local intd = 1
  while intd < SIG and a >= 10 ^ intd do intd = intd + 1 end
  local nd = SIG - intd
  if nd > dec then nd = dec end
  if a < 1 then
    local z, t = 0, a
    while t < 0.1 and z < 6 do t = t * 10; z = z + 1 end
    nd = SIG + z
    if nd > dec then nd = dec end
  end
  local u = floor(a * 10 ^ nd + 0.5)
  if nd == 0 and u >= 1e7 then a = x; return sci() end
  return neg .. put_scaled(u, nd)
end

-- Formato de resultados: siempre 3 decimales.
--   |x| >= 1 : 3 decimales fijos (1385304.123)
--   |x| <  1 : cientifica con 3 decimales (1.116E-2)
function fmt3(x)
  if x == nil then return "0.000" end
  if x ~= x or x == math.huge or x == -math.huge then return "ERR" end
  x = r3(x)
  if x == 0 then return "0.000" end
  local a = abs(x)
  if a >= 1 then return fmt("%.3f", x) end
  local e = floor(log10(a))
  local m = floor(a / 10 ^ e * 1000 + 0.5) / 1000
  if m >= 10 then m = m / 10; e = e + 1 end
  if m < 1 then m = m * 10; e = e - 1 end
  if e >= 0 then return fmt("%.3f", x) end
  return ((x < 0) and "-" or "") .. fmt("%.3f", m) .. "E" .. fmt("%d", e)
end

-- contadores: se muestran como enteros
INTK = {ITER = true, FIT = true, WIT = true, NW = true, FACES = true, WNC = true,
        PRNP = true, EIT = true}
function fint(x) return fmt("%d", floor((x or 0) + 0.5)) end

function fmt_w(x, width) return fmt3(x) end
function fv(x) return fmt3(x) end
function fw(x, w) return fmt3(x) end
function ng(x) return fmt("%.6g", x) end
function numstr(x) return fmt("%.10g", x) end

-- ===================== VISOR DE TEXTO (memoria) =====================
-- lineas: {k="t", t, c} | {k="v", l, v} | {k="sep"} | {k="row", cells, xs, c}
local VW = {}
local WRAP = 50

function vadd(t, c) VW[#VW + 1] = {k = "t", t = t or "", c = c or "fg"} end
function vsep() VW[#VW + 1] = {k = "sep"} end
function vval(l, v, u)
  VW[#VW + 1] = {k = "v", l = l, v = fv(v) .. (u and (" " .. u) or "")}
end
function vrow(cells, c, xs) VW[#VW + 1] = {k = "row", cells = cells, c = c, xs = xs} end
function msec(s)
  if #VW > 2 then vadd("", "fg") end
  vadd(s, "title")
end

function cut_at(s, max)
  for i = max, floor(max / 2) + 1, -1 do
    local c = s:sub(i, i)
    local p = s:sub(i - 1, i - 1)
    if c == " " or c == "+" or c == "*" or c == "/" or c == "(" or
       (c == "-" and i >= 2 and p ~= "E" and p ~= "(") then
      return i
    end
  end
  return max
end

function mline(s, c)
  if not s then return end
  local first = true
  while #s > 0 do
    local room = first and WRAP or (WRAP - 6)
    local take = #s
    if #s > room then take = cut_at(s, room) end
    local part = s:sub(1, take)
    if not first then part = "      " .. part end
    vadd(part, c)
    s = s:sub(take + 1)
    s = s:gsub("^ +", "")
    first = false
  end
end

function meq(lhs, formula, subst, res, unit)
  local pad = #lhs + 1
  if pad > 12 then pad = 4 end
  local sp = string.rep(" ", pad)
  if formula then mline(lhs .. " = " .. formula, "fg") end
  if subst and not formula then mline(lhs .. " = " .. subst, "fg")
  elseif subst then mline(sp .. "= " .. subst, "gray") end
  if not formula and not subst then
    mline(lhs .. " = " .. fv(res) .. " " .. (unit or ""), "ok")
  else
    mline(sp .. "= " .. fv(res) .. " " .. (unit or ""), "ok")
  end
end

function mres(label, v, unit)
  mline("> " .. label .. " = " .. fv(v) .. " " .. (unit or ""), "ok")
end

function warn_lines(w)
  local o = {}
  w = w or {}
  if w.fb then
    o[#o + 1] = "! Iteracion del curso no convergio:"
    o[#o + 1] = "  se resolvio por biseccion"
  end
  if w.lam then o[#o + 1] = "! Re < " .. fmt_real(CFG.re_lam, 0) .. ": laminar, f = 64/Re" end
  if w.trans then o[#o + 1] = "! Re en transicion: resultado indicativo" end
  if w.ksd then o[#o + 1] = "! ks/D > 0.05: fuera de Colebrook-White" end
  if w.sj then o[#o + 1] = "! Fuera del rango de Swamee-Jain" end
  if w.vhigh then o[#o + 1] = "! v > " .. fmt_real(CFG.v_max, 2) .. " m/s: velocidad alta" end
  if w.vlow then o[#o + 1] = "! v < " .. fmt_real(CFG.v_min, 2) .. " m/s: velocidad baja" end
  if w.hm then o[#o + 1] = "! hm > " .. fmt_real(100 * CFG.hm_ratio, 0) .. "% hf: perdidas locales altas" end
  if w.ld then o[#o + 1] = "! L/D > " .. fmt_real(CFG.ld_limit, 0) .. ": locales despreciables" end
  if w.pneg then o[#o + 1] = "! Presion manometrica negativa" end
  if w.cav then o[#o + 1] = "! p/gamma < -10.3 m: imposible" end
  if w.ksneg then o[#o + 1] = "! ks negativo: datos inconsistentes" end
  if w.hneg then o[#o + 1] = "! Valvula: carga insuficiente (hv < 0)" end
  return o
end

function mwarn(w)
  local o = warn_lines(w)
  if #o == 0 then vadd(" Sin advertencias", "ok"); return end
  for _, t in ipairs(o) do vadd(t, "warn") end
end

-- tablas de iteraciones de la memoria
local TABS = {
  course = {{"i", "hf", "v", "hm", "hf+1"}, {1, 1, 1, 1, 1}},
  bis = {{"i", "v min", "v max", "v", "hT-H"}, {1, 1, 1, 1, 1}},
  D = {{"i", "D min", "D max", "D mm", "hT-H"}, {1, 1000, 1000, 1000, 1}},
  cw = {{"i", "f_i"}, {1, 1}},
  bsec = {{"i", "hf", "v", "hm", "G"}, {1, 1, 1, 1, 1}},
  dsec = {{"i", "D mm", "v", "hT", "hT-H"}, {1, 1000, 1, 1, 1}},
  bq = {{"i", "Q min", "Q max", "Q l/s", "F"}, {1, 1, 1, 1, 1}},
}
local XS5 = {6, 30, 100, 170, 240}
local XS2 = {6, 50}

function mtable(kind, lg)
  local t = TABS[kind]
  if not t or not lg then return end
  local nc = #t[1]
  local xs = (nc == 5) and XS5 or XS2
  vrow(t[1], "title", xs)
  local cw = floor(36 / (nc - 1))
  for _, r in ipairs(lg) do
    local cells = {fmt("%d", r[1])}
    for k = 2, nc do cells[k] = fmt_w((r[k] or 0) * t[2][k], cw - 1) end
    vrow(cells, "fg", xs)
  end
end

-- ============ PROGRAMAS DE LA MEMORIA (memo_tables.c) ============
function SEC(t) return {"sec", t} end
function DAT(l, v, u) return {"dat", l, v, u} end
function EQ(l, f, s, v, u) return {"eq", l, f, s, v, u} end
function RES(l, v, u) return {"res", l, v, u} end
function LN(t, c) return {"ln", t, c or "fg"} end
function IF(g) return {"if", g} end
function IFN(g) return {"ifn", g} end
local ENDIF = {"endif"}
function CALL(n) return {"call", n} end
function TAB(k) return {"tab", k} end
local WARNS = {"warns"}
local DLIST = {"dlist"}
local SEPx = {"sep"}
function TX(t) return LN(t, "fg") end
function TG(t) return LN(t, "gray") end

function prog(...)
  local r = {}
  for _, x in ipairs({...}) do
    if type(x[1]) == "table" then
      for _, y in ipairs(x) do r[#r + 1] = y end
    else
      r[#r + 1] = x
    end
  end
  return r
end

local P_DATA = prog(
  SEC("DATOS"),
  IF("WITHQ"), DAT("Q", "Q", "m3/s"), ENDIF,
  IF("HASD"), DAT("D", "D", "m"), ENDIF,
  DAT("L", "L", "m"),
  IF("FIX"), DAT("f (dato)", "F"), ENDIF,
  IFN("FIX"), DAT("ks", "KS", "m"), DAT("nu", "NU", "m2/s"), ENDIF,
  DAT("Suma K", "K"),
  DAT("g", "G", "m/s2"),
  IFN("FIX"), LN(" Metodo de f: {METHOD}", "gray"), ENDIF)

local P_CALC = prog(
  EQ("A", "pi D^2/4", "pi({D})^2/4", "A", "m2"),
  EQ("v", "Q/A", "{Q}/{A}", "V", "m/s"),
  EQ("Re", "v D/nu", "{V}({D})/{NU}", "RE"),
  IF("FIX"), EQ("f", nil, nil, "F", "(dato)"), ENDIF,
  IFN("FIX"),
    IF("LAM"), EQ("f", "64/Re", "64/{RE}", "F", "(laminar)"), ENDIF,
    IFN("LAM"),
      EQ("ks/D", nil, "{KS}/{D}", "KSD"),
      IF("SJ"),
        EQ("f", "0.25/[log(ks/3.7D + 5.74/Re^0.9)]^2",
           "0.25/[log({A37} + 5.74/{RE}^0.9)]^2", "F", "(Swamee-Jain)"),
      ENDIF,
      IF("HA"),
        EQ("1/sqrt(f)", "-1.8 log[(ks/3.7D)^1.11 + 6.9/Re]",
           "-1.8 log[({A37})^1.11 + 6.9/{RE}]", "INVSF"),
        RES("f (Haaland)", "F"),
      ENDIF,
      IF("GO"),
        LN("1/sqrt(f) = 0.8686 ln(0.4587 Re/(C-0.31)^(C/(C+1)))"),
        LN("C = 0.124 Re ks/D + ln(0.4587 Re)"),
        RES("f (Goudar-Sonnad)", "F"),
      ENDIF,
      IF("CW"),
        LN("1/sqrt(f) = -2 log(ks/3.7D + 2.51/(Re sqrt(f)))"),
        LN("      = -2 log({A37} + 2.51/({RE} sqrt(f)))", "gray"),
        LN(" Sustitucion sucesiva desde f1 = 0.0001: {FIT!} iteraciones", "gray"),
        RES("f (Colebrook-White)", "F"),
      ENDIF,
      IF("TRANS"), LN(" Re en transicion: f indicativo", "warn"), ENDIF,
    ENDIF,
  ENDIF,
  EQ("v^2/2g", nil, "({V})^2/(2({G}))", "HV2G", "m"),
  EQ("hf", "f (L/D) v^2/2g", "{F}({L}/{D})({HV2G})", "HF", "m"),
  EQ("hm", "SumK v^2/2g", "{K}({HV2G})", "HM", "m"),
  EQ("hT", "hf + hm", "{HF} + {HM}", "HT", "m"))

local P_OBS = prog(
  SEC("OBSERVACIONES"),
  IF("KPOS"), LN(" L/D = {LD!}; hm/hf = {HMHF!} %", "gray"), ENDIF,
  WARNS)

local P_STATE = prog(
  DAT("Q", "QLS", "l/s"),
  DAT("v", "V", "m/s"),
  DAT("Re", "RE"),
  IF("FIX"), DAT("f (dato)", "F"), ENDIF,
  IFN("FIX"), DAT("f", "F"), ENDIF,
  DAT("hf", "HF", "m"),
  DAT("hm", "HM", "m"),
  DAT("hT = hf + hm", "HT", "m"))

local P_BOMBA = prog(
  IF("BOMB"),
    SEC("BOMBA"),
    LN(" Energia: (z1 - z2) + HB = hf + hm", "gray"),
    IF("BOMBP"),
      DAT("Potencia P", "BP", "kW"), DAT("Eficiencia eta", "BETA"),
      IFN("BOMBQ"),
        EQ("HB", "eta P/(gamma Q)", "{BETA}({BPW})/({GAM}({QB}))", "HB", "m"),
      ENDIF,
      IF("BOMBQ"), LN(" HB depende de Q: se resuelve abajo", "gray"), ENDIF,
    ENDIF,
    IFN("BOMBP"), DAT("HB (dato)", "HB", "m"), ENDIF,
    IF("HEFF"), IFN("BOMBQ"),
      DAT("z1 - z2", "HZ", "m"),
      EQ("H", "(z1 - z2) + HB", "{HZ} + {HB}", "H", "m"),
    ENDIF, ENDIF,
  ENDIF)

local SUBS = {data = P_DATA, calc = P_CALC, obs = P_OBS, state = P_STATE, bomba = P_BOMBA}

-- ---- A ----
local sA = prog(
  LN("RESULTADO  Perdidas dado Q", "title"), SEPx,
  CALL("state"),
  DAT("v^2/2g", "HV2G", "m"),
  IF("BOMB"), DAT("HB bomba", "HB", "m"), ENDIF,
  IF("HP"), DAT("p/gamma punto", "PH", "m"), DAT("p punto", "PKPA", "kPa"), ENDIF,
  SEPx, WARNS)
local mA = prog(
  LN("MEMORIA  Perdidas dado Q (A)", "title"), SEPx,
  CALL("data"),
  IF("HP"), DAT("H sobre punto", "HP", "m"), ENDIF,
  SEC("CALCULOS"), CALL("calc"),
  CALL("bomba"),
  IF("HP"),
    IFN("BOMB"), EQ("p/gamma", "H - v^2/2g - hT", "{HP} - {HV2G} - {HT}", "PH", "m"), ENDIF,
    IF("BOMB"), EQ("p/gamma", "H + HB - v^2/2g - hT", "{HP} + {HB} - {HV2G} - {HT}", "PH", "m"), ENDIF,
  ENDIF,
  SEC("RESULTADOS"),
  RES("hf", "HF", "m"), RES("hm", "HM", "m"), RES("hT", "HT", "m"),
  IF("HP"), RES("p", "PKPA", "kPa"), ENDIF,
  CALL("obs"))

-- ---- B ----
local sB = prog(
  LN("RESULTADO  Caudal maximo", "title"), SEPx,
  CALL("state"),
  IF("COURSE"), LN(" Metodo: iteracion del curso", "gray"), ENDIF,
  IF("DIRECT"), LN(" Metodo: directo (f dado)", "gray"), ENDIF,
  IF("BIS"), LN(" Metodo: biseccion sobre v", "gray"), ENDIF,
  IF("PSEC"), LN(" Metodo: secante (formula del curso)", "gray"), ENDIF,
  IF("PHW"), LN(" Arranque: Hazen-Williams, C_H = {CH0!}", "gray"), ENDIF,
  IF("BOMBQ"), LN(" Metodo: biseccion sobre Q (bomba de potencia P)", "gray"), ENDIF,
  IF("BOMB"), DAT("HB bomba", "HB", "m"), DAT("H = z1-z2+HB", "H", "m"), ENDIF,
  SEPx, WARNS)
local mB = prog(
  LN("MEMORIA  Caudal maximo (B)", "title"), SEPx,
  CALL("data"),
  IFN("BOMB"), DAT("H", "H", "m"), ENDIF,
  CALL("bomba"),
  IF("DIRECT"),
    SEC("CALCULOS"),
    EQ("v", "sqrt(2gH/(f L/D + SumK))", "sqrt(2({G})({H})/({F}({L}/{D})+{K}))", "V", "m/s"),
  ENDIF,
  IFN("DIRECT"),
    SEC("ITERACIONES"),
    IF("PHW"),
      LN("0 (Hazen-Williams): Q_HW tal que"),
      LN(" 10.675 L Q^1.852/(C_H^1.852 D^4.87) + SumK v^2/2g = H"),
      LN(" C_H = {CH0!}: Q_HW = {Q0LS!} l/s; hf1 = hf_HW = {HF1!} m", "gray"),
    ENDIF,
    IF("COURSE"),
      LN("v = -sqrt(8gD hf/L) log(ks/3.7D + 2.51 nu sqrt(L)/sqrt(2gD^3 hf))"),
      LN("hm = SumK v^2/2g;  hf(i+1) = H - hm"),
      IFN("PHW"), LN(" hf1 = H; parar si |dhf| <= {TOL!} m", "gray"), ENDIF,
      IF("PHW"), LN(" Fila 0 = Hazen-Williams; parar si |dhf| <= {TOL!} m", "gray"), ENDIF,
      TAB("course"),
    ENDIF,
    IF("PSEC"),
      LN("v = -sqrt(8gD hf/L) log(ks/3.7D + 2.51 nu sqrt(L)/sqrt(2gD^3 hf))"),
      LN("Secante sobre G(hf) = hf + SumK v^2/2g - H"),
      LN(" hf(1) = H - hm(0) (un paso del curso);", "gray"),
      LN(" luego hf+ = hf - G (hf - hf_ant)/(G - G_ant)", "gray"),
      IFN("PHW"), LN(" Fila 0: hf = H. Parar si |dhf| <= 1E-5 hf", "gray"), ENDIF,
      IF("PHW"), LN(" Fila 0 = Hazen-Williams. Parar si |dhf| <= 1E-5 hf", "gray"), ENDIF,
      TAB("bsec"),
    ENDIF,
    IF("BIS"),
      IF("FB"),
        IF("PREQ"), LN(" La secante no convergio (o Re < 2000).", "warn"), ENDIF,
        IFN("PREQ"), LN(" La iteracion del curso no convergio.", "warn"), ENDIF,
      ENDIF,
      LN("Biseccion: (f L/D + SumK) v^2/2g = H"),
      TAB("bis"),
    ENDIF,
    IF("BOMBQ"),
      LN("Q tal que hT(Q) = (z1 - z2) + eta P/(gamma Q)"),
      LN(" hT = (f L/D + SumK) v^2/2g; F = hT - (z1-z2) - HB", "gray"),
      LN(" Biseccion sobre Q (crece hT, baja HB):", "gray"),
      TAB("bq"),
    ENDIF,
    LN(" {ITER!} iteraciones", "gray"),
    SEC("CALCULOS CON v FINAL"),
  ENDIF,
  EQ("Q", "v A", "{V}({A})", "Q", "m3/s"),
  CALL("calc"),
  IF("BOMBQ"),
    EQ("HB", "eta P/(gamma Q)", "{BETA}({BPW})/({GAM}({Q}))", "HB", "m"),
    DAT("z1 - z2", "HZ", "m"),
    EQ("H", "(z1 - z2) + HB", "{HZ} + {HB}", "H", "m"),
  ENDIF,
  SEC("RESULTADOS"),
  RES("Q", "QLS", "l/s"), RES("v", "V", "m/s"),
  IF("BOMB"), RES("HB", "HB", "m"), ENDIF,
  LN(" Comprobacion: hf + hm = {HT} m (H = {H})", "gray"),
  CALL("obs"))

-- ---- C ----
local sC = prog(
  IF("PUMP"), LN("RESULTADO  Bomba", "title"), ENDIF,
  IFN("PUMP"), LN("RESULTADO  Turbina", "title"), ENDIF,
  SEPx, CALL("state"),
  IF("PUMP"),
    DAT("HB", "HMACH", "m"), DAT("Pn (agua)", "PNKW", "kW"),
    DAT("Pb (consume)", "PBKW", "kW"),
  ENDIF,
  IFN("PUMP"),
    DAT("HT", "HMACH", "m"), DAT("Pn (genera)", "PNKW", "kW"),
    DAT("Pb (agua)", "PBKW", "kW"),
  ENDIF,
  DAT("Pb", "PBHP", "Hp"),
  IF("ZB"), DAT("Cota piezometr.", "COTA", "m"), ENDIF,
  SEPx, WARNS)
local mC = prog(
  IF("PUMP"), LN("MEMORIA  Bomba (C)", "title"), ENDIF,
  IFN("PUMP"), LN("MEMORIA  Turbina (C)", "title"), ENDIF,
  SEPx, CALL("data"),
  IF("PUMP"), DAT("Hs (estatica)", "HS", "m"), ENDIF,
  IFN("PUMP"), DAT("Ha (disponible)", "HS", "m"), ENDIF,
  DAT("eta", "ETA"), DAT("gamma", "GAM", "N/m3"),
  SEC("CALCULOS"), CALL("calc"),
  IF("PUMP"),
    EQ("HB", "Hs + hT", "{HS} + {HT}", "HMACH", "m"),
    EQ("Pn", "gamma Q HB", "{GAM}({Q})({HMACH})", "PN", "W"),
    EQ("Pb", "Pn/eta", "{PN}/{ETA}", "PB", "W"),
  ENDIF,
  IFN("PUMP"),
    EQ("HT", "Ha - hT", "{HS} - {HT}", "HMACH", "m"),
    EQ("Pb", "gamma Q HT", "{GAM}({Q})({HMACH})", "PB", "W"),
    EQ("Pn", "eta Pb", "{ETA}({PB})", "PN", "W"),
  ENDIF,
  SEC("RESULTADOS"),
  IF("PUMP"), RES("HB", "HMACH", "m"), ENDIF,
  IFN("PUMP"), RES("HT", "HMACH", "m"), ENDIF,
  RES("Pn (neta)", "PNKW", "kW"), RES("Pb (bruta)", "PBKW", "kW"),
  RES("Pb", "PBHP", "Hp"),
  IF("ZB"),
    IF("PUMP"), EQ("Cota piez.", "z + HB", "{ZB} + {HMACH}", "COTA", "m"), ENDIF,
    IFN("PUMP"), EQ("Cota piez.", "z - HT", "{ZB} - {HMACH}", "COTA", "m"), ENDIF,
  ENDIF,
  LN(" Bruta = la mayor; neta = la menor (1 Hp = 745.7 W)", "gray"),
  CALL("obs"))

-- ---- D ----
local sD = prog(
  LN("RESULTADO  Diametro de diseno", "title"), SEPx,
  DAT("D exacto", "DEX", "mm"), DAT("D comercial", "DCOM", "mm"),
  DAT("Qmax con D com.", "QLS", "l/s"), DAT("v (Qmax)", "V", "m/s"),
  DAT("hf (Qmax)", "HF", "m"), DAT("hm (Qmax)", "HM", "m"),
  DAT("hm/hf", "HMHF", "%"),
  IF("VP"), DAT("vp", "VP", "m/s"), ENDIF,
  IF("VAL"), DAT("hv valvula (Qd)", "VALHV", "m"), DAT("Kv valvula", "VALKV"), ENDIF,
  IF("BOMB"), DAT("HB bomba", "HB", "m"), DAT("H = z1-z2+HB", "H", "m"), ENDIF,
  SEPx, WARNS)
local mD = prog(
  LN("MEMORIA  Diametro de diseno (D)", "title"), SEPx,
  CALL("data"), DAT("Qd", "QD", "m3/s"),
  IFN("BOMB"), DAT("H", "H", "m"), ENDIF,
  CALL("bomba"),
  SEC("DIAMETRO EXACTO"),
  LN("Se busca D tal que hT(Qd, D) = H"),
  IF("PSEC"),
    IF("PHW"),
      LN("0 (Hazen-Williams): D0 tal que"),
      LN(" 10.675 L Qd^1.852/(C_H^1.852 D^4.87) + SumK v^2/2g = H"),
      LN(" C_H = {CH0!}: D0 = {D0!} mm", "gray"),
    ENDIF,
    IFN("PHW"),
      LN("0: D0 con f = 0.02: (0.02 L/D + SumK) v^2/2g = H"),
      LN(" D0 = {D0!} mm", "gray"),
    ENDIF,
    LN("Secante con F = hT - H desde D0 y 1.02 D0:"),
    LN(" D+ = D - F (D - D_ant)/(F - F_ant)", "gray"),
    LN(" parar si |dD| <= 1E-5 D", "gray"),
    TAB("dsec"),
  ENDIF,
  IFN("PSEC"),
    IF("PDFB"), LN(" La secante no convergio: biseccion", "warn"), ENDIF,
    LN("(hT baja al crecer D: biseccion geometrica)", "gray"),
    TAB("D"),
  ENDIF,
  LN(" {ITER!} iteraciones", "gray"),
  RES("D exacto", "DEX", "mm"),
  LN(" Con D exacto: v = {EXV!}, Re = {EXRE!}, f = {EXF!}", "gray"),
  LN(" hf = {EXHF!}, hm = {EXHM!}, hT = {EXHT!} m", "gray"),
  SEC("DIAMETRO COMERCIAL"),
  LN(" Lista: {LISTNAME} (mm)", "gray"), DLIST,
  LN(" Menor diametro >= D exacto:"),
  RES("D comercial", "DCOM", "mm"),
  SEC("CAUDAL CON D COMERCIAL (tipo B)"),
  IF("COURSE"), LN(" Iteracion del curso", "gray"), ENDIF,
  IF("QSEC"), LN(" Secante (formula del curso)", "gray"), ENDIF,
  IFN("COURSE"), IFN("QSEC"), LN(" Biseccion sobre v", "gray"), ENDIF, ENDIF,
  CALL("calc"),
  RES("Qmax", "QLS", "l/s"),
  LN(" hm/hf = {HMHF!} %", "gray"),
  IF("VP"),
    EQ("vp", "sqrt(2g(H - hf)/SumK)", "sqrt(2({G})({H} - {HFCQ})/{K})", "VP", "m/s"),
    LN(" v con Qd = {VCQ!} m/s debe ser <= vp", "warn"),
  ENDIF,
  IF("VAL"),
    SEC("VALVULA DE CONTROL (Qd, D comercial)"),
    EQ("hT", nil, nil, "VALHT", "m"),
    EQ("hv", "H - hT", "{H} - {VALHT}", "VALHV", "m"),
    EQ("Kv", "2g hv/v^2", "2({G})({VALHV})/({VALV})^2", "VALKV"),
  ENDIF,
  CALL("obs"))

-- ---- F ----
local sF = prog(
  LN("RESULTADO  Valvula de control", "title"), SEPx,
  CALL("state"), DAT("hv", "HV", "m"), DAT("Kv", "KV"),
  SEPx, WARNS)
local mF = prog(
  LN("MEMORIA  Valvula de control (F)", "title"), SEPx,
  CALL("data"), DAT("H disponible", "H", "m"),
  SEC("CALCULOS"), CALL("calc"),
  EQ("hv", "H - hT", "{H} - {HT}", "HV", "m"),
  EQ("Kv", "2g hv/v^2", "2({G})({HV})/({V})^2", "KV"),
  SEC("RESULTADOS"), RES("hv", "HV", "m"), RES("Kv", "KV"),
  CALL("obs"))

-- ---- E ----
local sE = prog(
  LN("RESULTADO  Calibracion", "title"), SEPx,
  DAT("v", "V", "m/s"), DAT("Re", "RE"), DAT("hf + hm", "HTOT", "m"),
  DAT("hm", "HM", "m"), DAT("hf", "HF", "m"), DAT("f", "F"),
  DAT("ks", "KSMM", "mm"), DAT("ks/D", "KSD"),
  SEPx, WARNS)
local mE = prog(
  LN("MEMORIA  Calibracion (E)", "title"), SEPx,
  SEC("DATOS"),
  DAT("z1", "Z1", "m"), DAT("z2", "Z2", "m"),
  DAT("p1/gamma", "P1", "m"), DAT("p2/gamma", "P2", "m"),
  DAT("L", "L", "m"), DAT("D", "D", "m"), DAT("Q", "Q", "m3/s"),
  DAT("Suma K", "K"), DAT("nu", "NU", "m2/s"),
  SEC("CALCULOS"),
  EQ("A", "pi D^2/4", "pi({D})^2/4", "A", "m2"),
  EQ("v", "Q/A", "{Q}/{A}", "V", "m/s"),
  EQ("hf+hm", "(z1 - z2) + (p1 - p2)/gamma", "({Z1} - {Z2}) + ({P1} - {P2})", "HTOT", "m"),
  EQ("hm", "SumK v^2/2g", "{K}({V})^2/(2({G}))", "HM", "m"),
  EQ("hf", "(hf + hm) - hm", "{HTOT} - {HM}", "HF", "m"),
  EQ("f", "2g D hf/(L v^2)", "2({G})({D})({HF})/({L}({V})^2)", "F"),
  EQ("Re", "v D/nu", "{V}({D})/{NU}", "RE"),
  EQ("ks", "3.7D(10^(-1/(2 sqrt f)) - 2.51/(Re sqrt f))",
     "3.7({D})(10^(-1/(2({SF}))) - 2.51/({RE}({SF})))", "KS", "m"),
  SEC("RESULTADOS"), RES("f", "F"), RES("ks", "KSMM", "mm"),
  SEC("OBSERVACIONES"), WARNS)

-- ---- I ----
local sI = prog(
  LN("RESULTADO  Darcy-W. vs Hazen-W.", "title"), SEPx,
  IFN("MODEQ"),
    CALL("state"),
    DAT("hf Hazen-W.", "HW", "m"), DAT("Diferencia", "ERR", "%"),
    LN("   (HW - DW)/DW, solo friccion", "gray"),
  ENDIF,
  IF("MODEQ"),
    DAT("Q Darcy-W.", "QLS", "l/s"), DAT("Q Hazen-W.", "QHWLS", "l/s"),
    DAT("Diferencia", "ERR", "%"),
    LN("   (HW - DW)/DW; HW sin locales", "gray"),
  ENDIF,
  SEPx, WARNS)
local mI = prog(
  LN("MEMORIA  Darcy-W. vs Hazen-W. (I)", "title"), SEPx,
  CALL("data"), DAT("C_H", "CH"),
  IFN("MODEQ"),
    SEC("DARCY-WEISBACH"), CALL("calc"),
    SEC("HAZEN-WILLIAMS (sin locales)"),
    EQ("hf", "10.675 L Q^1.852/(C^1.852 D^4.87)",
       "10.675({L})({Q})^1.852/(({CH})^1.852({D})^4.87)", "HW", "m"),
    SEC("COMPARACION"),
    EQ("e", "(hf HW - hf DW)/hf DW", "({HW} - {HF})/{HF}", "ERR", "%"),
    LN(" Hazen-W. suele sobreestimar las perdidas", "gray"),
  ENDIF,
  IF("MODEQ"),
    DAT("H", "H", "m"),
    SEC("DARCY-WEISBACH (tipo B)"),
    IF("COURSE"), LN(" Iteracion del curso", "gray"), ENDIF,
    IFN("COURSE"), LN(" Biseccion sobre v", "gray"), ENDIF,
    CALL("calc"),
    RES("Q DW", "QLS", "l/s"),
    SEC("HAZEN-WILLIAMS (sin locales)"),
    EQ("Q", "(H C^1.852 D^4.87/(10.675 L))^(1/1.852)",
       "({H}({CH})^1.852({D})^4.87/(10.675({L})))^(1/1.852)", "QHW", "m3/s"),
    SEC("COMPARACION"),
    EQ("e", "(Q HW - Q DW)/Q DW", "({QHW} - {Q})/{Q}", "ERR", "%"),
  ENDIF,
  CALL("obs"))

local SUMS = {sA, sB, sD, sC, sF, sE, sI}
local MEMOS = {mA, mB, mD, mC, mF, mE, mI}

-- ---- Calcular f ----
local FTAB = prog(
  LN("Metodo           f          dif. CW", "title"),
  LN(" Colebrook-W.  {FCW}"),
  IF("OCW"), LN("   ! fuera de rango: ks/D > 0.05", "warn"), ENDIF,
  LN(" Swamee-Jain   {FSJ}  {DSJ!} %"),
  IF("OSJ"), LN("   ! fuera de rango (Re 4E3-1E8,", "warn"),
             LN("     ks/D 1E-6 a 1E-2)", "warn"), ENDIF,
  LN(" Haaland       {FHA}  {DHA!} %"),
  IF("OHA"), LN("   ! fuera de rango (Re 4E3-1E8)", "warn"), ENDIF,
  LN(" Goudar-Sonnad {FGO}  {DGO!} %"),
  IF("OGO"), LN("   ! fuera de rango (Re < 4000)", "warn"), ENDIF)

local FREG = prog(
  IF("LAM"), LN(" Re < Re lam: laminar, f = 64/Re", "warn"), ENDIF,
  IF("TRANS"), LN(" Re en transicion: f de CW indicativo", "warn"), ENDIF,
  IFN("LAM"), IFN("TRANS"), LN(" Re > Re turb: turbulento", "gray"), ENDIF,
    LN(" k+ = (ks/D) Re sqrt(f/8) = {KPLUS!}", "gray"),
    IF("ZSMOOTH"), LN(" Zona: hidraulicamente lisa (k+ < 5)", "gray"), ENDIF,
    IF("ZTRANS"), LN(" Zona: transicion (5 <= k+ <= 70)", "gray"), ENDIF,
    IF("ZROUGH"), LN(" Zona: rugosa, f casi no depende de Re", "gray"),
                  LN("   (k+ > 70)", "gray"), ENDIF,
  ENDIF)

local X_FRIC_SUM = prog(
  IF("FMODE2"), DAT("v", "V", "m/s"), ENDIF,
  DAT("Re", "RE"),
  DAT("ks/D", "KSD"),
  FREG,
  SEPx,
  LN("> f ({METHOD}) = {FSEL}", "ok"),
  DAT("1/sqrt(f)", "INVSF"),
  IFN("LAM"), SEPx, FTAB, ENDIF)

local X_FRIC_MEMO = prog(
  SEC("DATOS"),
  IF("FMODE2"),
    IFN("FHASV"), DAT("Q", "Q", "m3/s"), ENDIF,
    IF("FHASV"), DAT("v", "V", "m/s"), ENDIF,
    DAT("D", "D", "m"),
    DAT("ks", "KS", "m"),
    DAT("nu", "NU", "m2/s"),
  ENDIF,
  IFN("FMODE2"),
    DAT("Re", "RE"),
    IF("FKSDIN"), DAT("ks", "KSMM", "mm"), DAT("D", "DMM", "mm"), ENDIF,
    IFN("FKSDIN"), DAT("ks/D", "KSD"), ENDIF,
  ENDIF,
  LN(" Metodo de f (Ajustes): {METHOD}", "gray"),
  SEC("CALCULOS"),
  IF("FMODE2"),
    EQ("A", "pi D^2/4", "pi({D})^2/4", "A", "m2"),
    IFN("FHASV"), EQ("v", "Q/A", "{Q}/{A}", "V", "m/s"), ENDIF,
    EQ("Re", "v D/nu", "{V}({D})/{NU}", "RE"),
    EQ("ks/D", nil, "{KS}/{D}", "KSD"),
  ENDIF,
  IFN("FMODE2"), IF("FKSDIN"),
    EQ("ks/D", nil, "{KSMM}/{DMM}", "KSD"),
  ENDIF, ENDIF,
  FREG,
  IF("LAM"), EQ("f", "64/Re", "64/{RE}", "FSEL", "(laminar)"), ENDIF,
  IFN("LAM"),
    EQ("ks/3.7D", nil, "{KSD}/3.7", "A37"),
    IF("SJ"),
      EQ("f", "0.25/[log(ks/3.7D + 5.74/Re^0.9)]^2",
         "0.25/[log({A37} + 5.74/{RE}^0.9)]^2", "FSJ", "(Swamee-Jain)"),
    ENDIF,
    IF("HA"),
      EQ("1/sqrt(f)", "-1.8 log[(ks/3.7D)^1.11 + 6.9/Re]",
         "-1.8 log[({A37})^1.11 + 6.9/{RE}]", "INVSF"),
      RES("f (Haaland)", "FHA"),
    ENDIF,
    IF("GO"),
      LN("1/sqrt(f) = 0.8686 ln(0.4587 Re/(C-0.31)^(C/(C+1)))"),
      LN("C = 0.124 Re ks/D + ln(0.4587 Re)"),
      RES("f (Goudar-Sonnad)", "FGO"),
    ENDIF,
    SEC("ITERACIONES (COLEBROOK-WHITE)"),
    LN("1/sqrt(f) = -2 log(ks/3.7D + 2.51/(Re sqrt(f)))"),
    LN("      = -2 log({A37} + 2.51/({RE} sqrt(f)))", "gray"),
    LN(" Sustitucion sucesiva desde f1 = 0.0001", "gray"),
    TAB("cw"),
    LN(" Converge en {FIT!} iteraciones", "gray"),
    LN(" (|cambio de 1/sqrt f| < 1E-12 relativo)", "gray"),
    RES("f (Colebrook-White)", "FCW"),
  ENDIF,
  SEC("RESULTADO"),
  LN("> f ({METHOD}) = {FSEL}", "ok"),
  DAT("1/sqrt(f)", "INVSF"),
  SEC("COMPARACION Y AVISOS"),
  IFN("LAM"), FTAB, ENDIF,
  IF("LAM"), LN(" Laminar: f no depende de ks/D", "gray"), ENDIF,
  IF("TRANS"), LN("! Re en transicion: resultado indicativo", "warn"), ENDIF,
  IF("OCW"), LN("! ks/D > 0.05: fuera de Colebrook-White", "warn"), ENDIF)

-- ---- AYUDA ----
local AYUDA = {
  {"Uso y teclas", prog(
    LN("USO Y TECLAS", "title"), SEPx,
    TX(" enter   acepta y pasa al siguiente campo"),
    TX(" esc     vuelve a la pantalla anterior"),
    TX(" del     borra un caracter"),
    TX(" clear   vacia el campo"),
    TX(" flechas arriba/abajo mueven; izq./der."),
    TX("         cambian las opciones < >"),
    TX(" (-) signo;  EE = E (x10^)"),
    TX(" Tambien sirve el touchpad (clic)."),
    SEC("CAMPOS"),
    TX(" Aceptan cuentas: 0.5+4*1.1+3*0.3"),
    TX(" y potencias: 1.5*10^-6 o 1.5E-6"),
    TX(" Unidades: Q l/s, D mm, ks mm, L m,"),
    TX(" H y cotas m, presiones en m.c.a."),
    TX(" Los datos se conservan entre tipos."),
    TX(" Debajo de CALCULAR: Material, Suma K,"),
    TX(" Fluido, Calcular f y Ajustes."),
    SEC("RESULTADOS"),
    TX(" 1 (o tab) MEMORIA: calculo paso a paso"),
    TX(" 2 GRAFICO: lineas de energia (LE) y"),
    TX("    piezometrica (LP)"),
    TX(" 3 GUARDAR: guarda el caso (8 letras)"),
    TX(" Los casos y ajustes se guardan con el"),
    TX(" documento (guarde el .tns al salir)."))},
  {"Tipos de problema", prog(
    LN("TIPOS DE PROBLEMA", "title"), SEPx,
    TX("A Perdidas dado Q: v, Re, f, hf, hm."),
    TG("  Opcional: p/gamma en el punto final."),
    TX("B Caudal maximo dada la carga H."),
    TG("  Iteracion del curso; si no converge,"),
    TG("  biseccion sobre v (la memoria avisa)."),
    TG("  Opcional: secante y arranque desde"),
    TG("  Hazen-Williams (campo C_H arranque)."),
    TX("C Bomba o turbina: HB o HT y potencias"),
    TG("  Hs = z2 - z1 (bomba); Ha = z1 - z2"),
    TG("  (turbina); suma p/gamma si hay tanques"),
    TG("  presurizados."),
    TX("D Diametro exacto (biseccion o secante)"),
    TG("  y comercial (menor >= exacto); Qmax"),
    TG("  con el comercial; valvula opcional."),
    TG("  C_H arranque: secante desde Hazen-W."),
    TX("F Valvula: hv = H - hT; Kv = 2g hv/v^2."),
    TX("E Calibrar: f y ks con la caida medida."),
    TX("I Darcy-W. contra Hazen-Williams."),
    TX("G Sistemas: tubos por tramos (mismo"),
    TG("  tramo = paralelo; tramos en serie)."),
    TG("  Adelante: dada H. Atras: dado Q en un"),
    TG("  tubo se obtiene H y la presion."))},
  {"Formulas", prog(
    LN("FORMULAS", "title"), SEPx,
    TX("A = pi D^2/4;  v = Q/A;  Re = v D/nu"),
    TX("hf = f (L/D) v^2/2g  (Darcy-Weisbach)"),
    TX("hm = SumK v^2/2g;  hT = hf + hm"),
    SEC("FACTOR DE FRICCION"),
    TX("Re < 2000: f = 64/Re (laminar)"),
    TX("2000-4000: transicion (indicativo)"),
    TX("CW: 1/sqrt f = -2 log(ks/3.7D +"),
    TX("    2.51/(Re sqrt f))"),
    TX("SJ: f = 0.25/[log(ks/3.7D +"),
    TX("    5.74/Re^0.9)]^2"),
    TX("Haaland: 1/sqrt f = -1.8 log["),
    TX("    (ks/3.7D)^1.11 + 6.9/Re]"),
    SEC("HAZEN-WILLIAMS"),
    TX("hf = 10.675 L Q^1.852/(C^1.852 D^4.87)"),
    TG(" sin perdidas locales; agua fria"),
    SEC("MODULOS (sistemas)"),
    TX("M = 8/(pi^2 g)(f L/D^5 + SumK/D^4)"),
    TX("h = M Q^2; serie: M = suma de Mi"),
    TX("paralelo: M = (suma 1/sqrt Mi)^-2"),
    SEC("OTRAS"),
    TX("vp = sqrt(2g(H - hf)/SumK)"),
    TX("ks = 3.7D(10^(-1/(2 sqrt f)) -"),
    TX("     2.51/(Re sqrt f))"),
    TX("Expansion: K = (1 - A1/A2)^2 (con v1)"))},
  {"Potencia bruta y neta", prog(
    LN("POTENCIA BRUTA Y NETA", "title"), SEPx,
    TX("La bruta es la mayor y la neta la"),
    TX("menor (convencion de los examenes):"),
    SEC("BOMBA"),
    TX(" Pn = gamma Q HB  (la recibe el agua)"),
    TX(" Pb = Pn/eta      (la consume)"),
    SEC("TURBINA"),
    TX(" Pb = gamma Q HT  (la entrega el agua)"),
    TX(" Pn = eta Pb      (la que se genera)"),
    SEPx,
    TG(" 1 Hp = 745.7 W; gamma = 9810 N/m3"),
    TG(" por defecto (editable en Ajustes)."))},
  {"Suma K y fuentes de datos", prog(
    LN("SUMA K Y BIBLIOTECA", "title"), SEPx,
    TX("SumK suma los K de todos los"),
    TX("accesorios del tubo: cantidad x K."),
    TG("Se escribe a mano (acepta cuentas) o"),
    TG("con el boton Suma K del formulario."),
    TX("Notacion: hm = hL = hl; K = KL = km."),
    SEC("FUENTES DE LOS DATOS"),
    TX(" ks y C_H: tabla del curso"),
    TG("   (Perdidas-01.pdf, pags. 12 y 30)"),
    TX(" (C): Cengel; los K del curso pueden"),
    TX("   diferir del fabricante: editables"),
    TX(" Conjuntos de K: los ejercicios"),
    TG("   (PVC 200 mm, examenes 2017-2025)"),
    TX(" (std): agua a presion atmosferica,"),
    TG("   tabla estandar (no de los PDF)"),
    TX(" nu del curso: 1E-6, 1.007E-6,"),
    TX("   1.02E-6, 1.14E-6 y 1.17E-6"))},
  {"Advertencias", prog(
    LN("ADVERTENCIAS", "title"), SEPx,
    TX("! Re < 2000: laminar, f = 64/Re"),
    TX("! Re en transicion: resultado indicativo"),
    TX("! ks/D > 0.05: fuera de Colebrook-White"),
    TX("! Fuera del rango de Swamee-Jain"),
    TX("! v > 5 o v < 0.3 m/s (editable)"),
    TG("   criterio general, no del curso"),
    TX("! hm > 30% hf: perdidas locales altas"),
    TG("   en el diseno se muestra vp"),
    TX("! L/D > 4000: locales despreciables"),
    TG("   igual se suman (ajuste del curso)"),
    TX("! Presion manometrica negativa"),
    TX("! p/gamma < -10.3 m: imposible"),
    TX("! Iteracion del curso no convergio:"),
    TX("   se resolvio por biseccion"),
    TX("! ks negativo: datos inconsistentes"))},
  {"Erratas del material", prog(
    LN("ERRATAS DEL MATERIAL", "title"), SEPx,
    TX("Perdidas-01 p.34: usa D^4.87 aunque"),
    TX("  escribe 4.57 (19.32 m sale con 4.87)"),
    TX("PVC 200 mm: el enunciado dice 32 l/s;"),
    TX("  la solucion usa 72 l/s"),
    TX("Presentacion ej. 1: H = 43.5 m (hoja)"),
    TX("Presentacion ej. 2: ks = 2.0E-6 m"),
    TX("Presentacion ej. 4: L = 970 m (hoja) y"),
    TX("  gamma = 9801 (agua a 15 C)"),
    TX("2018 P1a: Q = 5.69 l/s, no 56.9;"),
    TX("  el manuscrito usa L = 2.06 m"),
    TX("2024 P3: QB = 23.53 l/s, no 20.53"),
    TX("2025 P1: con 285.75 mm, Q = 262.4"),
    TX("  l/s (la solucion uso 285.00 mm)"),
    TX("2024 y 2025: D exacto con Swamee-Jain"),
    TG("  (CW difiere 0.04 %: ver Ajustes)"))},
  {"Factor de friccion f", prog(
    LN("FACTOR DE FRICCION f", "title"), SEPx,
    TX("Menu > Calcular f (o Tuberia > f)."),
    TX("Modo: Re y ks/D directos, o datos"),
    TX("de tuberia (Q o v, D, ks, nu)."),
    TG("Re < 2000: laminar, f = 64/Re."),
    TG("2000 a 4000: transicion; CW indicativo."),
    TX("Metodos (campo Metodo de f):"),
    TX(" Colebrook-White: el del curso,"),
    TG("  implicito; sustitucion desde 0.0001."),
    TX(" Swamee-Jain: explicito, usado en las"),
    TG("  soluciones 2024-2025 (D exacto)."),
    TG("  Valido Re 5E3-1E8, ks/D 1E-6 a 1E-2."),
    TX(" Haaland (coef. 1.8 del curso) y"),
    TX(" Goudar-Sonnad: explicitos, para"),
    TG("  comparar (tabla del resultado)."),
    TX("Zona: k+ = (ks/D) Re sqrt(f/8);"),
    TG(" < 5 lisa, 5-70 transicion, > 70 rugosa"),
    TX("USAR f lleva el valor al formulario que"),
    TX("abrio la pantalla (boton Calcular f en"),
    TX("A, B, C, F y Sistemas)."))},
}

-- ---- interprete ----
local MV, MFL, MW, MLOG, MDL, MLISTNAME = {}, {}, {}, nil, nil, nil

function tpl(t)
  if not t then return nil end
  local r = t:gsub("{(%w+)(!?)}", function(n, b)
    if n == "METHOD" then return METODOS[metodo() + 1] end
    if n == "LISTNAME" then return MLISTNAME or "?" end
    if n == "TXT" then return MTXT or "" end
    local x = MV[n] or 0
    if INTK[n] then return fint(x) end
    return fmt3(x)
  end)
  return r
end

function run_prog(p, depth)
  if not p then return end
  local skip = 0
  for _, st in ipairs(p) do
    local op = st[1]
    if skip > 0 then
      if op == "if" or op == "ifn" then skip = skip + 1
      elseif op == "endif" then skip = skip - 1 end
    elseif op == "sec" then msec(st[2])
    elseif op == "sep" then vsep()
    elseif op == "dat" then
      if INTK[st[3]] then
        VW[#VW + 1] = {k = "v", l = st[2], v = fint(MV[st[3]]) .. (st[4] and (" " .. st[4]) or "")}
      else
        vval(st[2], MV[st[3]] or 0, st[4])
      end
    elseif op == "res" then mres(st[2], MV[st[3]] or 0, st[4])
    elseif op == "eq" then meq(st[2], st[3], tpl(st[4]), MV[st[5]] or 0, st[6])
    elseif op == "ln" then mline(tpl(st[2]), st[3])
    elseif op == "if" then if not MFL[st[2]] then skip = 1 end
    elseif op == "ifn" then if MFL[st[2]] then skip = 1 end
    elseif op == "call" then if depth < 3 then run_prog(SUBS[st[2]], depth + 1) end
    elseif op == "tab" then
      if st[2] == "hook" then
        if MHOOK then MHOOK() end
      else
        mtable(st[2], MLOG)
      end
    elseif op == "warns" then mwarn(MW)
    elseif op == "dlist" then
      local line = " "
      for _, d in ipairs(MDL or {}) do
        if #line > 30 then mline(line, "gray"); line = " " end
        line = line .. fmt_w(d * 1000, 7) .. " "
      end
      mline(line, "gray")
    end
  end
end

-- construye las lineas de un resultado (resumen o memoria)
function construir(res, memo)
  VW = {}
  if res.build then
    res.build(memo)
  else
    if res.V then
      for k, x in pairs(res.V) do
        if type(x) == "number" and not INTK[k] then res.V[k] = r3(x) end
      end
    end
    MV, MFL, MW, MLOG = res.V or {}, res.FL or {}, res.W or {}, res.log
    MDL, MLISTNAME = res.dlist, res.listname
    MTXT, MHOOK = res.txt, res.hook
    run_prog(memo and res.memo or res.sum, 0)
  end
  return VW
end

function ayuda_lineas(p)
  VW = {}
  MV, MFL, MW = {}, {}, {}
  run_prog(p, 0)
  return VW
end

-- =================== CALCULOS: TUBERIA SIMPLE ===================
local TITULOS = {"PERDIDAS DADO Q (A)", "CAUDAL MAXIMO (B)", "DIAMETRO DE DISENO (D)",
  "BOMBA O TURBINA (C)", "VALVULA DE CONTROL (F)", "CALIBRAR RUGOSIDAD (E)",
  "DARCY-W. vs HAZEN-W. (I)"}

-- lista propia de diametros (mm, hasta 15) y nombres de listas
local CUSTOM = {}
local nombresD = {}
for i, d in ipairs(DIAMETROS) do nombresD[i] = d[1] end
nombresD[#nombresD + 1] = "Lista propia"

function lista_diametros()
  local k = TOG.dset or 1
  local list = {}
  if k > #DIAMETROS then
    for _, d in ipairs(CUSTOM) do if d > 0 then list[#list + 1] = rmm(d / 1000) end end
    if #list == 0 then herr("Lista propia vacia (Biblioteca)") end
    table.sort(list)
    return list, "Lista propia"
  end
  for i, d in ipairs(DIAMETROS[k][2]) do list[i] = rmm(d / 1000) end
  return list, DIAMETROS[k][1]
end

function pipe_compute(tipo, v)
  NU = v.nu or CFG.nu
  local P = {D = rmm((v.D or 0) / 1000), L = v.L or 0, ks = r3((v.ks or 0) / 1000),
             K = v.K or 0, ff = v.f or 0}
  local o = {CH = v.CH0}
  local lg = {}
  local V, FL, Wr = {}, {}, {}
  local res = {V = V, FL = FL, W = Wr, log = lg, tipo = tipo, guardar = tipo,
               titulo = TITULOS[tipo], sum = SUMS[tipo], memo = MEMOS[tipo]}
  local s, D = nil, P.D
  local X = {}
  local modeQ = (TOG.modeI or 1) == 2
  local bomb = (tipo <= 3) and bomba_activa()
  local HB, Hef = 0, v.H
  if tipo == 1 then
    s = pipe_state(P, rls(v.Q / 1000))
    if bomb then HB = carga_bomba(v, s.Q) end
    if v.Hp then X.ph = pressure_head(v.Hp, HB, s.v, s.hT, s.warn) end
  elseif tipo == 2 then
    o.secant = (TOG.itB or 1) == 2
    if bomb and bomba_potencia() then
      X.q, HB = qmax_bomba(P, v.H, v, lg)
      Hef = r3(v.H + HB)
    else
      if bomb then HB = carga_bomba(v, 1) end
      Hef = r3(v.H + HB)
      X.q = qmax(P, Hef, o, lg)
    end
    s = X.q.st
  elseif tipo == 3 then
    P.ff = 0
    o.secant = (TOG.itD or 1) == 2
    local list, name = lista_diametros()
    if bomb then HB = carga_bomba(v, rls(v.Q / 1000)) end
    Hef = r3(v.H + HB)
    X.d = design(P, rls(v.Q / 1000), Hef, list, o, lg)
    res.dlist, res.listname = list, name
    if (TOG.valve or 1) == 2 then
      local pv = copypipe(P)
      pv.D = X.d.D_com
      X.val = valve(pv, rls(v.Q / 1000), Hef)
    end
    s = X.d.qmax.st
    D = X.d.D_com
  elseif tipo == 4 then
    if (TOG.mach or 1) == 1 then X.m = pump(P, rls(v.Q / 1000), v.Hs, v.eta)
    else X.m = turbine(P, rls(v.Q / 1000), v.Hs, v.eta) end
    s = X.m.st
  elseif tipo == 5 then
    X.v = valve(P, rls(v.Q / 1000), v.H)
    if X.v.hv < 0 then herr(ERR.HV) end
    s = X.v.st
  elseif tipo == 6 then
    P.ff = 0
    X.k = calibrate(rmm(v.D / 1000), v.L, rls(v.Q / 1000), P.K, r3(v.z1 - v.z2), r3(v.p1 - v.p2))
  else
    P.ff = 0
    if not (v.CH and v.CH >= 1 and v.CH <= 200) then herr("C_H debe estar entre 1 y 200") end
    if not modeQ then
      if not v.Q then herr("Falta Q (modo hf)") end
      s = pipe_state(P, rls(v.Q / 1000))
      X.hw = hw_hf(v.Q / 1000, P.D, P.L, v.CH)
      X.err = 100 * (X.hw - s.hf) / s.hf
    else
      if not v.H then herr("Falta H (modo Q)") end
      X.q = qmax(P, v.H, nil, lg)
      s = X.q.st
      X.Qhw = hw_q(v.H, P.D, P.L, v.CH)
      X.err = 100 * (X.Qhw - s.Q) / s.Q
    end
  end

  -- valores de la memoria (fill_values)
  V.D, V.L, V.KS, V.K = D, P.L, P.ks, P.K
  V.NU, V.G, V.GAM, V.TOL = NU, CFG.g, CFG.gamma, CFG.tol
  V.H, V.QD, V.KSMM = v.H or 0, rls((v.Q or 0) / 1000), P.ks * 1000
  if bomb then
    FL.BOMB = true
    FL.BOMBP = bomba_potencia()
    V.HB = HB
    V.BP, V.BPW, V.BETA = v.bP or 0, (v.bP or 0) * 1000, v.bEta or 0
    if tipo == 2 or tipo == 3 then
      FL.HEFF = true
      V.HZ = v.H
      V.H = Hef
    end
  end
  if s then
    V.Q, V.QLS, V.A, V.V = s.Q, s.Q * 1000, s.A, s.v
    V.RE, V.KSD, V.F = s.Re, s.ksD, s.f
    V.INVSF, V.HV2G = 1 / sqrt(s.f), s.hv2g
    V.HF, V.HM, V.HT, V.LD = s.hf, s.hm, s.hT, s.LD
    V.HMHF = (s.hf > 0) and (100 * s.hm / s.hf) or 0
    V.FIT = s.f_iters
    V.A37 = (D > 0) and (P.ks / (3.7 * D)) or 0
    for k, x in pairs(s.warn) do Wr[k] = x end
    FL.LAM = s.regime == LAM
    FL.TRANS = s.regime == TRANS
  end
  local m = metodo()
  FL.FIX = P.ff > 0
  FL.CW, FL.SJ, FL.HA, FL.GO = m == 0, m == 1, m == 2, m == 3
  FL.KPOS = P.K > 0
  FL.WITHQ = tipo == 1 or tipo == 4 or tipo == 5 or (tipo == 7 and not modeQ)
  FL.HASD = tipo ~= 3
  if tipo == 1 then
    V.HP = v.Hp or 0
    V.PH = X.ph or 0
    V.PKPA = (X.ph or 0) * CFG.gamma / 1000
    FL.HP = v.Hp ~= nil
  elseif tipo == 2 or (tipo == 7 and modeQ) then
    local q = X.q
    V.ITER = q.iters
    FL.COURSE = q.solver == "course"
    FL.BIS = q.solver == "bis"
    FL.DIRECT = q.solver == "direct"
    FL.FB = q.st.warn.fb and true or false
    FL.PSEC = q.solver == "sec"
    FL.PREQ = tipo == 2 and (TOG.itB or 1) == 2
    FL.BOMBQ = q.solver == "bomba"
    FL.PHW = q.hw
    V.CH0 = v.CH0 or 0
    V.HF1 = q.hf1
    V.Q0LS = q.Q0 * 1000
  end
  V.QB = (tipo == 3) and V.QD or (s and s.Q or 0)
  if tipo == 7 then
    V.CH = v.CH
    V.HW = X.hw or 0
    V.ERR = X.err
    V.QHW = X.Qhw or 0
    V.QHWLS = (X.Qhw or 0) * 1000
    FL.MODEQ = modeQ
  elseif tipo == 4 then
    local mm = X.m
    local bomba = (TOG.mach or 1) == 1
    V.HS, V.ETA, V.HMACH = v.Hs, v.eta, mm.Hm
    V.PN, V.PB = mm.Pn, mm.Pb
    V.PNKW, V.PBKW, V.PBHP = mm.Pn / 1000, mm.Pb / 1000, mm.Pb / 745.7
    V.ZB = v.zb or 0
    V.COTA = (v.zb or 0) + (bomba and mm.Hm or -mm.Hm)
    FL.PUMP = bomba
    FL.ZB = v.zb ~= nil
  elseif tipo == 5 then
    V.HV, V.KV = X.v.hv, X.v.Kv
  elseif tipo == 3 then
    local d = X.d
    V.ITER = d.iters
    V.DEX, V.DCOM, V.VP = d.D_exact * 1000, d.D_com * 1000, d.vp
    V.HFCQ, V.VCQ = d.st_com.hf, d.st_com.v
    if d.st_exact then
      V.EXV, V.EXRE, V.EXF = d.st_exact.v, d.st_exact.Re, d.st_exact.f
      V.EXHF, V.EXHM, V.EXHT = d.st_exact.hf, d.st_exact.hm, d.st_exact.hT
    end
    if X.val then
      V.VALHT, V.VALHV, V.VALKV, V.VALV = X.val.st.hT, X.val.hv, X.val.Kv, X.val.st.v
      if X.val.hv < 0 then Wr.hneg = true end
    end
    for k, x in pairs(d.warn) do Wr[k] = x end
    FL.COURSE = d.qmax.solver == "course"
    FL.QSEC = d.qmax.solver == "sec"
    FL.PSEC = d.solver == "sec"
    FL.PHW = d.hw
    FL.PDFB = d.fb
    V.CH0 = v.CH0 or 0
    V.D0 = d.D0 * 1000
    FL.VP = d.vp > 0
    FL.VAL = X.val ~= nil
  elseif tipo == 6 then
    local k = X.k
    V.D, V.Q = rmm(v.D / 1000), rls(v.Q / 1000)
    V.Z1, V.Z2, V.P1, V.P2 = v.z1, v.z2, v.p1, v.p2
    V.A, V.V, V.HTOT, V.HM, V.HF = k.A, k.v, k.htot, k.hm, k.hf
    V.F, V.RE, V.SF = k.f, k.Re, sqrt(k.f)
    V.KS, V.KSMM, V.KSD = k.ks, k.ks * 1000, k.ksD
    for kk, x in pairs(k.warn) do Wr[kk] = x end
  end

  -- grafica de LE y LP (pipe_graph)
  if s and tipo <= 5 then
    local segs = {{L = P.L, hloc = s.hm, hfr = s.hf, vh = s.hv2g, jump = 0, name = "L"}}
    local E0, Eend, tank2 = 0, 0, true
    if tipo == 1 then
      E0 = v.Hp or r3(s.hT - HB)
      tank2 = false
    elseif tipo == 2 or tipo == 3 then
      E0 = v.H
    elseif tipo == 4 then
      if (TOG.mach or 1) == 1 then
        E0 = 0
        segs[1].jump = X.m.Hm
        Eend = v.Hs
      else
        E0 = v.Hs
        segs[2] = {L = 0, hloc = 0, hfr = 0, jump = -X.m.Hm, vh = s.hv2g, name = "T"}
      end
    elseif tipo == 5 then
      E0 = v.H
      segs[2] = {L = 0, hloc = 0, hfr = 0, jump = -X.v.hv, vh = s.hv2g, name = "V"}
    end
    if bomb then segs[1].jump = segs[1].jump + HB end
    res.graph = {E0 = E0, segs = segs, Eend = Eend, tank2 = tank2}
  end
  return res
end

-- =================== CALCULAR f (scr_fric.c) ===================
function fric_compute(v)
  local V, FL = {}, {}
  local Re, ksd, D, ks, A, vel, Q = 0, 0, 0, 0, 0, 0, 0
  local ksdin, hasv = false, false
  local nu = CFG.nu
  local modo2 = (TOG.fmode or 1) == 2
  if not modo2 then
    Re = r3(v.Re)
    if v.ksD then ksd = r3(v.ksD)
    elseif v.ks1 and v.D1 then ksd = r3(v.ks1 / v.D1); ksdin = true
    else herr("Falta ks/D (o ks y D)") end
  else
    D = rmm(v.D / 1000)
    ks = r3(v.ks / 1000)
    nu = v.nu
    A = area(D)
    if v.V then vel = r3(v.V); Q = r3(vel * A); hasv = true
    elseif v.Q then Q = rls(v.Q / 1000); vel = r3(Q / A)
    else herr("Falta Q o v") end
    Re = r3(vel * D / nu)
    ksd = r3(ks / D)
  end
  local lg = {}
  local t = fric_all(Re, ksd, lg)
  local m = metodo()
  local fs = t.f[m + 1]
  V.RE, V.KSD, V.A37 = Re, ksd, ksd / 3.7
  V.FCW, V.FSJ, V.FHA, V.FGO = t.f[1], t.f[2], t.f[3], t.f[4]
  V.DSJ, V.DHA, V.DGO = t.dpct[2], t.dpct[3], t.dpct[4]
  V.FSEL, V.INVSF, V.FIT = fs, 1 / sqrt(fs), t.iters
  local kp = ksd * Re * sqrt(t.f[1] / 8)
  V.KPLUS = kp
  V.D, V.KS, V.NU, V.Q, V.QLS, V.A, V.V = D, ks, nu, Q, Q * 1000, A, vel
  V.KSMM, V.DMM = v.ks1 or 0, v.D1 or 0
  FL.FMODE2, FL.FHASV, FL.FKSDIN = modo2, hasv, ksdin
  FL.LAM, FL.TRANS = t.regime == LAM, t.regime == TRANS
  FL.CW, FL.SJ, FL.HA, FL.GO = m == 0, m == 1, m == 2, m == 3
  FL.ZSMOOTH, FL.ZTRANS, FL.ZROUGH = kp < 5, kp >= 5 and kp <= 70, kp > 70
  FL.OCW, FL.OSJ, FL.OHA, FL.OGO = t.out[1], t.out[2], t.out[3], t.out[4]
  return {V = V, FL = FL, W = {}, log = lg, sum = X_FRIC_SUM, memo = X_FRIC_MEMO,
          titulo = "FACTOR DE FRICCION f", fsel = fs, guardar = 8}
end

-- =================== SISTEMAS (scr_net.c) ===================
local LETRA = {"A", "B", "C", "D", "E", "F", "G", "H"}

function npipes()
  local s = MEM.np and table.concat(MEM.np) or ""
  local n = tonumber(s) or 1
  n = floor(n)
  if n < 1 then n = 1 end
  if n > 8 then n = 8 end
  return n
end

function net_compute(v)
  NU = v.nu or CFG.nu
  local np = npipes()
  for i = 1, np do
    if not v["nf" .. i] and not v["nks" .. i] then herr("Cada tubo necesita f o ks") end
    if v["ntr" .. i] < 1 or v["ntr" .. i] > 8 then herr("Tramo de " .. LETRA[i] .. ": 1 a 8") end
  end
  local tv = {}
  for i = 1, np do
    local x = v["ntr" .. i]
    local found = false
    for _, y in ipairs(tv) do if y == x then found = true end end
    if not found then tv[#tv + 1] = x end
  end
  table.sort(tv)
  local net = net_new()
  local pnode, trof = {}, {}
  for i = 1, np do
    pnode[i] = net_add_pipe(net, v["nL" .. i], rmm(v["nD" .. i] / 1000), v["nf" .. i] or 0,
                            r3((v["nks" .. i] or 0) / 1000), v["nK" .. i] or 0)
    for t, y in ipairs(tv) do if y == v["ntr" .. i] then trof[i] = t end end
  end
  local trnode = {}
  for t = 1, #tv do
    local kids = {}
    for i = 1, np do if trof[i] == t then kids[#kids + 1] = pnode[i] end end
    if #kids == 1 then trnode[t] = kids[1]
    else trnode[t] = net_add_group(net, "par", kids) end
  end
  if #tv > 1 then
    local roots = {}
    for t = 1, #tv do roots[t] = trnode[t] end
    net_add_group(net, "ser", roots)
  else
    net.root = trnode[1]
  end
  local atras = (TOG.nmode or 1) == 2
  local Htot, kp
  local bomb = bomba_activa()
  local HB, H0 = 0, 0
  local blog = {}
  if not atras then
    if not v.nH then herr("Falta la carga H") end
    H0 = v.nH
    if bomb and bomba_potencia() then
      -- Q total tal que Q = Q_red(H + eta P/(gamma Q))
      local function Qred(h)
        if not (h > 0) then return 0 end
        net_solve(net, h)
        return net.nodes[net.root].Q
      end
      local function gq(Q) return r3(Qred(r3(H0 + carga_bomba(v, Q))) - Q) end
      local lo, hi, it = 1e-6, 0.01, 0
      while gq(hi) > 0 do
        lo = hi
        hi = hi * 2
        it = it + 1
        if it > 60 then herr(ERR.NOROOT) end
      end
      for i = 1, 200 do
        local mid = rls(0.5 * (lo + hi))
        local g = gq(mid)
        blog[#blog + 1] = {i, lo * 1000, hi * 1000, mid * 1000, g}
        if g == 0 then lo, hi = mid, mid; break end
        if g > 0 then lo = mid else hi = mid end
        local nm = rls(0.5 * (lo + hi))
        if g == 0 or nm == lo or nm == hi then break end
      end
      HB = carga_bomba(v, rls(0.5 * (lo + hi)))
    elseif bomb then
      HB = carga_bomba(v, 1)
    end
    Htot = r3(H0 + HB)
    net_solve(net, Htot)
  else
    if not v.nkp or not v.nQk then herr("Falta el tubo conocido y su Q") end
    kp = floor(v.nkp)
    if kp < 1 or kp > np then herr("Ese tubo no existe") end
    Htot = net_solve_back(net, pnode[kp], rls(v.nQk / 1000))
    if bomb then HB = carga_bomba(v, net.nodes[net.root].Q) end
    H0 = r3(Htot - HB)
  end
  local res = {titulo = "SISTEMA SERIE/PARALELO"}
  local root = net.nodes[net.root]
  local function vel(i)
    local nd = net.nodes[pnode[i]]
    return nd.Q / area(nd.pipe.D)
  end
  local function pipe_lines()
    for i = 1, np do
      local nd = net.nodes[pnode[i]]
      vadd(" " .. LETRA[i] .. " (tramo " .. trof[i] .. ")  M = " .. fw(nd.M, 9), "fg")
      vadd("   Q " .. fw(1000 * nd.Q) .. " l/s  h " .. fw(nd.h) .. " m  v " .. fw(vel(i), 6), "gray")
    end
  end
  res.build = function(memo)
    if not memo then
      vadd("RESULTADO  Sistema serie/paralelo", "title")
      vsep()
      vval("Q total", 1000 * root.Q, "l/s")
      if bomb then
        vval("HB bomba", HB, "m")
        vval(atras and "z1-z2 necesaria" or "z1 - z2", H0, "m")
        vval("H = z1-z2+HB", Htot, "m")
      else
        vval(atras and "H necesaria" or "H", Htot, "m")
      end
      if atras then vval("H en kPa", H0 * CFG.gamma / 1000, "kPa") end
      vval("M total", root.M)
      vsep()
      pipe_lines()
      vsep()
      vadd(" Comprobacion: sum Q " .. fw(net.res_q * 1000) .. ", sum h " .. fw(net.res_h), "gray")
      return
    end
    local k0 = module_coef()
    vadd("MEMORIA  Sistema serie/paralelo", "title")
    vsep()
    msec("DATOS")
    for i = 1, np do
      local nd = net.nodes[pnode[i]]
      mline(" " .. LETRA[i] .. ": tramo " .. trof[i] .. ", L = " .. fv(v["nL" .. i]) ..
            " m, D = " .. fv(v["nD" .. i] / 1000) .. " m", "fg")
      if v["nf" .. i] then
        mline("    f = " .. fv(v["nf" .. i]) .. " (dato), SumK = " .. fv(v["nK" .. i] or 0), "gray")
      else
        mline("    ks = " .. fv(r3((v["nks" .. i] or 0) / 1000)) .. " m, SumK = " ..
              fv(v["nK" .. i] or 0) .. "; f auto = " .. fv(nd.f), "gray")
      end
    end
    if not atras then mline(" H = " .. fv(v.nH) .. " m", "fg")
    else mline(" Q conocido en " .. LETRA[kp] .. " = " .. fv(v.nQk) .. " l/s", "fg") end
    msec("MODULOS DE CAUDAL (h = M Q^2)")
    mline("M = 8/(pi^2 g) (f L/D^5 + SumK/D^4)", "fg")
    meq("8/(pi^2 g)", nil, "8/(pi^2 (" .. fv(CFG.g) .. "))", k0, nil)
    for i = 1, np do
      local nd = net.nodes[pnode[i]]
      meq("M_" .. LETRA[i], nil, fv(k0) .. "(" .. fv(nd.f) .. "(" .. fv(nd.pipe.L) .. ")/(" ..
          fv(nd.pipe.D) .. ")^5 + " .. fv(nd.pipe.K) .. "/(" .. fv(nd.pipe.D) .. ")^4)", nd.M, nil)
      if nd.Mk > 0 then
        mline("      (friccion " .. fw(nd.Mf, 9) .. " + local " .. fw(nd.Mk) .. ")", "gray")
      end
    end
    msec("REDUCCION DEL SISTEMA")
    for t = 1, #tv do
      local g = net.nodes[trnode[t]]
      if g.type == "par" then
        local b = ""
        for i = 1, np do
          if trof[i] == t then
            if b ~= "" then b = b .. " + " end
            b = b .. "1/sqrt(" .. fw(net.nodes[pnode[i]].M, 9) .. ")"
          end
        end
        mline("M tramo " .. t .. " (paralelo)", "fg")
        meq("  ", nil, "(" .. b .. ")^-2", g.M, nil)
      end
    end
    if #tv > 1 then
      local b = ""
      for t = 1, #tv do
        if t > 1 then b = b .. " + " end
        b = b .. fw(net.nodes[trnode[t]].M, 9)
      end
      mline("M total = suma de tramos en serie", "fg")
      meq("M", nil, b, root.M, nil)
    end
    msec("CAUDAL Y CARGA")
    if bomb then
      mline(" Bomba: (z1 - z2) + HB = M Q^2", "gray")
      if bomba_potencia() then
        mline(" HB = eta P/(gamma Q); P = " .. fv(v.bP) .. " kW, eta = " .. fv(v.bEta), "gray")
        if not atras then
          mline(" Q total por biseccion: Q = sqrt((z1-z2 + HB(Q))/M)", "gray")
          vrow({"i", "Q min", "Q max", "Q l/s", "F"}, "title", XS5)
          for _, rw in ipairs(blog) do
            vrow({fmt("%d", rw[1]), fw(rw[2]), fw(rw[3]), fw(rw[4]), fw(rw[5])}, "fg", XS5)
          end
        end
        meq("HB", "eta P/(gamma Q)", fv(v.bEta) .. "(" .. fv(v.bP * 1000) .. ")/(" ..
            fv(CFG.gamma) .. "(" .. fv(root.Q) .. "))", HB, "m")
      else
        vval("HB (dato)", HB, "m")
      end
    end
    if not atras then
      if bomb then meq("H", "(z1 - z2) + HB", fv(H0) .. " + " .. fv(HB), Htot, "m") end
      meq("Q", "sqrt(H/M)", "sqrt(" .. fv(Htot) .. "/" .. fv(root.M) .. ")", root.Q, "m3/s")
    else
      mline(" Con el Q conocido se sube por el arbol:", "gray")
      mline(" h = M Q^2 en el tubo; en un paralelo", "gray")
      mline(" Qi = sqrt(h/Mi); en serie h se suma.", "gray")
      meq("Q", nil, nil, root.Q, "m3/s")
      meq("H", "M Q^2", fv(root.M) .. "(" .. fv(root.Q) .. ")^2", Htot, "m")
      if bomb then meq("z1 - z2", "H - HB", fv(Htot) .. " - " .. fv(HB), H0, "m") end
      mres("p = gamma (z1 - z2)", H0 * CFG.gamma / 1000, "kPa")
    end
    msec("REPARTO")
    for t = 1, #tv do
      local g = net.nodes[trnode[t]]
      meq("h tramo " .. t, "M Q^2", fv(g.M) .. "(" .. fv(g.Q) .. ")^2", g.h, "m")
      if g.type == "par" then
        for i = 1, np do
          if trof[i] == t then
            local nd = net.nodes[pnode[i]]
            meq("Q_" .. LETRA[i], "sqrt(h/M)", "sqrt(" .. fv(g.h) .. "/" .. fv(nd.M) .. ")", nd.Q, "m3/s")
          end
        end
      end
    end
    msec("RESULTADOS")
    pipe_lines()
    if net.outer > 1 then
      mline(" f automatico: " .. net.outer .. " vueltas de Colebrook-W.", "gray")
    end
    msec("OBSERVACIONES")
    mline(" Nudos: |Q - sum Qi| max = " .. fw(net.res_q * 1000) .. " l/s", "gray")
    mline(" Rutas: |h - sum hi| max = " .. fw(net.res_h) .. " m", "gray")
  end
  -- grafica: la ruta pasa por el tubo de mayor caudal de cada tramo
  local segs = {}
  for t = 1, #tv do
    local g = net.nodes[trnode[t]]
    local best
    for i = 1, np do
      if trof[i] == t and (best == nil or net.nodes[pnode[i]].Q > net.nodes[pnode[best]].Q) then
        best = i
      end
    end
    local nd = net.nodes[pnode[best]]
    local hloc = (nd.M > 0) and (g.h * nd.Mk / nd.M) or 0
    segs[t] = {L = nd.pipe.L, hloc = hloc, hfr = g.h - hloc, jump = 0,
               vh = vel(best) * vel(best) / (2 * CFG.g),
               name = LETRA[best] .. ((g.type == "par") and "+" or "")}
  end
  if bomb and segs[1] then segs[1].jump = HB end
  local E0 = v.nz1 or H0
  if not bomb then E0 = v.nz1 or Htot end
  res.graph = {E0 = E0, segs = segs, Eend = E0 - (bomb and H0 or Htot), tank2 = true}
  res.gtitulo = "SISTEMA: LE y LP"
  res.net, res.Htot = net, Htot
  return res
end

-- ============================ CAMPOS ============================
-- F(clave, etiqueta, defecto, placeholder, cond, opciones, valor_cond)
-- defecto nil = obligatorio; "" = opcional (vacio = no se usa)
function F(k, lab, d, p, cond, opts, cv)
  return {k = k, l = lab, d = d, p = p, c = cond, o = opts, cv = cv}
end
function dnu() return CFG.nu end
function pnu() return ng(CFG.nu) end

local fQ   = F("Q", "Caudal Q [l/s]")
local fD   = F("D", "Diametro D [mm]")
local fL   = F("L", "Longitud L [m]")
local fks  = F("ks", "Rugosidad ks [mm]")
local fK   = F("K", "Suma K", 0, "0")
local fnu  = F("nu", "Viscosidad [m2/s]", dnu, pnu)
local ff   = F("f", "f dado (opc.)", "", "calcular")
local fmet = F("met", "Metodo de f", nil, nil, nil, METODOS)
local fCH0 = F("CH0", "C_H arranque (opc)", "", "no")
local fH   = F("H", "Carga H [m]")

-- ---- bomba en la linea (A, B, D, G y programa original) ----
-- z1 - z2 + HB = perdidas; HB dada o HB = eta P/(gamma Q)
function campos_bomba()
  local a = F("bom", "Bomba en la linea", nil, nil, nil, {"No", "Si"})
  local b = F("bdato", "Dato de la bomba", nil, nil, "bom", {"Potencia P", "Carga HB"}, 2)
  local c = F("bP", "Potencia bomba [kW]", nil, nil, "bdato", nil, 1)
  c.c2, c.cv2 = "bom", 2
  local d = F("bEta", "Eficiencia bomba (0-1)", nil, nil, "bdato", nil, 1)
  d.c2, d.cv2 = "bom", 2
  local e = F("bHB", "Carga HB [m]", nil, nil, "bdato", nil, 2)
  e.c2, e.cv2 = "bom", 2
  return {a, b, c, d, e}
end
function con_bomba(fs)
  local r = {}
  for _, f in ipairs(fs) do r[#r + 1] = f end
  for _, f in ipairs(campos_bomba()) do r[#r + 1] = f end
  return r
end
function bomba_activa() return (TOG.bom or 1) == 2 end
function bomba_potencia() return bomba_activa() and (TOG.bdato or 1) == 1 end
-- carga de la bomba con el caudal Q (m3/s)
function carga_bomba(v, Q)
  if not bomba_activa() then return 0 end
  if bomba_potencia() then
    if not (v.bP and v.bP > 0) then herr("Falta la potencia P de la bomba") end
    if not (v.bEta and v.bEta > 0 and v.bEta <= 1) then herr("Eficiencia de la bomba: 0 a 1") end
    return r3(v.bEta * v.bP * 1000 / (CFG.gamma * Q))
  end
  if v.bHB == nil then herr("Falta la carga HB de la bomba") end
  return r3(v.bHB)
end
-- caudal con bomba de potencia dada: hT(Q) = H0 + eta P/(gamma Q) (biseccion)
function qmax_bomba(P, H0, v, lg)
  local function Fq(Q)
    local st = pipe_state(P, Q)
    local hb = carga_bomba(v, Q)
    return r3(st.hT - (H0 + hb)), st, hb
  end
  local lo, hi, it = 1e-6, 0.01, 0
  while Fq(hi) < 0 do
    lo = hi
    hi = hi * 2
    it = it + 1
    if it > 60 then herr(ERR.NOROOT) end
  end
  logclear(lg)
  local n = 0
  for i = 1, 200 do
    n = i
    local mid = rls(0.5 * (lo + hi))
    local g = Fq(mid)
    logrow(lg, i, lo * 1000, hi * 1000, mid * 1000, g)
    if g == 0 then lo, hi = mid, mid; break end
    if g > 0 then hi = mid else lo = mid end
    local nm = rls(0.5 * (lo + hi))
    if g == 0 or nm == lo or nm == hi then break end
  end
  local Q = rls(0.5 * (lo + hi))
  local st = pipe_state(P, Q)
  return {st = st, iters = n, solver = "bomba", hw = false, hf1 = 0, Q0 = 0,
          course_ok = false}, carga_bomba(v, Q)
end

local TIPOS = {
  {"A  Perdidas dado Q", con_bomba({fQ, fD, fL, fks, fK, fnu, ff,
     F("Hp", "H sobre punto (opc)", "", "no"), fmet})},
  {"B  Caudal maximo", con_bomba({F("H", "Carga H = z1-z2 [m]"), fD, fL, fks, fK, fnu, ff, fmet, fCH0,
     F("itB", "Iteracion", nil, nil, nil, {"Curso", "Secante"})})},
  {"D  Diametro de diseno", con_bomba({F("Q", "Caudal diseno Qd [l/s]"),
     F("H", "Carga H = z1-z2 [m]"), fL, fks, fK, fnu,
     F("dset", "Lista diametros", nil, nil, nil, nombresD),
     F("valve", "Valvula control", nil, nil, nil, {"No", "Si"}), fmet, fCH0,
     F("itD", "Iteracion", nil, nil, nil, {"Biseccion", "Secante"})})},
  {"C  Bomba o turbina", {F("mach", "Equipo", nil, nil, nil, {"Bomba", "Turbina"}),
     fQ, fD, fL, fks, fK, fnu, F("Hs", "Desnivel Hs/Ha [m]"),
     F("eta", "Eficiencia (0-1)"), ff,
     F("zb", "Cota equipo (opc)", "", "no"), fmet}},
  {"F  Valvula de control", {fQ, fD, fL, fks, fK, fnu, fH, ff, fmet}},
  {"E  Calibrar rugosidad", {F("z1", "Cota z1 [m]"), F("z2", "Cota z2 [m]"),
     F("p1", "Presion p1/g [m]"), F("p2", "Presion p2/g [m]"), fL, fD, fQ, fK, fnu}},
  {"I  Darcy-W. vs Hazen-W.", {F("modeI", "Calcular", nil, nil, nil, {"hf dado Q", "Q dado H"}),
     F("Q", "Caudal Q [l/s]", "", "-", "modeI", nil, 1),
     F("H", "Carga H [m]", "", "-", "modeI", nil, 2),
     fD, fL, fks, F("K", "Suma K (solo DW)", 0, "0"), fnu,
     F("CH", "C_H Hazen-W."), fmet}},
}
local HAS_F = {true, true, false, true, true, false, false}

local FRIC_CAMPOS = {
  F("fmode", "Modo", nil, nil, nil, {"Re y ks/D", "Datos tuberia"}),
  F("Re", "Reynolds Re", nil, nil, "fmode", nil, 1),
  F("ksD", "ks/D (o ks y D)", "", "opcional", "fmode", nil, 1),
  F("ks1", "ks (opc.) [mm]", "", "opcional", "fmode", nil, 1),
  F("D1", "D (opc.) [mm]", "", "opcional", "fmode", nil, 1),
  F("Q", "Caudal Q (o v) [l/s]", "", "opcional", "fmode", nil, 2),
  F("V", "Velocidad (opc.) [m/s]", "", "opcional", "fmode", nil, 2),
  F("D", "Diametro D [mm]", nil, nil, "fmode", nil, 2),
  F("ks", "Rugosidad ks [mm]", nil, nil, "fmode", nil, 2),
  F("nu", "Viscosidad [m2/s]", dnu, pnu, "fmode", nil, 2),
  fmet}

function net_campos()
  local np = npipes()
  local fs = {
    F("np", "Numero de tubos", 1, "1"),
    F("nmode", "Calcular", nil, nil, nil, {"Adelante (H dada)", "Atras (Q en tubo)"}),
    F("nH", "Carga H (adelante)", "", "-", "nmode", nil, 1),
    F("nkp", "Tubo conocido 1-8", "", "-", "nmode", nil, 2),
    F("nQk", "Q en ese tubo [l/s]", "", "-", "nmode", nil, 2),
    F("nu", "Viscosidad [m2/s]", dnu, pnu),
    F("nz1", "Energia tanque 1 (opc)", "", "no"),
    fmet,
  }
  for _, f in ipairs(campos_bomba()) do fs[#fs + 1] = f end
  for i = 1, np do
    local L = LETRA[i]
    fs[#fs + 1] = F("ntr" .. i, L .. " tramo")
    fs[#fs + 1] = F("nL" .. i, L .. " L [m]")
    fs[#fs + 1] = F("nD" .. i, L .. " D [mm]")
    fs[#fs + 1] = F("nf" .. i, L .. " f dado (opc)", "", "-")
    fs[#fs + 1] = F("nks" .. i, L .. " ks [mm] (si no f)", "", "-")
    fs[#fs + 1] = F("nK" .. i, L .. " Suma K", 0, "0")
  end
  return fs
end

function R(r, t, w) return {r = r, t = t, w = w or {}} end
-- ===== Ilustraciones 3D del catalogo de CD (PERDGFX, RLE 4 bits) =====
GFX = {W = 96, H = 80, TW = 32, TH = 18, pal = {
  {255, 255, 255}, {24, 41, 57}, {49, 57, 74}, {65, 74, 98}, {82, 90, 115}, {98, 115, 131}, {123, 131, 148}, {139, 148, 164}, {156, 164, 180}, {180, 189, 197}, {197, 205, 213}, {213, 222, 238}, {238, 238, 255}, {238, 106, 0}, {0, 148, 65}, {16, 24, 41}},
  big = {
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\112\195\240\240\240\240\240\35\118\69\35\240\240\240\240\144\35\214\53\4\19\240\240\240\240\80\19\38\135\102\53\4\19\240\240\240\240\32\3\6\247\86\37\20\19\240\240\240\224\19\247\55\70\53\20\3\240\240\240\192\3\71\136\151\54\53\20\3\240\240\240\160\3\39\232\119\54\53\20\3\240\240\240\128\3\23\248\40\103\54\53\20\3\240\240\240\96\3\23\248\88\87\54\37\36\3\240\240\240\80\3\248\136\87\54\37\36\3\240\240\240\48\3\88\137\184\71\70\37\36\3\240\240\240\16\3\7\56\217\152\71\54\37\36\3\240\240\240\16\3\40\249\25\120\87\54\37\36\3\240\240\240\3\40\249\73\104\71\54\37\52\3\240\240\208\3\40\249\105\88\87\38\37\52\3\240\240\208\3\40\121\138\89\104\71\54\37\36\3\240\240\208\3\24\105\202\73\88\71\54\37\52\3\240\240\176\3\24\105\90\59\74\73\72\87\38\37\52\3\240\240\176\3\24\89\74\123\58\57\88\71\54\37\52\3\240\240\160\3\24\73\74\59\28\75\42\41\88\71\54\37\52\3\240\240\160\3\8\89\58\43\92\43\42\57\72\71\54\37\52\3\240\240\144\3\24\73\58\43\124\43\42\41\72\71\54\37\52\3\240\240\144\3\24\73\58\27\156\27\42\41\72\71\54\37\52\3\240\208\13\160\3\24\73\58\27\156\43\26\41\72\71\54\37\52\3\240\208\61\112\3\24\73\58\27\172\27\26\41\72\71\54\37\68\3\240\208\93\16\13\16\3\24\73\58\27\172\27\26\41\72\71\54\37\68\3\240\208\141\16\3\24\73\58\27\156\27\42\41\72\71\54\37\68\3\240\208\141\16\3\24\73\58\27\156\27\42\41\72\71\54\37\68\3\240\176\141\48\3\24\73\58\43\124\43\26\41\72\71\54\53\52\3\240\128\189\64\3\24\89\58\43\92\43\42\41\72\71\54\37\68\3\240\80\109\32\61\80\3\40\73\74\59\28\59\42\41\72\87\54\37\68\3\240\16\125\96\29\112\3\24\89\74\123\42\57\72\71\70\37\68\3\240\16\61\160\13\128\3\24\105\90\59\58\57\72\87\54\53\68\3\240\16\13\240\112\3\40\105\186\57\88\87\54\37\84\3\240\240\160\3\7\40\121\122\73\88\87\54\53\68\3\240\240\192\3\56\249\41\88\87\70\37\84\3\240\240\192\3\7\56\249\9\88\103\54\53\68\3\240\240\208\3\7\72\217\104\103\70\37\84\3\240\240\224\3\7\88\153\120\103\70\53\84\3\240\240\240\3\7\136\9\184\103\70\53\84\3\240\240\240\0\3\23\248\56\103\86\37\84\3\240\240\240\32\3\23\248\24\103\86\53\36\19\4\3\240\240\240\48\3\39\216\119\86\53\36\51\240\240\240\64\3\71\152\119\102\53\36\51\240\240\240\96\3\6\247\55\86\69\36\51\240\240\240\128\3\6\247\7\102\69\36\51\240\240\240\160\3\22\199\102\69\52\51\240\240\240\192\19\38\103\134\69\52\51\240\240\240\240\3\246\69\52\67\240\240\240\240\16\19\5\150\85\52\67\240\240\240\240\80\35\181\52\67\240\240\240\240\160\35\85\68\67\240\240\240\240\240\195\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\160",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\16\3\240\240\240\240\240\176\35\6\35\240\240\240\240\240\96\19\102\19\240\240\240\240\240\32\19\70\87\3\240\240\240\240\240\19\22\183\3\240\240\240\240\208\3\6\247\3\240\240\240\240\160\19\247\23\3\240\240\240\240\144\3\103\136\71\3\240\240\240\240\112\3\55\248\8\23\3\240\240\240\240\80\3\39\248\72\7\3\240\240\240\240\48\3\23\248\120\3\240\240\240\240\32\3\23\248\152\3\240\240\240\240\0\3\23\248\168\3\240\240\240\240\0\3\7\104\137\200\3\240\240\240\224\3\7\88\233\136\3\240\240\240\208\3\7\72\249\41\120\3\240\240\240\192\3\72\249\89\88\3\240\240\240\176\3\72\249\121\88\3\240\240\240\160\3\56\249\153\72\3\240\240\240\144\3\56\169\122\137\72\3\240\240\240\128\3\40\153\202\105\56\3\240\240\240\112\3\40\137\250\105\56\3\240\240\240\96\3\40\121\122\59\106\73\56\3\240\240\240\96\3\24\121\90\155\74\73\40\3\240\240\240\80\3\40\105\90\187\58\73\56\3\240\240\240\64\3\40\105\74\59\92\59\58\57\56\3\240\240\240\64\3\24\105\74\59\140\43\42\73\40\3\240\240\240\64\3\24\105\74\43\156\43\58\57\56\3\240\240\240\48\3\24\89\74\43\188\43\42\57\56\3\240\240\240\48\3\24\89\74\43\204\27\42\57\56\3\240\240\240\32\3\40\89\74\43\204\27\42\57\72\3\240\240\48\13\192\3\40\89\74\43\204\27\42\57\72\3\240\240\48\77\128\3\40\89\74\43\204\27\42\57\72\3\240\240\64\109\32\13\16\3\40\89\74\43\204\27\42\57\72\3\240\240\64\173\16\3\40\89\74\43\188\43\42\41\104\3\240\240\48\173\16\3\40\105\58\59\172\27\42\57\88\7\3\240\240\32\157\64\3\24\105\74\43\156\43\42\57\88\7\3\240\224\205\80\3\40\89\74\59\124\43\42\57\104\7\3\240\160\141\0\93\96\3\40\105\74\91\44\59\58\57\88\23\3\240\112\125\64\77\112\3\40\121\74\171\58\57\104\39\3\240\32\125\128\61\128\3\56\121\90\107\74\73\88\55\3\240\32\77\192\29\144\3\7\40\137\250\73\104\55\3\240\32\13\240\0\13\176\3\56\137\218\73\104\71\3\240\240\240\16\3\7\40\169\154\89\104\87\3\240\240\240\16\3\7\56\249\137\104\103\3\240\240\240\32\3\7\56\249\105\120\103\3\240\240\240\32\3\7\72\249\57\120\135\6\3\240\240\240\32\3\7\88\249\136\135\22\3\240\240\240\32\3\23\104\185\152\135\38\3\240\240\240\48\3\23\152\57\200\135\54\3\240\240\240\48\3\39\248\136\135\70\3\240\240\240\64\3\39\248\104\135\86\3\240\240\240\80\3\39\248\56\135\118\3\240\240\240\80\3\6\55\248\8\135\118\5\3\240\240\240\96\3\6\71\184\167\102\37\3\240\240\240\112\3\6\119\56\199\118\53\3\240\240\240\128\3\6\247\103\118\53\3\240\240\240\160\3\22\247\39\118\85\3\240\240\240\176\3\38\231\134\85\4\3\240\240\240\192\19\70\103\166\85\36\3\240\240\240\224\3\246\54\101\36\3\240\240\240\240\0\19\246\101\68\3\240\240\240\240\32\19\21\118\133\68\35\240\240\240\240\64\19\213\84\51\240\240\240\240\112\51\101\100\67\240\240\240\240\192\83\52\99\240\240\240\240\240\64\67\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\16",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\80\67\240\240\240\240\240\64\83\69\83\240\240\240\240\176\35\24\7\86\101\4\35\240\240\240\240\112\3\104\7\118\69\20\19\240\240\240\240\80\3\120\7\134\69\20\19\240\240\240\240\32\3\152\39\118\69\20\19\240\240\240\240\0\3\184\55\102\53\36\3\240\240\240\224\3\200\87\86\69\20\19\240\240\240\192\3\216\103\86\53\36\3\240\240\240\176\3\232\103\86\53\36\3\240\240\240\160\3\248\103\86\53\36\3\240\240\240\144\3\248\8\103\86\37\52\3\240\240\240\128\3\248\8\119\70\53\52\3\240\240\240\96\3\248\40\119\70\53\52\3\240\240\240\80\3\248\56\119\70\37\52\3\240\240\240\80\3\248\72\103\70\53\52\3\240\240\240\64\3\248\88\103\70\53\52\3\240\240\240\48\3\248\104\87\70\53\52\3\240\240\240\48\3\248\104\103\70\37\68\3\240\240\240\48\3\248\104\87\70\53\52\3\240\240\240\48\3\248\104\103\70\37\68\3\240\240\240\32\3\248\120\87\70\53\52\3\240\240\240\32\3\248\120\87\70\53\68\3\240\240\240\16\3\248\120\103\54\53\68\3\240\240\240\16\3\248\136\87\70\37\68\3\240\240\240\16\3\248\136\87\70\53\68\3\240\240\240\0\3\248\136\87\70\53\68\3\240\240\240\0\3\248\136\87\70\53\68\3\240\240\240\16\3\248\120\87\70\53\68\3\240\240\240\16\3\248\120\87\70\53\68\3\240\240\16\13\224\3\248\120\87\70\53\84\3\240\240\0\77\160\3\248\120\87\70\53\84\3\240\240\16\109\32\13\64\3\248\104\87\70\53\84\3\240\240\16\173\64\3\248\120\71\70\53\84\3\240\240\16\173\64\3\248\120\71\70\53\84\3\240\240\0\157\96\3\248\120\71\70\53\84\3\240\192\205\128\3\248\104\71\70\53\84\3\240\128\141\0\93\144\3\248\120\39\86\37\100\3\240\80\125\64\77\160\3\248\104\55\70\53\84\3\240\32\125\128\61\176\3\248\120\39\70\53\84\3\240\32\77\192\29\208\3\248\104\39\70\53\84\3\240\32\13\240\0\13\224\3\248\104\23\70\53\100\3\240\240\240\64\3\248\104\23\70\53\100\3\240\240\240\80\3\248\88\7\86\53\84\3\240\240\240\96\3\248\88\7\70\53\100\3\240\240\240\112\3\248\72\7\70\53\100\3\240\240\240\112\3\248\72\7\54\53\100\3\240\240\240\128\3\248\72\7\54\53\100\3\240\240\240\144\3\248\56\7\38\53\100\3\240\240\240\160\3\248\56\7\22\69\100\3\240\240\240\176\3\248\40\7\6\69\100\3\240\240\240\192\3\248\40\7\6\53\52\3\36\3\240\240\240\208\3\248\24\7\69\36\19\20\3\240\240\240\224\3\248\24\7\53\52\35\4\3\240\240\240\240\3\248\8\7\37\52\67\240\240\240\240\0\3\248\8\7\21\52\67\240\240\240\240\32\3\248\7\5\52\67\240\240\240\240\64\3\232\6\52\67\240\240\240\240\80\3\232\5\36\67\240\240\240\240\112\3\216\5\20\67\240\240\240\240\144\3\184\7\4\83\240\240\240\240\176\3\168\6\83\240\240\240\240\192\3\168\4\51\240\240\240\240\240\19\120\7\35\240\240\240\240\240\48\3\88\7\19\240\240\240\240\240\96\35\8\35\240\240\240\240\240\176\3\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\224",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\224\243\240\240\240\240\192\35\8\7\86\101\4\35\240\240\240\240\128\3\88\7\118\85\4\35\240\240\240\240\64\3\136\7\134\69\20\19\240\240\240\240\32\3\24\5\19\4\6\40\23\134\69\20\19\240\240\240\240\3\24\51\36\7\24\55\118\53\36\3\240\240\240\224\3\8\5\19\68\5\7\24\71\102\53\36\19\240\240\240\192\3\7\3\68\53\7\24\87\86\53\52\3\240\240\240\160\3\8\6\52\85\6\7\24\87\86\53\52\3\240\240\240\144\3\8\5\20\85\54\7\8\119\70\53\52\3\240\240\240\128\3\8\20\85\86\24\119\70\53\52\3\240\240\240\112\3\7\85\102\23\24\119\70\53\52\3\240\240\240\96\3\7\53\118\39\40\119\70\53\52\3\240\240\240\80\3\6\37\102\87\40\103\86\37\68\3\240\240\240\64\3\6\21\102\103\56\103\70\53\52\3\240\240\240\64\3\6\5\102\119\72\103\70\53\52\3\240\240\240\48\3\102\119\104\103\70\53\68\3\240\240\240\32\3\86\119\136\103\70\53\52\3\240\240\240\32\3\7\54\119\168\87\70\53\68\3\240\240\240\16\3\7\38\119\184\103\70\37\68\3\240\240\240\16\3\7\22\119\120\9\72\87\70\53\68\3\240\240\240\0\3\7\6\119\104\57\56\87\70\53\68\3\240\240\240\0\3\7\6\103\104\73\56\103\70\37\68\3\240\240\240\0\3\119\104\105\56\87\70\53\68\3\240\240\240\3\8\87\104\73\42\56\87\70\53\68\3\240\240\240\0\3\71\104\73\58\9\40\87\70\53\68\3\240\240\240\0\3\71\88\57\106\40\87\70\53\68\3\240\240\240\0\3\55\88\57\58\59\9\24\103\54\53\84\3\240\240\240\3\55\88\57\42\75\10\24\103\70\37\84\3\240\240\240\3\8\23\88\57\42\43\44\11\24\103\70\37\84\3\240\240\0\13\224\3\23\88\41\42\43\76\24\103\70\37\84\3\240\240\0\77\160\3\23\72\57\42\27\92\10\8\103\70\37\84\3\240\240\16\109\32\13\48\3\104\41\42\27\108\10\8\103\70\37\84\3\240\240\16\173\48\3\104\41\42\27\124\24\71\70\53\84\3\240\240\16\173\48\3\88\57\42\27\124\9\8\71\70\53\84\3\240\240\0\157\96\3\72\57\42\27\124\9\8\71\70\53\84\3\240\208\189\112\3\72\57\42\27\124\11\8\71\70\53\84\3\240\144\125\0\93\128\3\72\57\42\27\140\24\55\70\53\84\3\240\96\125\48\77\160\3\56\57\42\43\124\8\55\86\53\84\3\240\32\125\112\61\176\3\72\57\42\27\124\9\8\39\70\53\100\3\240\32\77\176\29\192\3\72\57\42\59\92\10\8\39\70\53\100\3\240\32\13\240\13\224\3\56\57\58\139\10\8\23\86\53\84\3\240\240\240\64\3\56\73\58\123\10\8\23\70\69\84\3\240\240\240\64\3\72\73\74\91\10\8\7\86\53\100\3\240\240\240\80\3\56\89\170\8\7\70\69\100\3\240\240\240\80\3\72\105\138\8\7\70\53\100\3\240\240\240\96\3\88\121\106\8\7\54\69\100\3\240\240\240\112\3\88\217\8\7\54\53\116\3\240\240\240\112\3\104\201\8\7\38\69\100\3\240\240\240\144\3\104\185\24\38\53\116\3\240\240\240\144\3\136\153\24\22\69\100\3\240\240\240\176\3\168\105\24\6\69\116\3\240\240\240\176\3\248\8\9\24\69\52\3\36\3\240\240\240\208\3\248\40\53\52\35\4\3\240\240\240\224\3\248\40\53\36\51\4\3\240\240\240\240\3\248\24\37\52\67\240\240\240\240\0\3\8\23\216\7\21\52\67\240\240\240\240\32\3\8\71\152\7\5\52\67\240\240\240\240\64\3\8\199\8\6\52\67\240\240\240\240\80\3\8\183\24\5\36\67\240\240\240\240\112\3\8\167\24\20\83\240\240\240\240\144\3\8\7\118\7\8\7\4\83\240\240\240\240\176\3\8\7\102\24\6\67\240\240\240\240\224\3\24\7\37\7\40\4\51\240\240\240\240\240\0\3\120\6\35\240\240\240\240\240\48\3\88\35\240\240\240\240\240\96\83\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\208",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\32\163\240\240\240\240\240\48\3\6\5\6\7\54\37\19\240\240\240\240\240\0\3\6\3\20\5\39\38\37\19\240\240\240\240\208\3\8\36\21\7\8\39\38\21\4\3\240\240\240\240\176\3\0\3\4\21\6\7\6\71\38\21\4\3\240\240\240\240\144\3\16\3\21\6\7\22\7\8\55\38\21\4\3\240\240\240\240\176\3\5\7\22\55\8\55\22\21\20\3\240\240\240\240\160\3\7\22\55\8\7\8\55\22\21\4\3\240\240\240\240\48\3\64\3\7\22\55\40\7\8\39\22\21\20\3\240\240\240\240\16\3\48\19\0\3\6\55\88\39\38\21\20\3\240\240\240\240\3\48\3\32\3\55\40\41\24\39\22\21\20\3\240\240\240\224\3\32\19\48\3\39\40\41\10\24\39\22\21\20\3\240\240\240\208\3\32\3\80\3\23\40\41\42\8\39\38\5\36\3\240\208\13\240\192\3\16\19\96\3\23\40\25\10\27\9\8\39\38\21\20\3\240\208\61\240\176\19\128\3\40\25\10\25\10\12\9\39\38\21\20\3\240\208\109\16\13\240\64\3\160\3\24\9\24\9\11\44\11\8\23\38\21\20\3\240\224\141\240\32\19\176\3\40\9\26\11\60\8\23\38\21\20\3\240\224\141\224\3\16\3\208\3\24\25\26\11\60\8\23\38\5\36\3\240\192\141\240\3\0\19\240\3\8\25\26\11\60\9\23\22\21\36\3\240\128\173\240\0\3\0\3\240\0\3\40\25\10\27\44\10\7\38\21\36\3\240\80\109\32\45\240\0\3\0\3\224\3\32\3\24\25\26\59\10\7\38\21\36\3\240\16\125\80\29\240\0\19\160\35\112\3\8\41\90\7\22\21\36\3\240\32\61\144\13\240\0\19\48\3\32\3\208\3\24\57\58\7\22\21\36\3\240\32\13\240\208\3\32\67\240\16\3\24\105\7\6\21\36\3\240\240\192\35\16\3\0\51\240\80\3\40\89\7\6\21\36\3\240\240\176\3\10\9\8\19\7\19\160\99\96\3\103\25\7\21\20\19\240\240\192\3\27\8\6\99\240\96\3\120\7\5\20\35\240\240\192\3\25\7\3\96\67\16\3\240\3\104\6\20\35\240\240\224\35\208\19\0\35\16\3\16\19\64\3\87\8\5\4\35\240\240\240\240\112\3\0\3\112\19\71\8\4\35\240\240\240\240\240\3\0\3\32\3\7\38\7\19\240\240\240\240\240\128\3\7\6\35\240\240\240\240\240\160\19\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\32",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\112\83\240\240\240\240\240\112\19\24\7\38\19\240\240\240\240\240\48\19\88\7\38\3\240\240\240\240\240\32\3\136\7\6\7\3\240\240\240\240\240\0\3\168\39\3\240\240\240\240\240\3\184\39\3\240\240\240\240\208\3\216\39\3\240\240\240\240\192\3\232\23\3\240\240\240\240\192\3\248\23\3\240\240\240\240\176\3\248\8\23\3\240\240\240\240\160\3\248\8\23\3\240\240\240\240\160\3\248\56\3\240\240\240\240\128\3\248\72\3\240\240\240\240\128\3\248\88\3\240\240\240\240\112\3\248\104\3\240\240\240\240\96\3\248\104\3\240\240\240\240\96\3\248\120\3\240\240\240\240\80\3\248\120\3\240\240\240\240\80\3\248\120\3\240\240\240\240\96\3\248\120\3\240\240\240\240\80\3\248\120\3\240\240\240\240\80\3\248\136\3\240\240\240\240\64\3\248\136\3\240\240\240\240\64\3\248\136\3\240\240\240\240\64\3\248\152\3\240\240\240\240\48\3\248\152\3\240\240\240\240\48\3\248\168\3\240\240\240\240\48\3\248\152\3\240\240\240\240\48\3\248\152\3\240\240\240\240\48\3\248\152\3\240\240\240\240\48\3\248\168\3\240\240\240\16\13\240\3\248\168\3\240\240\240\16\77\192\3\248\152\3\240\240\240\32\125\32\13\64\3\248\136\23\3\240\240\240\16\189\64\3\248\136\23\3\240\240\240\16\189\64\3\248\136\23\3\240\240\240\16\157\112\3\248\120\23\3\240\240\224\189\128\3\248\120\23\3\240\240\176\205\160\3\248\120\39\3\240\240\96\125\32\77\176\3\248\136\23\3\240\240\48\109\96\61\208\3\248\120\23\3\240\240\125\160\29\224\3\248\120\23\3\240\240\61\224\13\240\3\248\120\23\3\240\240\13\240\240\48\3\248\104\39\3\240\240\240\240\48\3\248\104\39\3\240\240\240\240\48\3\248\104\23\6\3\240\240\240\240\64\3\248\88\7\22\3\240\240\240\240\64\3\248\88\7\22\3\240\240\240\240\80\3\248\88\22\3\240\240\240\240\80\3\248\88\22\3\240\240\240\240\96\3\248\72\22\3\240\240\240\240\96\3\248\72\22\3\240\240\240\240\112\3\248\56\22\3\240\240\240\240\112\3\248\56\6\5\3\240\240\240\240\128\3\248\40\21\3\240\240\240\240\128\3\248\40\21\3\240\240\240\240\144\3\248\24\21\3\240\240\240\240\144\3\248\8\7\21\3\240\240\240\240\160\3\248\7\21\3\240\240\240\240\176\3\232\7\20\3\240\240\240\240\176\3\232\5\4\3\240\240\240\240\208\3\216\5\4\3\240\240\240\240\224\3\184\7\20\3\240\240\240\240\240\3\168\6\19\240\240\240\240\240\0\19\152\4\19\240\240\240\240\240\32\3\120\6\19\240\240\240\240\240\64\3\88\35\240\240\240\240\240\96\83\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\48",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\128\35\240\240\240\240\240\160\19\39\19\240\240\240\240\240\112\3\55\40\3\240\240\240\240\240\80\3\39\88\3\240\240\240\240\240\48\3\39\104\3\240\240\240\240\240\32\3\39\120\9\3\240\240\240\240\240\0\3\39\104\57\3\240\240\240\240\224\3\23\120\73\3\240\240\240\240\208\3\23\104\121\3\240\240\240\240\176\3\23\104\137\3\240\240\240\240\144\19\23\88\137\42\3\240\240\240\240\112\3\23\104\137\58\3\240\240\240\240\96\3\23\88\137\90\11\3\240\240\240\240\64\3\23\88\121\90\43\3\240\240\240\240\48\3\23\72\121\90\91\3\240\240\240\240\16\3\23\72\105\90\123\3\240\240\240\240\0\3\7\72\105\90\155\3\240\240\240\240\3\7\72\89\90\203\3\240\240\240\208\3\7\56\89\74\251\3\240\240\13\240\160\19\7\56\73\74\251\27\3\240\240\61\240\96\3\7\56\89\58\251\75\3\240\224\109\16\13\240\3\7\56\73\58\251\75\26\3\240\240\141\224\3\7\40\73\58\251\43\90\3\240\240\141\208\3\7\40\57\42\251\27\154\3\240\208\141\224\3\40\57\42\251\11\138\73\3\240\128\173\240\3\40\41\42\235\122\153\3\240\80\109\32\45\240\3\24\41\42\203\122\217\3\240\16\125\80\29\240\3\24\25\42\171\106\217\72\3\240\16\61\144\13\224\19\8\25\26\171\74\185\184\3\240\16\13\240\176\3\24\25\10\139\74\153\248\24\3\240\240\208\3\8\25\10\107\58\121\248\136\3\240\240\192\3\8\9\10\75\42\105\248\216\7\3\240\240\176\3\9\10\43\42\57\248\88\247\7\3\240\240\144\3\10\27\10\41\184\247\247\7\3\240\240\128\35\40\247\247\247\3\240\240\176\83\198\247\247\3\240\240\240\16\83\21\246\246\54\3\240\240\240\128\67\101\246\150\3\240\240\240\208\83\181\230\3\240\240\240\240\48\83\4\245\54\3\240\240\240\240\144\83\20\197\3\240\240\240\240\240\83\36\69\3\240\240\240\240\240\96\115\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\128",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\128\83\240\240\240\240\240\128\3\88\35\240\240\240\240\240\80\3\104\7\4\19\240\240\240\240\240\32\3\136\7\20\35\240\240\240\240\240\3\152\7\5\36\35\240\240\240\240\192\3\168\7\84\35\240\240\240\240\128\3\200\6\116\19\240\240\240\240\96\3\216\5\132\35\240\240\240\240\48\3\216\7\180\35\240\240\240\240\0\3\232\6\53\148\35\240\240\240\208\3\248\117\132\19\240\240\240\176\3\248\6\181\84\35\240\240\240\128\3\248\8\245\68\35\240\240\240\80\3\248\8\6\245\53\36\35\240\240\240\32\3\248\24\245\117\20\19\240\240\240\0\3\248\24\6\245\165\35\240\240\208\3\248\24\7\245\213\35\240\240\160\3\248\40\6\245\213\3\240\240\176\3\248\40\7\245\165\36\3\240\240\176\3\248\56\245\117\68\3\240\240\208\3\248\40\6\245\69\84\3\240\240\224\3\248\40\7\245\21\116\3\240\240\240\3\248\56\245\148\3\240\240\240\3\248\56\6\181\180\3\240\240\240\0\3\248\56\7\133\212\3\240\240\240\16\3\248\72\101\228\3\240\240\48\13\224\3\248\56\53\244\20\3\240\240\48\77\160\3\248\56\6\244\52\3\240\240\80\109\32\13\48\3\248\56\7\244\36\3\240\240\96\173\48\3\248\72\244\20\3\240\240\112\173\64\3\248\56\5\244\3\240\240\96\173\96\3\248\56\6\244\3\240\240\32\221\112\3\248\56\7\228\3\240\240\141\16\77\160\3\248\56\212\3\240\192\141\80\61\176\3\248\56\196\3\240\208\77\160\29\192\3\248\56\5\180\3\240\208\13\224\13\224\3\248\40\5\164\3\240\240\240\224\3\248\40\6\148\3\240\240\240\240\3\248\40\7\132\3\240\240\240\240\16\3\248\24\7\132\3\240\240\240\240\16\3\248\24\7\116\3\240\240\240\240\48\3\248\24\100\3\240\240\240\240\64\3\248\24\84\3\240\240\240\240\96\3\248\8\84\3\240\240\240\240\96\3\248\8\68\3\240\240\240\240\128\3\248\52\3\240\240\240\240\144\3\248\36\3\240\240\240\240\176\3\216\7\20\3\240\240\240\240\192\3\216\6\20\3\240\240\240\240\208\3\200\7\4\3\240\240\240\240\240\3\184\5\3\240\240\240\240\240\0\3\184\3\240\240\240\240\240\32\3\152\7\3\240\240\240\240\240\48\3\136\3\240\240\240\240\240\80\3\104\3\240\240\240\240\240\112\19\56\3\240\240\240\240\240\160\51\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\48",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\96\243\243\243\35\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\0\13\160\3\247\247\247\7\3\240\240\0\29\144\3\247\247\247\7\3\240\240\0\61\112\3\247\247\247\7\3\240\240\0\77\96\3\247\247\247\7\3\240\240\0\109\64\3\247\247\247\7\3\240\253\173\16\3\247\247\247\7\3\240\253\173\16\3\247\247\247\7\3\240\253\173\16\3\247\247\247\7\3\240\240\0\93\80\3\247\247\247\7\3\240\240\0\77\96\3\247\247\247\7\3\240\240\0\45\128\3\247\247\247\7\3\240\240\0\13\160\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\247\247\247\7\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\3\246\246\246\6\3\240\240\192\243\243\243\35\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\80",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\224\3\240\240\240\240\240\208\3\7\3\240\240\240\240\240\176\3\39\3\240\240\240\240\240\144\3\71\3\240\240\240\240\240\112\3\103\3\240\240\240\240\240\80\3\135\3\240\240\240\240\240\48\3\167\3\240\240\240\240\240\16\3\199\3\240\240\240\240\240\3\231\3\240\240\240\240\208\3\247\7\3\240\240\240\240\176\3\247\39\19\240\240\240\240\128\3\247\87\3\240\240\240\240\96\3\247\119\3\240\240\240\240\64\3\247\151\3\240\240\240\240\32\3\247\183\3\240\240\240\240\0\3\247\215\3\240\240\240\224\3\247\247\3\240\240\240\176\19\247\247\23\3\240\240\240\144\3\247\247\71\3\240\240\240\112\3\247\247\103\3\240\240\240\80\3\247\247\135\3\240\240\240\48\3\247\247\167\3\240\240\240\16\3\247\247\199\3\240\240\240\3\247\247\231\3\240\240\208\3\247\247\247\7\3\240\240\0\13\160\3\247\247\247\23\3\240\240\29\144\3\247\247\247\7\4\3\240\240\61\112\3\8\247\247\231\20\3\240\240\77\96\3\40\247\247\183\36\3\240\240\109\64\3\56\247\247\151\52\3\240\253\157\16\3\72\247\247\103\6\68\3\240\253\157\16\3\88\247\247\71\6\84\3\240\253\157\16\3\104\247\247\39\6\100\3\240\240\93\80\3\120\247\247\7\6\116\3\240\240\77\96\3\136\247\231\6\132\3\240\240\45\128\3\152\247\199\6\148\3\240\240\13\160\3\168\247\167\5\164\3\240\240\176\3\184\247\135\5\164\3\240\240\208\3\184\247\103\5\164\3\240\240\240\3\184\247\71\5\164\3\240\240\240\16\3\168\9\8\247\23\5\164\3\240\240\240\48\3\184\247\7\5\164\3\240\240\240\80\3\184\231\180\3\240\240\240\112\3\184\199\180\3\240\240\240\144\19\168\167\180\3\240\240\240\192\3\184\119\180\3\240\240\240\224\3\184\87\180\3\240\240\240\240\0\3\184\39\6\180\3\240\240\240\240\32\3\184\7\6\180\3\240\240\240\240\64\3\168\7\180\3\240\240\240\240\96\3\152\7\164\3\240\240\240\240\128\3\136\7\132\19\240\240\240\240\160\3\120\7\116\3\240\240\240\240\208\3\104\7\100\3\240\240\240\240\240\3\88\7\84\3\240\240\240\240\240\16\3\72\7\68\3\240\240\240\240\240\48\3\56\7\52\3\240\240\240\240\240\80\3\40\7\36\3\240\240\240\240\240\112\3\24\7\20\3\240\240\240\240\240\144\3\8\7\4\3\240\240\240\240\240\176\3\7\3\240\240\240\240\240\208\3\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\192\147\240\240\240\240\240\16\51\151\35\240\240\240\240\192\19\247\7\19\240\240\240\240\128\19\247\71\19\240\240\240\240\80\3\247\135\3\240\240\240\240\48\3\247\167\3\240\240\240\240\32\3\247\183\3\240\240\240\240\0\3\247\199\3\240\240\240\240\0\3\247\215\3\240\240\240\240\3\247\215\3\240\240\240\240\3\247\215\3\240\240\240\240\3\247\215\3\240\240\240\240\3\247\199\6\3\240\240\240\240\3\247\199\5\3\240\240\240\240\3\8\247\167\5\4\3\240\240\240\240\3\24\247\135\5\20\3\240\240\240\240\3\56\247\71\6\52\3\240\240\240\240\3\88\247\7\6\5\68\3\240\240\240\240\3\168\135\22\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\13\224\3\200\71\54\37\68\3\240\240\240\77\160\3\200\71\54\37\68\3\240\240\240\0\125\32\13\32\3\200\71\54\37\68\3\240\240\240\0\189\32\3\200\71\54\37\68\3\240\240\240\0\189\32\3\200\71\54\37\68\3\240\240\240\173\64\3\200\71\54\37\68\3\240\240\192\205\80\3\200\71\54\37\68\3\240\240\128\125\0\93\112\3\200\71\54\37\68\3\240\240\64\141\48\77\128\3\200\71\54\37\68\3\240\240\0\141\112\61\144\3\200\71\54\37\68\3\240\240\0\77\192\29\160\3\200\71\54\37\68\3\240\240\0\13\240\0\13\176\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\68\3\240\240\240\240\3\200\71\54\37\52\3\240\240\240\240\16\3\184\71\54\37\52\3\240\240\240\240\16\3\184\71\54\37\36\3\240\240\240\240\48\3\168\71\54\37\20\3\240\240\240\240\80\19\136\71\54\37\19\240\240\240\240\128\19\104\71\54\5\19\240\240\240\240\192\51\40\71\22\35\240\240\240\240\240\32\147\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\128",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\160\3\240\240\240\240\240\176\35\6\19\240\240\240\240\240\80\51\86\3\240\240\240\240\240\16\35\102\55\3\240\240\240\240\192\51\102\119\3\240\240\240\240\128\35\118\183\3\240\240\240\240\48\51\102\247\7\3\240\240\240\240\35\118\247\39\8\3\240\240\240\192\35\102\247\39\88\3\240\240\240\112\51\102\247\39\136\3\240\240\240\64\35\102\247\39\216\3\240\240\240\51\102\247\39\248\8\3\240\240\224\3\56\54\247\23\248\88\3\240\240\192\3\88\247\23\248\136\3\240\240\192\3\104\199\248\200\3\240\240\192\3\120\135\248\248\8\3\240\240\160\3\152\71\248\248\56\3\240\240\160\3\248\248\248\40\3\240\240\160\3\248\248\248\56\3\240\240\144\3\248\248\248\56\3\240\240\144\3\248\248\248\40\7\3\240\240\144\3\248\248\248\55\3\240\240\144\3\248\248\184\135\3\240\208\13\144\3\248\248\136\183\3\240\208\61\96\3\248\248\88\231\3\240\208\109\16\13\16\3\248\248\8\247\39\3\240\224\141\16\3\248\216\247\87\3\240\224\141\16\3\248\152\247\167\3\240\176\141\48\3\248\104\247\151\54\3\240\112\173\80\3\248\40\247\167\102\3\240\64\109\32\45\96\3\248\247\167\150\3\240\0\125\80\29\128\3\216\247\119\214\3\240\0\61\144\13\144\3\216\247\71\246\5\3\240\0\13\240\112\3\216\247\7\246\69\3\240\240\160\3\216\199\246\117\3\240\240\160\3\216\135\246\6\149\3\240\240\176\3\216\87\246\165\36\3\240\240\192\3\200\39\246\165\84\3\240\240\192\3\200\230\181\100\35\240\240\192\3\200\7\166\165\116\67\240\240\224\3\184\7\102\181\100\115\240\240\240\3\184\70\165\116\99\240\240\240\64\3\168\22\165\116\99\240\240\240\112\3\168\6\117\116\99\240\240\240\192\3\152\6\69\116\99\240\240\240\240\3\152\6\21\100\99\240\240\240\240\64\3\136\100\99\240\240\240\240\128\3\104\7\36\115\240\240\240\240\192\3\88\6\99\240\240\240\240\240\16\3\72\4\51\240\240\240\240\240\80\19\8\35\240\240\240\240\240\176\3\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\224",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\208\179\240\240\240\240\48\243\6\103\6\19\240\240\240\64\243\134\183\22\19\240\240\240\16\67\246\6\247\7\38\19\240\240\240\16\19\87\134\247\71\54\5\3\240\240\240\32\3\7\72\247\199\54\21\19\240\240\240\32\3\136\247\119\70\21\19\240\240\240\48\3\24\73\56\247\55\70\37\19\240\240\240\80\3\8\121\24\247\7\86\21\4\19\240\240\160\13\160\3\8\41\58\41\24\199\102\21\20\3\240\240\192\61\112\3\41\10\59\10\25\24\135\118\37\20\19\240\240\208\109\16\13\16\3\25\26\11\44\11\10\9\24\87\134\37\20\19\240\240\240\0\141\16\3\25\10\11\60\11\10\9\24\39\134\53\20\19\240\240\240\32\141\16\3\25\10\11\60\11\10\9\24\23\118\53\20\19\240\240\240\32\141\48\3\25\26\11\44\11\10\9\24\23\86\53\20\19\240\240\240\0\173\80\3\41\26\43\10\9\24\39\38\69\20\35\240\240\224\109\32\45\96\3\8\41\58\25\24\23\22\69\20\35\240\240\192\125\80\29\128\3\8\89\40\23\22\53\20\35\240\240\224\61\144\13\144\3\40\25\56\39\22\5\52\19\240\240\240\0\13\240\128\3\104\23\38\5\36\19\240\240\240\240\208\3\103\38\5\20\35\240\240\240\240\240\3\55\38\21\20\19\240\240\240\240\240\32\19\38\21\20\19\240\240\240\240\240\96\99\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\224",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\64\3\240\240\240\240\240\192\19\7\3\240\240\240\240\240\176\3\23\3\240\240\240\240\240\176\3\8\23\3\240\240\240\240\240\160\3\24\23\3\240\240\240\240\240\144\3\40\23\3\240\240\240\240\240\128\3\56\23\3\240\240\240\240\240\112\3\56\23\3\240\240\240\240\240\112\3\72\23\3\240\240\240\240\240\96\3\88\23\3\240\240\240\240\240\80\3\104\23\3\240\240\240\240\240\64\3\120\23\3\240\240\240\240\240\48\3\120\23\3\240\240\240\240\240\48\3\136\23\3\240\240\240\240\240\32\3\152\23\3\240\240\240\240\240\16\3\168\23\3\240\240\240\240\240\0\3\184\23\3\240\240\240\240\240\3\184\39\3\240\240\240\240\224\3\200\23\3\240\240\240\240\224\3\216\23\3\240\240\240\240\208\3\232\23\3\240\240\240\240\192\3\248\23\3\240\240\240\240\176\3\248\8\23\3\240\240\240\240\160\3\248\8\23\3\240\240\240\240\160\3\248\24\23\3\240\240\240\240\144\3\248\40\23\3\240\240\240\240\128\3\248\56\23\3\240\240\240\240\112\3\248\72\23\3\240\240\240\240\96\3\248\72\23\3\240\240\240\240\96\3\248\88\23\3\240\240\240\240\80\3\248\104\23\3\240\240\240\240\64\3\248\120\23\3\240\240\240\80\13\192\3\248\136\23\3\240\240\240\64\77\128\3\248\136\23\3\240\240\240\80\109\32\13\16\3\248\152\6\3\240\240\240\80\173\16\3\248\152\6\3\240\240\240\80\173\16\3\248\152\6\3\240\240\240\64\157\64\3\248\136\6\3\240\240\240\0\205\96\3\248\120\6\3\240\240\192\141\0\93\112\3\248\120\6\3\240\240\144\125\64\77\144\3\248\104\6\3\240\240\80\125\128\61\176\3\248\88\6\3\240\240\80\77\192\29\208\3\248\72\6\3\240\240\80\13\240\0\13\240\3\248\56\6\3\240\240\240\240\128\3\248\56\6\3\240\240\240\240\144\3\248\40\6\3\240\240\240\240\160\3\248\24\6\3\240\240\240\240\176\3\248\8\6\3\240\240\240\240\192\3\248\6\3\240\240\240\240\192\3\248\6\3\240\240\240\240\208\3\232\6\3\240\240\240\240\224\3\216\6\3\240\240\240\240\240\3\200\6\3\240\240\240\240\240\0\3\184\6\3\240\240\240\240\240\16\3\168\6\3\240\240\240\240\240\16\3\168\6\3\240\240\240\240\240\32\3\152\6\3\240\240\240\240\240\48\3\136\6\3\240\240\240\240\240\64\3\120\6\3\240\240\240\240\240\80\3\104\6\3\240\240\240\240\240\80\3\104\6\3\240\240\240\240\240\96\3\88\6\3\240\240\240\240\240\112\3\72\6\3\240\240\240\240\240\128\3\56\6\3\240\240\240\240\240\144\3\40\6\3\240\240\240\240\240\144\3\40\6\3\240\240\240\240\240\160\3\24\6\3\240\240\240\240\240\176\3\8\6\3\240\240\240\240\240\192\3\6\3\240\240\240\240\240\208\3\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\0",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\192\35\240\240\240\240\240\160\19\7\22\19\240\240\240\240\240\96\19\24\23\6\21\3\240\240\240\240\240\64\3\9\40\39\6\5\4\3\240\240\240\240\240\32\3\41\40\39\6\5\3\240\240\240\240\240\32\3\57\40\23\22\5\3\240\240\240\240\240\0\3\89\40\23\22\5\3\240\240\240\240\240\3\105\40\23\6\21\3\240\240\240\240\224\3\105\56\23\6\5\4\3\240\240\240\240\208\3\121\40\39\6\5\4\3\240\240\240\240\192\3\8\121\40\23\22\5\3\240\240\240\240\192\3\24\121\40\23\22\5\3\240\240\240\240\192\3\24\121\40\23\22\5\3\240\240\240\240\192\3\8\121\56\23\6\5\4\3\240\240\240\240\192\3\8\121\40\39\6\5\4\3\240\240\240\240\192\3\8\121\40\23\22\5\3\240\240\240\240\192\3\24\121\40\23\22\5\3\240\240\240\240\192\3\24\121\40\23\22\5\3\240\240\240\240\192\3\24\121\40\23\6\5\4\3\240\240\240\240\192\3\8\121\40\39\6\5\4\3\240\240\240\240\192\3\8\121\40\23\22\5\3\240\240\240\240\192\3\24\121\40\23\22\5\3\240\240\240\240\192\3\24\121\40\23\22\5\3\240\240\240\240\192\3\24\121\40\23\6\21\3\240\240\240\240\192\3\8\121\56\23\6\5\4\3\240\240\240\240\192\3\8\121\40\39\6\5\4\3\240\240\240\240\192\3\8\121\40\23\22\5\3\240\240\240\16\13\240\144\3\24\121\40\23\22\5\3\240\240\240\0\61\240\112\3\24\121\40\23\6\21\3\240\240\240\0\109\16\13\240\16\3\8\121\56\23\6\5\4\3\240\240\240\157\240\32\3\8\121\40\39\6\5\4\3\240\240\224\157\240\48\3\8\121\40\23\22\5\3\240\240\192\157\240\80\3\24\121\40\23\22\5\3\240\240\112\205\240\112\3\24\121\40\23\22\5\3\240\240\32\125\32\77\240\144\3\8\121\56\23\6\5\4\3\240\208\141\80\61\240\176\3\8\121\40\39\6\5\4\3\240\192\77\160\29\240\208\3\8\121\40\23\22\5\3\240\192\13\224\13\240\224\3\24\121\40\23\22\5\3\240\240\240\240\192\3\24\121\40\23\22\5\3\240\240\240\240\192\3\24\121\40\23\6\5\4\3\240\240\240\240\192\3\8\121\40\39\6\5\4\3\240\240\240\240\192\3\8\121\40\39\6\5\3\240\240\240\240\208\3\8\121\40\23\22\5\3\240\240\240\240\192\3\24\121\40\23\22\5\3\240\240\240\240\192\3\24\121\40\23\6\21\3\240\240\240\240\192\3\8\121\56\23\6\5\4\3\240\240\240\240\192\3\8\121\40\39\6\5\4\3\240\240\240\240\192\3\8\121\24\7\70\3\240\240\240\240\192\3\24\105\8\118\3\240\240\240\240\192\3\24\89\150\3\240\240\240\240\192\3\8\73\166\3\240\240\240\240\208\3\8\41\182\3\240\240\240\240\224\3\8\9\8\182\3\240\240\240\240\224\3\24\7\166\3\240\240\240\240\240\0\3\8\182\3\240\240\240\240\240\16\3\166\3\240\240\240\240\240\48\3\134\19\240\240\240\240\240\64\3\102\3\240\240\240\240\240\112\19\22\35\240\240\240\240\240\160\19\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\224",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\0\51\240\240\240\240\240\112\51\55\3\240\240\240\240\240\48\35\135\3\240\240\240\240\240\35\199\3\240\240\240\240\224\3\231\3\240\240\240\240\224\3\8\231\3\240\240\240\240\208\3\8\247\3\240\240\240\240\192\3\24\247\3\240\240\240\240\176\3\40\247\3\240\240\240\240\160\3\56\231\3\240\240\240\240\160\3\72\231\3\240\240\240\240\144\3\72\247\3\240\240\240\240\128\3\88\247\3\240\240\240\240\112\3\104\247\3\240\240\240\240\96\3\120\247\3\240\240\240\240\80\3\136\231\3\240\240\240\240\96\3\120\247\3\240\240\240\240\96\3\120\247\3\240\240\240\240\80\3\136\247\3\240\240\240\240\80\3\136\247\3\240\240\240\240\80\3\136\231\3\240\240\240\240\96\3\120\247\3\240\240\240\240\96\3\120\247\3\240\240\240\240\80\3\136\247\3\240\240\240\240\80\3\136\247\3\240\240\240\240\80\3\136\231\3\240\240\240\240\96\3\136\231\3\240\240\224\13\240\96\3\120\247\3\240\240\208\61\240\48\3\136\247\3\240\240\208\109\16\13\208\3\136\247\3\240\240\192\157\224\3\136\231\3\240\240\192\157\240\3\136\231\3\240\240\160\141\240\32\3\136\231\3\240\240\80\189\240\64\3\120\247\3\240\240\16\125\0\77\240\80\3\136\247\3\240\192\125\64\61\240\112\3\136\247\3\240\128\125\128\29\240\144\3\136\231\3\240\128\61\192\13\240\176\3\136\231\3\240\112\13\240\240\208\3\120\247\3\240\240\240\240\80\3\136\247\3\240\240\240\240\80\3\136\247\3\240\240\240\240\80\3\136\231\3\240\240\240\240\96\3\136\231\3\240\240\240\240\96\3\120\247\3\240\240\240\240\80\3\136\247\3\240\240\240\240\80\3\136\199\22\3\240\240\240\240\96\3\136\119\86\3\240\240\240\240\112\3\136\55\134\3\240\240\240\240\128\3\120\7\182\3\240\240\240\240\144\3\104\198\3\240\240\240\240\144\3\104\198\3\240\240\240\240\160\3\88\198\3\240\240\240\240\176\3\72\198\3\240\240\240\240\192\3\56\198\3\240\240\240\240\208\3\40\198\3\240\240\240\240\208\3\40\198\3\240\240\240\240\224\3\24\166\35\240\240\240\240\240\3\8\118\35\240\240\240\240\240\48\3\54\51\240\240\240\240\240\112\51\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\0",
    "\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\160\19\240\240\240\240\240\208\3\7\3\240\240\240\240\240\192\3\8\7\3\240\240\240\240\240\176\3\24\7\3\240\240\240\240\240\160\3\40\3\240\240\240\240\240\160\3\56\3\240\240\240\240\240\144\3\56\7\3\240\240\240\240\240\128\3\72\7\3\240\240\240\240\240\112\3\88\7\3\240\240\240\240\240\96\3\104\3\240\240\240\240\240\96\3\120\3\240\240\240\240\240\80\3\120\7\3\240\240\240\240\240\64\3\136\7\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\32\3\168\7\3\240\240\240\240\240\32\3\168\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\32\3\168\7\3\240\240\240\240\240\32\3\168\3\240\240\240\240\240\48\3\168\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\32\3\168\7\3\240\240\240\240\240\32\3\168\3\240\240\240\240\240\48\3\168\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\32\3\168\7\3\240\240\240\240\240\32\3\168\3\240\240\240\80\13\240\192\3\168\3\240\240\240\64\77\240\144\3\152\7\3\240\240\240\64\125\32\13\240\32\3\152\7\3\240\240\240\48\189\240\32\3\168\7\3\240\240\240\32\189\240\48\3\168\7\3\240\240\240\0\173\240\96\3\168\3\240\240\208\205\240\128\3\168\3\240\240\128\125\0\93\240\176\3\152\7\3\240\240\48\141\48\77\240\208\3\152\7\3\240\224\141\112\61\240\224\3\168\7\3\240\208\77\192\29\240\240\0\3\168\3\240\208\13\240\0\13\240\240\32\3\168\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\32\3\168\7\3\240\240\240\240\240\32\3\168\3\240\240\240\240\240\48\3\168\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\32\3\168\7\3\240\240\240\240\240\32\3\168\7\3\240\240\240\240\240\32\3\168\3\240\240\240\240\240\48\3\152\7\3\240\240\240\240\240\48\3\152\3\240\240\240\240\240\64\3\136\3\240\240\240\240\240\64\3\136\3\240\240\240\240\240\80\3\120\3\240\240\240\240\240\96\3\104\3\240\240\240\240\240\112\3\88\3\240\240\240\240\240\128\3\72\3\240\240\240\240\240\128\3\72\3\240\240\240\240\240\144\3\56\3\240\240\240\240\240\160\3\40\3\240\240\240\240\240\176\3\24\3\240\240\240\240\240\192\3\8\3\240\240\240\240\240\192\3\8\3\240\240\240\240\240\208\19\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\240\112",
  },
  small = {
    "\240\240\208\63\240\144\31\39\6\31\240\80\31\56\23\22\31\240\48\15\8\25\56\7\6\5\15\240\32\15\89\24\23\6\5\15\240\16\15\9\26\11\26\9\24\7\6\5\15\240\0\15\25\10\11\28\11\9\24\7\6\5\4\15\240\15\9\10\11\44\11\9\24\7\6\5\4\15\240\15\9\26\44\11\9\24\7\6\5\4\15\240\15\25\10\43\10\9\8\23\6\5\4\15\240\0\15\25\26\25\24\7\22\5\15\240\16\15\8\57\24\23\6\5\4\15\240\32\15\56\39\6\5\4\15\240\48\31\55\22\5\4\31\240\80\31\22\21\31\240\144\63\240\240\208",
    "\240\240\224\47\240\160\31\39\15\240\128\15\72\15\240\112\15\8\73\8\15\240\96\15\41\26\25\15\240\80\15\25\26\27\10\9\8\15\240\64\15\25\10\11\28\11\10\9\15\240\64\15\9\26\44\11\10\9\15\240\64\15\25\10\11\28\11\10\9\15\240\64\15\25\26\27\10\9\24\15\240\64\15\41\10\25\24\7\15\240\64\15\8\41\40\23\15\240\80\15\72\23\6\15\240\96\15\55\22\5\15\240\112\31\38\5\4\15\240\144\79\240\240\160",
    "\240\240\160\79\240\144\15\24\7\22\31\240\112\15\40\23\6\5\15\240\96\15\56\23\6\5\15\240\80\15\72\23\6\5\15\240\64\15\72\23\6\5\15\240\64\15\88\7\6\5\4\15\240\64\15\72\7\6\5\4\15\240\64\15\72\7\6\5\4\15\240\64\15\72\7\6\5\4\15\240\64\15\72\22\5\4\15\240\80\15\56\7\5\4\15\240\96\15\56\6\5\4\15\240\112\15\40\6\4\15\240\128\15\40\31\240\160\47\240\240\224",
    "\240\240\176\63\240\144\31\6\7\22\31\240\112\15\21\39\6\5\15\240\96\15\22\7\8\23\6\5\15\240\80\15\6\23\24\7\22\4\15\240\64\15\7\24\25\23\6\5\15\240\64\15\7\8\9\26\23\6\5\15\240\80\15\8\10\11\12\8\7\6\5\4\15\240\64\15\9\10\28\9\7\6\5\4\15\240\64\15\9\10\11\12\10\7\6\5\4\15\240\64\15\8\9\10\11\10\6\5\4\15\240\96\15\57\6\5\4\15\240\96\15\56\5\4\15\240\128\15\40\20\15\240\128\15\39\31\240\160\47\240\240\224",
    "\240\240\240\32\63\240\160\15\5\7\22\31\240\112\15\21\6\23\6\5\15\240\96\15\6\71\6\5\15\240\80\15\6\23\24\23\6\5\15\240\32\15\0\15\23\8\9\8\23\6\5\15\240\80\15\8\9\26\8\7\6\5\4\15\240\64\15\8\9\10\12\9\7\6\5\4\15\240\64\15\9\10\11\12\11\7\6\5\4\15\240\64\15\8\9\11\12\11\7\6\5\4\15\240\80\15\9\26\11\7\6\5\15\144\15\176\15\8\41\7\5\4\15\96\79\160\15\8\23\9\6\5\4\15\96\47\32\15\16\15\96\15\40\6\4\15\240\96\31\0\15\23\31\240\176\31\240\240\112",
    "\240\240\208\15\240\208\15\8\15\240\176\15\40\15\240\160\15\56\15\240\144\15\56\15\240\144\15\56\15\240\144\15\72\15\240\144\15\56\15\240\144\15\56\15\240\144\15\72\15\240\144\15\56\15\240\144\15\56\15\240\144\15\56\15\240\160\15\40\15\240\176\15\8\15\240\208\15\240\240\208",
    "\240\240\240\48\31\240\176\31\24\15\240\144\15\7\24\9\15\240\128\15\40\41\15\240\96\15\24\41\26\15\240\80\15\24\41\26\27\15\240\48\15\8\41\26\59\15\240\32\15\8\25\10\107\15\240\16\15\25\10\107\42\15\240\15\9\10\75\42\57\15\208\31\10\43\26\57\72\15\192\15\10\11\26\25\152\7\15\192\63\215\15\240\0\95\118\15\240\96\95\21\15\240\192\31\240\240\96",
    "\240\240\144\31\240\192\15\24\47\240\144\15\40\6\4\47\240\96\15\56\53\31\240\64\15\56\6\69\47\240\16\15\56\7\85\4\15\240\16\15\72\37\36\15\240\48\15\56\6\52\15\240\64\15\56\7\52\15\240\64\15\56\7\36\15\240\80\15\72\20\15\240\112\15\56\4\15\240\128\15\56\15\240\160\15\40\15\240\176\15\8\15\240\208\15\240\240\240\0",
    "\240\240\144\191\240\48\15\151\15\240\48\15\151\15\240\48\15\151\15\240\48\15\151\15\240\48\15\151\15\240\48\15\151\15\240\48\15\151\15\240\48\15\151\15\240\48\15\151\15\240\48\15\151\15\240\48\15\151\15\240\48\15\150\15\240\48\15\150\15\240\48\15\150\15\240\48\191\240\240\144",
    "\240\240\240\240\224\31\240\192\15\23\15\240\160\15\55\15\240\112\31\87\31\240\64\15\151\15\240\32\15\183\15\240\16\15\8\151\5\15\240\16\15\24\119\5\4\15\240\16\15\40\87\5\20\15\240\32\15\40\55\5\20\15\240\64\31\24\23\5\4\31\240\112\15\24\5\4\15\240\160\15\8\4\15\240\192\31\240\240\240\240\224",
    "\240\240\208\63\240\160\15\55\15\240\128\15\87\15\240\112\15\71\6\15\240\112\15\24\23\6\4\15\240\112\15\40\7\6\4\15\240\112\15\40\7\6\4\15\240\112\15\40\7\6\4\15\240\112\15\40\7\6\4\15\240\112\15\40\7\6\4\15\240\112\15\40\7\6\4\15\240\112\15\40\7\6\4\15\240\112\15\40\7\6\4\15\240\112\15\40\7\6\4\15\240\128\15\24\7\6\15\240\160\63\240\240\208",
    "\240\240\240\32\31\240\160\47\23\15\240\80\63\71\15\240\32\47\87\56\15\240\0\15\8\71\104\15\240\0\15\216\15\240\15\216\15\240\15\152\55\15\240\15\104\103\15\240\15\56\103\38\15\240\15\56\55\70\5\15\240\0\15\40\7\70\37\4\15\240\0\15\40\22\37\20\47\240\32\15\24\21\4\63\240\80\15\24\47\240\160\31\240\240\240\32",
    "\240\240\240\240\240\240\240\32\175\112\207\103\31\112\31\39\22\183\22\15\128\15\8\9\40\167\22\5\31\144\15\9\26\9\8\103\54\5\31\160\15\9\10\27\10\9\8\39\54\21\31\192\15\9\11\28\10\9\8\7\54\21\31\224\15\9\10\27\10\8\7\38\21\4\15\240\16\15\41\24\7\6\21\4\31\240\32\15\56\7\6\5\4\31\240\80\15\39\6\5\31\240\128\79\240\240\240\240\240\240\240\80",
    "\240\240\240\240\192\15\240\224\31\240\208\15\8\15\240\192\15\24\15\240\176\15\40\15\240\160\15\40\15\240\160\15\56\15\240\144\15\56\15\240\160\15\40\15\240\160\15\40\15\240\176\15\24\15\240\192\15\8\15\240\208\31\240\224\15\240\240\240\240\192",
    "\240\240\160\15\240\208\15\8\15\240\176\15\25\7\15\240\176\15\9\8\7\15\240\176\15\9\8\7\15\240\160\15\25\8\6\15\240\160\15\25\8\15\240\176\15\25\8\15\240\176\15\25\7\15\240\176\15\9\8\7\15\240\160\15\25\8\7\15\240\160\15\25\8\15\240\176\15\25\7\15\240\176\15\7\22\15\240\176\15\6\15\240\208\15\240\240\160",
    "\240\240\240\240\144\63\240\176\15\39\15\240\160\15\55\15\240\144\15\8\39\15\240\160\15\8\39\15\240\144\15\24\39\15\240\144\15\24\39\15\240\144\15\8\55\15\240\144\15\8\55\15\240\144\15\8\39\15\240\160\15\8\39\15\240\144\15\24\22\15\240\160\15\8\22\15\240\176\63\240\240\240\240\144",
    "\240\240\240\240\160\15\240\224\31\240\208\15\8\15\240\208\15\8\15\240\192\15\8\15\240\208\15\8\15\240\208\15\8\15\240\208\15\8\15\240\208\15\8\15\240\208\15\8\15\240\192\15\8\15\240\208\15\8\15\240\208\31\240\224\15\240\240\240\240\160",
  },
}
-- =====================================================================
-- FLUJOS v2.1: arrastre y sustentacion, vertedores y orificios, canales
-- y medicion (traducido de drag.c, weir.c, chan.c, scr_*.c, memo_*.c)
-- =====================================================================
ERR.ARG = "Dato invalido: revise los valores"
ERR.FLOATS = "W <= B: el cuerpo flota, no cae"
ERR.NOJUMP = "Fr1 <= 1: no hay salto hidraulico"
DEG2RAD = 0.01745329251994

-- ---------------- arrastre (drag.c) ----------------
-- (cada resultado intermedio se redondea con r3)
function drag_q(rho, V) return r3(0.5 * rho * V * V) end
function drag_force(rho, Cc, A, V) return r3(drag_q(rho, V) * Cc * A) end
function drag_re(V, L, nu) if nu > 0 then return r3(abs(V) * L / nu) end return 0 end

-- kind: 0 generico, 1 esfera, 2 cilindro largo
function drag_re_warn(Re, kind)
  local w = {}
  if Re < 1 then w.stokes = true end
  if Re < 1e4 then w.relow = true end
  if (kind == 1 and Re > 2e5) or (kind == 2 and Re > 5e5) then w.crisis = true end
  return w
end

function wmerge(a, b) for k, x in pairs(b) do if x then a[k] = true end end return a end

-- interpolacion en tabla creciente: valor e indice del vecino de abajo
function drag_interp(x, y, xv, w)
  local n = #x
  if xv <= x[1] then
    if xv < x[1] then w.clamp = true end
    return y[1], 1
  end
  if xv >= x[n] then
    if xv > x[n] then w.clamp = true end
    return y[n], n - 1
  end
  local i = 1
  while i < n - 1 and xv > x[i + 1] do i = i + 1 end
  w.interp = true
  return r3(y[i] + (y[i + 1] - y[i]) * (xv - x[i]) / (x[i + 1] - x[i])), i
end

function drag_terminal(Wt, rho, vol, Cd, A, Lref, nu, g, kind)
  if not (Wt > 0) or not (rho > 0) or not (Cd > 0) or not (A > 0) or
     not (vol >= 0) or not (g > 0) then herr(ERR.ARG) end
  local r = {warn = {}}
  r.B = r3(rho * g * vol)
  if vol > 0 then r.warn.buoy = true end
  r.net = r3(Wt - r.B)
  if not (r.net > 0) then herr(ERR.FLOATS) end
  r.v = r3(sqrt(2 * r.net / (rho * Cd * A)))
  r.Re = drag_re(r.v, Lref, nu)
  wmerge(r.warn, drag_re_warn(r.Re, kind))
  return r
end

function drag_struct(bodies, rho, nu)
  local n = #bodies
  if n < 1 or n > 6 or not (rho > 0) then herr(ERR.ARG) end
  local r = {F = {}, Re = {}, w = {}, Ftot = 0, M = 0, ycp = 0, warn = {}}
  for i, b in ipairs(bodies) do
    if not (b.Cd >= 0) or not (b.A >= 0) then herr(ERR.ARG) end
    r.F[i] = drag_force(rho, b.Cd, b.A, b.V)
    r.Re[i] = drag_re(b.V, b.Lref, nu)
    r.w[i] = drag_re_warn(r.Re[i], b.kind)
    wmerge(r.warn, r.w[i])
    r.Ftot = r3(r.Ftot + r.F[i])
    r.M = r3(r.M + r3(r.F[i] * b.y))
  end
  if r.Ftot > 0 then r.ycp = r3(r.M / r.Ftot) end
  return r
end

function drag_rho_alt(h)
  local t = 1 - 2.26e-5 * h
  if t > 0 then return r3(1.3 * t ^ 4.256) end
  return 0
end

function drag_plane_lift(Wt, rho, V, Aw, nw)
  if not (Wt > 0) or not (rho > 0) or not (V > 0) or not (Aw > 0) or nw < 1 then herr(ERR.ARG) end
  local r = {}
  r.q = drag_q(rho, V)
  r.Atot = r3(Aw * nw)
  r.CL = r3(Wt / (r.q * r.Atot))
  return r
end

function drag_plane_thrust(r, Wt, rho, V, CDw, CDf, Df, CLmax)
  if not (CDw >= 0) or not (CDf >= 0) or not (Df >= 0) or not (r.Atot > 0) then herr(ERR.ARG) end
  r.Afus = area(Df)
  r.Dw = r3(r.q * r.Atot * CDw)
  r.Df = r3(r.q * CDf * r.Afus)
  r.T = r3(r.Dw + r.Df)
  r.P = r3(r.T * V)
  r.Vst = (CLmax > 0) and r3(sqrt(2 * Wt / (rho * CLmax * r.Atot))) or 0
  return r
end

function drag_stokes(mu, V, D) return r3(3 * pi * mu * V * D) end

-- mode: 0 auto, 1 laminar, 2 turbulento, 3 mixto
function drag_plate(L, w, V, rho, nu, faces, mode)
  if not (L > 0) or not (w > 0) or not (V > 0) or not (rho > 0) or not (nu > 0) or
     faces < 1 or faces > 2 then herr(ERR.ARG) end
  local r = {warn = {}}
  r.Re = r3(V * L / nu)
  r.Cf_lam = r3(1.328 / sqrt(r.Re))
  r.Cf_turb = r3(0.074 / r.Re ^ 0.2)
  r.Cf_mix = r3(r.Cf_turb - 1742 / r.Re)
  if r.Re > 5e5 then r.warn.lamna = true end
  if r.Re > 1e7 then r.warn.turbna = true end
  if mode == 0 then mode = (r.Re < 5e5) and 1 or 2 end
  r.regime = mode
  if mode == 1 then r.Cf = r.Cf_lam elseif mode == 3 then r.Cf = r.Cf_mix else r.Cf = r.Cf_turb end
  r.A = r3(L * w)
  r.F = r3(r.Cf * drag_q(rho, V) * r.A * faces)
  return r
end

-- ---------------- catalogo de CD (dragcat.c) ----------------
AR_CIRC, AR_SQ, AR_LD, AR_BH, AR_SQ2 = 1, 2, 3, 4, 5
AREA_TXT = {"pi D^2/4", "D^2", "L D", "b h", "sqrt(2) D^2"}
-- nombre, orientacion, CD, area, kind, tabla, stokes, fuente, nota
SHAPES = {
  {"Esfera lisa", "cualquier orientacion", 0.5, AR_CIRC, 1, 0, 24, "Cengel 11-2",
   "White 0.47. Crisis de arrastre: CD 0.2|si Re > 2E5 (Cengel turbulento)"},
  {"Hemisferio convexo", "domo hacia el flujo", 0.4, AR_CIRC, 0, 0, 0, "Cengel 11-2", "White 0.42"},
  {"Hemisferio plano", "cara plana hacia el flujo", 1.17, AR_CIRC, 0, 0, 0, "Cengel 11-2", "White 1.15"},
  {"Copa hemisferica hueca", "abierta hacia el flujo", 1.42, AR_CIRC, 0, 0, 0, "Fox/Munson",
   "Abierta hacia atras: CD 0.38"},
  {"Paracaidas", "abierto, D del dosel", 1.3, AR_CIRC, 0, 0, 0, "Cengel 11-2",
   "Copa hueca 1.42 (figura 4). La Tarea|4-2 P1 no da CD: el curso usa 1.3"},
  {"Disco delgado", "normal al flujo", 1.1, AR_CIRC, 0, 0, 20.4, "Cengel 11-2",
   "White 1.17. Stokes: 20.4/Re normal,|13.6/Re paralelo al flujo"},
  {"Cono, punta al flujo", "angulo total 30 grados", 0.5, AR_CIRC, 0, 4, 0, "Cengel 11-2",
   "Tabla por angulo total (White);|escriba el angulo en grados"},
  {"Cono, base al flujo", "base plana hacia el flujo", 1.15, AR_CIRC, 0, 0, 0, "White", ""},
  {"Cubo, cara al flujo", "una cara normal al flujo", 1.05, AR_SQ, 0, 0, 0, "Cengel 11-2", "White 1.07"},
  {"Cubo, arista al flujo", "girado 45 grados", 0.80, AR_SQ2, 0, 0, 0, "Cengel 11-2",
   "White 0.81. Area proyectada sqrt(2)D^2;|las tablas usan D^2 (escriba A)"},
  {"Cilindro finito perpend.", "eje normal al flujo", 0.9, AR_LD, 2, 1, 0, "Cengel 11-2",
   "Tabla por L/D; L/D >= 1000: infinito|(1.2). Valor inicial: L/D = 10"},
  {"Cilindro, cara al flujo", "eje paralelo al flujo", 0.9, AR_CIRC, 0, 2, 0, "Cengel 11-2", "Tabla por L/D"},
  {"Cuerpo aerodinamico", "forma de gota, punta atras", 0.04, AR_CIRC, 0, 0, 0, "Cengel 11-2", ""},
  {"Placa rectangular", "normal al flujo", 1.18, AR_BH, 0, 3, 0, "Fox/Munson",
   "Tabla por b/h; b/h >= 1000: 1.98.|Valor inicial: b/h = 1"},
  {"Cilindro largo (2D)", "eje normal, por metro", 1.2, AR_LD, 2, 0, 0, "Cengel 11-1",
   "Re > 5E5 (turbulento): CD 0.3,|crisis de arrastre"},
  {"Barra cuadrada larga (2D)", "cara al flujo, esquinas vivas", 2.2, AR_LD, 0, 0, 0, "Cengel 11-1", ""},
  {"Placa plana larga (2D)", "normal al flujo, por metro", 1.9, AR_LD, 0, 0, 0, "Cengel 11-1", "Fox/Munson 1.98"},
}
CD_TABLES = {
  {"L/D", {1, 2, 5, 10, 40}, {0.6, 0.7, 0.8, 0.9, 1.0}, 1.2},
  {"L/D", {0.5, 1, 2, 4, 8}, {1.1, 0.9, 0.9, 0.9, 1.0}, 0},
  {"b/h", {1, 5, 10, 20}, {1.18, 1.2, 1.3, 1.5}, 1.98},
  {"angulo", {10, 20, 30, 40, 60, 75, 90}, {0.30, 0.40, 0.55, 0.65, 0.80, 1.05, 1.15}, 0},
}
CDU = {}   -- CD propios (0 = el del catalogo)

function dragcat_cd(i)
  if not SHAPES[i] then return 0 end
  if (CDU[i] or 0) > 0 then return CDU[i] end
  return SHAPES[i][3]
end

function dragcat_table(i)
  local s = SHAPES[i]
  if s and s[6] > 0 then return CD_TABLES[s[6]] end
  return nil
end

-- CD por parametro: valor y vecinos
function dragcat_param(i, p, w)
  local t = dragcat_table(i)
  if not t then return dragcat_cd(i), 0, 0, 0, 0 end
  if t[4] > 0 and p >= 1000 then return t[4], p, t[4], p, t[4] end
  local v, k = drag_interp(t[2], t[3], p, w)
  return v, t[2][k], t[3][k], t[2][k + 1], t[3][k + 1]
end

function dragcat_area(ar, a, b)
  if ar == AR_CIRC then return area(a) end
  if ar == AR_SQ then return r3(a * a) end
  if ar == AR_SQ2 then return r3(1.41421356 * a * a) end
  return r3(a * b)
end

-- ---------------- vertedores (weir.c) ----------------
WE_TRI, WE_RECT, WE_ORC, WE_ORR = 1, 2, 3, 4
ET_NAMES = {"Triangular", "Rectangular", "Orificio circ.", "Orificio rect."}

function weir_check(e)
  if not ET_NAMES[e.type] or e.count < 1 or not (e.Cd > 0) or not (e.a > 0) or e.ncon > 2 then return false end
  if e.type == WE_TRI and not (e.a < 180) then return false end
  if e.type == WE_ORR and not (e.b > 0) then return false end
  if (e.type == WE_TRI or e.type == WE_RECT) and not (e.b >= 0) then return false end
  return true
end

function weir_k(e, g)
  local s = sqrt(2 * g) * e.Cd * e.count
  if e.type == WE_TRI then return r3(s * (8 / 15) * math.tan(0.5 * e.a * DEG2RAD)) end
  return r3(s * (2 / 3) * e.a)
end

function weir_q(e, h, g, w)
  local hc = r3(h - e.z)
  if not (hc > 0) then w.dry = true; return 0, 0 end
  local s = sqrt(2 * g)
  if e.type == WE_TRI then
    if e.b > 0 and hc > e.b then w.high = true end
    return r3(weir_k(e, g) * hc ^ 2.5), hc
  elseif e.type == WE_RECT then
    if e.b > 0 and hc > e.b then w.high = true end
    local be = e.a
    if e.ncon > 0 then
      w.francis = true
      be = r3(be - 0.1 * e.ncon * hc)
      if not (be > 0) then w.beneg = true; return 0, hc end
    end
    return r3(r3(e.Cd * e.count * (2 / 3) * s * be) * hc ^ 1.5), hc
  end
  local A, half
  if e.type == WE_ORC then A = area(e.a); half = 0.5 * e.a
  else A = r3(e.a * e.b); half = 0.5 * e.b end
  if hc < half then w.partial = true end
  return r3(r3(e.Cd * e.count * A * s) * sqrt(hc)), hc
end

function weir_total(els, h, g, w)
  if #els < 1 or #els > 8 or not (g > 0) then herr(ERR.ARG) end
  for _, e in ipairs(els) do if not weir_check(e) then herr(ERR.ARG) end end
  local Q, Qi = 0, {}
  for i, e in ipairs(els) do
    Qi[i] = weir_q(e, h, g, w)
    Q = r3(Q + Qi[i])
  end
  return Q, Qi
end

function weir_level(els, Q, g, w)
  if #els < 1 or #els > 8 or not (g > 0) then herr(ERR.ARG) end
  for _, e in ipairs(els) do if not weir_check(e) then herr(ERR.ARG) end end
  if not (Q > 0) then herr(ERR.Q) end
  local e1 = els[1]
  if #els == 1 and (e1.type == WE_TRI or (e1.type == WE_RECT and e1.ncon == 0)) then
    local q = r3(Q / weir_k(e1, g))
    local h = r3(e1.z + q ^ ((e1.type == WE_TRI) and 0.4 or (2 / 3)))
    local _, Qi = weir_total(els, h, g, w)
    return h, Qi, 0
  end
  local zmin = els[1].z
  for _, e in ipairs(els) do if e.z < zmin then zmin = e.z end end
  local lo, hi = zmin, zmin + 1
  local ok = false
  for _ = 1, 40 do
    local q = weir_total(els, hi, g, {})
    if q >= Q then ok = true; break end
    lo = hi
    hi = zmin + 2 * (hi - zmin)
  end
  if not ok then herr(ERR.NOROOT) end
  local it = 0
  for k = 1, 200 do
    it = k
    local mid = r3(0.5 * (lo + hi))
    local q = weir_total(els, mid, g, {})
    if q == Q then lo, hi = mid, mid; break end
    if q > Q then hi = mid else lo = mid end
    local nm = r3(0.5 * (lo + hi))
    if q == Q or nm == lo or nm == hi then break end
  end
  local h = r3(0.5 * (lo + hi))
  local _, Qi = weir_total(els, h, g, w)
  return h, Qi, it
end

function weir_profile_pow(k, n, b, h)
  if not (k > 0) or not (n >= 0) or not (b > 0) or not (h > 0) then herr(ERR.ARG) end
  local Q = r3(b * k * h ^ (n + 1) / (n + 1))
  return Q, r3(Q / (b * h))
end

function weir_profile_pts(y, v, b)
  local n = #y
  if n < 2 or not (b > 0) then herr(ERR.ARG) end
  for i = 2, n do if not (y[i] > y[i - 1]) then herr(ERR.ARG) end end
  local dy = r3((y[n] - y[1]) / (n - 1))
  local eq = true
  for i = 2, n do if abs(y[i] - y[i - 1] - dy) > 1e-4 * dy + 1e-9 then eq = false end end
  local simpson = eq and n >= 3 and (n % 2 == 1)
  local s = 0
  if simpson then
    for i = 1, n do
      local c = (i == 1 or i == n) and 1 or ((i % 2 == 0) and 4 or 2)
      s = s + v[i] * c
    end
    s = r3(s * dy / 3)
  else
    for i = 2, n do s = r3(s + 0.5 * (v[i] + v[i - 1]) * (y[i] - y[i - 1])) end
  end
  local Q = r3(b * s)
  return Q, r3(Q / (b * (y[n] - y[1]))), simpson
end

function weir_section(Q, b, h, g)
  if not (Q > 0) or not (b > 0) or not (h > 0) or not (g > 0) then herr(ERR.ARG) end
  local v = r3(Q / (b * h))
  return v, r3(h + v * v / (2 * g))
end

function alt_bis(q, E, g, lo, hi)
  local f0 = lo + q * q / (2 * g * lo * lo) - E
  for _ = 1, 80 do
    local m = r3(0.5 * (lo + hi))
    local fm = m + q * q / (2 * g * m * m) - E
    if (fm > 0) == (f0 > 0) then lo = m; f0 = fm else hi = m end
    local nm = r3(0.5 * (lo + hi))
    if nm == lo or nm == hi then break end
  end
  return r3(0.5 * (lo + hi))
end

function weir_alt_depths(q, E, g)
  if not (q > 0) or not (E > 0) or not (g > 0) then herr(ERR.ARG) end
  local hc = r3((q * q / g) ^ (1 / 3))
  if E < 1.5 * hc then return nil, nil, hc end
  return alt_bis(q, E, g, hc, E), alt_bis(q, E, g, hc * 1e-3, hc), hc
end

-- ---------------- canales (chan.c) ----------------
-- conv: 1 fisico (S-1), 2 examen (S)
function chan_venturi(D1, D2, Q, Cv, S, conv)
  if not (D1 > 0) or not (D2 > 0) or not (D2 < D1) or not (Q > 0) or not (Cv > 0) or
     not (Cv <= 1) or not (S >= 0) then herr(ERR.ARG) end
  local rho = r3(CFG.gamma / CFG.g)
  local r = {}
  r.A1, r.A2 = area(D1), area(D2)
  r.v1, r.v2 = r3(Q / r.A1), r3(Q / r.A2)
  r.beta = r3(D2 / D1)
  local b4 = r3(r.beta ^ 4)
  if Cv == 1 then
    r.dp = r3(CFG.gamma * (r.v2 * r.v2 - r.v1 * r.v1) / (2 * CFG.g))
  else
    local u = r3(Q / (Cv * r.A2))
    r.dp = r3(0.5 * rho * u * u * (1 - b4))
  end
  r.h = 0
  if S > 0 then
    local u = (conv == 2) and S or (S - 1)
    if not (u > 0) then herr(ERR.ARG) end
    r.h = r3(r.dp / (u * CFG.gamma))
  end
  return r
end

function chan_jump(Q, b, y, from_y2)
  local g = CFG.g
  if not (Q > 0) or not (b > 0) or not (y > 0) then herr(ERR.ARG) end
  local r = {}
  r.q = r3(Q / b)
  local v = r3(r.q / y)
  local Fr = r3(v / sqrt(g * y))
  if not from_y2 then
    if not (Fr > 1) then herr("Fr1 <= 1: no hay salto hidraulico") end
    r.y1 = y
    r.y2 = r3(0.5 * y * (sqrt(1 + 8 * Fr * Fr) - 1))
  else
    if not (Fr < 1) then herr("Fr2 >= 1: y2 no es subcritico") end
    r.y2 = y
    r.y1 = r3(0.5 * y * (sqrt(1 + 8 * Fr * Fr) - 1))
  end
  r.v1, r.v2 = r3(r.q / r.y1), r3(r.q / r.y2)
  r.Fr1, r.Fr2 = r3(r.v1 / sqrt(g * r.y1)), r3(r.v2 / sqrt(g * r.y2))
  r.E1 = r3(r.y1 + r.v1 * r.v1 / (2 * g))
  r.E2 = r3(r.y2 + r.v2 * r.v2 / (2 * g))
  r.dE = r3(r.E1 - r.E2)
  r.P = r3(CFG.gamma * Q * r.dE)
  r.eff = r3(r.E2 / r.E1)
  return r
end

function chan_jet(v, theta, g)
  if not (v > 0) or not (g > 0) or not (theta >= 0) or not (theta <= 90) then herr(ERR.ARG) end
  local a = theta * DEG2RAD
  local r = {}
  r.vx, r.vy = r3(v * math.cos(a)), r3(v * math.sin(a))
  r.hmax = r3(r.vy * r.vy / (2 * g))
  r.R = r3(2 * r.vx * r.vy / g)
  r.t = r3(2 * r.vy / g)
  return r
end

-- ============ MEMORIAS DE FLUJOS (memo_drag.c, memo_weir.c, memo_chan.c) ============
DFL = prog(
  DAT("rho", "RHO", "kg/m3"), DAT("nu", "NU", "m2/s"),
  IF("DVCONV"), LN(" V dada = {VIN} (km/h o nudos)", "gray"), ENDIF,
  DAT("V", "VEL", "m/s"))
DSHP = prog(
  IF("DFIG"), LN(" Figura del catalogo de CD", "gray"), ENDIF,
  DAT("CD", "CDV"),
  IF("DACALC"), LN(" A = {TXT}  (D = {DIM1!}, L/b = {DIM2!})"), ENDIF,
  DAT("A", "AREF", "m2"),
  DAT("L para Re", "LREF", "m"))
DWARN = prog(
  IF("DSTK"), LN("! Re < 1: se uso Stokes (CD = k/Re)", "warn"), ENDIF,
  IF("DRE1"), IFN("DSTK"), LN("! Re < 1: flujo lento (Stokes)", "warn"), ENDIF, ENDIF,
  IF("DRELOW"), IFN("DRE1"), LN("! Re < 1E4: fuera del rango de la tabla", "warn"), ENDIF, ENDIF,
  IF("DCRIS"), LN("! Posible crisis de arrastre: el CD", "warn"),
               LN("  puede ser mucho menor; revise", "warn"), ENDIF,
  IFN("DRELOW"), IFN("DCRIS"), LN(" Re > 1E4: CD de la tabla valido", "ok"), ENDIF, ENDIF)

X_AR1_SUM = prog(
  DAT("q = 0.5 rho V^2", "QDYN", "Pa"), DAT("Re", "RE"),
  IFN("DLIFT"), RES("FD", "FD", "N"), ENDIF,
  IF("DLIFT"), RES("FL", "FD", "N"), ENDIF,
  SEPx, DWARN)
X_AR1_MEMO = prog(
  SEC("DATOS"), DFL, DSHP,
  IF("DLIFT"), LN(" (CL en lugar de CD; A = area en planta)", "gray"), ENDIF,
  SEC("CALCULOS"),
  EQ("q", "0.5 rho V^2", "0.5({RHO})({VEL})^2", "QDYN", "Pa"),
  EQ("Re", "V L/nu", "{VEL}({LREF})/{NU}", "RE"),
  IF("DSTK"), EQ("CD", "k/Re (Stokes)", "{KST}/{RE}", "CDV"), ENDIF,
  IFN("DLIFT"), EQ("FD", "CD q A", "{CDV}({QDYN})({AREF})", "FD", "N"), ENDIF,
  IF("DLIFT"), EQ("FL", "CL q A", "{CDV}({QDYN})({AREF})", "FD", "N"), ENDIF,
  SEC("RESULTADO"),
  IFN("DLIFT"), RES("FD", "FD", "N"), ENDIF,
  IF("DLIFT"), RES("FL", "FD", "N"), ENDIF,
  SEC("OBSERVACIONES"), DWARN)

X_AR2_SUM = prog(
  DAT("W", "W", "N"),
  IF("DBUOY"), DAT("B", "BUOY", "N"), DAT("W - B", "NET", "N"), ENDIF,
  RES("v terminal", "VT", "m/s"), RES("v terminal", "VTKMH", "km/h"),
  DAT("Re", "RE"), SEPx, DWARN)
X_AR2_MEMO = prog(
  SEC("DATOS"),
  DAT("rho", "RHO", "kg/m3"), DAT("nu", "NU", "m2/s"), DAT("W", "W", "N"),
  IF("DBUOY"), DAT("Volumen", "VOL", "m3"), ENDIF,
  DSHP,
  SEC("CALCULOS"),
  IF("DBUOY"),
    EQ("B", "rho g Vol", "{RHO}({G})({VOL})", "BUOY", "N"),
    EQ("W - B", nil, "{W} - {BUOY}", "NET", "N"),
  ENDIF,
  IFN("DBUOY"), LN(" Empuje despreciable (aire): W - B = W", "gray"), ENDIF,
  LN(" Equilibrio: W - B = FD = 0.5 rho CD A v^2"),
  IFN("DSTK"),
    EQ("v", "sqrt[2(W-B)/(rho CD A)]", "sqrt[2({NET})/({RHO}({CDV})({AREF}))]", "VT", "m/s"),
  ENDIF,
  IF("DSTK"),
    LN(" Re < 1: FD = 0.5 rho (k nu/(v L)) A v^2"),
    EQ("v", "2(W-B) L/(rho k nu A)", "2({NET})({LREF})/({RHO}({KST})({NU})({AREF}))", "VT", "m/s"),
  ENDIF,
  EQ("Re", "v L/nu", "{VT}({LREF})/{NU}", "RE"),
  SEC("RESULTADO"),
  RES("v terminal", "VT", "m/s"), RES("v terminal", "VTKMH", "km/h"),
  SEC("OBSERVACIONES"), DWARN)

X_AR3_SUM = prog(
  DAT("q = 0.5 rho V^2", "QDYN", "Pa"),
  RES("F total", "FTOT", "kN"), RES("M en la base", "MOM", "kN m"), RES("ycp = M/F", "YCP", "m"),
  SEPx, DWARN)
X_AR3_MEMO = prog(
  SEC("DATOS"), DFL,
  SEC("CALCULOS"),
  EQ("q", "0.5 rho V^2", "0.5({RHO})({VEL})^2", "QDYN", "Pa"),
  LN("Cuerpos: Fi = CDi q Ai (Vi propia si se dio)"),
  TAB("hook"),
  EQ("F", "suma Fi", nil, "FTOT", "kN"),
  EQ("M", "suma Fi yi", nil, "MOM", "kN m"),
  EQ("ycp", "M/F", "{MOM}/{FTOT}", "YCP", "m"),
  SEC("RESULTADO"),
  RES("F total", "FTOT", "kN"), RES("M en la base", "MOM", "kN m"), RES("ycp", "YCP", "m"),
  SEC("OBSERVACIONES"), DWARN)

X_AR4_SUM = prog(
  DAT("rho", "RHO", "kg/m3"), DAT("q", "QDYN", "Pa"),
  RES("CL necesario", "CL"),
  IFN("DSTEP2"),
    LN("> Lea alfa y CD en la grafica con", "warn"),
    LN("  CL = {CL!}; escribalos y CALCULAR", "warn"),
  ENDIF,
  IF("DSTEP2"),
    DAT("D alas", "DWING", "kN"), DAT("D fuselaje", "DFUS", "kN"),
    RES("Empuje T", "THR", "kN"), RES("Potencia P", "PWR", "MW"),
    IF("DVST"), RES("V perdida", "VST", "m/s"), ENDIF,
  ENDIF)
X_AR4_MEMO = prog(
  SEC("DATOS"),
  DAT("W", "W", "N"),
  IF("DVCONV"), LN(" V dada = {VIN} (km/h o nudos)", "gray"), ENDIF,
  DAT("V", "VEL", "m/s"),
  IF("DALT"), DAT("h", "ALT", "m"), ENDIF,
  IFN("DALT"), DAT("rho", "RHO", "kg/m3"), ENDIF,
  DAT("n alas", "NW"), DAT("A de un ala", "AW", "m2"),
  DAT("CD fuselaje", "CDF"), DAT("D fuselaje", "DF", "m"),
  SEC("CALCULOS"),
  IF("DALT"), EQ("rho", "1.3(1 - 2.26E-5 h)^4.256", "1.3(1 - 2.26E-5({ALT}))^4.256", "RHO", "kg/m3"), ENDIF,
  EQ("q", "0.5 rho V^2", "0.5({RHO})({VEL})^2", "QDYN", "Pa"),
  EQ("A", "n A ala", "{NW}({AW})", "ATOT", "m2"),
  LN(" Vuelo nivelado: L = W"),
  EQ("CL", "W/(q A)", "{W}/({QDYN}({ATOT}))", "CL"),
  IFN("DSTEP2"),
    LN("> Lea alfa y CD en la grafica con", "warn"),
    LN("  CL = {CL!}; escribalos y CALCULAR", "warn"),
  ENDIF,
  IF("DSTEP2"),
    LN(" Grafica: alfa = {ALPHA!} grad, CD = {CDW!}", "gray"),
    EQ("D alas", "CD q A", "{CDW}({QDYN})({ATOT})/1000", "DWING", "kN"),
    EQ("Af", "pi D^2/4", "pi({DF})^2/4", "AFUS", "m2"),
    EQ("D fus", "CDf q Af", "{CDF}({QDYN})({AFUS})/1000", "DFUS", "kN"),
    EQ("T", "D alas + D fus", "{DWING} + {DFUS}", "THR", "kN"),
    EQ("P", "T V", "{THR}({VEL})/1000", "PWR", "MW"),
    IF("DVST"), EQ("V perd", "sqrt[2W/(rho CLmax A)]", "sqrt[2({W})/({RHO}({CLMAX})({ATOT}))]", "VST", "m/s"), ENDIF,
  ENDIF,
  SEC("RESULTADO"),
  RES("CL necesario", "CL"),
  IF("DSTEP2"),
    RES("Empuje T", "THR", "kN"), RES("Potencia P", "PWR", "MW"),
    IF("DVST"), RES("V perdida", "VST", "m/s"), RES("V perdida", "VTKMH", "km/h"), ENDIF,
  ENDIF,
  SEC("OBSERVACIONES"),
  LN(" alfa y CD se leen en la grafica del", "gray"),
  LN(" perfil (entrada manual)", "gray"))

PWARN = prog(
  IF("PSTK"), IF("DRE1"), LN("! Re >= 1: Stokes no aplica", "warn"), ENDIF,
              IFN("DRE1"), LN(" Re < 1: Stokes valido", "ok"), ENDIF, ENDIF,
  IFN("PSTK"),
    IF("PLAMNA"), LN("! Re > 5E5: Cf laminar no aplica", "warn"), ENDIF,
    IF("PTURBNA"), LN("! Re > 1E7: fuera de 0.074/Re^0.2", "warn"), ENDIF,
    IF("PLAM"), IFN("PLAMNA"), LN(" Laminar: Re < 5E5", "ok"), ENDIF, ENDIF,
  ENDIF)
X_PL_SUM = prog(
  DAT("Re", "RE"),
  IF("PSTK"), DAT("CD = 24/Re", "CDV"), ENDIF,
  IFN("PSTK"),
    DAT("Cf laminar", "CFL"), DAT("Cf turbulento", "CFT"), DAT("Cf mixto", "CFM"),
    IF("PLAM"), LN(" Se usa: laminar", "gray"), ENDIF,
    IF("PTURB"), LN(" Se usa: turbulento", "gray"), ENDIF,
    IF("PMIX"), LN(" Se usa: mixto", "gray"), ENDIF,
  ENDIF,
  RES("FD", "FD", "N"), SEPx, PWARN)
X_PL_MEMO = prog(
  SEC("DATOS"), DFL,
  IF("PSTK"), DAT("D esfera", "DIM1", "m"), ENDIF,
  IFN("PSTK"), DAT("L placa", "DIM1", "m"), DAT("w", "DIM2", "m"), DAT("Caras", "FACES"), ENDIF,
  SEC("CALCULOS"),
  EQ("Re", "V L/nu", "{VEL}({DIM1})/{NU}", "RE"),
  IF("PSTK"),
    EQ("mu", "rho nu", "{RHO}({NU})", "MU", "Pa s"),
    EQ("FD", "3 pi mu V D", "3 pi({MU})({VEL})({DIM1})", "FD", "N"),
    EQ("CD", "24/Re", "24/{RE}", "CDV"),
  ENDIF,
  IFN("PSTK"),
    EQ("Cf lam", "1.328/sqrt(ReL)", "1.328/sqrt({RE})", "CFL"),
    EQ("Cf turb", "0.074/ReL^0.2", "0.074/{RE}^0.2", "CFT"),
    EQ("Cf mixto", "0.074/ReL^0.2 - 1742/ReL", "{CFT} - 1742/{RE}", "CFM"),
    IF("PLAM"), LN(" Se usa Cf laminar", "gray"), ENDIF,
    IF("PTURB"), LN(" Se usa Cf turbulento", "gray"), ENDIF,
    IF("PMIX"), LN(" Se usa Cf mixto", "gray"), ENDIF,
    EQ("q", "0.5 rho V^2", "0.5({RHO})({VEL})^2", "QDYN", "Pa"),
    EQ("A", "L w", "{DIM1}({DIM2})", "APL", "m2"),
    EQ("FD", "Cf q A (caras)", "{CF}({QDYN})({APL})({FACES})", "FD", "N"),
  ENDIF,
  SEC("RESULTADO"), RES("FD", "FD", "N"),
  SEC("OBSERVACIONES"), PWARN)

WWARN = prog(
  IF("WPART"), LN("! Nivel bajo el borde superior de un", "warn"),
               LN("  orificio: la formula deja de valer", "warn"), ENDIF,
  IF("WHIGH"), LN("! H mayor que la altura del vertedero", "warn"), ENDIF,
  IF("WFRAN"), LN(" Contracciones laterales (Francis):", "gray"),
               LN("  be = b - 0.1 n H = {WBE!} m", "gray"), ENDIF)
WFORM = prog(
  IF("WTRI"),
    LN("Q = Cd (8/15) sqrt(2g) tan(theta/2) H^(5/2)"),
    EQ("K", "Cd (8/15) sqrt(2g) tan(theta/2)", "{WCD}(8/15)sqrt(2({G}))({WT2})", "WK"),
  ENDIF,
  IF("WRECT"),
    LN("Q = Cd (2/3) sqrt(2g) b H^(3/2)"),
    EQ("K", "Cd (2/3) sqrt(2g) b", "{WCD}(2/3)sqrt(2({G}))({WBE})", "WK"),
  ENDIF,
  IF("WORC"), EQ("A", "pi d^2/4", "pi({WD1})^2/4", "WAREA", "m2"), ENDIF,
  IF("WORR"), EQ("A", "b a", "{WD1}({WD2})", "WAREA", "m2"), ENDIF,
  IF("WORC"), LN("Q = Cd A sqrt(2 g H)  (H al centro)"),
    EQ("K", "Cd A sqrt(2g)", "{WCD}({WAREA})sqrt(2({G}))", "WK"), ENDIF,
  IF("WORR"), LN("Q = Cd A sqrt(2 g H)  (H al centro)"),
    EQ("K", "Cd A sqrt(2g)", "{WCD}({WAREA})sqrt(2({G}))", "WK"), ENDIF)

X_VE1_SUM = prog(
  LN(" {TXT}", "gray"),
  IFN("WINV"), DAT("H", "WH", "m"), ENDIF,
  IF("WINV"), RES("H", "WH", "m"), ENDIF,
  IFN("WINV"), RES("Q", "WQ", "m3/s"), RES("Q", "WQLS", "l/s"), ENDIF,
  IF("WINV"), DAT("Q", "WQ", "m3/s"), ENDIF,
  IF("WH0"), RES("h0 = h - H", "WH0", "m"), ENDIF,
  SEPx, WWARN)
X_VE1_MEMO = prog(
  SEC("DATOS"),
  LN(" Elemento: {TXT}"),
  DAT("Cd", "WCD"),
  IF("WTRI"), DAT("theta", "WD1", "grad"), ENDIF,
  IF("WRECT"), DAT("b", "WD1", "m"), DAT("contracciones", "WNC"), ENDIF,
  IF("WORC"), DAT("d", "WD1", "m"), ENDIF,
  IF("WORR"), DAT("b", "WD1", "m"), DAT("a", "WD2", "m"), ENDIF,
  IFN("WINV"), DAT("H", "WH", "m"), ENDIF,
  IF("WINV"), DAT("Q", "WQ", "m3/s"), ENDIF,
  IF("WH0"), DAT("nivel arriba h", "WLEV", "m"), ENDIF,
  SEC("CALCULOS"),
  WFORM,
  IFN("WINV"),
    IF("WTRI"), EQ("Q", "K H^(5/2)", "{WK}({WH})^2.5", "WQ", "m3/s"), ENDIF,
    IF("WRECT"), EQ("Q", "K H^(3/2)", "{WK}({WH})^1.5", "WQ", "m3/s"), ENDIF,
    IF("WORC"), EQ("Q", "K H^(1/2)", "{WK}({WH})^0.5", "WQ", "m3/s"), ENDIF,
    IF("WORR"), EQ("Q", "K H^(1/2)", "{WK}({WH})^0.5", "WQ", "m3/s"), ENDIF,
  ENDIF,
  IF("WINV"),
    IF("WTRI"), EQ("H", "(Q/K)^(2/5)", "({WQ}/{WK})^0.4", "WH", "m"), ENDIF,
    IF("WRECT"),
      IFN("WFRAN"), EQ("H", "(Q/K)^(2/3)", "({WQ}/{WK})^(2/3)", "WH", "m"), ENDIF,
      IF("WFRAN"), LN(" Con Francis K depende de H:", "gray"),
                   LN(" biseccion: {WIT!} vueltas", "gray"),
                   RES("H", "WH", "m"), ENDIF,
    ENDIF,
    IF("WORC"), EQ("H", "(Q/K)^2", "({WQ}/{WK})^2", "WH", "m"), ENDIF,
    IF("WORR"), EQ("H", "(Q/K)^2", "({WQ}/{WK})^2", "WH", "m"), ENDIF,
    IF("WH0"), EQ("h0", "h - H", "{WLEV} - {WH}", "WH0", "m"), ENDIF,
  ENDIF,
  SEC("RESULTADO"),
  RES("H", "WH", "m"), RES("Q", "WQ", "m3/s"), RES("Q", "WQLS", "l/s"),
  IF("WH0"), RES("Cota de la cresta h0", "WH0", "m"), ENDIF,
  SEC("OBSERVACIONES"), WWARN,
  LN(" Cd editable (Ajustes: Cd vertedores)", "gray"))

X_VE4_SUM = prog(
  IFN("WINV"), DAT("Nivel h", "WLEV", "m"), ENDIF,
  IF("WINV"), RES("Nivel h", "WLEV", "m"), ENDIF,
  TAB("hook"),
  RES("Q total", "WQ", "m3/s"), RES("Q total", "WQLS", "l/s"),
  SEPx, WWARN)
X_VE4_MEMO = prog(
  SEC("DATOS"),
  IFN("WINV"), DAT("Nivel h", "WLEV", "m"), ENDIF,
  IF("WINV"), DAT("Q total", "WQ", "m3/s"), ENDIF,
  SEC("CALCULOS"),
  LN("Q(h) = suma Qi(h - zi); Qi = 0 si h <= zi"),
  LN(" Vertedero: Cd (8/15) sqrt(2g) tan(t/2) H^2.5", "gray"),
  LN("   o Cd (2/3) sqrt(2g) b H^1.5", "gray"),
  LN(" Orificio: Cd A sqrt(2 g H), H al centro", "gray"),
  IF("WINV"), LN(" Nivel por biseccion (Q(h) crece con h):"),
              LN("  {WIT!} vueltas", "gray"), ENDIF,
  TAB("hook"),
  EQ("Q", "suma Qi", nil, "WQ", "m3/s"),
  SEC("RESULTADO"),
  RES("Nivel h", "WLEV", "m"), RES("Q total", "WQ", "m3/s"), RES("Q total", "WQLS", "l/s"),
  SEC("OBSERVACIONES"), WWARN,
  IF("WDRY"), LN(" Algun elemento no recibe agua (Q = 0)", "gray"), ENDIF)

X_VE6_SUM = prog(
  RES("Q", "PRQ", "m3/s"), RES("Q", "WQLS", "l/s"), DAT("v media", "PRVM", "m/s"))
X_VE6_MEMO = prog(
  SEC("DATOS"),
  DAT("b", "PRB", "m"),
  IFN("WPTS"), DAT("h", "PRH", "m"), DAT("k", "PRK"), DAT("n", "PRN"), ENDIF,
  IF("WPTS"), DAT("puntos", "PRNP"), DAT("altura medida", "PRH", "m"), ENDIF,
  SEC("CALCULOS"),
  LN("Q = b * integral de v(y) dy de 0 a h"),
  IFN("WPTS"),
    LN(" v = k y^n:  Q = b k h^(n+1)/(n+1)"),
    EQ("Q", nil, "{PRB}({PRK})({PRH})^({PRN}+1)/({PRN}+1)", "PRQ", "m3/s"),
  ENDIF,
  IF("WPTS"),
    IF("WSIMP"), LN(" Simpson 1/3 (puntos iguales e impares)"), ENDIF,
    IFN("WSIMP"), LN(" Trapecios (puntos no aptos para Simpson)"), ENDIF,
    RES("Q", "PRQ", "m3/s"),
  ENDIF,
  EQ("v media", "Q/(b h)", "{PRQ}/({PRB}({PRH}))", "PRVM", "m/s"),
  SEC("RESULTADO"),
  RES("Q", "PRQ", "m3/s"), RES("Q", "WQLS", "l/s"), RES("v media", "PRVM", "m/s"))

X_VE7_SUM = prog(
  RES("v1", "SV1", "m/s"), RES("E1", "SE1", "m"), DAT("Fr1", "SFR1"),
  IF("SBER"),
    IFN("SNOE"), RES("h2 subcritico", "SHS", "m"), RES("h2 supercrit.", "SHP", "m"), ENDIF,
    IF("SNOE"), LN("! E2 < Emin: no hay tirante posible", "warn"), ENDIF,
  ENDIF)
X_VE7_MEMO = prog(
  SEC("DATOS"),
  DAT("Q", "SQ", "m3/s"), DAT("b", "SB", "m"), DAT("h1", "SH1", "m"),
  IF("SBER"), DAT("dz (escalon)", "SDZ", "m"), ENDIF,
  SEC("CALCULOS"),
  EQ("v1", "Q/(b h1)", "{SQ}/({SB}({SH1}))", "SV1", "m/s"),
  EQ("E1", "h1 + v1^2/2g", "{SH1} + ({SV1})^2/(2({G}))", "SE1", "m"),
  EQ("Fr1", "v1/sqrt(g h1)", "{SV1}/sqrt({G}({SH1}))", "SFR1"),
  IF("SBER"),
    EQ("q", "Q/b", "{SQ}/{SB}", "SQQ", "m2/s"),
    EQ("E2", "E1 - dz", "{SE1} - {SDZ}", "SE2", "m"),
    EQ("hc", "(q^2/g)^(1/3)", "(({SQQ})^2/{G})^(1/3)", "SHC", "m"),
    EQ("Emin", "1.5 hc", "1.5({SHC})", "WG2", "m"),
    IFN("SNOE"),
      LN(" E2 = h2 + q^2/(2 g h2^2): dos raices"),
      RES("h2 subcritico", "SHS", "m"), DAT("v2", "SVS", "m/s"),
      RES("h2 supercritico", "SHP", "m"), DAT("v2", "SVP", "m/s"),
    ENDIF,
    IF("SNOE"), LN("! E2 < Emin: no hay tirante posible", "warn"), ENDIF,
  ENDIF,
  SEC("RESULTADO"),
  RES("v1", "SV1", "m/s"), RES("E1", "SE1", "m"))

X_EX1_SUM = prog(
  DAT("Q", "VQLS", "l/s"), DAT("v1", "VV1", "m/s"), DAT("v2", "VV2", "m/s"),
  RES("dp = p1 - p2", "VDP", "Pa"),
  IF("VMANO"), RES("h manometro", "VH", "m"), ENDIF,
  IF("VMANO"), IF("VEXAM"), LN(" Convencion del examen: dp = S g h", "warn"), ENDIF, ENDIF)
X_EX1_MEMO = prog(
  SEC("DATOS"),
  DAT("D1", "VD1", "m"), DAT("D2", "VD2", "m"),
  IFN("VV1"), DAT("Q", "VQ", "m3/s"), ENDIF,
  IF("VV1"), DAT("v1", "VV1", "m/s"), ENDIF,
  IF("VCV"), DAT("Cv", "VCV"), ENDIF,
  IF("VMANO"), DAT("S manometro", "VS"), ENDIF,
  DAT("gamma", "GAM", "N/m3"),
  SEC("CALCULOS"),
  EQ("A1", "pi D1^2/4", "pi({VD1})^2/4", "VA1", "m2"),
  EQ("A2", "pi D2^2/4", "pi({VD2})^2/4", "VA2", "m2"),
  IFN("VV1"), EQ("v1", "Q/A1", "{VQ}/{VA1}", "VV1", "m/s"), ENDIF,
  IF("VV1"), EQ("Q", "v1 A1", "{VV1}({VA1})", "VQ", "m3/s"), ENDIF,
  EQ("v2", "Q/A2", "{VQ}/{VA2}", "VV2", "m/s"),
  IFN("VCV"),
    LN("Bernoulli 1-2 (z1 = z2):"),
    EQ("dp", "gamma (v2^2 - v1^2)/(2g)", "{GAM}(({VV2})^2 - ({VV1})^2)/(2({G}))", "VDP", "Pa"),
  ENDIF,
  IF("VCV"),
    EQ("beta^4", "(D2/D1)^4", "({VD2}/{VD1})^4", "VB4"),
    EQ("dp", "rho/2 (Q/(Cv A2))^2 (1 - beta^4)",
       "({GAM}/{G})/2 ({VQ}/({VCV}({VA2})))^2 (1 - {VB4})", "VDP", "Pa"),
  ENDIF,
  IF("VMANO"),
    IFN("VEXAM"),
      LN("Manometro diferencial: dp = (S - 1) gamma h"),
      EQ("h", "dp/((S - 1) gamma)", "{VDP}/(({VSF})({GAM}))", "VH", "m"),
    ENDIF,
    IF("VEXAM"),
      LN("Convencion de la solucion 2025: dp = S gamma h"),
      EQ("h", "dp/(S gamma)", "{VDP}/({VSF}({GAM}))", "VH", "m"),
    ENDIF,
  ENDIF,
  SEC("RESULTADO"),
  RES("dp", "VDP", "Pa"), RES("dp", "VDPK", "kPa"),
  IF("VMANO"), RES("h", "VH", "m"), ENDIF,
  SEC("OBSERVACIONES"),
  LN(" Use el Q que pide el enunciado (maximo o", "gray"),
  LN(" de diseno); la solucion 2025 uso 200 l/s", "gray"),
  IF("VEXAM"), LN("! La relacion fisica es (S - 1) gamma h", "warn"), ENDIF)

X_EX2_SUM = prog(
  DAT("q = Q/b", "JQQ", "m2/s"), DAT("Fr1", "JFR1"),
  IFN("JY2"), RES("y2", "JY2", "m"), ENDIF,
  IF("JY2"), RES("y1", "JY1", "m"), ENDIF,
  DAT("E1", "JE1", "m"), DAT("E2", "JE2", "m"),
  RES("dE = E1 - E2", "JDE", "m"), RES("P disipada", "JP", "kW"))
X_EX2_MEMO = prog(
  SEC("DATOS"),
  DAT("Q", "JQ", "m3/s"), DAT("b", "JB", "m"),
  IFN("JY2"), DAT("y1", "JY1", "m"), ENDIF,
  IF("JY2"), DAT("y2", "JY2", "m"), ENDIF,
  SEC("CALCULOS"),
  EQ("q", "Q/b", "{JQ}/{JB}", "JQQ", "m2/s"),
  IFN("JY2"),
    EQ("v1", "q/y1", "{JQQ}/{JY1}", "JV1", "m/s"),
    EQ("Fr1", "v1/sqrt(g y1)", "{JV1}/sqrt({G}({JY1}))", "JFR1"),
    LN("Cantidad de movimiento: q^2/(g y1) + y1^2/2"),
    LN("   = q^2/(g y2) + y2^2/2"),
    EQ("y2", "y1/2 (sqrt(1 + 8 Fr1^2) - 1)", "{JY1}/2 (sqrt(1 + 8({JFR1})^2) - 1)", "JY2", "m"),
    EQ("v2", "q/y2", "{JQQ}/{JY2}", "JV2", "m/s"),
  ENDIF,
  IF("JY2"),
    EQ("v2", "q/y2", "{JQQ}/{JY2}", "JV2", "m/s"),
    EQ("Fr2", "v2/sqrt(g y2)", "{JV2}/sqrt({G}({JY2}))", "JFR2"),
    EQ("y1", "y2/2 (sqrt(1 + 8 Fr2^2) - 1)", "{JY2}/2 (sqrt(1 + 8({JFR2})^2) - 1)", "JY1", "m"),
    EQ("v1", "q/y1", "{JQQ}/{JY1}", "JV1", "m/s"),
    DAT("Fr1", "JFR1"),
  ENDIF,
  EQ("E1", "y1 + v1^2/2g", "{JY1} + ({JV1})^2/(2({G}))", "JE1", "m"),
  EQ("E2", "y2 + v2^2/2g", "{JY2} + ({JV2})^2/(2({G}))", "JE2", "m"),
  EQ("dE", "E1 - E2", "{JE1} - {JE2}", "JDE", "m"),
  LN(" Comprobacion: (y2 - y1)^3/(4 y1 y2)", "gray"),
  EQ("P", "gamma Q dE", "{GAM}({JQ})({JDE})/1000", "JP", "kW"),
  EQ("E2/E1", nil, "100({JE2})/{JE1}", "JEFF", "%"),
  SEC("RESULTADO"),
  IFN("JY2"), RES("y2", "JY2", "m"), ENDIF,
  IF("JY2"), RES("y1", "JY1", "m"), ENDIF,
  RES("dE", "JDE", "m"), RES("P disipada", "JP", "kW"))

X_EX3_SUM = prog(
  RES("Q", "EQLS", "l/s"), DAT("v salida", "EV", "m/s"), DAT("f", "EF"),
  DAT("vx", "EVX", "m/s"), DAT("vy", "EVY", "m/s"),
  RES("h max", "EHM", "m"), RES("Alcance R", "ER", "m"), DAT("t de vuelo", "ET", "s"))
X_EX3_MEMO = prog(
  SEC("DATOS"),
  DAT("H", "EH", "m"), DAT("L", "EL", "m"), DAT("D", "ED", "m"),
  DAT("ks", "EKS", "m"), DAT("nu", "NU", "m2/s"), DAT("Suma K", "EK"),
  IF("EK1"), LN(" Incluye la energia cinetica de salida (+1)", "gray"), ENDIF,
  IFN("EK1"), LN(" Sin energia de salida (como la solucion)", "gray"), ENDIF,
  DAT("theta", "ETH", "grad"),
  SEC("CALCULOS"),
  LN("Caudal maximo (tuberia tipo B):"),
  LN(" H = (f L/D + Suma K) v^2/2g"),
  LN(" v = sqrt[2 g H/(f L/D + Suma K)]"),
  IFN("EBIS"), TAB("course"), ENDIF,
  IF("EBIS"), TAB("bis"), ENDIF,
  DAT("f", "EF"), DAT("Re", "ERE"),
  RES("v", "EV", "m/s"), RES("Q", "EQLS", "l/s"),
  LN("Trayectoria (mismo nivel de salida):"),
  EQ("vx", "v cos(theta)", nil, "EVX", "m/s"),
  EQ("vy", "v sin(theta)", nil, "EVY", "m/s"),
  EQ("h max", "vy^2/2g", "({EVY})^2/(2({G}))", "EHM", "m"),
  EQ("R", "v^2 sin(2 theta)/g", nil, "ER", "m"),
  EQ("t", "2 vy/g", "2({EVY})/{G}", "ET", "s"),
  SEC("RESULTADO"),
  RES("Q", "EQLS", "l/s"), RES("h max", "EHM", "m"), RES("R", "ER", "m"),
  SEC("OBSERVACIONES"), WARNS)

-- temas de ayuda de FLUJOS y erratas completas
AYUDA[7] = {"Erratas del material", prog(
  LN("ERRATAS DEL MATERIAL", "title"), SEPx,
  TX("Perdidas-01 p.34: usa D^4.87 aunque"),
  TX("  escribe 4.57 (19.32 m sale con 4.87)"),
  TX("PVC 200 mm: el enunciado dice 32 l/s;"),
  TX("  la solucion usa 72 l/s"),
  TX("Presentacion ej. 1: H = 43.5 m (hoja)"),
  TX("Presentacion ej. 2: ks = 2.0E-6 m"),
  TX("Presentacion ej. 4: L = 970 m (hoja) y"),
  TX("  gamma = 9801 (agua a 15 C)"),
  TX("2018 P1a: Q = 5.69 l/s, no 56.9;"),
  TX("  el manuscrito usa L = 2.06 m"),
  TX("2024 P3: QB = 23.53 l/s, no 20.53"),
  TX("2025 P1: con 285.75 mm, Q = 262.4"),
  TX("  l/s (la solucion uso 285.00 mm)"),
  TX("2024 y 2025: D exacto con Swamee-Jain"),
  TG("  (CW difiere 0.04 %: ver Ajustes)"),
  LN("v2.0 (flujos externos y medicion):", "title"),
  TX("2017 P2: sin solucion; alfa y CD se"),
  TX("  leen de la grafica (entrada manual)"),
  TX("T4-2 P1: no da CD; paracaidas 1.3"),
  TG("  (copa hueca 1.42 en el catalogo)"),
  TX("T4-2 P4: Re sobre la crisis de"),
  TX("  arrastre; se usa la tabla Re > 1E4"),
  TX("T4-2 P5: cubo de arista, A = sqrt(2)D^2"),
  TG("  (las tablas usan D^2: 1.580 m/s)"),
  TX("T4-2 P2b: Q = 16 + 20 = 36 l/s y cresta"),
  TX("  a la H de la parte a; Cd 0.6"),
  TX("2025 P4c: la solucion uso Q de diseno"),
  TX("  (200 l/s) y dp = S gamma h"),
  TX("2025 chorro: Suma K = 0, sin energia"),
  TX("  de salida (con ella, 3.899 l/s)"))}
AYUDA_FLUJOS = {
  {"Arrastre y sustentacion", prog(
    LN("ARRASTRE Y SUSTENTACION", "title"), SEPx,
    TX("FD = 0.5 rho CD A V^2  (A frontal)"),
    TX("FL = 0.5 rho CL A V^2  (A en planta)"),
    TX("Re = V L/nu; L = D salvo que se de."),
    TX("AR-2: W - B = FD; en agua B = rho g V."),
    TX("AR-3: Fi a su cota yi; M = suma Fi yi."),
    TX("AR-4: CL = W/(q A); lea alfa y CD en"),
    TX("  la grafica y escribalos (paso 2)."),
    TG("  rho(h) = 1.3(1 - 2.26E-5 h)^4.256"),
    TX("Catalogo (boton CD): 17 figuras, tablas"),
    TX("  por L/D, b/h o angulo; EDITAR guarda"),
    TX("  un CD propio. Area con la formula"),
    TX("  de la figura si no se teclea A."),
    TX("Avisos: Re < 1E4 fuera de la tabla;"),
    TX("  crisis de arrastre (esfera > 2E5,"),
    TX("  cilindro largo > 5E5); Re < 1 usa"),
    TX("  Stokes (CD = 24/Re en la esfera)."),
    TX("Placa: Cf = 1.328/sqrt(Re) laminar,"),
    TX("  0.074/Re^0.2 turb., - 1742/Re mixto."))},
  {"Vertedores y orificios", prog(
    LN("VERTEDORES Y ORIFICIOS", "title"), SEPx,
    TX("Triangular: Q = Cd 8/15 sqrt(2g)"),
    TX("  tan(theta/2) H^2.5 (H desde vertice)"),
    TX("Rectangular: Q = Cd 2/3 sqrt(2g) b H^1.5"),
    TG("  Francis: be = b - 0.1 n H (opcional)"),
    TX("Orificio: Q = Cd A sqrt(2 g H), con H"),
    TX("  hasta el CENTRO del orificio."),
    TX("Cd por defecto 0.6 (Ajustes), editable."),
    TX("Compuesta: hasta 8 elementos con cota"),
    TX("  z; Qi = 0 si h <= z. Dado Q, nivel por"),
    TX("  biseccion. Reparto: Qi del resultado."),
    TX("Cota de la cresta: h0 = h - H (dado el"),
    TX("  nivel aguas arriba, modo Q -> H)."),
    TX("Perfil: v = k y^n -> Q = b k h^(n+1)/"),
    TX("  (n+1); o puntos con Simpson."),
    TX("Aguas abajo: v = Q/(b h), E = h + v^2/2g"),
    TX("  y tirantes alternos con E2 = E1 - dz."))},
  {"Canales y medicion", prog(
    LN("CANALES Y MEDICION", "title"), SEPx,
    TX("Venturi: v2 = v1 (D1/D2)^2;"),
    TX("  dp = gamma (v2^2 - v1^2)/2g."),
    TX("  Manometro: dp = (S - 1) gamma h"),
    TG("  (fisico, por defecto) o S gamma h"),
    TG("  (solucion 2025; Ajustes > Manometro)"),
    TX("Salto: Fr1 = v1/sqrt(g y1);"),
    TX("  y2 = y1/2 (sqrt(1 + 8 Fr1^2) - 1);"),
    TX("  dE = (y2 - y1)^3/(4 y1 y2);"),
    TX("  P = gamma Q dE."),
    TX("Chorro: Q con la tuberia tipo B; luego"),
    TX("  h max = (v sin t)^2/2g,"),
    TX("  R = v^2 sin(2t)/g."),
    TG("  Energia de salida: Suma K + 1 (opc.)"),
    TX("Placa plana y Stokes: Canales 4 (o"),
    TX("  Arrastre 5)."))},
  AYUDA[7],
}

-- ============================ CALCULOS FLUJOS ============================
FL_TITLES = {"FUERZA DE ARRASTRE (AR-1)", "VELOCIDAD TERMINAL (AR-2)",
  "ESTRUCTURA: CUERPOS (AR-3)", "VUELO NIVELADO (AR-4)", "PLACA PLANA Y STOKES",
  "VERTEDERO U ORIFICIO", "ESTRUCTURA COMPUESTA (VE-4)",
  "PERFIL DE VELOCIDADES (VE-6)", "AGUAS ABAJO: ENERGIA (VE-7)",
  "VENTURI Y MANOMETRO (EX-1)", "SALTO HIDRAULICO (EX-2)", "CHORRO DESDE UN TUBO (EX-3)"}

function vms(x)
  local u = TOG.d_vunit or 1
  if u == 1 then return r3(x) end
  if u == 2 then return r3(x / 3.6) end
  return r3(x * CFG.knot / 3.6)
end

function figok(fig)
  if fig == nil then return nil end
  if fig ~= floor(fig) or fig < 1 or fig > #SHAPES then herr("Figura: entero de 1 a 17") end
  return fig
end

function area_of(fig, A, D, L)
  if A then return A end
  if not fig then herr("Falta el area A (o la figura)") end
  local ar = SHAPES[fig][4]
  if not D or ((ar == AR_LD or ar == AR_BH) and not L) then herr("Faltan las dimensiones (o A)") end
  return dragcat_area(ar, D, L)
end

function kind_of(fig) if fig then return SHAPES[fig][5] end return 0 end

function flag_dwarn(FL, w)
  FL.DRELOW = w.relow and true or false
  FL.DCRIS = w.crisis and true or false
  FL.DRE1 = w.stokes and true or false
end

-- t: 1 AR-1, 2 AR-2, 3 AR-3, 4 AR-4, 5 placa/Stokes
function drag_compute(t, v)
  local V, FL = {}, {}
  local res = {V = V, FL = FL, W = {}, titulo = FL_TITLES[t], guardar = 8 + t}
  local rho, nu = v.d_rho, v.d_nu
  local vel = v.d_V and vms(v.d_V) or 0
  V.VIN, V.VEL, V.RHO, V.NU, V.G = v.d_V or 0, vel, rho or 0, nu or 0, CFG.g
  V.MU = (rho and nu) and rho * nu or 0
  FL.DVCONV = (TOG.d_vunit or 1) ~= 1
  if t == 1 or t == 2 then
    local fig = figok(v.d_fig)
    local A = area_of(fig, v.d_A, v.d_D, v.d_L)
    local cd = v.d_cd or (fig and dragcat_cd(fig))
    if not cd then herr("Falta CD (o la figura)") end
    local Lr = v.d_Lr or v.d_D or r3(sqrt(A))
    local k = kind_of(fig)
    V.CDV, V.AREF, V.DIM1, V.DIM2, V.LREF = cd, A, v.d_D or 0, v.d_L or 0, Lr
    FL.DFIG = fig ~= nil
    FL.DACALC = v.d_A == nil
    res.txt = fig and AREA_TXT[SHAPES[fig][4]] or ""
    V.KST = fig and SHAPES[fig][7] or 0
    local w
    if t == 1 then
      if not v.d_V then herr("Falta la velocidad V") end
      V.QDYN = drag_q(rho, vel)
      V.FD = drag_force(rho, cd, A, vel)
      V.RE = drag_re(vel, Lr, nu)
      w = drag_re_warn(V.RE, k)
      FL.DLIFT = (TOG.d_lift or 1) == 2
      if w.stokes and V.KST > 0 and not FL.DLIFT then
        V.CDV = r3(V.KST / V.RE)
        V.FD = drag_force(rho, V.CDV, A, vel)
        FL.DSTK = true
      end
    else
      local fluid = TOG.d_fluid or 1
      local useb = v.d_vol ~= nil and (fluid == 2 or CFG.buoy == 1 or fluid == 3)
      if fluid == 2 and not v.d_vol then herr("Agua: falta el volumen (empuje)") end
      local tr = drag_terminal(v.d_W, rho, useb and v.d_vol or 0, cd, A, Lr, nu, CFG.g, k)
      V.W, V.VOL, V.BUOY, V.NET, V.VT, V.RE = v.d_W, v.d_vol or 0, tr.B, tr.net, tr.v, tr.Re
      w = tr.warn
      FL.DBUOY = useb
      if w.stokes and V.KST > 0 then
        V.VT = r3(2 * tr.net * Lr / (rho * V.KST * nu * A))
        V.RE = drag_re(V.VT, Lr, nu)
        V.CDV = r3(V.KST / V.RE)
        FL.DSTK = true
      end
      V.VTKMH = V.VT * 3.6
    end
    flag_dwarn(FL, w)
  elseif t == 3 then
    if not v.d_V then herr("Falta la velocidad V") end
    V.QDYN = drag_q(rho, vel)
    local nb = floor(v.d_nb)
    local bodies = {}
    for i = 1, nb do
      if v["d_y" .. i] == nil then herr("Falta la cota y de un cuerpo") end
      local fig = figok(v["d_fig" .. i])
      local A = area_of(fig, v["d_A" .. i], v["d_D" .. i], v["d_L" .. i])
      local cd = v["d_cd" .. i] or (fig and dragcat_cd(fig))
      if not cd then herr("Falta el CD del cuerpo " .. i) end
      bodies[i] = {Cd = cd, A = A, y = v["d_y" .. i],
                   V = v["d_V" .. i] and vms(v["d_V" .. i]) or vel,
                   Lref = v["d_D" .. i] or r3(sqrt(A)), kind = kind_of(fig)}
    end
    local sr = drag_struct(bodies, rho, nu)
    V.FTOT, V.MOM, V.YCP = sr.Ftot / 1000, sr.M / 1000, sr.ycp
    flag_dwarn(FL, sr.warn)
    res.hook = function()
      for i, b in ipairs(bodies) do
        mline(i .. ": CD=" .. fw(b.Cd) .. " A=" .. fw(b.A) .. " m2 y=" .. fw(b.y) .. " m", "fg")
        mline("   F" .. i .. " = CD q A = " .. fw(sr.F[i] / 1000) .. " kN  Re=" .. fw(sr.Re[i]), "ok")
        if sr.w[i].crisis then mline("   ! posible crisis de arrastre", "warn") end
      end
    end
    res.sketch = {bodies = bodies, sr = sr}
  elseif t == 4 then
    if not v.d_V then herr("Falta la velocidad V") end
    if not v.d_rh4 and not v.d_h then herr("Falta la altitud h o rho") end
    rho = v.d_rh4 or drag_rho_alt(v.d_h)
    FL.DALT = v.d_rh4 == nil
    V.ALT, V.RHO = v.d_h or 0, rho
    local nw = floor(v.d_nw)
    if nw < 1 or nw > 4 then herr("Numero de alas: 1 a 4") end
    local pl = drag_plane_lift(v.d_W, rho, vel, v.d_Aw, nw)
    if v.d_cdw then
      drag_plane_thrust(pl, v.d_W, rho, vel, v.d_cdw, v.d_cdf, v.d_Df, v.d_clmax or 0)
      FL.DSTEP2 = true
      FL.DVST = v.d_clmax ~= nil
      V.AFUS, V.DWING, V.DFUS = pl.Afus, pl.Dw / 1000, pl.Df / 1000
      V.THR, V.PWR, V.VST, V.VTKMH = pl.T / 1000, pl.P / 1e6, pl.Vst, pl.Vst * 3.6
    end
    V.W, V.QDYN, V.CL, V.ATOT, V.AW, V.NW = v.d_W, pl.q, pl.CL, pl.Atot, v.d_Aw, nw
    V.CDW, V.CDF, V.DF = v.d_cdw or 0, v.d_cdf, v.d_Df
    V.ALPHA, V.CLMAX = v.d_alpha or 0, v.d_clmax or 0
  else
    if not v.d_V then herr("Falta la velocidad V") end
    V.DIM1 = v.d_D
    V.RE = drag_re(vel, v.d_D, nu)
    if (TOG.d_kase or 1) == 2 then
      FL.PSTK = true
      V.FD = drag_stokes(r3(rho * nu), vel, v.d_D)
      V.CDV = 24 / V.RE
      FL.DRE1 = V.RE >= 1
    else
      if not v.d_L then herr("Falta el ancho w de la placa") end
      local p = drag_plate(v.d_D, v.d_L, vel, rho, nu, TOG.d_faces or 1, (TOG.d_regime or 1) - 1)
      V.DIM2, V.CFL, V.CFT, V.CFM, V.CF = v.d_L, p.Cf_lam, p.Cf_turb, p.Cf_mix, p.Cf
      V.APL, V.FACES, V.QDYN, V.FD = p.A, TOG.d_faces or 1, drag_q(rho, vel), p.F
      FL.PLAM, FL.PTURB, FL.PMIX = p.regime == 1, p.regime == 2, p.regime == 3
      FL.PLAMNA, FL.PTURBNA = p.warn.lamna and true or false, p.warn.turbna and true or false
    end
  end
  local SU = {X_AR1_SUM, X_AR2_SUM, X_AR3_SUM, X_AR4_SUM, X_PL_SUM}
  local ME = {X_AR1_MEMO, X_AR2_MEMO, X_AR3_MEMO, X_AR4_MEMO, X_PL_MEMO}
  res.sum, res.memo = SU[t], ME[t]
  return res
end

function qsi(q) if (TOG.w_qunit or 1) == 2 then return r3(q) end return r3(q / 1000) end

function flag_w(FL, w)
  FL.WFRAN = w.francis and true or false
  FL.WPART = w.partial and true or false
  FL.WHIGH = w.high and true or false
  FL.WDRY = w.dry and true or false
end

function coefK(e, H)
  local s = sqrt(2 * CFG.g) * e.Cd
  if e.type == WE_TRI then return r3(s * (8 / 15) * math.tan(e.a * 0.00872664626)) end
  if e.type == WE_RECT then return r3(s * (2 / 3) * (e.a - 0.1 * e.ncon * H)) end
  if e.type == WE_ORC then return r3(s * area(e.a)) end
  return r3(s * e.a * e.b)
end

-- t: 1 simple, 2 compuesta, 3 perfil, 4 aguas abajo
function weir_compute(t, v)
  local V, FL = {}, {}
  local res = {V = V, FL = FL, W = {}, titulo = FL_TITLES[5 + t], guardar = 13 + t}
  local SU = {X_VE1_SUM, X_VE4_SUM, X_VE6_SUM, X_VE7_SUM}
  local ME = {X_VE1_MEMO, X_VE4_MEMO, X_VE6_MEMO, X_VE7_MEMO}
  res.sum, res.memo = SU[t], ME[t]
  V.G = CFG.g
  local g = CFG.g
  local w = {}
  local Q, h, H, it = 0, 0, 0, 0
  local EL = {}
  if t == 1 then
    local et = TOG.w_etype or 1
    if et == WE_ORR and not v.w_d2 then herr("Falta el alto a del orificio") end
    EL[1] = {type = et, count = 1, Cd = v.w_cd, a = v.w_d1, z = 0,
             b = (et == WE_ORR) and v.w_d2 or 0,
             ncon = (et == WE_RECT and v.w_nc) and floor(v.w_nc) or 0}
    if EL[1].ncon < 0 or EL[1].ncon > 2 then herr("Contracciones: 0 a 2") end
    if (TOG.w_mode or 1) == 1 then
      if not v.w_H then herr("Falta la carga H") end
      Q = weir_total(EL, v.w_H, g, w)
      H = v.w_H
    else
      if not v.w_Q then herr("Falta el caudal Q") end
      Q = qsi(v.w_Q)
      H, _, it = weir_level(EL, Q, g, w)
      FL.WH0 = v.w_hup ~= nil
      V.WLEV = v.w_hup or 0
      V.WH0 = (v.w_hup or 0) - H
    end
    V.WH, V.WK = H, coefK(EL[1], H)
    V.WBE, V.WNC = EL[1].a - 0.1 * EL[1].ncon * H, EL[1].ncon
  elseif t == 2 then
    local ne = floor(v.w_ne)
    if ne < 1 or ne > 8 then herr("Numero de elementos: 1 a 8") end
    for i = 1, ne do
      local et = TOG["w_et" .. i] or 1
      if not v["w_n" .. i] or not v["w_d1" .. i] or v["w_z" .. i] == nil then herr("Faltan datos de un elemento") end
      if et == WE_ORR and not v["w_d2" .. i] then herr("Falta el alto a de un orificio") end
      EL[i] = {type = et, count = floor(v["w_n" .. i]), ncon = 0, Cd = v["w_cd" .. i] or CFG.cd_weir,
               z = v["w_z" .. i], a = v["w_d1" .. i], b = (et == WE_ORR) and v["w_d2" .. i] or 0}
    end
    local Qi
    if (TOG.w_cmode or 1) == 1 then
      if v.w_h == nil then herr("Falta el nivel h") end
      h = v.w_h
      Q, Qi = weir_total(EL, h, g, w)
    else
      if not v.w_Q then herr("Falta el caudal Q") end
      Q = qsi(v.w_Q)
      h, Qi, it = weir_level(EL, Q, g, w)
    end
    V.WLEV = h
    res.hook = function()
      for i, e in ipairs(EL) do
        mline(i .. " " .. ET_NAMES[e.type] .. " x" .. e.count .. ": z=" .. fw(e.z) .. " Cd=" .. fw(e.Cd), "fg")
        if h - e.z > 0 then
          mline("   H=h-z=" .. fw(h - e.z) .. " m  Q=" .. fw(Qi[i]) .. " m3/s", "ok")
        else
          mline("   h <= z: no recibe agua, Q = 0", "gray")
        end
      end
    end
    res.sketch = {els = EL, h = h, Q = Q}
  elseif t == 3 then
    V.PRB = v.w_b
    local vm
    if (TOG.w_pmode or 1) == 1 then
      Q, vm = weir_profile_pow(v.w_k, v.w_pn, v.w_b, v.w_ph)
      V.PRK, V.PRN, V.PRH = v.w_k, v.w_pn, v.w_ph
    else
      local np = floor(v.w_np)
      if np < 2 or np > 9 then herr("Numero de puntos: 2 a 9") end
      local y, vv = {}, {}
      for i = 1, np do y[i] = v["w_y" .. i]; vv[i] = v["w_v" .. i] end
      local ok, a, b, c = pcall(weir_profile_pts, y, vv, v.w_b)
      if not ok then herr("Datos invalidos (y debe crecer)") end
      Q, vm = a, b
      FL.WPTS, FL.WSIMP = true, c
      V.PRNP, V.PRH = np, y[np] - y[1]
    end
    V.PRVM, V.PRQ, V.WQLS = vm, Q, Q * 1000
    return res
  else
    Q = qsi(v.w_sQ)
    local v1, E1 = weir_section(Q, v.w_sb, v.w_h1, g)
    local q = r3(Q / v.w_sb)
    V.SQ, V.SB, V.SH1, V.SV1, V.SE1, V.SQQ = Q, v.w_sb, v.w_h1, v1, E1, q
    V.SFR1 = v1 / sqrt(g * v.w_h1)
    if (TOG.w_smode or 1) == 2 then
      V.SDZ = v.w_dz or 0
      V.SE2 = E1 - V.SDZ
      FL.SBER = true
      local hs, hp, hc = weir_alt_depths(q, V.SE2, g)
      V.SHC = hc
      if not hs then
        FL.SNOE = true
        V.SHS, V.SHP = 0, 0
      else
        V.SHS, V.SHP, V.SVS, V.SVP = hs, hp, q / hs, q / hp
      end
      V.WG2 = 1.5 * V.SHC
    end
    return res
  end
  V.WQ, V.WQLS, V.WCD, V.WD1, V.WD2 = Q, Q * 1000, EL[1].Cd, EL[1].a, EL[1].b
  V.WAREA = (EL[1].type == WE_ORC) and area(EL[1].a) or EL[1].a * EL[1].b
  V.WT2 = math.tan(EL[1].a * 0.00872664626)
  V.WIT = it
  FL.WTRI, FL.WRECT = EL[1].type == WE_TRI, EL[1].type == WE_RECT
  FL.WORC, FL.WORR = EL[1].type == WE_ORC, EL[1].type == WE_ORR
  FL.WINV = (t == 1) and ((TOG.w_mode or 1) == 2) or ((TOG.w_cmode or 1) == 2)
  flag_w(FL, w)
  res.txt = ET_NAMES[EL[1].type]
  return res
end

-- t: 1 Venturi, 2 salto, 3 chorro
function chan_compute(t, v)
  local V, FL = {}, {}
  local res = {V = V, FL = FL, W = {}, titulo = FL_TITLES[9 + t], guardar = 17 + t}
  local SU = {X_EX1_SUM, X_EX2_SUM, X_EX3_SUM}
  local ME = {X_EX1_MEMO, X_EX2_MEMO, X_EX3_MEMO}
  res.sum, res.memo = SU[t], ME[t]
  V.G, V.GAM = CFG.g, CFG.gamma
  if t == 1 then
    local D1 = rmm(v.c_D1 / 1000)
    local D2
    if v.c_D2 then D2 = rmm(v.c_D2 / 1000)
    elseif v.c_beta then D2 = r3(v.c_beta * D1)
    else herr("Falta D2 o D2/D1") end
    local Q
    if v.c_v1 then Q = r3(v.c_v1 * area(D1)); FL.VV1 = true
    elseif v.c_Q then Q = ((TOG.c_qunit or 1) == 2) and v.c_Q or r3(v.c_Q / 1000)
    else herr("Falta Q o v1") end
    if not (v.c_Cv >= 0.01 and v.c_Cv <= 1) then herr("Cv debe estar entre 0.01 y 1") end
    if D2 >= D1 then herr("D2 debe ser menor que D1") end
    local conv = TOG.c_conv or ((CFG.mano or 0) + 1)
    local r = chan_venturi(D1, D2, Q, v.c_Cv, v.c_S or 0, conv)
    V.VD1, V.VD2, V.VBETA, V.VB4 = D1, D2, r.beta, r.beta ^ 4
    V.VA1, V.VA2, V.VV1, V.VV2 = r.A1, r.A2, r.v1, r.v2
    V.VDP, V.VDPK, V.VH, V.VS = r.dp, r.dp / 1000, r.h, v.c_S or 0
    V.VSF = (conv == 2) and (v.c_S or 0) or ((v.c_S or 0) - 1)
    V.VCV, V.VQ, V.VQLS = v.c_Cv, Q, Q * 1000
    FL.VMANO, FL.VEXAM, FL.VCV = v.c_S ~= nil, conv == 2, v.c_Cv ~= 1
  elseif t == 2 then
    local y2 = (TOG.c_ymode or 1) == 2
    local r = chan_jump(v.c_Qj, v.c_b, v.c_y, y2)
    V.JQ, V.JB, V.JQQ, V.JY1, V.JY2 = v.c_Qj, v.c_b, r.q, r.y1, r.y2
    V.JV1, V.JV2, V.JFR1, V.JFR2 = r.v1, r.v2, r.Fr1, r.Fr2
    V.JE1, V.JE2, V.JDE, V.JP, V.JEFF = r.E1, r.E2, r.dE, r.P / 1000, 100 * r.eff
    FL.JY2 = y2
  else
    NU = v.c_nu
    local exitk = (TOG.c_exitk or 1) == 2
    local P = {D = rmm(v.c_D / 1000), L = v.c_L, ks = r3(v.c_ks / 1000), K = v.c_K + (exitk and 1 or 0), ff = 0}
    local lg = {}
    local q = qmax(P, v.c_H, nil, lg)
    if not (v.c_th >= 0 and v.c_th <= 90) then herr("Angulo theta: 0 a 90 grados") end
    local j = chan_jet(q.st.v, v.c_th, CFG.g)
    V.EH, V.EL, V.ED, V.EKS, V.NU, V.EK = v.c_H, v.c_L, P.D, P.ks, v.c_nu, P.K
    V.EQ, V.EQLS, V.EV, V.ERE, V.EF = q.st.Q, q.st.Q * 1000, q.st.v, q.st.Re, q.st.f
    V.ELD, V.EIT, V.ETH = P.L / P.D, q.iters, v.c_th
    V.EVX, V.EVY, V.EHM, V.ER, V.ET = j.vx, j.vy, j.hmax, j.R, j.t
    res.W = q.st.warn
    res.log = lg
    FL.EK1 = exitk
    FL.EBIS = q.solver == "bis"
  end
  return res
end

-- ============================ CAMPOS FLUJOS ============================
FLUID_NAMES = {"Aire (Ajustes)", "Agua", "Manual"}

function aplicar_fluido()
  local f = TOG.d_fluid or 1
  if f == 1 then
    MEM.d_rho = {numstr(CFG.rho_air)}
    MEM.d_nu = {numstr(CFG.nu_air)}
  elseif f == 2 then
    MEM.d_rho = {numstr(CFG.gamma / CFG.g)}
    MEM.d_nu = {numstr(CFG.nu)}
  end
end

function fig_hook(kfig, kcd)
  return function()
    local n = tonumber(texto(kfig))
    if n and n >= 1 and n <= #SHAPES and n == floor(n) then
      if kcd == "d_cd" or texto(kcd) == "" then MEM[kcd] = {numstr(dragcat_cd(n))} end
    end
  end
end

function campos_fluido()
  local ff1 = F("d_fluid", "Fluido", nil, nil, nil, FLUID_NAMES)
  ff1.on = aplicar_fluido
  return {ff1, F("d_rho", "rho [kg/m3]"), F("d_nu", "nu [m2/s]")}
end

function campos_V()
  return {F("d_V", "Velocidad V"), F("d_vunit", "Unidad de V", nil, nil, nil, {"m/s", "km/h", "nudos"})}
end

function campos_forma()
  local ffig = F("d_fig", "Figura 1-17 (opc)", "", "-")
  ffig.on = fig_hook("d_fig", "d_cd")
  return {F("d_cd", "CD (o figura)", "", "de la figura"), ffig,
    F("d_D", "Dim. D (o h) [m]", "", "-"), F("d_L", "Dim. L o b (opc) [m]", "", "-"),
    F("d_A", "Area A (opc) [m2]", "", "calcular"), F("d_Lr", "Long. Re (opc) [m]", "", "D")}
end

function lista(...)
  local r = {}
  for _, t in ipairs({...}) do for _, x in ipairs(t) do r[#r + 1] = x end end
  return r
end

function nbodies()
  local n = tonumber(texto("d_nb")) or 2
  n = floor(n)
  if n < 1 then n = 1 end
  if n > 6 then n = 6 end
  return n
end

DRAG_CAMPOS = {
  function() return lista({F("d_lift", "Calcular", nil, nil, nil, {"Arrastre FD", "Sustentac. FL"})},
    campos_fluido(), campos_V(), campos_forma()) end,
  function() return lista(campos_fluido(), {F("d_W", "Peso W [N]"),
    F("d_vol", "Volumen (empuje) [m3]", "", "no")}, campos_forma()) end,
  function()
    local fs = lista({F("d_nb", "Numero de cuerpos", 2, "2")}, campos_fluido(), campos_V())
    for i = 1, nbodies() do
      local ffig = F("d_fig" .. i, i .. " Figura 1-17", "", "-")
      ffig.on = fig_hook("d_fig" .. i, "d_cd" .. i)
      fs[#fs + 1] = F("d_cd" .. i, i .. " CD", "", "de la figura")
      fs[#fs + 1] = ffig
      fs[#fs + 1] = F("d_D" .. i, i .. " D (o h) [m]", "", "-")
      fs[#fs + 1] = F("d_L" .. i, i .. " L o b [m]", "", "-")
      fs[#fs + 1] = F("d_A" .. i, i .. " A (opc) [m2]", "", "calcular")
      fs[#fs + 1] = F("d_y" .. i, i .. " y cota [m]")
      fs[#fs + 1] = F("d_V" .. i, i .. " V (opc)", "", "la comun")
    end
    return fs
  end,
  function() return lista({F("d_W", "Peso W [N]")}, campos_V(), {
    F("d_h", "Altitud h [m]", "", "-"), F("d_rh4", "rho (o altitud)", "", "de h"),
    F("d_nw", "Numero de alas", 2, "2"), F("d_Aw", "Area de un ala [m2]"),
    F("d_cdf", "CD fuselaje"), F("d_Df", "D fuselaje [m]"),
    F("d_alpha", "Lectura: alfa (opc)", "", "-"), F("d_cdw", "Lectura: CD alas", "", "paso 2"),
    F("d_clmax", "CLmax (opc)", "", "-")}) end,
  function() return lista({F("d_kase", "Caso", nil, nil, nil, {"Placa plana", "Esfera Stokes"})},
    campos_fluido(), campos_V(), {
    F("d_D", "L placa o D esfera [m]"), F("d_L", "Ancho w (placa) [m]", "", "-"),
    F("d_faces", "Caras mojadas", nil, nil, nil, {"Una", "Dos"}),
    F("d_regime", "Regimen (placa)", nil, nil, nil, {"Auto", "Laminar", "Turbulento", "Mixto"})}) end,
}

function qunit_txt() return ((TOG.w_qunit or 1) == 2) and "m3/s" or "l/s" end
D1_LAB = {"Angulo theta [grad]", "Ancho b [m]", "Diametro d [m]", "Ancho b [m]"}
function dcdw() return CFG.cd_weir end
function pcdw() return ng(CFG.cd_weir) end

function nelems()
  local n = tonumber(texto("w_ne")) or 2
  n = floor(n)
  if n < 1 then n = 1 end
  if n > 8 then n = 8 end
  return n
end
function npuntos()
  local n = tonumber(texto("w_np")) or 5
  n = floor(n)
  if n < 2 then n = 2 end
  if n > 9 then n = 9 end
  return n
end

WEIR_CAMPOS = {
  function() return {
    F("w_etype", "Elemento", nil, nil, nil, ET_NAMES),
    F("w_mode", "Calcular", nil, nil, nil, {"Dado H -> Q", "Dado Q -> H"}),
    F("w_cd", "Cd", dcdw, pcdw),
    F("w_d1", D1_LAB[TOG.w_etype or 1]),
    F("w_d2", "Alto a (orif.rect) [m]", "", "-"),
    F("w_nc", "Contracciones 0-2", "", "0"),
    F("w_H", "Carga H [m]", "", "-", "w_mode", nil, 1),
    F("w_Q", "Caudal Q [" .. qunit_txt() .. "]", "", "-", "w_mode", nil, 2),
    F("w_qunit", "Unidad de Q", nil, nil, nil, {"l/s", "m3/s"}),
    F("w_hup", "Nivel arriba (opc) [m]", "", "-")} end,
  function()
    local fs = {F("w_ne", "Numero elementos", 2, "2"),
      F("w_cmode", "Calcular", nil, nil, nil, {"Nivel h -> Q", "Q -> nivel h"}),
      F("w_h", "Nivel h [m]", "", "-", "w_cmode", nil, 1),
      F("w_Q", "Q total [" .. qunit_txt() .. "]", "", "-", "w_cmode", nil, 2),
      F("w_qunit", "Unidad de Q", nil, nil, nil, {"l/s", "m3/s"})}
    for i = 1, nelems() do
      fs[#fs + 1] = F("w_et" .. i, i .. " Tipo", nil, nil, nil, ET_NAMES)
      fs[#fs + 1] = F("w_n" .. i, i .. " Cantidad", 1, "1")
      fs[#fs + 1] = F("w_d1" .. i, i .. " theta/b/d")
      fs[#fs + 1] = F("w_d2" .. i, i .. " a (orif.rect) [m]", "", "-")
      fs[#fs + 1] = F("w_z" .. i, i .. " Cota z [m]")
      fs[#fs + 1] = F("w_cd" .. i, i .. " Cd (opc)", "", ng(CFG.cd_weir))
    end
    return fs
  end,
  function()
    local fs = {F("w_pmode", "Perfil", nil, nil, nil, {"v = k y^n", "Tabla (y, v)"}),
                F("w_b", "Ancho b [m]")}
    if (TOG.w_pmode or 1) == 1 then
      fs[#fs + 1] = F("w_ph", "Tirante h [m]")
      fs[#fs + 1] = F("w_k", "k (v = k y^n)")
      fs[#fs + 1] = F("w_pn", "n (v = k y^n)")
    else
      fs[#fs + 1] = F("w_np", "Numero de puntos", 5, "5")
      for i = 1, npuntos() do
        fs[#fs + 1] = F("w_y" .. i, i .. " y (desde fondo) [m]")
        fs[#fs + 1] = F("w_v" .. i, i .. " v [m/s]")
      end
    end
    return fs
  end,
  function() return {
    F("w_smode", "Calcular", nil, nil, nil, {"Solo seccion 1", "h2 por Bernoulli"}),
    F("w_sQ", "Caudal Q [" .. qunit_txt() .. "]"),
    F("w_qunit", "Unidad de Q", nil, nil, nil, {"l/s", "m3/s"}),
    F("w_sb", "Ancho b [m]"), F("w_h1", "Tirante h1 [m]"),
    F("w_dz", "Escalon dz (opc) [m]", "", "0")} end,
}

function cnu() return CFG.nu end
CHAN_CAMPOS = {
  function() return {
    F("c_D1", "D1 entrada [mm]"), F("c_D2", "D2 garganta (opc) [mm]", "", "-"),
    F("c_beta", "o D2/D1 (opc)", "", "-"),
    F("c_Q", "Caudal Q (o v1) [" .. (((TOG.c_qunit or 1) == 2) and "m3/s" or "l/s") .. "]", "", "-"),
    F("c_qunit", "Unidad de Q", nil, nil, nil, {"l/s", "m3/s"}),
    F("c_v1", "o v1 (opc) [m/s]", "", "-"),
    F("c_Cv", "Cv", 1, "1"), F("c_S", "S manometro (opc)", "", "-"),
    F("c_conv", "Manometro", nil, nil, nil, {"(S-1) g h fisico", "S g h examen"})} end,
  function() return {
    F("c_Qj", "Caudal Q [m3/s]"), F("c_b", "Ancho b [m]"),
    F("c_ymode", "Dato", nil, nil, nil, {"Dado y1", "Dado y2"}),
    F("c_y", "Tirante y1 o y2 [m]")} end,
  function() return {
    F("c_H", "Carga H [m]"), F("c_L", "Longitud L [m]"), F("c_D", "Diametro D [mm]"),
    F("c_ks", "Rugosidad ks [mm]"), F("c_nu", "Viscosidad [m2/s]", cnu, pnu),
    F("c_K", "Suma K", 0, "0"),
    F("c_exitk", "Energia salida", nil, nil, nil, {"No (SumK = K)", "Si (SumK + 1)"}),
    F("c_th", "Angulo theta [grad]", 30, "30"), fmet} end,
}

-- ============================ CASOS FLUJOS ============================
FL_CASOS = {
  "AR-01 Paracaidista (T4-2 P1)", "AR-02 Torre y tanque (T4-2 P4)",
  "AR-03 Cubo en agua (T4-2 P5)", "AR-04 Avion A-330 (2017 P2)",
  "AR-05 Esfera en flujo lento (Stokes)", "AR-06 Placa plana en aire",
  "VE-01 Triang. + 3 orificios (2024 P5a)", "VE-02 Nivel con 0.5 m3/s (2024 P5b)",
  "VE-03 Triangular, 200 l/s (2025 P4a)", "VE-04 Triang., 260.64 l/s (2025 P4b)",
  "VE-05 Triang. 60, 16 l/s (T4-2 P2a)", "VE-06 Reparto 36 l/s (T4-2 P2b)",
  "VE-07 Perfil v = 2 y^2 (T4-2 P3a)", "VE-08 Cota de la cresta (T4-2 P3b)",
  "EX-01 Venturi (2025 P4c)", "EX-02 Salto hidraulico (2017 P3)",
  "EX-03 Chorro desde un tubo (2025)",
}

function limpiar(pref)
  for k in pairs(MEM) do if k:sub(1, #pref) == pref then MEM[k] = nil end end
  for k in pairs(TOG) do if k:sub(1, #pref) == pref then TOG[k] = nil end end
end
function SM(k, x) MEM[k] = {numstr(x)} end

-- devuelve modulo ("d", "w", "c") y tipo
function preset_flujos(k)
  if k <= 6 then
    limpiar("d_")
    SM("d_nw", 2); SM("d_nb", 2); SM("d_rho", 1.2); SM("d_nu", 1.5e-5)
    TOG.d_fluid = 1
    if k == 1 then
      SM("d_W", 950); SM("d_cd", 1.3); SM("d_fig", 5); SM("d_D", 8)
      return "d", 2
    elseif k == 2 then
      SM("d_V", 100); TOG.d_vunit = 2
      SM("d_cd1", 0.9166667); SM("d_fig1", 11); SM("d_D1", 2); SM("d_L1", 30); SM("d_y1", 15)
      SM("d_cd2", 0.5); SM("d_fig2", 1); SM("d_D2", 12); SM("d_y2", 36)
      return "d", 3
    elseif k == 3 then
      TOG.d_fluid = 2; SM("d_rho", 1000); SM("d_nu", 1e-6)
      SM("d_W", 19.8); SM("d_vol", 0.001); SM("d_cd", 0.8); SM("d_fig", 10); SM("d_D", 0.1)
      return "d", 2
    elseif k == 4 then
      SM("d_W", 3.9e6); SM("d_V", 480); TOG.d_vunit = 3; SM("d_h", 10675)
      SM("d_Aw", 180.8); SM("d_cdf", 1); SM("d_Df", 5.28)
      return "d", 4
    elseif k == 5 then
      TOG.d_kase = 2; TOG.d_fluid = 2; SM("d_rho", 1000); SM("d_nu", 1e-6)
      SM("d_V", 0.001); SM("d_D", 0.001)
      return "d", 5
    end
    SM("d_V", 10); SM("d_D", 2); SM("d_L", 1); TOG.d_regime = 3
    return "d", 5
  elseif k <= 14 then
    local j = k - 7
    limpiar("w_")
    SM("w_cd", CFG.cd_weir); SM("w_ne", 2); SM("w_np", 5)
    local function el(i, tp, n, d1, z)
      TOG["w_et" .. i] = tp; SM("w_n" .. i, n); SM("w_d1" .. i, d1); SM("w_z" .. i, z)
    end
    if j == 0 or j == 1 then
      el(1, WE_TRI, 1, 90, 1.4)
      el(2, WE_ORC, 3, 0.2, 0.1)
      if j == 0 then SM("w_h", 2)
      else TOG.w_cmode = 2; TOG.w_qunit = 2; SM("w_Q", 0.5) end
      return "w", 2
    elseif j == 5 then
      TOG.w_cmode = 2; SM("w_Q", 36)
      el(1, WE_TRI, 1, 60, 0)
      el(2, WE_RECT, 1, 1.3, 0.20724)
      return "w", 2
    elseif j == 6 then
      SM("w_b", 2); SM("w_ph", 1); SM("w_k", 2); SM("w_pn", 2)
      return "w", 3
    end
    TOG.w_etype = WE_TRI; TOG.w_mode = 2
    SM("w_d1", (j == 4) and 60 or 90)
    SM("w_Q", (j == 2) and 200 or ((j == 3) and 260.64 or ((j == 4) and 16 or 1.3333333)))
    if j == 7 then TOG.w_qunit = 2; SM("w_hup", 1) end
    return "w", 1
  end
  local j = k - 15
  limpiar("c_")
  SM("c_Cv", 1); SM("c_nu", 1e-6); SM("c_K", 0); SM("c_th", 30)
  TOG.c_conv = (CFG.mano or 0) + 1
  if j == 0 then
    SM("c_D1", 285.75); SM("c_beta", 0.6); SM("c_Q", 200); SM("c_S", 4)
    return "c", 1
  elseif j == 1 then
    SM("c_Qj", 12); SM("c_b", 2); SM("c_y", 0.4)
    return "c", 2
  end
  SM("c_H", 7.5); SM("c_L", 5); SM("c_D", 30); SM("c_ks", 0.045); SM("c_nu", 1.007e-6)
  return "c", 3
end

-- ============== PROGRAMA ORIGINAL (Tuberias hf + hL) ==============
local G0, GAM0, TOL0, NMAX0 = 9.81, 9810.0, 1e-4, 40
-- (cada paso se redondea con r3 y se muestra con 3 decimales)

function o_colebrook(Re, eD)
  if Re < 2000 then return r3(64 / Re) end
  local f, f1, fp2 = 0.02, 0.02, nil
  for _ = 1, 100 do
    f1 = r3((-2 * log10(eD / 3.71 + 2.51 / (Re * sqrt(f)))) ^ -2)
    if f1 == f or f1 == fp2 then break end
    fp2 = f
    f = f1
  end
  return f1
end
function o_re(Q, D, nu) return r3(4 * Q / (pi * D * nu)) end
function o_k8(Q, D) return r3(8 * Q * Q / (G0 * pi * pi * D ^ 4)) end
function o_reg(Re)
  if Re < 2000 then return "Laminar" end
  if Re < 4000 then return "Transicional" end
  return "Turbulento"
end
function o_tabla_f(Re, eD)
  if Re < 2000 then return r3(64 / Re), nil, {"Laminar: f = 64/Re"} end
  local rows, f0, f1 = {}, 0.05, 0.05
  local ok = false
  for i = 1, NMAX0 do
    f1 = r3((-2 * log10(eD / 3.71 + 2.51 / (Re * sqrt(f0)))) ^ -2)
    rows[#rows + 1] = {tostring(i), fmt3(f0), fmt3(f1)}
    if abs(f1 - f0) < TOL0 then ok = true; break end
    f0 = f1
  end
  local w = {}
  if not ok then w = {"Aviso: max. iteraciones"} end
  return f1, {hdr = {"i", "f0", "f1"}, xs = {12, 70, 180}, rows = rows}, w
end
function o_pot(P)
  P = r3(P)
  return {{"P", fmt3(P) .. " W"}, {"P", fmt3(r3(P / 1000)) .. " kW"}, {"P", fmt3(r3(P / 745.7)) .. " HP"}}
end
function cat(...)
  local r = {}
  for _, t in ipairs({...}) do for _, x in ipairs(t) do r[#r + 1] = x end end
  return r
end
function pos(x, n) if x == nil or x <= 0 then herr(n .. " debe ser > 0") end end
function u3(x, u) return fmt3(x) .. (u and (" " .. u) or "") end

-- memoria del programa original: escribe con mline/meq en una lista aparte
function omemo(fn)
  local saved = VW
  VW = {}
  fn()
  local L = VW
  VW = saved
  return L
end

-- raiz positiva de a Q^3 - b Q - c = 0 (Newton desde la derecha)
function raiz_cubica(a, b, c)
  local x = math.max((c / a) ^ (1 / 3), sqrt(math.max(b, 0) / a)) * 2 + 1e-9
  for _ = 1, 80 do
    local fx = a * x * x * x - b * x - c
    local d = 3 * a * x * x - b
    if d == 0 then break end
    local xn = x - fx / d
    if abs(xn - x) <= 1e-13 * abs(x) then x = xn; break end
    x = xn
  end
  return rls(x)
end

-- datos de la bomba para el programa original
function o_bomba(v)
  local b = {on = bomba_activa(), pot = bomba_potencia(), HB = 0, bpg = 0}
  if b.on then
    if b.pot then
      carga_bomba(v, 1)                           -- valida P y eta
      b.P, b.eta = v.bP, v.bEta
      b.bpg = v.bEta * v.bP * 1000 / CFG.gamma      -- eta P/gamma (sin redondear)
    else
      b.HB = carga_bomba(v, 1)
    end
  end
  return b
end

function o_memo_bomba(b, Q)
  if not b.on then return end
  msec("BOMBA")
  mline(" Energia: dZ + HB = (c + f L/D + SumK) V^2/2g", "gray")
  if b.pot then
    vval("Potencia P", b.P, "kW")
    vval("Eficiencia eta", b.eta)
    meq("eta P/gamma", nil, fv(b.eta) .. "(" .. fv(b.P * 1000) .. ")/" .. fv(CFG.gamma), b.bpg, "m4/s")
    if Q then
      meq("HB", "eta P/(gamma Q)", fv(b.eta) .. "(" .. fv(b.P * 1000) .. ")/(" .. fv(CFG.gamma) ..
          "(" .. fv(Q) .. "))", r3(b.bpg / Q), "m")
    end
  else
    vval("HB (dato)", b.HB, "m")
  end
end

function oc_Q(v)
  local c = ((TOG.cs or 1) == 1) and 1 or 0
  local dz, D, L, ks, nu, K, f0 = v.dz, rmm(v.D / 1000), v.L, r3(v.ks / 1000), v.nu0, v.K, v.f0
  pos(D, "D"); pos(nu, "nu")
  local b = o_bomba(v)
  local dzf = r3(dz + b.HB)
  if not b.pot and not (dzf > 0) then herr(b.on and "dZ + HB debe ser > 0" or "dZ debe ser > 0") end
  local eD = r3(ks / D)
  local LD = r3(L / D)
  local k4 = r3(G0 * pi * pi * D ^ 4)
  -- Q con un f dado; devuelve Q, C = c + f L/D + SumK, a
  local function Qf(x)
    local Cc = r3(c + r3(x * LD) + K)
    if b.pot then
      local a = r3(8 * Cc / k4)
      return raiz_cubica(a, dz, b.bpg), Cc, a
    end
    return rls(sqrt(dzf * k4 / (8 * Cc))), Cc, 0
  end
  local rows, ok = {}, false
  local Qi, C0, a0 = Qf(f0)
  local Qn, Qp2 = Qi, nil
  local f = f0
  local it1
  for i = 1, NMAX0 do
    local Re = o_re(Qi, D, nu)
    f = o_colebrook(Re, eD)
    local Cn, an
    Qn, Cn, an = Qf(f)
    if i == 1 then it1 = {Q1 = Qi, Re = Re, f = f, Q2 = Qn, C1 = Cn, a1 = an} end
    local row = {tostring(i), fmt3(r3(Qi * 1000)), fmt3(Re), fmt3(f), fmt3(r3(Qn * 1000))}
    if b.pot then row[6] = fmt3(r3(b.bpg / Qn)) end
    rows[#rows + 1] = row
    if abs(Qn - Qi) * 1000 < TOL0 or Qn == Qp2 then ok = true; break end
    Qp2 = Qi
    Qi = Qn
  end
  local HB = b.pot and r3(b.bpg / Qn) or b.HB
  local V = r3(Qn / area(D))
  local hv = o_k8(Qn, D)
  local hf, hl = r3(f * LD * hv), r3(K * hv)
  local r = {{"Caudal Q", u3(r3(Qn * 1000), "l/s")}, {"Q", u3(Qn, "m3/s")},
    {"V", u3(V, "m/s")}, {"f", fmt3(f)}, {"e/D", fmt3(eD)},
    {"Re", fmt3(o_re(Qn, D, nu))}, {"hf", u3(hf, "m")},
    {"hL", u3(hl, "m")}}
  if b.on then
    r[#r + 1] = {"HB bomba", u3(HB, "m")}
    r[#r + 1] = {"dZ + HB", u3(r3(dz + HB), "m")}
  end
  r[#r + 1] = {"Iteraciones", tostring(#rows)}
  local hdr = {"i", "Qi l/s", "Re", "f", "Qi+1"}
  if b.pot then hdr[6] = "HB m" end
  local res = R(r, {hdr = hdr, xs = {6, 30, 100, 170, 240}, rows = rows},
                ok and {} or {"Aviso: max. iteraciones"})
  res.mlines = omemo(function()
    vadd("MEMORIA  Calculo de Q", "title")
    vsep()
    msec("DATOS")
    vval("dZ = z1 - z2", dz, "m")
    vval("D", D, "m"); vval("L", L, "m"); vval("ks", ks, "m")
    vval("nu", nu, "m2/s"); vval("Suma K", K); vval("c (salida)", c)
    vval("f inicial", f0); vval("g", G0, "m/s2")
    o_memo_bomba(b, nil)
    if b.on and not b.pot then
      meq("H", "dZ + HB", fv(dz) .. " + " .. fv(b.HB), dzf, "m")
    end
    msec("ITERACION 1")
    meq("e/D", "ks/D", fv(ks) .. "/" .. fv(D), eD)
    meq("L/D", nil, fv(L) .. "/" .. fv(D), LD)
    meq("C0", "c + f L/D + SumK", fv(c) .. " + " .. fv(f0) .. "(" .. fv(LD) .. ") + " .. fv(K), C0)
    if b.pot then
      mline("(dZ + eta P/(gamma Q)) = C 8 Q^2/(g pi^2 D^4)")
      mline(" => a Q^3 - dZ Q - eta P/gamma = 0", "gray")
      meq("a", "8 C0/(g pi^2 D^4)", "8(" .. fv(C0) .. ")/(" .. fv(G0) .. " pi^2 (" .. fv(D) .. ")^4)", a0)
      meq("Q1", nil, "raiz de " .. fv(a0) .. " Q^3 - (" .. fv(dz) .. ") Q - " .. fv(b.bpg), it1.Q1, "m3/s")
      meq("HB1", "eta P/(gamma Q1)", fv(b.eta) .. "(" .. fv(b.P * 1000) .. ")/(" .. fv(CFG.gamma) ..
          "(" .. fv(it1.Q1) .. "))", r3(b.bpg / it1.Q1), "m")
    else
      local Hs = b.on and "(dZ + HB)" or "dZ"
      meq("Q1", "sqrt(" .. Hs .. " g pi^2 D^4/(8 C0))",
          "sqrt(" .. fv(dzf) .. "(" .. fv(G0) .. ")pi^2(" .. fv(D) .. ")^4/(8(" .. fv(C0) .. ")))",
          it1.Q1, "m3/s")
    end
    meq("Re1", "4 Q1/(pi D nu)", "4(" .. fv(it1.Q1) .. ")/(pi(" .. fv(D) .. ")(" .. fv(nu) .. "))", it1.Re)
    mline("1/sqrt(f) = -2 log(e/(3.71 D) + 2.51/(Re sqrt(f)))")
    mline("      = -2 log(" .. fv(eD) .. "/3.71 + 2.51/(" .. fv(it1.Re) .. " sqrt(f)))", "gray")
    mres("f1 (Colebrook)", it1.f)
    meq("C1", "c + f1 L/D + SumK", fv(c) .. " + " .. fv(it1.f) .. "(" .. fv(LD) .. ") + " .. fv(K), it1.C1)
    if b.pot then
      meq("a", "8 C1/(g pi^2 D^4)", "8(" .. fv(it1.C1) .. ")/(" .. fv(G0) .. " pi^2 (" .. fv(D) .. ")^4)", it1.a1)
      meq("Q2", nil, "raiz de " .. fv(it1.a1) .. " Q^3 - (" .. fv(dz) .. ") Q - " .. fv(b.bpg), it1.Q2, "m3/s")
    else
      local Hs = b.on and "(dZ + HB)" or "dZ"
      meq("Q2", "sqrt(" .. Hs .. " g pi^2 D^4/(8 C1))",
          "sqrt(" .. fv(dzf) .. "(" .. fv(G0) .. ")pi^2(" .. fv(D) .. ")^4/(8(" .. fv(it1.C1) .. ")))",
          it1.Q2, "m3/s")
    end
    mline(" |Q2 - Q1| = " .. fv(r3(abs(it1.Q2 - it1.Q1) * 1000)) .. " l/s", "gray")
    msec("ITERACIONES SIGUIENTES")
    mline(" Se repite con Qi+1 hasta |Qi+1 - Qi| < 1E-4 l/s", "gray")
    mline(" Total: " .. #rows .. " iteraciones (tab: ver la tabla)", "gray")
    msec("RESULTADO")
    mres("Q", r3(Qn * 1000), "l/s")
    meq("V", "Q/A", fv(Qn) .. "/" .. fv(area(D)), V, "m/s")
    meq("V^2/2g", "8 Q^2/(g pi^2 D^4)", nil, hv, "m")
    meq("hf", "f (L/D) V^2/2g", fv(f) .. "(" .. fv(LD) .. ")(" .. fv(hv) .. ")", hf, "m")
    meq("hL", "SumK V^2/2g", fv(K) .. "(" .. fv(hv) .. ")", hl, "m")
    if b.on then mres("HB", HB, "m") end
  end)
  return res
end

function oc_D(v)
  local c = ((TOG.cs or 1) == 1) and 1 or 0
  local dz, Q, L, ks, nu, K, Di = v.dz, rls(v.Q / 1000), v.L, r3(v.ks / 1000), v.nu0, v.K, rmm(v.D0 / 1000)
  pos(Q, "Q"); pos(nu, "nu"); pos(Di, "D inicial")
  local b = o_bomba(v)
  local HB = b.pot and r3(b.bpg / Q) or b.HB
  local dzf = r3(dz + HB)
  if not (dzf > 0) then herr(b.on and "dZ + HB debe ser > 0" or "dZ debe ser > 0") end
  local A = r3(8 * Q * Q / (pi * pi * G0 * dzf))
  local D1 = Di
  local rows, ok, Dn, f, Dp2 = {}, false, Di, 0, nil
  local it1
  for i = 1, NMAX0 do
    local eD = r3(ks / Di)
    local Re = o_re(Q, Di, nu)
    f = o_colebrook(Re, eD)
    local LDi = r3(L / Di)
    Dn = rmm((A * (r3(f * LDi) + K + c)) ^ 0.25)
    if i == 1 then it1 = {eD = eD, Re = Re, f = f, LD = LDi, D2 = Dn} end
    rows[#rows + 1] = {tostring(i), fmt3(r3(Di * 1000)), fmt3(eD), fmt3(Re), fmt3(f), fmt3(r3(Dn * 1000))}
    if abs(Dn - Di) * 1000 < TOL0 or Dn == Dp2 then ok = true; break end
    Dp2 = Di
    Di = Dn
  end
  local r = {{"Diametro D", u3(r3(Dn * 1000), "mm")}, {"V", u3(r3(Q / area(Dn)), "m/s")},
    {"f", fmt3(f)}, {"Re", fmt3(o_re(Q, Dn, nu))}}
  if b.on then
    r[#r + 1] = {"HB bomba", u3(HB, "m")}
    r[#r + 1] = {"dZ + HB", u3(dzf, "m")}
  end
  r[#r + 1] = {"Iteraciones", tostring(#rows)}
  local res = R(r, {hdr = {"i", "Di mm", "e/D", "Re", "f", "Di+1"}, xs = {4, 20, 80, 146, 204, 258}, rows = rows},
                ok and {} or {"Aviso: max. iteraciones"})
  res.mlines = omemo(function()
    vadd("MEMORIA  Calculo de D", "title")
    vsep()
    msec("DATOS")
    vval("dZ = z1 - z2", dz, "m"); vval("Q", Q, "m3/s"); vval("L", L, "m")
    vval("ks", ks, "m"); vval("nu", nu, "m2/s"); vval("Suma K", K)
    vval("c (salida)", c); vval("D inicial", D1, "m"); vval("g", G0, "m/s2")
    o_memo_bomba(b, Q)
    local Hs = "dZ"
    if b.on then
      Hs = "H"
      meq("H", "dZ + HB", fv(dz) .. " + " .. fv(HB), dzf, "m")
    end
    msec("CONSTANTE")
    mline(Hs .. " = (c + f L/D + SumK) 8 Q^2/(g pi^2 D^4)", "gray")
    mline(" => D = [A (f L/D + SumK + c)]^(1/4)", "gray")
    meq("A", "8 Q^2/(pi^2 g " .. Hs .. ")", "8(" .. fv(Q) .. ")^2/(pi^2(" .. fv(G0) .. ")(" .. fv(dzf) .. "))", A)
    msec("ITERACION 1  (D1 = " .. fv(D1) .. " m)")
    meq("e/D1", "ks/D1", fv(ks) .. "/" .. fv(D1), it1.eD)
    meq("Re1", "4 Q/(pi D1 nu)", "4(" .. fv(Q) .. ")/(pi(" .. fv(D1) .. ")(" .. fv(nu) .. "))", it1.Re)
    mline("1/sqrt(f) = -2 log(e/(3.71 D) + 2.51/(Re sqrt(f)))")
    mline("      = -2 log(" .. fv(it1.eD) .. "/3.71 + 2.51/(" .. fv(it1.Re) .. " sqrt(f)))", "gray")
    mres("f1 (Colebrook)", it1.f)
    meq("L/D1", nil, fv(L) .. "/" .. fv(D1), it1.LD)
    meq("D2", "[A (f1 L/D1 + SumK + c)]^(1/4)",
        "[" .. fv(A) .. "(" .. fv(it1.f) .. "(" .. fv(it1.LD) .. ") + " .. fv(K) .. " + " .. fv(c) .. ")]^(1/4)",
        it1.D2, "m")
    mline(" |D2 - D1| = " .. fv(r3(abs(it1.D2 - D1) * 1000)) .. " mm", "gray")
    msec("ITERACIONES SIGUIENTES")
    mline(" Se repite con Di+1 hasta |Di+1 - Di| < 1E-4 mm", "gray")
    mline(" Total: " .. #rows .. " iteraciones (tab: ver la tabla)", "gray")
    msec("RESULTADO")
    mres("D", r3(Dn * 1000), "mm")
    meq("V", "Q/A", fv(Q) .. "/" .. fv(area(Dn)), r3(Q / area(Dn)), "m/s")
  end)
  return res
end

-- perdidas con Q conocido (H bomba, H turbina y perdidas totales)
function o_perd(v)
  local Q, D, L, ks, nu, K = rls(v.Q / 1000), rmm(v.D / 1000), v.L, r3(v.ks / 1000), v.nu0, v.K
  pos(Q, "Q"); pos(D, "D"); pos(nu, "nu")
  local p = {Q = Q, D = D, L = L, ks = ks, nu = nu, K = K}
  p.Re = o_re(Q, D, nu)
  p.eD = r3(ks / D)
  local f, t, w = o_tabla_f(p.Re, p.eD)
  p.f = f
  p.lam = p.Re < 2000
  if not p.lam then
    p.f1 = r3((-2 * log10(p.eD / 3.71 + 2.51 / (p.Re * sqrt(0.05)))) ^ -2)
    p.nit = #t.rows
  end
  p.A = area(D)
  p.V = r3(Q / p.A)
  p.LD = r3(L / D)
  p.hv = o_k8(Q, D)
  p.hf, p.hl = r3(f * p.LD * p.hv), r3(K * p.hv)
  p.hT = r3(p.hf + p.hl)
  p.cs = (TOG.cs or 1) == 1
  p.vs = 0
  if p.cs then p.vs = v.vs or p.V end
  p.hs = r3(p.vs * p.vs / (2 * G0))
  local r = {{"f", fmt3(f)}, {"Re", fmt3(p.Re) .. " (" .. o_reg(p.Re) .. ")"},
    {"V", u3(p.V, "m/s")}, {"V2/2g", u3(p.hv, "m")}, {"hf", u3(p.hf, "m")},
    {"hL", u3(p.hl, "m")}, {"hT = hf+hL", u3(p.hT, "m")}}
  if p.cs then r[#r + 1] = {"Vs2/2g", u3(p.hs, "m")} end
  return Q, p.hT, p.hs, r, t, w, p
end

-- memoria comun de perdidas (primera iteracion de f incluida)
function o_memo_perd(p, titulo, extra)
  vadd("MEMORIA  " .. titulo, "title")
  vsep()
  msec("DATOS")
  if extra then extra() end
  vval("Q", p.Q, "m3/s"); vval("D", p.D, "m"); vval("L", p.L, "m")
  vval("ks", p.ks, "m"); vval("nu", p.nu, "m2/s"); vval("Suma K", p.K)
  vval("g", G0, "m/s2")
  msec("CALCULOS")
  meq("A", "pi D^2/4", "pi(" .. fv(p.D) .. ")^2/4", p.A, "m2")
  meq("V", "Q/A", fv(p.Q) .. "/" .. fv(p.A), p.V, "m/s")
  meq("Re", "4 Q/(pi D nu)", "4(" .. fv(p.Q) .. ")/(pi(" .. fv(p.D) .. ")(" .. fv(p.nu) .. "))", p.Re)
  meq("e/D", "ks/D", fv(p.ks) .. "/" .. fv(p.D), p.eD)
  if p.lam then
    meq("f", "64/Re", "64/" .. fv(p.Re), p.f)
  else
    msec("f: ITERACION 1 (f0 = 0.05)")
    mline("f1 = [-2 log(e/(3.71 D) + 2.51/(Re sqrt(f0)))]^-2")
    mline("   = [-2 log(" .. fv(p.eD) .. "/3.71 + 2.51/(" .. fv(p.Re) .. " sqrt(5.000E-2)))]^-2", "gray")
    mres("f1", p.f1)
    mline(" Se repite hasta |f1 - f0| < 1E-4: " .. p.nit .. " iteraciones", "gray")
    mline(" (tab: ver la tabla)", "gray")
    mres("f", p.f)
  end
  meq("V^2/2g", "8 Q^2/(g pi^2 D^4)", nil, p.hv, "m")
  meq("hf", "f (L/D) V^2/2g", fv(p.f) .. "(" .. fv(p.LD) .. ")(" .. fv(p.hv) .. ")", p.hf, "m")
  meq("hL", "SumK V^2/2g", fv(p.K) .. "(" .. fv(p.hv) .. ")", p.hl, "m")
  meq("hT", "hf + hL", fv(p.hf) .. " + " .. fv(p.hl), p.hT, "m")
  if p.cs then meq("Vs^2/2g", nil, "(" .. fv(p.vs) .. ")^2/(2(" .. fv(G0) .. "))", p.hs, "m") end
end

function oc_HB(v)
  local Q, hT, hs, r, t, w, p = o_perd(v)
  pos(v.eta, "Eficiencia")
  local HB = r3(v.dz + hs + hT)
  local P = r3(GAM0 * Q * HB / v.eta)
  local res = R(cat({{"Altura bomba HB", u3(HB, "m")}}, o_pot(P), r), t, w)
  res.mlines = omemo(function()
    o_memo_perd(p, "H bomba", function() vval("dZ = z2 - z1", v.dz, "m"); vval("eta", v.eta) end)
    msec("BOMBA")
    meq("HB", "dZ + Vs^2/2g + hT", fv(v.dz) .. " + " .. fv(hs) .. " + " .. fv(hT), HB, "m")
    meq("P", "gamma Q HB/eta", fv(GAM0) .. "(" .. fv(Q) .. ")(" .. fv(HB) .. ")/" .. fv(v.eta), P, "W")
  end)
  return res
end
function oc_HT(v)
  local Q, hT, hs, r, t, w, p = o_perd(v)
  local HT = r3(v.dz - hs - hT)
  local P = r3(GAM0 * Q * HT * v.eta)
  local res = R(cat({{"Altura turbina HTur", u3(HT, "m")}}, o_pot(P), r), t, w)
  res.mlines = omemo(function()
    o_memo_perd(p, "H turbina", function() vval("dZ = z1 - z2", v.dz, "m"); vval("eta", v.eta) end)
    msec("TURBINA")
    meq("HT", "dZ - Vs^2/2g - hT", fv(v.dz) .. " - " .. fv(hs) .. " - " .. fv(hT), HT, "m")
    meq("P", "gamma Q HT eta", fv(GAM0) .. "(" .. fv(Q) .. ")(" .. fv(HT) .. ")(" .. fv(v.eta) .. ")", P, "W")
  end)
  return res
end
function oc_hT(v)
  local Q, hT, hs, r, t, w, p = o_perd(v)
  local b = o_bomba(v)
  local HB = b.pot and r3(b.bpg / Q) or b.HB
  local dZ = r3(hT + hs - HB)
  local lab = b.on and "Desnivel dZ = hT+Vs2/2g-HB" or "Desnivel dZ = hT+Vs2/2g"
  local top = {{lab, u3(dZ, "m")}}
  if b.on then top[#top + 1] = {"HB bomba", u3(HB, "m")} end
  local res = R(cat(top, r), t, w)
  res.mlines = omemo(function()
    o_memo_perd(p, "Perdidas totales", nil)
    o_memo_bomba(b, Q)
    msec("DESNIVEL")
    if b.on then
      mline(" Energia: dZ + HB = hT + Vs^2/2g", "gray")
      meq("dZ", "hT + Vs^2/2g - HB", fv(hT) .. " + " .. fv(hs) .. " - " .. fv(HB), dZ, "m")
    else
      meq("dZ", "hT + Vs^2/2g", fv(hT) .. " + " .. fv(hs), dZ, "m")
    end
  end)
  return res
end

function oi_V(v) pos(v.D, "D"); return R({{"V = Q/A", u3(r3(rls(v.Q / 1000) / area(rmm(v.D / 1000))), "m/s")}}) end
function oi_Q(v)
  local Q = r3(v.V * area(rmm(v.D / 1000)))
  return R({{"Q = V*A", u3(r3(Q * 1000), "l/s")}, {"Q", u3(Q, "m3/s")}})
end
function oi_Re(v)
  pos(v.D, "D"); pos(v.nu0, "nu")
  local D, V = rmm(v.D / 1000), nil
  if v.Q ~= nil then V = r3(rls(v.Q / 1000) / area(D)) elseif v.V ~= nil then V = v.V else herr("Ingresa Q o V") end
  local Re = r3(V * D / v.nu0)
  return R({{"Reynolds", fmt3(Re)}, {"Regimen", o_reg(Re)}, {"V", u3(V, "m/s")}})
end
function oi_eD(v) pos(v.D, "D"); return R({{"e/D", fmt3(r3(v.ks / v.D))}}) end
function oi_f(v)
  pos(v.Re, "Re")
  local f, t, w = o_tabla_f(r3(v.Re), r3(v.eD))
  return R({{"f Colebrook", fmt3(f)}, {"Regimen", o_reg(v.Re)}}, t, w)
end
function oi_hf(v)
  pos(v.Q, "Q"); pos(v.D, "D")
  local Q, D, f = rls(v.Q / 1000), rmm(v.D / 1000), v.f
  local t, w, r = nil, {}, {}
  if f == nil then
    if v.ks == nil then herr("Ingresa f o ks") end
    pos(v.nu0, "nu")
    local Re = o_re(Q, D, v.nu0)
    f, t, w = o_tabla_f(Re, r3(r3(v.ks / 1000) / D))
    r = {{"f", fmt3(f)}, {"Re", fmt3(Re)}}
  end
  return R(cat({{"hf = fLV2/(2gD)", u3(r3(f * r3(v.L / D) * o_k8(Q, D)), "m")}}, r), t, w)
end
function oi_hL(v) pos(v.D, "D"); return R({{"hL = K V2/2g", u3(r3(v.K * o_k8(rls(v.Q / 1000), rmm(v.D / 1000))), "m")}}) end
function oi_K(v)
  pos(v.Q, "Q"); pos(v.D, "D")
  return R({{"K = 2g hL/V2", fmt3(r3(v.hl / o_k8(rls(v.Q / 1000), rmm(v.D / 1000))))}})
end
function oi_hv(v)
  local V
  if v.V ~= nil then V = v.V
  elseif v.Q ~= nil and v.D ~= nil then pos(v.D, "D"); V = r3(rls(v.Q / 1000) / area(rmm(v.D / 1000)))
  else herr("Ingresa V, o Q y D") end
  return R({{"V2/2g", u3(r3(V * V / (2 * G0)), "m")}, {"V", u3(V, "m/s")}})
end
function oi_PB(v) pos(v.eta, "Eficiencia"); return R(o_pot(GAM0 * rls(v.Q / 1000) * v.HB / v.eta)) end
function oi_PT(v) return R(o_pot(GAM0 * rls(v.Q / 1000) * v.HTu * v.eta)) end

local fcs  = F("cs", "Vel. salida", nil, nil, nil, {"Si (libre)", "No (tanque)"})
local fnu0 = F("nu0", "nu [m2/s]", 1.02e-6, "1.02e-6")
local fvs  = F("vs", "Vs [m/s]", "", "Q/A", "cs", nil, 1)
local feta = F("eta", "Eficiencia", 1, "1")
local fQo  = F("Q", "Q [l/s]", "", "opcional")
local fVo  = F("V", "V [m/s]", "", "opcional")
local fDo  = F("D", "D [mm]", "", "opcional")
local fQ2  = F("Q", "Q [l/s]")
local fD2  = F("D", "D [mm]")
local fL2  = F("L", "L [m]")
local fks2 = F("ks", "ks [mm]")

local ORIG = {
  {"Calculo de Q", con_bomba({fcs, F("dz", "dZ = z1-z2 [m]"), fD2, fL2, fks2, fnu0, fK, F("f0", "f inicial", 0.02, "0.02")}), oc_Q},
  {"Calculo de D", con_bomba({fcs, F("dz", "dZ = z1-z2 [m]"), fQ2, fL2, fks2, fnu0, fK, F("D0", "D inicial [mm]", 100, "100")}), oc_D},
  {"H bomba", {fcs, F("dz", "dZ=z2-z1 [m]"), fQ2, fD2, fL2, fks2, fnu0, fK, fvs, feta}, oc_HB},
  {"H turbina", {fcs, F("dz", "dZ=z1-z2 [m]"), fQ2, fD2, fL2, fks2, fnu0, fK, fvs, feta}, oc_HT},
  {"Perdidas totales", con_bomba({fcs, fQ2, fD2, fL2, fks2, fnu0, fK, fvs}), oc_hT},
}
local ORIG_IND = {
  {"V = Q/A", {fQ2, fD2}, oi_V},
  {"Q = V*A", {F("V", "V [m/s]"), fD2}, oi_Q},
  {"Reynolds", {fQo, fVo, fD2, fnu0}, oi_Re},
  {"e/D", {fks2, fD2}, oi_eD},
  {"f Colebrook", {F("Re", "Re"), F("eD", "e/D")}, oi_f},
  {"hf = fLV2/(2gD)", {fQ2, fD2, fL2, F("f", "f", "", "calcular"), F("ks", "ks [mm]", "", "si f vacio"), fnu0}, oi_hf},
  {"hL = K V2/2g", {fQ2, fD2, fK}, oi_hL},
  {"K = 2g hL/V2", {F("hl", "hL [m]"), fQ2, fD2}, oi_K},
  {"V2/2g", {fVo, fQo, fDo}, oi_hv},
  {"Potencia bomba", {fQ2, F("HB", "HB [m]"), feta}, oi_PB},
  {"Potencia turbina", {fQ2, F("HTu", "HTur [m]"), feta}, oi_PT},
}

-- ======================= CASOS DEL CURSO =======================
local N = false
local CASOS = {
  {"P-02 PVC 200 mm, p (A)", 1, {72, 200, 1000, 0.0015, 6.7, 1.007e-6, N, 53, 1}},
  {"P-01 DW vs HW, PVC (I)", 7, {0, 72, N, 200, 1000, 0.0015, 0, 1.007e-6, 150, 1}},
  {"P-03 Pres. ejemplo 1 (B)", 2, {43.5, 293, 700, 0.0015, 11.5, 1e-6, N, 0, N, 0}},
  {"P-05 Pres. practica 1 (B)", 2, {80, 1050, 23778, 0.046, 7, 1e-6, N, 0, N, 0}},
  {"P-07 Examen 2018 P1a (B)", 2, {5, 50, 2.06, 0.045, 10.8, 1.007e-6, N, 0, N, 0}},
  {"P-09 Tarea 4 P3a (B)", 2, {100, 300, 4500, 0.045, 5, 1e-6, N, 0, N, 0}},
  {"P-10 Tarea 4 P3b (I)", 7, {1, N, 100, 300, 4500, 0.045, 5, 1e-6, 130, 0}},
  {"P-11 Pres. ejemplo 4 (C)", 4, {0, 42, 150, 970, 0.0015, 9.4, 1.14e-6, 16, 0.65, N, N, 0}},
  {"P-12 Examen 2024 P2 (C)", 4, {0, 75, 200, 1000, 0, 0, 1e-6, 102, 0.85, 0.014, N, 0}},
  {"P-15 Pres. ejemplo 5 (D)", 3, {200, 8, 450, 0.25, 2.5, 1.17e-6, 2, 0, 0, N, 0}},
  {"P-17 Examen 2025 P1 (D)", 3, {200, 76, 1900, 0.0015, 12.8, 1e-6, 0, 1, 0, N, 0}},
  {"P-18 Examen 2025 P2 (F)", 5, {200, 285.75, 1900, 0.0015, 12.8, 1e-6, 76, N, 0}},
  {"P-19 Examen 2025 P3a (C)", 4, {1, 200, 285.75, 1900, 0.0015, 12.8, 1e-6, 76, 0.65, N, N, 0}},
  {"P-20 Examen 2025 P3b (C)", 4, {0, 200, 285.75, 1900, 0.0015, 12.8, 1e-6, 76, 0.60, N, 1015, 0}},
  {"P-21 Examen 2024 P1 (D)", 3, {400, 8, 600, 0.0015, 5, 1.02e-6, 1, 0, 0, N, 0}},
  {"P-25 Pres. ejemplo 6 (E)", 6, {1135, 1070, 36, 84, 405, 274, 172, 3.5, 1.17e-6}},
  {"P-26 Ejercicio 2, HW (D)", 3, {305, 8, 500, 0.0015, 5, 1e-6, 1, 0, 0, 150, 1}},
  {"P-27 Ejercicio 2, HW (B)", 2, {8, 400, 500, 0.0015, 5, 1e-6, N, 0, 150, 1}},
}
-- sistemas S-01 a S-05: {tramo, L, D mm, f, K}
local CASOS_NET = {
  {"S-01 Examen 2024 P3 (G)", 20, false, {{1, 100, 150, 0.020, 0}, {2, 100, 100, 0.015, 5},
    {2, 100, 100, 0.015, 5}, {2, 100, 100, 0.015, 5}}},
  {"S-02 Examen 2025 P5 (G)", 20, false, {{1, 500, 150, 0.014, 0}, {1, 600, 100, 0.018, 0},
    {2, 700, 200, 0.015, 5}}},
  {"S-03 Examen 2018 P3 (G)", 24, false, {{1, 100, 100, 0.025, 0}, {2, 100, 100, 0.025, 0},
    {2, 100, 200, 0.020, 30}, {3, 100, 100, 0.025, 0}}},
  {"S-04 Examen 2017 P5 (G)", 0, true, {{1, 400, 200, 0.02, 0}, {2, 180, 100, 0.025, 0},
    {2, 50, 100, 0.025, 0}, {2, 400, 200, 0.02, 0}}},
  {"S-05 Tarea 4 P4 (G)", 75, false, {{1, 700, 300, 0.014, 5}, {2, 600, 150, 0.020, 0},
    {2, 500, 200, 0.011, 0}, {3, 600, 250, 0.028, 3}}},
}

function cargar_valores(fs, vals)
  for i, f in ipairs(fs) do
    local x = vals[i]
    if x == nil then break end
    if f.o then
      TOG[f.k] = x + 1
    elseif x == N then
      MEM[f.k] = {}
    else
      MEM[f.k] = {numstr(x)}
    end
  end
end

function cargar_net(c)
  for k in pairs(MEM) do
    if k:sub(1, 1) == "n" and k ~= "nu" and k ~= "nu0" then MEM[k] = nil end
  end
  MEM.np = {tostring(#c[4])}
  TOG.nmode = c[3] and 2 or 1
  MEM.nH = c[3] and {} or {numstr(c[2])}
  MEM.nkp = {"4"}
  MEM.nQk = {"40"}
  MEM.nu = {"1e-6"}
  TOG.met = 1
  for i, p in ipairs(c[4]) do
    MEM["ntr" .. i] = {numstr(p[1])}
    MEM["nL" .. i] = {numstr(p[2])}
    MEM["nD" .. i] = {numstr(p[3])}
    MEM["nf" .. i] = {numstr(p[4])}
    MEM["nks" .. i] = {}
    MEM["nK" .. i] = {numstr(p[5])}
  end
end

-- ================= EVALUADOR DE EXPRESIONES =================
local FNS = {
  {"sqrt", sqrt}, {"\226\136\154", sqrt}, {"ln", math.log},
  {"log", log10}, {"exp", math.exp},
}

function evalexpr(s)
  s = s:gsub("%s", "")
  if s == "" then return nil end
  local n = tonumber(s)
  if n then return n end
  local i = 1
  local expr, unary
  local function at(p) return s:find("^" .. p, i) end
  local function cierra()
    if s:sub(i, i) == ")" then i = i + 1
    elseif i <= #s then error("sintaxis", 0) end
  end
  local function primary()
    local a, b = at("%d*%.?%d+[eE][%+%-]?%d+")
    if not a then a, b = at("%d+%.?%d*") end
    if not a then a, b = at("%.%d+") end
    if a then i = b + 1; return tonumber(s:sub(a, b)) end
    if s:sub(i, i) == "(" then
      i = i + 1
      local v = expr()
      cierra()
      return v
    end
    a, b = at("\207\128")
    if not a then a, b = at("pi") end
    if a then i = b + 1; return pi end
    for _, p in ipairs(FNS) do
      a, b = at(p[1] .. "%(")
      if a then
        i = b + 1
        local v = expr()
        cierra()
        return p[2](v)
      end
    end
    error("sintaxis", 0)
  end
  local function power()
    local v = primary()
    if s:sub(i, i) == "^" then i = i + 1; return v ^ unary() end
    return v
  end
  unary = function()
    local c = s:sub(i, i)
    if c == "-" then i = i + 1; return -unary() end
    if c == "+" then i = i + 1; return unary() end
    return power()
  end
  local function term()
    local v = unary()
    while true do
      local c = s:sub(i, i)
      if c == "*" then i = i + 1; v = v * unary()
      elseif c == "/" then i = i + 1; v = v / unary()
      else return v end
    end
  end
  expr = function()
    local v = term()
    while true do
      local c = s:sub(i, i)
      if c == "+" then i = i + 1; v = v + term()
      elseif c == "-" then i = i + 1; v = v - term()
      else return v end
    end
  end
  local ok, v = pcall(expr)
  if ok and i > #s and v == v and v ~= math.huge and v ~= -math.huge then return v end
  return nil
end

-- ============================ INTERFAZ ============================
local C = {
  bg = {244, 247, 251}, hd = {14, 40, 82}, ac = {0, 146, 214},
  tx = {28, 32, 44}, sub = {118, 128, 146}, sel = {214, 234, 250},
  ok = {0, 128, 84}, err = {196, 36, 36}, w = {255, 255, 255},
  ln = {208, 216, 228}, ft = {228, 234, 243}, alt = {234, 240, 248},
  lab = {170, 200, 235}, sec = {226, 238, 250}, warn = {204, 102, 0},
  le = {0, 90, 200}, lp = {214, 40, 40}, water = {150, 200, 240},
}
local LC = {title = C.ac, fg = C.tx, gray = C.sub, ok = C.ok, warn = C.warn, err = C.err}

local gc_ = nil
function col(c) gc_:setColorRGB(c[1], c[2], c[3]) end
function box(x, y, w, h, c) col(c); gc_:fillRect(x, y, w, h) end
function font(sz, st) gc_:setFont("sansserif", st or "r", sz) end
function txt(x, y, s, c) col(c or C.tx); gc_:drawString(s, x, y, "top") end
function tw(s) return gc_:getStringWidth(s) end
function linea(x1, y1, x2, y2, c) col(c); gc_:drawLine(x1, y1, x2, y2) end

function cabecera(t, extra)
  box(0, 0, W, 24, C.hd)
  box(0, 24, W, 2, C.ac)
  box(6, 9, 14, 7, C.ac)
  box(19, 6, 3, 13, C.w)
  box(22, 9, 4, 7, C.ac)
  font(11, "b")
  txt(32, 4, t, C.w)
  if extra then
    font(9, "r")
    txt(W - 6 - tw(extra), 7, extra, C.lab)
  end
end

function pie(s, c)
  box(0, H - 19, W, 1, C.ln)
  box(0, H - 18, W, 18, C.ft)
  font(9, "r")
  txt(6, H - 16, s, c or C.sub)
end

function barra(top, n, N, y0, alto)
  if n <= N then return end
  box(W - 5, y0, 3, alto, C.ln)
  local h = math.max(10, floor(alto * N / n))
  local y = y0 + floor((alto - h) * (top - 1) / math.max(1, n - N))
  box(W - 5, y, 3, h, C.ac)
end

function visibles(fs)
  local r = {}
  for _, f in ipairs(fs) do
    if (f.c == nil or (TOG[f.c] or 1) == (f.cv or 1)) and
       (f.c2 == nil or (TOG[f.c2] or 1) == (f.cv2 or 1)) then r[#r + 1] = f end
  end
  return r
end

function texto(k)
  local t = MEM[k]
  if t then return table.concat(t) end
  return ""
end

function leer(fs)
  local v = {}
  for idx, f in ipairs(visibles(fs)) do
    local k = f.k
    if f.o then
      v[k] = TOG[k] or 1
    else
      local s = texto(k)
      if s == "" then
        local d = f.d
        if type(d) == "function" then d = d() end
        if d == nil then return nil, "Falta: " .. f.l, idx end
        if d ~= "" then v[k] = d end
      elseif f.t then
        v[k] = s
      else
        local n = evalexpr(s)
        if n == nil then return nil, "Valor invalido: " .. f.l, idx end
        v[k] = n
      end
    end
  end
  return v
end

-- ---------- pila de pantallas ----------
local pila = {}
function actual() return pila[#pila] end
function redraw() if platform.window then platform.window:invalidate() end end
function push(s) pila[#pila + 1] = s; redraw() end
function pop()
  if #pila > 1 then pila[#pila] = nil end
  redraw()
end

function nuevoMenu(titulo, items, pick, foot)
  local s = {tipo = "menu", titulo = titulo, pick = pick,
             foot = foot or "enter: elegir   esc: volver", sel = 1, top = 1, RH = 23}
  if type(items) == "function" then s.itemsfn = items else s.items = items end
  return s
end
function itemsDe(s)
  if s.itemsfn then s.items = s.itemsfn() end
  return s.items
end

function nuevaForm(titulo, fs, fn, acciones, btn)
  local s = {tipo = "form", titulo = titulo, fn = fn, sel = 1, top = 1, RH = 22,
             nuevo = true, acc = acciones or {}, btn = btn or "CALCULAR"}
  if type(fs) == "function" then s.fsfn = fs else s.fs = fs end
  return s
end
function campos(s) if s.fsfn then return s.fsfn() end return s.fs end

function nuevoRes(titulo, res)
  return {tipo = "res", titulo = titulo, res = res, vista = 0, top = 1}
end

-- visor de lineas (memoria, ayuda, avisos)
function nuevaVista(titulo, lines, botones)
  return {tipo = "view", titulo = titulo, lines = lines, botones = botones or {}, top = 1}
end
function aviso(titulo, msgs, c)
  local L = {}
  for _, m in ipairs(msgs) do L[#L + 1] = {k = "t", t = m, c = c or "fg"} end
  push(nuevaVista(titulo, L, {}))
end

-- ---------- persistencia (se guarda con el documento) ----------
local CASOS_U = {}      -- {nombre, tipo, mem, tog}
local SL = {}           -- sumador: {nombre, cantidad, K}
local TIPO_TXT = {"(A) Perdidas dado Q", "(B) Caudal maximo", "(D) Diametro",
  "(C) Bomba/turbina", "(F) Valvula", "(E) Calibracion", "(I) DW vs HW",
  "f: factor de friccion",
  "AR-1 Fuerza FD/FL", "AR-2 Velocidad terminal", "AR-3 Estructura",
  "AR-4 Vuelo nivelado", "Placa plana / Stokes",
  "VE Elemento simple", "VE-4 Compuesta", "VE-6 Perfil v(y)", "VE-7 Aguas abajo",
  "EX-1 Venturi", "EX-2 Salto hidraulico", "EX-3 Chorro"}

function copia(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, x in pairs(t) do r[k] = copia(x) end
  return r
end

local CFG0 = copia(CFG)

function on.save()
  return {ver = 1, casos = CASOS_U, custom = CUSTOM, cfg = CFG, met = TOG.met, sl = SL, cdu = CDU}
end

function on.restore(st)
  if type(st) ~= "table" or st.ver ~= 1 then return end
  if type(st.casos) == "table" then
    local l = {}
    for _, c in ipairs(st.casos) do
      if type(c) == "table" and type(c.nombre) == "string" and type(c.tipo) == "number" and
         c.tipo >= 1 and c.tipo <= 20 and type(c.mem) == "table" and type(c.tog) == "table" and
         #l < 20 then
        l[#l + 1] = c
      end
    end
    for i = #CASOS_U, 1, -1 do CASOS_U[i] = nil end
    for i, c in ipairs(l) do CASOS_U[i] = c end
  end
  if type(st.custom) == "table" then
    CUSTOM = {}
    for _, d in ipairs(st.custom) do
      if type(d) == "number" and d > 0 and d < 1e5 then CUSTOM[#CUSTOM + 1] = d end
    end
  end
  if type(st.cfg) == "table" then
    for k, x in pairs(CFG) do
      if type(st.cfg[k]) == type(x) then CFG[k] = st.cfg[k] end
    end
  end
  if type(st.met) == "number" and st.met >= 1 and st.met <= 4 then TOG.met = st.met end
  if type(st.sl) == "table" then SL = st.sl end
  if type(st.cdu) == "table" then
    for i = 1, 17 do
      local x = st.cdu[i]
      if type(x) == "number" and (x == 0 or (x >= 1e-3 and x <= 10)) then CDU[i] = x end
    end
  end
end

-- ---------- pantalla de resultado (resumen / memoria) ----------
local abrirGuardar   -- se define mas abajo

function nuevaVistaRes(res, s0)
  local s = nuevaVista(res.titulo, nil, {})
  s.res = res
  s.memo = false
  s.rebuild = function()
    s.lines = construir(res, s.memo)
    s.botones[1][1] = s.memo and "RESUMEN" or "MEMORIA"
  end
  s.botones[1] = {"MEMORIA", function()
    s.memo = not s.memo
    s.top = 1
    s.rebuild()
  end}
  if res.graph then
    s.botones[#s.botones + 1] = {"GRAFICO", function()
      push({tipo = "graph", titulo = res.gtitulo or res.titulo, g = res.graph})
    end}
  end
  if res.sketch then
    s.botones[#s.botones + 1] = {"ESQUEMA", function() abrirEsquema(res) end}
  end
  if s0 and s0.dest and res.fsel then
    s.botones[#s.botones + 1] = {"USAR f", function()
      MEM[s0.dest] = {numstr(res.fsel)}
      local parent = s0.parent
      pop()
      pop()
      if parent then
        parent.msg = "f = " .. fv(res.fsel) .. " copiado al formulario"
        parent.msgc = C.ok
      end
    end}
  end
  if res.guardar then
    s.botones[#s.botones + 1] = {"GUARDAR", function() abrirGuardar(res.guardar) end}
  end
  s.rebuild()
  return s
end

function calcular(s)
  local v, err, idx = leer(campos(s))
  if not v then
    s.msg = err
    s.msgc = C.err
    s.sel = idx
    s.nuevo = true
    return
  end
  local ok, res = pcall(s.fn, v, s)
  if not ok then
    s.msg = tostring(res)
    s.msgc = C.err
    return
  end
  if type(res) == "table" then
    if res.r then push(nuevoRes(s.titulo, res))
    else push(nuevaVistaRes(res, s)) end
  end
end

-- ---------- dibujo: menu ----------
function dMenu(s)
  cabecera(s.titulo)
  local items = itemsDe(s)
  local RH = s.RH
  local N = math.max(1, floor((H - 30 - 20) / RH))
  s.N = N
  local n = #items
  if s.sel > n then s.sel = math.max(1, n) end
  if s.sel < s.top then s.top = s.sel end
  if s.sel > s.top + N - 1 then s.top = s.sel - N + 1 end
  if n == 0 then
    font(10, "r")
    txt(14, 40, s.vacio or "(lista vacia)", C.sub)
  end
  for j = s.top, math.min(n, s.top + N - 1) do
    local y = 30 + (j - s.top) * RH
    local act = (j == s.sel)
    if act then
      box(4, y, W - 12, RH - 3, C.sel)
      box(4, y, 3, RH - 3, C.ac)
    end
    col(act and C.ac or C.hd)
    gc_:fillArc(12, y + 1, 18, 18, 0, 360)
    font(9, "b")
    local ns = tostring(j)
    txt(21 - floor(tw(ns) / 2), y + 2, ns, C.w)
    font(10, act and "b" or "r")
    local it = items[j]
    while #it > 1 and tw(it) > W - 50 do it = it:sub(1, #it - 1) end
    txt(38, y + 2, it, act and C.hd or C.tx)
  end
  barra(s.top, n, N, 30, N * RH - 3)
  if s.msg then pie(s.msg, s.msgc or C.ok) else pie(s.foot) end
end

-- ---------- dibujo: formulario ----------
function dForm(s)
  cabecera(s.titulo)
  local vs = visibles(campos(s))
  local nb = #vs + 1
  local n = nb + #s.acc
  local RH = s.RH
  local N = math.max(1, floor((H - 30 - 20) / RH))
  s.N = N
  if s.sel > n then s.sel = n end
  if s.sel < s.top then s.top = s.sel end
  if s.sel > s.top + N - 1 then s.top = s.sel - N + 1 end
  local bx = W - 158
  local bw = 146
  for j = s.top, math.min(n, s.top + N - 1) do
    local y = 30 + (j - s.top) * RH
    local act = (j == s.sel)
    if j == nb then
      box(floor(W / 2) - 89, y + 1, 178, RH - 4, act and C.ac or C.hd)
      font(10, "b")
      txt(floor(W / 2) - floor(tw(s.btn) / 2), y + 2, s.btn, C.w)
    elseif j > nb then
      local a = s.acc[j - nb]
      box(floor(W / 2) - 89, y + 2, 178, RH - 6, act and C.ac or C.ln)
      box(floor(W / 2) - 88, y + 3, 176, RH - 8, act and C.sel or C.w)
      font(9, act and "b" or "r")
      txt(floor(W / 2) - floor(tw(a[1]) / 2), y + 3, a[1], C.hd)
    else
      local f = vs[j]
      if act then
        box(3, y, W - 10, RH - 2, C.sel)
        box(3, y, 3, RH - 2, C.ac)
      end
      font(9, act and "b" or "r")
      txt(9, y + 3, f.l, act and C.hd or C.tx)
      box(bx, y + 2, bw, RH - 6, act and C.ac or C.ln)
      box(bx + 1, y + 3, bw - 2, RH - 8, C.w)
      font(10, "r")
      if f.o then
        local op = f.o[TOG[f.k] or 1] or "?"
        txt(bx + 5, y + 2, "<", C.ac)
        while #op > 1 and tw(op) > bw - 30 do op = op:sub(1, #op - 1) end
        txt(bx + 15, y + 2, op, C.tx)
        txt(bx + bw - 11, y + 2, ">", C.ac)
      else
        local toks = MEM[f.k] or {}
        local st = table.concat(toks)
        if st == "" then
          local ph = f.p or "---"
          if type(ph) == "function" then ph = ph() end
          txt(bx + 5, y + 2, ph, C.sub)
          if act then txt(bx + 5 + tw(ph) + 2, y + 2, "_", C.ac) end
        else
          local i0 = 1
          while i0 < #toks and tw(st) > bw - 18 do
            i0 = i0 + 1
            st = ".." .. table.concat(toks, "", i0)
          end
          txt(bx + 5, y + 2, st, C.tx)
          if act then txt(bx + 5 + tw(st), y + 2, "_", C.ac) end
        end
      end
    end
  end
  barra(s.top, n, N, 30, N * RH - 2)
  if s.msg then pie(s.msg, s.msgc or C.err)
  else pie("enter: siguiente   del: borrar   esc: volver") end
end

-- ---------- dibujo: visor (memoria / resumen / ayuda) ----------
function dView(s)
  local lines = s.lines or {}
  local RH = 13
  local y0 = 29
  local fb = 20
  local N = math.max(1, floor((H - fb - y0) / RH))
  s.N = N
  local n = #lines
  s.n = n
  if s.top > math.max(1, n - N + 1) then s.top = math.max(1, n - N + 1) end
  local pg = nil
  if n > N then
    local np = math.ceil(n / N)
    local p = math.min(np, floor((s.top - 1) / N) + 1)
    if s.top + N - 1 >= n then p = np end
    pg = p .. "/" .. np
  end
  cabecera(s.titulo, pg)
  local sx = W / 318
  for j = s.top, math.min(n, s.top + N - 1) do
    local L = lines[j]
    local y = y0 + (j - s.top) * RH
    if L.k == "sep" then
      box(6, y + 6, W - 16, 1, C.ln)
    elseif L.k == "v" then
      font(9, "r")
      txt(10, y, L.l, C.sub)
      font(9, "b")
      txt(floor(118 * sx), y, "= " .. L.v, C.tx)
    elseif L.k == "row" then
      local tc = LC[L.c] or C.tx
      if L.c == "title" then box(4, y, W - 12, RH, C.sec) end
      font(9, L.c == "title" and "b" or "r")
      for i, c in ipairs(L.cells) do
        txt(floor(L.xs[i] * sx) + 2, y, c, tc)
      end
    else
      local c = L.c
      if c == "title" then box(4, y, W - 12, RH, C.sec) end
      font(9, (c == "title" or c == "ok") and "b" or "r")
      txt(8, y, L.t, LC[c] or C.tx)
    end
  end
  barra(s.top, n, N, y0, N * RH)
  -- barra de botones
  box(0, H - fb - 1, W, 1, C.ln)
  box(0, H - fb, W, fb, C.ft)
  if s.msg then
    font(9, "b")
    txt(6, H - fb + 3, s.msg, s.msgc or C.ok)
    return
  end
  local nb = #s.botones
  local bwid = floor((W - 30) / math.max(1, nb))
  s.bxs = {}
  for i, b in ipairs(s.botones) do
    local x = 4 + (i - 1) * bwid
    box(x, H - fb + 2, bwid - 4, fb - 4, C.hd)
    font(9, "b")
    local lb = i .. " " .. b[1]
    txt(x + floor((bwid - 4 - tw(lb)) / 2), H - fb + 3, lb, C.w)
    s.bxs[i] = {x, x + bwid - 4}
  end
  font(9, "b")
  txt(W - 25, H - fb + 3, "esc", C.sub)
end

-- ---------- dibujo: resultados simples (programa original) ----------
-- vista 0: resumen; vista 1: tabla de iteraciones; vista 2: fila por fila

-- ajusta la tabla al ancho: letra 9 o 7 y, si aun no cabe, desplazamiento
-- horizontal por columnas (la columna i siempre queda visible)
function layoutTabla(t)
  local function anchos(sz)
    font(sz, "b")
    local ws = {}
    for i, h in ipairs(t.hdr) do ws[i] = tw(h) end
    for _, row in ipairs(t.rows) do
      for i, c in ipairs(row) do
        local w = tw(c)
        if w > (ws[i] or 0) then ws[i] = w end
      end
    end
    return ws
  end
  local gap = 10
  local disp = W - 14
  for _, sz in ipairs({9, 7}) do
    local ws = anchos(sz)
    local tot = 0
    for _, w in ipairs(ws) do tot = tot + w + gap end
    if tot <= disp then return sz, ws, gap, false end
  end
  return 7, anchos(7), 8, true
end

function dResFila(s, t)
  local n = #t.rows
  local j = s.fila
  cabecera(s.titulo, "fila " .. j .. "/" .. n)
  local row = t.rows[j]
  local y = 32
  local ult = (j == n)
  box(6, y, W - 12, 20, ult and C.ok or C.hd)
  font(10, "b")
  txt(14, y + 3, (t.hdr[1] or "i") .. " = " .. (row[1] or tostring(j)) ..
      (ult and "   (ultima: valor final)" or ""), C.w)
  y = y + 26
  local RH = floor((H - 22 - y) / math.max(1, #row - 1))
  if RH > 26 then RH = 26 end
  if RH < 18 then RH = 18 end
  for i = 2, #row do
    if (i % 2) == 0 then box(6, y, W - 14, RH - 2, C.alt) end
    font(10, "r")
    txt(14, y + 3, t.hdr[i] or "", C.sub)
    local v = row[i]
    local sz = 12
    font(sz, "b")
    while tw(v) > W - 110 and sz > 9 do
      if sz == 12 then sz = 11 elseif sz == 11 then sz = 10 else sz = 9 end
      font(sz, "b")
    end
    txt(W - 14 - tw(v), y + 2, v, C.tx)
    y = y + RH
  end
  pie("arriba/abajo: otra fila   esc: tabla   tab: resultados")
end

function dRes(s)
  local res = s.res
  if s.vista == 0 then
    cabecera(s.titulo)
    local lin = {}
    for _, x in ipairs(res.w) do lin[#lin + 1] = {"w", x} end
    for i = 2, #res.r do lin[#lin + 1] = {"r", res.r[i]} end
    local y = 30
    if #res.r > 0 then
      local err = (res.r[1][1] == "Error")
      box(6, y, W - 12, 36, err and C.err or C.hd)
      box(6, y + 34, W - 12, 2, C.ac)
      font(9, "r")
      txt(14, y + 2, res.r[1][1], C.lab)
      local sz = err and 10 or 12
      font(sz, "b")
      while tw(res.r[1][2]) > W - 32 and sz > 9 do sz = sz - 1; font(sz, "b") end
      txt(14, y + 15, res.r[1][2], C.w)
      y = y + 42
    end
    local RH = 18
    local N = math.max(1, floor((H - 20 - y) / RH))
    local n = #lin
    s.N, s.n = N, n
    if s.top > math.max(1, n - N + 1) then s.top = math.max(1, n - N + 1) end
    for j = s.top, math.min(n, s.top + N - 1) do
      local tp, x = lin[j][1], lin[j][2]
      local yy = y + (j - s.top) * RH
      if tp == "w" then
        font(9, "b")
        txt(12, yy + 2, "! " .. x, C.err)
      else
        if (j - s.top) % 2 == 0 then box(6, yy, W - 14, RH - 1, C.alt) end
        font(9, "r")
        txt(14, yy + 2, x[1], C.sub)
        local lw = tw(x[1])
        -- el valor se ajusta: letra 10, 9 o 7, alineado a la derecha si no cabe
        local vx = 150
        local sz = 10
        font(sz, "b")
        local vw = tw(x[2])
        if vx + vw > W - 10 then
          for _, z in ipairs({9, 7}) do
            sz = z
            font(sz, "b")
            vw = tw(x[2])
            if W - 10 - vw >= 20 + lw then break end
          end
          vx = math.max(20 + lw, W - 10 - vw)
        end
        txt(vx, yy + ((sz == 10) and 1 or 3), x[2], C.tx)
      end
    end
    barra(s.top, n, N, y, N * RH)
    pie((res.mlines and "1: memoria   " or "") .. (res.t and "tab: iteraciones   " or "") .. "esc: volver")
  elseif s.vista == 2 then
    dResFila(s, res.t)
  else
    local t = res.t
    local n = #t.rows
    s.fila = math.max(1, math.min(n, s.fila or n))
    local sz, ws, gap, scroll = layoutTabla(t)
    s.scroll = scroll
    local nc = #t.hdr
    s.c0 = math.max(2, math.min(s.c0 or 2, nc))
    -- columnas visibles: la 1 (i) siempre; desde c0 las que quepan
    local cols = {1}
    local used = 8 + ws[1] + gap
    for i = (scroll and s.c0 or 2), nc do
      if used + ws[i] > W - 8 and #cols > 1 then break end
      cols[#cols + 1] = i
      used = used + ws[i] + gap
    end
    s.cfin = cols[#cols]
    -- reparte el espacio sobrante entre las columnas
    local extra = 0
    if not scroll and #cols > 1 then extra = floor((W - 8 - used) / #cols) end
    if extra < 0 then extra = 0 end
    local xs = {}
    local x = 8
    for _, i in ipairs(cols) do
      xs[i] = x
      x = x + ws[i] + gap + extra
    end
    local extraTxt = nil
    if scroll then extraTxt = "col " .. (s.c0 - 1) .. "-" .. (s.cfin - 1) .. "/" .. (nc - 1) end
    cabecera(s.titulo, extraTxt)
    box(4, 30, W - 8, 18, C.hd)
    font(sz, "b")
    for _, i in ipairs(cols) do
      txt(xs[i] + ws[i] - tw(t.hdr[i]), 32 + ((sz == 7) and 2 or 0), t.hdr[i], C.w)
    end
    local RH = (sz == 7) and 13 or 16
    local N = math.max(1, floor((H - 20 - 50) / RH))
    s.N, s.n, s.RHt = N, n, RH
    if s.fila < s.top then s.top = s.fila end
    if s.fila > s.top + N - 1 then s.top = s.fila - N + 1 end
    if s.top > math.max(1, n - N + 1) then s.top = math.max(1, n - N + 1) end
    if s.top < 1 then s.top = 1 end
    for j = s.top, math.min(n, s.top + N - 1) do
      local yy = 50 + (j - s.top) * RH
      local ult = (j == n)
      if j == s.fila then
        box(4, yy, W - 8, RH, C.sel)
        box(4, yy, 3, RH, C.ac)
      elseif (j - s.top) % 2 == 1 then
        box(4, yy, W - 8, RH, C.alt)
      end
      font(sz, "b")
      for _, i in ipairs(cols) do
        local c = t.rows[j][i] or ""
        txt(xs[i] + ws[i] - tw(c), yy + 1, c, ult and C.ok or C.tx)
      end
    end
    barra(s.top, n, N, 50, N * RH)
    pie("enter: ver fila" .. (scroll and "   izq/der: columnas" or "") ..
        "   tab: resultados   esc")
  end
end

-- ---------- dibujo: grafica de LE y LP (graph.c) ----------
function dGraph(s)
  local g = s.g
  cabecera(s.titulo)
  local GX0, GX1, GY0, GY1 = 34, W - 34, 42, H - 34
  local segs = g.segs
  local n = #segs
  local ymin, ymax = g.E0, g.E0
  local E = g.E0
  local Ltot = 0
  for i = 1, n do
    local sg = segs[i]
    E = E + sg.jump
    if E > ymax then ymax = E end
    E = E - sg.hloc
    if E - sg.vh < ymin then ymin = E - sg.vh end
    E = E - sg.hfr
    if E - sg.vh < ymin then ymin = E - sg.vh end
    if E > ymax then ymax = E end
    Ltot = Ltot + sg.L
  end
  if g.tank2 then
    if g.Eend < ymin then ymin = g.Eend end
    if g.Eend > ymax then ymax = g.Eend end
  end
  if not (ymax > ymin) then ymax = ymax + 1; ymin = ymin - 1 end
  local wdt = (ymax - ymin) * 0.08
  ymax = ymax + wdt
  ymin = ymin - wdt
  local function yp(e) return GY1 - floor((e - ymin) / (ymax - ymin) * (GY1 - GY0)) end
  local minw = Ltot / (4 * math.max(1, n))
  local Lt = 0
  for i = 1, n do Lt = Lt + math.max(segs[i].L, minw) end
  if Lt <= 0 then Lt = 1 end
  local xs = {GX0}
  local acc = 0
  for i = 1, n do
    acc = acc + math.max(segs[i].L, minw)
    xs[i + 1] = GX0 + floor((GX1 - GX0) * (acc / Lt))
  end
  local function lab(v, x, y, c)
    local span = ymax - ymin
    if v < span * 1e-5 and v > -span * 1e-5 then v = 0 end
    local b = fmt_w(v, 7)
    font(9, "b")
    if x > W - tw(b) - 2 then x = W - tw(b) - 2 end
    if x < 0 then x = 0 end
    if y < GY0 - 12 then y = GY0 - 12 end
    if y > GY1 + 2 then y = GY1 + 2 end
    txt(x, y, b, c)
  end
  -- tanques
  local yE0 = yp(g.E0)
  if yE0 < GY1 then box(2, yE0, GX0 - 4, GY1 - yE0 + 1, C.water) end
  col(C.sub)
  gc_:drawRect(2, GY0, GX0 - 4, GY1 - GY0)
  if g.tank2 then
    local yEe = yp(g.Eend)
    if yEe < GY1 then box(GX1 + 2, yEe, W - GX1 - 4, GY1 - yEe + 1, C.water) end
    col(C.sub)
    gc_:drawRect(GX1 + 2, GY0, W - GX1 - 4, GY1 - GY0)
  end
  -- eje del tubo
  linea(GX0, GY1, GX1, GY1, C.sub)
  for i = 1, n + 1 do linea(xs[i], GY1 - 3, xs[i], GY1 + 3, C.sub) end
  gc_:setPen("medium", "smooth")
  E = g.E0
  for i = 1, n do
    local sg = segs[i]
    local x0, x1 = xs[i], xs[i + 1]
    local Ea = E + sg.jump
    local Eb = Ea - sg.hloc
    local Ec = Eb - sg.hfr
    linea(x0, yp(E), x0, yp(Eb), C.le)
    linea(x0, yp(Eb), x1, yp(Ec), C.le)
    linea(x0, yp(Eb - sg.vh), x1, yp(Ec - sg.vh), C.lp)
    if i > 1 then linea(x0, yp(E - segs[i - 1].vh), x0, yp(Eb - sg.vh), C.lp) end
    font(9, "b")
    txt(floor((x0 + x1) / 2) - 4, GY1 + 4, sg.name, C.tx)
    if sg.jump ~= 0 then lab(Ea, x0 + 2, yp(Ea) - 12, C.le) end
    E = Ec
  end
  if n > 0 then
    linea(GX1, yp(E - segs[n].vh), GX1, yp(g.tank2 and g.Eend or E), C.lp)
  end
  gc_:setPen("thin", "smooth")
  lab(g.E0, 2, yE0 - 13, C.le)
  lab(E, GX1 - 56, yp(E) - 13, C.le)
  font(9, "b")
  txt(W - 70, 28, "LE", C.le)
  txt(W - 46, 28, "LP", C.lp)
  pie("Esquema sin escala; cotas de energia, m   esc: volver")
end

-- ================= TECLAS =================
local CHMAP = {["\226\136\146"] = "-", ["\225\180\135"] = "e",
               ["\195\151"] = "*", ["\195\183"] = "/", ["\194\183"] = "*"}

function k_menu(s, k)
  local items = itemsDe(s)
  local n = #items
  s.msg = nil
  if k == "esc" then pop(); return end
  if n == 0 then return end
  if k == "up" then s.sel = (s.sel - 2) % n + 1
  elseif k == "down" then s.sel = s.sel % n + 1
  elseif k == "enter" then s.pick(s.sel, s)
  elseif #k == 1 and k:find("%d") then
    local d = tonumber(k)
    if d >= 1 and d <= n then s.sel = d; s.pick(d, s) end
  end
end

function k_form(s, k, ch)
  local vs = visibles(campos(s))
  local nb = #vs + 1
  local n = nb + #s.acc
  s.msg = nil
  if k == "esc" then pop(); return end
  if k == "up" then s.sel = (s.sel - 2) % n + 1; s.nuevo = true; return end
  if k == "down" then s.sel = s.sel % n + 1; s.nuevo = true; return end
  if s.sel == nb then
    if k == "enter" then calcular(s) end
    return
  end
  if s.sel > nb then
    if k == "enter" then s.acc[s.sel - nb][2](s) end
    return
  end
  local f = vs[s.sel]
  if not f then return end
  if f.o then
    local m = #f.o
    local cur = TOG[f.k] or 1
    if k == "right" then TOG[f.k] = cur % m + 1
    elseif k == "left" then TOG[f.k] = (cur - 2) % m + 1
    elseif k == "enter" then s.sel = s.sel + 1 end
    if f.on and TOG[f.k] ~= cur then f.on(s) end
    return
  end
  local toks = MEM[f.k] or {}
  local antes = table.concat(toks)
  if k == "enter" then
    s.sel = s.sel + 1
    s.nuevo = true
  elseif k == "del" then
    toks[#toks] = nil
    MEM[f.k] = toks
    s.nuevo = false
  elseif k == "clear" then
    MEM[f.k] = {}
    s.nuevo = false
  elseif k == "left" or k == "right" then
    s.nuevo = false
  elseif k == "char" then
    ch = CHMAP[ch] or ch
    if f.t then
      ch = ch:upper()
      if not ch:find("^[A-Z0-9]$") then return end
    end
    if s.nuevo then toks = {}; s.nuevo = false end
    if #toks < (f.t and 8 or 40) then toks[#toks + 1] = ch end
    MEM[f.k] = toks
  end
  if f.on and texto(f.k) ~= antes then f.on(s) end
end

function k_view(s, k, ch)
  s.msg = nil
  if k == "esc" or (k == "enter" and #s.botones == 0) then pop(); return end
  if k == "up" then s.top = math.max(1, s.top - 1)
  elseif k == "down" then
    if s.n and s.N and s.top < s.n - s.N + 1 then s.top = s.top + 1 end
  elseif k == "left" then s.top = math.max(1, s.top - (s.N or 10))
  elseif k == "right" then
    if s.n and s.N then s.top = math.min(math.max(1, s.n - s.N + 1), s.top + s.N) end
  elseif k == "tab" and s.botones[1] then s.botones[1][2]()
  elseif k == "char" and ch and ch:find("^%d$") then
    local b = s.botones[tonumber(ch)]
    if b then b[2]() end
  end
end

function k_res(s, k, ch)
  local t = s.res.t
  if k == "char" and ch == "1" and s.res.mlines then
    push(nuevaVista("MEMORIA", s.res.mlines, {}))
    return
  end
  if not t then
    if k == "esc" then pop()
    elseif k == "up" then s.top = math.max(1, s.top - 1)
    elseif k == "down" then
      if s.n and s.N and s.top < s.n - s.N + 1 then s.top = s.top + 1 end
    end
    return
  end
  if s.vista == 2 then
    local n = #t.rows
    if k == "esc" or k == "enter" then s.vista = 1
    elseif k == "tab" then s.vista = 0; s.top = 1
    elseif k == "up" or k == "left" then s.fila = math.max(1, s.fila - 1)
    elseif k == "down" or k == "right" then s.fila = math.min(n, s.fila + 1) end
    return
  end
  if s.vista == 1 then
    local n = #t.rows
    if k == "esc" then pop()
    elseif k == "tab" then s.vista = 0; s.top = 1
    elseif k == "enter" then s.vista = 2
    elseif k == "up" then s.fila = math.max(1, (s.fila or n) - 1)
    elseif k == "down" then s.fila = math.min(n, (s.fila or n) + 1)
    elseif k == "left" and s.scroll then s.c0 = math.max(2, (s.c0 or 2) - 1)
    elseif k == "right" and s.scroll then
      if (s.cfin or #t.hdr) < #t.hdr then s.c0 = (s.c0 or 2) + 1 end
    end
    return
  end
  if k == "esc" then pop()
  elseif k == "tab" and t then s.vista = 1; s.top = 1; s.fila = #t.rows
  elseif k == "up" then s.top = math.max(1, s.top - 1)
  elseif k == "down" then
    if s.n and s.N and s.top < s.n - s.N + 1 then s.top = s.top + 1 end
  end
end

function tecla(k, ch)
  local s = actual()
  if not s then return end
  if s.tipo == "menu" then k_menu(s, k == "char" and ch or k)
  elseif s.tipo == "form" then k_form(s, k, ch)
  elseif s.tipo == "view" then k_view(s, k, ch)
  elseif s.tipo == "graph" then
    if k == "esc" or k == "enter" then pop() end
  elseif s.tipo == "custom" then
    local had = s.msg
    s.msg = nil
    if k == "char" and ch and ch:find("^%d$") and s.botones[tonumber(ch)] then
      s.botones[tonumber(ch)][2]()
    elseif s.key then
      s.key(s, k, ch)
    end
    if had == nil and s.msg == nil then s.msg = nil end
  else k_res(s, k, ch) end
  redraw()
end

-- ================= EVENTOS NSPIRE =================
function on.resize(w, h)
  W, H = w, h
  redraw()
end

function on.paint(gc)
  gc_ = gc
  W = platform.window:width()
  H = platform.window:height()
  box(0, 0, W, H, C.bg)
  local s = actual()
  if not s then return end
  if s.tipo == "menu" then dMenu(s)
  elseif s.tipo == "form" then dForm(s)
  elseif s.tipo == "view" then dView(s)
  elseif s.tipo == "graph" then dGraph(s)
  elseif s.tipo == "custom" then s.draw(s)
  else dRes(s) end
end

function on.arrowKey(k) tecla(k) end
function on.enterKey() tecla("enter") end
function on.returnKey() tecla("enter") end
function on.escapeKey() tecla("esc") end
function on.tabKey() tecla("tab") end
function on.backspaceKey() tecla("del") end
function on.clearKey() tecla("clear") end
function on.charIn(ch) tecla("char", ch) end

function on.mouseDown(x, y)
  local s = actual()
  if not s then return end
  if s.tipo == "menu" or s.tipo == "form" then
    if y < 30 or not s.N then return end
    local j = s.top + floor((y - 30) / s.RH)
    if j > s.top + s.N - 1 then return end
    if s.tipo == "menu" then
      if j <= #itemsDe(s) then s.sel = j; s.pick(j, s) end
    else
      local vs = visibles(campos(s))
      local nb = #vs + 1
      if j > nb + #s.acc then return end
      s.sel = j
      s.nuevo = true
      s.msg = nil
      if j == nb then calcular(s)
      elseif j > nb then s.acc[j - nb][2](s)
      else
        local f = vs[j]
        if f.o and x > W - 158 then
          TOG[f.k] = (TOG[f.k] or 1) % #f.o + 1
          if f.on then f.on(s) end
        end
      end
    end
  elseif s.tipo == "custom" then
    s.msg = nil
    if y >= H - 20 and s.bxs then
      for i, b in ipairs(s.bxs) do
        if x >= b[1] and x <= b[2] then s.botones[i][2]() end
      end
    elseif s.click then
      s.click(s, x, y)
    end
  elseif s.tipo == "view" then
    if y >= H - 20 and s.bxs then
      for i, b in ipairs(s.bxs) do
        if x >= b[1] and x <= b[2] then s.botones[i][2]() end
      end
    end
  elseif s.tipo == "graph" then
    pop()
  elseif s.tipo == "res" and s.res.t then
    if s.vista == 1 and y >= 50 and y < H - 20 and s.RHt then
      local j = s.top + floor((y - 50) / s.RHt)
      if j <= #s.res.t.rows then s.fila = j; s.vista = 2 end
    elseif s.vista == 2 then
      s.vista = 1
    else
      s.vista = 1
      s.top = 1
      s.fila = #s.res.t.rows
    end
  end
  redraw()
end

-- ================= PANTALLAS =================
function nombres(t)
  local r = {}
  for i, e in ipairs(t) do r[i] = e[1] end
  return r
end

-- vuelve al formulario de origen con un mensaje, o muestra un aviso
function hecho(origen, msg, titulo)
  if origen then
    origen.msg = msg
    origen.msgc = C.ok
  else
    aviso(titulo or "Listo", {msg}, "ok")
  end
end

local abrirAjustes, abrirFric, abrirTipo

-- ---- Biblioteca: materiales ----
function elegirMaterial(origen)
  local it = {}
  for j, m in ipairs(MATERIALES) do
    local s = m[1] .. "  "
    if m[2] >= 0 then s = s .. fmt_real(m[2], 4) .. " mm" else s = s .. "--" end
    if m[3] > 0 then s = s .. "  CH " .. m[3] end
    it[j] = s
  end
  push(nuevoMenu("Materiales  ks (mm)  C_H", it, function(j)
    local m = MATERIALES[j]
    if m[2] >= 0 then MEM.ks = {numstr(m[2])} end
    if m[3] > 0 then MEM.CH = {numstr(m[3])} end
    pop()
    hecho(origen, "ks y C_H quedan en los formularios", "Material")
  end, "(C) = Cengel; los demas, tabla del curso"))
end

-- ---- Biblioteca: fluido ----
function elegirFluido(origen, ajustes)
  local it = {}
  for j, f in ipairs(FLUIDOS) do it[j] = f[1] .. "   nu " .. fmt_real(f[4], 6) end
  push(nuevoMenu(ajustes and "Fluido por defecto" or "Fluido", it, function(j)
    local f = FLUIDOS[j]
    pop()
    if not ajustes then
      MEM.nu = {numstr(f[4])}
      hecho(origen, "nu = " .. fmt_real(f[4], 6) .. " en el formulario", "Fluido")
      return
    end
    if f[3] > 0 and f[3] < 10 then
      aviso("Aire", {"El aire se usa en FLUJOS (arrastre).", "No cambia el fluido de las tuberias."}, "warn")
      return
    end
    local gam = CFG.gamma
    if f[3] > 0 then gam = f[3] * CFG.g end
    if gam < 1000 or gam > 20000 then
      aviso("Fluido por defecto", {"gamma = rho g queda fuera de", "rango: revise g en Ajustes"}, "err")
      return
    end
    CFG.nu = f[4]
    CFG.gamma = gam
    if f[5] > 0 then CFG.pv = f[5] end
    MEM.nu = {numstr(f[4])}
    if f[3] > 0 then
      aviso("Fluido por defecto", {"nu, gamma = rho g y presion", "de vapor quedan en Ajustes"}, "ok")
    else
      aviso("Fluido por defecto", {"nu del curso (gamma sin", "cambio) queda en Ajustes"}, "ok")
    end
  end, "(std) tabla estandar"))
end

-- ---- Biblioteca: sumador de accesorios ----
function sumaSL()
  local t = 0
  for _, l in ipairs(SL) do t = t + l[2] * l[3] end
  return t
end

function editarLinea(i)
  local l = SL[i]
  MEM.s_q = {numstr(l[2])}
  MEM.s_k = {numstr(l[3])}
  TOG.s_del = 1
  push(nuevaForm(l[1], {
    F("s_q", "Cantidad [uds]"),
    F("s_k", "K c/u"),
    F("s_del", "Quitar esta linea", nil, nil, nil, {"No", "Si"}),
  }, function(v)
    if (TOG.s_del or 1) == 2 then
      table.remove(SL, i)
    else
      if v.s_q < 0 or v.s_k < 0 then herr("Cantidad y K deben ser >= 0") end
      l[2], l[3] = v.s_q, v.s_k
    end
    pop()
  end, nil, "LISTO"))
end

function sumador(origen)
  push(nuevoMenu("Sumador de accesorios", function()
    local it = {"Suma K = " .. fmt_real(sumaSL(), 4) .. "   USAR esta suma",
                "+ Agregar accesorio", "+ Conjunto del curso (reemplaza)",
                "+ Otro accesorio"}
    for _, l in ipairs(SL) do
      it[#it + 1] = l[1] .. ":  " .. ng(l[2]) .. " x " .. ng(l[3])
    end
    return it
  end, function(j)
    if j == 1 then
      local t = sumaSL()
      MEM.K = {numstr(t)}
      pop()
      hecho(origen, "Suma K = " .. fmt_real(t, 4) .. " en los formularios", "Suma K")
    elseif j == 2 then
      local it = {}
      for k, a in ipairs(ACCESORIOS) do it[k] = a[1] .. "   K = " .. fmt_real(a[2], 3) end
      push(nuevoMenu("Accesorios (K)", it, function(k)
        local a = ACCESORIOS[k]
        if #SL < 10 then SL[#SL + 1] = {a[1], 1, a[2]} end
        pop()
      end, "(C) = Cengel; K editable despues"))
    elseif j == 3 then
      local it = {}
      for k, p in ipairs(PRESETS_K) do
        local t = 0
        for _, x in ipairs(p[2]) do t = t + x[2] * x[3] end
        it[k] = p[1] .. "   SumK " .. fmt_real(t, 3)
      end
      push(nuevoMenu("Conjuntos del curso", it, function(k)
        SL = {}
        for _, x in ipairs(PRESETS_K[k][2]) do SL[#SL + 1] = {x[1], x[2], x[3]} end
        pop()
      end, "Reemplaza la lista actual"))
    elseif j == 4 then
      if #SL < 10 then
        SL[#SL + 1] = {"Otro accesorio", 1, 0}
        editarLinea(#SL)
      end
    else
      editarLinea(j - 4)
    end
  end, "enter: usar / agregar / editar   esc: volver"))
end

-- ---- Biblioteca: diametros ----
function editarPropia()
  for i = 1, 15 do
    MEM["cd" .. i] = CUSTOM[i] and {numstr(CUSTOM[i])} or {}
  end
  local fs = {}
  for i = 1, 15 do fs[i] = F("cd" .. i, "Diametro " .. i .. " [mm]", "", "vacio") end
  push(nuevaForm("Lista propia (mm, internos)", fs, function(v)
    local l = {}
    for i = 1, 15 do
      local d = v["cd" .. i]
      if d then
        if not (d > 0 and d < 1e5) then herr("Diametro " .. i .. " fuera de rango") end
        l[#l + 1] = d
      end
    end
    CUSTOM = l
    pop()
    aviso("Lista propia", {"Guardada: " .. #l .. " diametros.", "Se guarda con el documento."}, "ok")
  end, nil, "GUARDAR"))
end

function verDiametros()
  push(nuevoMenu("Diametros comerciales", nombresD, function(j)
    if j > #DIAMETROS then editarPropia(); return end
    local d = DIAMETROS[j]
    local L = {{k = "t", t = d[1], c = "title"}, {k = "t", t = "Diametros internos (mm):", c = "gray"}, {k = "sep"}}
    local line = ""
    for _, x in ipairs(d[2]) do
      if #line > 30 then L[#L + 1] = {k = "t", t = line, c = "fg"}; line = "" end
      line = line .. " " .. fmt_real(x, 2)
    end
    L[#L + 1] = {k = "t", t = line, c = "fg"}
    push(nuevaVista("Diametros comerciales", L, {}))
  end, "enter: ver o editar (lista propia)"))
end

function biblioteca()
  push(nuevoMenu("Biblioteca", {"Materiales (ks, C_H)", "Accesorios (K) y sumador",
    "Fluido por defecto (T, nu, gamma)", "Diametros comerciales"}, function(i)
    if i == 1 then elegirMaterial(nil)
    elseif i == 2 then sumador(nil)
    elseif i == 3 then elegirFluido(nil, true)
    else verDiametros() end
  end))
end

-- ---- Ajustes ----
local AJ = {
  {"aj_g", "g [m/s2]", "g", 1, 20},
  {"aj_gam", "gamma [N/m3]", "gamma", 1000, 20000},
  {"aj_nu", "nu [m2/s]", "nu", 1e-8, 1e-3},
 {"aj_tol", "Tolerancia iter. [m]", "tol", 1e-9, 1},
  {"aj_pv", "Presion de vapor [Pa]", "pv", 0, 101325},
  {"aj_vmin", "v minima aviso [m/s]", "v_min", 0, 100},
  {"aj_vmax", "v maxima aviso [m/s]", "v_max", 0, 100},
  {"aj_ld", "L/D despreciable", "ld_limit", 1, 1e6},
  {"aj_hm", "Aviso hm/hf", "hm_ratio", 0, 100},
  {"aj_rl", "Re laminar <", "re_lam", 100, 10000},
  {"aj_rt", "Re turbulento >", "re_turb", 100, 100000},
  {"aj_rha", "rho del aire [kg/m3]", "rho_air", 0.05, 5},
  {"aj_nua", "nu del aire [m2/s]", "nu_air", 1e-7, 1e-3},
  {"aj_cdw", "Cd vertedores", "cd_weir", 0.1, 1.5},
  {"aj_knot", "km/h por nudo", "knot", 1, 3},
}

abrirAjustes = function(origen)
  local fs = {fmet}
  for _, a in ipairs(AJ) do
    local key = a[3]
    MEM[a[1]] = {}
    fs[#fs + 1] = F(a[1], a[2], function() return CFG[key] end, function() return ng(CFG[key]) end)
  end
  TOG.aj_buoy = (CFG.buoy or 0) + 1
  TOG.aj_mano = (CFG.mano or 0) + 1
  fs[#fs + 1] = F("aj_buoy", "Empuje con aire", nil, nil, nil, {"No", "Si"})
  fs[#fs + 1] = F("aj_mano", "Manometro", nil, nil, nil, {"(S-1) g h fisico", "S g h examen"})
  push(nuevaForm("AJUSTES", fs, function(v)
    CFG.buoy = (TOG.aj_buoy or 1) - 1
    CFG.mano = (TOG.aj_mano or 1) - 1
    TOG.c_conv = CFG.mano + 1
    local t = copia(CFG)
    for _, a in ipairs(AJ) do
      local x = v[a[1]]
      if not (x >= a[4] and x <= a[5]) then herr(a[2] .. ": fuera de rango") end
      t[a[3]] = x
    end
   if not (t.re_turb > t.re_lam and t.v_max > t.v_min) then
      herr("Revise: Re turb > Re lam, vmax > vmin")
    end
    for k, x in pairs(t) do CFG[k] = x end
    for _, a in ipairs(AJ) do MEM[a[1]] = {} end
    pop()
    hecho(origen, "Ajustes guardados", "Ajustes")
  end, {{"Restaurar valores por defecto", function(s)
    for k, x in pairs(CFG0) do CFG[k] = x end
    TOG.met = 1
    TOG.aj_buoy, TOG.aj_mano = 1, 1
    for _, a in ipairs(AJ) do MEM[a[1]] = {} end
    s.msg = "Valores por defecto restaurados"
    s.msgc = C.ok
  end}}, "LISTO"))
end

-- ---- Calcular f ----
abrirFric = function(dest, parent, autocalc)
  local acc = {
    {"Material (ks, C_H)", function(s)
      if (TOG.fmode or 1) == 2 then elegirMaterial(s)
      else s.msg = "MAT: solo en modo datos de tuberia"; s.msgc = C.warn end
    end},
    {"Fluido (nu)", function(s)
      if (TOG.fmode or 1) == 2 then elegirFluido(s, false)
      else s.msg = "FLUIDO: solo en modo datos de tuberia"; s.msgc = C.warn end
    end},
    {"Ajustes", function(s) abrirAjustes(s) end},
  }
  local s = nuevaForm("FACTOR DE FRICCION f", FRIC_CAMPOS, function(v)
    return fric_compute(v)
  end, acc)
  s.dest, s.parent = dest, parent
  push(s)
  if autocalc then calcular(s) end
end

-- ---- Tuberia simple ----
abrirTipo = function(i, autocalc)
  local acc = {
    {"Material (ks, C_H)", function(s) elegirMaterial(s) end},
    {"Suma K (accesorios)", function(s) sumador(s) end},
    {"Fluido (nu)", function(s) elegirFluido(s, false) end},
  }
  if HAS_F[i] then
    acc[#acc + 1] = {"Calcular f", function(s) abrirFric("f", s) end}
  end
  acc[#acc + 1] = {"Ajustes", function(s) abrirAjustes(s) end}
  local s = nuevaForm(TITULOS[i], TIPOS[i][2], function(v) return pipe_compute(i, v) end, acc)
  push(s)
  if autocalc then calcular(s) end
end

-- ---- Sistemas ----
function abrirNet(autocalc)
  local acc = {
    {"Calcular f para un tubo", function(s)
      local it = {}
      for i = 1, npipes() do it[i] = "Tubo " .. LETRA[i] end
      push(nuevoMenu("Calcular f: elija el tubo", it, function(j)
        pop()
        abrirFric("nf" .. j, s)
      end))
    end},
    {"Ajustes", function(s) abrirAjustes(s) end},
  }
  local s = nuevaForm("SISTEMA SERIE/PARALELO (G)", net_campos, net_compute, acc)
  push(s)
  if autocalc then calcular(s) end
end

-- ---- Mis casos ----
function camposDe(tipo)
  if tipo == 8 then return FRIC_CAMPOS end
  return TIPOS[tipo][2]
end

function prefijoDe(tipo)
  if tipo >= 18 then return "c_" end
  if tipo >= 14 then return "w_" end
  if tipo >= 9 then return "d_" end
  return nil
end

function snapshot(tipo)
  local m, t = {}, {}
  local pref = prefijoDe(tipo)
  if pref then
    for k, x in pairs(MEM) do if k:sub(1, #pref) == pref then m[k] = copia(x) end end
    for k, x in pairs(TOG) do if k:sub(1, #pref) == pref then t[k] = x end end
    t.met = TOG.met or 1
    return m, t
  end
  for _, f in ipairs(camposDe(tipo)) do
    if f.o then t[f.k] = TOG[f.k] or 1 else m[f.k] = copia(MEM[f.k] or {}) end
  end
  return m, t
end

function guardarCaso(nombre, tipo)
  local m, t = snapshot(tipo)
  for _, c in ipairs(CASOS_U) do
    if c.nombre == nombre then c.tipo, c.mem, c.tog = tipo, m, t; return true end
  end
  if #CASOS_U >= 20 then return false end
  CASOS_U[#CASOS_U + 1] = {nombre = nombre, tipo = tipo, mem = m, tog = t}
  return true
end

abrirGuardar = function(tipo)
  MEM.cname = {}
  local fs = {F("cname", "Nombre (max. 8)")}
  fs[1].t = true
  push(nuevaForm("GUARDAR CASO", fs, function(v)
    local nombre = v.cname
    if not nombre:find("^[A-Z0-9]+$") or #nombre > 8 then herr("Solo letras A-Z y numeros") end
    local existe = false
    for _, c in ipairs(CASOS_U) do if c.nombre == nombre then existe = true end end
    local function hacer()
      if not guardarCaso(nombre, tipo) then
        aviso("Guardar", {"Lista llena (20 casos).", "Borre uno en Mis casos."}, "err")
        return
      end
      aviso("Caso guardado", {nombre, "Casos guardados: " .. #CASOS_U .. " de 20",
        "Guarde el documento (.tns) para", "conservarlos al cerrarlo."}, "ok")
    end
    pop()
    if existe then
      push(nuevoMenu("Ya existe " .. nombre, {"Reemplazarlo", "Cancelar"}, function(j)
        pop()
        if j == 1 then hacer() end
      end))
    else
      if #CASOS_U >= 20 then
        aviso("Guardar", {"Lista llena (20 casos).", "Borre uno en Mis casos."}, "err")
        return
      end
      hacer()
    end
  end, nil, "GUARDAR"))
end

function cargarCaso(c)
  local pref = prefijoDe(c.tipo)
  if pref then limpiar(pref) end
  for k, x in pairs(c.mem) do MEM[k] = copia(x) end
  for k, x in pairs(c.tog) do TOG[k] = x end
  if c.tipo >= 18 then abrirChan(c.tipo - 17, true)
  elseif c.tipo >= 14 then abrirWeir(c.tipo - 13, true)
  elseif c.tipo >= 9 then abrirDrag(c.tipo - 8, true)
  elseif c.tipo == 8 then abrirFric(nil, nil, true)
  else abrirTipo(c.tipo, true) end
end

function misCasos()
  local s = nuevoMenu("Mis casos", function()
    local it = {}
    for i, c in ipairs(CASOS_U) do it[i] = c.nombre .. "   " .. (TIPO_TXT[c.tipo] or "?") end
    return it
  end, function(j)
    local c = CASOS_U[j]
    push(nuevoMenu(c.nombre, {"Cargar y calcular", "Borrar"}, function(k)
      pop()
      if k == 1 then
        cargarCaso(c)
      else
        push(nuevoMenu("Borrar " .. c.nombre .. "?", {"Si, borrar para siempre", "No"}, function(q)
          pop()
          if q == 1 then table.remove(CASOS_U, j) end
        end))
      end
    end))
  end, "enter: cargar o borrar   esc: volver")
  s.vacio = "No hay casos. Use GUARDAR en un resultado."
  push(s)
end

-- ---- Casos del curso ----
local F_PRESETS = {
  {"F-01 f: Re 20000, ks/D 1E-4 (ej. 3a)", 1, 20000, 1e-4},
  {"F-02 f: Re 2E5, ks/D 1.5E-4 (ej. 3b)", 1, 200000, 1.5e-4},
  {"F-03 f: 200 l/s, 285.75 mm (2025 P2)", 2, 200, 285.75, 0.0015},
  {"F-04 f: Re 455180, PVC 200 mm", 1, 455180, 7.5e-6},
  {"F-05 f: laminar, 20 mm, 0.02 l/s", 2, 0.02, 20, 0},
}

function cargarFric(p)
  for _, k in ipairs({"Re", "ksD", "ks1", "D1", "V"}) do MEM[k] = {} end
  TOG.fmode = p[2]
  if p[2] == 1 then
    MEM.Re = {numstr(p[3])}
    MEM.ksD = {numstr(p[4])}
  else
    MEM.Q = {numstr(p[3])}
    MEM.D = {numstr(p[4])}
    MEM.ks = {numstr(p[5])}
    MEM.nu = {"1e-6"}
  end
end

function casosCurso()
  local it = nombres(CASOS)
  for _, c in ipairs(CASOS_NET) do it[#it + 1] = c[1] end
  for _, c in ipairs(F_PRESETS) do it[#it + 1] = c[1] end
  push(nuevoMenu("Casos del curso", it, function(i)
    TOG.bom = 1
    if i <= #CASOS then
      local c = CASOS[i]
      cargar_valores(TIPOS[c[2]][2], c[3])
      abrirTipo(c[2], true)
    elseif i <= #CASOS + #CASOS_NET then
      cargar_net(CASOS_NET[i - #CASOS])
      abrirNet(true)
    else
      cargarFric(F_PRESETS[i - #CASOS - #CASOS_NET])
      abrirFric(nil, nil, true)
    end
  end, "enter carga los datos y calcula"))
end

-- ---- Ayuda ----
function acercaDe()
  aviso("ACERCA DE", {
    "TUBERIAS 2  (PERDIDAS y FLUJOS v2.1)",
    "Perdidas de energia en tuberias,",
    "arrastre, vertedores y canales",
    "IC-0605 Mecanica de Fluidos, UCR",
    "Motor original: Adrian Castro Ramirez",
    "(programa en C para TI-84 Plus CE)",
    "",
    "Version Lua para TI-Nspire CX II-T CAS,",
    "con el programa original Tuberias hf+hL.",
    "Casos, ajustes y lista propia se guardan",
    "con el documento .tns.",
  }, "fg")
end

function ayuda()
  local it = nombres(AYUDA)
  it[#it + 1] = "Casos del curso (cargar)"
  it[#it + 1] = "Acerca de"
  push(nuevoMenu("Ayuda", it, function(i)
    if i <= #AYUDA then
      push(nuevaVista("AYUDA", ayuda_lineas(AYUDA[i][2]), {}))
    elseif i == #AYUDA + 1 then
      casosCurso()
    else
      acercaDe()
    end
  end))
end

-- ---- Programa original ----
function abrirForm(e) push(nuevaForm(e[1], e[2], e[3])) end

function menuOriginal()
  push(nuevoMenu("Mi programa original", cat(nombres(ORIG), {"Operaciones individuales"}),
    function(i)
      if i <= #ORIG then abrirForm(ORIG[i])
      else
        push(nuevoMenu("Operaciones individuales", nombres(ORIG_IND),
          function(j) abrirForm(ORIG_IND[j]) end))
      end
    end))
end

function menuTuberia()
  local it = nombres(TIPOS)
  it[#it + 1] = "f: factor de friccion"
  push(nuevoMenu("Tuberia simple", it, function(i)
    if i <= #TIPOS then abrirTipo(i) else abrirFric() end
  end))
end

-- ======================= FLUJOS: INTERFAZ =======================
-- ilustracion del catalogo (RLE de 4 bits, como gfxcat.c)
function drawGfx(i, big, x, y, s)
  local data = big and GFX.big[i] or GFX.small[i]
  if not data then return end
  local w = big and GFX.W or GFX.TW
  local h = big and GFX.H or GFX.TH
  local n = w * h
  local px = 0
  local last = -1
  for k = 1, #data do
    local b = data:byte(k)
    local sym = b % 16
    local run = floor(b / 16) + 1
    while run > 0 and px < n do
      local cx = px % w
      local row = floor(px / w)
      local r = run
      if cx + r > w then r = w - cx end
      if sym > 0 then
        if sym ~= last then
          local c = GFX.pal[sym + 1]
          gc_:setColorRGB(c[1], c[2], c[3])
          last = sym
        end
        gc_:fillRect(x + cx * s, y + row * s, r * s, s)
      end
      px = px + r
      run = run - r
    end
    if px >= n then break end
  end
end

-- barra de botones numerados (pantallas propias)
function barraBotones(s, hint)
  local fb = 20
  box(0, H - fb - 1, W, 1, C.ln)
  box(0, H - fb, W, fb, C.ft)
  if s.msg then
    font(9, "b")
    txt(6, H - fb + 3, s.msg, s.msgc or C.ok)
    return
  end
  local nb = #s.botones
  if nb == 0 then
    font(9, "r")
    txt(6, H - fb + 3, hint or "esc: volver", C.sub)
    return
  end
  local bwid = floor((W - 30) / nb)
  s.bxs = {}
  for i, b in ipairs(s.botones) do
    local x = 4 + (i - 1) * bwid
    box(x, H - fb + 2, bwid - 4, fb - 4, C.hd)
    font(9, "b")
    local lb = i .. " " .. b[1]
    txt(x + floor((bwid - 4 - tw(lb)) / 2), H - fb + 3, lb, C.w)
    s.bxs[i] = {x, x + bwid - 4}
  end
  font(9, "b")
  txt(W - 25, H - fb + 3, "esc", C.sub)
end

function nuevaPropia(titulo, draw, key, botones)
  return {tipo = "custom", titulo = titulo, draw = draw, key = key, botones = botones or {}}
end

-- ---------------- catalogo de CD (scr_cat.c) ----------------
CAT = {cur = 1, mk = {}}

function marcado(i)
  for _, m in ipairs(CAT.mk) do if m == i then return true end end
  return false
end

function alternarMarca(i)
  for k, m in ipairs(CAT.mk) do
    if m == i then table.remove(CAT.mk, k); return nil end
  end
  if #CAT.mk >= 3 then return "Maximo 3 figuras para comparar" end
  CAT.mk[#CAT.mk + 1] = i
  return nil
end

function comparar()
  local s = nuevaPropia("COMPARAR FIGURAS", function(s)
    cabecera(s.titulo)
    local mx = 0
    local cd = {}
    for k, m in ipairs(CAT.mk) do
      cd[k] = dragcat_cd(m)
      if cd[k] > mx then mx = cd[k] end
    end
    for k, m in ipairs(CAT.mk) do
      local x = 4 + (k - 1) * 104
      drawGfx(m, true, x, 30, 1)
      font(9, "b")
      local nm = SHAPES[m][1]
      while #nm > 1 and tw(nm) > 98 do nm = nm:sub(1, #nm - 1) end
      txt(x, 112, nm, C.tx)
      txt(x, 124, "CD " .. fmt_w(cd[k], 7), C.ac)
      box(x, 139, math.max(1, floor(96 * cd[k] / math.max(mx, 1e-9))), 7, C.le)
    end
    local y = 150
    font(9, "r")
    for k = 2, #CAT.mk do
      txt(6, y, "Fig " .. k .. " / fig 1: " .. fmt_w(cd[k] / cd[1], 7) .. " veces el arrastre", C.tx)
      y = y + 11
    end
    txt(6, y, "(igual A, V y rho: F prop. a CD)", C.sub)
    barraBotones(s)
  end, function(s, k) if k == "esc" then pop() end end)
  s.botones = {{"LIMPIAR", function() CAT.mk = {}; pop() end}}
  push(s)
end

function ranking()
  local ord = {}
  for i = 1, #SHAPES do ord[i] = i end
  table.sort(ord, function(a, b) return dragcat_cd(a) < dragcat_cd(b) end)
  local s = nuevaPropia("RANKING DE CD (menor a mayor)", function(s)
    cabecera(s.titulo)
    local RH = 13
    local N = floor((H - 28 - 22) / RH)
    s.N = N
    if s.top > #ord - N + 1 then s.top = math.max(1, #ord - N + 1) end
    for j = s.top, math.min(#ord, s.top + N - 1) do
      local i = ord[j]
      local y = 28 + (j - s.top) * RH
      local cd = dragcat_cd(i)
      font(9, "r")
      txt(6, y, i .. " " .. SHAPES[i][1], C.tx)
      font(9, "b")
      txt(W - 112, y, fmt_w(cd, 4), C.ac)
      box(W - 76, y + 2, floor(66 * cd / 2.2) + 1, 8, C.le)
    end
    barra(s.top, #ord, N, 28, N * RH)
    barraBotones(s, "flechas: desplazar   esc: volver")
  end, function(s, k)
    if k == "esc" then pop()
    elseif k == "up" then s.top = math.max(1, s.top - 1)
    elseif k == "down" then s.top = s.top + 1 end
  end)
  s.top = 1
  push(s)
end

function editarCD(i)
  MEM.cat_cd = {numstr(dragcat_cd(i))}
  push(nuevaForm("EDITAR CD", {F("cat_cd", "CD propio")}, function(v)
    if not (v.cat_cd >= 0.001 and v.cat_cd <= 10) then herr("CD entre 0.001 y 10") end
    CDU[i] = (v.cat_cd == SHAPES[i][3]) and 0 or v.cat_cd
    pop()
    aviso("EDITAR CD", {SHAPES[i][1], "CD = " .. fmt_w(dragcat_cd(i), 7)}, "ok")
  end, {{"Valor del catalogo (DEFECTO)", function()
    CDU[i] = 0
    pop()
    aviso("EDITAR CD", {SHAPES[i][1], "CD del catalogo = " .. fmt_w(SHAPES[i][3], 7)}, "ok")
  end}}, "LISTO"))
end

-- pide el parametro de la tabla; luego(cd, texto)
function pedirParam(i, luego)
  local t = dragcat_table(i)
  if not MEM.cat_p or #MEM.cat_p == 0 then MEM.cat_p = {"10"} end
  push(nuevaForm("CD POR TABLA", {F("cat_p", t[1])}, function(v)
    local w = {}
    local cd, x0, y0, x1, y1 = dragcat_param(i, v.cat_p, w)
    local l1 = "CD = " .. fmt_w(cd, 7) .. ((w.clamp and " (fuera: extremo)") or (w.interp and " (interpolado)") or "")
    local l2 = t[1] .. " " .. fmt_w(x0, 7) .. ": " .. fmt_w(y0, 7) .. "   " .. fmt_w(x1, 7) .. ": " .. fmt_w(y1, 7)
    pop()
    luego(cd, l1, l2, w.clamp)
  end, nil, "LISTO"))
end

function detalleCD(use, entregar)
  local s = nuevaPropia("", nil, nil)
  s.pag = 1
  local function botones()
    local i = CAT.cur
    s.botones = {}
    if use then
      s.botones[#s.botones + 1] = {"USAR", function()
        local cd = dragcat_cd(i)
        if dragcat_table(i) then
          pedirParam(i, function(c, l1, l2) entregar(i, c, l1:match("%((.-)%)")) end)
        else
          entregar(i, cd, nil)
        end
      end}
    end
    s.botones[#s.botones + 1] = {"COMPAR.", function()
      if not marcado(i) then s.msg = alternarMarca(i) end
      if #CAT.mk >= 2 then comparar()
      elseif not s.msg then s.msg = "Marcada; elija otra figura" end
    end}
    s.botones[#s.botones + 1] = {"EDITAR", function() editarCD(i) end}
    if dragcat_table(i) then
      s.botones[#s.botones + 1] = {"TABLA", function()
        pedirParam(i, function(c, l1, l2, cl) aviso("CD POR TABLA", {l1, l2}, cl and "warn" or "ok") end)
      end}
    end
  end
  s.draw = function(s)
    local i = CAT.cur
    local d = SHAPES[i]
    botones()
    cabecera(i .. " " .. d[1], s.pag .. "/2")
    local t = dragcat_table(i)
    if s.pag == 1 then
      drawGfx(i, true, 2, 28, 2)
      local x, y = 198, 30
      local function L(str, c, b)
        font(9, b and "b" or "r")
        txt(x, y, str, c)
        y = y + 12
      end
      L("CD = " .. fmt_w(dragcat_cd(i), 7), C.ac, true)
      if (CDU[i] or 0) > 0 then L("(catal. " .. fmt_w(d[3], 7) .. ")", C.warn) end
      y = y + 4
      L("Area de ref.:", C.sub); L(AREA_TXT[d[4]], C.tx)
      L("Validez:", C.sub); L("Re > 1E4", C.tx)
      if d[7] > 0 then L("Re<1: " .. fmt_w(d[7], 7) .. "/Re", C.tx) end
      L("Fuente:", C.sub); L(d[8], C.tx)
      if marcado(i) then L("* marcada", C.ok, true) end
      font(9, "r")
      txt(x, 176, "tab: mas datos", C.sub)
    else
      local y = 30
      local function L(str, c, b)
        font(9, b and "b" or "r")
        txt(8, y, str, c)
        y = y + 12
      end
      L(d[2], C.sub)
      L("CD = " .. fmt_w(dragcat_cd(i), 7) .. (((CDU[i] or 0) > 0) and ("  (catalogo " .. fmt_w(d[3], 7) .. ")") or ""), C.ac, true)
      L("Area de referencia: " .. AREA_TXT[d[4]], C.tx)
      L("Validez: Re > 1E4" .. ((d[7] > 0) and ("; Re < 1: " .. fmt_w(d[7], 7) .. "/Re") or ""), C.tx)
      L("Fuente: " .. d[8], C.tx)
      if t then
        local l = t[1] .. ":"
        for k = 1, #t[2] do l = l .. " " .. fmt_w(t[2][k], 4) .. "->" .. fmt_w(t[3][k], 4) end
        if t[4] > 0 then l = l .. "  inf->" .. fmt_w(t[4], 4) end
        mline("", "fg")
        local saved = VW
        VW = {}
        mline(l, "fg")
        for _, x in ipairs(VW) do L(x.t, C.tx) end
        VW = saved
      end
      for part in (d[9] .. "|"):gmatch("([^|]*)|") do
        if part ~= "" then L(part, C.tx) end
      end
      if marcado(i) then L("* marcada para comparar", C.ok, true) end
    end
    barraBotones(s)
  end
  s.key = function(s, k)
    if k == "esc" then pop()
    elseif k == "tab" or k == "left" or k == "right" then s.pag = 3 - s.pag
    elseif k == "up" then if CAT.cur > 1 then CAT.cur = CAT.cur - 1 end
    elseif k == "down" then if CAT.cur < #SHAPES then CAT.cur = CAT.cur + 1 end end
  end
  push(s)
end

function catalogo(use, entregar)
  local s = nuevaPropia(use and "ELIJA LA FIGURA (CD)" or "COEFICIENTES DE ARRASTRE", nil, nil)
  s.top = 1
  s.botones = {
    {"MARCAR", function() s.msg = alternarMarca(CAT.cur); if s.msg then s.msgc = C.warn end end},
    {"COMPAR.", function()
      if #CAT.mk >= 2 then comparar() else s.msg = "Marque 2 o 3 figuras"; s.msgc = C.warn end
    end},
    {"RANKING", function() ranking() end},
  }
  s.draw = function(s)
    cabecera(s.titulo)
    local RH = 20
    local N = floor((H - 28 - 22) / RH)
    s.N, s.RH = N, RH
    if CAT.cur < s.top then s.top = CAT.cur end
    if CAT.cur > s.top + N - 1 then s.top = CAT.cur - N + 1 end
    for j = s.top, math.min(#SHAPES, s.top + N - 1) do
      local y = 28 + (j - s.top) * RH
      if j == CAT.cur then
        box(2, y, W - 10, RH - 1, C.sel)
        box(2, y, 3, RH - 1, C.ac)
      end
      drawGfx(j, false, 6, y + 1, 1)
      font(9, "b")
      txt(42, y, (marcado(j) and "*" or " ") .. j .. " " .. SHAPES[j][1], C.tx)
      font(9, "r")
      txt(50, y + 9, SHAPES[j][2], C.sub)
      local cs = fmt_w(dragcat_cd(j), 4)
      font(9, "b")
      txt(W - 12 - tw(cs), y + 4, cs, ((CDU[j] or 0) > 0) and C.warn or C.ac)
    end
    barra(s.top, #SHAPES, N, 28, N * RH)
    barraBotones(s)
  end
  s.key = function(s, k)
    if k == "esc" then pop()
    elseif k == "up" then CAT.cur = (CAT.cur - 2) % #SHAPES + 1
    elseif k == "down" then CAT.cur = CAT.cur % #SHAPES + 1
    elseif k == "enter" then detalleCD(use, entregar) end
  end
  s.click = function(s, x, y)
    if y >= 28 and y < H - 22 and s.RH then
      local j = s.top + floor((y - 28) / s.RH)
      if j <= #SHAPES then CAT.cur = j; detalleCD(use, entregar) end
    end
  end
  push(s)
end

-- elegir CD desde un formulario de arrastre (en AR-3, para un cuerpo)
function elegirCD(form, t)
  local function abrir(kcd, kfig)
    local base = #pila
    catalogo(true, function(i, cd, extra)
      MEM[kcd] = {numstr(cd)}
      MEM[kfig] = {numstr(i)}
      while #pila > base do pop() end
      form.msg = "CD = " .. fmt_w(cd, 7) .. " (figura " .. i .. ")" .. (extra and ("  " .. extra) or "")
      form.msgc = C.ok
    end)
  end
  if t == 3 then
    local it = {}
    for i = 1, nbodies() do it[i] = "Cuerpo " .. i end
    push(nuevoMenu("CD: elija el cuerpo", it, function(j)
      pop()
      abrir("d_cd" .. j, "d_fig" .. j)
    end))
  else
    abrir("d_cd", "d_fig")
  end
end

-- ---------------- esquemas (AR-3 y VE-4) ----------------
function abrirEsquema(res)
  local sk = res.sketch
  if sk.bodies then
    local s = nuevaPropia("ESQUEMA DE FUERZAS", function(s)
      cabecera(s.titulo)
      local ymax, fmax = 0, 0
      for i, b in ipairs(sk.bodies) do
        if b.y > ymax then ymax = b.y end
        if sk.sr.F[i] > fmax then fmax = sk.sr.F[i] end
      end
      local yb = H - 40
      box(10, yb, W - 20, 3, {120, 100, 70})
      box(30, 32, 3, yb - 32, C.sub)
      if ymax > 0 and fmax > 0 then
        for i, b in ipairs(sk.bodies) do
          local y = yb - floor((yb - 40) * b.y / ymax)
          box(33, y - 1, floor(150 * sk.sr.F[i] / fmax) + 2, 3, C.lp)
          font(9, "b")
          txt(190, y - 6, "F" .. i .. "=" .. fw(sk.sr.F[i] / 1000) .. " kN", C.tx)
        end
      end
      font(9, "b")
      txt(6, H - 34, "M = " .. fw(sk.sr.M / 1000) .. " kN m   ycp = " .. fw(sk.sr.ycp) .. " m", C.ac)
      barraBotones(s)
    end, function(s, k) if k == "esc" or k == "enter" then pop() end end)
    push(s)
    return
  end
  local s = nuevaPropia("ESQUEMA DE LA ESTRUCTURA", function(s)
    cabecera(s.titulo)
    local top, zmin = sk.h, 0
    for _, e in ipairs(sk.els) do
      if e.z < zmin then zmin = e.z end
      if e.z + 0.1 > top then top = e.z + 0.1 end
    end
    top = top * 1.15
    if not (top - zmin > 0) then barraBotones(s); return end
    local yb = H - 42
    local sc = (yb - 34) / (top - zmin)
    box(20, 34, W - 40, yb - 34 + 1, {150, 130, 100})
    local y0 = yb - floor((sk.h - zmin) * sc)
    if y0 < yb then box(4, y0, 16, yb - y0, C.water) end
    for i, e in ipairs(sk.els) do
      local x = 34 + (i - 1) * 34
      local y1 = yb - floor((e.z - zmin) * sc)
      if e.type >= WE_ORC then
        local d = floor(((e.type == WE_ORC) and e.a or e.b) * sc) + 2
        box(x, y1 - floor(d / 2), 14, d, C.bg)
      else
        box(x, 34, 14, y1 - 34, C.bg)
        box(x, y1, 14, 2, C.tx)
      end
      font(9, "b")
      txt(x + 3, math.max(36, math.min(yb - 12, y1 - 14)), tostring(i), C.ac)
    end
    box(4, y0, W - 24, 1, C.le)
    font(9, "b")
    txt(6, H - 36, "h = " .. fw(sk.h) .. " m   Q = " .. fw(sk.Q) .. " m3/s", C.ac)
    barraBotones(s)
  end, function(s, k) if k == "esc" or k == "enter" then pop() end end)
  push(s)
end

-- ---------------- formularios de FLUJOS ----------------
function abrirDrag(t, autocalc)
  if TOG.d_fluid == nil then TOG.d_fluid = 1 end
  if texto("d_rho") == "" and (TOG.d_fluid or 1) < 3 then aplicar_fluido() end
  if t == 4 and texto("d_V") == "" then TOG.d_vunit = 3 end
  local acc = {}
  if t <= 3 then acc[#acc + 1] = {"Catalogo de CD (figura)", function(s) elegirCD(s, t) end} end
  acc[#acc + 1] = {"Ajustes", function(s) abrirAjustes(s) end}
  local s = nuevaForm(FL_TITLES[t], DRAG_CAMPOS[t], function(v) return drag_compute(t, v) end, acc)
  push(s)
  if autocalc then calcular(s) end
end

function abrirWeir(t, autocalc)
  local s = nuevaForm(FL_TITLES[5 + t], WEIR_CAMPOS[t], function(v) return weir_compute(t, v) end,
    {{"Ajustes", function(s) abrirAjustes(s) end}})
  push(s)
  if autocalc then calcular(s) end
end

function abrirChan(t, autocalc)
  if TOG.c_conv == nil then TOG.c_conv = (CFG.mano or 0) + 1 end
  local s = nuevaForm(FL_TITLES[9 + t], CHAN_CAMPOS[t], function(v) return chan_compute(t, v) end,
    {{"Ajustes", function(s) abrirAjustes(s) end}})
  push(s)
  if autocalc then calcular(s) end
end

function abrirModulo(m, t, autocalc)
  if m == "d" then abrirDrag(t, autocalc)
  elseif m == "w" then abrirWeir(t, autocalc)
  else abrirChan(t, autocalc) end
end

function casosFlujos()
  push(nuevoMenu("Casos del curso (FLUJOS)", FL_CASOS, function(i)
    local m, t = preset_flujos(i)
    abrirModulo(m, t, true)
  end, "enter carga los datos y calcula"))
end

function ayudaFlujos()
  local it = nombres(AYUDA_FLUJOS)
  it[#it + 1] = "Casos del curso (cargar)"
  push(nuevoMenu("Ayuda de FLUJOS", it, function(i)
    if i <= #AYUDA_FLUJOS then push(nuevaVista("AYUDA", ayuda_lineas(AYUDA_FLUJOS[i][2]), {}))
    else casosFlujos() end
  end))
end

function menuFlujos()
  push(nuevoMenu("FLUJOS EXTERNOS Y MEDICION", {
    "Arrastre y sustentacion", "Vertedores y orificios", "Canales y medicion",
    "Coeficientes de arrastre (CD)", "Casos del curso (FLUJOS)", "Mis casos",
    "Ajustes", "Ayuda de FLUJOS"}, function(i)
    if i == 1 then
      push(nuevoMenu("Arrastre y sustentacion", {
        "Fuerza de arrastre FD o FL (AR-1)", "Velocidad terminal (AR-2)",
        "Estructura: varios cuerpos (AR-3)", "Vuelo nivelado (AR-4)",
        "Placa plana y flujo lento (Stokes)", "Catalogo de coeficientes CD"}, function(j)
        if j <= 5 then abrirDrag(j) else catalogo(false) end
      end))
    elseif i == 2 then
      push(nuevoMenu("Vertedores y orificios", {
        "Vertedero u orificio (VE-1,2,5)", "Estructura compuesta (VE-4)",
        "Perfil de velocidades (VE-6)", "Aguas abajo: energia (VE-7)"}, function(j)
        abrirWeir(j)
      end))
    elseif i == 3 then
      push(nuevoMenu("Canales y medicion", {
        "Venturi y manometro (EX-1)", "Salto hidraulico (EX-2)",
        "Chorro desde un tubo (EX-3)", "Placa plana y Stokes (EX-4)"}, function(j)
        if j <= 3 then abrirChan(j) else abrirDrag(5) end
      end))
    elseif i == 4 then catalogo(false)
    elseif i == 5 then casosFlujos()
    elseif i == 6 then misCasos()
    elseif i == 7 then abrirAjustes(nil)
    else ayudaFlujos() end
  end))
end

-- ================= MENU PRINCIPAL =================
push(nuevoMenu("TUBERIAS 2   Perdidas y Flujos", {
  "Tuberia simple (A B D C F E I)",
  "Sistemas serie / paralelo (G)",
  "Calcular f (solo f)",
  "Flujos externos (FLUJOS)",
  "Biblioteca",
  "Mis casos",
  "Ajustes",
  "Ayuda / Casos del curso",
  "Mi programa original",
}, function(i)
  if i == 1 then menuTuberia()
  elseif i == 2 then abrirNet()
  elseif i == 3 then abrirFric()
  elseif i == 4 then menuFlujos()
  elseif i == 5 then biblioteca()
  elseif i == 6 then misCasos()
  elseif i == 7 then abrirAjustes(nil)
  elseif i == 8 then ayuda()
  else menuOriginal() end
end, "flechas: mover   enter: elegir"))
