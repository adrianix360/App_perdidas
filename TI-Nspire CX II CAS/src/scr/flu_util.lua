-- flu_util.lua - Utilidades comunes de las pantallas de FLUJOS (F4).
-- Acceso perezoso a las pantallas de F3 (scr.screens: ajustes y acerca de;
-- scr.cases: Mis casos), ajustes con valores por defecto y copia de tablas.
-- Nada aqui llama a ui_getkey dentro de pcall: solo pcall(require, ...).
local U = require("ui.ui")
local H = require("core.hydro")
local F = {}

-- Ajustes globales (g_set del C). Si el almacen de ajustes (scr.store) aun no
-- relleno algo, se usan los valores por defecto de settings_default (store.c).
function F.gset()
  local g = U.g_set
  if type(g.h) ~= "table" then g.h = H.new_cfg() end
  if g.rho_air == nil then g.rho_air = 1.2 end
  if g.nu_air == nil then g.nu_air = 1.5e-5 end
  if g.cd_weir == nil then g.cd_weir = 0.6 end
  if g.knot == nil then g.knot = 1.85 end
  if g.mano == nil then g.mano = 0 end
  if g.buoy == nil then g.buoy = 0 end
  if g.dec == nil then g.dec = 6 end
  return g
end

-- Copia superficial de la configuracion hidraulica (hydro_cfg C = g_set.h)
function F.cfg_copy()
  local c = {}
  for k, v in pairs(F.gset().h) do c[k] = v end
  return c
end

function F.deep_copy(v)
  if type(v) ~= "table" then return v end
  local c = {}
  for k, x in pairs(v) do c[k] = F.deep_copy(x) end
  return c
end

-- Vacia t y copia dentro el contenido de src (conserva la identidad de t)
function F.fill(t, src)
  for k in pairs(t) do t[k] = nil end
  for k, v in pairs(src) do t[k] = F.deep_copy(v) end
  return t
end

local function pending(label)
  U.ui_alert(label, "Modulo pendiente (fase F3).", "Disponible al integrar PERDIDAS.", U.C_WARN)
end

-- m[fname]() del modulo modname si existe; si no, un aviso. Devuelve true si corrio
local function call(modname, fname, label, ...)
  local ok, m = pcall(require, modname)
  if ok and type(m) == "table" and type(m[fname]) == "function" then
    m[fname](...)
    return true
  end
  pending(label)
  return false
end

function F.scr_settings() call("scr.screens", "scr_settings", "Ajustes") end
function F.scr_about() call("scr.screens", "scr_about", "Acerca de") end
function F.scr_cases() call("scr.cases", "scr_cases", "Mis casos") end
-- Guarda el caso actual de la pantalla de resultado (tipo = KT_*)
function F.case_save_ui(tipo) call("scr.cases", "case_save_ui", "Guardar", tipo) end

-- C_D propio (Ajustes: cd_user): dragcat.cd_user y g_set.cd_user son la misma
-- tabla, para que el almacen de ajustes lo guarde. Se llama antes de usarlo.
function F.sync_cd_user()
  local dc = require("data.dragcat")
  local g = F.gset()
  if type(g.cd_user) == "table" then
    if dc.cd_user ~= g.cd_user then dc.cd_user = g.cd_user end
  else
    g.cd_user = dc.cd_user
  end
end

return F
