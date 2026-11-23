-- scr_fric.lua - v2.0 "Calcular f": factor de friccion solo (port de scr_fric.c).
-- Dos modos (F2 MODO): 1 Re y ks/D (o ks y D en mm); 2 datos de la tuberia
-- (comparte pin con la tuberia simple). Resultado: regimen, zona, f con el
-- metodo de Ajustes y la tabla de los 4 metodos. [USAR f] devuelve el valor al
-- formulario que abrio esta pantalla.
--
-- API: F.scr_fric(dest_tabla, dest_clave, dest_clave_set)  (los tres nil desde el menu)
--      F.scr_fric_run(dest_tabla, k, ks, autocalc)
--      F.fric_save() -> tabla {fi=, pin=}   F.fric_load(t) -> bool   F.fric_preset(k)
local U = require("ui.ui")
local W = require("ui.widgets")
local nf = require("ui.numfmt")
local H = require("core.hydro")
local MR = require("memo_run")

local F = {}
local g_set = U.g_set
local FF_POS, FF_NONNEG, FF_OPT, FF_CHOICE = W.FF_POS, W.FF_NONNEG, W.FF_OPT, W.FF_CHOICE
local K_ENTER, K_CLEAR, K_QUIT, K_MODE, K_NONE = U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE, U.K_NONE
local K_F1, K_F2, K_F3, K_F4, K_F5 = U.K_F1, U.K_F2, U.K_F3, U.K_F4, U.K_F5
local C_OK, C_WARN, C_ERR = U.C_OK, U.C_WARN, U.C_ERR

local function pipe() return require("scr.scr_pipe") end
local function lib() return require("scr.scr_lib") end
local function settings() require("scr.screens").scr_settings() end
local pin = pipe().pin

local function new_fi()
  return { Re = 0, ksd = 0, ks1 = 0, D1 = 0, v = 0, sRe = 0, sksd = 0, sks1 = 0, sD1 = 0,
           sv = 0, mode = 0 }
end
local fi = new_fi()
local FI_KEYS = { "Re", "ksd", "ks1", "D1", "v", "sRe", "sksd", "sks1", "sD1", "sv", "mode" }
F.fi = fi

local mode_names = { "Re y ks/D", "Datos tuberia" }
local method_names = { "Colebrook-White", "Swamee-Jain", "Haaland", "Goudar-Sonnad" }

local function F_MODE()
  return { label = "Modo", t = fi, chk = "mode", flags = FF_CHOICE, choices = mode_names,
           nchoices = 2 }
end
local function F_MET()
  return { label = "Metodo de f", t = g_set.h, chk = "method", flags = FF_CHOICE,
           choices = method_names, nchoices = 4 }
end

local f_m1 = {
  F_MODE(),
  { label = "Reynolds Re", t = fi, k = "Re", setk = "sRe", flags = FF_POS },
  { label = "ks/D (o ks y D)", t = fi, k = "ksd", setk = "sksd", flags = FF_NONNEG + FF_OPT },
  { label = "ks (opc.)", unit = "mm", t = fi, k = "ks1", setk = "sks1", flags = FF_NONNEG + FF_OPT },
  { label = "D (opc.)", unit = "mm", t = fi, k = "D1", setk = "sD1", flags = FF_POS + FF_OPT },
  F_MET(),
}
local f_m2 = {
  F_MODE(),
  { label = "Caudal Q (o v)", unit = "l/s", t = pin, k = "Q", setk = "sQ", flags = FF_POS + FF_OPT },
  { label = "Velocidad (opc.)", unit = "m/s", t = fi, k = "v", setk = "sv", flags = FF_POS + FF_OPT },
  { label = "Diametro D", unit = "mm", t = pin, k = "D", setk = "sD", flags = FF_POS },
  { label = "Rugosidad ks", unit = "mm", t = pin, k = "ks", setk = "sks", flags = FF_NONNEG },
  { label = "Viscosidad nu", unit = "m2/s", t = pin, k = "nu", setk = "snu", flags = FF_POS },
  F_MET(),
}

local fm_now

local function set_mode_form(fm)
  fm.f = fi.mode ~= 0 and f_m2 or f_m1
  fm.n = #fm.f
  if fm.cur >= fm.n then fm.cur = 0 end
end

