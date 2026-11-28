-- screens.lua - Menus y pantallas de PERDIDAS: menu principal, Ajustes, Ayuda,
-- Acerca de, casos del curso (port de screens.c). FLUJOS reutiliza scr_settings
-- y scr_about.
--
-- API: Sc.scr_main(), Sc.scr_settings(), Sc.scr_about(), Sc.method_names,
--      Sc.course_cases()
local U = require("ui.ui")
local W = require("ui.widgets")
local nf = require("ui.numfmt")
local H = require("core.hydro")
local MR = require("memo_run")
local ex = require("data.examples")
local S = require("scr.store")
local Pipe = require("scr.scr_pipe")
local Fric = require("scr.scr_fric")
local Net = require("scr.scr_net")
local Tanks = require("scr.scr_tanks")
local Orig = require("scr.scr_orig")
local Lib = require("scr.scr_lib")
local Cases = require("scr.cases")

local Sc = {}
local g_set = U.g_set
local FF_RANGE, FF_INT, FF_CHOICE = W.FF_RANGE, W.FF_INT, W.FF_CHOICE
local K_ENTER, K_CLEAR, K_QUIT, K_MODE, K_F1, K_F5 =
  U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE, U.K_F1, U.K_F5
local C_TITLE, C_FG, C_GRAY, C_WARN, C_ERR, C_OK = U.C_TITLE, U.C_FG, U.C_GRAY, U.C_WARN, U.C_ERR, U.C_OK
local HELP_COUNT_UI = 7        -- temas de tuberias en PERDTXT (0..6) + 7: factor de friccion f
local APP_VERSION = "1.2"

Sc.method_names = { "Colebrook-White", "Swamee-Jain", "Haaland", "Goudar-Sonnad" }
local method_names = Sc.method_names

-- ==================================================================
-- Ajustes (MODE desde cualquier pantalla)
-- ==================================================================
local yesno2 = { "No", "Si" }
local mano_names = { "(S-1) g h fisico", "S g h examen" }
local set_cur = 0

local function RNG(label, unit, t, k, lo, hi)
  return { label = label, unit = unit, t = t, k = k, flags = FF_RANGE, lo = lo, hi = hi }
end

function Sc.scr_settings()
  local old = S.copy_settings(g_set)
  local h = g_set.h
  local tmp = { dec = g_set.dec }
  local f = {
    { label = "Metodo de f", t = h, chk = "method", flags = FF_CHOICE, choices = method_names,
      nchoices = 4 },
    RNG("g", "m/s2", h, "g", 1, 20),
    RNG("gamma", "N/m3", h, "gamma", 1000, 20000),
    RNG("nu", "m2/s", h, "nu", 1e-8, 1e-3),
    { label = "Decimales", t = tmp, k = "dec", flags = FF_INT, lo = 0, hi = W.DEC_MAX },
    RNG("Tolerancia iter.", "m", h, "tol", 1e-9, 1),
    RNG("Presion de vapor", "Pa", h, "pv", 0, 101325),
    RNG("v minima aviso", "m/s", h, "v_min", 0, 100),
    RNG("v maxima aviso", "m/s", h, "v_max", 0, 100),
    RNG("L/D despreciable", nil, h, "ld_limit", 1, 1e6),
    RNG("Aviso hm/hf", nil, h, "hm_ratio", 0, 100),
    RNG("Re laminar <", nil, h, "re_lam", 100, 10000),
    RNG("Re turbulento >", nil, h, "re_turb", 100, 100000),
    -- v2.0
    RNG("rho del aire", "kg/m3", g_set, "rho_air", 0.05, 5),
    RNG("nu del aire", "m2/s", g_set, "nu_air", 1e-7, 1e-3),
    { label = "Empuje con aire", t = g_set, chk = "buoy", flags = FF_CHOICE, choices = yesno2,
      nchoices = 2 },
    RNG("Cd vertedores", nil, g_set, "cd_weir", 0.1, 1.5),
    RNG("km/h por nudo", nil, g_set, "knot", 1, 3),
    { label = "Manometro", t = g_set, chk = "mano", flags = FF_CHOICE, choices = mano_names,
      nchoices = 2 },
    -- Modificaciones JV: cada paso de tuberias redondeado a 3 decimales
    { label = "Redondeo a mano", t = h, chk = "r3", flags = FF_CHOICE,
      choices = { "No", "Si (3 dec.)" }, nchoices = 2 },
  }
  local fm = { title = "AJUSTES", f = f, n = #f, cur = set_cur,
               fk = { "DEFECTO", "", "", "", "LISTO" },
               hint = "Cambios se guardan con el documento" }
  while true do
    local k = W.form_run(fm)
    g_set.dec = tmp.dec
    if k == K_QUIT then break end
    if k == K_F1 then
      if U.ui_alert("Ajustes", "Restaurar los valores", "por defecto?", C_WARN) then
        S.settings_default(g_set)
        tmp.dec = g_set.dec
      end
    elseif k == K_F5 or k == K_CLEAR or k == K_MODE or k == K_ENTER then
      if not S.settings_valid(g_set) then
        fm.msg = "Revise: Re turb > Re lam, vmax > vmin"
        fm.msg_color = C_ERR
      else
        break
      end
    end
  end
  set_cur = fm.cur
  if not S.settings_valid(g_set) then S.assign_settings(g_set, old) end
  if S.sig(old) ~= S.sig(g_set) then U.mark_changed() end
