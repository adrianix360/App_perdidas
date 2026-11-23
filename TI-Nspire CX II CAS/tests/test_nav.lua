-- test_nav.lua - Navegacion de punta a punta desde el menu inicial real de main.lua
-- (PERDIDAS / FLUJOS / Salir) con teclas, toolpalette y clics simulados; port de la
-- parte de recorrido de ti84/tests/test_nav.c. Cubre tambien: arranque en distinto
-- orden de eventos, on.save/on.restore con casos de ambos programas y ajustes
-- cambiados, cambio de tamano de ventana y reinicio tras un error de la corrutina.
local mock = dofile("tests/mock_nspire.lua")
local APP = "build/app.lua"
local env = mock.load_app(APP)

local fails, checks = 0, 0
local function check(cond, msg)
  checks = checks + 1
  if not cond then fails = fails + 1; print("FALLO: " .. tostring(msg)) end
  return cond
end

local rt, U, W, Store, Sc
local function bind()
  rt = env.require("ui.rt"); U = env.require("ui.ui"); W = env.require("ui.widgets")
  Store = env.require("scr.store"); Sc = env.require("scr.screens")
end
bind()

local function keys(...) for _, k in ipairs({ ... }) do mock.key(k) end end
local function typed(s) for c in s:gmatch(".") do mock.key(c) end end
local function TE(s) typed(s); mock.key("enter") end
local function downs(n) for _ = 1, n do mock.key("down") end end
local function F(i) mock.paint(); mock.click(math.floor((i - 0.5) * mock.W / 5), mock.H - 5) end
local function shown(s) mock.paint(); return mock.has_text(s) and true or false end
local function title()                       -- texto de la barra de titulo
  mock.paint()
  local best
  for _, t in ipairs(mock.screen_text()) do
    if t.y <= 2 and t.style == "b" and (not best or t.x < best.x) then best = t end
  end
  return best and best.text or ""
end
local function vhas(s)
  for i = 1, W.view_n do if W.view_line[i]:find(s, 1, true) then return true end end
  return false
end
local function noerr(msg)
  return check(not rt.fatal, msg .. ": sin error de Lua (" .. tostring(rt.fatal) .. ")")
end
local function restart() rt.start(rt.app_main); W.APP_NAME = "PERDIDAS"; Sc.reset_menus() end
local function back_root()
  for _ = 1, 14 do
    if shown("PERDIDAS / FLUJOS") then return true end
    if shown("Desea salir") or shown("Datos guardados") then keys("enter") else keys("esc") end
  end
  return shown("PERDIDAS / FLUJOS")
end

-- ===================================================== 1. arranque y primer cuadro
do
  check(shown("PERDIDAS / FLUJOS") and shown("PERDIDAS - tuberias") and
    shown("FLUJOS - arrastre") and shown("Salir (guardar)"), "arranque: menu inicial con 3 opciones")
  -- SO antiguo: on.create / on.resize / on.paint
  mock.load_app(APP, { old_order = true })
  mock.paint()
  check(mock.has_text("PERDIDAS / FLUJOS"), "arranque con on.create (SO antiguo) dibuja el primer cuadro")
  -- ni construction ni create: basta resize + paint
  mock.load_app(APP, { no_init = true })
  mock.paint()
  check(mock.has_text("PERDIDAS / FLUJOS"), "arranque sin construction/create: dibuja el primer cuadro")
  -- solo paint, sin resize
  mock.load_app(APP, { no_init = true, no_resize = true })
  mock.paint()
  check(mock.has_text("PERDIDAS / FLUJOS"), "arranque solo con on.paint: dibuja el primer cuadro")
  -- construction y create juntos no reinician la app
  local e3 = mock.load_app(APP)
  e3.on.create(); e3.on.construction(); mock.key("down"); e3.on.create()
  mock.paint()
  check(mock.has_text("PERDIDAS / FLUJOS"), "construction + create + teclas: un solo arranque")
  env = mock.load_app(APP); bind()
end

