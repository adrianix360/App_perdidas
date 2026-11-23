-- scr_chan.lua - Canales y medicion (port de scr_chan.c, v2.1).
--   0 EX-1 Venturi con manometro diferencial (convencion fisica o la de la
--     solucion del examen 2025)
--   1 EX-2 salto hidraulico en canal rectangular (dado y1 o dado y2)
--   2 EX-3 chorro desde un tubo: Q con el motor de tuberia tipo B (caudal maximo)
--     y luego la trayectoria
-- (EX-4 placa plana y Stokes esta en scr_drag.lua.)
--
-- Estado: tabla `ci` (valores, banderas s<campo>, elecciones); Mis casos guarda una
-- copia profunda.
-- API: scr_chan(t), scr_chan_run(t, autocalc), chan_preset(k) -> tipo,
--      chan_save() -> tabla, chan_load(tabla) -> bool.
local U = require("ui.ui")
local W = require("ui.widgets")
local MR = require("memo_run")
local H = require("core.hydro")
local Ch = require("core.chan")
local F = require("scr.flu_util")

local S = {}
local CT_VENT, CT_JUMP, CT_JET, CT_COUNT = 0, 1, 2, 3
local FF_POS, FF_NONNEG, FF_CHOICE, FF_RANGE, FF_OPT =
  W.FF_POS, W.FF_NONNEG, W.FF_CHOICE, W.FF_RANGE, W.FF_OPT
local K_F4, K_F5, K_F1, K_F3, K_ENTER, K_CLEAR, K_QUIT, K_MODE =
  U.K_F4, U.K_F5, U.K_F1, U.K_F3, U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE
local C_ERR = U.C_ERR
local msetf = MR.msetf

local function nz(x) return x ~= nil and x ~= 0 and x ~= false end

local VALS = { "D1", "D2", "beta", "Q", "v1", "Cv", "S", "b", "y", "H", "L", "D", "ks", "nu", "K", "th" }
local CHOICES = { "qunit", "conv", "ymode", "exitk", "init" }

local ci = {}
local function blank()
  for k in pairs(ci) do ci[k] = nil end
  for _, k in ipairs(VALS) do ci[k] = 0; ci["s" .. k] = 0 end
  for _, k in ipairs(CHOICES) do ci[k] = 0 end
end
blank()

local qu_names = { "l/s", "m3/s" }
local cv_names = { "(S-1) g h fisico", "S g h examen" }
local ym_names = { "Dado y1", "Dado y2" }
local yn_names = { "No (SumK = K)", "Si (SumK + 1)" }

local function FN(lab, un, k, fl, lo, hi)
  return { label = lab, unit = un, t = ci, k = k, setk = "s" .. k, flags = fl, lo = lo, hi = hi }
end
local function FC(lab, k, names, n)
  return { label = lab, t = ci, chk = k, flags = FF_CHOICE, choices = names, nchoices = n }
end

local f_vent = {
  FN("D1 entrada", "mm", "D1", FF_POS),
  FN("D2 garganta (opc)", "mm", "D2", FF_POS + FF_OPT),
  FN("o D2/D1 (opc)", nil, "beta", FF_POS + FF_OPT),
  FN("Caudal Q (o v1)", "l/s", "Q", FF_POS + FF_OPT),
  FC("Unidad de Q", "qunit", qu_names, 2),
  FN("o v1 (opc)", "m/s", "v1", FF_POS + FF_OPT),
  FN("Cv", nil, "Cv", FF_RANGE, 0.01, 1),
  FN("S manometro (opc)", nil, "S", FF_POS + FF_OPT),
  FC("Manometro", "conv", cv_names, 2),
}
local f_jump = {
  FN("Caudal Q", "m3/s", "Q", FF_POS),
  FN("Ancho b", "m", "b", FF_POS),
  FC("Dato", "ymode", ym_names, 2),
  FN("Tirante y1 o y2", "m", "y", FF_POS),
}
local f_jet = {
  FN("Carga H", "m", "H", FF_POS),
  FN("Longitud L", "m", "L", FF_POS),
  FN("Diametro D", "mm", "D", FF_POS),
  FN("Rugosidad ks", "mm", "ks", FF_NONNEG),
  FN("Viscosidad nu", "m2/s", "nu", FF_POS),
  FN("Suma K", nil, "K", FF_NONNEG),
  FC("Energia salida", "exitk", yn_names, 2),
  FN("Angulo theta", "grad", "th", FF_RANGE, 0, 90),
}

