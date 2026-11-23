platform.apiLevel = '2.4'

-- main.lua - Punto de entrada: eventos on.*, corrutina, on.save/on.restore y menu
-- inicial PERDIDAS / FLUJOS. La logica corre en una corrutina (ui/rt.lua).
local rt = require("ui.rt")
local U = require("ui.ui")
local W = require("ui.widgets")

local store = require("scr.store")   -- ajustes (U.g_set), validacion y empaque

-- Carga un modulo de pantallas; devuelve el modulo o nil + mensaje
local function load_mod(name)
  local ok, m = pcall(require, name)
  if ok and type(m) == "table" then return m end
  return nil, ok and "no devolvio una tabla" or tostring(m)
end

-- Llama m[fname]() si existe; si no, avisa "pendiente"
local function run_screen(modname, fname, label)
  local m, err = load_mod(modname)
  if m and type(m[fname]) == "function" then
    m[fname]()
    return true
  end
  local msg = err and (err:find("modulo no encontrado", 1, true) and "pendiente" or err)
  U.ui_alert(label, "Modulo " .. modname .. ": " .. (msg or "pendiente"),
    "Disponible en una fase posterior.", U.C_WARN)
  return false
end

local function salir()
  U.quit = false
  U.mark_changed()
  U.ui_alert("Datos guardados", "Guarde el documento (ctrl+S) para",
    "conservar casos y ajustes.", U.C_OK)
end

local function app_main()
  local m = {
    title = "PERDIDAS / FLUJOS",
    items = { "PERDIDAS - tuberias, redes y perdidas", "FLUJOS - arrastre, vertedores, canales",
              "Salir (guardar)" },
    n = 3, cur = 0,
  }
  while true do
    local r = W.menu_run(m)
    if r == 0 then
      W.APP_NAME = "PERDIDAS"
      run_screen("scr.screens", "scr_main", "PERDIDAS")
    elseif r == 1 then
      W.APP_NAME = "FLUJOS"
      run_screen("scr.flujos", "flujos_main", "FLUJOS")
    elseif r == W.MENU_MODE then
      run_screen("scr.screens", "scr_settings", "Ajustes")
    else
      salir()
    end
    if U.quit then salir() end
    W.APP_NAME = "PERDIDAS"
  end
end

rt.install(on, app_main)

-- Persistencia: el documento guarda la tabla de store.pack() (ajustes, casos y
-- lista propia de diametros, por nombre de campo y con version)
function on.save()
  return store.pack()
end

function on.restore(t)
  store.unpack(t)
end
