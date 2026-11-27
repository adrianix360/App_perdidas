-- cases.lua - Mis casos: guardar, cargar y borrar casos de TODOS los tipos de
-- problema (tuberia, Calcular f, arrastre, vertedores y canales) y su lista
-- (port de cases.c). Persisten en U.state.cas, que on.save/on.restore guardan
-- con el documento; cada cambio llama a U.mark_changed().
--
-- Cada caso es {nombre, tipo = KT_*, datos = copia profunda de la tabla de
-- entradas de la pantalla}: el modulo no conoce la forma de los datos.
-- Max. 20 casos, nombres de 1 a 8 caracteres A-Z 0-9.
--
-- Los modulos de FLUJOS (scr_drag, scr_weir, scr_chan) se enganchan por
-- nombre, como en el C:
--   scr.scr_drag : drag_save() -> tabla|nil, drag_load(t) -> bool, scr_drag_run(t, autocalc)
--   scr.scr_weir : weir_save(), weir_load(t), scr_weir_run(t, autocalc)
--   scr.scr_chan : chan_save(), chan_load(t), scr_chan_run(t, autocalc)
-- (t en scr_*_run = tipo relativo: KT - KT_DRAG / KT_WEIR / KT_CHAN). Tambien se
-- puede registrar un proveedor con C.register(kt_lo, kt_hi, {save=, load=, run=}).
--
-- API: C.KT_*, C.case_save_ui(tipo), C.scr_cases(), C.cases_count(), C.cases_write(),
--      C.cases_list() (U.state.cas), C.tipo_txt, C.own(tipo), C.register(...)
local U = require("ui.ui")
local W = require("ui.widgets")
local nf = require("ui.numfmt")
local S = require("scr.store")

local C = {}
local K_ENTER, K_CLEAR, K_QUIT, K_MODE = U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE
local K_F1, K_F3, K_F5 = U.K_F1, U.K_F3, U.K_F5
local C_ERR, C_WARN, C_OK, C_TITLE = U.C_ERR, U.C_WARN, U.C_OK, U.C_TITLE

C.CASES_MAX, C.CASE_NAME = 20, 8
C.PT_COUNT = 7
C.KT_FRIC, C.KT_DRAG, C.KT_WEIR, C.KT_CHAN, C.KT_COUNT = 7, 8, 13, 17, 41
local KT_FRIC, KT_DRAG, KT_WEIR, KT_CHAN, KT_COUNT = 7, 8, 13, 17, 41
-- Tipos de la ampliacion (se agregan al final: los casos guardados siguen valiendo)
C.KT_VE8, C.KT_AR5 = 20, 21
local KT_VE8, KT_AR5 = 20, 21
-- Estatica (kinds 1..11 de scr_stat) = 22..32; dinamica (D1c D1t D2a D2b D2c D3a D3b D4) = 33..40
C.KT_STAT, C.KT_DYN = 22, 33
local KT_STAT = 22
local DYN_KINDS = { "D1c", "D1t", "D2a", "D2b", "D2c", "D3a", "D3b", "D4" }

-- nombre corto de cada tipo para la lista (<= 28 caracteres)
C.tipo_txt = {
  [0] = "(A) Perdidas dado Q", "(B) Caudal maximo", "(D) Diametro",
  "(C) Bomba/turbina", "(F) Valvula", "(E) Calibracion", "(I) DW vs HW",
  "f: factor de friccion",
  "AR-1 Fuerza FD/FL", "AR-2 Velocidad terminal", "AR-3 Estructura",
  "AR-4 Vuelo nivelado", "Placa plana / Stokes",
  "VE Elemento simple", "VE-4 Compuesta", "VE-6 Perfil v(y)",
  "VE-7 Aguas abajo",
  "EX-1 Venturi", "EX-2 Salto hidraulico", "EX-3 Chorro",
  "VE-8 Tanques acoplados", "AR-5 Balance vertical",
  "E1 Placa entre paredes", "E1 Cojinete", "E1 Bloque en rampa", "E2 Manometria",
  "E3 Superficie plana", "E3 Compuerta en L", "E4 Cuarto de circulo", "E4 Semicilindro",
  "E5 Flotacion", "E6 Equilibrio relativo", "E6 Recipientes en polea",
  "D1 Perfil en canal", "D1 Perfil en tuberia", "D2 Continuidad", "D2 Descarga de tanque",
  "D2 Bernoulli", "D3 Codo o reduccion", "D3 Chorros y peso", "D4 Tanque no permanente",
}

