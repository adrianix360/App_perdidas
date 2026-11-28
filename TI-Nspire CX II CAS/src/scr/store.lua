-- store.lua - Ajustes de la app, validacion de rangos y empaque para el documento
-- (port de store.c). En la Nspire no hay AppVars: los ajustes viven en U.g_set
-- (= U.state.cfg) y on.save/on.restore los guardan con el documento (main.lua
-- llama a pack() y unpack()). Se conserva el campo `ver` y el validador de
-- rangos: lo que se lee del documento nunca se acepta sin validar.
--
-- API PUBLICA
--   S.CFG_VER (= 3), S.g_set (la tabla de ajustes, la misma que U.g_set)
--   S.settings_default(s) -> s     rellena en sitio (h, dec, rho_air, nu_air, cd_weir,
--                                  knot, mano, buoy, cd_user[0..16])
--   S.settings_valid(s) -> bool    validacion de rangos (falso con NaN)
--   S.copy_settings(s) -> copia profunda
--   S.assign_settings(dst, src)    copia sobre dst conservando la identidad de las tablas
--   S.sig(s) -> string             firma para comparar ajustes
--   S.pack() -> tabla {cfg, cas, diam, ver}   para on.save
--   S.unpack(t) -> bool            para on.restore (valida; ignora lo invalido)
local U = require("ui.ui")
local H = require("core.hydro")
local diams = require("data.diams")
local dc = require("data.dragcat")

local S = {}
S.CFG_VER = 3
S.CAT_N = 17
S.DEC_MAX = 9
S.CASES_MAX = 20
S.CASE_NAME = 8
S.KT_COUNT = 41          -- v2.1 (0..19) + VE-8 (20) + AR-5 (21) + estatica (22..32) + dinamica (33..40)

local g_set = U.g_set
S.g_set = g_set

local function inr(x, lo, hi)
  return type(x) == "number" and x >= lo and x <= hi      -- falso con NaN
end

function S.settings_default(s)
  s.h = H.hydro_cfg_default(s.h or {})
  s.dec = 6
  s.rho_air = 1.2
  s.nu_air = 1.5e-5
  s.cd_weir = 0.6
  s.knot = 1.85
  s.mano = 0
  s.buoy = 0
  s.cd_user = s.cd_user or {}
  for i = 0, S.CAT_N - 1 do s.cd_user[i] = 0 end
  return s
end

local function cd_ok(c)
  for i = 0, S.CAT_N - 1 do
    local v = c[i]
    if not (v == 0 or inr(v, 1e-3, 10)) then return false end
  end
  return true
end

function S.settings_valid(s)
  local h = s.h
  if type(h) ~= "table" or type(s.cd_user) ~= "table" then return false end
  return inr(h.g, 1, 20) and inr(h.gamma, 1000, 20000) and
    inr(h.nu, 1e-8, 1e-3) and inr(h.tol, 1e-9, 1) and
    inr(h.re_lam, 100, 10000) and inr(h.re_turb, h.re_lam or 0, 100000) and
    inr(h.ld_limit, 1, 1e6) and inr(h.v_min, 0, 100) and
    inr(h.v_max, h.v_min or 0, 100) and inr(h.pv, 0, 101325) and
    inr(h.hm_ratio, 0, 100) and inr(h.method, 0, H.FM_COUNT - 1) and
    h.method == math.floor(h.method) and
    inr(h.max_iter, 10, 1e6) and inr(s.dec, 0, S.DEC_MAX) and s.dec == math.floor(s.dec) and
    inr(s.rho_air, 0.05, 5) and inr(s.nu_air, 1e-7, 1e-3) and
    inr(s.cd_weir, 0.1, 1.5) and inr(s.knot, 1, 3) and
    (s.mano == 0 or s.mano == 1) and (s.buoy == 0 or s.buoy == 1) and cd_ok(s.cd_user) and
    (h.r3 == nil or h.r3 == 0 or h.r3 == 1)
end

local function copy_flat(t)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  return r
end

function S.copy_settings(s)
  local r = copy_flat(s)
  r.h = copy_flat(s.h)
  r.cd_user = copy_flat(s.cd_user)
  return r
end

-- Copia src sobre dst en sitio (las tablas h y cd_user conservan su identidad)
function S.assign_settings(dst, src)
  for k, v in pairs(src) do
    if k ~= "h" and k ~= "cd_user" then dst[k] = v end
  end
  dst.h = dst.h or {}
  for k in pairs(dst.h) do dst.h[k] = nil end
  for k, v in pairs(src.h) do dst.h[k] = v end
  dst.cd_user = dst.cd_user or {}
  for k in pairs(dst.cd_user) do dst.cd_user[k] = nil end
  for k, v in pairs(src.cd_user) do dst.cd_user[k] = v end
