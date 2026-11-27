--[[
statics.lua - Estatica de fluidos para los ejercicios de examen (E1..E6). Motor puro,
sin UI, todo en SI. Convenciones del puerto: ver core/hydro.lua (err primero, 0 = OK;
salidas en la tabla `r` que se pasa `{}`; si hay error, r.msg trae el texto).
Todas las funciones reciben `c` (hydro_cfg: c.g, c.gamma); si es nil se usa
g = 9.81 y gamma = 9810.

API PUBLICA   (p = tabla de entradas, c = cfg, r = tabla de salida)
  E1 Viscosidad
    st_visc_plate(p, c, r)    p: mu A V Vu Vl t1 t2   (V placa, Vu/Vl paredes sup./inf., con signo)
                              r: tau1 tau2 F1 F2 F  s0 (cero de velocidad en la capa sup., desde
                              la placa) y0 (en la capa inf., desde la pared inf.) - nil si no hay
    st_visc_bearing(p, c, r)  p: mu D L e mode(0 rpm,1 T,2 P) val   r: K omega rpm T P tau F
    st_visc_block(p, c, r)    p: W th A V t mu mode(0 aceite,1 seco) mus   r: F Fv N fr
  E2 Manometria
    st_mano_chain(p, c, r)    p: pA n S{} dz{} mode(0 pB,1 desnivel) pB k   r: pB dzk pp{} dp{}
  E3 Superficies planas
    st_shape(shape, b, L, b2) -> A, sc, Ic   (0 rect,1 tri vertice arriba,2 tri vertice abajo,
                                              3 circulo (L = D),4 trapecio)
    st_plane(p, c, r)         p: S p0 plates{ {shape th hs b L b2} } hinge(0..3) dh sup
                              r: pl{ {A sc Ic s_top yc hc F yp hp dcp} } F n same yp hp hinge{}
    st_gateL(p, c, r)         p: a w e Sl S [hmax]   r: H Wp Fw Mw Wl Ml lg iters
    st_bisect(f, a, b, tol, maxit) -> err, x, iters, lg
  E4 Superficies curvas
    st_curved(p, c, r)        p: type(0 domo,1 cuenco) R h w side(0 encima,1 debajo) S hinge(0,1 A,2 B)
                              dir(0 horiz.,1 vert.)   r: FH FV FR ang vol xV hpd Fx Fz P Pdir
    st_semicyl(p, c, r)       p: D L h s rows S   r: FVu FV nb Fp Hp
  E5 Flotacion
    st_float(p, c, r)         p: shape(0..6) mode(0 calado,1 densidad) b H hk L D e S rhob h
                              r: h Vd zB zG I BM GM stable sink rhob Sb Wt Htot Vm lg
  E6 Equilibrio relativo
    st_relative(p, c, r)      p: S ax az x0 z0 p0 mode(0,1 hallar ax,2 hallar az) xt zt pt
                              pts{ {x,z} } tank{x,z,Lx,Hz}   r: ax az alpha pp{} corners{} pmax pmin
    st_pulley(p, c, r)        p: S mc1 V1 h1 mc2 V2 h2   r: M1 M2 a T p1 p2
]]

local H = require("core.hydro")

local M = {}
local sqrt, sin, cos, atan2, abs, max, min = math.sqrt, math.sin, math.cos, math.atan2,
  math.abs, math.max, math.min
local pi = math.pi
local H_OK, H_ERR_ARG = H.H_OK, H.H_ERR_ARG
local DEG = pi / 180

local function fail(r, msg)
  r.msg = msg
  return H_ERR_ARG
end
local function cg(c)
  if type(c) ~= "table" then return 9.81, 9810 end
  return c.g or 9.81, c.gamma or 9810
end