-- si cambia el modo desde el campo, el formulario se rehace
local function mode_changed()
  if fm_now and fm_now.f ~= (fi.mode ~= 0 and f_m2 or f_m1) then set_mode_form(fm_now) end
end

local C = {}
local LG = MR.lg
local T = {}

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

-- nil si todo bien, o un texto de error
local function compute()
  local Re, ksd, D, ks, A, v, Q = 0, 0, 0, 0, 0, 0, 0
  local ksdin, hasv = false, false
  C = {}
  for k, x in pairs(g_set.h) do C[k] = x end
  if fi.mode == 0 then
    Re = fi.Re
    if b(fi.sksd) then
      ksd = fi.ksd
    elseif b(fi.sks1) and b(fi.sD1) then
      ksd = fi.ks1 / fi.D1
      ksdin = true
    else
      return "Falta ks/D (o ks y D)"
    end
  else
    D = pin.D / 1000
    ks = pin.ks / 1000
    C.nu = pin.nu
    A = H.hydro_area(D)
    if b(fi.sv) then
      v = fi.v
      Q = v * A
      hasv = true
    elseif b(pin.sQ) then
      Q = pin.Q / 1000
      v = Q / A
    else
      return "Falta Q o v"
    end
    Re = v * D / C.nu
    ksd = ks / D
  end
  H.hydro_log_clear(LG)
  T = {}
  local e = H.hydro_fric_all(Re, ksd, C, T, LG)
  if e ~= 0 then return H.hydro_err_text(e) end

  MR.memo_reset()
  local fs = T.f[C.method]
  sv("V_RE", Re)
  sv("V_KSD", ksd)
  sv("V_A37", ksd / 3.7)
  sv("V_FCW", T.f[H.FM_CW])
  sv("V_FSJ", T.f[H.FM_SJ])
  sv("V_FHA", T.f[H.FM_HAALAND])
  sv("V_FGO", T.f[3])
  sv("V_DSJ", T.dpct[H.FM_SJ])
  sv("V_DHA", T.dpct[H.FM_HAALAND])
  sv("V_DGO", T.dpct[3])
  sv("V_FSEL", fs)
  sv("V_INVSF", 1 / math.sqrt(fs))
  sv("V_FIT", T.iters)
  local kp = ksd * Re * math.sqrt(T.f[H.FM_CW] / 8)
  sv("V_KPLUS", kp)
  sv("V_D", D)
  sv("V_KS", ks)
  sv("V_NU", C.nu)
  sv("V_Q", Q)
  sv("V_QLS", Q * 1000)
  sv("V_A", A)
  sv("V_V", v)
  sv("V_KSMM", fi.ks1)
  sv("V_DMM", fi.D1)
  sf("G_FMODE2", fi.mode ~= 0)
  sf("G_FHASV", hasv)
  sf("G_FKSDIN", ksdin)
  sf("G_LAM", T.regime == H.REG_LAMINAR)
  sf("G_TRANS", T.regime == H.REG_TRANSITION)
  sf("G_CW", C.method == H.FM_CW)
  sf("G_SJ", C.method == H.FM_SJ)
  sf("G_HA", C.method == H.FM_HAALAND)
  sf("G_GO", C.method == 3)
  sf("G_ZSMOOTH", kp < 5)
  sf("G_ZTRANS", kp >= 5 and kp <= 70)
  sf("G_ZROUGH", kp > 70)
  sf("G_OCW", b(T.out[H.FM_CW]))
  sf("G_OSJ", b(T.out[H.FM_SJ]))
  sf("G_OHA", b(T.out[H.FM_HAALAND]))
  sf("G_OGO", b(T.out[3]))
  MR.cfg = C
  MR.log = LG
  return nil
end

-- Devuelve true si se uso [USAR f]. dest = {t=, k=, sk=} o nil
local function result_loop(dest)
  local fk_sum = { "MEMORIA", dest and "USAR f" or "", "GUARDAR", "", "VOLVER" }
  local fk_memo = { "RESUMEN", "", "", "", "VOLVER" }
  local memo = false
  while true do
    MR.memo_show(memo and MR.PROG_X(MR.XP_FRIC_MEMO) or MR.PROG_X(MR.XP_FRIC_SUM))
    local k = W.view_run("FACTOR DE FRICCION f", memo and fk_memo or fk_sum)
    if k == K_F1 then
      memo = not memo
    elseif k == K_F2 and not memo and dest then
      dest.t[dest.k] = MR.V[MR.V_FSEL]
      if dest.sk then dest.t[dest.sk] = 1 end
      U.ui_alert("USAR f", "Se copio al formulario:",
        "f = " .. nf.fmt_real(dest.t[dest.k], g_set.dec), C_OK)
      return true
    elseif k == K_F3 and not memo then
      require("scr.cases").case_save_ui(require("scr.cases").KT_FRIC)
    elseif k == K_MODE then
      settings()
      compute()               -- el metodo pudo cambiar
    elseif k == K_F5 or k == K_CLEAR or k == K_QUIT then
      return false
    end
    if U.quit then return false end
  end
