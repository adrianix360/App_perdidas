-- test_dyn.lua - Motor core/dyn.lua (valores de dinamica de tools/oracle_examenes.py,
-- tolerancia relativa 1e-3) y pantallas scr/scr_dyn.lua (menu, ejemplos de examen,
-- memoria de calculo, edicion de expresiones, Mis casos).
-- Uso: desde la raiz, tras tools/build.py --no-tns (lo hace tools/run_tests.sh).
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
local TOL = 1e-3

local Dy = env.require("core.dyn")
local U = env.require("ui.ui")
local W = env.require("ui.widgets")
local rt = env.require("ui.rt")
local F = env.require("scr.flu_util")
local Sd = env.require("scr.scr_dyn")
local dc = env.require("data.dragcat")
local PI = math.pi

-- ===================================================================== MOTOR
-- ---- evaluador de expresiones
do
  local function ev(s, vars, ...)
    local e, f, m = Dy.dyn_compile(s, vars)
    if e ~= 0 then return nil, m end
    return f(...)
  end
  near(ev("2*y^2", { "y" }, 3), 18, 1e-12, "expr 2*y^2")
  near(ev("2y^2", { "y" }, 3), 18, 1e-12, "expr multiplicacion implicita 2y^2")
  near(ev("-2^2", {}), -4, 1e-12, "expr -2^2 = -4")
  near(ev("2^3^2", {}), 512, 1e-12, "expr potencia asociativa a la derecha")
  near(ev("0.1*(1+sin(t/(8*pi)))", { "t", "y" }, 90, 0), 0.0574609, 1e-5, "expr Qs(t) del examen")
  near(ev("8pi", {}), 8 * PI, 1e-12, "expr 8pi")
  near(ev("1.5E-3*t", { "t" }, 2), 0.003, 1e-12, "expr notacion cientifica")
  near(ev("sqrt(2*9.81*y)+abs(-1)+ln(1)+exp(0)", { "y" }, 1), math.sqrt(19.62) + 2, 1e-12, "expr funciones")
  local bad = { "", "2+", "(1+2", "foo(1)", "z", "1 2 $", "sin 3", "2**3" }
  for _, s in ipairs(bad) do
    local e = Dy.dyn_compile(s, { "y" })
    check(e ~= 0, "expr invalida: '" .. s .. "'")
  end
  eq(Dy.dyn_err_text(2), "Expresion mal escrita", "texto de error")
  near(Dy.dyn_simpson(function(x) return x * x end, 0, 3, 10), 9, 1e-12, "Simpson x^2")
end