-- ----------------------------------------------------------- biseccion
-- f(a) y f(b) de signo contrario. Devuelve err, x, iteraciones y lg
-- (lg.r[i] = {i, a, b, x_medio, f(x_medio)}; solo las 6 primeras y las 6 ultimas).
function M.st_bisect(f, a, b, tol, maxit)
  tol = tol or 1e-10
  maxit = maxit or 100
  local fa, fb = f(a), f(b)
  local lg = { n = 0, total = 0, r = {} }
  if fa == 0 then return H_OK, a, 0, lg end
  if fb == 0 then return H_OK, b, 0, lg end
  if (fa < 0) == (fb < 0) then return H_ERR_ARG, nil, 0, lg end
  local rows = {}
  local it, x = 0, 0.5 * (a + b)
  while it < maxit do
    it = it + 1
    x = 0.5 * (a + b)
    local fx = f(x)
    rows[it] = { it, a, b, x, fx }
    if fx == 0 then break end
    if (fx < 0) == (fa < 0) then a, fa = x, fx else b = x end
    if (b - a) <= tol * max(1, abs(x)) then x = 0.5 * (a + b); break end
  end
  lg.total = it
  if it <= 12 then
    for i = 1, it do lg.r[i] = rows[i] end
    lg.n = it
  else
    for i = 1, 6 do lg.r[i] = rows[i] end
    for i = 1, 6 do lg.r[6 + i] = rows[it - 6 + i] end
    lg.n = 12
  end
  return H_OK, x, it, lg
end

-- ============================================================= E1 viscosidad
function M.st_visc_plate(p, c, r)
  local mu, A, V, Vu, Vl, t1, t2 = p.mu, p.A, p.V, p.Vu, p.Vl, p.t1, p.t2
  if not (mu > 0) or not (A > 0) or not (t1 > 0) or not (t2 > 0) then
    return fail(r, "mu, A, t1 y t2 deben ser > 0")
  end
  r.tau1 = mu * (V - Vu) / t1
  r.tau2 = mu * (V - Vl) / t2
  r.F1 = r.tau1 * A
  r.F2 = r.tau2 * A
  r.F = r.F1 + r.F2
  r.s0, r.y0 = nil, nil
  -- capa superior: u(s) = V + (Vu - V) s/t1, s medido desde la placa
  if V ~= Vu then
    local s = V * t1 / (V - Vu)
    if s > 1e-9 * t1 and s < t1 * (1 - 1e-9) then r.s0 = s end
  end
  -- capa inferior: u(y) = Vl + (V - Vl) y/t2, y medido desde la pared inferior
  if V ~= Vl then
    local y = -Vl * t2 / (V - Vl)
    if y > 1e-9 * t2 and y < t2 * (1 - 1e-9) then r.y0 = y end
  end
  return H_OK
end

function M.st_visc_bearing(p, c, r)
  local mu, D, L, e = p.mu, p.D, p.L, p.e
  if not (mu > 0) or not (D > 0) or not (L > 0) or not (e > 0) or not (p.val > 0) then
    return fail(r, "Todos los datos deben ser > 0")
  end
  local K = pi * mu * D * D * D * L / (4 * e)     -- T = K omega
  local mode = p.mode or 0
  local omega, T
  if mode == 0 then omega = p.val * 2 * pi / 60; T = K * omega
  elseif mode == 1 then T = p.val; omega = T / K
  else omega = sqrt(p.val / K / 1); T = K * omega end
  r.K = K
  r.omega = omega
  r.rpm = omega * 60 / (2 * pi)
  r.T = T
  r.P = T * omega
  r.tau = mu * omega * (D / 2) / e
  r.F = r.tau * pi * D * L
  return H_OK
end

function M.st_visc_block(p, c, r)
  local W, th = p.W, p.th * DEG
  if not (W > 0) or not (p.th >= 0) or not (p.th < 90) then
    return fail(r, "W > 0 y 0 <= theta < 90")
  end
  local s, co = sin(th), cos(th)
  if (p.mode or 0) == 0 then
    if not (p.mu > 0) or not (p.A > 0) or not (p.t > 0) or p.V == nil then
      return fail(r, "mu, A y t deben ser > 0")
    end
    r.Fv = p.mu * p.A * p.V / p.t
    r.tau = r.Fv / p.A
    r.F = (r.Fv + W * s) / co
    r.N = W * co + r.F * s
    r.fr = r.Fv
  else
    local den = co - p.mus * s
    if not (p.mus >= 0) then return fail(r, "mu_s no puede ser negativo") end
    if not (den > 0) then return fail(r, "cos(th) - mus sen(th) <= 0: se atasca") end
    r.F = W * (s + p.mus * co) / den
    r.N = W * co + r.F * s
    r.fr = p.mus * r.N
    r.Fv = 0
  end
  return H_OK
end

