-- scr_stat.lua - ESTATICA DE FLUIDOS (E1..E6) para los ejercicios de examen.
-- Motor: core/statics.lua. Cada problema tiene formulario, resumen y MEMORIA DE
-- CALCULO paso a paso (escrita aqui con la API de ui/memo.lua).
--
-- Menu: scr_stat_menu() = submenu ESTATICA DE FLUIDOS (E1..E6 + Ejemplos de examen).
--
-- MIS CASOS (kind = numero o nombre; todo el estado es una tabla plana de numeros):
--   1 visc_plate   E1 placa entre dos paredes
--   2 visc_bearing E1 eje y cojinete
--   3 visc_block   E1 bloque en plano inclinado (aceite o friccion seca)
--   4 mano         E2 manometria en serie
--   5 plane        E3 superficies planas (1 a 4 placas, bisagra)
--   6 gate_l       E3 compuerta en L (incognita H)
--   7 curved       E4 cuarto de circulo
--   8 semicyl      E4 semicilindro con pernos
--   9 float        E5 flotacion y estabilidad
--  10 relative     E6 tanque con aceleracion
--  11 pulley       E6 recipientes en polea
-- API: case_get(kind) -> tabla, case_set(kind, t) -> bool, case_run(kind, autocalc),
--      case_count, kind_name(kind), S.KT_BASE (si se asigna, F3 GUARDAR del
--      resultado llama a F.case_save_ui(KT_BASE + kind - 1)), example_count, example_name(i),
--      example_run(i), run_kind(kind, autocalc), scr_stat_menu().
-- Unidades de pantalla: mm, cm, l, kPa, rpm; el motor trabaja en SI.
local U = require("ui.ui")
local W = require("ui.widgets")
local F = require("scr.flu_util")
local nf = require("ui.numfmt")
local Mm = require("ui.memo")
local St = require("core.statics")

local S = {}
local FF_POS, FF_NONNEG, FF_CHOICE, FF_INT, FF_OPT, FF_RANGE =
  W.FF_POS, W.FF_NONNEG, W.FF_CHOICE, W.FF_INT, W.FF_OPT, W.FF_RANGE
local K_F1, K_F3, K_F4, K_F5, K_ENTER, K_CLEAR, K_QUIT, K_MODE =
  U.K_F1, U.K_F3, U.K_F4, U.K_F5, U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE
local C_ERR, C_OK, C_WARN, C_FG, C_TITLE, C_GRAY = U.C_ERR, U.C_OK, U.C_WARN, U.C_FG, U.C_TITLE, U.C_GRAY
local memo_begin, memo_sec, memo_data, memo_eq, memo_res, memo_line, memo_table =
  Mm.memo_begin, Mm.memo_sec, Mm.memo_data, Mm.memo_eq, Mm.memo_res, Mm.memo_line, Mm.memo_table
local mfmt = Mm.mfmt
local pi, sin, cos, sqrt, atan2 = math.pi, math.sin, math.cos, math.sqrt, math.atan2

local KINDS = { "visc_plate", "visc_bearing", "visc_block", "mano", "plane", "gate_l",
  "curved", "semicyl", "float", "relative", "pulley" }
S.KINDS = KINDS
S.KT_BASE = nil

local function nz(x) return x ~= nil and x ~= 0 and x ~= false end
local function N(x) return nf.fmt_real(x, U.g_set.dec or 6) end
local function V(label, v, unit) W.view_add_val(label, v, unit) end
local function note(s, col) Mm.memo_line(s, col or C_FG) end
local function warn(s) Mm.memo_line(" ! " .. s, C_WARN) end
local function eq(lhs, formula, fmt, res, unit, ...)
  memo_eq(lhs, formula, fmt and mfmt(fmt, ...) or nil, res, unit)
end

-- ---------------------------------------------------------------- campos
local function FN(st, lab, un, k, fl, lo, hi)
  return { label = lab, unit = un, t = st, k = k, flags = fl or 0, lo = lo, hi = hi }
end
local function FO(st, lab, un, k, fl)
  return { label = lab, unit = un, t = st, k = k, setk = "s" .. k, flags = (fl or 0) + FF_OPT }