-- ==================================================== 2. menu inicial y Salir
do
  keys("down"); keys("down"); keys("down")
  keys("up")
  restart()
  mock.marked_changed = 0
  keys("3")
  check(shown("Guarde el documento (ctrl+S)"), "inicio: Salir avisa de guardar el documento")
  check(mock.marked_changed > 0, "inicio: Salir marca el documento como modificado")
  keys("enter")
  check(shown("PERDIDAS / FLUJOS"), "inicio: tras Salir vuelve al menu inicial")
  keys("esc")
  check(shown("Guarde el documento"), "inicio: ESC equivale a Salir")
  keys("enter")
  -- Salir con flechas + ENTER
  restart(); keys("down", "down", "enter")
  check(shown("Datos guardados"), "inicio: flechas + ENTER sobre Salir")
  keys("enter")
  -- ajustes desde el menu inicial con la tecla menu
  keys("menu")
  check(title() == "AJUSTES", "inicio: tecla menu abre Ajustes")
  keys("esc")
  check(shown("PERDIDAS / FLUJOS"), "inicio: Ajustes vuelve")
  noerr("menu inicial")
end

-- ============================================ 3. PERDIDAS: cada opcion y vuelta con ESC
local perd_titles = { [1] = "TUBERIA SIMPLE", [2] = "SISTEMA SERIE/PARALELO (G)",
  [3] = "FACTOR DE FRICCION f", [5] = "BIBLIOTECA", [6] = "MIS CASOS", [7] = "AJUSTES",
  [8] = "AYUDA" }
do
  restart()
  keys("1")
  check(title() == "MENU PRINCIPAL" and shown("Tuberia simple") and shown("Biblioteca") and
    shown("Mis casos") and shown("Ayuda / Acerca de"), "PERDIDAS: menu principal")
  for _, i in ipairs({ 1, 2, 3, 5, 6, 7, 8 }) do
    keys(tostring(i))
    check(title() == perd_titles[i], "PERDIDAS opcion " .. i .. ": abre " .. perd_titles[i] .. " (" .. title() .. ")")
    noerr("PERDIDAS opcion " .. i)
    keys("esc")
    check(title() == "MENU PRINCIPAL", "PERDIDAS opcion " .. i .. ": ESC vuelve al menu principal")
  end
  -- submenu de tuberia: cada entrada abre y vuelve
  keys("1")
  for i = 1, 8 do
    keys(tostring(i))
    check(title() ~= "TUBERIA SIMPLE" and noerr("tuberia entrada " .. i), "tuberia entrada " .. i .. " abre su pantalla")
    keys("esc")
    check(title() == "TUBERIA SIMPLE", "tuberia entrada " .. i .. ": ESC vuelve")
  end
  -- ayuda: 10 entradas
  for i = 1, 10 do
    restart(); keys("1", "8")
    if i < 10 then keys(tostring(i)) else downs(9); keys("enter") end
    check(noerr("ayuda " .. i) and (i >= 9 or W.view_n > 3), "ayuda entrada " .. i .. " abre")
    keys("esc")
    check(title() == "AYUDA", "ayuda entrada " .. i .. ": ESC vuelve a Ayuda")
  end
  -- biblioteca: 4 entradas
  for i = 1, 4 do
    restart(); keys("1", "5", tostring(i))
    check(noerr("biblioteca " .. i) and title() ~= "BIBLIOTECA", "biblioteca entrada " .. i .. " abre")
    keys("esc")
    check(title() == "BIBLIOTECA", "biblioteca entrada " .. i .. ": ESC vuelve")
  end
  -- "Flujos externos" (4) abre FLUJOS
  restart(); keys("1", "4")
  check(title() == "FLUJOS EXTERNOS Y MEDICION" and W.APP_NAME == "FLUJOS", "PERDIDAS 4 Flujos externos abre FLUJOS")
  keys("esc"); check(shown("Desea salir de FLUJOS"), "FLUJOS desde PERDIDAS: ESC pide confirmar")
  keys("enter")
  check(title() == "MENU PRINCIPAL" and W.APP_NAME == "PERDIDAS", "FLUJOS desde PERDIDAS: vuelve a PERDIDAS")
  -- PERDIDAS 9 Salir y ESC con confirmacion
  mock.marked_changed = 0
  keys("9")
  check(shown("Guarde el documento") and mock.marked_changed > 0, "PERDIDAS 9 Salir: guarda y avisa")
  keys("enter")
  check(shown("PERDIDAS / FLUJOS"), "PERDIDAS 9 Salir: menu inicial")
  keys("1", "esc"); check(shown("Desea salir de PERDIDAS"), "PERDIDAS ESC: confirmacion")
  keys("esc"); check(title() == "MENU PRINCIPAL", "PERDIDAS ESC+ESC: se queda")
  keys("esc", "enter", "enter"); check(shown("PERDIDAS / FLUJOS"), "PERDIDAS ESC+ENTER: sale al inicio")