local function cs() return U.state.cas end
function C.cases_list() return U.state.cas end
function C.cases_count() return #U.state.cas end
function C.cases_write() U.mark_changed(); return true end

local function settings() require("scr.screens").scr_settings() end

-- Programa dueno del caso: PERDIDAS (< KT_DRAG) o FLUJOS (>= KT_DRAG).
-- Cada programa lista todos, pero solo abre los suyos.
function C.own(t)
  if t >= KT_STAT then return true end      -- estatica y dinamica: se abren desde ambos
  if W.APP_NAME == "FLUJOS" then return t >= KT_DRAG end
  return t < KT_DRAG
end

-- ---------------------------------------------------------- proveedores
local providers = {}
function C.register(lo, hi, p) providers[#providers + 1] = { lo = lo, hi = hi, p = p } end

local function f4mod(name)
  local ok, m = pcall(require, "scr." .. name)
  if ok and type(m) == "table" then return m end
  return nil
end

-- Estatica y dinamica: un proveedor por tipo (modulos cargados al usarse)
for kind = 1, 11 do
  local function m() return f4mod("scr_stat") end
  C.register(KT_STAT + kind - 1, KT_STAT + kind - 1, {
    save = function() local s = m(); return s and s.case_get(kind) end,
    load = function(d) local s = m(); return s ~= nil and type(d) == "table" and s.case_set(kind, d) end,
    run = function() local s = m(); if s then s.case_run(kind, true) end end })
end
for i, kind in ipairs(DYN_KINDS) do
  local function m() return f4mod("scr_dyn") end
  C.register(C.KT_DYN + i - 1, C.KT_DYN + i - 1, {
    save = function() local s = m(); return s and s.case_get(kind) end,
    load = function(d) local s = m(); return s ~= nil and type(d) == "table" and s.case_set(kind, d) end,
    run = function() local s = m(); if s then s.case_run(kind) end end })
end
-- Asigna los codigos a los modulos (GUARDAR de sus pantallas); se llama al usar Mis casos
-- o al abrir el submenu de estatica y dinamica
function C.bind_kinds()
  local s = f4mod("scr_stat")
  if s then s.KT_BASE = KT_STAT end
  local d = f4mod("scr_dyn")
  if d then for i, kind in ipairs(DYN_KINDS) do d.kt[kind] = C.KT_DYN + i - 1 end end
end

-- Devuelve {save=, load=, run=} del tipo t, o nil si no esta disponible
local function provider(t)
  for i = #providers, 1, -1 do
    local r = providers[i]
    if t >= r.lo and t <= r.hi then return r.p end
  end
  local P = require("scr.scr_pipe")
  if t < KT_FRIC then
    return {
      save = function() return S.deep_copy(P.pin) end,
      load = function(d)
        if type(d) ~= "table" then return false end
        P.pin_assign(d)
        return true
      end,
      run = function() P.scr_pipe_run(t, true) end,
    }
  elseif t == KT_FRIC then
    local F = require("scr.scr_fric")
    return { save = F.fric_save, load = F.fric_load,
             run = function() F.scr_fric_run(nil, nil, nil, true) end }
  end
  local name, pre, base
  if t == KT_VE8 then name, pre, base = "scr_weir", "weir", KT_VE8 - 4     -- tipo relativo 4
  elseif t == KT_AR5 then name, pre, base = "scr_drag", "drag", KT_AR5 - 5  -- tipo relativo 5
  elseif t < KT_WEIR then name, pre, base = "scr_drag", "drag", KT_DRAG
  elseif t < KT_CHAN then name, pre, base = "scr_weir", "weir", KT_WEIR
  else name, pre, base = "scr_chan", "chan", KT_CHAN end
  local m = f4mod(name)
  if not m or not m[pre .. "_save"] or not m[pre .. "_load"] or not m["scr_" .. pre .. "_run"] then
    return nil
  end
  return { save = m[pre .. "_save"], load = m[pre .. "_load"],
           run = function() m["scr_" .. pre .. "_run"](t - base, true) end }
end

-- Nombre valido: 1..8 caracteres A-Z o 0-9
C.name_ok = S.name_ok

local function find(name)
  local l = cs()
  for i = 1, #l do if l[i].nombre == name then return i end end
  return nil
end

-- Guarda el caso actual (desde la pantalla de resultado)
function C.case_save_ui(tipo)
  C.bind_kinds()
  local p = provider(tipo)
  local data = p and p.save and p.save()
  if type(data) ~= "table" then
    U.ui_alert("Guardar", "Este tipo no se puede", "guardar (sin datos)", C_ERR)
    return
  end
  local ok, name = W.text_input("GUARDAR CASO", "Nombre del caso (max. 8):", "", C.CASE_NAME)
  if not ok then return end
  local l = cs()
  local i = find(name)
  if i then
    if not U.ui_alert("Guardar", "Ya existe un caso con ese", "nombre. Reemplazarlo?", C_WARN) then
      return
    end
  else
    if #l >= C.CASES_MAX then
      U.ui_alert("Guardar", "Lista llena (20 casos).", "Borre uno en Mis casos.", C_ERR)
      return
    end
    i = #l + 1
  end
  l[i] = { nombre = name, tipo = tipo, datos = S.deep_copy(data) }
  C.cases_write()
  U.ui_alert("Caso guardado", name, "Casos guardados: " .. nf.fmt_int(#l) .. " de 20", C_OK)
end

function C.scr_cases()
  C.bind_kinds()
  local fk = { "CARGAR", "", "BORRAR", "", "VOLVER" }
  local cur = 0
  while true do
    local l = cs()
    local n = #l
    for i = 0, n - 1 do
      local c = l[i + 1]
      local line = " " .. c.nombre .. string.rep(" ", 10 - 1 - #c.nombre) ..
        (C.tipo_txt[c.tipo] or "?"):sub(1, 28)
      if not C.own(c.tipo) then line = ">" .. line:sub(2) end   -- es del otro programa
      W.list_line[i] = line
    end
    local hint = "Casos: " .. nf.fmt_int(n) .. " de 20. ENTER carga"
    local r, k = W.list_pick("MIS CASOS", hint, n, cur, fk)
    if k == K_QUIT or k == K_CLEAR or k == K_F5 then return end
    if k == K_MODE then
      settings()
    elseif r >= 0 then
      cur = r
      local c = l[r + 1]
      if k == K_ENTER or k == K_F1 then
        if not C.own(c.tipo) then
          U.ui_alert("Mis casos", "Este caso se abre en",
            c.tipo >= KT_DRAG and "el programa FLUJOS" or "el programa PERDIDAS", C_TITLE)
        else
          local p = provider(c.tipo)
          if not (p and p.load and p.load(S.deep_copy(c.datos))) then
            U.ui_alert("Mis casos", "Caso de otra version:", "no se puede cargar", C_ERR)
          else
            p.run()
            if U.quit then return end
          end
        end
      elseif k == K_F3 then
        if U.ui_alert("Borrar caso", c.nombre, "Se borra para siempre.", C_WARN) then
          table.remove(l, r + 1)
          if cur >= #l and cur > 0 then cur = cur - 1 end
          C.cases_write()
        end
      end
    end
  end
end

return C