end

-- ==================================================================
-- Ayuda / Acerca de
-- ==================================================================
function Sc.scr_about()
  local fk = { "", "", "", "", "VOLVER" }
  local flujos = W.APP_NAME == "FLUJOS"
  W.view_clear()
  W.view_add(W.APP_NAME .. " v" .. APP_VERSION, C_TITLE)
  W.view_add(flujos and "Arrastre, vertedores y canales" or "Perdidas de energia en tuberias", C_FG)
  W.view_add("+ Estatica y dinamica de fluidos", C_FG)
  W.view_add("IC-0605 Mecanica de Fluidos, UCR", C_FG)
  W.view_add("Adrian Castro Ramirez", C_FG)
  W.view_add_sep()
  W.view_add("Port a TI-Nspire CX II CAS (Lua 5.1).", C_GRAY)
  W.view_add("Un solo documento con dos programas:", C_GRAY)
  W.view_add("PERDIDAS (tuberias) y FLUJOS (flujos", C_GRAY)
  W.view_add("externos). Comparten ajustes y Mis", C_GRAY)
  W.view_add("casos; se guardan con el documento", C_GRAY)
  W.view_add("(ctrl+S).", C_GRAY)
  W.view_add_sep()
  W.view_add(" Memoria Lua: " .. nf.fmt_int(U.ui_free_ram()) .. " B", C_GRAY)
  W.view_run("ACERCA DE", fk)
end

local fnames = {
  [0] = "F-01 f: Re 20000, ks/D 1E-4 (ej. 3a)",
  "F-02 f: Re 2E5, ks/D 1.5E-4 (ej. 3b)",
  "F-03 f: 200 l/s, 285.75 mm (2025 P2)",
  "F-04 f: Re 455180, PVC 200 mm",
  "F-05 f: laminar, 20 mm, 0.02 l/s",
}

local cc_cur = 0
function Sc.course_cases()
  local NE = ex.EXAMPLES
  while true do
    for i = 0, NE - 1 do W.list_line[i] = ex.examples[i + 1].name end
    for i = 0, 4 do W.list_line[NE + i] = fnames[i] end
    local r, k = W.list_pick("CASOS DEL CURSO", "ENTER carga los datos y calcula", NE + 5, cc_cur, nil)
    if r < 0 or k ~= K_ENTER then return end
    cc_cur = r
    if r >= NE then
      Fric.fric_preset(r - NE)
      Fric.scr_fric_run(nil, nil, nil, true)
    else
      local e = ex.examples[r + 1]
      if e.tipo == ex.PT_COUNT then
        Net.scr_net_example(e.n)
      else
        Pipe.pipe_load_example(e.tipo, e.vals, e.n)
        Pipe.scr_pipe_run(e.tipo, true)
      end
    end
    if U.quit then return end
  end
end

local help_menu = {
  title = "AYUDA", n = 10, cur = 0,
  items = { "Uso y teclas", "Tipos de problema", "Formulas", "Potencia bruta y neta",
            "Suma K y fuentes de datos", "Advertencias", "Erratas del material",
            "Factor de friccion f", "Casos del curso (cargar)", "Acerca de" },
}

-- Vuelve los cursores de los menus y listas al principio (para las pruebas)
function Sc.reset_cursors()
  help_menu.cur, cc_cur, set_cur = 0, 0, 0
  Lib.reset_cursors()
  Pipe.reset_cursors()
  Fric.reset_cursors()
  Net.reset_cursors()
  Tanks.reset_cursors()
  Orig.reset_cursors()
end