-- ---- D1 perfiles
do
  local r = {}
  eq(Dy.dyn_profile_channel({ b = 8, h = 1, u = Dy.dyn_power_channel(1, 0.5, 1), nu = 1.007e-6, Lc = 1 }, r), 0, "D1 EPSON P5a err")
  near(r.Q, 16 / 3, TOL, "EPSON P5a Q = 5.333 (Simpson)")
  near(r.V, 2 / 3, TOL, "EPSON P5a V = 2/3")
  near(r.Re, 662032, TOL, "EPSON P5a Re = 662 032")
  r = {}
  Dy.dyn_profile_channel({ b = 2, h = 1, u = Dy.dyn_power_channel(2, 2, 1), nu = 1e-6, Lc = 1 }, r)
  near(r.Q, 1.33333, TOL, "P2-2024 P4a Q = 1.3333")
  r = {}
  eq(Dy.dyn_profile_pipe({ r0 = 0.2, u = Dy.dyn_power_pipe(2, 2, 1, 0.2), nu = 1e-6, Lc = 0.4 }, r), 0, "D1 parabolico err")
  near(r.Q, 0.12566, TOL, "parabolico Q = 0.12566")
  near(r.V, 1, TOL, "parabolico V = 1")
  near(r.alfa, 2, TOL, "parabolico alfa = 2")
  near(r.beta, 4 / 3, TOL, "parabolico beta = 4/3")
  -- expresion libre = ley de potencia
  local _, f = Dy.dyn_compile("2*(1-r^2/0.04)", { "r" })
  r = {}
  Dy.dyn_profile_pipe({ r0 = 0.2, u = f, nu = 1e-6, Lc = 0.4 }, r)
  near(r.alfa, 2, TOL, "parabolico por expresion: alfa")
  eq(Dy.dyn_profile_pipe({ r0 = -1, u = f }, {}), 1, "D1 dato invalido")
  eq(Dy.dyn_profile_channel({ b = 1, h = 1, u = function() return 0 / 0 end }, {}), 3, "D1 u no finita")
  -- formulas cerradas (exactas, 1e-9)
  r = {}
  Dy.dyn_profile_channel({ b = 8, h = 1, u = Dy.dyn_power_channel(1, 0.5, 1), nu = 1.007e-6, Lc = 1,
    power = { umax = 1, n = 0.5 } }, r)
  check(r.exact, "canal: formulas cerradas")
  near(r.Q, 16 / 3, 1e-9, "canal exacto Q = umax b h/(n+1)")
  near(r.V, 2 / 3, 1e-9, "canal exacto V = umax/(n+1)")
  near(r.alfa, 1.5 ^ 3 / 2.5, 1e-9, "canal exacto alfa = (n+1)^3/(3n+1)")
  near(r.beta, 1.5 ^ 2 / 2, 1e-9, "canal exacto beta = (n+1)^2/(2n+1)")
  near(r.Re, (2 / 3) / 1.007e-6, 1e-9, "canal exacto Re")
  r = {}
  Dy.dyn_profile_pipe({ r0 = 0.2, u = Dy.dyn_power_pipe(2, 2, 1, 0.2), Lc = 0.4, nu = 1e-6,
    power = { umax = 2, m = 2, k = 1 } }, r)
  near(r.V, 1, 1e-9, "tuberia exacta V = umax/2")
  near(r.alfa, 2, 1e-9, "tuberia exacta alfa = 2")
  near(r.beta, 4 / 3, 1e-9, "tuberia exacta beta = 4/3")
  near(r.Q, PI * 0.04, 1e-9, "tuberia exacta Q")
  r = {}
  Dy.dyn_profile_pipe({ r0 = 0.2, u = Dy.dyn_power_pipe(2, 4, 1, 0.2), power = { umax = 2, m = 4, k = 1 } }, r)
  near(r.V, 2 * 4 / 6, 1e-9, "tuberia exacta V = umax m/(m+2)")
  local r2 = {}
  Dy.dyn_profile_pipe({ r0 = 0.2, u = Dy.dyn_power_pipe(2, 4, 1, 0.2), n = 2000 }, r2)
  near(r.alfa, r2.alfa, 1e-6, "tuberia: cerrada = Simpson")
end