local titles = { "VENTURI Y MANOMETRO (EX-1)", "SALTO HIDRAULICO (EX-2)",
  "CHORRO DESDE UN TUBO (EX-3)" }
local forms = { [0] = f_vent, f_jump, f_jet }

local tipo = CT_VENT

local function on_commit()
  f_vent[4].unit = qu_names[ci.qunit + 1]
end

-- Devuelve nil si va bien o el texto del error
local function compute()
  MR.memo_reset()
  local V = MR.V
  local C = F.cfg_copy()
  MR.cfg = C
  MR.hook = nil
  MR.log = nil
  V[MR.V_G] = C.g
  V[MR.V_GAM] = C.gamma
  local err
  if tipo == CT_VENT then
    local r = {}
    local D1 = ci.D1 / 1000
    local D2, Q
    if nz(ci.sD2) then D2 = ci.D2 / 1000
    elseif nz(ci.sbeta) then D2 = ci.beta * D1
    else return "Falta D2 o D2/D1" end
    if nz(ci.sv1) then
      Q = ci.v1 * H.hydro_area(D1)
      msetf(MR.G_VV1, true)
    elseif nz(ci.sQ) then
      Q = (ci.qunit ~= 0) and ci.Q or ci.Q / 1000
    else
      return "Falta Q o v1"
    end
    err = Ch.chan_venturi(D1, D2, Q, ci.Cv, nz(ci.sS) and ci.S or 0, ci.conv, C, r)
    if err ~= 0 then
      return (D2 >= D1) and "D2 debe ser menor que D1" or H.hydro_err_text(err)
    end
    V[MR.V_VD1] = D1
    V[MR.V_VD2] = D2
    V[MR.V_VBETA] = r.beta
    V[MR.V_VB4] = r.beta * r.beta * r.beta * r.beta
    V[MR.V_VA1] = r.A1
    V[MR.V_VA2] = r.A2
    V[MR.V_VV1] = r.v1
    V[MR.V_VV2] = r.v2
    V[MR.V_VDP] = r.dp
    V[MR.V_VDPK] = r.dp / 1000
    V[MR.V_VH] = r.h
    V[MR.V_VS] = ci.S
    V[MR.V_VSF] = (ci.conv ~= 0) and ci.S or ci.S - 1
    V[MR.V_VCV] = ci.Cv
    V[MR.V_VQ] = Q
    V[MR.V_VQLS] = Q * 1000
    msetf(MR.G_VMANO, nz(ci.sS))
    msetf(MR.G_VEXAM, ci.conv ~= 0)
    msetf(MR.G_VCV, ci.Cv ~= 1)
  elseif tipo == CT_JUMP then
    local r = {}
    err = Ch.chan_jump(ci.Q, ci.b, ci.y, ci.ymode, C, r)
    if err == H.H_ERR_NOJUMP then
      return (ci.ymode ~= 0) and "Fr2 >= 1: y2 no es subcritico" or "Fr1 <= 1: no hay salto hidraulico"
    end
    if err ~= 0 then return H.hydro_err_text(err) end
    V[MR.V_JQ] = ci.Q
    V[MR.V_JB] = ci.b
    V[MR.V_JQQ] = r.q
    V[MR.V_JY1] = r.y1
    V[MR.V_JY2] = r.y2
    V[MR.V_JV1] = r.v1
    V[MR.V_JV2] = r.v2
    V[MR.V_JFR1] = r.Fr1
    V[MR.V_JFR2] = r.Fr2
    V[MR.V_JE1] = r.E1
    V[MR.V_JE2] = r.E2
    V[MR.V_JDE] = r.dE
    V[MR.V_JP] = r.P / 1000
    V[MR.V_JEFF] = 100 * r.eff
    msetf(MR.G_JY2, ci.ymode ~= 0)
  else
    local q, j = {}, {}
    C.nu = ci.nu
    local p = { D = ci.D / 1000, L = ci.L, ks = ci.ks / 1000,
                sumK = ci.K + ((ci.exitk ~= 0) and 1 or 0), f_fixed = 0 }
    local LG = H.new_log()
    MR.lg = LG
    err = H.hydro_qmax(p, ci.H, C, q, LG)
    if err ~= 0 then return H.hydro_err_text(err) end
    err = Ch.chan_jet(q.st.v, ci.th, C.g, j)
    if err ~= 0 then return H.hydro_err_text(err) end
    V[MR.V_EH] = ci.H
    V[MR.V_EL] = ci.L
    V[MR.V_ED] = p.D
    V[MR.V_EKS] = p.ks
    V[MR.V_NU] = ci.nu
    V[MR.V_EK] = p.sumK
    V[MR.V_EQ] = q.st.Q
    V[MR.V_EQLS] = q.st.Q * 1000
    V[MR.V_EV] = q.st.v
    V[MR.V_ERE] = q.st.Re
    V[MR.V_EF] = q.st.f
    V[MR.V_ELD] = p.L / p.D
    V[MR.V_EIT] = q.iters
    V[MR.V_ETH] = ci.th
    V[MR.V_EVX] = j.vx
    V[MR.V_EVY] = j.vy
    V[MR.V_EHM] = j.hmax
    V[MR.V_ER] = j.R
    V[MR.V_ET] = j.t
    MR.W = q.st.warn
    MR.log = LG
    msetf(MR.G_EK1, ci.exitk ~= 0)
    msetf(MR.G_EBIS, q.solver == H.SOLV_BISECTION)
  end
  return nil
