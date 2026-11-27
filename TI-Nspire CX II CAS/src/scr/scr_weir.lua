-- scr_weir.lua - Vertedores y orificios (port de scr_weir.c, v2.1).
--   0 Elemento simple: vertedero triangular o rectangular, orificio circular o
--     rectangular; dado H -> Q o dado Q -> H (VE-1, VE-2) y, con el nivel aguas
--     arriba, la cota de la cresta h0 = h - H (VE-5)
--   1 Estructura compuesta: hasta 8 elementos a distintas cotas, con "cantidad x";
--     nivel -> Q por elemento y total, o Q -> nivel (VE-4)
--   2 Perfil de velocidades: v = k y^n o tabla de puntos (VE-6)
--   3 Aguas abajo: v, E, Fr y tirantes alternos por Bernoulli (VE-7)
--   4 Tanques acoplados (VE-8): T-A recibe Qe y descarga a T-B por un orificio
--     sumergido; cada tanque tiene hasta 4 salidas libres (core/weir.weir_tanks).
--     Su memoria de calculo se escribe aqui (ui/memo.lua), no en PERDTXT.
-- Cotas desde una misma referencia: z es el vertice (triangular), la cresta
-- (rectangular) o el CENTRO del orificio. Motor: core/weir.lua.
--
-- Estado: tabla `wi` (valores, banderas s<campo>, elementos wi.e[1..8] y puntos
-- del perfil wi.p[1..9] = {y, v, sy, sv}); Mis casos guarda una copia profunda.
-- Nombres distintos al C: Qd/bd = Q y b de "aguas abajo" (sQ_/sb del C).
--
-- API: scr_weir(t), scr_weir_run(t, autocalc), weir_preset(k) -> tipo,
--      weir_save() -> tabla, weir_load(tabla) -> bool.
local U = require("ui.ui")
local W = require("ui.widgets")
local M = require("ui.memo")
local nf = require("ui.numfmt")
local G = require("ui.gfxcat")
local MR = require("memo_run")
local H = require("core.hydro")
local We = require("core.weir")
local F = require("scr.flu_util")

local S = {}
local WT_SIMPLE, WT_COMP, WT_PROF, WT_DOWN, WT_TANKS, WT_COUNT = 0, 1, 2, 3, 4, 5
local KT_VE8 = 20           -- tipo de Mis casos (scr.cases)
local WE_TRI, WE_RECT, WE_ORC, WE_ORR, WE_COUNT = We.WE_TRI, We.WE_RECT, We.WE_ORC,
  We.WE_ORR, We.WE_COUNT
local NE, NP = We.WEIR_MAX, 9
local FF_POS, FF_NONNEG, FF_CHOICE, FF_INT, FF_OPT, FF_ANY =
  W.FF_POS, W.FF_NONNEG, W.FF_CHOICE, W.FF_INT, W.FF_OPT, W.FF_ANY
local K_F1, K_F2, K_F3, K_F4, K_F5, K_ENTER, K_CLEAR, K_QUIT, K_MODE =
  U.K_F1, U.K_F2, U.K_F3, U.K_F4, U.K_F5, U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE
local C_FG, C_WARN, C_ERR, C_TITLE, C_BG, C_GROUND, C_WATER, C_LE =
  U.C_FG, U.C_WARN, U.C_ERR, U.C_TITLE, U.C_BG, U.C_GROUND, U.C_WATER, U.C_LE
local mfmt = M.mfmt
local floor, sqrt, tan = math.floor, math.sqrt, math.tan
local msetf = MR.msetf

local function nz(x) return x ~= nil and x ~= 0 and x ~= false end

-- ---------------------------------------------------------------- estado
local VALS = { "cd", "d1", "d2", "H", "Q", "hup", "nc", "ne", "h", "b", "ph", "k", "pn", "np",
  "Qd", "bd", "h1", "dz",
  "Qe", "qel", "HAv", "HBv", "wA", "wB", "nA", "nB", "ccd", "cd1", "cd2", "cz" }
local CHOICES = { "etype", "mode", "qunit", "cmode", "pmode", "smode", "init",
  "tmode", "esel", "ctype", "tinit" }
local EVALS = { "n", "d1", "d2", "z", "cd" }

local wi = {}
local function blank()
  for k in pairs(wi) do wi[k] = nil end
  for _, k in ipairs(VALS) do wi[k] = 0; wi["s" .. k] = 0 end
  for _, k in ipairs(CHOICES) do wi[k] = 0 end
  wi.e = {}
  for i = 1, NE do
    local e = { type = 0 }
    for _, k in ipairs(EVALS) do e[k] = 0; e["s" .. k] = 0 end
    wi.e[i] = e
  end
  wi.p = {}
  for i = 1, NP do wi.p[i] = { y = 0, v = 0, sy = 0, sv = 0 } end
end
blank()

local et_names = { "Triangular", "Rectangular", "Orificio circ.", "Orificio rect." }
local md_names = { "Dado H -> Q", "Dado Q -> H" }
local cm_names = { "Nivel h -> Q", "Q -> nivel h" }
local qu_names = { "l/s", "m3/s" }
local pm_names = { "v = k y^n", "Tabla (y, v)" }
local sm_names = { "Solo seccion 1", "h2 por Bernoulli" }
local tm_names = { "Dado Qe", "Dado Q de un elem.", "Dado nivel T-A", "Dado nivel T-B" }
local el_names = { "A1", "A2", "A3", "A4", "B1", "B2", "B3", "B4" }
local ct_names = { "Circular", "Rectangular" }
local d1_lab = { "Angulo theta", "Ancho b", "Diametro d", "Ancho b" }
local d1_unit = { "grad", "m", "m", "m" }

local function FN(lab, un, k, fl) return { label = lab, unit = un, t = wi, k = k, setk = "s" .. k, flags = fl } end
local function FC(lab, k, names, n)
  return { label = lab, t = wi, chk = k, flags = FF_CHOICE, choices = names, nchoices = n }
end
local function FI(lab, un, k, fl, lo, hi)
  return { label = lab, unit = un, t = wi, k = k, setk = "s" .. k, flags = fl, lo = lo, hi = hi }
end