end

-- ============================================= 4. FLUJOS: cada opcion y vuelta con ESC
do
  restart(); keys("2")
  check(title() == "FLUJOS EXTERNOS Y MEDICION" and W.APP_NAME == "FLUJOS", "inicio 2: abre FLUJOS")
  local subs = {
    { 1, "ARRASTRE Y SUSTENTACION", 6 }, { 2, "VERTEDORES Y ORIFICIOS", 4 },
    { 3, "CANALES Y MEDICION", 4 }, { 7, "AYUDA", 6 } }
  for _, s in ipairs(subs) do
    keys(tostring(s[1]))
    check(title() == s[2], "FLUJOS " .. s[1] .. ": abre " .. s[2])
    for i = 1, s[3] do
      keys(tostring(i))
      check(noerr(s[2] .. " " .. i) and (s[2] == "AYUDA" and (i >= 5 or W.view_n > 3) or title() ~= s[2]),
        s[2] .. " entrada " .. i .. " abre")
      keys("esc")
      check(title() == s[2], s[2] .. " entrada " .. i .. ": ESC vuelve")
    end
    keys("esc")
    check(title() == "FLUJOS EXTERNOS Y MEDICION", "FLUJOS " .. s[1] .. ": ESC vuelve al menu")
  end
  for _, i in ipairs({ 4, 5, 6 }) do
    keys(tostring(i))
    check(noerr("FLUJOS " .. i) and title() ~= "FLUJOS EXTERNOS Y MEDICION", "FLUJOS opcion " .. i .. " abre")
    keys("esc")
    check(title() == "FLUJOS EXTERNOS Y MEDICION", "FLUJOS opcion " .. i .. ": ESC vuelve")
  end
  keys("menu"); check(title() == "AJUSTES", "FLUJOS: tecla menu abre Ajustes"); keys("esc")
  keys("8")
  check(shown("PERDIDAS / FLUJOS") or shown("Datos guardados"), "FLUJOS 8 Salir vuelve al inicio")
  back_root()
  check(shown("PERDIDAS / FLUJOS"), "FLUJOS: se llega de vuelta al menu inicial")
end