end

local cur = 0

function F.reset_cursors() cur = 0 end

function F.scr_fric_run(dt, dk, dsk, autocalc)
  local dest = dt and { t = dt, k = dk, sk = dsk } or nil
  local m0 = g_set.h.method
  if not b(pin.snu) then pin.nu = g_set.h.nu; pin.snu = 1 end
  local fm = { title = "FACTOR DE FRICCION f", cur = cur,
               fk = { "MAT", "MODO", "FLUIDO", "AJUSTES", "CALC" },
               hint = "F2 cambia el modo de entrada", on_commit = mode_changed }
  set_mode_form(fm)
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
    if k ~= K_NONE then
      if k == K_F1 then
        if fi.mode ~= 0 then lib().lib_pick_material()
        else fm.msg = "MAT: solo en modo datos de tuberia" end
        fm.msg_color = C_WARN
      elseif k == K_F2 then
        fi.mode = fi.mode == 0 and 1 or 0
        fm.cur = 0
        set_mode_form(fm)
      elseif k == K_F3 then
        if fi.mode ~= 0 then lib().lib_pick_fluid(0)
        else fm.msg = "FLUIDO: solo en modo datos de tuberia" end
        fm.msg_color = C_WARN
      elseif k == K_F4 or k == K_MODE then
        settings()
      elseif k == K_F5 or k == K_ENTER then
        if W.form_check(fm) then
          local err = compute()
          if err then
            fm.msg = err
            fm.msg_color = C_ERR
          elseif result_loop(dest) or U.quit then
            break
          end
        end
      end
    end
    if U.quit then break end
  end
  cur = fm.cur
  if g_set.h.method ~= m0 then U.mark_changed() end
end

function F.scr_fric(dt, dk, dsk) F.scr_fric_run(dt, dk, dsk, false) end

-- ---- Mis casos: modo, Re, ks/D... y los datos de tuberia (pin) ----
function F.fric_save()
  local S = require("scr.store")
  return { fi = S.deep_copy(fi), pin = S.deep_copy(pin) }
end

function F.fric_load(t)
  if type(t) ~= "table" or type(t.fi) ~= "table" or type(t.pin) ~= "table" then return false end
  local nf0 = new_fi()
  for i = 1, #FI_KEYS do
    local v = t.fi[FI_KEYS[i]]
    fi[FI_KEYS[i]] = type(v) == "number" and v == v and v or nf0[FI_KEYS[i]]
  end
  fi.mode = fi.mode ~= 0 and 1 or 0
  for _, key in ipairs({ "sRe", "sksd", "sks1", "sD1", "sv" }) do
    fi[key] = fi[key] ~= 0 and 1 or 0
  end
  pipe().pin_assign(t.pin)
  return true
end

-- ---- Casos del curso F-01 a F-05 (prompt v2, sec. 8.5) ----
function F.fric_preset(k)
  local re = { [0] = 20000, 200000, 0, 455180, 0 }
  local kd = { [0] = 1e-4, 1.5e-4, 0, 7.5e-6, 0 }
  local n0 = new_fi()
  for i = 1, #FI_KEYS do fi[FI_KEYS[i]] = n0[FI_KEYS[i]] end
  if k == 2 or k == 4 then                 -- datos de tuberia
    fi.mode = 1
    pin.Q = (k == 2) and 200 or 0.02
    pin.D = (k == 2) and 285.75 or 20
    pin.ks = (k == 2) and 0.0015 or 0
    pin.nu = 1e-6
    pin.sQ, pin.sD, pin.sks, pin.snu = 1, 1, 1, 1
  else
    fi.Re = re[k]
    fi.ksd = kd[k]
    fi.sRe, fi.sksd = 1, 1
  end
end

return F
