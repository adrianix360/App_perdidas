-- scr_pipe.lua - Tuberia simple: tipos A, B, C, D, E, F e I (port de scr_pipe.c).
-- Cada tipo: formulario -> calculo con el motor -> resumen y memoria de calculo
-- paso a paso. Los datos se comparten entre tipos (ultimo valor) en la tabla
-- `pin` (unidades de pantalla: Q l/s, D mm, ks mm, L m, H m; el motor va en SI).
--
-- API: P.pin, P.scr_pipe(t), P.scr_pipe_run(t, autocalc), P.pipe_load_example(t, vals, n),
--      P.pin_sanitize(p), P.pin_reset(), P.titles, P.PT_* (codigos 0..6 como el C)
local U = require("ui.ui")
local W = require("ui.widgets")
local H = require("core.hydro")
local MR = require("memo_run")
local GR = require("ui.graph")
local ex = require("data.examples")
local diams = require("data.diams")

local P = {}
local g_set = U.g_set
local PT_A, PT_B, PT_D, PT_C, PT_F, PT_E, PT_I, PT_COUNT = 0, 1, 2, 3, 4, 5, 6, 7
P.PT_A, P.PT_B, P.PT_D, P.PT_C, P.PT_F, P.PT_E, P.PT_I, P.PT_COUNT =
  PT_A, PT_B, PT_D, PT_C, PT_F, PT_E, PT_I, PT_COUNT
local FF_ANY, FF_POS, FF_NONNEG, FF_CHOICE, FF_OPT, FF_RANGE =
  W.FF_ANY, W.FF_POS, W.FF_NONNEG, W.FF_CHOICE, W.FF_OPT, W.FF_RANGE
local K_ENTER, K_CLEAR, K_QUIT, K_MODE = U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE
local K_F1, K_F2, K_F3, K_F4, K_F5 = U.K_F1, U.K_F2, U.K_F3, U.K_F4, U.K_F5
local C_ERR, C_FG, C_GRAY = U.C_ERR, U.C_FG, U.C_GRAY

local function lib() return require("scr.scr_lib") end
local function settings() require("scr.screens").scr_settings() end

-- ------------------------------------------------------------------
-- Datos compartidos (pipe_inputs)
-- ------------------------------------------------------------------
local NUMS = { "Q", "H", "D", "L", "ks", "K", "nu", "f", "CH", "eta", "Hs", "zb", "Hp",
               "z1", "z2", "p1", "p2", "CH0", "bP", "bEta", "bHB" }
local FLAGS = { "sQ", "sH", "sD", "sL", "sks", "sK", "snu", "sf", "sCH", "seta", "sHs",
                "szb", "sHp", "sz1", "sz2", "sp1", "sp2", "sCH0", "sbP", "sbEta", "sbHB" }
-- 0/1 salvo dset (0..5); bom = bomba en la linea, bdato = 0 potencia / 1 carga HB
local CHOICES = { "mach", "dset", "valve", "modeI", "itm", "bom", "bdato" }

local pin = {}
P.pin = pin

function P.pin_reset()
  for i = 1, #NUMS do pin[NUMS[i]] = 0 end
  for i = 1, #FLAGS do pin[FLAGS[i]] = 0 end
  for i = 1, #CHOICES do pin[CHOICES[i]] = 0 end
end
P.pin_reset()

-- acota todo lo que se usa como bandera o indice (un archivo danado nunca
-- debe provocar un indice fuera de rango)
function P.pin_sanitize(p)
  p = p or pin
  for i = 1, #NUMS do
    local v = p[NUMS[i]]
    if type(v) ~= "number" or v ~= v then p[NUMS[i]] = 0 end
  end
  for i = 1, #FLAGS do
    local v = p[FLAGS[i]]
    p[FLAGS[i]] = (type(v) == "number" and v ~= 0) and 1 or 0
  end
  for i = 1, #CHOICES do
    local v = p[CHOICES[i]]
    if type(v) ~= "number" or v ~= math.floor(v) or v < 0 then v = 0 end
    if CHOICES[i] == "dset" then
      if v >= diams.DIAM_CHOICES then v = 0 end
    elseif v > 1 then
      v = v ~= 0 and 1 or 0
    end
    p[CHOICES[i]] = v
  end