-- ============================================================= E2 manometria
function M.st_mano_chain(p, c, r)
  local _, gam = cg(c)
  local n = p.n
  if not (n >= 1) or n > 8 or n ~= math.floor(n) then return fail(r, "1 a 8 tramos") end
  for i = 1, n do
    if not (p.S[i] > 0) then return fail(r, "S de cada tramo debe ser > 0") end
  end
  local dz = {}
  for i = 1, n do dz[i] = p.dz[i] or 0 end
  if (p.mode or 0) == 1 then
    local k = p.k
    if not (k >= 1) or k > n or k ~= math.floor(k) then return fail(r, "Tramo incognita fuera de 1..n") end
    local sum = 0
    for i = 1, n do if i ~= k then sum = sum + gam * p.S[i] * dz[i] end end
    dz[k] = (p.pB - p.pA - sum) / (gam * p.S[k])
    r.dzk = dz[k]
  end
  local acc = p.pA
  r.pp, r.dp, r.dz = {}, {}, dz
  for i = 1, n do
    r.dp[i] = gam * p.S[i] * dz[i]
    acc = acc + r.dp[i]
    r.pp[i] = acc
  end
  r.pB = acc
  return H_OK
end

-- ================================================= E3 superficies planas
-- A, distancia del centroide al borde superior, I centroidal (eje paralelo a la superficie)
function M.st_shape(shape, b, L, b2)
  if shape == 0 then return b * L, L / 2, b * L * L * L / 12
  elseif shape == 1 then return b * L / 2, 2 * L / 3, b * L * L * L / 36
  elseif shape == 2 then return b * L / 2, L / 3, b * L * L * L / 36
  elseif shape == 3 then return pi * L * L / 4, L / 2, pi * L ^ 4 / 64
  else
    local s = b + b2
    return s * L / 2, L * (b + 2 * b2) / (3 * s), L * L * L * (b * b + 4 * b * b2 + b2 * b2) / (36 * s)
  end
end

function M.st_plane(p, c, r)
  local _, g0 = cg(c)
  local gam = g0 * p.S
  if not (p.S > 0) then return fail(r, "S debe ser > 0") end
  local plates = p.plates or { p }
  local np = #plates
  if np < 1 then return fail(r, "Sin placas") end
  local h0 = (p.p0 or 0) / gam
  r.pl, r.n = {}, np
  local F, Mom, same = 0, 0, true
  for i = 1, np do
    local q = plates[i]
    if not (q.th > 0) or q.th > 90 then return fail(r, "theta debe estar en (0, 90]") end
    if not (q.L > 0) or (q.shape ~= 3 and not (q.b > 0)) then return fail(r, "Dimensiones deben ser > 0") end
    if q.shape == 4 and not (q.b2 >= 0 and (q.b + q.b2) > 0) then return fail(r, "Bases del trapecio invalidas") end
    if not (q.hs >= 0) then return fail(r, "Profundidad del borde < 0") end
    local A, sc, Ic = M.st_shape(q.shape, q.b, q.L, q.b2 or 0)
    local sn = sin(q.th * DEG)
    local s_top = (q.hs + h0) / sn
    local yc = s_top + sc
    if not (yc > 0) then return fail(r, "Placa sobre la superficie libre") end
    local o = { A = A, sc = sc, Ic = Ic, s_top = s_top, yc = yc, th = q.th }
    o.hc = yc * sn
    o.F = gam * o.hc * A
    o.yp = yc + Ic / (yc * A)
    o.hp = o.yp * sn
    o.dcp = o.yp - s_top
    r.pl[i] = o
    F = F + o.F
    Mom = Mom + o.F * o.yp
    if abs(q.th - plates[1].th) > 1e-9 then same = false end
  end
  r.F = F
  r.same = same
  if same then
    r.yp = Mom / F
    r.hp = r.yp * sin(plates[1].th * DEG)
  end
  r.hinge = nil
  local hg = p.hinge or 0
  if hg ~= 0 and np == 1 then
    local o, q = r.pl[1], plates[1]
    local ext = q.L
    local sh
    if hg == 1 then sh = 0 elseif hg == 2 then sh = ext else sh = p.dh or 0 end
    if sh < 0 or sh > ext then return fail(r, "Bisagra fuera de la placa") end
    local ss = p.sup
    if ss == nil then ss = (sh <= ext / 2) and ext or 0 end
    if abs(ss - sh) < 1e-9 then return fail(r, "Apoyo y bisagra coinciden") end
    local Mh = o.F * (o.dcp - sh)
    local Rs = Mh / (ss - sh)
    r.hinge = { sh = sh, ss = ss, M = Mh, Rs = Rs, Rh = o.F - Rs }
  end
  return H_OK
end

