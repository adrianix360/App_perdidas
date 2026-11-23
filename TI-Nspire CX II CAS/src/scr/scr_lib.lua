-- scr_lib.lua - Biblioteca: materiales (ks, C_H), accesorios y sumador de K,
-- fluido (temperatura, nu, gamma, presion de vapor) y diametros comerciales
-- (listas del curso y lista propia). Port de scr_lib.c.
--
-- API: L.lib_pick_material() -> bool, L.lib_sumador() -> bool,
--      L.lib_pick_fluid(to_settings) -> bool, L.lib_diams(), L.scr_library()
-- Todas actuan sobre pin (scr_pipe.pin) como el C.
local U = require("ui.ui")
local W = require("ui.widgets")
local nf = require("ui.numfmt")
local lib = require("data.lib")
local diams = require("data.diams")
local S = require("scr.store")

local L = {}
local g_set = U.g_set
local C_FG, C_GRAY, C_TITLE, C_OK, C_ERR, C_WARN = U.C_FG, U.C_GRAY, U.C_TITLE, U.C_OK, U.C_ERR, U.C_WARN
local K_ENTER, K_CLEAR, K_QUIT, K_MODE = U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE
local K_F1, K_F2, K_F3, K_F4, K_F5 = U.K_F1, U.K_F2, U.K_F3, U.K_F4, U.K_F5

local function pin() return require("scr.scr_pipe").pin end
local function settings() require("scr.screens").scr_settings() end

local function pad_to(s, col)
  if #s < col then s = s .. string.rep(" ", col - #s) end
  return s
end

-- ------------------------------------------------------------ Materiales
local mat_cur = 0
function L.lib_pick_material()
  local fk = { "", "", "", "", "USAR" }
  for i = 0, lib.MATERIALS - 1 do
    local m = lib.materials[i + 1]
    local l = pad_to(m.name, 20)
    if m.ks_mm >= 0 then l = l .. nf.fmt_real(m.ks_mm, 4) else l = l .. "  --" end
    l = pad_to(l, 31)
    if m.ch > 0 then l = l .. "CH " .. nf.fmt_int(m.ch) end
    W.list_line[i] = l
  end
  local r, k = W.list_pick("MATERIALES  ks (mm)  C_H", "(C) = Cengel; los demas, tabla del curso",
    lib.MATERIALS, mat_cur, fk)
  if r < 0 or (k ~= K_ENTER and k ~= K_F5) then return false end
  mat_cur = r
  local m = lib.materials[r + 1]
  local p = pin()
  if m.ks_mm >= 0 then p.ks = m.ks_mm; p.sks = 1 end
  if m.ch > 0 then p.CH = m.ch; p.sCH = 1 end
  return true
end

-- ------------------------------------------------- Sumador de accesorios
local SUM_MAX = 10
local sl = {}                  -- {name, qty, K, sq, sk}
local stotal = { v = 0 }
local fit_cur, sum_cur = 0, 0

local function sum_total()
  local t = 0
  for i = 1, #sl do t = t + sl[i].qty * sl[i].K end
  stotal.v = t
end