end

-- Copia sobre pin conservando la identidad de la tabla (los formularios la referencian)
function P.pin_assign(src)
  P.pin_reset()
  for k, v in pairs(src) do
    if pin[k] ~= nil then pin[k] = v end
  end
  P.pin_sanitize(pin)
end

local mach_names = { "Bomba", "Turbina" }
local yesno = { "No", "Si" }
local modeI_names = { "hf dado Q", "Q dado H" }
local itB_names = { "Curso", "Secante" }
local itD_names = { "Biseccion", "Secante" }
local method_names = { "Colebrook-White", "Swamee-Jain", "Haaland", "Goudar-Sonnad" }

-- Estado del ultimo calculo
local C, PP, R, X = {}, {}, {}, {}
local LG = MR.lg
local dlist, dlist_n = {}, 0
local tipo = 0

local titles = {
  [0] = "PERDIDAS DADO Q  (A)", "CAUDAL MAXIMO  (B)", "DIAMETRO DE DISENO (D)",
  "BOMBA O TURBINA  (C)", "VALVULA DE CONTROL (F)", "CALIBRAR RUGOSIDAD (E)",
  "DARCY-W. vs HAZEN-W. (I)",
}
P.titles = titles

-- ------------------------------------------------------------------
-- Campos
-- ------------------------------------------------------------------
local function FLD(lab, un, v, s, fl)
  return { label = lab, unit = un, t = pin, k = v, setk = s, flags = fl }