-- ---- D2 continuidad y Bernoulli
do
  local r = {}
  eq(Dy.dyn_continuity({ vol = 12e-3, time = 50, rho = 1000, D = { 0.012, 0.005 } }, r), 0, "Ej1 err")
  near(r.Q, 2.4e-4, TOL, "Ej1 Q = 2.4e-4")
  near(r.mdot, 0.24, TOL, "Ej1 mdot = 0.24 kg/s")
  near(r.V[1], 2.12207, TOL, "Ej1 V (12 mm)")
  near(r.V[2], 12.2231, TOL, "Ej1 V (5 mm)")
  r = {}
  eq(Dy.dyn_bernoulli({ g = 9.81, rho = 1.2, D1 = 0.22, D2 = 0.10, Q = 0.12, z1 = 0, z2 = 0,
    rhom = 1000 }, r), 0, "P2-2025 P1 err")
  near(r.V1, 3.15679, TOL, "P2-2025 P1 V1")
  near(r.V2, 15.2789, TOL, "P2-2025 P1 V2")
  near(r.dp, 134.087, TOL, "P2-2025 P1 dP = 134.09 Pa")
  near(r.hmano * 1000, 13.6848, TOL, "P2-2025 P1 h = 13.68 mm")
  r = {}
  eq(Dy.dyn_discharge({ g = 9.81, rho = 1000, z0 = 6, zs = 2.4, d = 0.05, D = 0.15,
    pts = { { z = 0 }, { z = 6 }, { z = 7.5 }, { z = 2.4 } } }, r), 0, "P2-2024 P2 err")
  near(r.Q * 1000, 16.5018, TOL, "P2-2024 P2 Q = 16.50 l/s")
  near(r.pts[1].p, 58424, TOL, "P2-2024 P2 pA = 58 424")
  near(r.pts[2].p, -436, 2e-3, "P2-2024 P2 pB = -436")
  near(r.pts[3].p, -15151, TOL, "P2-2024 P2 pC = -15 151")
  near(r.pts[4].p, 34880, TOL, "P2-2024 P2 pD = 34 880")
  eq(Dy.dyn_discharge({ g = 9.81, rho = 1000, z0 = 2, zs = 3, d = 0.05, D = 0.15 }, {}), 4, "descarga sin carga")
end

-- ---- D3 cantidad de movimiento
do
  local r = {}
  eq(Dy.dyn_elbow({ g = 9.81, rho = 1000, D1 = 0.2, D2 = 0.15, theta = 45, V1 = 2.5, p1 = 10000,
    dz = 2 }, r), 0, "P2-2024 P3 err")
  near(r.Q * 1000, 78.5398, TOL, "P2-2024 P3 Q = 78.54 l/s")
  near(r.V2, 4.44444, TOL, "P2-2024 P3 V2")
  near(r.p2, -16371.5, TOL, "P2-2024 P3 p2 = -16 372")
  near(r.Rx, 468.254, TOL, "P2-2024 P3 Rx = 468.3")
  near(r.Ry, -42.2544, TOL, "P2-2024 P3 Ry = -42.25 (fluido sobre codo)")
  near(r.R, 470.157, TOL, "P2-2024 P3 R = 470.2")
  near(r.Ax, -468.254, TOL, "anclaje Ax = -Rx")
  r = {}
  Dy.dyn_elbow({ g = 9.81, rho = 1000, D1 = 0.2, D2 = 0.15, theta = 45, V1 = 2.5, p1 = 10000, p2 = -16371.5 }, r)
  near(r.Rx, 468.254, TOL, "codo con p2 dado")
  r = {}
  eq(Dy.dyn_jets({ g = 9.81, rho = 1040, N = 2, d = 0.05, alpha = 10, D = 0.1, mass = 130, H = 6.5,
    eta = 0.8 }, r), 0, "P2-2025 P5 err")
  near(r.V2, 11.8206, TOL, "P2-2025 P5 V2 = 11.82")
  near(r.V1, 5.9103, TOL, "P2-2025 P5 V1")
  near(r.Q, 0.0464194, TOL, "P2-2025 P5 Q = 0.04642")
  near(r.p0 / 1000, 120.809, TOL, "P2-2025 P5 P0 = 120.8 kPa")
  near(r.HB, 13.6216, TOL, "P2-2025 P5 HB = 13.62")
  near(r.Pot / 1000, 6.45106, TOL, "P2-2025 P5 P = 6.45 kW")
  near(r.Pshaft / 1000, 6.45106 / 0.8, TOL, "P2-2025 P5 potencia al eje")
end