end

local function flat_sig(t, out)
  local keys = {}
  for k in pairs(t) do
    if type(t[k]) ~= "table" then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for i = 1, #keys do out[#out + 1] = tostring(keys[i]) .. "=" .. tostring(t[keys[i]]) end
end

function S.sig(s)
  local out = {}
  flat_sig(s, out)
  flat_sig(s.h, out)
  flat_sig(s.cd_user, out)
  return table.concat(out, ";")
end

-- los Cd propios son la misma tabla que usa el catalogo (data.dragcat)
g_set.cd_user = dc.cd_user
S.settings_default(g_set)
-- el motor lee aqui el ajuste "Redondeo a mano" (h.r3; la tabla h conserva su
-- identidad con assign_settings)
H.round_src = g_set.h

-- ---------------------------------------------------------------- empaque
local function deep(v)
  if type(v) ~= "table" then return v end
  local r = {}
  for k, x in pairs(v) do r[k] = deep(x) end
  return r
end
S.deep_copy = deep

-- Nombre de caso valido: 1..8 caracteres A-Z o 0-9
function S.name_ok(n)
  return type(n) == "string" and #n >= 1 and #n <= S.CASE_NAME and n:match("^[A-Z0-9]+$") ~= nil
end

-- Datos de un caso: solo numeros, cadenas, booleanos y subtablas (sin ciclos)
local function data_ok(v, depth)
  local tv = type(v)
  if tv == "number" or tv == "string" or tv == "boolean" then return true end
  if tv ~= "table" or depth > 6 then return false end
  for k, x in pairs(v) do
    if type(k) ~= "number" and type(k) ~= "string" then return false end
    if not data_ok(x, depth + 1) then return false end
  end
  return true
end

function S.pack()
  local cfg = deep(g_set)
  -- cd_user va en base 1 en el documento (claves 1..17)
  local cu = {}
  for i = 0, S.CAT_N - 1 do cu[i + 1] = g_set.cd_user[i] or 0 end
  cfg.cd_user = cu
  local diam = {}
  for i = 1, diams.DIAM_CUSTOM_MAX do diam[i] = diams.diam_custom[i] or 0 end
  return { cfg = cfg, cas = deep(U.state.cas), diam = diam, ver = S.CFG_VER }
end

-- Devuelve true si se cargo algo. Todo se valida; lo invalido se ignora.
function S.unpack(t)
  if type(t) ~= "table" then return false end
  if type(t.ver) ~= "number" or t.ver > S.CFG_VER or t.ver < 1 then return false end
  local any = false
  if type(t.cfg) == "table" then
    local tmp = S.copy_settings(g_set)
    S.settings_default(tmp)                 -- lo que falte queda por defecto
    local c = t.cfg
    for k, v in pairs(c) do
      if k ~= "h" and k ~= "cd_user" and type(v) == "number" then tmp[k] = v end
    end
    if type(c.h) == "table" then
      for k, v in pairs(c.h) do
        if type(v) == "number" and tmp.h[k] ~= nil then tmp.h[k] = v end
      end
    end
    if type(c.cd_user) == "table" then
      for i = 0, S.CAT_N - 1 do
        local v = c.cd_user[i + 1]
        if type(v) == "number" then tmp.cd_user[i] = v end
      end
    end
    if S.settings_valid(tmp) then
      S.assign_settings(g_set, tmp)
      any = true
    end
  end
  local cas = U.state.cas
  if type(t.cas) == "table" then
    for k in pairs(cas) do cas[k] = nil end
    local n = 0
    for i = 1, #t.cas do
      local c = t.cas[i]
      if n < S.CASES_MAX and type(c) == "table" and S.name_ok(c.nombre) and
          type(c.tipo) == "number" and c.tipo >= 0 and c.tipo < S.KT_COUNT and
          c.tipo == math.floor(c.tipo) and type(c.datos) == "table" and data_ok(c.datos, 0) then
        n = n + 1
        cas[n] = { nombre = c.nombre, tipo = c.tipo, datos = deep(c.datos) }
      end
    end
    any = true
  end
  if type(t.diam) == "table" then
    for i = 1, diams.DIAM_CUSTOM_MAX do
      local v = t.diam[i]
      diams.diam_custom[i] = (type(v) == "number" and v > 0 and v < 1e5) and v or 0
    end
    any = true
  end
  return any
end

return S