end
local function FC(st, lab, k, names)
  return { label = lab, t = st, chk = k, flags = FF_CHOICE, choices = names, nchoices = #names }
end
local function FI(st, lab, k, lo, hi)
  return { label = lab, t = st, k = k, flags = FF_INT, lo = lo, hi = hi }
end

-- ---------------------------------------------------------------- estado
local DEF, PR, ST = {}, {}, {}
local function reset(name)
  local t = ST[name] or {}
  for k in pairs(t) do t[k] = nil end
  for k, v in pairs(DEF[name]()) do t[k] = v end
  ST[name] = t
  return t
end

local function cfg() return F.cfg_copy() end

-- ================================================================== E1 placa
DEF.visc_plate = function()
  return { mu = 0.0027, A = 0.16, V = 1, Vu = 0, Vl = -0.3, t1 = 1, t2 = 2.6 }
end
PR.visc_plate = {
  title = "VISCOSIDAD: PLACA (E1)",
  hint = "Velocidades con signo (+ a la derecha)",
  fields = function(st)
    return {
      FN(st, "Viscosidad mu", "Pa.s", "mu", FF_POS),
      FN(st, "Area de la placa", "m2", "A", FF_POS),
      FN(st, "Velocidad de la placa", "m/s", "V"),
      FN(st, "V pared superior", "m/s", "Vu"),
      FN(st, "V pared inferior", "m/s", "Vl"),
      FN(st, "Espesor sup. t1", "mm", "t1", FF_POS),
      FN(st, "Espesor inf. t2", "mm", "t2", FF_POS),
    }
  end,
  calc = function(st)
    local p = { mu = st.mu, A = st.A, V = st.V, Vu = st.Vu, Vl = st.Vl, t1 = st.t1 / 1000, t2 = st.t2 / 1000 }
    local r = {}
    if St.st_visc_plate(p, cfg(), r) ~= 0 then return r.msg end
    return nil, { p = p, r = r }
  end,
  sum = function(R)
    local r = R.r
    V("tau capa sup", r.tau1, "Pa")
    V("tau capa inf", r.tau2, "Pa")
    V("F cara sup", r.F1, "N")
    V("F cara inf", r.F2, "N")
    V("F TOTAL", r.F, "N")
    if r.s0 then V("cero sup (placa)", r.s0 * 1000, "mm") end
    if r.y0 then V("cero inf (pared)", r.y0 * 1000, "mm") end
    if not r.s0 and not r.y0 then W.view_add(" Sin velocidad nula en las capas", C_GRAY) end
  end,
  memo = function(R)
    local p, r = R.p, R.r
    memo_begin("MEMORIA: PLACA ENTRE PAREDES")
    memo_sec("DATOS")
    memo_data("mu", p.mu, "Pa.s")
    memo_data("Area A", p.A, "m2")
    memo_data("V placa", p.V, "m/s")
    memo_data("V pared sup", p.Vu, "m/s")
    memo_data("V pared inf", p.Vl, "m/s")
    memo_data("t1 (sup)", p.t1 * 1000, "mm")
    memo_data("t2 (inf)", p.t2 * 1000, "mm")
    memo_sec("ESFUERZOS (perfil lineal)")
    note("tau = mu (V - Vpared)/t")
    eq("tau1", "mu (V - Vu)/t1", "%v*(%v-%v)/%v", r.tau1, "Pa", p.mu, p.V, p.Vu, p.t1)
    eq("tau2", "mu (V - Vl)/t2", "%v*(%v-%v)/%v", r.tau2, "Pa", p.mu, p.V, p.Vl, p.t2)
    memo_sec("FUERZA SOBRE LA PLACA")
    eq("F1", "tau1 A", "%v*%v", r.F1, "N", r.tau1, p.A)
    eq("F2", "tau2 A", "%v*%v", r.F2, "N", r.tau2, p.A)
    eq("F", "F1 + F2", "%v+%v", r.F, "N", r.F1, r.F2)
    memo_sec("VELOCIDAD CERO")
    if r.y0 then
      eq("y0", "-Vl t2/(V - Vl)", "-(%v)*%v/(%v-(%v))", r.y0, "m", p.Vl, p.t2, p.V, p.Vl)
      note("(medido desde la pared inferior)")
    end
    if r.s0 then
      eq("s0", "V t1/(V - Vu)", "%v*%v/(%v-%v)", r.s0, "m", p.V, p.t1, p.V, p.Vu)
      note("(medido desde la placa)")
    end
    if not r.y0 and not r.s0 then note("No hay velocidad nula en las capas") end
    memo_sec("RESULTADO")
    memo_res("F total", r.F, "N")
  end,
}

-- ================================================================ E1 cojinete
DEF.visc_bearing = function()
  return { mu = 0.005, D = 80, L = 1000, e = 0.1, dato = 0, val = 500 }
end
local dato_names = { "Velocidad (rpm)", "Par T (N.m)", "Potencia (W)" }
local dato_unit = { [0] = "rpm", "N.m", "W" }
PR.visc_bearing = {
  title = "VISCOSIDAD: COJINETE (E1)",
  hint = "Eje en cojinete con aceite",
  fields = function(st)
    return {
      FN(st, "Viscosidad mu", "Pa.s", "mu", FF_POS),
      FN(st, "Diametro D", "mm", "D", FF_POS),
      FN(st, "Longitud L", "mm", "L", FF_POS),
      FN(st, "Holgura e", "mm", "e", FF_POS),
      FC(st, "Dato conocido", "dato", dato_names),
      FN(st, "Valor del dato", dato_unit[st.dato] or "", "val", FF_POS),
    }
  end,
  calc = function(st)
    local p = { mu = st.mu, D = st.D / 1000, L = st.L / 1000, e = st.e / 1000, mode = st.dato, val = st.val }
    local r = {}
    if St.st_visc_bearing(p, cfg(), r) ~= 0 then return r.msg end
    return nil, { p = p, r = r }
  end,
  sum = function(R)
    local r = R.r
    V("Velocidad", r.rpm, "rpm")
    V("omega", r.omega, "rad/s")
    V("Par T", r.T, "N.m")
    V("Potencia P", r.P, "W")
    V("tau", r.tau, "Pa")
    V("Fuerza F", r.F, "N")
  end,
  memo = function(R)
    local p, r = R.p, R.r
    memo_begin("MEMORIA: EJE Y COJINETE")
    memo_sec("DATOS")
    memo_data("mu", p.mu, "Pa.s")
    memo_data("D", p.D * 1000, "mm")
    memo_data("L", p.L * 1000, "mm")
    memo_data("e", p.e * 1000, "mm")
    memo_data(dato_names[p.mode + 1]:sub(1, 16), p.val, dato_unit[p.mode])
    memo_sec("MODELO")
    note("tau = mu w R/e (perfil lineal)")
    note("T = tau (pi D L) R = K w")
    eq("K", "pi mu D^3 L/(4 e)", "pi*%v*%v^3*%v/(4*%v)", r.K, "N.m.s", p.mu, p.D, p.L, p.e)
    memo_sec("VELOCIDAD Y PAR")
    if p.mode == 0 then
      eq("w", "rpm 2 pi/60", "%v*2*pi/60", r.omega, "rad/s", p.val)
      eq("T", "K w", "%v*%v", r.T, "N.m", r.K, r.omega)
    elseif p.mode == 1 then
      eq("w", "T/K", "%v/%v", r.omega, "rad/s", p.val, r.K)
      eq("rpm", "w 60/(2 pi)", "%v*60/(2*pi)", r.rpm, "rpm", r.omega)
    else
      note("P = T w = K w^2")
      eq("w", "sqrt(P/K)", "sqrt(%v/%v)", r.omega, "rad/s", p.val, r.K)
      eq("rpm", "w 60/(2 pi)", "%v*60/(2*pi)", r.rpm, "rpm", r.omega)
      eq("T", "K w", "%v*%v", r.T, "N.m", r.K, r.omega)
    end
    eq("P", "T w", "%v*%v", r.P, "W", r.T, r.omega)
    eq("tau", "mu w D/(2 e)", "%v*%v*%v/(2*%v)", r.tau, "Pa", p.mu, r.omega, p.D, p.e)
    eq("F", "tau pi D L", "%v*pi*%v*%v", r.F, "N", r.tau, p.D, p.L)
    memo_sec("RESULTADO")
    memo_res("T", r.T, "N.m")
    memo_res("Velocidad", r.rpm, "rpm")
    memo_res("Potencia", r.P, "W")
  end,
}

-- ================================================================ E1 bloque
DEF.visc_block = function()
  return { W = 150, th = 20, tipo = 0, A = 0.25, V = 1.2, t = 0.5, mu = 0.015, mus = 0.27 }
end
local tipo_names = { "Con aceite", "Friccion seca" }
PR.visc_block = {
  title = "VISCOSIDAD: BLOQUE (E1)",
  hint = "F horizontal que sube el bloque",
  fields = function(st)
    local f = {
      FN(st, "Peso W", "N", "W", FF_POS),
      FN(st, "Angulo theta", "grad", "th", FF_RANGE, 0, 85),
      FC(st, "Contacto", "tipo", tipo_names),
    }
    if st.tipo == 0 then
      f[#f + 1] = FN(st, "Area de contacto", "m2", "A", FF_POS)
      f[#f + 1] = FN(st, "Velocidad V", "m/s", "V", FF_NONNEG)
      f[#f + 1] = FN(st, "Espesor de aceite", "mm", "t", FF_POS)
      f[#f + 1] = FN(st, "Viscosidad mu", "Pa.s", "mu", FF_POS)
    else
      f[#f + 1] = FN(st, "Coef. friccion mus", nil, "mus", FF_NONNEG)
    end
    return f
  end,
  calc = function(st)
    local p = { W = st.W, th = st.th, mode = st.tipo, A = st.A, V = st.V, t = st.t / 1000, mu = st.mu, mus = st.mus }
    local r = {}
    if St.st_visc_block(p, cfg(), r) ~= 0 then return r.msg end
    return nil, { p = p, r = r }
  end,
  sum = function(R)
    local p, r = R.p, R.r
    if p.mode == 0 then
      V("tau aceite", r.tau, "Pa")
      V("F viscosa", r.Fv, "N")
    else
      V("Normal N", r.N, "N")
      V("Friccion", r.fr, "N")
    end
    V("F HORIZONTAL", r.F, "N")
  end,
  memo = function(R)
    local p, r = R.p, R.r
    local th = p.th * pi / 180
    memo_begin("MEMORIA: BLOQUE EN RAMPA")
    memo_sec("DATOS")
    memo_data("W", p.W, "N")
    memo_data("theta", p.th, "grad")
    if p.mode == 0 then
      memo_data("A", p.A, "m2")
      memo_data("V", p.V, "m/s")
      memo_data("t", p.t * 1000, "mm")
      memo_data("mu", p.mu, "Pa.s")
      memo_sec("EQUILIBRIO A LO LARGO DEL PLANO")
      note("F cos(th) = W sen(th) + Fv")
      eq("Fv", "mu A V/t", "%v*%v*%v/%v", r.Fv, "N", p.mu, p.A, p.V, p.t)
      eq("F", "(Fv + W sen th)/cos th", "(%v+%v*sin(%v))/cos(%v)", r.F, "N", r.Fv, p.W, p.th, p.th)
      eq("N", "W cos th + F sen th", "%v*cos(%v)+%v*sin(%v)", r.N, "N", p.W, p.th, r.F, p.th)
    else
      memo_data("mu_s", p.mus, "")
      memo_sec("EQUILIBRIO (A PUNTO DE SUBIR)")
      note("F cos th = W sen th + mus N")
      note("N = W cos th + F sen th")
      eq("F", "W (sen th + mus cos th)/(cos th - mus sen th)",
        "%v*(sin(%v)+%v*cos(%v))/(cos(%v)-%v*sin(%v))", r.F, "N", p.W, p.th, p.mus, p.th, p.th, p.mus, p.th)
      eq("N", "W cos th + F sen th", "%v*cos(%v)+%v*sin(%v)", r.N, "N", p.W, p.th, r.F, p.th)
      eq("fr", "mus N", "%v*%v", r.fr, "N", p.mus, r.N)
    end
    memo_sec("RESULTADO")
    memo_res("F horizontal", r.F, "N")
  end,
}

-- ================================================================ E2 manometria
DEF.mano = function()
  local t = { n = 3, pA = 0, modo = 0, pB = 0, k = 1 }
  local S0 = { 13.6, 0.85, 1 }
  local D0 = { 0.45, -0.3, -0.2 }
  for i = 1, 8 do t["S" .. i] = S0[i] or 1; t["dz" .. i] = D0[i] or 0 end
  return t
end
PR.mano = {
  title = "MANOMETRIA EN SERIE (E2)",
  hint = "dz: + si el tramo baja, - si sube",
  fields = function(st)
    local n = math.floor(st.n)
    if n < 1 then n = 1 elseif n > 8 then n = 8 end
    local f = {
      FI(st, "Numero de tramos", "n", 1, 8),
      FN(st, "Presion al inicio", "kPa", "pA"),
      FC(st, "Calcular", "modo", { "Presion al final", "Un desnivel" }),
    }
    if st.modo == 1 then
      f[#f + 1] = FN(st, "Presion al final", "kPa", "pB")
      f[#f + 1] = FI(st, "Tramo incognita", "k", 1, n)
    end
    for i = 1, n do
      f[#f + 1] = FN(st, "S tramo " .. i, nil, "S" .. i, FF_POS)
      if not (st.modo == 1 and st.k == i) then
        f[#f + 1] = FN(st, "dz tramo " .. i .. " (+baja)", "m", "dz" .. i)
      end
    end
    return f
  end,
  calc = function(st)
    local n = math.floor(st.n)
    local p = { pA = st.pA * 1000, n = n, S = {}, dz = {}, mode = st.modo, pB = st.pB * 1000, k = st.k }
    for i = 1, n do p.S[i] = st["S" .. i]; p.dz[i] = st["dz" .. i] end
    local r = {}
    if St.st_mano_chain(p, cfg(), r) ~= 0 then return r.msg end
    return nil, { p = p, r = r }
  end,
  sum = function(R)
    local p, r = R.p, R.r
    if p.mode == 1 then
      V("dz del tramo", r.dzk, "m")
      V("dz del tramo", r.dzk * 1000, "mm")
    else
      V("p final", r.pB / 1000, "kPa")
      V("p final", r.pB, "Pa")
    end
    for i = 1, p.n do V("p tras tramo " .. i, r.pp[i] / 1000, "kPa") end
  end,
  memo = function(R)
    local p, r = R.p, R.r
    local gam = cfg().gamma
    memo_begin("MEMORIA: MANOMETRIA")
    memo_sec("DATOS")
    memo_data("p inicio", p.pA / 1000, "kPa")
    memo_data("gamma", gam, "N/m3")
    for i = 1, p.n do
      local d = r.dz[i]
      memo_line(mfmt(" tramo %d: S=%v  dz=%v m", i, p.S[i], d), (p.mode == 1 and p.k == i) and C_WARN or C_FG)
    end
    memo_sec("ECUACION")
    note("pB = pA + gamma Sum(S_i dz_i)")
    if p.mode == 1 then
      local sum = 0
      for i = 1, p.n do if i ~= p.k then sum = sum + gam * p.S[i] * r.dz[i] end end
      memo_data("p final", p.pB / 1000, "kPa")
      eq("Sum otros", "gamma Sum S dz", nil, sum, "Pa")
      eq("dz" .. p.k, "(pB - pA - Sum)/(gamma S)", "(%v-%v-%v)/(%v*%v)", r.dzk, "m",
        p.pB, p.pA, sum, gam, p.S[p.k])
    else
      for i = 1, p.n do
        eq("dp" .. i, "gamma S dz", "%v*%v*%v", r.dp[i], "Pa", gam, p.S[i], r.dz[i])
      end
      eq("pB", "pA + Sum dp", nil, r.pB, "Pa")
    end
    memo_sec("PRESIONES ACUMULADAS")
    for i = 1, p.n do memo_line(mfmt(" tras tramo %d: %v kPa", i, r.pp[i] / 1000), C_FG) end
    memo_sec("RESULTADO")
    if p.mode == 1 then
      memo_res("dz", r.dzk, "m")
      memo_res("dz", r.dzk * 1000, "mm")
    else
      memo_res("p final", r.pB / 1000, "kPa")
    end
  end,
}

-- ============================================================ E3 superficies planas
local shape_names = { "Rectangulo", "Triangulo v.arriba", "Triangulo v.abajo", "Circulo", "Trapecio" }
local shape_full = { "Rectangulo", "Triangulo vertice arriba", "Triangulo vertice abajo",
  "Circulo", "Trapecio" }
local hinge_names = { "Sin bisagra", "Borde superior", "Borde inferior", "A una distancia" }
DEF.plane = function()
  local t = { n = 1, cur = 1, S = 2.5, p0 = 0, sp0 = 0, hinge = 0, dh = 0, ssup = 0, sup = 0 }
  for i = 1, 4 do
    t["sh" .. i], t["th" .. i], t["hs" .. i], t["b" .. i], t["L" .. i], t["b2" .. i] =
      0, 90, 0, (i == 1) and 6 or 1, (i == 1) and 1.5 or 1, 0
  end
  return t
end
local function PF(st, lab, un, key, fl, lo, hi)
  return { label = lab, unit = un, flags = fl or 0, lo = lo, hi = hi,
    get = function() return st[key .. st.cur] end,
    put = function(v) st[key .. st.cur] = v end }
end
PR.plane = {
  title = "SUPERFICIES PLANAS (E3)",
  hint = "theta: 90 = vertical; hs: borde sup.",
  fields = function(st)
    local n = math.floor(st.n)
    if n < 1 then n = 1 elseif n > 4 then n = 4 end
    if st.cur > n then st.cur = n elseif st.cur < 1 then st.cur = 1 end
    local i = st.cur
    local sh = st["sh" .. i]
    local f = {
      FI(st, "Numero de placas", "n", 1, 4),
      FN(st, "S del liquido", nil, "S", FF_POS),
      FO(st, "Presion en superficie", "kPa", "p0"),
    }
    if n > 1 then f[#f + 1] = FI(st, "Placa que se edita", "cur", 1, n) end
    local tag = (n > 1) and (" " .. i) or ""
    f[#f + 1] = { label = "Forma" .. tag, chk = "sh" .. i, t = st, flags = FF_CHOICE,
      choices = shape_names, nchoices = 5,
      cget = function() return st["sh" .. st.cur] end, cput = function(v) st["sh" .. st.cur] = v end }
    f[#f + 1] = PF(st, "Inclinacion theta" .. tag, "grad", "th", FF_RANGE, 1, 90)
    f[#f + 1] = PF(st, "Prof. borde sup." .. tag, "m", "hs", FF_NONNEG)
    if sh == 3 then
      f[#f + 1] = PF(st, "Diametro D" .. tag, "m", "L", FF_POS)
    elseif sh == 4 then
      f[#f + 1] = PF(st, "Base superior" .. tag, "m", "b", FF_POS)
      f[#f + 1] = PF(st, "Base inferior" .. tag, "m", "b2", FF_NONNEG)
      f[#f + 1] = PF(st, "Altura en plano" .. tag, "m", "L", FF_POS)
    else
      f[#f + 1] = PF(st, "Ancho b" .. tag, "m", "b", FF_POS)
      f[#f + 1] = PF(st, "Altura en plano" .. tag, "m", "L", FF_POS)
    end
    if n == 1 then
      f[#f + 1] = FC(st, "Bisagra", "hinge", hinge_names)
      if st.hinge == 3 then f[#f + 1] = FN(st, "Bisagra a distancia", "m", "dh", FF_NONNEG) end
      if st.hinge ~= 0 then f[#f + 1] = FO(st, "Apoyo a distancia", "m", "sup", FF_NONNEG) end
    end
    return f
  end,
  calc = function(st)
    local n = math.floor(st.n)
    local p = { S = st.S, p0 = nz(st.sp0) and st.p0 * 1000 or 0, plates = {},
      hinge = (n == 1) and st.hinge or 0, dh = st.dh }
    if n == 1 and st.hinge ~= 0 and nz(st.ssup) then p.sup = st.sup end
    for i = 1, n do
      p.plates[i] = { shape = st["sh" .. i], th = st["th" .. i], hs = st["hs" .. i],
        b = st["b" .. i], L = st["L" .. i], b2 = st["b2" .. i] }
    end
    local r = {}
    if St.st_plane(p, cfg(), r) ~= 0 then return r.msg end
    return nil, { p = p, r = r }
  end,
  sum = function(R)
    local p, r = R.p, R.r
    for i = 1, r.n do
      local o = r.pl[i]
      if r.n > 1 then W.view_add("Placa " .. i .. ": " .. shape_full[p.plates[i].shape + 1], C_TITLE) end
      V("Area A", o.A, "m2")
      V("hc (vertical)", o.hc, "m")
      V("Fuerza F", o.F, "N")
      V("yc (en plano)", o.yc, "m")
      V("yp (en plano)", o.yp, "m")
      V("hp (vertical)", o.hp, "m")
    end
    if r.n > 1 then
      W.view_add("TOTAL", C_TITLE)
      V("F total", r.F, "N")
      if r.same then
        V("yp resultante", r.yp, "m")
        V("hp resultante", r.hp, "m")
      end
    end
    if r.hinge then
      local h = r.hinge
      W.view_add("Bisagra", C_TITLE)
      V("Momento", h.M, "N.m")
      V("Reaccion apoyo", h.Rs, "N")
      V("Reaccion bisagra", h.Rh, "N")
    end
  end,
  memo = function(R)
    local p, r = R.p, R.r
    local c = cfg()
    local gam = c.gamma * p.S
    memo_begin("MEMORIA: SUPERFICIES PLANAS")
    memo_sec("DATOS")
    memo_data("S", p.S, "")
    memo_data("gamma S", gam, "N/m3")
    if p.p0 ~= 0 then
      memo_data("p superficie", p.p0 / 1000, "kPa")
      eq("h0", "p0/(gamma S)", "%v/%v", p.p0 / gam, "m", p.p0, gam)
    end
    for i = 1, r.n do
      local q, o = p.plates[i], r.pl[i]
      memo_sec(r.n > 1 and ("PLACA " .. i) or "PLACA")
      note(shape_full[q.shape + 1] .. ", theta = " .. N(q.th))
      memo_data("hs (borde sup)", q.hs, "m")
      if r.n > 1 then
        -- varias placas: memoria compacta (formulas de la tabla de figuras)
        memo_line(mfmt(" A=%v sc=%v Ic=%v", o.A, o.sc, o.Ic), C_FG)
        memo_line(mfmt(" s_top=%v yc=%v hc=%v", o.s_top, o.yc, o.hc), C_FG)
        memo_line(mfmt(" F=gamma S hc A=%v N", o.F), C_OK)
        memo_line(mfmt(" yp=yc+Ic/(yc A)=%v m", o.yp), C_OK)
      elseif q.shape == 0 then
        memo_data("b x L", q.b * q.L, "m2")
        eq("A", "b L", "%v*%v", o.A, "m2", q.b, q.L)
        eq("sc", "L/2", "%v/2", o.sc, "m", q.L)
        eq("Ic", "b L^3/12", "%v*%v^3/12", o.Ic, "m4", q.b, q.L)
      elseif q.shape == 1 or q.shape == 2 then
        eq("A", "b L/2", "%v*%v/2", o.A, "m2", q.b, q.L)
        eq("sc", q.shape == 1 and "2L/3" or "L/3", q.shape == 1 and "2*%v/3" or "%v/3", o.sc, "m", q.L)
        eq("Ic", "b L^3/36", "%v*%v^3/36", o.Ic, "m4", q.b, q.L)
      elseif q.shape == 3 then
        eq("A", "pi D^2/4", "pi*%v^2/4", o.A, "m2", q.L)
        eq("sc", "D/2", "%v/2", o.sc, "m", q.L)
        eq("Ic", "pi D^4/64", "pi*%v^4/64", o.Ic, "m4", q.L)
      else
        eq("A", "(b+b2) L/2", "(%v+%v)*%v/2", o.A, "m2", q.b, q.b2, q.L)
        eq("sc", "L(b+2 b2)/(3(b+b2))", "%v*(%v+2*%v)/(3*(%v+%v))", o.sc, "m", q.L, q.b, q.b2, q.b, q.b2)
        eq("Ic", "L^3(b^2+4 b b2+b2^2)/(36(b+b2))", nil, o.Ic, "m4")
      end
      local sn = sin(q.th * pi / 180)
      if r.n == 1 then
      eq("s_top", "(hs + h0)/sen th", "(%v+%v)/sin(%v)", o.s_top, "m", q.hs, p.p0 / gam, q.th)
      eq("yc", "s_top + sc", "%v+%v", o.yc, "m", o.s_top, o.sc)
      eq("hc", "yc sen th", "%v*sin(%v)", o.hc, "m", o.yc, q.th)
      eq("F", "gamma S hc A", "%v*%v*%v", o.F, "N", gam, o.hc, o.A)
      eq("yp", "yc + Ic/(yc A)", "%v+%v/(%v*%v)", o.yp, "m", o.yc, o.Ic, o.yc, o.A)
      eq("hp", "yp sen th", "%v*sin(%v)", o.hp, "m", o.yp, q.th)
      end
    end
    if r.n > 1 then
      memo_sec("SUMA DE PLACAS")
      eq("F", "Sum F_i", nil, r.F, "N")
      if r.same then
        eq("yp", "Sum(F_i yp_i)/F", nil, r.yp, "m")
      else
        warn("theta distinto: no hay yp unico")
      end
    end
    if r.hinge then
      local h, o = r.hinge, r.pl[1]
      memo_sec("MOMENTO EN LA BISAGRA")
      memo_data("bisagra a", h.sh, "m del borde sup")
      memo_data("apoyo a", h.ss, "m del borde sup")
      eq("CP", "yp - s_top", "%v-%v", o.dcp, "m", o.yp, o.s_top)
      eq("M", "F (CP - bisagra)", "%v*(%v-%v)", h.M, "N.m", o.F, o.dcp, h.sh)
      eq("R apoyo", "M/(apoyo - bisagra)", "%v/(%v-%v)", h.Rs, "N", h.M, h.ss, h.sh)
      eq("R bisagra", "F - R apoyo", "%v-%v", h.Rh, "N", o.F, h.Rs)
    end
    memo_sec("RESULTADO")
    memo_res("F", r.F, "N")
    if r.n == 1 then memo_res("yp", r.pl[1].yp, "m") end
    if r.hinge then memo_res("R apoyo", r.hinge.Rs, "N") end
  end,
}

-- ============================================================ E3 compuerta en L
DEF.gate_l = function()
  return { a = 1.2, w = 3, e = 3, Sl = 7.9, S = 1 }
end
PR.gate_l = {
  title = "COMPUERTA EN L (E3)",
  hint = "H: altura de la parte vertical",
  fields = function(st)
    return {
      FN(st, "Largo de la tapa a", "m", "a", FF_POS),
      FN(st, "Ancho w", "m", "w", FF_POS),
      FN(st, "Espesor lamina", "mm", "e", FF_NONNEG),
      FN(st, "S de la lamina", nil, "Sl", FF_NONNEG),
      FN(st, "S del liquido", nil, "S", FF_POS),
    }
  end,
  calc = function(st)
    local p = { a = st.a, w = st.w, e = st.e / 1000, Sl = st.Sl, S = st.S }
    local r = {}
    if St.st_gateL(p, cfg(), r) ~= 0 then return r.msg end
    return nil, { p = p, r = r }
  end,
  sum = function(R)
    local r = R.r
    V("H", r.H, "m")
    V("Peso lamina", r.Wp, "N")
    V("Empuje vertical", r.Fw, "N")
    V("Momento volcador", r.Mw, "N.m")
    V("Momento resist.", r.Ml, "N.m")
    V("Iteraciones", r.iters, "")
  end,
  memo = function(R)
    local p, r = R.p, R.r
    local c = cfg()
    memo_begin("MEMORIA: COMPUERTA EN L")
    memo_sec("DATOS")
    memo_data("a (tapa)", p.a, "m")
    memo_data("w", p.w, "m")
    memo_data("e lamina", p.e * 1000, "mm")
    memo_data("S lamina", p.Sl, "")
    memo_data("S liquido", p.S, "")
    memo_sec("PESO DE LA TAPA")
    eq("Wp", "e a w S_l gamma_w", "%v*%v*%v*%v*%v", r.Wp, "N", p.e, p.a, p.w, p.Sl, c.gamma)
    memo_sec("MOMENTOS EN LA ESQUINA")
    note("Empuje en la parte vertical:")
    note("Mw = gamma S w H^3/6")
    note("Liquido sobre la tapa + peso:")
    note("Ml = (gamma S H a w + Wp) a/2")
    note("Equilibrio: Mw - Ml = 0 (biseccion)")
    memo_sec("BISECCION EN H")
    memo_table({ "it", "a", "b", "H", "f" }, 5, r.lg, { 1, 1, 1, 1, 1 })
    memo_sec("COMPROBACION")
    eq("Mw", "gamma S w H^3/6", "%v*%v*%v^3/6", r.Mw, "N.m", r.gam, p.w, r.H)
    eq("Ml", "(gamma S H a w + Wp) a/2", "(%v*%v*%v*%v+%v)*%v/2", r.Ml, "N.m", r.gam, r.H, p.a, p.w, r.Wp, p.a)
    memo_sec("RESULTADO")
    memo_res("H", r.H, "m")
  end,
}

-- ============================================================ E4 cuarto de circulo
DEF.curved = function()
  return { tipo = 1, R = 5, h = 5, w = 2, side = 0, hinge = 1, dir = 0, S = 1 }
end
local curve_names = { "Domo (convexo)", "Cuenco (concavo)" }
local side_names = { "Liquido encima", "Liquido debajo" }
local chinge_names = { "Sin bisagra", "Extremo sup. A", "Extremo inf. B" }
local dir_names = { "Horizontal", "Vertical" }
PR.curved = {
  title = "SUPERFICIE CURVA (E4)",
  hint = "Cuarto de circulo, ancho w",
  fields = function(st)
    local f = {
      FC(st, "Arco", "tipo", curve_names),
      FN(st, "Radio R", "m", "R", FF_POS),
      FN(st, "Prof. sobre borde sup.", "m", "h", FF_NONNEG),
      FN(st, "Ancho w", "m", "w", FF_POS),
      FC(st, "Liquido", "side", side_names),
      FN(st, "S del liquido", nil, "S", FF_POS),
      FC(st, "Bisagra", "hinge", chinge_names),
    }
    if st.hinge ~= 0 then f[#f + 1] = FC(st, "Fuerza en el otro", "dir", dir_names) end
    return f
  end,
  calc = function(st)
    local p = { type = st.tipo, R = st.R, h = st.h, w = st.w, side = st.side, S = st.S,
      hinge = st.hinge, dir = st.dir }
    local r = {}
    if St.st_curved(p, cfg(), r) ~= 0 then return r.msg end
    return nil, { p = p, r = r }
  end,
  sum = function(R)
    local p, r = R.p, R.r
    V("FH", r.FH, "N")
    V("FV", r.FV, "N")
    V("FR", r.FR, "N")
    V("Angulo (horiz.)", r.ang, "grad")
    V("Prof. CP de FH", r.hpd, "m")
    V("x de FV (desde O)", r.xV, "m")
    W.view_add(r.real and " Volumen real (liquido encima)" or " Volumen imaginario (debajo)", C_GRAY)
    if r.P then
      W.view_add("Para mantenerla cerrada", C_TITLE)
      V("Fuerza P", r.P, "N")
      local s
      if r.Pdir == 0 then s = (r.Psign >= 0) and "hacia la derecha" or "hacia la izquierda"
      else s = (r.Psign >= 0) and "hacia arriba" or "hacia abajo" end
      W.view_add(" P " .. s, C_GRAY)
    end
  end,
  memo = function(R)
    local p, r = R.p, R.r
    local gam = cfg().gamma * p.S
    memo_begin("MEMORIA: SUPERFICIE CURVA")
    memo_sec("DATOS")
    note(curve_names[p.type + 1] .. ", " .. side_names[p.side + 1]:lower())
    memo_data("R", p.R, "m")
    memo_data("h sobre borde sup", p.h, "m")
    memo_data("w", p.w, "m")
    memo_data("gamma S", gam, "N/m3")
    memo_sec("COMPONENTE HORIZONTAL")
    note("Proyeccion vertical de altura R")
    eq("hc", "h + R/2", "%v+%v/2", r.hc, "m", p.h, p.R)
    eq("FH", "gamma S hc R w", "%v*%v*%v*%v", r.FH, "N", gam, r.hc, p.R, p.w)
    eq("hp", "hc + R^2/(12 hc)", "%v+%v^2/(12*%v)", r.hpd, "m", r.hc, p.R, r.hc)
    memo_sec("COMPONENTE VERTICAL")
    if p.type == 0 then
      note("Vol = (h+R) R - pi R^2/4 (por m)")
      eq("Vol", "((h+R) R - pi R^2/4) w", "((%v+%v)*%v-pi*%v^2/4)*%v", r.vol, "m3", p.h, p.R, p.R, p.R, p.w)
    else
      note("Vol = h R + pi R^2/4 (por m)")
      eq("Vol", "(h R + pi R^2/4) w", "(%v*%v+pi*%v^2/4)*%v", r.vol, "m3", p.h, p.R, p.R, p.w)
    end
    note(r.real and "Volumen REAL (liquido encima)" or "Volumen IMAGINARIO (liquido debajo)")
    eq("FV", "gamma S Vol", "%v*%v", r.FV, "N", gam, r.vol)
    eq("xV", "x del centroide desde O", nil, r.xV, "m")
    memo_sec("RESULTANTE")
    eq("FR", "sqrt(FH^2 + FV^2)", "sqrt(%v^2+%v^2)", r.FR, "N", r.FH, r.FV)
    eq("ang", "atan(FV/FH)", "atan(%v/%v)", r.ang, "grad", r.FV, r.FH)
    note("FR pasa por el centro O del arco")
    if r.P then
      memo_sec("FUERZA PARA MANTENERLA CERRADA")
      note("Bisagra en " .. (p.hinge == 1 and "A (extremo sup.)" or "B (extremo inf.)"))
      note("Fuerza " .. (p.dir == 0 and "horizontal" or "vertical") .. " en el otro extremo")
      eq("M", "momento de FR en la bisagra", nil, r.M, "N.m")
      eq("P", "|M|/brazo", nil, r.P, "N")
    end
    memo_sec("RESULTADO")
    memo_res("FH", r.FH, "N")
    memo_res("FV", r.FV, "N")
    memo_res("FR", r.FR, "N")
    if r.P then memo_res("P", r.P, "N") end
  end,
}

-- ============================================================ E4 semicilindro
DEF.semicyl = function()
  return { D = 1.5, L = 3, h = 3, s = 0.16, rows = 2, S = 1 }
end
PR.semicyl = {
  title = "SEMICILINDRO Y PERNOS (E4)",
  hint = "h: superficie libre sobre la corona",
  fields = function(st)
    return {
      FN(st, "Diametro D", "m", "D", FF_POS),
      FN(st, "Longitud L", "m", "L", FF_POS),
      FN(st, "Libre sobre corona h", "m", "h", FF_NONNEG),
      FN(st, "Separacion pernos s", "m", "s", FF_POS),
      FI(st, "Filas de pernos", "rows", 1, 2),
      FN(st, "S del liquido", nil, "S", FF_POS),
    }
  end,
  calc = function(st)
    local p = { D = st.D, L = st.L, h = st.h, s = st.s, rows = st.rows, S = st.S }
    local r = {}
    if St.st_semicyl(p, cfg(), r) ~= 0 then return r.msg end
    return nil, { p = p, r = r }
  end,
  sum = function(R)
    local r = R.r
    V("FV por metro", r.FVu, "N/m")
    V("FV total", r.FV, "N")
    V("Numero de pernos", r.nb, "")
    V("Fuerza por perno", r.Fp, "N")
  end,
  memo = function(R)
    local p, r = R.p, R.r
    local gam = cfg().gamma * p.S
    memo_begin("MEMORIA: SEMICILINDRO")
    memo_sec("DATOS")
    memo_data("D", p.D, "m")
    memo_data("L", p.L, "m")
    memo_data("h sobre corona", p.h, "m")
    memo_data("s pernos", p.s, "m")
    memo_data("filas", p.rows, "")
    memo_data("gamma S", gam, "N/m3")
    memo_sec("FUERZA VERTICAL")
    note("Volumen entre la tapa y el nivel")
    note("libre (por metro de longitud)")
    eq("Hp", "h + D/2", "%v+%v/2", r.Hp, "m", p.h, p.D)
    eq("Vol", "D Hp - pi D^2/8", "%v*%v-pi*%v^2/8", r.volu, "m3/m", p.D, r.Hp, p.D)
    eq("FVu", "gamma S Vol", "%v*%v", r.FVu, "N/m", gam, r.volu)
    eq("FV", "FVu L", "%v*%v", r.FV, "N", r.FVu, p.L)
    memo_sec("PERNOS")
    eq("nb", "filas L/s", "%v*%v/%v", r.nb, "", p.rows, p.L, p.s)
    eq("Fp", "FVu s/filas", "%v*%v/%v", r.Fp, "N", r.FVu, p.s, p.rows)
    memo_sec("RESULTADO")
    memo_res("Fuerza por perno", r.Fp, "N")
  end,
}

-- ============================================================ E5 flotacion
local float_names = { "Rectangulo", "Triangulo v.abajo", "Triangulo v.arriba", "Rect.+quilla tri.",
  "Cuadrado a 45 gr", "Cilindro macizo", "Cilindro hueco" }
local float_full = { "Prisma rectangular", "Prisma triangular, vertice abajo",
  "Prisma triangular, vertice arriba", "Rectangulo con quilla triangular", "Prisma cuadrado girado 45",
  "Cilindro macizo (eje vertical)", "Cilindro hueco con fondo" }
DEF.float = function()
  return { shape = 6, mode = 0, S = 1, rhob = 2500, h = 0.5, b = 1, H = 4.5, hk = 0.6, L = 1, D = 3, e = 0.25 }
end
PR.float = {
  title = "FLOTACION Y ESTABILIDAD (E5)",
  hint = "Calado medido desde el fondo",
  fields = function(st)
    local f = {
      FC(st, "Forma", "shape", float_names),
      FC(st, "Calcular", "mode", { "Calado", "Densidad del cuerpo" }),
      FN(st, "S del liquido", nil, "S", FF_POS),
    }
    if st.mode == 0 then f[#f + 1] = FN(st, "Densidad del cuerpo", "kg/m3", "rhob", FF_POS)
    else f[#f + 1] = FN(st, "Calado h", "m", "h", FF_POS) end
    local sh = st.shape
    if sh == 0 or sh == 1 or sh == 2 then
      f[#f + 1] = FN(st, sh == 0 and "Ancho b" or "Base b", "m", "b", FF_POS)
      f[#f + 1] = FN(st, "Altura H", "m", "H", FF_POS)
      f[#f + 1] = FN(st, "Largo L", "m", "L", FF_POS)
    elseif sh == 3 then
      f[#f + 1] = FN(st, "Ancho b", "m", "b", FF_POS)
      f[#f + 1] = FN(st, "Altura del rectangulo", "m", "H", FF_POS)
      f[#f + 1] = FN(st, "Altura de la quilla", "m", "hk", FF_POS)
      f[#f + 1] = FN(st, "Largo L", "m", "L", FF_POS)
    elseif sh == 4 then
      f[#f + 1] = FN(st, "Lado a", "m", "b", FF_POS)
      f[#f + 1] = FN(st, "Largo L", "m", "L", FF_POS)
    elseif sh == 5 then
      f[#f + 1] = FN(st, "Diametro D", "m", "D", FF_POS)
      f[#f + 1] = FN(st, "Altura H", "m", "H", FF_POS)
    else
      f[#f + 1] = FN(st, "Diametro interior", "m", "D", FF_POS)
      f[#f + 1] = FN(st, "Espesor e", "m", "e", FF_POS)
      f[#f + 1] = FN(st, "Altura H", "m", "H", FF_POS)
    end
    return f
  end,
  calc = function(st)
    local p = { shape = st.shape, mode = st.mode, S = st.S, rhob = st.rhob, h = st.h, b = st.b,
      H = st.H, hk = st.hk, L = st.L, D = st.D, e = st.e }
    local r = {}
    if St.st_float(p, cfg(), r) ~= 0 then return r.msg end
    return nil, { p = p, r = r }
  end,
  sum = function(R)
    local p, r = R.p, R.r
    V("Calado h", r.h, "m")
    V("Altura total", r.Htot, "m")
    V("Densidad cuerpo", r.rhob, "kg/m3")
    V("zB (centro empuje)", r.zB, "m")
    V("zG (centro grav.)", r.zG, "m")
    V("I linea de agua", r.I, "m4")
    V("BM = I/Vd", r.BM, "m")
    V("GM", r.GM, "m")
    if r.sink then
      W.view_add(" ! Calado > altura: se hunde", C_ERR)
    else
      W.view_add(r.stable and " ESTABLE (GM > 0)" or " INESTABLE (GM < 0)", r.stable and C_OK or C_ERR)
    end
  end,
  memo = function(R)
    local p, r = R.p, R.r
    memo_begin("MEMORIA: FLOTACION")
    memo_sec("DATOS")
    note(float_full[p.shape + 1])
    memo_data("S liquido", p.S, "")
    if p.mode == 0 then memo_data("rho cuerpo", p.rhob, "kg/m3") else memo_data("calado h", p.h, "m") end
    if p.shape <= 4 then
      memo_data(p.shape == 4 and "lado a" or "b", p.b, "m")
      if p.shape <= 3 then memo_data("H", p.H, "m") end
      if p.shape == 3 then memo_data("hk (quilla)", p.hk, "m") end
      memo_data("L", p.L, "m")
    elseif p.shape == 5 then
      memo_data("D", p.D, "m"); memo_data("H", p.H, "m")
    else
      memo_data("Di", p.D, "m"); memo_data("e", p.e, "m"); memo_data("H", p.H, "m")
    end
    memo_sec("VOLUMEN DEL CUERPO")
    eq("rho_f", "S rho_agua", "%v*%v", r.rhof, "kg/m3", p.S, r.rhof / p.S)
    if p.shape == 0 then eq("Vm", "b H L", "%v*%v*%v", r.Vm, "m3", p.b, p.H, p.L)
    elseif p.shape == 1 or p.shape == 2 then eq("Vm", "b H L/2", "%v*%v*%v/2", r.Vm, "m3", p.b, p.H, p.L)
    elseif p.shape == 3 then
      eq("Vm", "(b hk/2 + b H) L", "(%v*%v/2+%v*%v)*%v", r.Vm, "m3", p.b, p.hk, p.b, p.H, p.L)
    elseif p.shape == 4 then eq("Vm", "a^2 L", "%v^2*%v", r.Vm, "m3", p.b, p.L)
    elseif p.shape == 5 then eq("Vm", "pi D^2 H/4", "pi*%v^2*%v/4", r.Vm, "m3", p.D, p.H)
    else
      eq("Do", "Di + 2 e", "%v+2*%v", r.Do, "m", p.D, p.e)
      eq("Vm", "pi/4 (Do^2 H - Di^2 (H-e))", "pi/4*(%v^2*%v-%v^2*(%v-%v))", r.Vm, "m3",
        r.Do, p.H, p.D, p.H, p.e)
    end
    memo_sec("EQUILIBRIO")
    note("Peso = Empuje: rho_b Vm = rho_f Vd")
    if p.mode == 0 then
      eq("Vd", "rho_b Vm/rho_f", "%v*%v/%v", r.Vd, "m3", p.rhob, r.Vm, r.rhof)
    else
      eq("Vd", "volumen bajo el calado", nil, r.Vd, "m3")
      eq("rho_b", "rho_f Vd/Vm", "%v*%v/%v", r.rhob, "kg/m3", r.rhof, r.Vd, r.Vm)
    end
    if r.lg then
      memo_sec("BISECCION EN EL CALADO")
      note("Area sumergida = Vd/L")
      memo_table({ "it", "a", "b", "h", "f" }, 5, r.lg, { 1, 1, 1, 1, 1 })
    elseif p.mode == 0 then
      if p.shape >= 5 then
        eq("h", "Vd/(pi Do^2/4)", "%v/(pi*%v^2/4)", r.h, "m", r.Vd, r.Do or p.D)
      end
    end
    eq("h", "calado", nil, r.h, "m")
    memo_sec("ESTABILIDAD")
    eq("zB", "centroide sumergido", nil, r.zB, "m")
    eq("zG", "centroide del cuerpo", nil, r.zG, "m")
    eq("I", "inercia de la linea de agua", nil, r.I, "m4")
    eq("BM", "I/Vd", "%v/%v", r.BM, "m", r.I, r.Vd)
    eq("GM", "BM - (zG - zB)", "%v-(%v-%v)", r.GM, "m", r.BM, r.zG, r.zB)
    if r.sink then
      warn("Calado mayor que la altura: se hunde")
    elseif r.stable then
      note("GM > 0: ESTABLE", C_OK)
    else
      warn("GM < 0: INESTABLE")
    end
    memo_sec("RESULTADO")
    memo_res("h", r.h, "m")
    memo_res("rho cuerpo", r.rhob, "kg/m3")
    memo_res("GM", r.GM, "m")
  end,
}

-- ============================================================ E6 tanque con aceleracion
DEF.relative = function()
  return { S = 0.9, ax = 4.903, az = 0, x0 = 0, z0 = 1.2, p0 = 0, modo = 0, xt = 1.8, zt = 0, pt = 0,
    np = 2, x1 = 1.8, z1 = 0, x2 = -0.15, z2 = -0.15, x3 = 0, z3 = 0, x4 = 0, z4 = 0,
    tank = 0, tx = 0, tz = 0, tL = 1, tH = 1 }
end
PR.relative = {
  title = "EQUILIBRIO RELATIVO (E6)",
  hint = "x a la derecha, z hacia arriba",
  fields = function(st)
    local np = math.floor(st.np)
    if np < 0 then np = 0 elseif np > 4 then np = 4 end
    local f = {
      FN(st, "S del liquido", nil, "S", FF_POS),
      FN(st, "Aceleracion ax", "m/s2", "ax"),
      FN(st, "Aceleracion az", "m/s2", "az"),
      FN(st, "Referencia x0", "m", "x0"),
      FN(st, "Referencia z0", "m", "z0"),
      FN(st, "p en la referencia", "kPa", "p0"),
      FC(st, "Calcular", "modo", { "Presiones", "Hallar ax", "Hallar az" }),
    }
    if st.modo ~= 0 then
      f[#f + 1] = FN(st, "Punto objetivo x", "m", "xt")
      f[#f + 1] = FN(st, "Punto objetivo z", "m", "zt")
      f[#f + 1] = FN(st, "p objetivo", "kPa", "pt")
    end
    f[#f + 1] = FI(st, "Puntos a evaluar", "np", 0, 4)
    for i = 1, np do
      f[#f + 1] = FN(st, "Punto " .. i .. " x", "m", "x" .. i)
      f[#f + 1] = FN(st, "Punto " .. i .. " z", "m", "z" .. i)
    end
    f[#f + 1] = FC(st, "Tanque cerrado", "tank", { "No", "Si" })
    if st.tank ~= 0 then
      f[#f + 1] = FN(st, "Esquina inf. x", "m", "tx")
      f[#f + 1] = FN(st, "Esquina inf. z", "m", "tz")
      f[#f + 1] = FN(st, "Ancho Lx", "m", "tL", FF_POS)
      f[#f + 1] = FN(st, "Alto Hz", "m", "tH", FF_POS)
    end
    return f
  end,
  calc = function(st)
    local np = math.floor(st.np)
    local p = { S = st.S, ax = st.ax, az = st.az, x0 = st.x0, z0 = st.z0, p0 = st.p0 * 1000,
      mode = st.modo, xt = st.xt, zt = st.zt, pt = st.pt * 1000, pts = {} }
    for i = 1, np do p.pts[i] = { st["x" .. i], st["z" .. i] } end
    if st.tank ~= 0 then p.tank = { x = st.tx, z = st.tz, Lx = st.tL, Hz = st.tH } end
    if p.mode == 0 and np == 0 and not p.tank then return "Agregue un punto o el tanque" end
    local r = {}
    if St.st_relative(p, cfg(), r) ~= 0 then return r.msg end
    return nil, { p = p, r = r }
  end,
  sum = function(R)
    local p, r = R.p, R.r
    if p.mode == 1 then V("ax necesaria", r.ax, "m/s2") end
    if p.mode == 2 then V("az necesaria", r.az, "m/s2") end
    V("Pendiente dz/dx", r.slope, "")
    V("Angulo superficie", r.alpha, "grad")
    for i, q in ipairs(p.pts) do V("p punto " .. i, r.pp[i], "Pa") end
    if r.corners then
      V("p maxima", r.pmax / 1000, "kPa")
      V("p minima", r.pmin / 1000, "kPa")
    end
  end,
  memo = function(R)
    local p, r = R.p, R.r
    memo_begin("MEMORIA: EQUILIBRIO RELATIVO")
    memo_sec("DATOS")
    memo_data("S", p.S, "")
    eq("rho", "S rho_agua", nil, r.rho, "kg/m3")
    memo_data("ax", r.ax, "m/s2")
    memo_data("az", r.az, "m/s2")
    memo_data("referencia x0", p.x0, "m")
    memo_data("referencia z0", p.z0, "m")
    memo_data("p referencia", p.p0 / 1000, "kPa")
    memo_sec("GRADIENTE DE PRESION")
    note("dp/dx = -rho ax   dp/dz = -rho (g+az)")
    eq("gz", "g + az", "%v+%v", r.gz, "m/s2", r.gz - r.az, r.az)
    eq("tan a", "ax/(g+az)", "%v/%v", r.ax / r.gz, "", r.ax, r.gz)
    eq("alfa", "atan(ax/(g+az))", nil, r.alpha, "grad")
    note("La superficie libre baja hacia +x")
    note("si ax > 0 (sube hacia atras)")
    if p.mode ~= 0 then
      memo_sec("ACELERACION NECESARIA")
      memo_data("punto (x,z)", p.xt, "m")
      memo_data("z", p.zt, "m")
      memo_data("p objetivo", p.pt / 1000, "kPa")
      if p.mode == 1 then
        eq("ax", "(p0-pt-rho gz dz)/(rho dx)", "(%v-%v-%v*%v*%v)/(%v*%v)", r.ax, "m/s2",
          p.p0, p.pt, r.rho, r.gz, p.zt - p.z0, r.rho, p.xt - p.x0)
      else
        eq("gz", "(p0-pt-rho ax dx)/(rho dz)", "(%v-%v-%v*%v*%v)/(%v*%v)", r.gz, "m/s2",
          p.p0, p.pt, r.rho, r.ax, p.xt - p.x0, r.rho, p.zt - p.z0)
        eq("az", "gz - g", "%v-%v", r.az, "m/s2", r.gz, r.gz - r.az)
      end
    end
    if #p.pts > 0 then
      memo_sec("PRESIONES EN PUNTOS")
      note("p = p0 - rho ax dx - rho gz dz")
      for i, q in ipairs(p.pts) do
        eq("p" .. i, "(" .. N(q[1]) .. "," .. N(q[2]) .. ")", "%v-%v*%v*%v-%v*%v*%v", r.pp[i], "Pa",
          p.p0, r.rho, r.ax, q[1] - p.x0, r.rho, r.gz, q[2] - p.z0)
      end
    end
    if r.corners then
      memo_sec("TANQUE CERRADO LLENO")
      note("La presion es lineal: extremos en esquinas")
      for i, q in ipairs(r.corners) do
        memo_line(mfmt(" (%v, %v) p = %v kPa", q[1], q[2], q[3] / 1000), C_FG)
      end
      memo_res("p maxima", r.pmax / 1000, "kPa")
      memo_res("p minima", r.pmin / 1000, "kPa")
    end
    memo_sec("RESULTADO")
    if p.mode == 1 then memo_res("ax", r.ax, "m/s2") end
    if p.mode == 2 then memo_res("az", r.az, "m/s2") end
    memo_res("angulo superficie", r.alpha, "grad")
    for i = 1, #p.pts do memo_res("p punto " .. i, r.pp[i], "Pa") end
  end,
}

-- ============================================================ E6 polea
DEF.pulley = function()
  return { S = 1, mc1 = 0, V1 = 200, h1 = 20, mc2 = 0, V2 = 300, h2 = 30 }
end
PR.pulley = {
  title = "RECIPIENTES EN POLEA (E6)",
  hint = "Polea ideal; presion en el fondo",
  fields = function(st)
    return {
      FN(st, "S del liquido", nil, "S", FF_POS),
      FN(st, "Masa recipiente 1", "kg", "mc1", FF_NONNEG),
      FN(st, "Volumen liquido 1", "l", "V1", FF_NONNEG),
      FN(st, "Altura liquido 1", "cm", "h1", FF_POS),
      FN(st, "Masa recipiente 2", "kg", "mc2", FF_NONNEG),
      FN(st, "Volumen liquido 2", "l", "V2", FF_NONNEG),
      FN(st, "Altura liquido 2", "cm", "h2", FF_POS),
    }
  end,
  calc = function(st)
    local p = { S = st.S, mc1 = st.mc1, V1 = st.V1 / 1000, h1 = st.h1 / 100,
      mc2 = st.mc2, V2 = st.V2 / 1000, h2 = st.h2 / 100 }
    local r = {}
    local c = cfg()
    if St.st_pulley(p, c, r) ~= 0 then return r.msg end
    return nil, { p = p, r = r, g = c.g }
  end,
  sum = function(R)
    local r = R.r
    V("Masa 1", r.M1, "kg")
    V("Masa 2", r.M2, "kg")
    V("Aceleracion", math.abs(r.a), "m/s2")
    W.view_add(r.a >= 0 and " Baja el recipiente 2" or " Baja el recipiente 1", C_GRAY)
    V("Tension T", r.T, "N")
    V("p fondo 1", r.p1, "Pa")
    V("p fondo 2", r.p2, "Pa")
  end,
  memo = function(R)
    local p, r = R.p, R.r
    memo_begin("MEMORIA: RECIPIENTES EN POLEA")
    memo_sec("DATOS")
    memo_data("rho", r.rho, "kg/m3")
    memo_data("m recip 1", p.mc1, "kg")
    memo_data("V liquido 1", p.V1 * 1000, "l")
    memo_data("h liquido 1", p.h1 * 100, "cm")
    memo_data("m recip 2", p.mc2, "kg")
    memo_data("V liquido 2", p.V2 * 1000, "l")
    memo_data("h liquido 2", p.h2 * 100, "cm")
    memo_sec("MASAS")
    eq("M1", "mc1 + rho V1", "%v+%v*%v", r.M1, "kg", p.mc1, r.rho, p.V1)
    eq("M2", "mc2 + rho V2", "%v+%v*%v", r.M2, "kg", p.mc2, r.rho, p.V2)
    memo_sec("ACELERACION Y TENSION")
    note("a positiva: baja 2 y sube 1")
    eq("a", "g (M2 - M1)/(M1 + M2)", "%v*(%v-%v)/(%v+%v)", r.a, "m/s2", R.g, r.M2, r.M1, r.M1, r.M2)
    eq("T", "2 M1 M2 g/(M1 + M2)", "2*%v*%v*%v/(%v+%v)", r.T, "N", r.M1, r.M2, R.g, r.M1, r.M2)
    memo_sec("PRESION EN EL FONDO")
    note("Sube: g + a;  baja: g - a")
    eq("p1", "rho (g + a) h1", "%v*(%v+%v)*%v", r.p1, "Pa", r.rho, R.g, r.a, p.h1)
    eq("p2", "rho (g - a) h2", "%v*(%v-%v)*%v", r.p2, "Pa", r.rho, R.g, r.a, p.h2)
    memo_sec("RESULTADO")
    memo_res("a", r.a, "m/s2")
    memo_res("T", r.T, "N")
    memo_res("p fondo 1", r.p1, "Pa")
    memo_res("p fondo 2", r.p2, "Pa")
  end,
}

for _, name in ipairs(KINDS) do reset(name) end

-- ================================================================ corredor generico
local cur_of = {}
local fk_sum = { "MEMORIA", "", "GUARDAR", "", "VOLVER" }
local fk_memo = { "RESUMEN", "", "", "", "VOLVER" }

local function result_loop(kind_i, pr, R)
  local memo = false
  while true do
    if memo then pr.memo(R) else
      W.view_clear()
      pr.sum(R)
    end
    local fk = memo and fk_memo or fk_sum
    if not S.KT_BASE then fk = memo and fk_memo or { "MEMORIA", "", "", "", "VOLVER" } end
    local k = W.view_run(pr.title, fk)
    if k == K_F1 then memo = not memo
    elseif k == K_F3 and not memo and S.KT_BASE then F.case_save_ui(S.KT_BASE + kind_i - 1)
    elseif k == K_MODE then F.scr_settings()
    else return end
    if U.quit then return end
  end
end

local function kind_of(kind)
  if type(kind) == "string" then
    for i, n in ipairs(KINDS) do if n == kind then return i, n end end
    return nil
  end
  if type(kind) == "number" and KINDS[kind] then return kind, KINDS[kind] end
  return nil
end
function S.kind_name(kind) local _, n = kind_of(kind); return n end

local last_kind
function S.run_kind(kind, autocalc)
  local ki, name = kind_of(kind)
  if not ki then return end
  last_kind = ki
  local pr, st = PR[name], ST[name]
  local fm = { title = pr.title, f = pr.fields(st), cur = cur_of[name] or 0, top = 0 }
  fm.n = #fm.f
  fm.fk = { "", "", "", "AJUSTES", "CALC" }
  fm.hint = pr.hint
  fm.on_commit = function()
    fm.f = pr.fields(st)
    fm.n = #fm.f
    if fm.cur >= fm.n then fm.cur = fm.n - 1 end
  end
  if fm.cur >= fm.n then fm.cur = 0 end
  while true do
    local k
    if autocalc then
      autocalc = false
      k = K_F5
    else
      k = W.form_run(fm)
    end
    if k == K_QUIT or k == K_CLEAR then break end
    if k == K_F4 or k == K_MODE then
      F.scr_settings()
    elseif k == K_F5 or k == K_ENTER then
      if W.form_check(fm) then
        local err, R = pr.calc(st)
        if err then
          fm.msg = err
          fm.msg_color = C_ERR
        else
          result_loop(ki, pr, R)
          if U.quit then break end
        end
      end
    end
  end
  cur_of[name] = fm.cur
end

-- ----------------------------------------------------------- Mis casos
function S.case_get(kind)
  local _, name = kind_of(kind)
  if not name then return nil end
  local t = {}
  for k, v in pairs(ST[name]) do if type(v) == "number" then t[k] = v end end
  return t
end

function S.case_set(kind, t)
  local _, name = kind_of(kind)
  if not name or type(t) ~= "table" then return false end
  local st = reset(name)
  for k, v in pairs(t) do if type(v) == "number" and st[k] ~= nil then st[k] = v end end
  return true
end

function S.case_run(kind, autocalc)
  if autocalc == nil then autocalc = true end
  S.run_kind(kind, autocalc)
end
function S.case_count() return #KINDS end
function S.last_kind() return last_kind end

-- ================================================================ ejemplos de examen
local D2R = 180 / pi
local EX = {}
local function ex(name, kind, fn) EX[#EX + 1] = { name = name, kind = kind, fn = fn } end
local function setv(st, t) for k, v in pairs(t) do st[k] = v end end
local function plate(st, i, sh, th, hs, b, L, b2)
  st["sh" .. i], st["th" .. i], st["hs" .. i], st["b" .. i], st["L" .. i], st["b2" .. i] =
    sh, th, hs, b, L, b2 or 0
end

ex("EPSON P1a Cojinete: par T", "visc_bearing", function(st)
  setv(st, { mu = 0.005, D = 80, L = 1000, e = 0.1, dato = 0, val = 500 }) end)
ex("EPSON P1b Cojinete: rpm con T", "visc_bearing", function(st)
  setv(st, { mu = 0.005, D = 80, L = 2000, e = 0.2, dato = 1, val = 0.2 }) end)
ex("EPSON P2-1 Encofrado vertical", "plane", function(st)
  setv(st, { n = 1, cur = 1, S = 2.5 }); plate(st, 1, 0, 90, 0, 6, 1.5) end)
ex("EPSON P2-2 Encofrado inclinado", "plane", function(st)
  setv(st, { n = 1, cur = 1, S = 2.5 })
  plate(st, 1, 0, atan2(2.5, 1) * D2R, 1.5, 6, sqrt(2.5 * 2.5 + 1)) end)
ex("EPSON P2-3 Encofrado compuesto", "plane", function(st)
  setv(st, { n = 2, cur = 1, S = 2.5 })
  plate(st, 1, 0, 90, 0, 1, 4); plate(st, 2, 1, 90, 1.5, 1, 2.5) end)
ex("EPSON P3a Semicilindro, pernos", "semicyl", function(st)
  setv(st, { D = 1.5, L = 3, h = 3, s = 0.16, rows = 2, S = 1 }) end)
ex("EPSON P3b Cuarto de circulo", "curved", function(st)
  setv(st, { tipo = 1, R = 5, h = 5, w = 2, side = 0, hinge = 1, dir = 0, S = 1 }) end)
ex("EPSON P4a Cilindro hueco", "float", function(st)
  setv(st, { shape = 6, mode = 0, S = 1, rhob = 2500, D = 3, e = 0.25, H = 4.5 }) end)
ex("EPSON P4b Cilindro hueco H=3e", "float", function(st)
  setv(st, { shape = 6, mode = 0, S = 1, rhob = 2500, D = 3, e = 0.25, H = 0.75 }) end)
ex("EPSON P5b Recipientes en polea", "pulley", function(st)
  setv(st, { S = 1, mc1 = 0, V1 = 200, h1 = 20, mc2 = 0, V2 = 300, h2 = 30 }) end)
ex("P1-2024 P1 Cojinete: potencia", "visc_bearing", function(st)
  setv(st, { mu = 0.2, D = 40, L = 60, e = 0.1, dato = 0, val = 1250 }) end)
ex("P1-2018 P1a Prisma tri. S 0.7", "float", function(st)
  setv(st, { shape = 1, mode = 0, S = 1, rhob = 700, b = 2 * 0.6 / sqrt(3), H = 0.6, L = 1 }) end)
ex("P1-2018 P1b Prisma tri. S 0.3", "float", function(st)
  setv(st, { shape = 2, mode = 0, S = 1, rhob = 300, b = 2 * 0.6 / sqrt(3), H = 0.6, L = 1 }) end)
ex("P1-2018 P2 Compuerta en L", "gate_l", function(st)
  setv(st, { a = 1.2, w = 3, e = 3, Sl = 7.9, S = 1 }) end)
ex("P1-2018 P3 Manometro en serie", "mano", function(st)
  setv(st, { n = 3, pA = 0, modo = 0, S1 = 13.6, dz1 = 0.45, S2 = 0.85, dz2 = -0.3, S3 = 1, dz3 = -0.2 }) end)
ex("P1-2018 P4 Placa entre paredes", "visc_plate", function(st)
  setv(st, { mu = 0.0027, A = 0.16, V = 1, Vu = 0, Vl = -0.3, t1 = 1, t2 = 2.6 }) end)
ex("P1-2018 P5 Tanque acelerado", "relative", function(st)
  setv(st, { S = 1, ax = 2.5, az = 0, x0 = 7, z0 = 3, p0 = 100, modo = 0, np = 0,
    tank = 1, tx = 0, tz = 0, tL = 7, tH = 3 }) end)
ex("P1-2022 P1 Bloque rampa aceite", "visc_block", function(st)
  setv(st, { W = 150, th = 20, tipo = 0, A = 0.25, V = 1.2, t = 0.5, mu = 0.015 }) end)
ex("P1-2022 P2 Compuerta circular", "plane", function(st)
  setv(st, { n = 1, cur = 1, S = 1.1 })
  plate(st, 1, 3, 60, 3 - 1.2 * sin(pi / 3), 1, 2.4) end)
ex("P1-2022 P3 Cuarto circ. convexo", "curved", function(st)
  setv(st, { tipo = 0, R = 1.2, h = 2.8, w = 1, side = 0, hinge = 0, dir = 0, S = 1 }) end)
ex("P1-2022 P3 Cuarto circ. concavo", "curved", function(st)
  setv(st, { tipo = 1, R = 1.2, h = 2.8, w = 1, side = 0, hinge = 0, dir = 0, S = 1 }) end)
ex("P1-2022 P4 Barcaza con quilla", "float", function(st)
  setv(st, { shape = 3, mode = 1, S = 1, h = 1.5, b = 2.4, H = 1.2, hk = 0.6, L = 7.5 }) end)
ex("P1-2022 P5 Aceleracion horiz.", "relative", function(st)
  setv(st, { S = 0.9, ax = 4.903, az = 0, x0 = 0, z0 = 1.2, p0 = 0, modo = 0, np = 2,
    x1 = 1.8, z1 = 0, x2 = -0.15, z2 = -0.15, tank = 0 }) end)
ex("P1-2022 P5 a para p(B) = 0", "relative", function(st)
  setv(st, { S = 0.9, ax = 0, az = 0, x0 = 0, z0 = 1.2, p0 = 0, modo = 1, xt = 1.8, zt = 0,
    pt = 0, np = 0, tank = 0 }) end)
ex("P1-2017 P1 Manometro: d", "mano", function(st)
  setv(st, { n = 3, pA = 0, modo = 1, pB = 2.7, k = 1, S1 = 1.4, dz1 = 0, S2 = 13.6, dz2 = 0.02,
    S3 = 0.6, dz3 = -0.06 }) end)
ex("P1-2017 P2 Compuerta plana 45", "plane", function(st)
  setv(st, { n = 1, cur = 1, S = 1, hinge = 1, ssup = 0 }); plate(st, 1, 0, 45, 0.25, 1, 1) end)
ex("P1-2017 P3a Bloque rampa aceite", "visc_block", function(st)
  setv(st, { W = 150, th = 20, tipo = 0, A = 0.25, V = 0.8, t = 0.4, mu = 0.012 }) end)
ex("P1-2017 P3b Bloque rampa seco", "visc_block", function(st)
  setv(st, { W = 150, th = 20, tipo = 1, mus = 0.27 }) end)
ex("P1-2017 P4a Cubo plano", "float", function(st)
  setv(st, { shape = 0, mode = 0, S = 1, rhob = 500, b = 1, H = 1, L = 1 }) end)
ex("P1-2017 P4b Cubo girado 45", "float", function(st)
  setv(st, { shape = 4, mode = 0, S = 1, rhob = 500, b = 1, L = 1 }) end)

function S.example_count() return #EX end
function S.example_name(i) return EX[i] and EX[i].name end
function S.example_kind(i) return EX[i] and EX[i].kind end

function S.example_run(i)
  local e = EX[i]
  if not e then return end
  local st = reset(e.kind)
  e.fn(st)
  S.run_kind(e.kind, true)
end

local ex_cur = 0
local function examples()
  while not U.quit do
    for i = 1, #EX do W.list_line[i - 1] = EX[i].name end
    local r, k = W.list_pick("EJEMPLOS DE EXAMEN", "ENTER carga los datos y calcula", #EX, ex_cur, nil)
    if r < 0 or k ~= K_ENTER then return end
    ex_cur = r
    S.example_run(r + 1)
  end
end
S.examples = examples

-- ================================================================ menus
local function sub_menu(m, fn)
  while not U.quit do
    local r = W.menu_run(m)
    if r == W.MENU_BACK or r == W.MENU_QUIT then return end
    if r == W.MENU_MODE then F.scr_settings() else fn(r) end
  end
end

local m_visc = { title = "VISCOSIDAD (E1)", cur = 0, n = 3, items = {
  "Placa entre dos paredes", "Eje y cojinete", "Bloque en plano inclinado" } }
local m_plan = { title = "SUPERFICIES PLANAS (E3)", cur = 0, n = 2, items = {
  "Placas planas y bisagra", "Compuerta en L (incognita H)" } }
local m_curv = { title = "SUPERFICIES CURVAS (E4)", cur = 0, n = 2, items = {
  "Cuarto de circulo", "Semicilindro con pernos" } }
local m_rel = { title = "EQUILIBRIO RELATIVO (E6)", cur = 0, n = 2, items = {
  "Tanque con aceleracion", "Recipientes en polea" } }
local m_main = { title = "ESTATICA DE FLUIDOS", cur = 0, n = 7, items = {
  "Viscosidad              (E1)", "Manometria              (E2)",
  "Superficies planas      (E3)", "Superficies curvas      (E4)",
  "Flotacion y estabilidad (E5)", "Equilibrio relativo     (E6)",
  "Ejemplos de examen" } }

function S.scr_stat_menu()
  while not U.quit do
    local r = W.menu_run(m_main)
    if r == W.MENU_QUIT or r == W.MENU_BACK then return end
    if r == W.MENU_MODE then F.scr_settings()
    elseif r == 0 then sub_menu(m_visc, function(i) S.run_kind(i + 1, false) end)
    elseif r == 1 then S.run_kind("mano", false)
    elseif r == 2 then sub_menu(m_plan, function(i) S.run_kind(i == 0 and "plane" or "gate_l", false) end)
    elseif r == 3 then sub_menu(m_curv, function(i) S.run_kind(i == 0 and "curved" or "semicyl", false) end)
    elseif r == 4 then S.run_kind("float", false)
    elseif r == 5 then sub_menu(m_rel, function(i) S.run_kind(i == 0 and "relative" or "pulley", false) end)
    else examples() end
  end
end

return S