-- ===================================== 5. toolpalette (tecla menu) y barra de acciones
do
  restart(); keys("1", "1", "1")                       -- Tuberia A: formulario
  local tp = mock.toolpalette_menu
  check(tp and tp[1] and tp[1][1] == "Acciones", "toolpalette: menu 'Acciones' registrado")
  local labels = {}
  for i = 2, #tp[1] do labels[#labels + 1] = tp[1][i][1] end
  check(table.concat(labels, ",") == "MAT,SUMA K,FLUIDO,CALC f,CALC,Ajustes",
    "toolpalette A: F1..F5 + Ajustes (" .. table.concat(labels, ",") .. ")")
  local function item(name)
    for i = 2, #mock.toolpalette_menu[1] do
      if mock.toolpalette_menu[1][i][1] == name then mock.toolpalette_menu[1][i][2](); return true end
    end
    return false
  end
  check(item("MAT") and title() == "MATERIALES", "toolpalette: MAT (F1)"); keys("esc")
  check(item("SUMA K") and title() == "SUMADOR DE ACCESORIOS", "toolpalette: SUMA K (F2)"); keys("esc")
  check(item("FLUIDO") and title() == "FLUIDO", "toolpalette: FLUIDO (F3)"); keys("esc")
  check(item("CALC f") and title() == "FACTOR DE FRICCION f", "toolpalette: CALC f (F4) abre Calcular f"); keys("esc")
  check(item("Ajustes") and title() == "AJUSTES", "toolpalette: Ajustes"); keys("esc")
  check(title() == "PERDIDAS DADO Q", "toolpalette: se vuelve al formulario A")
  check(item("CALC") and shown("Falta este dato"), "toolpalette: CALC (F5)"); keys("esc")
  noerr("toolpalette")
  -- cada pantalla re-registra sus acciones
  keys("esc")
  keys("3")
  local l2 = {}
  tp = mock.toolpalette_menu
  for i = 2, #tp[1] do l2[#l2 + 1] = tp[1][i][1] end
  check(#l2 >= 3 and l2[#l2] == "Ajustes",
    "toolpalette: Calcular f registra sus acciones (" .. table.concat(l2, ",") .. ")")
  keys("menu"); check(title() == "AJUSTES", "tecla menu en un formulario abre Ajustes"); keys("esc")
  -- clic en la barra de acciones y en el cuerpo
  restart(); keys("1")
  mock.paint(); mock.click(mock.W * 0.7, mock.H - 5)
  check(title() == "AJUSTES", "clic en la barra (F4) abre Ajustes")
  keys("esc")
  mock.paint(); mock.click(10, 5)
  check(title() == "MENU PRINCIPAL", "clic en el titulo no hace nada")
  local L = rt.layout()
  mock.click(40, L.y_body + L.rowh * 5 + 2)             -- fila 6: Mis casos
  check(title() == "MIS CASOS", "clic en una fila del menu la elige")
  keys("esc")
  keys("1", "1"); F(5)
  check(shown("Falta este dato"), "clic en la barra (F5 CALC) calcula")
  keys("esc"); keys("esc"); keys("esc")
  noerr("clics")
end

-- ================================================= 6. cambio de tamano de ventana
do
  for _, sz in ipairs({ { 320, 240 }, { 480, 320 }, { 318, 212 } }) do
    mock.W, mock.H = sz[1], sz[2]
    env.on.resize(sz[1], sz[2])
    for _, path in ipairs({ { "1" }, { "1", "1", "1" }, { "2", "4" }, { "2", "1", "1" } }) do
      restart(); keys(unpack(path))
      mock.paint()
      local tag = "resize " .. sz[1] .. "x" .. sz[2] .. " " .. table.concat(path, ",")
      check(noerr(tag), tag)
      local ok = true
      for _, t in ipairs(mock.screen_text()) do
        if t.y + t.h > mock.H + 2 or t.y < 0 then ok = false end
      end
      check(ok, tag .. ": texto dentro de la ventana")
    end
    restart(); keys("1", "1", "1")
    mock.W, mock.H = 480, 320; env.on.resize(480, 320); mock.paint()
    check(noerr("resize en caliente") and mock.has_text("PERDIDAS DADO Q"),
      "resize en caliente conserva la pantalla")
    mock.W, mock.H = sz[1], sz[2]; env.on.resize(sz[1], sz[2])
  end
  mock.W, mock.H = 318, 212; env.on.resize(318, 212)
  back_root()
end

-- ===================== 7. on.save / on.restore con casos de ambos programas y ajustes
local saved
local function save_case(name)
  F(3)
  typed(name); keys("enter")
  keys("enter")                                         -- aviso "Caso guardado"