-- ---- D4 tanques
do
  local PIx = PI
  local _, qs = Dy.dyn_compile("0.1*(1+sin(t/(8*pi)))", { "t", "y" })
  local r = {}
  eq(Dy.dyn_tank({ A = 4, y0 = 5, qe = 0.1, qs = qs, tf = 90, at = PIx * 0.15 ^ 2 / 4 }, r), 0, "P2-2024 P1 err")
  near(r.y_end, 3.80305, TOL, "P2-2024 P1 y(90) = 3.803")
  near(r.Qs_end, 0.0574609, TOL, "P2-2024 P1 Qs(90)")
  near(r.v_end, 3.25162, TOL, "P2-2024 P1 v = 3.252")
  local _, qs2 = Dy.dyn_compile("0.4*cos(t/18000)", { "t", "y" })
  r = {}
  eq(Dy.dyn_tank({ A = PIx * 144 / 4, y0 = 6.5, qe = 0.1, qs = qs2, ytarget = 0 }, r), 0, "P2-2025 P2 err")
  near(r.t_end, 2460.65, TOL, "P2-2025 P2 t = 2460.6 s")
  eq(r.status, "target", "P2-2025 P2 estado")
  r = {}
  Dy.dyn_tank({ A = PIx * 1.5 ^ 2 / 4, y0 = 2, Cd = 1, a = PIx * 0.15 ^ 2 / 4, ytarget = 1 }, r)
  near(r.t_end, 18.7027, TOL, "Varios Ej2 t = 18.70 s")
  near(r.Qs0 * 1000, 110.697, TOL, "Varios Ej2 Q0 = 110.7 l/s")
  near(r.Qs_end * 1000, 78.2748, TOL, "Varios Ej2 Q1 = 78.27 l/s")
  r = {}
  Dy.dyn_tank({ A = 20, y0 = 3, Cd = 1, a = PIx * 0.15 ^ 2 / 4, ytarget = 0 }, r)
  near(r.t_end, 885.113, TOL, "tanque 3 m t = 885.1 s")
  near(r.v0, 7.67203, TOL, "tanque 3 m V2(0)")
  near(r.dvdt0, -0.00866785, TOL, "tanque 3 m dV2/dt = -a g/A")
  r = {}
  eq(Dy.dyn_tank({ A = 36, y0 = 5, qe = 0.1, Cd = 1, a = PIx * 0.15 ^ 2 / 4, ytarget = 0.5 }, r), 0, "tanque 5 m err")
  eq(r.status, "equilibrium", "tanque 5 m: tiende al equilibrio")
  check(not r.reached, "tanque 5 m: no se alcanza el nivel")
  near(r.y_end, 1.63214, TOL, "tanque 5 m equilibrio 1.632 m")
  near(r.y_eq, 1.63214, TOL, "tanque 5 m y_eq analitico")
  eq(Dy.dyn_tank({ A = 0, y0 = 1, qs = qs, tf = 10 }, {}), 1, "tanque dato invalido")
  eq(Dy.dyn_tank({ A = 1, y0 = 1, qs = function() return 0 / 0 end, tf = 10 }, {}), 3, "tanque Qs no finito")
  -- nivel que sube: llena hasta un nivel
  r = {}
  Dy.dyn_tank({ A = 10, y0 = 0, qe = 1, qs = function() return 0 end, ytarget = 2 }, r)
  near(r.t_end, 20, TOL, "llenado: t = A dy / Qe")
end

-- =================================================================== PANTALLAS
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
local MODE = "menu"
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
local function run_fn(fn) start(fn); play() end
local function scr_has(s) mock.paint(); return (mock.has_text(s)) end
local function has_line(s)
  for i = 1, W.view_n do
    if W.view_line[i]:find(s, 1, true) then return true end
  end
  return false
end
local function memo_ok(label)
  local bad
  for i = 1, W.view_n do
    local l = W.view_line[i]
    if l:find("?", 1, true) or l:find("{", 1, true) or l:find("ERR", 1, true) or #l > 40 then bad = l end
  end
  check(not bad, label .. ": memoria sin '?', '{', ERR ni lineas > 40 (" .. tostring(bad) .. ")")
  check(W.view_n < W.VIEW_MAX, label .. ": memoria cabe en el visor (" .. W.view_n .. " lineas)")