local f_simple = {
  FC("Elemento", "etype", et_names, WE_COUNT),
  FC("Calcular", "mode", md_names, 2),
  FN("Cd", nil, "cd", FF_POS),
  FN("Angulo theta", "grad", "d1", FF_POS),
  FN("Alto a (orif.rect)", "m", "d2", FF_POS + FF_OPT),
  FI("Contracciones 0-2", nil, "nc", FF_INT + FF_OPT, 0, 2),
  FN("Carga H (o Q)", "m", "H", FF_POS + FF_OPT),
  FN("Caudal Q (o H)", nil, "Q", FF_POS + FF_OPT),
  FC("Unidad de Q", "qunit", qu_names, 2),
  FN("Nivel arriba(opc)", "m", "hup", FF_ANY + FF_OPT),
}
local f_prof_pow = {
  FC("Perfil", "pmode", pm_names, 2),
  FN("Ancho b", "m", "b", FF_POS),
  FN("Tirante h", "m", "ph", FF_POS),
  FN("k (v = k y^n)", nil, "k", FF_POS),
  FN("n (v = k y^n)", nil, "pn", FF_NONNEG),
}
local f_down = {
  FC("Calcular", "smode", sm_names, 2),
  FN("Caudal Q", nil, "Qd", FF_POS),
  FC("Unidad de Q", "qunit", qu_names, 2),
  FN("Ancho b", "m", "bd", FF_POS),
  FN("Tirante h1", "m", "h1", FF_POS),
  FN("Escalon dz (opc)", "m", "dz", FF_ANY + FF_OPT),
}

local titles = { "VERTEDERO U ORIFICIO", "ESTRUCTURA COMPUESTA (VE-4)",
  "PERFIL DE VELOCIDADES (VE-6)", "AGUAS ABAJO: ENERGIA (VE-7)",
  "TANQUES ACOPLADOS (VE-8)" }

local tipo = WT_SIMPLE
local fm_now = nil
local ne0, np0, pm0 = 0, 0, 0