end
do
  for i = #U.state.cas, 1, -1 do U.state.cas[i] = nil end
  restart(); keys("1", "8"); downs(8); keys("enter", "enter")   -- caso del curso #1 de PERDIDAS
  save_case("PERD1")
  back_root()
  restart(); keys("2", "7", "5", "enter")                  -- AR-01
  save_case("AR01")
  back_root()
  restart(); keys("2", "7", "5"); downs(15); keys("enter")  -- EX-02
  save_case("EX02")
  back_root()
  check(#U.state.cas == 3, "Mis casos: 3 casos de ambos programas (" .. #U.state.cas .. ")")
  restart(); keys("1", "7", "backtab", "right", "right")   -- ajustes: Haaland
  downs(4); TE("3"); F(5)                                   -- decimales = 3
  check(U.g_set.h.method == 3 and U.g_set.dec == 3,
    "ajustes cambiados antes de guardar (" .. U.g_set.h.method .. "," .. U.g_set.dec .. ")")
  back_root()
  saved = mock.save()
  check(saved.ver == 3 and #saved.cas == 3 and saved.cfg.dec == 3 and saved.cfg.h.method == 3,
    "on.save: casos de los dos programas y ajustes cambiados")
  env = mock.load_app(APP); bind()
  check(#U.state.cas == 0, "app nueva: sin casos")
  mock.restore(saved)
  check(#U.state.cas == 3 and U.g_set.dec == 3 and U.g_set.h.method == 3,
    "on.restore: casos y ajustes de vuelta en una app nueva")
  local names = {}
  for i, c in ipairs(U.state.cas) do names[i] = c.nombre end
  check(table.concat(names, ",") == "PERD1,AR01,EX02", "on.restore: nombres de los casos")
  restart(); keys("1", "6")
  check(shown("PERD1") and shown("AR01") and shown("EX02") and shown("Casos: 3 de 20"),
    "Mis casos tras restaurar: lista")
  keys("enter")
  check(noerr("cargar PERD1") and (vhas("RESULTADO") or vhas("Colebrook")),
    "caso de PERDIDAS restaurado calcula")
  back_root()
  restart(); keys("2", "5", "down", "enter")
  check(noerr("cargar AR01") and vhas("> v terminal = 4.922 m/s"), "caso AR-01 restaurado da v terminal = 4.922 m/s")
  back_root()
  -- restore antes del primer paint (otro orden posible del SO)
  env = mock.load_app(APP, { no_init = true, no_resize = true }); bind()
  mock.restore(saved)
  mock.paint()
  check(mock.has_text("PERDIDAS / FLUJOS") and #U.state.cas == 3 and U.g_set.dec == 3,
    "on.restore antes del primer paint: arranca con datos")
  local again = mock.save()
  check(#again.cas == 3 and again.cfg.dec == 3 and again.ver == 3 and again.cas[3].nombre == "EX02",
    "on.save tras on.restore: ida y vuelta igual")
  mock.restore({ ver = 99 }); mock.restore({}); mock.restore(nil)
  check(noerr("restore invalido"), "on.restore con datos invalidos no rompe")
  env = mock.load_app(APP); bind()
  Store.settings_default(U.g_set)
  for i = #U.state.cas, 1, -1 do U.state.cas[i] = nil end
end

-- ================================== 8. error de la corrutina: pantalla y ENTER reinicia
do
  restart()
  local orig = Sc.scr_main
  Sc.scr_main = function() error("fallo de prueba") end
  keys("1")
  check(rt.fatal ~= nil and tostring(rt.fatal):find("fallo de prueba", 1, true), "error de corrutina capturado")
  mock.paint()
  check(mock.has_text("Error de la app") and mock.has_text("fallo de prueba"), "el error se muestra en pantalla")
  check(mock.has_text("ENTER: reiniciar"), "la pantalla de error avisa de ENTER")
  keys("down"); check(rt.fatal ~= nil, "otras teclas no reinician")
  Sc.scr_main = orig
  keys("enter")
  check(rt.fatal == nil and shown("PERDIDAS / FLUJOS"), "ENTER reinicia la app en el menu inicial")
  keys("1"); check(title() == "MENU PRINCIPAL", "tras reiniciar la app funciona")
  Sc.scr_main = function() error("otro fallo") end
  restart(); keys("1")
  Sc.scr_main = orig
  F(5)
  check(rt.fatal == nil and shown("PERDIDAS / FLUJOS"), "F5 tambien reinicia tras un error")
end

-- ============ 9. maqueta a partir de la medida real del texto (gc:getStringHeight)
do
  restart(); keys("1", "1", "1")
  local L = rt.layout()
  mock.paint()
  local okmsg, okbar = true, true
  for _, t in ipairs(mock.screen_text()) do
    if t.y >= L.y_msg and t.y < L.y_bar and t.y + t.h > L.y_bar then okmsg = false end
    if t.y >= L.y_bar and (t.x < 0 or t.y + t.h > L.h + 1) then okbar = false end
    if t.y >= L.y_bar and t.w > L.w / 5 - 3 then okbar = false end
  end
  check(okmsg, "maqueta: la linea de mensaje no invade la barra de acciones")
  check(okbar, "maqueta: las etiquetas de la barra caben en su boton")
  -- gc de la calculadora con letra mas alta: la maqueta se recalcula
  local rows0, lh0 = L.rows, L.lh
  local fake = { setFont = function() end, getStringHeight = function() return 16 end }
  check(rt.remeasure(fake) and rt.layout().lh == 16 and rt.layout().rows < rows0,
    "maqueta: una letra mas alta reduce las filas (" .. rows0 .. " -> " .. rt.layout().rows .. ")")
  check(rt.layout().ah >= 16 and rt.layout().mh >= 16, "maqueta: barra y mensaje crecen con la letra")
  fake.getStringHeight = function() return lh0 end
  rt.remeasure(fake)
  check(rt.layout().lh == lh0 and rt.layout().rows == rows0, "maqueta: vuelve a la medida original")
  back_root()
end

-- ===== 10. acciones F de formularios y cada campo de Ajustes (huecos de checklist)
do
  Store.settings_default(U.g_set)
  -- Calcular f desde el formulario A: F4 CALC f + USAR f devuelve f al campo "f dado"
  restart(); keys("1", "1", "1"); downs(7)
  F(4)
  check(title() == "FACTOR DE FRICCION f", "A: F4 CALC f con el cursor en 'f dado' abre Calcular f")
  keys("down"); TE("20000"); TE("1E-4"); F(5)
  check(shown("Colebrook") and shown("USAR f"), "Calcular f desde A: el resultado ofrece USAR f")
  F(2)
  check(shown("Se copio al formulario"), "Calcular f: USAR f copia f al formulario A")
  keys("enter")
  check(title() == "PERDIDAS DADO Q" and (shown("0.026") or shown("0.0264")), "Calcular f: A recibe f = 0.0264")
  -- en D, E, I la tecla F4 es AJUSTES
  for _, t in ipairs({ { "3", "D" }, { "6", "E" }, { "7", "I" } }) do
    restart(); keys("1", "1", t[1]); F(4)
    check(title() == "AJUSTES", "tipo " .. t[2] .. ": F4 = AJUSTES")
    keys("esc")
    check(title() ~= "AJUSTES", "tipo " .. t[2] .. ": Ajustes vuelve al formulario")
  end
  -- cada uno de los 19 campos de Ajustes se edita y se guarda
  restart(); keys("1", "7", "backtab")
  keys("right", "down")                                   -- metodo: Swamee-Jain
  for _, v in ipairs({ "9.8", "9800", "1.1E-6", "4", "1E-6", "2000", "0.5", "4", "5000", "0.2",
    "2100", "4100", "1.2", "1.5E-5" }) do TE(v) end
  keys("right", "down")                                   -- empuje con aire: Si
  TE("0.62"); TE("1.85")                                  -- Cd vertedores, km/h por nudo
  keys("right")                                           -- manometro: examen
  F(5)
  local g, h = U.g_set, U.g_set.h
  local function nr(a, b) return math.abs(a - b) <= 1e-9 * math.abs(b) end
  check(h.method == 1 and nr(h.g, 9.8) and nr(h.gamma, 9800) and nr(h.nu, 1.1e-6), "Ajustes: metodo, g, gamma, nu")
  check(g.dec == 4 and nr(h.tol, 1e-6) and nr(h.pv, 2000), "Ajustes: decimales, tolerancia, presion de vapor")
  check(h.v_min == 0.5 and h.v_max == 4 and h.ld_limit == 5000 and h.hm_ratio == 0.2,
    "Ajustes: v minima, v maxima, L/D despreciable, hm/hf")
  check(h.re_lam == 2100 and h.re_turb == 4100, "Ajustes: Re laminar, Re turbulento")
  check(nr(g.rho_air, 1.2) and nr(g.nu_air, 1.5e-5) and g.buoy == 1, "Ajustes: rho y nu del aire, empuje con aire")
  check(nr(g.cd_weir, 0.62) and nr(g.knot, 1.85) and g.mano == 1, "Ajustes: Cd vertedores, km/h por nudo, manometro")
  local t = mock.save()
  check(t.cfg.h.v_max == 4 and t.cfg.knot == 1.85 and t.cfg.mano == 1 and t.cfg.buoy == 1,
    "on.save conserva los 19 ajustes")
  Store.settings_default(U.g_set)
  back_root()
end

-- ===== 11. biblioteca completa: cada fluido y cada conjunto de accesorios del curso
do
  local lib = env.require("data.lib")
  local Pipe = env.require("scr.scr_pipe")
  local function nr(a, b) return math.abs(a - b) <= 1e-9 * math.abs(b) + 1e-15 end
  for i = 0, lib.WATERS - 1 do
    local w = lib.waters[i + 1]
    Store.settings_default(U.g_set)
    restart(); keys("1", "5", "3"); downs(i); keys("enter")
    local ok
    if w.rho > 0 and w.rho < 10 then ok = nr(U.g_set.rho_air, w.rho) and nr(U.g_set.nu_air, w.nu)
    else ok = nr(U.g_set.h.nu, w.nu) end
    check(noerr("fluido " .. w.name) and ok, "fluido " .. w.name .. ": valores a Ajustes")
    back_root()
  end
  for i = 0, lib.K_PRESETS - 1 do
    local pr = lib.k_presets[i + 1]
    local sum = 0
    for _, it in ipairs(pr.items) do sum = sum + it.qty * it.K end
    Pipe.pin_reset()
    restart(); keys("1", "5", "2"); F(2); downs(i); keys("enter"); F(5)
    check(noerr("conjunto " .. pr.name) and math.abs(Pipe.pin.K - sum) < 1e-6,
      "conjunto " .. pr.name .. ": Suma K = " .. sum .. " (" .. tostring(Pipe.pin.K) .. ")")
    back_root()
  end
  Store.settings_default(U.g_set)
end

-- ===== 12. AR-1: opciones de Fluido y unidades de velocidad (m/s, km/h, nudos)
do
  Store.settings_default(U.g_set)
  restart(); keys("2", "1", "1", "backtab", "down", "right")
  check(shown("Agua") and shown("1000") and shown("1E-6"), "AR-1: Fluido Agua llena rho y nu")
  keys("right")
  check(shown("Manual"), "AR-1: Fluido Manual")
  keys("right")
  check(shown("Aire (Ajustes)") and shown("1.2"), "AR-1: Fluido Aire (Ajustes) llena rho y nu del aire")
  downs(4); keys("right")
  check(shown("km/h"), "AR-1: unidad km/h")
  keys("right")
  check(shown("nudos"), "AR-1: unidad nudos")
  keys("right"); check(shown("m/s"), "AR-1: unidad m/s (vuelve)")
  back_root()
  local function fd_con(vtxt, unit_rights)
    restart(); keys("2", "1", "1", "backtab", "down", "down", "down", "down")   -- cursor en V
    TE(vtxt)
    local Sd = env.require("scr.scr_drag")
    for _ = 1, 3 do if Sd.drag_save().vunit ~= unit_rights then keys("right") end end
    keys("down"); TE("0.5"); TE("1"); TE("0.5")                      -- CD, figura 1, D
    F(5)
    local ok = vhas("> FD = 23.56")
    back_root()
    return ok
  end
  Store.settings_default(U.g_set)
  check(fd_con("20", 0), "AR-1: V = 20 m/s da FD = 23.56 N")
  check(fd_con("72", 1), "AR-1: V = 72 km/h equivale a 20 m/s")
  check(fd_con("20*3.6/" .. tostring(U.g_set.knot), 2), "AR-1: V en nudos (km/h por nudo de Ajustes) equivale a 20 m/s")
end

print(string.format("test_nav: %d comprobaciones, %d fallo(s)", checks, fails))
if fails > 0 then os.exit(1) end
print("test_nav OK")