end

local function result_loop()
  local fk_sum = { "MEMORIA", "", "GUARDAR", "", "VOLVER" }
  local fk_memo = { "RESUMEN", "", "", "", "VOLVER" }
  local memo = false
  while true do
    MR.memo_show(MR.PROG_X(MR.XP_EX1_SUM + 2 * tipo + (memo and 1 or 0)))
    local k = W.view_run(titles[tipo + 1], memo and fk_memo or fk_sum)
    if k == K_F1 then memo = not memo
    elseif k == K_F3 and not memo then F.case_save_ui(MR.KT_CHAN + tipo)
    elseif k == K_MODE then F.scr_settings()
    else return end
    if U.quit then return end
  end
end

local cur_of = {}

function S.scr_chan_run(t, autocalc)
  if t < 0 or t >= CT_COUNT then return end
  tipo = t
  if not nz(ci.init) then
    local g = F.gset()
    ci.init = 1
    ci.Cv = 1
    ci.nu = g.h.nu
    ci.K = 0
    ci.th = 30
    ci.sCv, ci.snu, ci.sK, ci.sth = 1, 1, 1, 1
    ci.conv = g.mano
  end
  local fm = { title = titles[t + 1], f = forms[t], n = #forms[t], cur = cur_of[t] or 0, top = 0 }
  fm.fk = { "", "", "", "AJUSTES", "CALC" }
  fm.on_commit = on_commit
  on_commit()
  fm.hint = t == CT_VENT and "Use el Q que pide el enunciado"
    or t == CT_JUMP and "Canal rectangular" or "theta sobre la horizontal"
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

function S.scr_chan(t) S.scr_chan_run(t, false) end

-- ----------------------------------------------------------- Mis casos
function S.chan_save() return F.deep_copy(ci) end

function S.chan_load(t)
  if type(t) ~= "table" then return false end
  blank()
  for k, v in pairs(t) do if type(v) == "number" then ci[k] = v end end
  ci.qunit = (ci.qunit == 1) and 1 or 0
  ci.conv = (ci.conv == 1) and 1 or 0
  ci.ymode = (ci.ymode == 1) and 1 or 0
  ci.exitk = (ci.exitk == 1) and 1 or 0
  ci.init = 1
  return true
end

-- ---- Casos del curso EX-01..EX-03. Devuelve el tipo
local function SC(k, x) ci[k] = x; ci["s" .. k] = 1 end

function S.chan_preset(k)
  blank()
  ci.init = 1
  SC("Cv", 1); SC("nu", 1e-6); SC("K", 0); SC("th", 30)
  ci.conv = F.gset().mano
  if k == 0 then                                 -- Venturi, 2025 P4c
    SC("D1", 285.75); SC("beta", 0.6); SC("Q", 200); SC("S", 4)
  elseif k == 1 then                             -- salto, 2017 P3
    SC("Q", 12); SC("b", 2); SC("y", 0.4)
  else                                           -- chorro, 2025
    SC("H", 7.5); SC("L", 5); SC("D", 30); SC("ks", 0.045)
    SC("nu", 1.007e-6)
  end
  return k < 3 and k or 2
end

return S