end
local function inside(label)
  mock.paint()
  for _, t in ipairs(mock.screen_text()) do
    local ok = t.x >= 0 and t.x + t.w <= mock.W + 2 and t.y >= 0 and t.y + t.h <= mock.H + 2
    if not ok then
      check(false, label .. ": texto fuera de pantalla '" .. t.text .. "' x=" .. t.x .. " w=" .. t.w)
    end
  end
end
local function dump()
  mock.paint()
  for _, t in ipairs(mock.screen_text()) do io.write("[", t.text, "] ") end
  print()
  for i = 1, W.view_n do print(W.view_line[i]) end
end
_G.__dump = dump
if os.getenv("DUMPMEMO") then _G.__dump_all = true end

local function reset_set()
  local g = U.g_set
  for k in pairs(g) do g[k] = nil end
  g.dec = 6
  dc.cd_user = {}
  F.gset()
  g.cd_user = dc.cd_user
end
reset_set()

-- ---- menus
do
  run_fn(function() Sd.scr_dyn_menu() end)
  check(scr_has("DINAMICA DE FLUIDOS"), "menu: titulo")
  for _, s in ipairs({ "D1 Perfiles de velocidad", "D2 Continuidad y Bernoulli",
    "D3 Cantidad de movimiento", "D4 Tanques no permanentes", "Ejemplos de examen" }) do
    check(scr_has(s), "menu: " .. s)
  end
  inside("menu dinamica")
  T("1"); play()
  check(scr_has("D1 PERFILES DE VELOCIDAD") and scr_has("Canal rectangular") and scr_has("Tuberia circular"),
    "submenu D1")
  K(CLEAR); T("2"); play()
  check(scr_has("Continuidad (Q, V") and scr_has("Descarga libre") and scr_has("manometro"), "submenu D2")
  K(CLEAR); T("3"); play()
  check(scr_has("Codo o reduccion") and scr_has("Chorros que sostienen"), "submenu D3")
  K(CLEAR); T("4"); play()
  check(scr_has("D4 TANQUE NO PERMANENTE") and scr_has("Qs(t,y)"), "D4 desde el menu")
  K(CLEAR); T("5"); play()
  check(scr_has("EJEMPLOS DE EXAMEN") and scr_has("EPSON P5a") and scr_has("Tanque 3 m"), "lista de ejemplos")
  inside("ejemplos")
  K(CLEAR); K(CLEAR); play()
  check(R.done, "ESC sale del menu")
  eq(#Sd.examples, 13, "13 ejemplos de examen")
end

-- ---- ejemplos de examen: resumen, memoria y resultado
local function example(i, kind, checks_fn)
  reset_set()
  run_fn(function() Sd.example_run(i) end)
  eq(Sd.examples[i].kind, kind, "ejemplo " .. i .. " kind")
  local res = Sd.res[kind]
  check(res ~= nil, "ejemplo " .. i .. ": hay resultado")
  if not res then return end
  inside("resumen ejemplo " .. i)
  checks_fn(res.o, res.inp, false)
  if os.getenv("DUMPMEMO") then print("== resumen " .. i); dump() end
  K("F1"); play()
  checks_fn(res.o, res.inp, true)
  memo_ok("ejemplo " .. i)
  if os.getenv("DUMPMEMO") then print("== memoria " .. i); dump() end
  inside("memoria ejemplo " .. i)
  K(CLEAR); K(CLEAR); K(CLEAR); play()
end

example(1, "D1c", function(o, _, memo)
  near(o.Q, 16 / 3, TOL, "UI EPSON P5a Q"); near(o.Re, 662032, TOL, "UI EPSON P5a Re")
  if memo then check(has_line("Q = umax b h / (n + 1)") and has_line("> Q = 5.333333"), "memoria EPSON P5a")
  else check(has_line("Caudal Q") and has_line("5.333333"), "resumen EPSON P5a") end
end)
example(2, "D1c", function(o, _, memo)
  near(o.Q, 4 / 3, TOL, "UI P2-2024 P4a Q")
  if memo then check(has_line("V = umax / (n + 1)"), "memoria P2-2024 P4a: V = umax/(n+1)") end
end)
example(3, "D1t", function(o, _, memo)
  near(o.Q, 0.125664, TOL, "UI parabolico Q"); near(o.alfa, 2, TOL, "UI parabolico alfa")
  near(o.beta, 4 / 3, TOL, "UI parabolico beta")
  if memo then check(has_line("> alfa = 2") and has_line("Parabolico: V=umax/2"), "memoria parabolico") end
end)
example(4, "D2a", function(o, _, memo)
  near(o.V[1], 2.12207, TOL, "UI Ej1 V12"); near(o.V[2], 12.2231, TOL, "UI Ej1 V5")
  if memo then check(has_line("> V2 = 12.223") and has_line("> m punto = 0.24 kg/s"), "memoria Ej1")
  else check(has_line("Flujo masico"), "resumen Ej1") end
end)
example(5, "D2c", function(o, _, memo)
  near(o.dp, 134.087, TOL, "UI P2-2025 P1 dP"); near(o.hmano * 1000, 13.6848, TOL, "UI P2-2025 P1 h")
  if memo then check(has_line("> h = 13.68") and has_line("MANOMETRO DIFERENCIAL"), "memoria P2-2025 P1")
  else check(has_line("h manometro") and has_line("13.68"), "resumen P2-2025 P1") end
end)
example(6, "D2b", function(o, _, memo)
  near(o.Q * 1000, 16.5018, TOL, "UI P2-2024 P2 Q"); near(o.pts[1].p, 58424, TOL, "UI pA")
  near(o.pts[3].p, -15151, TOL, "UI pC")
  if memo then check(has_line("Punto C: z = 7.5 m, D = 150 mm") and has_line("Vs = sqrt(2 g (z0 - zs))"),
    "memoria P2-2024 P2")
  else check(has_line("A: p = 58424 Pa"), "resumen P2-2024 P2") end
end)
example(7, "D3a", function(o, _, memo)
  near(o.p2, -16371.5, TOL, "UI P2-2024 P3 p2"); near(o.Rx, 468.254, TOL, "UI Rx"); near(o.R, 470.157, TOL, "UI R")
  if memo then check(has_line("CONVENCION DE SIGNOS") and has_line("> Rx (fluido-codo) = 468.25") and
    has_line("> Ay anclaje = 42.25"), "memoria P2-2024 P3 con convencion de signos")
  else check(has_line("Anclajes: Ax = -Rx, Ay = -Ry"), "resumen codo") end
end)
example(8, "D3b", function(o, _, memo)
  near(o.V2, 11.8206, TOL, "UI flyboard V2"); near(o.HB, 13.6216, TOL, "UI flyboard HB")
  near(o.Pot / 1000, 6.45106, TOL, "UI flyboard P")
  if memo then check(has_line("> HB = 13.62") and has_line("> Potencia = 6.451"), "memoria flyboard")
  else check(has_line("V chorros") and has_line("11.82"), "resumen flyboard") end
end)
example(9, "D4", function(o, _, memo)
  near(o.y_end, 3.80305, TOL, "UI P2-2024 P1 y(90)"); near(o.v_end, 3.25162, TOL, "UI P2-2024 P1 v")
  if memo then check(has_line("Runge-Kutta 4 con paso automatico") and has_line("> y(t) = 3.803") and
    has_line("t [s]"), "memoria P2-2024 P1 con tabla de integracion")
  else check(has_line("Nivel y(t)") and has_line("V en el tubo"), "resumen P2-2024 P1") end
end)
example(10, "D4", function(o, _, memo)
  near(o.t_end, 2460.65, TOL, "UI P2-2025 P2 t")
  if memo then check(has_line("> t = 2460.6"), "memoria P2-2025 P2") end
end)
example(11, "D4", function(o, _, memo)
  near(o.t_end, 18.7027, TOL, "UI Ej2 t"); near(o.Qs0 * 1000, 110.697, TOL, "UI Ej2 Q0")
  near(o.Qs_end * 1000, 78.2748, TOL, "UI Ej2 Q1")
  if memo then check(has_line("Qs = Cd a sqrt(2 g (y - zs))") and has_line("> t = 18.70"), "memoria Ej2") end
end)
example(12, "D4", function(o, _, memo)
  near(o.t_end, 885.113, TOL, "UI tanque 3 m t")
  if memo then check(has_line("dV/dt(0)") and has_line("> t = 885"), "memoria tanque 3 m") end
end)
example(13, "D4", function(o, _, memo)
  eq(o.status, "equilibrium", "UI tanque 5 m: equilibrio"); near(o.y_end, 1.63214, TOL, "UI tanque 5 m y_eq")
  if memo then
    check(has_line("NO se alcanza") and has_line("1.632"), "memoria tanque 5 m: aviso de equilibrio")
  else
    check(has_line("El nivel 0.5 m NO se alcanza.") and has_line("equilibrio y = 1.632"),
      "resumen tanque 5 m: aviso con el nivel de equilibrio")
  end
end)

-- ---- formato numerico de Ajustes (decimales)
do
  reset_set()
  U.g_set.dec = 2
  run_fn(function() Sd.example_run(4) end)
  K("F1"); play()
  check(has_line("> m punto = 0.24 kg/s") and has_line("> V2 = 12.22 m/s"), "memoria con 2 decimales de Ajustes")
  K(CLEAR); K(CLEAR); K(CLEAR); play()
  reset_set()
end

-- ---- edicion de expresiones en D4 (formulario, F1 EDITAR)
do
  reset_set()
  Sd.case_set("D4", { A = 4, sA = 1, y0 = 5, sy0 = 1, zs = 0, szs = 1, tf = 90, stf = 1, tk = 0, so = 0, ob = 0,
    qs = "0.1", qe = "0.1" })
  run_fn(function() Sd.scr_dyn("D4") end)
  check(scr_has("D4 TANQUE NO PERMANENTE") and scr_has("EDITAR"), "D4: formulario con F1 EDITAR")
  -- Qs(t,y) es el 7.o campo (indice 6): bajar 6 veces
  for _ = 1, 6 do K(DOWN) end
  K("F1"); play()
  check(scr_has("EDITAR EXPRESION") and scr_has("Variables: t, y"), "editor de expresion")
  for _ = 1, 3 do K(DEL) end
  T("0.1*(1+sin(t/(8*pi)))"); K("enter"); play()
  check(scr_has("0.1*(1+sin(t/(8*.."), "formulario muestra la expresion abreviada")
  eq(Sd.case_get("D4").qs, "0.1*(1+sin(t/(8*pi)))", "la expresion queda guardada como texto")
  K("F1"); T("+"); K("enter"); play()
  check(scr_has("Expresion incompleta") or scr_has("Sintaxis") or scr_has("Falta"), "editor rechaza expresion invalida")
  K(CLEAR); play()
  eq(Sd.case_get("D4").qs, "0.1*(1+sin(t/(8*pi)))", "ESC en el editor conserva la expresion")
  K("F5"); play()
  check(has_line("Nivel y(t)") and has_line("3.803"), "D4 calcula con la expresion escrita en pantalla")
  K(CLEAR); K(CLEAR); play()
end

-- ---- errores del formulario
do
  reset_set()
  Sd.case_set("D4", { A = 4, sA = 1, y0 = 5, sy0 = 1, tk = 0, so = 0, ob = 0, qs = "0.1", qe = "0" })
  run_fn(function() Sd.scr_dyn("D4") end)
  K("F5"); play()
  check(scr_has("Falta este dato") or scr_has("Falta el tiempo"), "D4 sin tiempo: mensaje")
  Sd.case_set("D4", { A = 4, sA = 1, y0 = 5, sy0 = 1, tf = 10, stf = 1, tk = 0, so = 0, ob = 0, qs = "0.1*q", qe = "0" })
  run_fn(function() Sd.scr_dyn("D4") end)
  K("F5"); play()
  check(scr_has("Variable desconocida: q"), "D4 con variable desconocida: mensaje")
  Sd.case_set("D2c", { D1 = 100, sD1 = 1, D2 = 50, sD2 = 1, Q = 10, sQ = 1, md = 0, fl = 0, S = 0.5, sS = 1 })
  run_fn(function() Sd.scr_dyn("D2c") end)
  K("F5"); play()
  check(scr_has("El manometro debe ser mas denso"), "D2c con manometro menos denso que el fluido")
  Sd.case_set("D2b", { z0 = 1, sz0 = 1, zs = 3, szs = 1, d = 50, sd = 1, D = 100, sD = 1, fl = 0 })
  run_fn(function() Sd.scr_dyn("D2b") end)
  K("F5"); play()
  check(scr_has("z0 debe estar sobre zs"), "D2b sin carga")
  Sd.case_set("D1c", { b = 1, sb = 1, h = 1, sh = 1, nu = 1e-6, snu = 1, pf = 1, lc = 0, ex = "-y" })
  run_fn(function() Sd.scr_dyn("D1c") end)
  K("F5"); play()
  check(scr_has("Q <= 0"), "D1 con perfil negativo")
  K(CLEAR); play()
end

-- ---- Mis casos: case_get / case_set / case_run / GUARDAR
do
  reset_set()
  for _, kind in ipairs(Sd.kinds) do
    local d = Sd.case_get(kind)
    check(type(d) == "table", "case_get " .. kind)
    local ok = true
    for k, v in pairs(d) do
      if type(v) ~= "number" and type(v) ~= "string" then ok = false end
    end
    check(ok, "case_get " .. kind .. ": solo numeros y cadenas")
    check(Sd.case_set(kind, d), "case_set " .. kind)
    local d2 = Sd.case_get(kind)
    local same = true
    for k, v in pairs(d) do if d2[k] ~= v then same = false end end
    check(same, "case_get/case_set " .. kind .. ": ida y vuelta")
  end
  check(Sd.case_get("XX") == nil and not Sd.case_set("XX", {}) and not Sd.case_set("D4", 3), "kinds y datos invalidos")
  Sd.example_load(9)
  local d = Sd.case_get("D4")
  eq(d.qs, "0.1*(1+sin(t/(8*pi)))", "caso D4: expresion como texto")
  Sd.example_load(1)
  Sd.case_set("D4", d)
  run_fn(function() Sd.case_run("D4") end)
  check(has_line("Nivel y(t)") and has_line("3.803"), "case_run D4 calcula con los datos cargados")
  -- GUARDAR sin tipo registrado: aviso
  K("F3"); play()
  check(scr_has("tipos de caso"), "GUARDAR sin KT registrado: aviso")
  K(ENTER); K(CLEAR); K(CLEAR); play()
  -- GUARDAR con KT registrado: pide el nombre
  Sd.kt["D4"] = 17
  run_fn(function() Sd.case_run("D4") end)
  K("F3"); play()
  check(scr_has("GUARDAR CASO") or scr_has("Guardar") or scr_has("Este tipo"), "GUARDAR con KT llama a Mis casos")
  Sd.kt["D4"] = nil
  K(CLEAR); K(CLEAR); K(CLEAR); play()
end

-- ---- ventana grande
do
  reset_set()
  run_fn(function() Sd.example_run(9) end)
  K("F1"); play()
  mock.W, mock.H = 480, 320
  env.on.resize(480, 320)
  mock.paint()
  check(not rt.fatal, "resize en la memoria D4 sin errores")
  mock.W, mock.H = 318, 212
  env.on.resize(318, 212)
  reset_set()
end

print(string.format("test_dyn: %d comprobaciones, %d fallo(s)", checks, fails))
if fails > 0 then os.exit(1) end
print("test_dyn OK")