local function add_line(name, qty, K)
  if #sl >= SUM_MAX then return end
  sl[#sl + 1] = { name = name:sub(1, 19), qty = qty, K = K, sq = 1, sk = 1 }
end

local function pick_fitting()
  for i = 0, lib.FITTINGS - 1 do
    local f = lib.fittings[i + 1]
    W.list_line[i] = pad_to(f.name, 24) .. "K = " .. nf.fmt_real(f.K, 3)
  end
  local r, k = W.list_pick("ACCESORIOS  (K)", "(C) = Cengel; K editable despues",
    lib.FITTINGS, fit_cur, nil)
  if r >= 0 and k == K_ENTER then fit_cur = r; return r end
  return -1
end

local function pick_preset()
  for i = 0, lib.K_PRESETS - 1 do
    local p = lib.k_presets[i + 1]
    local t = 0
    for j = 1, p.n do t = t + p.items[j].qty * p.items[j].K end
    W.list_line[i] = pad_to(p.name, 24) .. "SumK " .. nf.fmt_real(t, 3)
  end
  local r, k = W.list_pick("CONJUNTOS DEL CURSO", "Reemplaza la lista actual",
    lib.K_PRESETS, 0, nil)
  return (r >= 0 and k == K_ENTER) and r or -1
end

function L.lib_sumador()
  while true do
    sum_total()
    local f = { { label = "Suma K total", t = stotal, k = "v", flags = W.FF_INFO } }
    for i = 1, #sl do
      local it = sl[i]
      f[#f + 1] = { label = it.name, unit = "uds", t = it, k = "qty", setk = "sq",
                    flags = W.FF_NONNEG }
      f[#f + 1] = { label = "   K c/u", t = it, k = "K", setk = "sk", flags = W.FF_NONNEG }
    end
    local n = #f
    local fm = {
      title = "SUMADOR DE ACCESORIOS", f = f, n = n,
      cur = sum_cur < n and sum_cur or 0,
      fk = { "AGREGAR", "CONJUNT", "QUITAR", "OTRO", "USAR" },
      hint = #sl > 0 and "Cantidad y K editables; F5 usa la suma"
                      or "F1 agrega accesorio; F2 conjunto curso",
      on_commit = sum_total,
    }
    local k = W.form_run(fm)
    sum_cur = fm.cur
    if k == K_F1 then
      local r = pick_fitting()
      if r >= 0 then
        local ft = lib.fittings[r + 1]
        add_line(ft.name, 1, ft.K)
        sum_cur = 2 * #sl - 1 + 0
      end
    elseif k == K_F2 then
      local r = pick_preset()
      if r >= 0 then
        sl = {}
        local p = lib.k_presets[r + 1]
        for i = 1, p.n do add_line(p.items[i].name, p.items[i].qty, p.items[i].K) end
        sum_cur = 0
      end
    elseif k == K_F3 then
      if #sl > 0 and fm.cur >= 1 then
        local li = math.floor((fm.cur - 1) / 2) + 1
        table.remove(sl, li)
        sum_cur = sum_cur > 2 and sum_cur - 2 or 0
      end
    elseif k == K_F4 then
      add_line("Otro accesorio", 1, 0)
      sum_cur = 2 * #sl
    elseif k == K_F5 then
      sum_total()
      local p = pin()
      p.K = stotal.v
      p.sK = 1
      return true
    elseif k == K_MODE then
      settings()
    elseif k ~= K_ENTER then       -- CLEAR o QUIT
      return false
    end
    if U.quit then return false end
  end
end

-- ----------------------------------------------------------------- Fluido
local fl_cur = 0
function L.lib_pick_fluid(to_settings)
  for i = 0, lib.WATERS - 1 do
    local w = lib.waters[i + 1]
    W.list_line[i] = pad_to(w.name, 18) .. "nu " .. nf.fmt_real(w.nu, 6)
  end
  local r, k = W.list_pick(to_settings and to_settings ~= 0 and "FLUIDO POR DEFECTO" or "FLUIDO",
    "(std) tabla estandar; aire: arrastre", lib.WATERS, fl_cur, nil)
  if r < 0 or k ~= K_ENTER then return false end
  fl_cur = r
  local w = lib.waters[r + 1]
  local p = pin()
  if not to_settings or to_settings == 0 then
    p.nu = w.nu
    p.snu = 1
    return true
  end
  if w.rho > 0 and w.rho < 10 then          -- v2.0: aire
    g_set.rho_air = w.rho
    g_set.nu_air = w.nu
    U.mark_changed()
    U.ui_alert("Aire por defecto", "rho y nu del aire quedan en",
      "Ajustes (arrastre y sustentacion)", C_OK)
    return true
  end
  local t = S.copy_settings(g_set)            -- se valida antes de aplicar
  t.h.nu = w.nu
  if w.rho > 0 then t.h.gamma = w.rho * t.h.g end
  if w.pv > 0 then t.h.pv = w.pv end
  if not S.settings_valid(t) then
    U.ui_alert("Fluido por defecto", "gamma = rho g queda fuera de",
      "rango: revise g en Ajustes", C_ERR)
    return false
  end
  S.assign_settings(g_set, t)
  U.mark_changed()
  p.nu = w.nu
  p.snu = 1
  U.ui_alert("Fluido por defecto",
    w.rho > 0 and "nu, gamma = rho g y presion" or "nu del curso (gamma sin",
    w.rho > 0 and "de vapor quedan en Ajustes" or "cambio) queda en Ajustes", C_OK)
  return true
end

-- ------------------------------------------------- Diametros comerciales
local function edit_custom()
  local dc = diams.diam_custom
  local set = {}
  local f = {}
  for i = 1, diams.DIAM_CUSTOM_MAX do
    set[i] = dc[i] > 0
    f[i] = {
      label = "Diametro " .. i, unit = "mm",
      get = function() return dc[i] end,
      put = function(v) dc[i] = v end,
      hget = function() return set[i] end,
      hput = function(b) set[i] = b end,
      flags = W.FF_POS + W.FF_OPT,
    }
  end
  local fm = { title = "LISTA PROPIA (mm, internos)", f = f, n = #f, cur = 0,
               fk = { "", "", "", "", "GUARDAR" }, hint = "DEL vacia un campo; F5 guarda" }
  local k
  repeat
    k = W.form_run(fm)
    if k == K_MODE then settings() end
  until k ~= K_MODE or U.quit
  if k == K_F5 or k == K_ENTER or k == K_CLEAR then
    for i = 1, diams.DIAM_CUSTOM_MAX do
      if not set[i] then dc[i] = 0 end
    end
    U.mark_changed()                   -- cases_write: la lista propia viaja con el documento
  end
end

local function show_set(s)
  local fk = { "", "", "", "", "VOLVER" }
  W.view_clear()
  W.view_add(diams.diam_set_names[s + 1], C_TITLE)
  W.view_add("Diametros internos (mm):", C_GRAY)
  W.view_add_sep()
  local line = ""
  local ds = diams.diam_sets[s + 1]
  for i = 1, ds.n do
    if #line > 30 then W.view_add(line, C_FG); line = "" end
    line = line .. " " .. nf.fmt_real(ds.mm[i], 2)
  end
  W.view_add(line, C_FG)
  W.view_run("DIAMETROS COMERCIALES", fk)
end

local dm_cur = 0
function L.lib_diams()
  while true do
    for i = 0, diams.DIAM_CHOICES - 1 do W.list_line[i] = diams.diam_set_names[i + 1] end
    local r = W.list_pick("DIAMETROS COMERCIALES", "ENTER: ver o editar (lista propia)",
      diams.DIAM_CHOICES, dm_cur, nil)
    if r < 0 then return end
    dm_cur = r
    if r == diams.DIAM_CUSTOM then edit_custom() else show_set(r) end
    if U.quit then return end
  end
end

local lib_menu = {
  title = "BIBLIOTECA", n = 4, cur = 0,
  items = { "Materiales (ks, C_H)", "Accesorios (K) y sumador",
            "Fluido por defecto (T, nu, gamma)", "Diametros comerciales" },
}
function L.reset_cursors()
  mat_cur, fit_cur, sum_cur, fl_cur, dm_cur = 0, 0, 0, 0, 0
  lib_menu.cur = 0
  sl = {}
end

function L.scr_library()
  while not U.quit do
    local r = W.menu_run(lib_menu)
    if r == W.MENU_BACK or r == W.MENU_QUIT then return end
    if r == W.MENU_MODE then
      settings()
    elseif r == 0 then
      if L.lib_pick_material() then
        U.ui_alert("Material", "ks y C_H quedan en los", "formularios de tuberia", C_OK)
      end
    elseif r == 1 then
      if L.lib_sumador() then
        U.ui_alert("Suma K", "La suma queda en el campo", "Suma K de los formularios", C_OK)
      end
    elseif r == 2 then
      L.lib_pick_fluid(1)
    elseif r == 3 then
      L.lib_diams()
    end
  end
end

return L