function M.st_gateL(p, c, r)
  local _, g0 = cg(c)
  local a, w, e = p.a, p.w, p.e
  if not (a > 0) or not (w > 0) or not (e >= 0) or not (p.Sl >= 0) or not (p.S > 0) then
    return fail(r, "Datos de la compuerta invalidos")
  end
  local gam = g0 * p.S
  local Wp = e * a * w * p.Sl * g0
  local function f(H1) return gam * w * H1 * H1 * H1 / 6 - (gam * H1 * a * w + Wp) * a / 2 end
  local hi = max(100, 20 * a)
  local err, H1, it, lg = M.st_bisect(f, 1e-9, hi, 1e-12, 200)
  if err ~= H_OK then return fail(r, "No hay H que equilibre la compuerta") end
  r.H, r.Wp, r.iters, r.lg = H1, Wp, it, lg
  r.Fw = gam * w * H1 * H1 / 2           -- empuje sobre la parte vertical
  r.Mw = r.Fw * H1 / 3                   -- momento volcador
  r.Wl = gam * H1 * a * w                -- agua sobre la tapa
  r.Ml = (r.Wl + Wp) * a / 2             -- momento resistente
  r.gam = gam
  return H_OK
end

-- ================================================= E4 superficies curvas
function M.st_curved(p, c, r)
  local _, g0 = cg(c)
  local R, h, w = p.R, p.h, p.w
  if not (R > 0) or not (h >= 0) or not (w > 0) or not (p.S > 0) then
    return fail(r, "R, w, S > 0 y h >= 0")
  end
  local gam = g0 * p.S
  local tp = p.type or 0
  local hc = h + R / 2
  r.hc = hc
  r.FH = gam * hc * R * w
  r.hpd = hc + R * R / (12 * hc)                 -- profundidad del centro de presion de FH
  local vol, xV
  if tp == 0 then
    vol = (h + R) * R - pi * R * R / 4
    xV = (R * R * (h + R) / 2 - R * R * R / 3) / vol
  else
    vol = h * R + pi * R * R / 4
    xV = (h * R * R / 2 + R * R * R / 3) / vol
  end
  r.vol = vol * w
  r.xV = xV
  r.FV = gam * vol * w
  r.FR = sqrt(r.FH * r.FH + r.FV * r.FV)
  r.ang = atan2(r.FV, r.FH) / DEG
  r.real = (p.side or 0) == 0
  -- sentido: el fluido del lado del centro O empuja hacia afuera; del otro lado, hacia O
  local inside = (tp == 0 and p.side == 1) or (tp == 1 and (p.side or 0) == 0)
  local sx, sz = 1, (tp == 0) and 1 or -1
  if not inside then sx, sz = -sx, -sz end
  r.Fx, r.Fz = sx * r.FH, sz * r.FV
  r.hinge = nil
  local hg = p.hinge or 0
  if hg ~= 0 then
    local A, B
    if tp == 0 then A, B = { 0, R }, { R, 0 } else A, B = { R, 0 }, { 0, -R } end
    local Hp, E = A, B
    if hg == 2 then Hp, E = B, A end
    -- el resultante pasa por O = (0,0)
    local Mo = -Hp[1] * r.Fz + Hp[2] * r.Fx
    local rx, rz = E[1] - Hp[1], E[2] - Hp[2]
    local P
    if (p.dir or 0) == 0 then
      if abs(rz) < 1e-12 then return fail(r, "Brazo nulo: use fuerza vertical") end
      P = Mo / rz
    else
      if abs(rx) < 1e-12 then return fail(r, "Brazo nulo: use fuerza horizontal") end
      P = -Mo / rx
    end
    r.M = Mo
    r.P = abs(P)
    r.Psign = P
    r.Pdir = p.dir or 0
    r.armO = { Hp[1], Hp[2], rx, rz }
  end
  return H_OK
end

function M.st_semicyl(p, c, r)
  local _, g0 = cg(c)
  local D, L, h, s = p.D, p.L, p.h, p.s
  if not (D > 0) or not (L > 0) or not (h >= 0) or not (s > 0) or not (p.S > 0) then
    return fail(r, "D, L, s, S > 0 y h >= 0")
  end
  local rows = p.rows or 2
  local gam = g0 * p.S
  r.Hp = h + D / 2
  r.volu = D * r.Hp - pi * D * D / 8
  r.FVu = gam * r.volu
  r.FV = r.FVu * L
  r.nb = rows * L / s
  r.Fp = r.FVu * s / rows
  return H_OK
end

