-- scr_drag.lua - Arrastre y sustentacion (port de scr_drag.c, v2.1).
--   0 AR-1 fuerza de arrastre o sustentacion
--   1 AR-2 velocidad terminal (con empuje)
--   2 AR-3 estructura con varios cuerpos (fuerza, momento en la base)
--   3 AR-4 vuelo nivelado (dos pasos: C_L necesario, luego la lectura)
--   4 EX-4 placa plana y flujo lento (Stokes)
-- Patron de siempre: formulario -> resultado -> memoria (PERDTXT).
-- F1 CD abre el catalogo y devuelve C_D y la figura. Unidades: SI; V en m/s, km/h o nudos.
--
-- Estado: la tabla `di` (campos de entrada y banderas "tiene valor" s<campo>,
-- cuerpos di.b[1..6]); Mis casos guarda una copia profunda (drag_save/drag_load).
--
-- API: scr_drag(t), scr_drag_run(t, autocalc), drag_preset(k) -> tipo,
--      drag_save() -> tabla, drag_load(tabla) -> bool.
local U = require("ui.ui")
local W = require("ui.widgets")
local M = require("ui.memo")
local G = require("ui.gfxcat")
local MR = require("memo_run")
local H = require("core.hydro")
local Dr = require("core.drag")
local dc = require("data.dragcat")
local cat = require("scr.scr_cat")
local F = require("scr.flu_util")

local S = {}
local DT_AR1, DT_AR2, DT_AR3, DT_AR4, DT_PL, DT_COUNT = 0, 1, 2, 3, 4, 5
local NB = Dr.DRAG_BODIES
local CAT_N = dc.CAT_N
local FF_POS, FF_NONNEG, FF_CHOICE, FF_INT, FF_OPT, FF_ANY =
  W.FF_POS, W.FF_NONNEG, W.FF_CHOICE, W.FF_INT, W.FF_OPT, W.FF_ANY
local K_F1, K_F2, K_F3, K_F4, K_F5, K_ENTER, K_CLEAR, K_QUIT, K_MODE =
  U.K_F1, U.K_F2, U.K_F3, U.K_F4, U.K_F5, U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE
local C_FG, C_OK, C_WARN, C_ERR, C_GRAY, C_TITLE, C_BG, C_LP, C_GROUND =
  U.C_FG, U.C_OK, U.C_WARN, U.C_ERR, U.C_GRAY, U.C_TITLE, U.C_BG, U.C_LP, U.C_GROUND
local mfmt = M.mfmt
local floor, sqrt = math.floor, math.sqrt
local msetf = MR.msetf

local function nz(x) return x ~= nil and x ~= 0 and x ~= false end

-- ------------------------------------------------------------ estado (di)
local VALS = { "rho", "nu", "V", "cd", "fig", "D", "L", "A", "Lr", "W", "vol", "h", "rh4",
  "nw", "Aw", "cdf", "Df", "alpha", "cdw", "clmax", "nb" }
local CHOICES = { "fluid", "vunit", "lift", "kase", "faces", "regime", "init" }
local BVALS = { "cd", "fig", "D", "L", "A", "y", "V" }

local di = {}
local function blank()
  for k in pairs(di) do di[k] = nil end
  for _, k in ipairs(VALS) do di[k] = 0; di["s" .. k] = 0 end
  for _, k in ipairs(CHOICES) do di[k] = 0 end
  di.b = {}
  for i = 1, NB do
    local b = {}
    for _, k in ipairs(BVALS) do b[k] = 0; b["s" .. k] = 0 end
    di.b[i] = b
  end
end
blank()

local fluid_names = { "Aire (Ajustes)", "Agua", "Manual" }
local vu_names = { "m/s", "km/h", "nudos" }
local lift_names = { "Arrastre FD", "Sustentac. FL" }
local kase_names = { "Placa plana", "Esfera Stokes" }
local face_names = { "Una", "Dos" }
local reg_names = { "Auto", "Laminar", "Turbulento", "Mixto" }

