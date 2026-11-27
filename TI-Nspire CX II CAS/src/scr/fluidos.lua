-- fluidos.lua - Submenu "ESTATICA Y DINAMICA" (v1.1 Nspire): ejercicios de examen de
-- estatica de fluidos (scr.scr_stat) y dinamica de fluidos (scr.scr_dyn) con memoria de
-- calculo paso a paso. Se abre desde el menu principal de PERDIDAS.
--
-- API: Fl.fluidos_main()
local U = require("ui.ui")
local W = require("ui.widgets")
local F = require("scr.flu_util")

local Fl = {}
local C_GRAY, C_FG, C_TITLE = U.C_GRAY, U.C_FG, U.C_TITLE

local function bind()
  local ok, C = pcall(require, "scr.cases")
  if ok and type(C) == "table" and C.bind_kinds then C.bind_kinds() end
end

local function help()
  W.view_clear()
  W.view_add("ESTATICA Y DINAMICA (v1.1)", C_TITLE)
  W.view_add_sep()
  W.view_add("ESTATICA DE FLUIDOS", C_TITLE)
  W.view_add(" E1 Viscosidad: placa, cojinete, rampa", C_FG)
  W.view_add(" E2 Manometria en serie", C_FG)
  W.view_add(" E3 Superficies planas y compuerta L", C_FG)
  W.view_add(" E4 Superficies curvas y semicilindro", C_FG)
  W.view_add(" E5 Flotacion y estabilidad", C_FG)
  W.view_add(" E6 Equilibrio relativo", C_FG)
  W.view_add("", C_FG)
  W.view_add("DINAMICA DE FLUIDOS", C_TITLE)
  W.view_add(" D1 Perfiles de velocidad (Q, alfa, beta)", C_FG)
  W.view_add(" D2 Continuidad, descarga y Bernoulli", C_FG)
  W.view_add(" D3 Cantidad de movimiento (codo, chorros)", C_FG)
  W.view_add(" D4 Tanque no permanente (Qe y Qs)", C_FG)
  W.view_add("", C_FG)
  W.view_add("Unidades: pantalla en mm, cm, l, kPa, rpm;", C_GRAY)
  W.view_add("los calculos van en SI (m, s, N, Pa).", C_GRAY)
  W.view_add("Cada resultado tiene MEMORIA (F1) paso a", C_GRAY)
  W.view_add("paso y GUARDAR (F3) en Mis casos.", C_GRAY)
  W.view_add("Las expresiones usan t, y o r (ej. 0.1*sin(t)).", C_GRAY)
  W.view_add("Ejemplos de examen: en cada submenu.", C_GRAY)
  W.view_run("AYUDA", { "", "", "", "", "VOLVER" })
end

local m = { title = "ESTATICA Y DINAMICA", n = 3, cur = 0,
  items = { "Estatica de fluidos", "Dinamica de fluidos", "Ayuda" } }

function Fl.fluidos_main()
  bind()
  while not U.quit do
    local r = W.menu_run(m)
    if r == W.MENU_BACK or r == W.MENU_QUIT then return end
    if r == W.MENU_MODE then F.scr_settings()
    elseif r == 0 or r == 1 then
      local ok, mod = pcall(require, r == 0 and "scr.scr_stat" or "scr.scr_dyn")
      local fn = ok and type(mod) == "table" and (r == 0 and mod.scr_stat_menu or mod.scr_dyn_menu)
      if fn then fn() else U.ui_alert("Estatica y dinamica", "Modulo no disponible", nil, U.C_ERR) end
    else help() end
  end
end

return Fl