-- ================================================= E5 flotacion
-- Seccion de la forma: Htot, Amat (area del material), zG; sub(h) -> area, zB, ancho en la linea de agua
local function section(p)
  local sh, b, Hh, hk = p.shape, p.b, p.H, p.hk or 0
  local o = {}
  if sh == 0 then
    o.Htot, o.Amat, o.zG = Hh, b * Hh, Hh / 2
    o.sub = function(h) return b * h, h / 2, b end
  elseif sh == 1 then
    o.Htot, o.Amat, o.zG = Hh, b * Hh / 2, 2 * Hh / 3
    o.sub = function(h) return b * h * h / (2 * Hh), 2 * h / 3, b * h / Hh end
  elseif sh == 2 then
    o.Htot, o.Amat, o.zG = Hh, b * Hh / 2, Hh / 3
    o.sub = function(h)
      local A = b * h - b * h * h / (2 * Hh)
      local zB = 0
      if A > 0 then zB = b * (h * h / 2 - h * h * h / (3 * Hh)) / A end
      return A, zB, b * (1 - h / Hh)
    end
  elseif sh == 3 then
    local Ak, Ar = b * hk / 2, b * Hh
    o.Htot, o.Amat = hk + Hh, Ak + Ar
    o.zG = (Ar * (hk + Hh / 2) + Ak * 2 * hk / 3) / o.Amat
    o.sub = function(h)
      if h <= hk then return b * h * h / (2 * hk), 2 * h / 3, b * h / hk end
      local Ad = b * (h - hk)
      return Ak + Ad, (Ak * 2 * hk / 3 + Ad * (hk + (h - hk) / 2)) / (Ak + Ad), b
    end
  else                                 -- cuadrado de lado b girado 45 grados
    local d = b * sqrt(2)
    o.Htot, o.Amat, o.zG = d, b * b, d / 2
    o.sub = function(h)
      if h <= d / 2 then return h * h, 2 * h / 3, 2 * h end
      local t = d - h
      local A = b * b - t * t
      return A, (b * b * d / 2 - t * t * (d - 2 * t / 3)) / A, 2 * t
    end
  end
  return o
end

function M.st_float(p, c, r)
  local g, g0 = cg(c)
  local rhof = (p.S or 1) * g0 / g
  local sh, mode = p.shape, p.mode or 0
  local L = p.L or 1
  local Htot, Vm, zG, Vd, h, zB, I, wid
  local prism = sh <= 4
  local b, Hh = p.b, p.H
  r.lg = nil
  if prism then
    if not (L > 0) or not (b > 0) or not (sh == 4 or (Hh and Hh > 0)) then return fail(r, "Dimensiones deben ser > 0") end
    if sh == 3 and not (p.hk > 0) then return fail(r, "Altura de la quilla > 0") end
    local o = section(p)
    Htot, zG = o.Htot, o.zG
    Vm = o.Amat * L
    if mode == 0 then
      if not (p.rhob > 0) then return fail(r, "Densidad del cuerpo > 0") end
      local Ad = p.rhob / rhof * o.Amat
      if Ad >= o.Amat * (1 - 1e-12) then
        r.sink = true
        h = Htot
      else
        local err, x, it, lg = M.st_bisect(function(hh) return (o.sub(hh)) - Ad end, 0, Htot, 1e-13, 200)
        if err ~= H_OK then return fail(r, "Sin calado de equilibrio") end
        h = x
        r.lg, r.iters = lg, it
      end
    else
      h = p.h
      if not (h > 0) then return fail(r, "Calado debe ser > 0") end
      if h > Htot * (1 + 1e-9) then return fail(r, "Calado mayor que la altura") end
    end
    local Ad
    Ad, zB, wid = o.sub(h)
    Vd = Ad * L
    I = L * wid * wid * wid / 12
  else
    local Do, Di, ee = p.D, 0, 0
    if sh == 6 then
      Di, ee = p.D, p.e
      if not (Di > 0) or not (ee > 0) or not (Hh > ee) then return fail(r, "Di, e > 0 y H > e") end
      Do = Di + 2 * ee
      Vm = pi / 4 * (Do * Do * Hh - Di * Di * (Hh - ee))
      zG = (Do * Do * Hh * Hh / 2 - Di * Di * (Hh * Hh - ee * ee) / 2) /
        (Do * Do * Hh - Di * Di * (Hh - ee))
    else
      if not (Do > 0) or not (Hh > 0) then return fail(r, "D y H deben ser > 0") end
      Vm = pi / 4 * Do * Do * Hh
      zG = Hh / 2
    end
    Htot = Hh
    local Aw = pi / 4 * Do * Do
    if mode == 0 then
      if not (p.rhob > 0) then return fail(r, "Densidad del cuerpo > 0") end
      Vd = p.rhob / rhof * Vm
      h = Vd / Aw
    else
      h = p.h
      if not (h > 0) then return fail(r, "Calado debe ser > 0") end
      if h > Htot * (1 + 1e-9) then return fail(r, "Calado mayor que la altura") end
      Vd = Aw * h
    end
    zB = h / 2
    I = pi * Do ^ 4 / 64
    r.Do = Do
  end
  r.Htot, r.Vm, r.zG, r.h, r.Vd, r.zB, r.I = Htot, Vm, zG, h, Vd, zB, I
  if h > Htot * (1 + 1e-9) then r.sink = true end
  r.BM = I / Vd
  r.GM = r.BM - (zG - zB)
  r.stable = r.GM > 0
  r.rhob = rhof * Vd / Vm
  r.Sb = r.rhob / (g0 / g)
  r.rhof = rhof
  r.Wt = r.rhob * g * Vm
  return H_OK