local function scr_help()
  local fk = { "", "", "", "", "VOLVER" }
  while not U.quit do
    local r = W.menu_run(help_menu)
    if r == W.MENU_BACK or r == W.MENU_QUIT then return end
    if r == W.MENU_MODE then
      Sc.scr_settings()
    elseif r <= HELP_COUNT_UI then
      if not MR.help_topic(r) then
        U.ui_alert("Ayuda", "Falta el modulo de textos.", "Regenere src/gen/perdtxt.lua", C_ERR)
      else
        W.view_run("AYUDA", fk)
      end
    elseif r == HELP_COUNT_UI + 1 then
      Sc.course_cases()
    else
      Sc.scr_about()
    end
  end
end

-- ==================================================================
-- Menus
-- ==================================================================
local pipe_menu = {
  title = "TUBERIA SIMPLE", n = 8, cur = 0,
  items = { "Perdidas dado el caudal      (A)", "Caudal maximo / comprobacion (B)",
            "Diametro de diseno           (D)", "Bomba o turbina: carga y P   (C)",
            "Valvula de control           (F)", "Calibrar rugosidad           (E)",
            "Darcy-W. vs Hazen-Williams   (I)", "f: factor de friccion" },
}

local function scr_pipe_menu()
  while not U.quit do
    local r = W.menu_run(pipe_menu)
    if r == W.MENU_BACK or r == W.MENU_QUIT then return end
    if r == W.MENU_MODE then
      Sc.scr_settings()
    elseif r == Pipe.PT_COUNT then
      Fric.scr_fric(nil, nil, nil)
    else
      Pipe.scr_pipe(r)
    end
  end
end

-- En la Nspire ambos programas viven en el mismo documento: "Flujos externos"
-- abre FLUJOS directamente (en la TI-84 avisaba de abrir el otro programa).
local function ext_flujos()
  local ok, m = pcall(require, "scr.flujos")
  if ok and type(m) == "table" and type(m.flujos_main) == "function" then
    local prev = W.APP_NAME
    W.APP_NAME = "FLUJOS"
    m.flujos_main()
    W.APP_NAME = prev
  else
    U.ui_alert("Flujos externos", "Elija FLUJOS en el menu inicial",
      "(arrastre, vertedores y canales)", C_TITLE)
  end
end

-- "Salir": en Nspire no se puede cerrar el documento; se marcan los cambios
-- y se avisa de que se guarden con ctrl+S.
local function salir_aviso()
  U.mark_changed()
  U.ui_alert("Datos guardados", "Guarde el documento (ctrl+S) para",
    "conservar casos y ajustes.", C_OK)
end
Sc.salir_aviso = salir_aviso

local function ext_fluidos()
  local ok, m = pcall(require, "scr.fluidos")
  if ok and type(m) == "table" then m.fluidos_main()
  else U.ui_alert("Estatica y dinamica", "Modulo no disponible", nil, C_ERR) end
end

local main_menu = {
  title = "MENU PRINCIPAL", n = 12, cur = 0,
  items = { "Tuberia simple", "Sistemas (serie / paralelo)", "Calcular f (solo f)",
            "Flujos externos (FLUJOS)", "Estatica y dinamica", "Biblioteca", "Mis casos", "Ajustes",
            "Ayuda / Acerca de", "Tres tanques (nudo)", "Mi programa original",
            "Salir" },
}

function Sc.reset_menus()
  main_menu.cur, pipe_menu.cur = 0, 0
  Sc.reset_cursors()
end

function Sc.scr_main()
  while not U.quit do
    local r = W.menu_run(main_menu)
    if r == W.MENU_QUIT then return end
    if r == W.MENU_BACK then
      if U.ui_alert("Salir", "Desea salir de " .. W.APP_NAME .. "?", nil, C_TITLE) then
        salir_aviso()
        return
      end
    elseif r == W.MENU_MODE or r == 7 then Sc.scr_settings()
    elseif r == 0 then scr_pipe_menu()
    elseif r == 1 then Net.scr_net()
    elseif r == 2 then Fric.scr_fric(nil, nil, nil)
    elseif r == 3 then ext_flujos()
    elseif r == 4 then ext_fluidos()
    elseif r == 5 then Lib.scr_library()
    elseif r == 6 then Cases.scr_cases()
    elseif r == 8 then scr_help()
    elseif r == 9 then Tanks.scr_tanks()
    elseif r == 10 then Orig.scr_orig()
    elseif r == 11 then
      salir_aviso()
      return
    end
  end
end

return Sc