-- Estructura: 5 comunes + 6 por elemento (tipo, cantidad, dim 1, dim 2, cota z, Cd)
local function build_comp()
  local sub = { "Tipo", "Cantidad", "theta/b/d", "a (orif.rect)", "Cota z", "Cd (opc)" }
  local unit = { nil, nil, nil, "m", "m", nil }
  local fl = { FF_CHOICE, FF_INT, FF_POS, FF_POS + FF_OPT, FF_ANY, FF_POS + FF_OPT }
  local f = {
    FI("Numero elementos", nil, "ne", FF_INT, 1, NE),
    FC("Calcular", "cmode", cm_names, 2),
    FN("Nivel h (o Q)", "m", "h", FF_ANY + FF_OPT),
    FN("Q total (o h)", qu_names[wi.qunit + 1], "Q", FF_POS + FF_OPT),
    FC("Unidad de Q", "qunit", qu_names, 2),
  }
  local key = { false, "n", "d1", "d2", "z", "cd" }
  for i = 1, floor(wi.ne) do
    local e = wi.e[i]
    for j = 1, 6 do
      local fd = { label = i .. " " .. sub[j], unit = unit[j], flags = fl[j], lo = 1, hi = 20, t = e }
      if j == 1 then
        fd.chk, fd.choices, fd.nchoices = "type", et_names, WE_COUNT
      else
        fd.k, fd.setk = key[j], "s" .. key[j]
      end
      f[#f + 1] = fd
    end
  end
  return f
end

-- Tanques acoplados: segun el modo, la conexion y 6 campos por elemento
-- (A: wi.e[1..4]; B: wi.e[5..8])
local function build_tanks()
  local un = qu_names[wi.qunit + 1]
  local f = { FC("Calcular", "tmode", tm_names, 4) }
  if wi.tmode == 0 then
    f[#f + 1] = FN("Caudal Qe (a T-A)", un, "Qe", FF_POS)
    f[#f + 1] = FC("Unidad de Q", "qunit", qu_names, 2)
  elseif wi.tmode == 1 then
    f[#f + 1] = FC("Elemento dado", "esel", el_names, 8)
    f[#f + 1] = FN("Q del elemento", un, "qel", FF_NONNEG)
    f[#f + 1] = FC("Unidad de Q", "qunit", qu_names, 2)
  elseif wi.tmode == 2 then
    f[#f + 1] = FN("Nivel T-A (o pared)", "m", "HAv", FF_ANY + FF_OPT)
  else
    f[#f + 1] = FN("Nivel T-B (o pared)", "m", "HBv", FF_ANY + FF_OPT)
  end
  f[#f + 1] = FN("Pared T-A (opc)", "m", "wA", FF_ANY + FF_OPT)
  f[#f + 1] = FN("Pared T-B (opc)", "m", "wB", FF_ANY + FF_OPT)
  f[#f + 1] = FC("Orificio conexion", "ctype", ct_names, 2)
  f[#f + 1] = FN("Cd conexion", nil, "ccd", FF_POS)
  f[#f + 1] = FN(wi.ctype == 0 and "Diametro d" or "Ancho b", "m", "cd1", FF_POS)
  f[#f + 1] = FN("Alto a (rect.)", "m", "cd2", FF_POS + FF_OPT)
  f[#f + 1] = FN("Cota z (centro)", "m", "cz", FF_ANY)
  f[#f + 1] = FI("Elementos T-A (0-4)", nil, "nA", FF_INT, 0, 4)
  f[#f + 1] = FI("Elementos T-B (1-4)", nil, "nB", FF_INT, 1, 4)
  local sub = { "Tipo", "Cantidad", "theta/b/d", "a (orif.rect)", "Cota z", "Cd (opc)" }
  local unit = { nil, nil, nil, "m", "m", nil }
  local fl = { FF_CHOICE, FF_INT, FF_POS, FF_POS + FF_OPT, FF_ANY, FF_POS + FF_OPT }
  local key = { false, "n", "d1", "d2", "z", "cd" }
  for tk = 0, 1 do
    local cnt = floor(tk == 0 and wi.nA or wi.nB)
    for i = 1, cnt do
      local e = wi.e[tk * 4 + i]
      for j = 1, 6 do
        local fd = { label = (tk == 0 and "A" or "B") .. i .. " " .. sub[j], unit = unit[j],
                     flags = fl[j], lo = 1, hi = 20, t = e }
        if j == 1 then
          fd.chk, fd.choices, fd.nchoices = "type", et_names, WE_COUNT
        else
          fd.k, fd.setk = key[j], "s" .. key[j]
        end
        f[#f + 1] = fd
      end
    end
  end
  return f
end

-- Perfil por puntos: comunes + (y, v) por punto
local function build_pts()
  local f = {
    FC("Perfil", "pmode", pm_names, 2),
    FN("Ancho b", "m", "b", FF_POS),
    FI("Numero de puntos", nil, "np", FF_INT, 2, NP),
  }
  for i = 1, floor(wi.np) do
    local p = wi.p[i]
    f[#f + 1] = { label = i .. " y (desde fondo)", unit = "m", t = p, k = "y", setk = "sy",
                  flags = FF_NONNEG }
    f[#f + 1] = { label = i .. " v", unit = "m/s", t = p, k = "v", setk = "sv", flags = FF_NONNEG }
  end
  return f
end

local function set_form(fm)
  if tipo == WT_SIMPLE then fm.f = f_simple
  elseif tipo == WT_COMP then fm.f = build_comp()
  elseif tipo == WT_TANKS then fm.f = build_tanks()
  elseif tipo == WT_PROF then
    fm.f = (wi.pmode ~= 0) and build_pts() or f_prof_pow
  else fm.f = f_down end
  fm.n = #fm.f
  if fm.cur >= fm.n then fm.cur = 0 end
end

-- Etiqueta de la dimension segun el elemento; rehacer los formularios con
-- numero variable de campos
local function on_commit()
  f_simple[4].label = d1_lab[wi.etype + 1]
  f_simple[4].unit = d1_unit[wi.etype + 1]
  f_simple[8].unit = qu_names[wi.qunit + 1]
  f_down[2].unit = qu_names[wi.qunit + 1]
  if tipo == WT_COMP and fm_now and fm_now.f[4] then fm_now.f[4].unit = qu_names[wi.qunit + 1] end
  if tipo == WT_TANKS and fm_now then set_form(fm_now) end
  if fm_now and ((tipo == WT_COMP and wi.ne ~= ne0) or
      (tipo == WT_PROF and (wi.pmode ~= pm0 or wi.np ~= np0))) then
    ne0, np0, pm0 = wi.ne, wi.np, wi.pmode
    set_form(fm_now)
  end
end

-- ------------------------------------------------------------------ calculo
local EL = {}
local QI, HI = {}, {}
local C = {}

local function qsi(q) return (wi.qunit ~= 0) and q or q / 1000 end    -- a m3/s

local function flag_w(w)
  msetf(MR.G_WFRAN, H.warn_has(w, We.VW_FRANCIS))
  msetf(MR.G_WPART, H.warn_has(w, We.VW_PARTIAL))
  msetf(MR.G_WHIGH, H.warn_has(w, We.VW_HIGH))
  msetf(MR.G_WDRY, H.warn_has(w, We.VW_DRY))
end

-- Coeficiente de Q = K H^p (con Francis: ancho efectivo b - 0,1 n H)
local function coefK(e, Hh)
  local s = sqrt(2 * C.g) * e.Cd
  if e.type == WE_TRI then return s * (8.0 / 15.0) * tan(e.a * 0.00872664626)
  elseif e.type == WE_RECT then return s * (2.0 / 3.0) * (e.a - 0.1 * e.ncon * Hh)
  elseif e.type == WE_ORC then return s * H.hydro_area(e.a) end
  return s * e.a * e.b
end

-- v2.1: en la memoria (comp_full) cada elemento va paso a paso
local comp_full = false
local function comp_hook()
  local V = MR.V
  for i = 1, floor(wi.ne) do
    local e = EL[i]
    M.memo_line(mfmt("%d %s x%d: z=%w Cd=%w", i, et_names[e.type + 1], e.count, e.z, e.Cd), C_FG)
    if not (HI[i] > 0) then
      M.memo_line("   h <= z: no recibe agua, Q = 0", U.C_GRAY)
    elseif not comp_full then
      M.memo_line(mfmt("   H=h-z=%w m  Q=%w m3/s", HI[i], QI[i]), U.C_OK)
    else
      M.memo_line(mfmt(" H = h - z = %v - %v = %v m", V[MR.V_WLEV], e.z, HI[i]), C_FG)
      if e.type == WE_RECT then
        M.memo_line(" Q = n Cd (2/3) sqrt(2g) b H^1.5", C_FG)
        M.memo_line(mfmt("   = %d(%v)(2/3)sqrt(2(%v))(%v)(%v)^1.5", e.count, e.Cd, C.g, e.a, HI[i]),
          U.C_GRAY)
      elseif e.type == WE_TRI then
        M.memo_line(" Q = n Cd (8/15) sqrt(2g) tan(t/2) H^2.5", C_FG)
        M.memo_line(mfmt("   = %d(%v)(8/15)sqrt(2(%v))tan(%v/2)(%v)^2.5", e.count, e.Cd, C.g, e.a,
          HI[i]), U.C_GRAY)
      else
        if e.type == WE_ORC then
          M.memo_line(mfmt(" A = pi d^2/4 = pi(%v)^2/4 = %v m2", e.a, H.hydro_area(e.a)), C_FG)
        else
          M.memo_line(mfmt(" A = b a = %v(%v) = %v m2", e.a, e.b, e.a * e.b), C_FG)
        end
        M.memo_line(" Q = n Cd A sqrt(2 g H)  (H al centro)", C_FG)
        M.memo_line(mfmt("   = %d(%v)(%v)sqrt(2(%v)(%v))", e.count, e.Cd,
          e.type == WE_ORC and H.hydro_area(e.a) or e.a * e.b, C.g, HI[i]), U.C_GRAY)
      end
      M.memo_line(mfmt("   Q%d = %v m3/s", i, QI[i]), U.C_OK)
    end
  end
  if comp_full then
    local b = " Q = "
    for i = 1, floor(wi.ne) do
      b = b .. (i > 1 and " + " or "") .. nf.fmt_real(QI[i], U.g_set.dec or 6)
    end
    M.memo_line(b:sub(1, 80), C_FG)
  end
end

-- ------------------------------------------------ VE-8: tanques acoplados
local TK = nil            -- ultimo calculo: {t = entradas del motor, r = resultados, g}

local function tk_name(tk, i) return (tk == 0 and "A" or "B") .. i end

-- Devuelve nil si va bien o el texto del error
local function compute_tanks()
  local C = F.cfg_copy()
  local t = { a = {}, b = {}, na = floor(wi.nA), nb = floor(wi.nB), mode = wi.tmode }
  for tk = 0, 1 do
    local cnt = (tk == 0) and t.na or t.nb
    for i = 1, cnt do
      local e = wi.e[tk * 4 + i]
      local nm = tk_name(tk, i)
      if not nz(e.sn) or not nz(e.sd1) or not nz(e.sz) then return "Faltan datos de " .. nm end
      if e.type == WE_ORR and not nz(e.sd2) then return "Falta el alto a de " .. nm end
      local el = { type = e.type, count = floor(e.n), ncon = 0,
        Cd = nz(e.scd) and e.cd or F.gset().cd_weir, z = e.z, a = e.d1,
        b = (e.type == WE_ORR) and e.d2 or 0 }
      if tk == 0 then t.a[i] = el else t.b[i] = el end
    end
  end
  if t.nb < 1 then return "T-B necesita al menos 1 salida" end
  if wi.ctype ~= 0 and not nz(wi.scd2) then return "Falta el alto a del orificio" end
  t.con = { type = (wi.ctype == 0) and WE_ORC or WE_ORR, Cd = wi.ccd, a = wi.cd1,
            b = (wi.ctype ~= 0) and wi.cd2 or 0, z = wi.cz }
  if nz(wi.swA) then t.wA = wi.wA end
  if nz(wi.swB) then t.wB = wi.wB end
  if wi.tmode == 0 then
    t.Qe = qsi(wi.Qe)
  elseif wi.tmode == 1 then
    t.tank = (wi.esel >= 4) and 1 or 0
    t.idx = floor(wi.esel) % 4 + 1
    if t.idx > ((t.tank == 0) and t.na or t.nb) then return "Ese elemento no existe" end
    t.q = qsi(wi.qel)
  elseif wi.tmode == 2 then
    if nz(wi.sHAv) then t.HA = wi.HAv
    elseif t.wA then t.HA = t.wA
    else return "Falta el nivel de T-A (o su pared)" end
  else
    if nz(wi.sHBv) then t.HB = wi.HBv
    elseif t.wB then t.HB = t.wB
    else return "Falta el nivel de T-B (o su pared)" end
  end
  local r, lg = {}, { n = 0, total = 0, r = {} }
  local err = We.weir_tanks(t, C.g, r, lg)
  if err ~= 0 then
    if err == H.H_ERR_ARG then return "Datos invalidos (Cd, dimensiones)" end
    return H.hydro_err_text(err)
  end
  TK = { t = t, r = r, g = C.g, lg = lg }
  return nil
end

local function dim_txt(e)
  if e.type == WE_TRI then return mfmt("theta=%v", e.a)
  elseif e.type == WE_RECT then return mfmt("b=%v", e.a)
  elseif e.type == WE_ORC then return mfmt("d=%v", e.a) end
  return mfmt("%v x %v", e.a, e.b)
end

-- Caudal de un elemento con formula y sustitucion
local function tk_elem(nm, e, lev, lname, q, g)
  M.memo_line(mfmt("%s %s x%d %s z=%w Cd=%w", nm, et_names[e.type + 1], e.count,
    dim_txt(e), e.z, e.Cd), C_FG)
  local hc = lev - e.z
  if not (hc > 0) then
    M.memo_line("   h <= z: no recibe agua, Q = 0", U.C_GRAY)
    return
  end
  M.memo_line(mfmt(" H = %s - z = %w - %w = %w m", lname, lev, e.z, hc), C_FG)
  local lhs = "Q" .. nm
  if e.type == WE_RECT then
    M.memo_eq(lhs, "n Cd (2/3) sqrt(2g) b H^1.5",
      mfmt("%d(%w)(2/3)sqrt(2(%w))(%w)(%w)^1.5", e.count, e.Cd, g, e.a, hc), q, "m3/s")
  elseif e.type == WE_TRI then
    M.memo_eq(lhs, "n Cd 8/15 sqrt(2g) tan(t/2) H^2.5",
      mfmt("%d(%w)(8/15)sqrt(2(%w))tan(%w/2)(%w)^2.5", e.count, e.Cd, g, e.a, hc), q, "m3/s")
  else
    local A
    if e.type == WE_ORC then
      A = H.hydro_area(e.a)
      M.memo_line(mfmt(" A = pi(%w)^2/4 = %w m2", e.a, A), C_FG)
    else
      A = e.a * e.b
      M.memo_line(mfmt(" A = b a = %w(%w) = %w m2", e.a, e.b, A), C_FG)
    end
    M.memo_eq(lhs, "n Cd A sqrt(2 g H)",
      mfmt("%d(%w)(%w)sqrt(2(%w)(%w))", e.count, e.Cd, A, g, hc), q, "m3/s")
  end
  M.memo_line(mfmt("      = %v l/s", q * 1000), U.C_GRAY)
end

local function tk_warns()
  local r, t = TK.r, TK.t
  local out = {}
  local w = r.warn
  if H.warn_has(w, We.VW_UNSUB) then out[#out + 1] = "! Orificio no sumergido: HB < z + a/2" end
  if H.warn_has(w, We.VW_OVA) then
    out[#out + 1] = mfmt("! T-A rebalsa: HA = %w > pared %w", r.HA, t.wA)
  end
  if H.warn_has(w, We.VW_OVB) then
    out[#out + 1] = mfmt("! T-B rebalsa: HB = %w > pared %w", r.HB, t.wB)
  end
  if H.warn_has(w, We.VW_PARTIAL) then out[#out + 1] = "! Orificio parcial: H < mitad de altura" end
  if H.warn_has(w, We.VW_HIGH) then out[#out + 1] = "! H mayor que el limite del vertedero" end
  return out
end

local function tk_results()
  local r = TK.r
  M.memo_res("HB (nivel T-B)", r.HB, "m")
  M.memo_res("HA (nivel T-A)", r.HA, "m")
  M.memo_res("dh del orificio", r.dh, "m")
  M.memo_res("Qe (entra a T-A)", r.Qe * 1000, "l/s")
  M.memo_res("Q conexion A->B", r.Qcon * 1000, "l/s")
  M.memo_res("Suma salidas T-A", r.sumA * 1000, "l/s")
  M.memo_res("Suma salidas T-B", r.sumB * 1000, "l/s")
end

local function tanks_sum()
  local r, t = TK.r, TK.t
  M.memo_begin("VE-8 TANQUES ACOPLADOS")
  M.memo_sec("RESULTADOS")
  tk_results()
  for tk = 0, 1 do
    local cnt = (tk == 0) and t.na or t.nb
    if cnt > 0 then
      M.memo_sec(tk == 0 and "SALIDAS DE T-A" or "SALIDAS DE T-B")
      for i = 1, cnt do
        local e = (tk == 0 and t.a or t.b)[i]
        local q = (tk == 0 and r.QA or r.QB)[i]
        M.memo_line(mfmt("%s %s: Q = %v l/s", tk_name(tk, i), et_names[e.type + 1], q * 1000),
          q > 0 and U.C_OK or U.C_GRAY)
      end
    end
  end
  M.memo_sec("ADVERTENCIAS")
  local ws = tk_warns()
  if #ws == 0 then W.view_add(" Sin advertencias", U.C_OK) end
  for i = 1, #ws do M.memo_line(ws[i], C_WARN) end
end

local function tanks_memo()
  local r, t, g, c = TK.r, TK.t, TK.g, TK.t.con
  M.memo_begin("MEMORIA: TANQUES ACOPLADOS")
  M.memo_sec("DATOS")
  M.memo_data("g", g, "m/s2")
  if t.mode == 0 then M.memo_line(mfmt("Dado Qe = %v l/s; incognita HB", t.Qe * 1000), C_FG)
  elseif t.mode == 1 then
    M.memo_line(mfmt("Dado Q de %s = %v l/s", tk_name(t.tank, t.idx), t.q * 1000), C_FG)
  elseif t.mode == 2 then M.memo_line(mfmt("Dado nivel de T-A: HA = %v m", t.HA), C_FG)
  else M.memo_line(mfmt("Dado nivel de T-B: HB = %v m", t.HB), C_FG) end
  M.memo_line(mfmt("Orif. A->B %s %s z=%w Cd=%w",
    c.type == WE_ORC and "circ." or "rect.", dim_txt(c), c.z, c.Cd), C_FG)
  if t.wA then M.memo_data("Pared T-A", t.wA, "m") end
  if t.wB then M.memo_data("Pared T-B", t.wB, "m") end
  for tk = 0, 1 do
    local cnt = (tk == 0) and t.na or t.nb
    for i = 1, cnt do
      local e = (tk == 0 and t.a or t.b)[i]
      M.memo_line(mfmt("%s %s x%d %s z=%w Cd=%w", tk_name(tk, i), et_names[e.type + 1],
        e.count, dim_txt(e), e.z, e.Cd), C_FG)
    end
  end
  M.memo_sec("METODO")
  M.memo_line("Para un HB dado, hacia aguas arriba:", C_FG)
  M.memo_line(" Qcon = suma QB(HB)", C_FG)
  M.memo_line(" dh = (Qcon/(Cd A))^2/(2g); HA = HB+dh", C_FG)
  M.memo_line(" Qe = Qcon + suma QA(HA)", C_FG)
  if t.mode == 0 then M.memo_line("HB por biseccion hasta Qe(HB) = Qe", C_FG)
  elseif t.mode == 2 then M.memo_line("HB por biseccion hasta HA(HB) = HA", C_FG)
  elseif t.mode == 1 then M.memo_line("El Q dado fija el nivel de su tanque", C_FG) end
  M.memo_sec("1. SALIDAS DE T-B")
  M.memo_data("HB", r.HB, "m")
  for i = 1, t.nb do tk_elem(tk_name(1, i), t.b[i], r.HB, "HB", r.QB[i], g) end
  M.memo_eq("Qcon", "suma QB", nil, r.Qcon, "m3/s")
  M.memo_line(mfmt("      = %v l/s", r.Qcon * 1000), U.C_GRAY)
  M.memo_sec("2. ORIFICIO DE CONEXION")
  if c.type == WE_ORC then
    M.memo_eq("A", "pi d^2/4", mfmt("pi(%w)^2/4", c.a), r.Acon, "m2")
  else
    M.memo_eq("A", "b a", mfmt("%w(%w)", c.a, c.b), r.Acon, "m2")
  end
  M.memo_eq("dh", "(Qcon/(Cd A))^2/(2g)",
    mfmt("(%w/(%w(%w)))^2/(2(%w))", r.Qcon, c.Cd, r.Acon, g), r.dh, "m")
  M.memo_eq("HA", "HB + dh", mfmt("%w + %w", r.HB, r.dh), r.HA, "m")
  if t.na > 0 then
    M.memo_sec("3. SALIDAS DE T-A")
    M.memo_data("HA", r.HA, "m")
    for i = 1, t.na do tk_elem(tk_name(0, i), t.a[i], r.HA, "HA", r.QA[i], g) end
    M.memo_eq("sumQA", "suma QA", nil, r.sumA, "m3/s")
  end
  M.memo_sec("4. BALANCE")
  M.memo_eq("Qe", "Qcon + suma QA", mfmt("%w + %w", r.Qcon, r.sumA), r.Qe, "m3/s")
  M.memo_line(mfmt("      = %v l/s", r.Qe * 1000), U.C_GRAY)
  if r.iters > 0 and TK.lg.n > 0 then
    M.memo_sec("5. BISECCION DE HB (" .. nf.fmt_int(r.iters) .. " vueltas)")
    local lg, sub = TK.lg, { n = 0, total = TK.lg.total, r = {} }
    for i = 1, lg.n do
      if i <= 6 or i > lg.n - 6 then
        sub.n = sub.n + 1
        sub.r[sub.n] = lg.r[i]
      end
    end
    if lg.total <= sub.n then sub.total = sub.n end
    M.memo_table({ "i", "HB min", "HB max", "HB", t.mode == 0 and "dQ l/s" or "dHA m" }, 5, sub,
      { 1, 1, 1, 1, t.mode == 0 and 1000 or 1 })
  end
  M.memo_sec("RESULTADOS")
  tk_results()
  local ws = tk_warns()
  for i = 1, #ws do M.memo_line(ws[i], C_WARN) end
end

-- Devuelve nil si va bien o el texto del error
local function compute()
  local g = F.gset()
  if tipo == WT_TANKS then return compute_tanks() end
  MR.memo_reset()
  local V = MR.V
  C = F.cfg_copy()
  MR.cfg = C
  MR.hook = nil
  MR.lg = { n = 0, total = 0, r = {} }       -- v2.1: biseccion del nivel
  MR.log = MR.lg
  V[MR.V_G] = C.g
  local Q, h, Hh, w, err, it = 0, 0, 0, 0, 0, 0
  if tipo == WT_SIMPLE then
    local ncon = (wi.etype == WE_RECT and nz(wi.snc)) and floor(wi.nc) or 0
    EL = { { type = wi.etype, count = 1, Cd = wi.cd, a = wi.d1, z = 0, ncon = ncon,
             b = (wi.etype == WE_ORR) and (nz(wi.sd2) and wi.d2 or 0) or 0 } }
    if wi.etype == WE_ORR and not nz(wi.sd2) then return "Falta el alto a del orificio" end
    if wi.mode == 0 then
      if not nz(wi.sH) then return "Falta la carga H" end
      err, Q, QI, w = We.weir_total(EL, 1, wi.H, C.g, 0)
      Hh = wi.H
      if err ~= 0 then return H.hydro_err_text(err) end
    else
      if not nz(wi.sQ) then return "Falta el caudal Q" end
      Q = qsi(wi.Q)
      err, Hh, QI, w, it = We.weir_level(EL, 1, Q, C.g, 0, MR.lg)
      if err ~= 0 then return H.hydro_err_text(err) end
      msetf(MR.G_WH0, nz(wi.shup))
      V[MR.V_WLEV] = wi.hup
      V[MR.V_WH0] = wi.hup - Hh
    end
    V[MR.V_WH] = Hh
    V[MR.V_WK] = coefK(EL[1], Hh)
    V[MR.V_WBE] = EL[1].a - 0.1 * EL[1].ncon * Hh
    V[MR.V_WNC] = EL[1].ncon
  elseif tipo == WT_COMP then
    EL = {}
    local ne = floor(wi.ne)
    for i = 1, ne do
      local e = wi.e[i]
      if not nz(e.sn) or not nz(e.sd1) or not nz(e.sz) then return "Faltan datos de un elemento" end
      if e.type == WE_ORR and not nz(e.sd2) then return "Falta el alto a de un orificio" end
      EL[i] = { type = e.type, count = floor(e.n), ncon = 0, Cd = nz(e.scd) and e.cd or g.cd_weir,
                z = e.z, a = e.d1, b = (e.type == WE_ORR) and e.d2 or 0 }
    end
    if wi.cmode == 0 then
      if not nz(wi.sh) then return "Falta el nivel h" end
      h = wi.h
      err, Q, QI, w = We.weir_total(EL, ne, h, C.g, 0)
    else
      if not nz(wi.sQ) then return "Falta el caudal Q" end
      Q = qsi(wi.Q)
      err, h, QI, w, it = We.weir_level(EL, ne, Q, C.g, 0, MR.lg)
    end
    if err ~= 0 then return H.hydro_err_text(err) end
    HI = {}
    for i = 1, ne do HI[i] = h - EL[i].z end
    V[MR.V_WLEV] = h
    MR.hook = comp_hook
  elseif tipo == WT_PROF then
    local vm, simp = 0, 0
    V[MR.V_PRB] = wi.b
    if wi.pmode == 0 then
      err, Q, vm = We.weir_profile_pow(wi.k, wi.pn, wi.b, wi.ph)
      V[MR.V_PRK] = wi.k
      V[MR.V_PRN] = wi.pn
      V[MR.V_PRH] = wi.ph
    else
      local np = floor(wi.np)
      local y, v = {}, {}
      for i = 1, np do y[i], v[i] = wi.p[i].y, wi.p[i].v end
      err, Q, vm, simp = We.weir_profile_pts(y, v, np, wi.b)
      msetf(MR.G_WPTS, true)
      msetf(MR.G_WSIMP, nz(simp))
      V[MR.V_PRNP] = wi.np
      V[MR.V_PRH] = y[np] - y[1]
    end
    if err ~= 0 then return "Datos invalidos (y debe crecer)" end
    V[MR.V_PRVM] = vm
    V[MR.V_PRQ] = Q
    V[MR.V_WQLS] = Q * 1000
    return nil
  else
    Q = qsi(wi.Qd)
    local e1, v1, E1 = We.weir_section(Q, wi.bd, wi.h1, C.g)
    if e1 ~= 0 then return H.hydro_err_text(e1) end
    local q = Q / wi.bd
    V[MR.V_SQ] = Q
    V[MR.V_SB] = wi.bd
    V[MR.V_SH1] = wi.h1
    V[MR.V_SV1] = v1
    V[MR.V_SE1] = E1
    V[MR.V_SQQ] = q
    V[MR.V_SFR1] = v1 / sqrt(C.g * wi.h1)
    if wi.smode ~= 0 then
      V[MR.V_SDZ] = nz(wi.sdz) and wi.dz or 0
      V[MR.V_SE2] = E1 - V[MR.V_SDZ]
      msetf(MR.G_SBER, true)
      local e2, hs, hp, hc = We.weir_alt_depths(q, V[MR.V_SE2], C.g)
      if e2 ~= 0 then
        msetf(MR.G_SNOE, true)
        V[MR.V_SHC] = (q * q / C.g) ^ (1.0 / 3.0)
        V[MR.V_SHS], V[MR.V_SHP] = 0, 0
      else
        V[MR.V_SHS], V[MR.V_SHP], V[MR.V_SHC] = hs, hp, hc
        V[MR.V_SVS] = q / hs
        V[MR.V_SVP] = q / hp
      end
      V[MR.V_WG2] = 1.5 * V[MR.V_SHC]
    end
    return nil
  end
  local e1 = EL[1]
  V[MR.V_WQ] = Q
  V[MR.V_WQLS] = Q * 1000
  V[MR.V_WCD] = e1.Cd
  V[MR.V_WD1] = e1.a
  V[MR.V_WD2] = e1.b
  V[MR.V_WAREA] = e1.type == WE_ORC and H.hydro_area(e1.a) or e1.a * e1.b
  V[MR.V_WT2] = tan(e1.a * 0.00872664626)
  V[MR.V_WIT] = it
  msetf(MR.G_WTRI, e1.type == WE_TRI)
  msetf(MR.G_WRECT, e1.type == WE_RECT)
  msetf(MR.G_WORC, e1.type == WE_ORC)
  msetf(MR.G_WORR, e1.type == WE_ORR)
  msetf(MR.G_WINV, (tipo == WT_SIMPLE) and wi.mode ~= 0 or (tipo ~= WT_SIMPLE and wi.cmode ~= 0))
  flag_w(w)
  MR.txt = et_names[e1.type + 1]
  return nil
end

-- --------------------- esquema de la estructura compuesta: pared, elementos y nivel
local function sketch()
  local fk = { "", "", "", "", "VOLVER" }
  local V = MR.V
  local ne = floor(wi.ne)
  local top, zmin = V[MR.V_WLEV], 0
  for i = 1, ne do
    if EL[i].z < zmin then zmin = EL[i].z end
    if EL[i].z + 0.1 > top then top = EL[i].z + 0.1 end
  end
  top = top * 1.15
  if not (top - zmin > 0) then return end
  while true do
    if U.quit then return end
    local BW, BH = U.ui_body_w(), U.ui_body_h()
    local ybase, ytop = BH - 18, 8
    local sc = (ybase - ytop - 4) / (top - zmin)
    U.ui_begin("ESQUEMA DE LA ESTRUCTURA", nil)
    G.gfxcat_rect(20, ytop, BW - 40, ybase - ytop + 1, C_GROUND)               -- pared
    local y0 = floor(ybase - (V[MR.V_WLEV] - zmin) * sc)
    if y0 < 0 then y0 = 0 end
    G.gfxcat_rect(4, y0, 16, ybase - y0, C_WATER)                              -- agua
    for i = 1, ne do
      local x = 34 + (i - 1) * 34
      local e = EL[i]
      local y1 = floor(ybase - (e.z - zmin) * sc)
      if e.type >= WE_ORC then                      -- orificio: cuadro centrado
        local d = floor((e.type == WE_ORC and e.a or e.b) * sc) + 2
        G.gfxcat_rect(x, y1 - floor(d / 2), 14, d, C_BG)
      else                                          -- vertedero: hasta arriba
        G.gfxcat_rect(x, ytop, 14, y1 - ytop, C_BG)
        G.gfxcat_rect(x, y1, 14, 2, C_FG)
      end
      local ty = y1 + 4
      if ty > ybase - 10 then ty = ybase - 10 end
      U.ui_px_text(x + 2, ty, tostring(i), C_TITLE)
    end
    G.gfxcat_rect(4, y0, BW - 22, 1, C_LE)                                     -- nivel
    U.ui_text(U.ui_rows(), 0, mfmt("h = %w m   Q = %w m3/s", V[MR.V_WLEV], V[MR.V_WQ]),
      C_TITLE, C_BG)
    U.ui_fbar(fk)
    U.ui_end()
    local k = U.ui_getkey()
    if not (k.k == U.K_NONE or k.k == U.K_ALPHA or k.k == U.K_CLICK) then return end
  end
end

local function result_loop()
  local fk_sum = { "MEMORIA", tipo == WT_COMP and "ESQUEMA" or "", "GUARDAR", "", "VOLVER" }
  local fk_memo = { "RESUMEN", "", "", "", "VOLVER" }
  local memo = false
  while true do
    comp_full = memo
    if tipo == WT_TANKS then
      if memo then tanks_memo() else tanks_sum() end
    else
      MR.memo_show(MR.PROG_X(MR.XP_VE1_SUM + 2 * tipo + (memo and 1 or 0)))
    end
    local k = W.view_run(titles[tipo + 1], memo and fk_memo or fk_sum)
    if k == K_F1 then memo = not memo
    elseif k == K_F3 and not memo then
      F.case_save_ui(tipo == WT_TANKS and KT_VE8 or MR.KT_WEIR + tipo)
    elseif k == K_F2 and tipo == WT_COMP then sketch()
    elseif k == K_MODE then F.scr_settings()
    else return end
    if U.quit then return end
  end
end

local cur_of = {}

function S.scr_weir_run(t, autocalc)
  if t < 0 or t >= WT_COUNT then return end
  tipo = t
  if not nz(wi.init) then
    wi.init = 1
    wi.cd = F.gset().cd_weir
    wi.scd = 1
    wi.ne, wi.np = 2, 5
    wi.sne, wi.snp = 1, 1
    for i = 1, NE do wi.e[i].n = 1; wi.e[i].sn = 1 end
  end
  if t == WT_TANKS and not nz(wi.tinit) then      -- valores iniciales de VE-8
    wi.tinit = 1
    wi.nA, wi.snA, wi.nB, wi.snB = 1, 1, 1, 1
    wi.ccd, wi.sccd = F.gset().cd_weir, 1
    wi.cz, wi.scz = 0, 1
    for i = 1, NE do if not nz(wi.e[i].sn) then wi.e[i].n = 1; wi.e[i].sn = 1 end end
  end
  local fm = { title = titles[t + 1], cur = cur_of[t] or 0, top = 0, n = 0 }
  on_commit()
  set_form(fm)
  fm.fk = { "", "", "", "AJUSTES", "CALC" }
  fm.on_commit = on_commit
  fm.hint = t == WT_SIMPLE and "Orificio: H al centro; z desde una ref."
    or t == WT_COMP and "Cotas z: vertice, cresta o centro"
    or t == WT_PROF and "Perfil: elija la forma con izq/der"
    or t == WT_TANKS and "T-A recibe Qe; orificio sumergido"
    or "Bernoulli: E2 = E1 - dz"
  while true do
    fm_now = fm
    local k
    if autocalc then
      autocalc = false
      k = K_F5
    else
      k = W.form_run(fm)
    end
    fm_now = nil
    if k == K_QUIT or k == K_CLEAR then break end
    if k == K_F4 or k == K_MODE then
      F.scr_settings()
    elseif k == K_F5 or k == K_ENTER then
      if W.form_check(fm) then
        local err = compute()
        if err then
          fm.msg = err
          fm.msg_color = C_ERR
        else
          result_loop()
          if U.quit then break end
        end
      end
    end
  end
  cur_of[t] = fm.cur
end

function S.scr_weir(t) S.scr_weir_run(t, false) end

-- ----------------------------------------------------------- Mis casos
function S.weir_save() return F.deep_copy(wi) end

local function clamp01(v) return (v == 1) and 1 or 0 end

function S.weir_load(t)
  if type(t) ~= "table" or type(t.e) ~= "table" then return false end
  blank()
  for k, v in pairs(t) do
    if k ~= "e" and k ~= "p" and type(v) == "number" then wi[k] = v end
  end
  for i = 1, NE do
    if type(t.e[i]) == "table" then
      for k, v in pairs(t.e[i]) do if type(v) == "number" then wi.e[i][k] = v end end
    end
  end
  if type(t.p) == "table" then
    for i = 1, NP do
      if type(t.p[i]) == "table" then
        for k, v in pairs(t.p[i]) do if type(v) == "number" then wi.p[i][k] = v end end
      end
    end
  end
  if wi.etype >= WE_COUNT or wi.etype < 0 then wi.etype = 0 end
  wi.mode, wi.qunit, wi.cmode = clamp01(wi.mode), clamp01(wi.qunit), clamp01(wi.cmode)
  wi.pmode, wi.smode = clamp01(wi.pmode), clamp01(wi.smode)
  if wi.tmode < 0 or wi.tmode > 3 then wi.tmode = 0 end
  if wi.esel < 0 or wi.esel > 7 then wi.esel = 0 end
  wi.ctype = clamp01(wi.ctype)
  if not (wi.nA >= 0 and wi.nA <= 4) then wi.nA = 1 end
  if not (wi.nB >= 1 and wi.nB <= 4) then wi.nB = 1 end
  if not (wi.ne >= 1 and wi.ne <= NE) then wi.ne = 2 end
  if not (wi.np >= 2 and wi.np <= NP) then wi.np = 5 end
  for i = 1, NE do
    if wi.e[i].type >= WE_COUNT or wi.e[i].type < 0 then wi.e[i].type = 0 end
  end
  wi.init = 1
  return true
end

-- ---- Casos del curso VE-01..VE-08. Devuelve el tipo
local function SW(k, x) wi[k] = x; wi["s" .. k] = 1 end
local function el(i, type, n, d1, z)
  local e = wi.e[i]
  e.type, e.n, e.d1, e.z = type, n, d1, z
  e.sn, e.sd1, e.sz = 1, 1, 1
end

-- VE-09..VE-12 (k = 8..11): dos tanques acoplados (Vertedores P4 y Parcial 2-2025 P3)
local function tel(i, type, n, d1, z)
  el(i, type, n, d1, z)
end

local function tanks_preset(k)
  blank()
  wi.init, wi.tinit = 1, 1
  SW("cd", F.gset().cd_weir)
  SW("ne", 2)
  SW("np", 5)
  for i = 1, NE do wi.e[i].n = 1; wi.e[i].sn = 1 end
  SW("ccd", F.gset().cd_weir)
  if k <= 1 then                                 -- Vertedores P4: orificio + vert. rect.
    SW("nA", 0); SW("nB", 1)
    tel(5, WE_RECT, 1, 1.5, 2)
    SW("cd1", 0.35); SW("cz", 0.5)
    if k == 0 then SW("Qe", 250)
    else wi.tmode = 2; SW("wA", 3.5) end         -- nivel de T-A = pared (rebalse)
  else                                           -- Parcial 2-2025 P3
    SW("nA", 1); SW("nB", 3)
    tel(1, WE_RECT, 1, 1.0, 1.1)
    tel(5, WE_ORC, 1, 0.2, 0.1)
    tel(6, WE_RECT, 1, 0.6, 1.0)
    tel(7, WE_TRI, 1, 90, 1.059)
    wi.ctype = 1
    SW("cd1", 0.2); SW("cd2", 0.5); SW("cz", 0.5)
    wi.tmode = 1; wi.esel = 6                    -- elemento B3 (vertedero triangular)
    SW("qel", k == 2 and 0 or 50)
  end
  return WT_TANKS
end

function S.weir_preset(k)
  if k >= 8 then return tanks_preset(k - 8) end
  local tipo_of = { [0] = WT_COMP, WT_COMP, WT_SIMPLE, WT_SIMPLE, WT_SIMPLE, WT_COMP, WT_PROF,
                    WT_SIMPLE }
  blank()
  wi.init = 1
  SW("cd", F.gset().cd_weir)
  SW("ne", 2)
  SW("np", 5)
  if k == 0 or k == 1 then                       -- examen 2024 P5
    el(1, WE_TRI, 1, 90, 1.4)
    el(2, WE_ORC, 3, 0.2, 0.1)
    if k == 0 then SW("h", 2)
    else wi.cmode = 1; wi.qunit = 1; SW("Q", 0.5) end
  elseif k == 2 or k == 3 or k == 4 or k == 7 then   -- triangular simple
    wi.etype = WE_TRI; wi.mode = 1
    SW("d1", k == 4 and 60 or 90)
    SW("Q", k == 2 and 200 or k == 3 and 260.64 or k == 4 and 16 or 1.3333333)
    if k == 7 then wi.qunit = 1; SW("hup", 1) end
  elseif k == 5 then                             -- T4-2 P2b: reparto
    wi.cmode = 1; SW("Q", 36)
    el(1, WE_TRI, 1, 60, 0)
    el(2, WE_RECT, 1, 1.3, 0.20724)
  else                                           -- T4-2 P3a: perfil
    wi.b = 2; wi.sb = 1
    wi.ph = 1; wi.sph = 1
    SW("k", 2)
    wi.pn = 2; wi.spn = 1
  end
  return tipo_of[k < 8 and k or 7]
end

return S
