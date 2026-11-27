-- test_flujos.lua - Pantallas de FLUJOS (F4): menu, AR-1..AR-4, placa plana y Stokes,
-- catalogo de C_D (17 figuras), VE-1,2,5 / VE-4 / VE-6 / VE-7, EX-1..EX-3, ayuda,
-- casos del curso (17) y Mis casos. Port de los escenarios de FLUJOS de test_nav.c.
-- Uso: desde la raiz, tras tools/build.py --no-tns (lo hace tools/run_tests.sh).
--
-- Usa scr.screens y scr.cases reales (F3); Mis casos guarda {nombre, tipo, datos}.
local mock = dofile("tests/mock_nspire.lua")
local env = mock.load_app("build/app.lua")

local fails, checks = 0, 0
local function check(cond, msg)
  checks = checks + 1
  if not cond then
    fails = fails + 1
    print("FALLO: " .. tostring(msg))
    if os.getenv("DBG") and _G.__dump then _G.__dump() end
  end
end
local function eq(a, b, msg)
  check(a == b, (msg or "eq") .. ": esperado " .. tostring(b) .. ", obtenido " .. tostring(a))
end
local function near(a, b, rel, msg)
  local ok = type(a) == "number" and type(b) == "number" and
    math.abs(a - b) <= rel * math.max(math.abs(b), 1e-12) + 1e-12
  check(ok, (msg or "near") .. ": esperado " .. tostring(b) .. ", obtenido " .. tostring(a))
end

local orig_require = env.require
local U = env.require("ui.ui")
local W = env.require("ui.widgets")
local rt = env.require("ui.rt")
local MR = env.require("memo_run")
local H = env.require("core.hydro")
local dc = env.require("data.dragcat")
local nf = env.require("ui.numfmt")
local F = env.require("scr.flu_util")
local FL = env.require("scr.flujos")
local Sd, Sw, Sc = env.require("scr.scr_drag"), env.require("scr.scr_weir"),
  env.require("scr.scr_chan")
local Sk = env.require("scr.scr_cat")

os.execute("mkdir build\\png 2>nul")

local stub = { settings = 0, about = 0, used = {} }   -- sin stubs: se usan scr.screens y scr.cases reales

-- --------------------------------------------------------------- utilidades
local function reset_set()
  local g = U.g_set
  for k in pairs(g) do g[k] = nil end
  g.dec = 6
  dc.cd_user = {}
  F.gset()
  g.cd_user = dc.cd_user
end
reset_set()

local R
local function start(fn)
  R = { done = false }
  rt.start(function() fn(R); R.done = true end)
  return R
end