local function FN(lab, un, k, fl) return { label = lab, unit = un, t = di, k = k, setk = "s" .. k, flags = fl } end
local function FC(lab, k, names, n)
  return { label = lab, t = di, chk = k, flags = FF_CHOICE, choices = names, nchoices = n }
end
local function FI(lab, k, fl, lo, hi)
  return { label = lab, t = di, k = k, setk = "s" .. k, flags = fl, lo = lo, hi = hi }
end

local function cat_ext(a, b)           -- concatena listas
  local r = {}
  for _, l in ipairs({ a, b }) do for _, x in ipairs(l) do r[#r + 1] = x end end
  return r
end

local function F_FLUID()
  return { FC("Fluido", "fluid", fluid_names, 3), FN("rho", "kg/m3", "rho", FF_POS),
           FN("nu", "m2/s", "nu", FF_POS) }
end
local function F_V()
  return { FN("Velocidad V", nil, "V", FF_POS), FC("Unidad de V", "vunit", vu_names, 3) }
end
local function F_SHAPE()
  return { FN("CD (F1: catalogo)", nil, "cd", FF_POS),
           FI("Figura 1-17 (opc)", "fig", FF_INT + FF_OPT, 1, CAT_N),
           FN("Dim. D (o h)", "m", "D", FF_POS + FF_OPT),
           FN("Dim. L o b (opc)", "m", "L", FF_POS + FF_OPT),
           FN("Area A (opc)", "m2", "A", FF_POS + FF_OPT),
           FN("Long. Re (opc)", "m", "Lr", FF_POS + FF_OPT) }
end

local f_ar1 = cat_ext({ FC("Calcular", "lift", lift_names, 2) },
  cat_ext(F_FLUID(), cat_ext(F_V(), F_SHAPE())))
local f_ar2 = cat_ext(F_FLUID(), cat_ext({ FN("Peso W", "N", "W", FF_POS),
  FN("Volumen (empuje)", "m3", "vol", FF_POS + FF_OPT) }, F_SHAPE()))
local f_ar4 = cat_ext({ FN("Peso W", "N", "W", FF_POS) }, cat_ext(F_V(), {
  FN("Altitud h", "m", "h", FF_NONNEG + FF_OPT),
  FN("rho (o altitud)", "kg/m3", "rh4", FF_POS + FF_OPT),
  FI("Numero de alas", "nw", FF_INT, 1, 4),
  FN("Area de un ala", "m2", "Aw", FF_POS),
  FN("CD fuselaje", nil, "cdf", FF_NONNEG),
  FN("D fuselaje", "m", "Df", FF_NONNEG),
  FN("Lectura: alfa(opc)", "grad", "alpha", FF_ANY + FF_OPT),
  FN("Lectura: CD alas", nil, "cdw", FF_POS + FF_OPT),
  FN("CLmax (opc)", nil, "clmax", FF_POS + FF_OPT) }))
local f_pl = cat_ext({ FC("Caso", "kase", kase_names, 2) }, cat_ext(F_FLUID(), cat_ext(F_V(), {
  FN("L placa o D esfera", "m", "D", FF_POS),
  FN("Ancho w (placa)", "m", "L", FF_POS + FF_OPT),
  FC("Caras mojadas", "faces", face_names, 2),
  FC("Regimen (placa)", "regime", reg_names, 4) })))

local titles = { "FUERZA DE ARRASTRE (AR-1)", "VELOCIDAD TERMINAL (AR-2)",
  "ESTRUCTURA: CUERPOS (AR-3)", "VUELO NIVELADO (AR-4)", "PLACA PLANA Y STOKES" }

local tipo = DT_AR1
local last_fluid, last_fig = 255, 0
local fm_now = nil
local nb0 = 0

-- Formulario de la estructura: datos comunes y 7 campos por cuerpo
local function build_ar3()
  local sub = { "CD", "Figura 1-17", "D (o h)", "L o b", "A (opc)", "y cota", "V (opc)" }
  local unit = { nil, nil, "m", "m", "m2", "m", nil }
  local fl = { FF_POS, FF_INT + FF_OPT, FF_POS + FF_OPT, FF_POS + FF_OPT, FF_POS + FF_OPT,
               FF_ANY, FF_POS + FF_OPT }
  local f = cat_ext({ FI("Numero de cuerpos", "nb", FF_INT, 1, NB) },
    cat_ext(F_FLUID(), F_V()))
  for i = 1, floor(di.nb) do
    local b = di.b[i]
    for j = 1, 7 do
      local k = BVALS[j]
      f[#f + 1] = { label = i .. " " .. sub[j], unit = unit[j], t = b, k = k, setk = "s" .. k,
                    flags = fl[j], lo = 1, hi = CAT_N }
    end
  end
  return f
end

local function set_form(fm)
  if tipo == DT_AR3 then fm.f = build_ar3()
  else fm.f = ({ [0] = f_ar1, f_ar2, false, f_ar4, f_pl })[tipo] end
  fm.n = #fm.f
  if fm.cur >= fm.n then fm.cur = 0 end
end

-- Fluido elegido -> rho y nu; figura escrita -> su C_D; numero de cuerpos ->
-- rehacer el formulario
local function on_commit()
  local g = F.gset()
  if di.fluid ~= last_fluid and di.fluid < 2 then
    di.rho = (di.fluid ~= 0) and g.h.gamma / g.h.g or g.rho_air
    di.nu = (di.fluid ~= 0) and g.h.nu or g.nu_air
    di.srho, di.snu = 1, 1
  end
  last_fluid = di.fluid
  if nz(di.sfig) and floor(di.fig) ~= last_fig then
    last_fig = floor(di.fig)
    di.cd = dc.dragcat_cd(last_fig - 1)
    di.scd = 1
  end
  for i = 1, NB do
    local b = di.b[i]
    if nz(b.sfig) and not nz(b.scd) then
      b.cd = dc.dragcat_cd(floor(b.fig) - 1)
      b.scd = 1
    end
  end
  if tipo == DT_AR3 and fm_now and di.nb ~= nb0 then
    nb0 = di.nb
    set_form(fm_now)
  end
end

-- ------------------------------------------------------------------ calculo
local function vms(v)
  if di.vunit == 0 then return v end
  if di.vunit == 1 then return v / 3.6 end
  return v * F.gset().knot / 3.6
end

-- Area de referencia de una figura: A tecleada o formula con D y L.
-- Devuelve (mensaje de error | nil, area)
local function area_of(sfig, fig, sA, A, sD, D, sL, L)
  if nz(sA) then return nil, A end
  if not nz(sfig) or not (fig >= 1 and fig <= CAT_N) then
    return "Falta el area A (o la figura)"
  end
  local ar = dc.drag_shapes[floor(fig)].area
  if not nz(sD) or ((ar == dc.AR_LD or ar == dc.AR_BH) and not nz(sL)) then
    return "Faltan las dimensiones (o A)"
  end
  return nil, dc.dragcat_area(ar, D, L)
end

local function kind_of(sfig, fig)
  if not (fig >= 1 and fig <= CAT_N) then sfig = 0 end
  return nz(sfig) and dc.drag_shapes[floor(fig)].kind or Dr.DK_GENERIC
end

local function flag_warn(w)
  msetf(MR.G_DRELOW, H.warn_has(w, Dr.DW_RE_LOW))
  msetf(MR.G_DCRIS, H.warn_has(w, Dr.DW_CRISIS))
  msetf(MR.G_DRE1, H.warn_has(w, Dr.DW_STOKES))
end

local SR = { F = {} }
local BD = {}

local function bodies_hook()
  for i = 1, floor(di.nb) do
    M.memo_line(mfmt("%d: CD=%w A=%w m2 y=%w m", i, BD[i].Cd, BD[i].A, BD[i].y), C_FG)
    M.memo_line(mfmt("   F%d = CD q A = %w kN  Re=%w", i, SR.F[i] / 1000, SR.Re[i]), C_OK)
    if H.warn_has(SR.w[i], Dr.DW_CRISIS) then
      M.memo_line("   ! posible crisis de arrastre", C_WARN)
    end
  end
end

-- Devuelve nil si va bien o el texto del error
local function compute()
  local g = F.gset()
  MR.memo_reset()
  local V = MR.V
  local C = F.cfg_copy()
  MR.cfg = C
  MR.hook = nil
  local rho = di.rho
  local v = vms(di.V)
  V[MR.V_VIN] = di.V
  V[MR.V_VEL] = v
  V[MR.V_RHO] = rho
  V[MR.V_NU] = di.nu
  V[MR.V_MU] = rho * di.nu
  V[MR.V_G] = C.g
  msetf(MR.G_DVCONV, di.vunit ~= 0)
  local err = 0
  if tipo == DT_AR1 or tipo == DT_AR2 then
    local e, A = area_of(di.sfig, di.fig, di.sA, di.A, di.sD, di.D, di.sL, di.L)
    if e then return e end
    local cd = di.cd
    local Lr = nz(di.sLr) and di.Lr or (nz(di.sD) and di.D or sqrt(A))
    local k = kind_of(di.sfig, di.fig)
    V[MR.V_CDV] = cd
    V[MR.V_AREF] = A
    V[MR.V_DIM1] = di.D
    V[MR.V_DIM2] = di.L
    V[MR.V_LREF] = Lr
    msetf(MR.G_DFIG, nz(di.sfig))
    msetf(MR.G_DACALC, not nz(di.sA))
    local figok = nz(di.sfig) and di.fig >= 1 and di.fig <= CAT_N
    MR.txt = figok and dc.area_txt[dc.drag_shapes[floor(di.fig)].area + 1] or ""
    V[MR.V_KST] = figok and dc.drag_shapes[floor(di.fig)].stokes or 0
    local w
    if tipo == DT_AR1 then
      V[MR.V_QDYN] = Dr.drag_q(rho, v)
      V[MR.V_FD] = Dr.drag_force(rho, cd, A, v)
      V[MR.V_RE] = Dr.drag_re(v, Lr, di.nu)
      w = Dr.drag_re_warn(V[MR.V_RE], k)
      msetf(MR.G_DLIFT, di.lift ~= 0)
      if H.warn_has(w, Dr.DW_STOKES) and V[MR.V_KST] > 0 and di.lift == 0 then
        V[MR.V_CDV] = V[MR.V_KST] / V[MR.V_RE]
        V[MR.V_FD] = Dr.drag_force(rho, V[MR.V_CDV], A, v)
        msetf(MR.G_DSTK, true)
      end
    else
      local useb = nz(di.svol) and (di.fluid == 1 or nz(g.buoy) or di.fluid == 2)
      if di.fluid == 1 and not nz(di.svol) then return "Agua: falta el volumen (empuje)" end
      local t = {}
      err = Dr.drag_terminal(di.W, rho, useb and di.vol or 0, cd, A, Lr, di.nu, C.g, k, t)
      if err == H.H_ERR_FLOATS then return "W <= B: el cuerpo flota, no cae" end
      if err ~= 0 then return H.hydro_err_text(err) end
      V[MR.V_W] = di.W
      V[MR.V_VOL] = di.vol
      V[MR.V_BUOY] = t.B
      V[MR.V_NET] = t.net
      V[MR.V_VT] = t.v
      V[MR.V_RE] = t.Re
      w = t.warn
      msetf(MR.G_DBUOY, useb)
      if H.warn_has(w, Dr.DW_STOKES) and V[MR.V_KST] > 0 then
        V[MR.V_VT] = 2 * t.net * Lr / (rho * V[MR.V_KST] * di.nu * A)
        V[MR.V_RE] = Dr.drag_re(V[MR.V_VT], Lr, di.nu)
        V[MR.V_CDV] = V[MR.V_KST] / V[MR.V_RE]
        msetf(MR.G_DSTK, true)
      end
      V[MR.V_VTKMH] = V[MR.V_VT] * 3.6
    end
    flag_warn(w)
  elseif tipo == DT_AR3 then
    V[MR.V_QDYN] = Dr.drag_q(rho, v)
    BD = {}
    local nb = floor(di.nb)
    for i = 1, nb do
      local b = di.b[i]
      if not nz(b.sy) then return "Falta la cota y de un cuerpo" end
      local e, A = area_of(b.sfig, b.fig, b.sA, b.A, b.sD, b.D, b.sL, b.L)
      if e then return e end
      BD[i] = { Cd = b.cd, A = A, y = b.y, V = nz(b.sV) and vms(b.V) or v,
                Lref = nz(b.sD) and b.D or sqrt(A), kind = kind_of(b.sfig, b.fig) }
    end
    SR = {}
    err = Dr.drag_struct(BD, nb, rho, di.nu, SR)
    if err ~= 0 then return H.hydro_err_text(err) end
    V[MR.V_FTOT] = SR.Ftot / 1000
    V[MR.V_MOM] = SR.M / 1000
    V[MR.V_YCP] = SR.ycp
    flag_warn(SR.warn)
    MR.hook = bodies_hook
  elseif tipo == DT_AR4 then
    local pl = {}
    if not nz(di.srh4) and not nz(di.sh) then return "Falta la altitud h o rho" end
    rho = nz(di.srh4) and di.rh4 or Dr.drag_rho_alt(di.h)
    msetf(MR.G_DALT, not nz(di.srh4))
    V[MR.V_ALT] = di.h
    V[MR.V_RHO] = rho
    err = Dr.drag_plane_lift(di.W, rho, v, di.Aw, floor(di.nw), pl)
    if err ~= 0 then return H.hydro_err_text(err) end
    if nz(di.scdw) then
      err = Dr.drag_plane_thrust(di.W, rho, v, di.cdw, di.cdf, di.Df,
        nz(di.sclmax) and di.clmax or 0, pl)
      msetf(MR.G_DSTEP2, true)
      msetf(MR.G_DVST, nz(di.sclmax))
      if err ~= 0 then return H.hydro_err_text(err) end
      V[MR.V_AFUS] = pl.Afus
      V[MR.V_DWING] = pl.Dw / 1000
      V[MR.V_DFUS] = pl.Df / 1000
      V[MR.V_THR] = pl.T / 1000
      V[MR.V_PWR] = pl.P / 1e6
      V[MR.V_VST] = pl.Vst
      V[MR.V_VTKMH] = pl.Vst * 3.6
    end
    V[MR.V_W] = di.W
    V[MR.V_QDYN] = pl.q
    V[MR.V_CL] = pl.CL
    V[MR.V_ATOT] = pl.Atot
    V[MR.V_AW] = di.Aw
    V[MR.V_NW] = di.nw
    V[MR.V_CDW] = di.cdw
    V[MR.V_CDF] = di.cdf
    V[MR.V_DF] = di.Df
    V[MR.V_ALPHA] = di.alpha
    V[MR.V_CLMAX] = di.clmax
  else
    V[MR.V_DIM1] = di.D
    V[MR.V_RE] = Dr.drag_re(v, di.D, di.nu)
    if di.kase ~= 0 then
      msetf(MR.G_PSTK, true)
      V[MR.V_FD] = Dr.drag_stokes(rho * di.nu, v, di.D)
      V[MR.V_CDV] = 24 / V[MR.V_RE]
      msetf(MR.G_DRE1, V[MR.V_RE] > 1 + 1e-9)        -- aviso: Re >= 1
    else
      local p = {}
      if not nz(di.sL) then return "Falta el ancho w de la placa" end
      err = Dr.drag_plate(di.D, di.L, v, rho, di.nu, di.faces + 1, di.regime, p)
      if err ~= 0 then return H.hydro_err_text(err) end
      V[MR.V_DIM2] = di.L
      V[MR.V_CFL] = p.Cf_lam
      V[MR.V_CFT] = p.Cf_turb
      V[MR.V_CFM] = p.Cf_mix
      V[MR.V_CF] = p.Cf
      V[MR.V_APL] = p.A
      V[MR.V_FACES] = di.faces + 1
      V[MR.V_QDYN] = Dr.drag_q(rho, v)
      V[MR.V_FD] = p.F
      msetf(MR.G_PLAM, p.regime == Dr.PL_LAM)
      msetf(MR.G_PTURB, p.regime == Dr.PL_TURB)
      msetf(MR.G_PMIX, p.regime == Dr.PL_MIX)
      msetf(MR.G_PLAMNA, H.warn_has(p.warn, Dr.DW_LAM_NA))
      msetf(MR.G_PTURBNA, H.warn_has(p.warn, Dr.DW_TURB_NA))
    end
  end
  if err ~= 0 then return H.hydro_err_text(err) end
  return nil
end

-- --------------------------------------------- esquema: fuerzas a su altura
local function sketch()
  local fk = { "", "", "", "", "VOLVER" }
  local nb = floor(di.nb)
  local ymax, fmax = 0, 0
  for i = 1, nb do
    if BD[i].y > ymax then ymax = BD[i].y end
    if SR.F[i] > fmax then fmax = SR.F[i] end
  end
  if not (ymax > 0) or not (fmax > 0) then return end
  while true do
    if U.quit then return end
    local BW, BH = U.ui_body_w(), U.ui_body_h()
    local rh = floor(BH / U.ui_rows())
    local ground = BH - 16                                 -- y del suelo
    U.ui_begin("ESQUEMA DE FUERZAS", nil)
    G.gfxcat_rect(10, ground, BW - 20, 3, C_GROUND)        -- suelo
    G.gfxcat_rect(30, 8, 3, ground - 8, C_GRAY)            -- eje
    for i = 1, nb do
      local y = floor(ground - (ground - 22) * BD[i].y / ymax)
      G.gfxcat_rect(33, y - 1, floor(150 * SR.F[i] / fmax) + 2, 3, C_LP)
      U.ui_px_text(floor(BW * 0.6), y - 12, mfmt("F%d=%w kN", i, SR.F[i] / 1000), C_FG)
    end
    U.ui_text(U.ui_rows(), 0, mfmt("M = %w kN m  ycp = %w m", SR.M / 1000, SR.ycp), C_TITLE, C_BG)
    U.ui_fbar(fk)
    U.ui_end()
    local k = U.ui_getkey()
    if not (k.k == U.K_NONE or k.k == U.K_ALPHA or k.k == U.K_CLICK) then return end
  end
end

-- --------------------------------------------------------------- resultado
local function result_loop()
  local fk_sum = { "MEMORIA", tipo == DT_AR3 and "ESQUEMA" or "", "GUARDAR", "", "VOLVER" }
  local fk_memo = { "RESUMEN", "", "", "", "VOLVER" }
  local memo = false
  while true do
    MR.memo_show(MR.PROG_X(MR.XP_AR1_SUM + 2 * tipo + (memo and 1 or 0)))
    local k = W.view_run(titles[tipo + 1], memo and fk_memo or fk_sum)
    if k == K_F1 then memo = not memo
    elseif k == K_F3 and not memo then F.case_save_ui(MR.KT_DRAG + tipo)
    elseif k == K_F2 and tipo == DT_AR3 then sketch()
    elseif k == K_MODE then F.scr_settings()
    else return end
    if U.quit then return end
  end
end

-- F1 CD: catalogo; en la estructura, para el cuerpo del cursor
local function pick_cd(fm)
  local i = nil
  if tipo == DT_AR3 then
    if fm.cur >= 6 then i = floor((fm.cur - 6) / 7) end
    if i == nil or i >= floor(di.nb) then
      fm.msg = "Ubique el cursor en un cuerpo"
      fm.msg_color = C_WARN
      return
    end
  end
  local r = cat.scr_cat(true)
  if r < 0 then return end
  if i then
    local b = di.b[i + 1]
    b.cd = cat.cat_sel_cd
    b.fig = r + 1
    b.scd, b.sfig = 1, 1
  else
    di.cd = cat.cat_sel_cd
    di.fig = r + 1
    di.scd, di.sfig = 1, 1
    last_fig = r + 1
  end
end

local cur_of = {}

function S.scr_drag_run(t, autocalc)
  if t < 0 or t >= DT_COUNT then return end
  tipo = t
  F.sync_cd_user()
  if not nz(di.init) then
    di.init = 1
    di.nw, di.nb = 2, 2
    di.snw, di.snb = 1, 1
  end
  local fm = { title = titles[t + 1], cur = cur_of[t] or 0, top = 0, n = 0 }
  if t == DT_AR4 and not nz(di.sV) then di.vunit = 2 end   -- el examen da nudos
  on_commit()
  set_form(fm)
  fm.fk = { (t <= DT_AR3) and "CD" or "", "", "", "AJUSTES", "CALC" }
  fm.on_commit = on_commit
  fm.hint = t == DT_AR4 and "Sin CD alas: calcula el CL necesario"
    or "Fluido Aire o Agua llena rho y nu"
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
    if k == K_F1 and t <= DT_AR3 then
      pick_cd(fm)
    elseif k == K_F4 or k == K_MODE then
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

function S.scr_drag(t) S.scr_drag_run(t, false) end

-- ----------------------------------------------------------- Mis casos
function S.drag_save() return F.deep_copy(di) end

local function clamp01(v) return (v == 1) and 1 or 0 end

function S.drag_load(t)
  if type(t) ~= "table" or type(t.b) ~= "table" then return false end
  blank()
  for k, v in pairs(t) do
    if k ~= "b" and type(v) == "number" then di[k] = v end
  end
  for i = 1, NB do
    if type(t.b[i]) == "table" then
      for k, v in pairs(t.b[i]) do if type(v) == "number" then di.b[i][k] = v end end
    end
  end
  if di.fluid > 2 then di.fluid = 0 end
  if di.vunit > 2 then di.vunit = 0 end
  di.lift, di.kase, di.faces = clamp01(di.lift), clamp01(di.kase), clamp01(di.faces)
  if di.regime > 3 then di.regime = 0 end
  if not (di.nb >= 1 and di.nb <= NB) then di.nb = 2 end
  if not (di.nw >= 1 and di.nw <= 4) then di.nw = 2 end
  di.init = 1
  last_fluid, last_fig = di.fluid, floor(di.fig)   -- no pisar rho, nu ni CD guardados
  return true
end

-- ---- Casos del curso AR-01..AR-06. Devuelve el tipo
local function SD(k, x) di[k] = x; di["s" .. k] = 1 end

function S.drag_preset(k)
  local tipo_of = { [0] = DT_AR2, DT_AR3, DT_AR2, DT_AR4, DT_PL, DT_PL }
  blank()
  di.init = 1
  SD("nw", 2)
  SD("nb", 2)
  SD("rho", 1.2)
  SD("nu", 1.5e-5)
  local b1, b2 = di.b[1], di.b[2]
  if k == 0 then                                -- paracaidista, T4-2 P1
    SD("W", 950); SD("cd", 1.3); SD("fig", 5); SD("D", 8)
  elseif k == 1 then                            -- torre y tanque, T4-2 P4
    SD("V", 100); di.vunit = 1
    b1.cd, b1.fig, b1.D, b1.L, b1.y = 0.9166667, 11, 2, 30, 15
    b2.cd, b2.fig, b2.D, b2.y = 0.5, 1, 12, 36
    b1.scd, b1.sfig, b1.sD, b1.sL, b1.sy = 1, 1, 1, 1, 1
    b2.scd, b2.sfig, b2.sD, b2.sy = 1, 1, 1, 1
  elseif k == 2 then                            -- cubo en agua, T4-2 P5
    di.fluid = 1; SD("rho", 1000); SD("nu", 1e-6)
    SD("W", 19.8); SD("vol", 0.001); SD("cd", 0.8); SD("fig", 10)
    SD("D", 0.1)
  elseif k == 3 then                            -- A-330, examen 2017 P2
    SD("W", 3.9e6); SD("V", 480); di.vunit = 2; SD("h", 10675)
    SD("Aw", 180.8); SD("cdf", 1); SD("Df", 5.28)
  elseif k == 4 then                            -- esfera de Stokes
    di.kase = 1; di.fluid = 1; SD("rho", 1000); SD("nu", 1e-6)
    SD("V", 0.001); SD("D", 0.001)
  else                                          -- placa plana en aire
    SD("V", 10); SD("D", 2); SD("L", 1); di.regime = Dr.PL_TURB
  end
  last_fluid = di.fluid
  last_fig = floor(di.fig)
  return tipo_of[k < 6 and k or 5]
end

return S