end

-- ================================================= E6 equilibrio relativo
function M.st_relative(p, c, r)
  local g, g0 = cg(c)
  if not (p.S > 0) then return fail(r, "S debe ser > 0") end
  local rho = p.S * g0 / g
  local ax, az = p.ax or 0, p.az or 0
  local x0, z0, p0 = p.x0, p.z0, p.p0
  local mode = p.mode or 0
  if mode == 1 then
    local dx, dz = p.xt - x0, p.zt - z0
    if abs(dx) < 1e-12 then return fail(r, "Punto objetivo con la misma x") end
    ax = (p0 - p.pt - rho * (g + az) * dz) / (rho * dx)
  elseif mode == 2 then
    local dx, dz = p.xt - x0, p.zt - z0
    if abs(dz) < 1e-12 then return fail(r, "Punto objetivo con la misma z") end
    az = (p0 - p.pt - rho * ax * dx) / (rho * dz) - g
  end
  local gz = g + az
  if abs(gz) < 1e-9 then return fail(r, "g + az = 0: caida libre") end
  r.rho, r.ax, r.az, r.gz = rho, ax, az, gz
  r.slope = -ax / gz                              -- dz/dx de la superficie libre
  r.alpha = atan2(ax, gz) / DEG
  r.gx, r.gzp = -rho * ax, -rho * gz              -- gradiente de presion
  local function pr(x, z) return p0 - rho * ax * (x - x0) - rho * gz * (z - z0) end
  r.pfun = pr
  r.pp = {}
  for i, q in ipairs(p.pts or {}) do r.pp[i] = pr(q[1], q[2]) end
  if p.tank then
    local t = p.tank
    if not (t.Lx > 0) or not (t.Hz > 0) then return fail(r, "Dimensiones del tanque > 0") end
    r.corners = {
      { t.x, t.z }, { t.x + t.Lx, t.z }, { t.x + t.Lx, t.z + t.Hz }, { t.x, t.z + t.Hz } }
    r.pmax, r.pmin = -1 / 0, 1 / 0
    for i, q in ipairs(r.corners) do
      q[3] = pr(q[1], q[2])
      if q[3] > r.pmax then r.pmax, r.imax = q[3], i end
      if q[3] < r.pmin then r.pmin, r.imin = q[3], i end
    end
  end
  return H_OK
end

function M.st_pulley(p, c, r)
  local g, g0 = cg(c)
  if not (p.S > 0) or not (p.V1 >= 0) or not (p.V2 >= 0) or not (p.h1 > 0) or not (p.h2 > 0) then
    return fail(r, "S > 0, volumenes >= 0 y alturas > 0")
  end
  local rho = p.S * g0 / g
  r.rho = rho
  r.M1 = p.mc1 + rho * p.V1
  r.M2 = p.mc2 + rho * p.V2
  if not (r.M1 + r.M2 > 0) then return fail(r, "Masa total nula") end
  r.a = g * (r.M2 - r.M1) / (r.M1 + r.M2)          -- + : el 2 baja y el 1 sube
  r.T = 2 * r.M1 * r.M2 * g / (r.M1 + r.M2)
  r.p1 = rho * (g + r.a) * p.h1
  r.p2 = rho * (g - r.a) * p.h2
  return H_OK
end

return M