end
local function CHO(lab, key, names, tbl)
  return { label = lab, t = tbl or pin, chk = key, flags = FF_CHOICE, choices = names,
           nchoices = #names }
end
local function F_Q() return FLD("Caudal Q", "l/s", "Q", "sQ", FF_POS) end
local function F_D() return FLD("Diametro D", "mm", "D", "sD", FF_POS) end
local function F_L() return FLD("Longitud L", "m", "L", "sL", FF_POS) end
local function F_KS() return FLD("Rugosidad ks", "mm", "ks", "sks", FF_NONNEG) end
local function F_K() return FLD("Suma K", nil, "K", "sK", FF_NONNEG) end
local function F_NU() return FLD("Viscosidad nu", "m2/s", "nu", "snu", FF_POS) end
local function F_F() return FLD("f dado (opc.)", nil, "f", "sf", FF_POS + FF_OPT) end
local function F_MET() return CHO("Metodo de f", "method", method_names, g_set.h) end
-- v2.1: C_H opcional para arrancar desde Hazen-Williams y metodo de iteracion.
-- Van al final: los casos del curso cargan los campos en orden.
local function F_CH0()
  return { label = "C_H inicio (opc.)", t = pin, k = "CH0", setk = "sCH0",
           flags = FF_RANGE + FF_OPT, lo = 1, hi = 200 }
end
-- Bomba en la linea (A, B y D; Modificaciones JV): (z1 - z2) + HB = hf + hm,
-- con HB dato o HB = eta P/(gamma Q). Van al final del formulario.
local bdato_names = { "Potencia P", "Carga HB" }
local function add_bomba(fl)
  fl[#fl + 1] = CHO("Bomba en la linea", "bom", yesno)
  fl[#fl + 1] = CHO("Dato de la bomba", "bdato", bdato_names)
  fl[#fl + 1] = FLD("Potencia bomba P", "kW", "bP", "sbP", FF_POS + FF_OPT)
  fl[#fl + 1] = { label = "Eficiencia bomba", unit = "0-1", t = pin, k = "bEta", setk = "sbEta",
                  flags = FF_RANGE + FF_OPT, lo = 0.001, hi = 1 }
  fl[#fl + 1] = FLD("Carga HB (dato)", "m", "bHB", "sbHB", FF_ANY + FF_OPT)
  return fl
end

local forms = {}
forms[PT_A] = add_bomba({ F_Q(), F_D(), F_L(), F_KS(), F_K(), F_NU(), F_F(),
  FLD("H sobre punto(opc)", "m", "Hp", "sHp", FF_ANY + FF_OPT), F_MET() })
forms[PT_B] = add_bomba({ FLD("Carga H", "m", "H", "sH", FF_ANY), F_D(), F_L(), F_KS(), F_K(),
  F_NU(), F_F(), F_MET(), F_CH0(), CHO("Iteracion", "itm", itB_names) })
forms[PT_C] = { CHO("Equipo", "mach", mach_names), F_Q(), F_D(), F_L(), F_KS(), F_K(), F_NU(),
  FLD("Desnivel Hs/Ha", "m", "Hs", "sHs", FF_ANY),
  { label = "Eficiencia eta", unit = "0-1", t = pin, k = "eta", setk = "seta",
    flags = FF_RANGE, lo = 0.001, hi = 1 },
  F_F(), FLD("Cota z equipo(opc)", "m", "zb", "szb", FF_ANY + FF_OPT), F_MET() }
forms[PT_D] = { FLD("Caudal diseno Qd", "l/s", "Q", "sQ", FF_POS),
  FLD("Carga H", "m", "H", "sH", FF_ANY), F_L(), F_KS(), F_K(), F_NU(),
  CHO("Lista diametros", "dset", diams.diam_set_names),
  CHO("Valvula control", "valve", yesno), F_MET(), F_CH0(),
  CHO("Iteracion", "itm", itD_names) }
add_bomba(forms[PT_D])
forms[PT_F] = { F_Q(), F_D(), F_L(), F_KS(), F_K(), F_NU(),
  FLD("Carga H", "m", "H", "sH", FF_ANY), F_F(), F_MET() }
forms[PT_E] = { FLD("Cota z1", "m", "z1", "sz1", FF_ANY), FLD("Cota z2", "m", "z2", "sz2", FF_ANY),
  FLD("Presion p1/gamma", "m", "p1", "sp1", FF_ANY),
  FLD("Presion p2/gamma", "m", "p2", "sp2", FF_ANY),
  F_L(), F_D(), F_Q(), F_K(), F_NU() }
forms[PT_I] = { CHO("Calcular", "modeI", modeI_names),
  FLD("Q (modo hf)", "l/s", "Q", "sQ", FF_POS + FF_OPT),
  FLD("H (modo Q)", "m", "H", "sH", FF_POS + FF_OPT),
  F_D(), F_L(), F_KS(), FLD("Suma K (solo DW)", nil, "K", "sK", FF_NONNEG), F_NU(),
  { label = "C_H Hazen-W.", t = pin, k = "CH", setk = "sCH", flags = FF_RANGE, lo = 1, hi = 200 },
  F_MET() }
P.forms = forms

-- ------------------------------------------------------------------
-- Memoria de calculo y resumen: interprete de PERDTXT
-- ------------------------------------------------------------------
local function sv(name, x)
  local id = MR[name]
  assert(id, "memo_run: constante " .. name)
  MR.V[id] = x
end
local function sf(name, cond)
  local id = MR[name]
  assert(id, "memo_run: bandera " .. name)
  MR.msetf(id, cond and true or false)
end
local function b(x) return x ~= nil and x ~= 0 and x ~= false end

-- OR de mascaras de advertencia (sin operadores de bits)
local function warn_or(a, c)
  local r = a or 0
  local f = 1
  while f <= 2048 do
    if H.warn_has(c or 0, f) then r = H.warn_set(r, f) end
    f = f * 2
  end
  return r
end

local function state_of()
  if tipo == PT_A then return R.st
  elseif tipo == PT_F then return R.v and R.v.st
  elseif tipo == PT_C then return R.m and R.m.st
  elseif tipo == PT_B then return R.q and R.q.st
  elseif tipo == PT_D then return R.d and R.d.qmax and R.d.qmax.st
  elseif tipo == PT_I then
    if b(pin.modeI) then return R.q and R.q.st else return R.st end
  end
  return nil
end

local function fill_values()
  local s = state_of()
  local D = PP.D
  MR.memo_reset()
  if tipo == PT_D then D = R.d.D_com end
  sv("V_D", D); sv("V_L", PP.L); sv("V_KS", PP.ks); sv("V_K", PP.sumK)
  sv("V_NU", C.nu); sv("V_G", C.g); sv("V_GAM", C.gamma); sv("V_TOL", C.tol)
  sv("V_H", X.bomb and X.Hef or pin.H); sv("V_QD", pin.Q / 1000); sv("V_KSMM", PP.ks * 1000)
  if s then
    sv("V_Q", s.Q); sv("V_QLS", s.Q * 1000); sv("V_A", s.A); sv("V_V", s.v)
    sv("V_RE", s.Re); sv("V_KSD", s.ksD); sv("V_F", s.f)
    sv("V_INVSF", 1 / math.sqrt(s.f)); sv("V_HV2G", s.hv2g)
    sv("V_HF", s.hf); sv("V_HM", s.hm); sv("V_HT", s.hT); sv("V_LD", s.LD)
    sv("V_HMHF", s.hf > 0 and 100 * s.hm / s.hf or 0)
    sv("V_FIT", s.f_iters)
    sv("V_A37", D > 0 and PP.ks / (3.7 * D) or 0)
    MR.W = s.warn
    sf("G_LAM", s.regime == H.REG_LAMINAR)
    sf("G_TRANS", s.regime == H.REG_TRANSITION)
  end
  sf("G_FIX", PP.f_fixed > 0)
  sf("G_CW", C.method == H.FM_CW)
  sf("G_SJ", C.method == H.FM_SJ)
  sf("G_HA", C.method == H.FM_HAALAND)
  sf("G_GO", C.method == H.FM_GOUDAR)
  sf("G_KPOS", PP.sumK > 0)
  sf("G_WITHQ", tipo == PT_A or tipo == PT_C or tipo == PT_F or (tipo == PT_I and not b(pin.modeI)))
  sf("G_HASD", tipo ~= PT_D)
  if tipo == PT_A then
    sv("V_HP", pin.Hp); sv("V_PH", X.ph); sv("V_PKPA", X.ph * C.gamma / 1000)
    sf("G_HP", b(pin.sHp))
  elseif tipo == PT_B or tipo == PT_I then
    local q = R.q
    if tipo == PT_I and not b(pin.modeI) then q = { iters = 0, solver = -1, st = { warn = 0 }, hw = false,
                                                      hf1 = 0, Q0 = 0 } end
    sv("V_ITER", q.iters or 0)
    sf("G_COURSE", q.solver == H.SOLV_COURSE)
    sf("G_BIS", q.solver == H.SOLV_BISECTION)
    sf("G_DIRECT", q.solver == H.SOLV_DIRECT)
    sf("G_FB", H.warn_has(q.st.warn, H.W_FALLBACK))
    sf("G_PSEC", q.solver == H.SOLV_SECANT)
    sf("G_PREQ", tipo == PT_B and pin.itm == H.IT_SECANT)
    sf("G_PHW", b(q.hw))        -- hw es 0/1: en Lua el 0 es verdadero
    sv("V_CH0", pin.CH0); sv("V_HF1", q.hf1 or 0)
    sv("V_Q0LS", (q.Q0 or 0) * 1000)
    if tipo == PT_I then
      sv("V_CH", pin.CH); sv("V_HW", X.hw); sv("V_ERR", X.err)
      sv("V_QHW", X.Qhw); sv("V_QHWLS", X.Qhw * 1000)
      sf("G_MODEQ", b(pin.modeI))
      if not b(pin.modeI) then
        MR.FL[MR.G_COURSE] = nil
        MR.FL[MR.G_BIS] = nil
      end
    end
  elseif tipo == PT_C then
    local m = R.m
    sv("V_HS", pin.Hs); sv("V_ETA", pin.eta); sv("V_HMACH", m.Hm)
    sv("V_PN", m.Pn); sv("V_PB", m.Pb); sv("V_PNKW", m.Pn / 1000)
    sv("V_PBKW", m.Pb / 1000); sv("V_PBHP", m.Pb / 745.7)
    sv("V_ZB", pin.zb)
    sv("V_COTA", pin.zb + (pin.mach == 0 and m.Hm or -m.Hm))
    sf("G_PUMP", pin.mach == 0)
    sf("G_ZB", b(pin.szb))
  elseif tipo == PT_F then
    sv("V_HV", R.v.hv); sv("V_KV", R.v.Kv)
  elseif tipo == PT_D then
    local d = R.d
    sv("V_ITER", d.iters); sv("V_DEX", d.D_exact * 1000)
    sv("V_DCOM", d.D_com * 1000); sv("V_VP", d.vp)
    sv("V_HFCQ", d.st_com_qd.hf); sv("V_VCQ", d.st_com_qd.v)
    sv("V_EXV", d.st_exact.v); sv("V_EXRE", d.st_exact.Re)
    sv("V_EXF", d.st_exact.f); sv("V_EXHF", d.st_exact.hf)
    sv("V_EXHM", d.st_exact.hm); sv("V_EXHT", d.st_exact.hT)
    local vst = X.val and X.val.st or {}
    sv("V_VALHT", vst.hT or 0); sv("V_VALHV", X.val and X.val.hv or 0)
    sv("V_VALKV", X.val and X.val.Kv or 0); sv("V_VALV", vst.v or 0)
    MR.W = warn_or(MR.W, d.warn)
    sf("G_COURSE", d.qmax.solver == H.SOLV_COURSE)
    sf("G_QSEC", d.qmax.solver == H.SOLV_SECANT)
    sf("G_PSEC", d.solver == H.SOLV_SECANT)
    sf("G_PHW", b(d.hw))
    sf("G_PDFB", b(d.fb))
    sv("V_CH0", pin.CH0); sv("V_D0", d.D0 * 1000)
    sf("G_VP", d.vp > 0)
    sf("G_VAL", X.has_val)
  elseif tipo == PT_E then
    local k = R.k
    sv("V_D", pin.D / 1000); sv("V_Q", pin.Q / 1000)
    sv("V_Z1", pin.z1); sv("V_Z2", pin.z2); sv("V_P1", pin.p1); sv("V_P2", pin.p2)
    sv("V_A", k.A); sv("V_V", k.v); sv("V_HTOT", k.htot)
    sv("V_HM", k.hm); sv("V_HF", k.hf); sv("V_F", k.f); sv("V_RE", k.Re)
    sv("V_SF", math.sqrt(k.f)); sv("V_KS", k.ks); sv("V_KSMM", k.ks * 1000)
    sv("V_KSD", k.ksD)
    MR.W = k.warn
  end
end

-- Carga un caso del curso en el formulario del tipo dado (vals: lista 1-based)
function P.pipe_load_example(t, vals, n)
  if t < 0 or t >= PT_COUNT then return end
  local fl = forms[t]
  for i = 1, n do
    local f = fl[i]
    if not f then break end
    local v = vals[i]
    if f.flags and W.hasf(f.flags, FF_CHOICE) then
      local c = math.floor(v)
      if c >= 0 and c < f.nchoices then
        if f.t == g_set.h and f.chk == "method" and f.t.method ~= c then U.mark_changed() end
        f.t[f.chk] = c
      end
    elseif v <= ex.EX_NONE then
      if f.setk then f.t[f.setk] = 0 end
    else
      f.t[f.k] = v
      if f.setk then f.t[f.setk] = 1 end
    end
  end
end

local BLOG = H.new_log()     -- biseccion de Q con bomba de potencia dada (tipo B)

-- Seccion de la bomba en la linea: se inserta despues del titulo del resumen
-- o de la memoria (los programas de PERDTXT no la traen).
function P.bomba_lines(memo)
  local M = require("ui.memo")
  local keep, kc = {}, {}
  for i = 1, W.view_n do keep[i] = W.view_line[i]; kc[i] = W.view_color[i] end
  local n = W.view_n
  W.view_clear()
  for i = 1, math.min(2, n) do W.view_add(keep[i], kc[i]) end
  local HB, Hef = X.HB, X.Hef
  local st = state_of()
  local Q = (tipo == PT_D) and pin.Q / 1000 or (st and st.Q or 0)
  if not memo then
    W.view_add_val("HB bomba", HB, "m")
    if tipo ~= PT_A then W.view_add_val("H = z1-z2+HB", Hef, "m") end
  else
    M.memo_sec("BOMBA EN LA LINEA")
    M.memo_line(" Energia: (z1 - z2) + HB = hf + hm", C_GRAY)
    if pin.bdato == 0 then
      M.memo_line(M.mfmt(" P = %v kW, eta = %v", pin.bP, pin.bEta), C_FG)
      if X.bpot and tipo == PT_B then
        M.memo_line(" HB depende de Q: biseccion sobre Q con", C_GRAY)
        M.memo_line(" F(Q) = hT(Q) - (z1 - z2) - eta P/(gamma Q)", C_GRAY)
        M.memo_table({ "it", "Q min", "Q max", "Q l/s", "F m" }, 5, BLOG,
          { 1, 1000, 1000, 1000, 1 })
      end
      M.memo_eq("HB", "eta P/(gamma Q)", M.mfmt("%v(%v)/(%v(%v))", pin.bEta, pin.bP * 1000,
        C.gamma, Q), HB, "m")
    else
      M.memo_eq("HB", nil, nil, HB, "m (dato)")
    end
    if tipo ~= PT_A then
      M.memo_eq("H", "(z1 - z2) + HB", M.mfmt("%v + %v", pin.H, HB), Hef, "m")
      M.memo_line(" El calculo sigue con esta H:", C_GRAY)
    elseif b(pin.sHp) then
      M.memo_line(" p/gamma = H punto + HB - v^2/2g - hT", C_GRAY)
    end
  end
  for i = 3, n do W.view_add(keep[i], kc[i]) end
end

local function show(memo)
  fill_values()
  MR.cfg = C
  MR.log = LG
  MR.dlist = dlist
  MR.dlist_n = dlist_n
  MR.listname = function()
    return diams.diam_set_names[pin.dset + 1] or "?"
  end
  MR.memo_show(memo and MR.PROG_MEMO(tipo) or MR.PROG_SUM(tipo))
  if X.bomb then P.bomba_lines(memo) end
end

-- ------------------------------------------------------------------
-- Calculo
-- ------------------------------------------------------------------
local function make_pipe()
  C = {}
  for k, v in pairs(g_set.h) do C[k] = v end
  C.nu = pin.nu
  PP = {
    D = pin.D / 1000, L = pin.L, ks = pin.ks / 1000,
    sumK = b(pin.sK) and pin.K or 0,
    f_fixed = b(pin.sf) and pin.f or 0,
  }
end

-- Devuelve nil si todo bien, o un texto de error
-- Carga de la bomba con el caudal Q (m3/s). -> texto de error o nil, HB
local function bomba_HB(Q)
  if pin.bdato == 0 then
    if not b(pin.sbP) then return "Falta la potencia P de la bomba" end
    if not b(pin.sbEta) then return "Falta la eficiencia de la bomba" end
    return nil, H.hydro_head_from_power(pin.bP * 1000, pin.bEta, Q, C)
  end
  if not b(pin.sbHB) then return "Falta la carga HB de la bomba" end
  return nil, pin.bHB
end

local function compute()
  local e = H.H_OK
  local o = { CH = b(pin.sCH0) and pin.CH0 or 0, solver = pin.itm }
  make_pipe()
  H.hydro_log_clear(LG)
  X = { ph = 0, hw = 0, err = 0, Qhw = 0 }
  R = {}
  X.bomb = b(pin.bom) and (tipo == PT_A or tipo == PT_B or tipo == PT_D)
  X.HB, X.Hef, X.bpot = 0, pin.H, false
  local berr
  if tipo == PT_A then
    R.st = {}
    e = H.hydro_pipe_state(PP, pin.Q / 1000, C, R.st)
    if e == 0 and X.bomb then
      berr, X.HB = bomba_HB(R.st.Q)
      if berr then return berr end
    end
    if e == 0 and b(pin.sHp) then
      X.ph, R.st.warn = H.hydro_pressure_head(pin.Hp, X.HB, R.st.v, R.st.hT, C, R.st.warn)
    end
  elseif tipo == PT_B then
    R.q = {}
    if X.bomb and pin.bdato == 0 then
      if not b(pin.sbP) then return "Falta la potencia P de la bomba" end
      if not b(pin.sbEta) then return "Falta la eficiencia de la bomba" end
      local Qb
      e, Qb, X.HB = H.hydro_qmax_pump(PP, pin.H, pin.bP * 1000, pin.bEta, C, BLOG)
      if e ~= 0 then return H.hydro_err_text(e) end
      X.bpot = true
    elseif X.bomb then
      berr, X.HB = bomba_HB(1)
      if berr then return berr end
    end
    X.Hef = pin.H + X.HB
    if X.bomb and not (X.Hef > 0) then return "H + HB debe ser > 0" end
    e = H.hydro_qmax_o(PP, X.Hef, C, o, R.q, LG)
  elseif tipo == PT_C then
    R.m = {}
    if pin.mach == 0 then
      e = H.hydro_pump(PP, pin.Q / 1000, pin.Hs, pin.eta, C, R.m)
    else
      e = H.hydro_turbine(PP, pin.Q / 1000, pin.Hs, pin.eta, C, R.m)
    end
  elseif tipo == PT_D then
    PP.f_fixed = 0
    dlist = {}
    dlist_n = 0
    if pin.dset == diams.DIAM_CUSTOM then
      for i = 1, diams.DIAM_CUSTOM_MAX do
        if diams.diam_custom[i] > 0 then
          dlist_n = dlist_n + 1
          dlist[dlist_n] = diams.diam_custom[i] / 1000
        end
      end
      if dlist_n == 0 then return "Lista propia vacia (Biblioteca)" end
    else
      local ds = diams.diam_sets[pin.dset + 1]
      dlist_n = ds.n
      for i = 1, dlist_n do dlist[i] = ds.mm[i] / 1000 end
    end
    R.d = {}
    if X.bomb then
      berr, X.HB = bomba_HB(pin.Q / 1000)
      if berr then return berr end
      X.bpot = pin.bdato == 0
    end
    X.Hef = pin.H + X.HB
    if X.bomb and not (X.Hef > 0) then return "H + HB debe ser > 0" end
    e = H.hydro_design_o(PP, pin.Q / 1000, X.Hef, dlist, dlist_n, C, o, R.d, LG)
    if e == 0 and b(pin.valve) then
      PP.D = R.d.D_com
      X.has_val = true          -- si hv < 0 se muestra igual, con su aviso
      X.val = {}
      H.hydro_valve(PP, pin.Q / 1000, X.Hef, C, X.val)
    end
  elseif tipo == PT_F then
    R.v = {}
    e = H.hydro_valve(PP, pin.Q / 1000, pin.H, C, R.v)
  elseif tipo == PT_E then
    PP.f_fixed = 0
    R.k = {}
    e = H.hydro_calibrate(pin.D / 1000, pin.L, pin.Q / 1000, PP.sumK,
      pin.z1 - pin.z2, pin.p1 - pin.p2, C, R.k)
    if e == H.H_ERR_KS_NEG then e = H.H_OK end     -- se muestra con su advertencia
  elseif tipo == PT_I then
    PP.f_fixed = 0
    if pin.modeI == 0 then
      if not b(pin.sQ) then return "Falta Q (modo hf)" end
      R.st = {}
      e = H.hydro_pipe_state(PP, pin.Q / 1000, C, R.st)
      X.hw = H.hydro_hw_hf(pin.Q / 1000, PP.D, PP.L, pin.CH)
      X.err = 100 * (X.hw - R.st.hf) / R.st.hf
      X.Qhw = 0
    else
      if not b(pin.sH) then return "Falta H (modo Q)" end
      R.q = {}
      e = H.hydro_qmax(PP, pin.H, C, R.q, LG)
      X.Qhw = H.hydro_hw_q(pin.H, PP.D, PP.L, pin.CH)
      X.err = 100 * (X.Qhw - R.q.st.Q) / R.q.st.Q
      X.hw = 0
    end
  end
  if e ~= 0 then return H.hydro_err_text(e) end
  return nil
end

-- ------------------------------------------------------------------
-- Bucle de resultado: resumen <-> memoria
-- ------------------------------------------------------------------
local function seg()
  return { L = 0, jump = 0, hloc = 0, hfr = 0, vh = 0, name = "" }
end

-- LE y LP del tubo simple (tipos A, B, C, D y F; en E e I no aplica)
local function pipe_graph()
  local s = { seg(), seg() }
  local st = state_of()
  local E0, Eend, n, tank2 = 0, 0, 1, true
  if tipo == PT_E or tipo == PT_I or not st then
    U.ui_alert("Grafico", "No aplica a este tipo", "de problema", C_GRAY)
    return
  end
  s[1].L = PP.L
  s[1].hloc = st.hm
  s[1].hfr = st.hf
  s[1].vh = st.hv2g
  s[1].name = "L"
  if tipo == PT_A then
    E0 = b(pin.sHp) and pin.Hp or (st.hT - X.HB)
    tank2 = false
  elseif tipo == PT_B or tipo == PT_D then
    E0 = pin.H
  elseif tipo == PT_C then
    if pin.mach == 0 then            -- bomba al inicio
      E0 = 0
      s[1].jump = R.m.Hm
      Eend = pin.Hs
    else                              -- turbina al final
      E0 = pin.Hs
      s[2].L = 0
      s[2].jump = -R.m.Hm
      s[2].vh = st.hv2g
      s[2].name = "T"
      n = 2
    end
  elseif tipo == PT_F then            -- valvula al final
    E0 = pin.H
    s[2].jump = -R.v.hv
    s[2].vh = st.hv2g
    s[2].name = "V"
    n = 2
  end
  if X.bomb then s[1].jump = s[1].jump + X.HB end
  if tank2 and tipo ~= PT_C then Eend = 0 end
  GR.graph_run(titles[tipo], E0, s, n, Eend, tank2)
end

local function result_loop()
  local fk_sum = { "MEMORIA", "GRAFICO", "GUARDAR", "", "VOLVER" }
  local fk_memo = { "RESUMEN", "", "", "", "VOLVER" }
  local memo = false
  while true do
    show(memo)
    local k = W.view_run(titles[tipo], memo and fk_memo or fk_sum)
    if k == K_F1 then
      memo = not memo
    elseif k == K_F2 then
      pipe_graph()
    elseif k == K_F3 and not memo then
      require("scr.cases").case_save_ui(tipo)
    elseif k == K_MODE then
      settings()
    else
      return
    end
  end
end

local function has_f(t)
  return t == PT_A or t == PT_B or t == PT_C or t == PT_F
end

local cur = {}
for i = 0, PT_COUNT - 1 do cur[i] = 0 end

function P.reset_cursors() for i = 0, PT_COUNT - 1 do cur[i] = 0 end end

function P.scr_pipe_run(t, autocalc)
  if t < 0 or t >= PT_COUNT then return end
  tipo = t
  if not b(pin.snu) then pin.nu = g_set.h.nu; pin.snu = 1 end
  if not b(pin.sK) then pin.K = 0; pin.sK = 1 end
  local fm = {
    title = titles[t], f = forms[t], n = #forms[t], cur = cur[t],
    fk = { "MAT", "SUMA K", "FLUIDO", has_f(t) and "CALC f" or "AJUSTES", "CALC" },
  }
  if t == PT_C then fm.hint = "Hs = z2-z1 (bomba); Ha = z1-z2 (turb.)" end
  local m0 = g_set.h.method
  while true do
    local k
    if autocalc then
      autocalc = false
      k = K_F5
    else
      k = W.form_run(fm)
    end
    if k == K_QUIT or k == K_CLEAR then break end
    if k == K_F1 then lib().lib_pick_material()
    elseif k == K_F2 then lib().lib_sumador()
    elseif k == K_F3 then lib().lib_pick_fluid(0)
    elseif k == K_F4 and has_f(t) then
      require("scr.scr_fric").scr_fric(pin, "f", "sf")
    elseif k == K_F4 or k == K_MODE then settings()
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
    if U.quit then break end
  end
  cur[t] = fm.cur
  if g_set.h.method ~= m0 then U.mark_changed() end
end

function P.scr_pipe(t) P.scr_pipe_run(t, false) end

return P
