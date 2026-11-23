-- scr_weir.lua - Vertedores y orificios (port de scr_weir.c, v2.1).
--   0 Elemento simple: vertedero triangular o rectangular, orificio circular o
--     rectangular; dado H -> Q o dado Q -> H (VE-1, VE-2) y, con el nivel aguas
--     arriba, la cota de la cresta h0 = h - H (VE-5)
--   1 Estructura compuesta: hasta 8 elementos a distintas cotas, con "cantidad x";
--     nivel -> Q por elemento y total, o Q -> nivel (VE-4)
--   2 Perfil de velocidades: v = k y^n o tabla de puntos (VE-6)
--   3 Aguas abajo: v, E, Fr y tirantes alternos por Bernoulli (VE-7)
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
local WT_SIMPLE, WT_COMP, WT_PROF, WT_DOWN, WT_COUNT = 0, 1, 2, 3, 4
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
  "Qd", "bd", "h1", "dz" }
local CHOICES = { "etype", "mode", "qunit", "cmode", "pmode", "smode", "init" }
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
  "PERFIL DE VELOCIDADES (VE-6)", "AGUAS ABAJO: ENERGIA (VE-7)" }

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

-- Devuelve nil si va bien o el texto del error
local function compute()
  local g = F.gset()
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
    MR.memo_show(MR.PROG_X(MR.XP_VE1_SUM + 2 * tipo + (memo and 1 or 0)))
    local k = W.view_run(titles[tipo + 1], memo and fk_memo or fk_sum)
    if k == K_F1 then memo = not memo
    elseif k == K_F3 and not memo then F.case_save_ui(MR.KT_WEIR + tipo)
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
  local fm = { title = titles[t + 1], cur = cur_of[t] or 0, top = 0, n = 0 }
  on_commit()
  set_form(fm)
  fm.fk = { "", "", "", "AJUSTES", "CALC" }
  fm.on_commit = on_commit
  fm.hint = t == WT_SIMPLE and "Orificio: H al centro; z desde una ref."
    or t == WT_COMP and "Cotas z: vertice, cresta o centro"
    or t == WT_PROF and "Perfil: elija la forma con izq/der"
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

function S.weir_preset(k)
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