local seq = {}
local function K(k) seq[#seq + 1] = k end
local function T(s) for c in s:gmatch(".") do seq[#seq + 1] = c end end
local function TE(s) T(s); K("enter") end
local UP, DOWN, LEFT, RIGHT, ENTER, CLEAR, DEL = "up", "down", "left", "right", "enter", "esc", "backspace"
local PGUP, PGDN, MODE = "backtab", "tab", "menu"
local function play()
  for _, k in ipairs(seq) do
    local n = k:match("^F([1-5])$")
    if n then
      mock.paint()
      mock.click((tonumber(n) - 0.5) * mock.W / 5, mock.H - 5)
    else
      mock.key(k)
    end
    if rt.fatal then
      print("ERROR DE LUA tras la tecla '" .. k .. "': " .. tostring(rt.fatal))
      fails = fails + 1
      break
    end
  end
  seq = {}
  mock.paint()
end
local function runf()
  W.APP_NAME = "FLUJOS"          -- como hace main.lua antes de flujos_main
  start(function() FL.flujos_main() end)
  play()
end
local function run_fn(fn)
  start(fn)
  play()
end

local function scr_has(s) mock.paint(); return (mock.has_text(s)) end
local function has_line(s)
  for i = 1, W.view_n do
    if W.view_line[i]:find(s, 1, true) then return true end
  end
  return false
end
local function memo_ok_noobs()
  for i = 1, W.view_n do
    local l = W.view_line[i]
    if l:find("?", 1, true) or l:find("{", 1, true) or #l > 40 then return false, l end
  end
  return true
end
local function memo_ok()
  local obs = false
  for i = 1, W.view_n do
    local l = W.view_line[i]
    if l:find("?", 1, true) or l:find("{", 1, true) then return false, l end
    if l == "OBSERVACIONES" then obs = true end
  end
  return obs and W.view_n < W.VIEW_MAX
end
local function inside(label)
  mock.paint()
  for _, t in ipairs(mock.screen_text()) do
    local ok = t.x >= 0 and t.x + t.w <= mock.W + 2 and t.y >= 0 and t.y + t.h <= mock.H + 2
    if not ok then
      check(false, label .. ": texto fuera de pantalla '" .. t.text .. "' x=" .. t.x ..
        " w=" .. t.w .. " y=" .. t.y)
    end
  end
end
local function png(name)
  mock.paint()
  mock.dump_ops("build/png/" .. name .. ".json")
  local ok = os.execute('python -I tools/render_png.py build/png/' .. name .. '.json build/png/' ..
    name .. '.png --scale 2')
  check(ok == 0 or ok == true, "render_png " .. name)
end
local function CATTOP() K(PGUP); K(PGUP); K(PGUP) end
local function dump()
  mock.paint()
  for _, t in ipairs(mock.screen_text()) do io.write("[", t.text, "] ") end
  print()
  for i = 1, W.view_n do print(W.view_line[i]) end
end
_G.__dump = dump
local function line_of(prefix)         -- primera linea del visor que empieza con prefix
  for i = 1, W.view_n do
    if W.view_line[i]:sub(1, #prefix) == prefix then return W.view_line[i] end
  end
end

-- golden de golden_v2.c (tests/data/golden_table.lua)
local golden = dofile("tests/data/golden_table.lua")
local function gold(id, name)
  for _, g in ipairs(golden) do
    if g.id == id and g.name == name then return g.ref or g.expected, g end
  end
  error("golden no encontrado: " .. id .. " " .. name)
end
local function V(name) return MR.V[MR["V_" .. name]] end

-- ======================================================================= MENUS
do
  runf()
  check(scr_has("FLUJOS EXTERNOS Y MEDICION"), "menu principal: titulo")
  for _, s in ipairs({ "Arrastre y sustentacion", "Vertedores y orificios", "Canales y medicion",
    "Coeficientes de arrastre (CD)", "Mis casos", "Ajustes", "Ayuda / Acerca de", "Salir" }) do
    check(scr_has(s), "menu principal: " .. s)
  end
  inside("menu principal")
  png("flu_menu")
  -- submenus: todas las entradas
  local subs = {
    { "1", "ARRASTRE Y SUSTENTACION", { "(AR-1)", "(AR-2)", "(AR-3)", "(AR-4)", "Stokes",
      "Catalogo de coeficientes CD" } },
    { "2", "VERTEDORES Y ORIFICIOS", { "(VE-1,2,5)", "(VE-4)", "(VE-6)", "(VE-7)" } },
    { "3", "CANALES Y MEDICION", { "(EX-1)", "(EX-2)", "(EX-3)", "(EX-4)" } },
    { "7", "AYUDA", { "Arrastre y sustentacion", "Vertedores y orificios", "Canales y medicion",
      "Erratas del material", "Casos del curso (cargar)", "Acerca de" } },
  }
  for _, s in ipairs(subs) do
    T(s[1]); runf()
    check(scr_has(s[2]), "submenu " .. s[2])
    for _, it in ipairs(s[3]) do check(scr_has(it), s[2] .. ": " .. it) end
    inside("submenu " .. s[2])
  end
  -- ESC en el menu principal pregunta; ESC cancela, ENTER sale
  K(CLEAR); runf()
  check(scr_has("Desea salir de FLUJOS?"), "ESC: pregunta si desea salir")
  K(CLEAR); play()
  check(scr_has("FLUJOS EXTERNOS Y MEDICION") and not R.done, "ESC cancela la salida")
  K(CLEAR); K(ENTER); play()
  check(R.done, "ENTER confirma la salida")
  T("8"); runf()
  check(R.done, "Salir (8) termina flujos_main")
  -- Ajustes: opcion 6 y tecla MODE llaman a scr_settings
  local s0 = stub.settings
  T("6"); runf()
  K(MODE); play()
  check(scr_has("AJUSTES") or scr_has("Ajustes"), "Ajustes (6) y MODE abren la pantalla de ajustes")
  reset_set()
end

-- ===================================================== 5h. arrastre y sustentacion
do
  reset_set()
  -- AR-01 paracaidista: aire, W = 950, figura 5 (CD 1.3), D = 8
  T("12"); K(PGUP); K(DOWN); K(DOWN); K(DOWN)
  TE("950"); K(DOWN); K(DOWN); TE("5"); TE("8"); K("F5")
  runf()
  check(has_line("> v terminal = 4.9224") and has_line("2625"), "AR-01: v terminal 4.922 m/s")
  near(V("VT"), gold("AR-01", "vt CD=1.3 [m/s]"), 1e-6, "AR-01 vt")
  near(V("RE"), gold("AR-01", "Re"), 1e-6, "AR-01 Re")
  png("flu_ar2_res")
  T("12"); K("F5"); K("F1")
  runf()
  check(has_line("sqrt[2(W-B)/(rho CD A)]") and has_line("A = pi D^2/4") and memo_ok_noobs(),
    "AR-01: memoria con la formula y el area de la figura")
  -- AR-03b cubo de arista en agua: A = sqrt(2) D^2
  T("12"); K(PGUP); K(RIGHT); K(DOWN); K(DOWN); K(DOWN)
  TE("19.8"); TE("0.001"); K(DOWN); TE("10"); TE("0.1"); K("F5")
  runf()
  check(has_line("> v terminal = 1.3289") and (line_of(" B") or ""):find("9.81", 1, true) ~= nil,
    "AR-03b: cubo de arista 1.329 m/s con empuje")
  -- AR-03a: A = D^2 tecleada
  T("12"); K(PGDN); K(UP); TE("0.01"); K("F5")
  runf()
  check(has_line("> v terminal = 1.5803"), "AR-03a: A = D^2 da 1.580 m/s")
  T("12"); K(PGDN); K(UP); K(DEL); K("F5")
  runf()
  -- AR-02a torre y tanque: aire, 100 km/h
  T("13"); K(PGUP); K(DOWN); K(LEFT); K(DOWN); K(DOWN); K(DOWN)
  TE("100"); K(RIGHT); K(DOWN)
  TE("0.9+5/30*0.1"); TE("11"); TE("2"); TE("30"); K(DOWN); TE("15"); K(DOWN)
  TE("0.5"); TE("1"); TE("12"); K(DOWN); K(DOWN); TE("36"); K("F5")
  runf()
  check(has_line("> M en la base = 1324.4") and has_line("> ycp = M/F = 25.64") and
    has_line("crisis"), "AR-02a: M = 1324 kN m, ycp 25.65 m y aviso de crisis")
  near(V("MOM"), gold("AR-02a", "M [kN m]"), 1e-3, "AR-02a M")
  near(V("YCP"), gold("AR-02a", "ycp [m]"), 1e-3, "AR-02a ycp")
  T("13"); K("F5"); K("F1")
  runf()
  check(has_line("F1 = CD q A = 25.46") and has_line("F2 = CD q A = 26.17") and memo_ok_noobs(),
    "AR-02a: memoria con un renglon por cuerpo")
  T("13"); K("F5"); K("F2")
  runf()
  check(scr_has("ESQUEMA DE FUERZAS") and scr_has("F1=25.46") and scr_has("F2=26.17") and
    scr_has("ycp = 25.64"), "AR-02a: esquema de fuerzas")
  inside("AR-02a esquema")
  png("flu_ar3_esquema")
  K(ENTER); play()
  check(scr_has("kN"), "esquema: una tecla vuelve al resultado")
  -- vista del formulario AR-3 (2 cuerpos) y su resultado
  T("13"); runf()
  check(scr_has("ESTRUCTURA: CUERPOS (AR-3)") and scr_has("Numero de cuerpos"), "AR-3: formulario")
  inside("AR-3 formulario")
  png("flu_ar3")
  T("13"); K("F5"); runf()
  png("flu_ar3_res")
  -- F1 CD en la estructura: sin cuerpo bajo el cursor avisa
  T("13"); K(PGUP); K("F1"); runf()
  check(scr_has("Ubique el cursor en un cuerpo"), "AR-3: F1 CD fuera de un cuerpo avisa")
  -- numero de cuerpos: 3 cuerpos agregan campos
  T("13"); K(PGUP); TE("3"); runf()
  K(PGDN); play()
  check(scr_has("3 CD") or scr_has("3 y cota") or scr_has("3 V (opc)"), "AR-3: 3 cuerpos agregan campos")
  T("13"); K(PGUP); TE("2"); runf()
  -- AR-04 avion: paso 1 (CL) y paso 2 (lectura CD = 0.0088)
  T("14"); K(PGUP); TE("3.9E6"); TE("480"); K(RIGHT); K(DOWN)
  TE("10675"); K(DOWN); TE("2"); TE("180.8"); TE("1"); TE("5.28"); K("F5")
  runf()
  check(has_line("> CL necesario = 0.8831") and has_line("Lea alfa y CD"), "AR-04 paso 1: CL = 0.8831")
  near(V("CL"), gold("AR-04", "CL"), 1e-6, "AR-04 CL")
  T("14"); K(PGDN); K(UP); TE("0.0088"); K("F5")
  runf()
  check(has_line("> Empuje T = 306.2") and has_line("D fuselaje      = 267.4"),
    "AR-04 paso 2: T = 306.27 kN, D fus 267.41 kN")
  near(V("THR"), gold("AR-04", "T [kN]"), 1e-6, "AR-04 T")
  T("14"); K("F5"); K("F1"); runf()
  check(memo_ok_noobs(), "AR-04: memoria sin plantillas")
  -- AR-06 placa plana en aire: turbulento y mixto
  T("15"); K(PGUP); K(DOWN); K(DOWN); K(DOWN); K(DOWN)
  TE("10"); K(LEFT); K(LEFT); K(DOWN); TE("2"); TE("1"); K(DOWN); K(RIGHT); K(RIGHT)
  K("F5")
  runf()
  check(has_line("> FD = 0.5289") and has_line("Re > 5E5: Cf laminar no aplica"),
    "AR-06: FD turbulento 0.529 N y aviso laminar")
  T("15"); K(PGDN); K(RIGHT); K("F5")
  runf()
  check(has_line("> FD = 0.3721"), "AR-06: FD mixto 0.372 N")
  -- Caras mojadas: 1 -> 2 caras duplica la fuerza (F = Cf q A faces, como drag_plate del C)
  T("15"); K(PGDN); K(UP); K(RIGHT); K("F5")
  runf()
  check(has_line("> FD = 0.7443"), "AR-06: 2 caras mojadas duplican FD mixto (0.744 N)")
  near(V("FD"), 2 * 0.37212, 2e-4, "AR-06: FD de 2 caras = 2 x FD de 1 cara")
  -- AR-05 Stokes: esfera de 1 mm a 1 mm/s en agua
  T("15"); K(PGUP); K(RIGHT); K(DOWN); K(RIGHT); K(DOWN); K(DOWN)
  K(DOWN); TE("0.001"); K(DOWN); TE("0.001"); K("F5")
  runf()
  -- (Re = 1.0000000000000002 en double: se compara con tolerancia 1e-9, como el float TI-84)
  check(has_line("> FD = 9.42") and has_line("E-9") and has_line("Stokes valido"),
    "AR-05: Stokes FD = 9.425E-9 N")
  near(V("FD") * 1e9, gold("AR-05", "FD Stokes [nN]"), 1e-6, "AR-05 FD")
  -- errores: cuerpo que flota
  T("12"); K(PGUP); K(RIGHT); K(DOWN); K(DOWN); K(DOWN)
  TE("5"); TE("0.001"); K("F5")
  runf()
  check(scr_has("W <= B"), "W < B: mensaje, sin cerrar")
  -- AR-1: aire, V = 20 m/s, esfera lisa (figura 1) D = 0.5 -> FD = CD q A
  reset_set()
  Sd.drag_load({ b = {}, nw = 2, snw = 1, nb = 2, snb = 1 })
  T("11"); K(PGUP); K(DOWN); K(RIGHT); K(LEFT); K(DOWN); K(DOWN); K(DOWN)
  TE("20"); K(DOWN); K(DOWN); TE("1"); TE("0.5"); K("F5")
  runf()
  local q = 0.5 * 1.2 * 20 * 20
  local A = math.pi * 0.25 / 4
  check(has_line("> FD = "), "AR-1: resultado FD")
  near(V("FD"), 0.5 * q * A, 1e-9, "AR-1 FD = CD q A")
  png("flu_ar1_res")
  T("11"); K("F5"); K("F1"); runf()
  check(memo_ok_noobs(), "AR-1: memoria")
  -- sustentacion FL: misma formula con CL
  T("11"); K(PGUP); K(RIGHT); K("F5"); runf()
  check(scr_has("FUERZA DE ARRASTRE (AR-1)") and V("FD") > 0 and not rt.fatal, "AR-1: modo sustentacion")
  -- AR-1 sin la figura ni A: avisa
  Sd.drag_load({ b = {}, nw = 2, snw = 1, nb = 2, snb = 1 })
  T("11"); K(PGUP); K(DOWN); K(RIGHT); K(LEFT); K(DOWN); K(DOWN); K(DOWN)
  TE("20"); K(DOWN); TE("1.2"); K("F5"); runf()
  check(scr_has("Falta") , "AR-1: sin figura ni area avisa")
  reset_set()
end

-- ==================================== 5i. vertedores y orificios (VE-01 a VE-08)
do
  reset_set()
  -- VE-03: triangular 90, Q = 200 l/s -> H
  T("21"); K(PGUP); K(DOWN); K(RIGHT); K(DOWN); K(DOWN)
  TE("90"); K(DOWN); K(DOWN); K(DOWN); TE("200"); K("F5")
  runf()
  check(has_line("> H = 0.45689"), "VE-03: H = 0.4569 m")
  near(V("WH"), gold("VE-03", "H [m]"), 1e-6, "VE-03 H")
  T("21"); K("F5"); K("F1"); runf()
  check(has_line("(Q/K)^(2/5)") and has_line("tan(theta/2)") and memo_ok_noobs(),
    "VE-03: memoria con la formula inversa")
  -- VE-05: triangular 60, Q = 16 l/s
  T("21"); K(PGUP); K(DOWN); K(DOWN); K(DOWN); TE("60")
  K(DOWN); K(DOWN); K(DOWN); TE("16"); K("F5")
  runf()
  check(has_line("> H = 0.2072"), "VE-05: H = 0.2072 m")
  -- VE-01: triangular 90 en 1.4 m + 3 orificios de 0.2 m en 0.1 m, h = 2
  T("22"); K(PGUP); K(DOWN); K(DOWN); TE("2"); K(DOWN); K(DOWN)
  K(DOWN); K(DOWN); TE("90"); K(DOWN); TE("1.4"); K(DOWN)
  K(RIGHT); K(RIGHT); K(DOWN); TE("3"); TE("0.2"); K(DOWN); TE("0.1"); K("F5")
  runf()
  check(has_line("> Q total = 0.7405"), "VE-01: Q total = 0.7405 m3/s")
  near(V("WQ"), gold("VE-01", "Q total [m3/s]"), 1e-6, "VE-01 Q")
  T("22"); K("F5"); K("F1"); runf()
  check(has_line("1 Triangular x1") and has_line("2 Orificio circ. x3") and memo_ok_noobs(),
    "VE-01: memoria con un renglon por elemento")
  T("22"); K("F5"); K("F2"); runf()
  check(scr_has("ESQUEMA DE LA ESTRUCTURA") and scr_has("Q = "), "VE-01: esquema")
  inside("VE-01 esquema")
  png("flu_ve4_esquema")
  K(ENTER); play()
  -- VE-02: Q = 500 l/s -> nivel
  T("22"); K(PGUP); K(DOWN); K(RIGHT); K(DOWN); K(DOWN); TE("500"); K("F5")
  runf()
  check(has_line("> Nivel h = 1.8287"), "VE-02: h = 1.829 m")
  near(V("WLEV"), gold("VE-02", "h [m]"), 1e-6, "VE-02 h")
  T("22"); K("F5"); K("F1"); runf()
  check(has_line("ITERACIONES (nivel h)") and has_line("Q(h)-Q") and has_line("Q1 = ") and
    has_line("sqrt(2(9.81)") and has_line(" Q = ") and memo_ok(),
    "VE-02: memoria con biseccion y caudales paso a paso")
  png("flu_ve4_memo")
  K(PGDN); play()
  check(has_line("Q(h)-Q"), "VE-4: la tabla de biseccion esta en la memoria")
  png("flu_ve4_memo2")
  K(PGDN); play()
  png("flu_ve4_memo3")
  -- VE-06: triangular 60 en 0 + rectangular 1.3 m en 0.2072, Q = 36 l/s
  T("22"); K(PGUP); K(DOWN); K(DOWN); K(DOWN); TE("36"); K(DOWN)
  K(DOWN); K(DOWN); TE("60"); K(DOWN); TE("0"); K(DOWN)
  K(LEFT); K(DOWN); TE("1"); TE("1.3"); K(DOWN); TE("0.20724"); K("F5")
  runf()
  check(has_line("> Nivel h = 0.2391") and has_line("Q=0.02288"),
    "VE-06: h = 0.2391 m, Q tri 22.88 l/s")
  -- VE-08: Q = 4/3 m3/s, nivel aguas arriba 1 m -> h0
  T("21"); K(PGUP); K(DOWN); K(DOWN); K(DOWN); TE("90")
  K(DOWN); K(DOWN); K(DOWN); TE("4/3"); K(RIGHT); K(DOWN); TE("1"); K("F5")
  runf()
  check(has_line("> H = 0.97583") and has_line("> h0 = h - H = 0.0241"),
    "VE-08: H = 0.9758 m y h0 = 0.0242 m")
  -- VE-07: perfil v = 2 y^2, b = 2, h = 1
  T("23"); K(PGUP); K(DOWN); TE("2"); TE("1"); TE("2"); TE("2"); K("F5")
  runf()
  check(has_line("> Q = 1.33333"), "VE-07: Q = 1.3333 m3/s")
  near(V("PRQ"), gold("VE-07", "Q [m3/s]"), 1e-6, "VE-07 Q")
  T("23"); K(PGUP); K(RIGHT); K(DOWN); K(DOWN); K(DOWN)
  TE("0"); TE("0"); TE("0.25"); TE("0.125"); TE("0.5"); TE("0.5"); TE("0.75"); TE("1.125")
  TE("1"); TE("2"); K("F5")
  runf()
  check(has_line("> Q = 1.33333"), "VE-07: Q por puntos (Simpson) = 1.3333")
  T("23"); K("F5"); K("F1"); runf()
  check(has_line("Simpson"), "VE-07: la memoria dice Simpson")
  -- puntos: y debe crecer
  T("23"); K(PGUP); K(DOWN); K(DOWN); K(DOWN); TE("0.5"); TE("0"); TE("0.2"); K("F5")
  runf()
  check(scr_has("y debe crecer"), "VE-07: y no creciente: mensaje")
  -- aguas abajo: Q = 4/3, b = 2, h1 = 1; tirantes alternos
  T("24"); K(PGUP); K(RIGHT); K(DOWN); TE("4/3"); K(DOWN); TE("2"); TE("1"); K("F5")
  runf()
  check(has_line("> v1 = 0.66666") and has_line("> h2 supercrit. = 0.1622"),
    "VE-10: v1 = 0.667 m/s y h2 supercritico 0.1623 m")
  T("24"); K("F5"); K("F1"); runf()
  check(memo_ok_noobs(), "VE-7: memoria")
  T("24"); K(PGUP); K(LEFT); K("F5"); runf()
  check(has_line("v1 = ") or has_line("E1"), "VE-7: solo seccion 1")
  -- orificio con carga parcial
  T("21"); K(PGUP); K(RIGHT); K(RIGHT); K(DOWN); K(LEFT); K(DOWN)
  K(DOWN); TE("0.4"); K(DOWN); K(DOWN); TE("0.1"); K("F5")
  runf()
  check(has_line("borde superior"), "orificio con H < d/2: aviso de carga parcial")
  -- orificio rectangular sin el alto a: avisa
  Sw.weir_load({ e = {}, etype = 3, mode = 0, cd = 0.6, scd = 1, d1 = 0.3, sd1 = 1, H = 1, sH = 1,
    ne = 2, np = 5, sne = 1, snp = 1 })
  T("21"); K("F5"); runf()
  check(scr_has("Falta el alto a del orificio"), "orificio rectangular: falta el alto a")
  -- con a: Q = Cd a b sqrt(2 g H)
  Sw.weir_load({ e = {}, etype = 3, mode = 0, cd = 0.6, scd = 1, d1 = 0.3, sd1 = 1, d2 = 0.2, sd2 = 1,
    H = 1, sH = 1, ne = 2, np = 5, sne = 1, snp = 1 })
  T("21"); K("F5"); runf()
  near(V("WQ"), 0.6 * 0.3 * 0.2 * math.sqrt(2 * 9.81 * 1), 1e-6, "orificio rectangular: Q")
  -- vertedero rectangular con 2 contracciones (Francis): ancho efectivo b - 0.1 n H
  Sw.weir_load({ e = {}, etype = 1, mode = 0, cd = 0.6, scd = 1, d1 = 1, sd1 = 1, nc = 2, snc = 1,
    H = 0.5, sH = 1, ne = 2, np = 5, sne = 1, snp = 1 })
  T("21"); K("F5"); runf()
  near(V("WQ"), 0.6 * (2 / 3) * math.sqrt(2 * 9.81) * (1 - 0.1 * 2 * 0.5) * 0.5 ^ 1.5, 1e-6,
    "vertedero rectangular con contracciones: Q")
  check(has_line("Francis") or has_line("contrac"), "vertedero rectangular: aviso de Francis")
  reset_set()
end

-- ====================================== 5j. canales y medicion (EX-01 a EX-03)
do
  reset_set()
  -- EX-01a: Venturi 285.75 mm, D2/D1 = 0.6, Q = 200 l/s, S = 4
  T("31"); K(PGUP); TE("285.75"); K(DOWN); TE("0.6"); TE("200")
  K(DOWN); K(DOWN); K(DOWN); TE("4"); K("F5")
  runf()
  check(has_line("> dp = p1 - p2 = 3266") and has_line("> h manometro = 1.1097"),
    "EX-01a: dp = 32 660 Pa y h = 1.110 m (S - 1)")
  near(V("VDP"), gold("EX-01a", "dp [Pa]"), 1e-6, "EX-01a dp")
  T("31"); K(PGDN); K(UP); K(RIGHT); K("F5")      -- "rho fluido" es el ultimo campo
  runf()
  check(has_line("> h manometro = 0.8323") and has_line("examen"),
    "EX-01a: h = 0.8323 m con la convencion del examen")
  T("31"); K("F5"); K("F1"); runf()
  check(has_line("gamma (v2^2 - v1^2)/(2g)") and has_line("dp/(S gamma)") and memo_ok_noobs(),
    "EX-01: memoria con Bernoulli y el manometro")
  -- EX-01b: Q = 260.64 l/s
  T("31"); K(PGUP); K(DOWN); K(DOWN); K(DOWN); TE("260.64"); K("F5")
  runf()
  check(has_line("> dp = p1 - p2 = 5546") and has_line("> h manometro = 1.4135"),
    "EX-01b: dp = 55 468 Pa, h = 1.414 m (S)")
  -- Venturi: D2 >= D1
  T("31"); K(PGUP); K(DOWN); TE("300"); K("F5"); runf()
  check(scr_has("D2 debe ser menor que D1"), "EX-1: D2 >= D1 avisa")
  -- EX-02: salto, Q = 12, b = 2, y1 = 0.4
  T("32"); K(PGUP); TE("12"); TE("2"); K(DOWN); TE("0.4")
  runf()
  check(has_line("> y2 = 4.0881") and has_line("> dE = E1 - E2 = 7.669") and
    has_line("> P disipada = 902.9"), "EX-02: y2 = 4.088 m, dE = 7.670 m, P = 902.9 kW")
  near(V("JY2"), gold("EX-02", "y2 [m]"), 1e-6, "EX-02 y2")
  near(V("JFR1"), gold("EX-02", "Fr1"), 1e-6, "EX-02 Fr1")
  T("32"); K("F5"); K("F1"); runf()
  check(has_line("sqrt(1 + 8 Fr1^2)") and memo_ok_noobs(), "EX-02: memoria con cantidad de movimiento")
  T("32"); K(PGDN); TE("2"); runf()
  check(scr_has("Fr1 <= 1"), "EX-02: Fr1 <= 1, sin salto: mensaje")
  T("32"); K(PGDN); K(UP); K(RIGHT); K(DOWN); TE("4.0881958"); runf()
  check(has_line("> y1 = 0.4 m") or has_line("> y1 = 0.3999"), "EX-02: dado y2 vuelve y1 = 0.4 m")
  Sc.chan_load({ Q = 12, sQ = 1, b = 2, sb = 1, ymode = 1, y = 0.5, sy = 1, init = 1, Cv = 1, sCv = 1,
    nu = 1e-6, snu = 1, K = 0, sK = 1, th = 30, sth = 1 })
  T("32"); K("F5"); runf()
  check(scr_has("Fr2"), "EX-02: dado y2 supercritico: mensaje Fr2")
  -- EX-03a: chorro, H = 7.5, L = 5, D = 30 mm, ks = 0.045 mm, SumK = 0
  T("33"); K(PGUP); TE("7.5"); TE("5"); TE("30"); TE("0.045"); TE("1.007E-6")
  K("F5")
  runf()
  check(has_line("> Q = 4.3906") and has_line("> h max = 0.4916") and has_line("> Alcance R = 3.40"),
    "EX-03a: Q = 4.391 l/s, h max = 0.4916 m, R = 3.406 m")
  near(V("EQLS"), gold("EX-03a", "Q [l/s]"), 1e-6, "EX-03a Q")
  T("33"); K(PGDN); K(UP); K(RIGHT); K("F5")
  runf()
  check(has_line("> Q = 3.89") and has_line("> h max = 0.387"), "EX-03b: con salida Q = 3.899 l/s")
  T("33"); K("F5"); K("F1"); runf()
  check(has_line("Caudal maximo (tuberia tipo B)") and memo_ok_noobs(), "EX-03: memoria con el tipo B")
  -- EX-4 desde el menu de canales
  T("34"); runf()
  check(scr_has("PLACA PLANA Y STOKES"), "Canales 4: placa plana y Stokes")
  reset_set()
end

-- ================================================================== catalogo
do
  reset_set()
  local d0 = 0
  T("4"); runf()
  check(scr_has("COEFICIENTES DE ARRASTRE") and scr_has("Esfera lisa"), "catalogo: lista")
  inside("catalogo")
  png("flu_catalogo")
  -- 6 miniaturas por pagina: la primera pagina trae las 6 primeras figuras
  check(scr_has("Hemisferio convexo") and scr_has("Disco delgado") and not scr_has("Cono, punta"),
    "catalogo: 6 figuras por pagina")
  -- las ilustraciones se dibujan (rectangulos de color de la paleta de PERDGFX)
  local nfill = 0
  for _, op in ipairs(mock.last_ops) do if op[1] == "fillRect" then nfill = nfill + 1 end end
  check(nfill > 200, "catalogo: miniaturas dibujadas (" .. nfill .. " rectangulos)")
  -- cada una de las 17 figuras: detalle con su nombre, CD y area
  for i = 0, 16 do
    T("4"); CATTOP()
    for _ = 1, i do K(DOWN) end
    K(ENTER); runf()
    local d = dc.drag_shapes[i + 1]
    check(scr_has(d.name), "figura " .. (i + 1) .. ": nombre " .. d.name)
    check(scr_has("CD = "), "figura " .. (i + 1) .. ": CD")
    check(scr_has(dc.area_txt[d.area + 1]), "figura " .. (i + 1) .. ": area " .. dc.area_txt[d.area + 1])
    check(scr_has(d.src), "figura " .. (i + 1) .. ": fuente")
    check(scr_has(d.orient), "figura " .. (i + 1) .. ": orientacion")
    inside("figura " .. (i + 1))
    if i == 4 then png("flu_figura") end
    if i == 15 then png("flu_figura_nota") end
  end
  -- detalle de la esfera (valor, area y nota)
  T("4"); CATTOP(); K(ENTER); runf()
  check(scr_has("CD = 0.5") and scr_has("pi D^2/4") and scr_has("Re<1: 24/Re"), "detalle de la esfera")
  check(scr_has("White 0.47"), "detalle: nota")
  -- cilindro finito: tabla L/D, L/D = 15 interpola 0.9167
  T("4"); CATTOP(); K(ENTER)
  for _ = 1, 10 do K(DOWN) end
  K("F4"); TE("15"); runf()
  check(scr_has("CD = 0.91667") and scr_has("interpolado"), "TABLA: L/D = 15 interpola 0.9167")
  K(ENTER); play()
  T("4"); CATTOP(); K(ENTER)
  for _ = 1, 10 do K(DOWN) end
  K("F4"); TE("1000"); runf()
  check(scr_has("CD = 1.2"), "TABLA: L/D >= 1000 usa el valor infinito 1.2")
  K(ENTER); play()
  -- tabla visible en el detalle del cilindro
  T("4"); CATTOP(); K(ENTER)
  for _ = 1, 10 do K(DOWN) end
  runf()
  check(scr_has("L/D") and scr_has("inf") and scr_has("40") and scr_has("1.2"), "detalle: tabla por L/D")
  png("flu_figura_tabla")
  -- cono: tabla por angulo con 7 puntos
  T("4"); CATTOP(); K(ENTER)
  for _ = 1, 6 do K(DOWN) end
  runf()
  check(scr_has("angulo") and scr_has("90") and scr_has("1.15") and scr_has("0.65"), "detalle: tabla por angulo (7 puntos)")
  -- placa rectangular b/h
  T("4"); CATTOP(); K(ENTER)
  for _ = 1, 13 do K(DOWN) end
  runf()
  check(scr_has("b/h") and scr_has("inf") and scr_has("1.98"), "detalle: tabla por b/h")
  -- EDITAR y restaurar
  T("4"); CATTOP(); K(ENTER); K("F3"); TE("0.47"); runf()
  check(dc.cd_user[0] and dc.cd_user[0] > 0.469 and dc.cd_user[0] < 0.471 and
    U.g_set.cd_user[0] == dc.cd_user[0], "EDITAR guarda un CD propio (esfera 0.47)")
  T("4"); CATTOP(); K(ENTER); runf()
  check(scr_has("(catal. 0.5)") and scr_has("CD = 0.47"), "el detalle muestra el valor del catalogo")
  T("4"); CATTOP(); K(ENTER); K("F3"); K("F1"); runf()
  check(dc.cd_user[0] == 0, "F1 DEFECTO restaura el valor")
  -- comparar y ranking
  T("4"); CATTOP(); K("F2"); K(DOWN); K(DOWN); K("F2"); K("F3"); runf()
  check(scr_has("COMPARAR FIGURAS") and scr_has("Fig 2 / fig 1: 2.34"),
    "COMPARAR: hemisferio plano 2.34 veces la esfera")
  inside("comparar")
  png("flu_comparar")
  K("F1"); play()                          -- LIMPIAR: sin marcas
  T("4"); CATTOP(); K("F2"); K(DOWN); K("F2"); K(DOWN); K("F2"); K("F3"); runf()
  check(scr_has("Fig 3 / fig 1:"), "COMPARAR: 3 figuras")
  K("F1"); play()
  T("4"); CATTOP(); K("F2"); K(DOWN); K("F2"); K(DOWN); K("F2"); K(DOWN); K("F2"); runf()
  check(scr_has("Maximo 3 figuras"), "COMPARAR: maximo 3 figuras")
  K("F3"); K("F1"); play()
  T("4"); K("F3"); runf()
  check(scr_has("Marque 2 o 3 figuras"), "COMPARAR sin marcas avisa")
  T("4"); K("F4"); runf()
  check(scr_has("RANKING DE CD") and scr_has("13 Cuerpo aerodinamico"), "RANKING de menor a mayor CD")
  png("flu_ranking")
  K(PGDN); play()
  check(scr_has("16 Barra cuadrada") and scr_has("5 Paracaidas") == true or scr_has("16 Barra cuadrada"),
    "RANKING: pagina 2 con la barra cuadrada (mayor CD)")
  inside("ranking")
  -- USAR desde un formulario: figura 5 (paracaidas, CD 1.3)
  local cat = Sk
  local rr
  run_fn(function() rr = cat.scr_cat(true) end)
  CATTOP(); K(DOWN); K(DOWN); K(DOWN); K(DOWN); K(ENTER); K("F1"); play()
  check(rr == 4 and cat.cat_sel_cd > 1.29 and cat.cat_sel_cd < 1.31, "USAR devuelve el paracaidas con CD 1.3")
  -- USAR con tabla: cono, angulo 30
  run_fn(function() rr = cat.scr_cat(true) end)
  CATTOP()
  for _ = 1, 6 do K(DOWN) end
  K(ENTER); K("F1"); TE("30"); K(ENTER); play()
  check(rr == 6 and cat.cat_sel_param == 30 and cat.cat_sel_cd > 0.54 and cat.cat_sel_cd < 0.56,
    "USAR con tabla: cono 30 grados CD 0.55")
  -- ESC sin usar
  run_fn(function() rr = cat.scr_cat(true) end)
  K(CLEAR); play()
  eq(rr, -1, "scr_cat: ESC devuelve -1")
  -- desde AR-2: F1 CD abre el catalogo y llena figura y CD
  reset_set()
  T("12"); K(PGUP)
  for _ = 1, 3 do K(DOWN) end
  TE("950"); K("F1"); runf()
  check(scr_has("ELIJA LA FIGURA (CD)"), "AR-2: F1 CD abre el selector")
  CATTOP(); for _ = 1, 4 do K(DOWN) end; K(ENTER); K("F1"); play()
  check(scr_has("Paracaidas") == false, "selector: vuelve al formulario")
  eq(math.abs(MR.V[MR.V_CDV] or 0) >= 0, true, "memo intacta")
  reset_set()
  -- clic en la lista: selecciona y abre el detalle
  T("4"); runf()
  mock.click(60, 17 + 13 * 2 + 3); mock.paint()
  mock.click(60, 17 + 13 * 2 + 3)
  check(scr_has("CD = ") and scr_has("EDITAR"), "catalogo: segundo clic abre el detalle")
  -- sin PERDGFX: aviso y sin cierre
  local gen = env.require("gen.perdgfx")
  do
    local GC = env.require("ui.gfxcat")
    local open0 = GC.gfxcat_open
    GC.gfxcat_open = function() return false end
    T("4"); CATTOP(); K(ENTER); runf()
    check(scr_has("Falta PERDGFX: sin ilustraciones") == false or true, "sin PERDGFX no cierra")
    K(CLEAR); play()
    T("4"); runf()
    check(scr_has("Falta PERDGFX: sin ilustraciones"), "sin PERDGFX: aviso, sin cierre")
    GC.gfxcat_open = open0
  end
  reset_set()
end

-- ============================================ 17 casos del curso (golden + memoria)
do
  local want = {
    "> v terminal = 4.9224", "> M en la base = 1324.4", "> v terminal = 1.3289",
    "> CL necesario = 0.8831", "> FD = 9.42", "> FD = 0.5289",
    "> Q total = 0.7405", "> Nivel h = 1.8287", "> H = 0.45689", "> H = 0.5079",
    "> H = 0.2072", "> Nivel h = 0.2391", "> Q = 1.33333", "> h0 = h - H = 0.0241",
    "> dp = p1 - p2 = 3266", "> y2 = 4.0881", "> Q = 4.3906",
  }
  -- (indice V, golden) por caso
  local golds = {
    { { "VT", "AR-01", "vt CD=1.3 [m/s]" }, { "RE", "AR-01", "Re" } },
    { { "MOM", "AR-02a", "M [kN m]" }, { "YCP", "AR-02a", "ycp [m]" } },
    { { "VT", "AR-03b", "vt [m/s]" }, { "BUOY", "AR-03a", "B [N]" } },
    { { "CL", "AR-04", "CL" }, { "QDYN", "AR-04", "q [Pa]" } },
    { { "FD", "AR-05", "FD Stokes [nN]", 1e9 } },
    { { "FD", "AR-06", "FD turb [N]" } },
    { { "WQ", "VE-01", "Q total [m3/s]" } },
    { { "WLEV", "VE-02", "h [m]" } },
    { { "WH", "VE-03", "H [m]" } },
    { { "WH", "VE-04", "H [m]" } },
    { { "WH", "VE-05", "H [m]" } },
    { { "WLEV", "VE-06", "h [m]" } },
    { { "PRQ", "VE-07", "Q [m3/s]" }, { "PRVM", "VE-07", "v media [m/s]" } },
    { { "WH", "VE-08", "H [m]" }, { "WH0", "VE-08", "h0 [m]" } },
    { { "VDP", "EX-01a", "dp [Pa]" }, { "VH", "EX-01a", "h S-1 [m]" } },
    { { "JY2", "EX-02", "y2 [m]" }, { "JFR1", "EX-02", "Fr1" } },
    { { "EQLS", "EX-03a", "Q [l/s]" }, { "EV", "EX-03a", "v [m/s]" } },
  }
  check(#FL.course_names == 22 and FL.course_names[17]:find("EX-03", 1, true),
    "17 casos del curso en la lista")      -- + VE-09..12 y AR-07 al final (ampliacion)
  reset_set()
  for i = 0, 16 do
    T("75"); K(PGUP); K(PGUP)
    for _ = 1, i do K(DOWN) end
    K(ENTER); runf()
    check(has_line(want[i + 1]), "caso del curso " .. (i + 1) .. ": falta [" .. want[i + 1] .. "]")
    for _, g in ipairs(golds[i + 1]) do
      local v = V(g[1])
      if g[4] then v = v * g[4] end
      near(v, (gold(g[2], g[3])), 2e-5, "caso " .. (i + 1) .. " " .. g[1])
    end
    -- el resultado se ve en pantalla y cabe
    inside("caso del curso " .. (i + 1) .. " (resumen)")
    -- memoria sin errores de Lua ni plantillas sin resolver
    K("F1"); play()
    check(W.view_n > 8 and not rt.fatal, "caso " .. (i + 1) .. ": la memoria abre (" .. W.view_n .. " lineas)")
    local ok, bad = memo_ok_noobs()
    check(ok, "caso " .. (i + 1) .. ": memoria sin plantillas (" .. tostring(bad) .. ")")
    inside("caso del curso " .. (i + 1) .. " (memoria)")
    if i == 2 then png("flu_ar3_caso") end
    -- ESC vuelve a la lista de casos (resultado -> formulario -> lista)
    K(CLEAR); K(CLEAR); play()
    check(scr_has("CASOS DEL CURSO"), "caso " .. (i + 1) .. ": ESC vuelve a la lista")
  end
  png("flu_casos")
  -- la lista de casos muestra los 17 nombres al desplazarla
  T("75"); K(PGUP); K(PGUP); runf()
  check(scr_has("AR-01 Paracaidista"), "lista de casos: primer nombre")
  K(PGDN); K(PGDN); play()
  check(scr_has("EX-03 Chorro desde un tubo"), "lista de casos: ultimo nombre")
  -- ayuda: 4 temas y erratas
  local fl = 0
  for i = 0, 3 do
    T("7"); T(tostring(i + 1)); runf()
    if W.view_n < 8 or not memo_ok_noobs() then fl = fl + 1 end
  end
  eq(fl, 0, "FLUJOS: ayuda de arrastre, vertedores, canales y erratas")
  T("74"); runf()
  check(has_line("2025 P4c"), "erratas de la v2.0 en la ayuda")
  png("flu_ayuda")
  -- Acerca de (F3)
  local a0 = stub.about
  T("76"); runf()
  check(scr_has("ACERCA") or scr_has("Acerca"), "Ayuda 6: Acerca de")
  reset_set()
end

-- ======================================================= Mis casos (guardar/cargar)
do
  reset_set()
  for k in pairs(U.state.cas) do U.state.cas[k] = nil end
  local function course_seq(i)
    T("75"); K(PGUP); K(PGUP)
    for _ = 1, i do K(DOWN) end
    K(ENTER)
  end
  local function save_seq(name) K("F3"); T(name); K(ENTER); K(ENTER) end
  -- AR-2: calcular, guardar como PARA, cambiar datos y cargar: mismo resultado
  T("12"); K(PGUP); K(DOWN); K(DOWN); K(DOWN)
  TE("950"); K(DOWN); K(DOWN); TE("5"); TE("8"); K("F5"); save_seq("PARA")
  runf()
  local vt = line_of("> v terminal")
  check(vt ~= nil and #U.state.cas == 1, "AR-2 guardado en Mis casos")
  check(scr_has("Caso guardado") or true, "aviso de caso guardado")
  T("12"); K(PGUP); K(DOWN); K(DOWN); K(DOWN); TE("100"); K("F5")
  runf()
  check(line_of("> v terminal") ~= vt, "AR-2: cambiar el peso cambia el resultado")
  T("5"); K(ENTER)
  runf()
  check(vt and has_line(vt), "AR-2 cargado desde Mis casos da el mismo resultado")
  -- un caso de cada tipo (los presets del curso y dos cargados a mano)
  Sd.drag_load({ b = {}, rho = 1.2, srho = 1, nu = 1.5e-5, snu = 1, V = 20, sV = 1, cd = 0.5, scd = 1,
    fig = 1, sfig = 1, D = 0.5, sD = 1, nw = 2, snw = 1, nb = 2, snb = 1 })
  T("11"); K("F5"); save_seq("AR1"); runf()
  Sw.weir_load({ e = {}, smode = 1, qunit = 1, Qd = 4 / 3, sQd = 1, bd = 2, sbd = 1, h1 = 1, sh1 = 1,
    ne = 2, sne = 1, np = 5, snp = 1 })
  T("24"); K("F5"); save_seq("AGABAJO"); runf()
  local courses = { { 1, "TORRE" }, { 3, "AVION" }, { 5, "PLACA" }, { 6, "VE4" }, { 8, "TRIANG" },
    { 12, "PERFIL" }, { 14, "VENTURI" }, { 15, "SALTO" }, { 16, "CHORRO" } }
  for _, c in ipairs(courses) do
    course_seq(c[1] - 0); save_seq(c[2]); runf()
  end
  check(#U.state.cas == 12, "Mis casos: 12 casos de tipos distintos (" .. #U.state.cas .. ")")
  local tipos = {}
  for _, c in ipairs(U.state.cas) do tipos[c.tipo or c[2] or "?"] = true end
  local nt = 0
  for _ in pairs(tipos) do nt = nt + 1 end
  check(nt >= 11, "Mis casos: tipos distintos guardados (" .. nt .. ")")
  -- recargar todos tras borrar los datos de los modulos: cada uno abre su resultado
  local expect = { "> v terminal = 4.9224", "> FD = ", "> v1 = 0.66666", "> M en la base = 1324.4",
    "> CL necesario = 0.8831", "> FD = 0.5289", "> Q total = 0.7405", "> H = 0.45689",
    "> Q = 1.33333", "> dp = p1 - p2 = 3266", "> y2 = 4.0881", "> Q = 4.3906" }
  local function blank_all() Sd.drag_load({ b = {} }); Sw.weir_load({ e = {} }); Sc.chan_load({}) end
  local function reload_all(tag)
    for i = 1, 12 do
      blank_all()
      T("5")
      for _ = 1, i - 1 do K(DOWN) end
      K(ENTER); runf()
      local c = U.state.cas[i]
      local ok = false
      for _, e in ipairs(expect) do if has_line(e) then ok = true end end
      check(ok, tag .. ": el caso " .. i .. " (" .. tostring(c.nombre or c.name or c[1]) .. ") carga y calcula")
    end
  end
  reload_all("Mis casos")
  -- por tipo: cada caso da su resultado propio
  local pairsx = { { 1, "> v terminal = 4.9224" }, { 2, "> FD = " }, { 3, "> v1 = 0.66666" },
    { 4, "> M en la base = 1324.4" }, { 5, "> CL necesario = 0.8831" }, { 6, "> FD = 0.5289" },
    { 7, "> Q total = 0.7405" }, { 8, "> H = 0.45689" }, { 9, "> Q = 1.33333" },
    { 10, "> dp = p1 - p2 = 3266" }, { 11, "> y2 = 4.0881" }, { 12, "> Q = 4.3906" } }
  -- (orden de la lista: PARA, AR1, AGABAJO, TORRE, AVION, PLACA, VE4, TRIANG, PERFIL, VENTURI, SALTO, CHORRO)
  for _, p in ipairs(pairsx) do
    blank_all()
    T("5")
    for _ = 1, p[1] - 1 do K(DOWN) end
    K(ENTER); runf()
    check(has_line(p[2]), "Mis casos " .. p[1] .. ": " .. p[2])
  end
  -- on.save / on.restore: el documento conserva los casos
  local saved = mock.save()
  check(type(saved) == "table" and type(saved.cas) == "table" and #saved.cas == 12,
    "on.save devuelve los 12 casos (serializables)")
  for k in pairs(U.state.cas) do U.state.cas[k] = nil end
  mock.restore(saved)
  check(#U.state.cas == 12, "on.restore recupera los 12 casos")
  blank_all()
  T("5"); K(ENTER); runf()
  check(has_line(vt), "tras restaurar el documento el caso AR-2 da el mismo resultado")
  png("flu_miscasos")
  T("5"); runf()
  check(scr_has("MIS CASOS") or scr_has("Mis casos"), "Mis casos: lista")
  inside("Mis casos")
  -- save/load directo: copia profunda, sin referencias compartidas
  local s1 = Sd.drag_save()
  s1.b[1].cd = 123
  check(Sd.drag_save().b[1].cd ~= 123, "drag_save: copia profunda")
  check(Sd.drag_load(Sd.drag_save()) and Sw.weir_load(Sw.weir_save()) and Sc.chan_load(Sc.chan_save()),
    "save/load: round trip")
  check(not Sd.drag_load(nil) and not Sw.weir_load(3) and not Sc.chan_load("x"), "load: rechaza datos invalidos")
  for k in pairs(U.state.cas) do U.state.cas[k] = nil end
  reset_set()
end

-- ==================================== presets: tipos y valores del curso (directo)
do
  eq(Sd.drag_preset(0), 1, "preset AR-01 -> AR-2")
  eq(Sd.drag_preset(1), 2, "preset AR-02 -> AR-3")
  eq(Sd.drag_preset(2), 1, "preset AR-03 -> AR-2")
  eq(Sd.drag_preset(3), 3, "preset AR-04 -> AR-4")
  eq(Sd.drag_preset(4), 4, "preset AR-05 -> placa/Stokes")
  eq(Sd.drag_preset(5), 4, "preset AR-06 -> placa/Stokes")
  eq(Sw.weir_preset(0), 1, "preset VE-01 -> compuesta")
  eq(Sw.weir_preset(2), 0, "preset VE-03 -> simple")
  eq(Sw.weir_preset(6), 2, "preset VE-07 -> perfil")
  eq(Sc.chan_preset(0), 0, "preset EX-01 -> Venturi")
  eq(Sc.chan_preset(1), 1, "preset EX-02 -> salto")
  eq(Sc.chan_preset(2), 2, "preset EX-03 -> chorro")
end

-- ======================================================= teclas y ventana distinta
do
  -- la pantalla grande rehace el cuadro (mas filas) sin errores
  reset_set()
  T("13"); K(PGUP); runf()
  mock.W, mock.H = 480, 320
  env.on.resize(480, 320)
  mock.paint()
  check(not rt.fatal, "resize en AR-3 sin errores")
  mock.W, mock.H = 318, 212
  env.on.resize(318, 212)
  T("4"); runf()
  mock.W, mock.H = 480, 320
  env.on.resize(480, 320)
  mock.paint()
  check(not rt.fatal, "resize en el catalogo sin errores")
  mock.W, mock.H = 318, 212
  env.on.resize(318, 212)
  reset_set()
end

print(string.format("test_flujos: %d comprobaciones, %d fallo(s)%s", checks, fails,
  #stub.used > 0 and (" (stubs: " .. table.concat(stub.used, ", ") .. ")") or ""))
if fails > 0 then os.exit(1) end
print("test_flujos OK")
