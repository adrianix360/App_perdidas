-- test_statics.lua - ESTATICA DE FLUIDOS (E1..E6): motor core/statics.lua contra el
-- oraculo (tools/oracle_examenes.py, tolerancia relativa 1e-3) y pantallas
-- scr/scr_stat.lua con teclas simuladas (menus, ejemplos de examen, memoria de calculo).
-- Uso: desde la raiz, tras tools/build.py --no-tns (lo hace tools/run_tests.sh).
local mock = dofile("tests/mock_nspire.lua")
local env = mock.load_app("build/app.lua")

local fails, checks = 0, 0
local function check(cond, msg)
  checks = checks + 1
  if not cond then
    fails = fails + 1
    print("FALLO: " .. tostring(msg))
  end
end
local function near(a, b, rel, msg)
  local ok = type(a) == "number" and type(b) == "number" and
    math.abs(a - b) <= rel * math.max(math.abs(b), 1e-12) + 1e-12
  check(ok, (msg or "near") .. ": esperado " .. tostring(b) .. ", obtenido " .. tostring(a))
end

local U = env.require("ui.ui")
local W = env.require("ui.widgets")
local rt = env.require("ui.rt")
local nf = env.require("ui.numfmt")
local F = env.require("scr.flu_util")
local St = env.require("core.statics")
local Sx = env.require("scr.scr_stat")
local C = { g = 9.81, gamma = 9810 }
local PI = math.pi
local TOL = 1e-3

-- ============================================================ oraculo
local oracle = {}
do
  local fh = io.popen("python -I tools/oracle_examenes.py")
  check(fh ~= nil, "oraculo: no se pudo ejecutar python")
  if fh then
    for line in fh:lines() do
      local id, rest = line:match("^(.-): (%w[%w_]*=.*)$")
      if id then
        local t = {}
        for k, v in rest:gmatch("([%w_]+)=([^,]+)") do t[k] = tonumber(v) end
        oracle[id] = t
      end
    end
    fh:close()
  end
end
local function O(id, key)
  local t = oracle[id]
  check(t ~= nil and t[key] ~= nil, "oraculo sin " .. id .. "." .. key)
  return t and t[key] or 0
end

-- ============================================================ motor
-- E1 viscosidad
do
  local r = {}
  check(St.st_visc_bearing({ mu = 0.005, D = 0.08, L = 1, e = 1e-4, mode = 0, val = 500 }, C, r) == 0, "cojinete ok")
  near(r.T, O("EPS-P1a", "T"), TOL, "EPSON P1a T")
  r = {}
  St.st_visc_bearing({ mu = 0.005, D = 0.08, L = 2, e = 2e-4, mode = 1, val = 0.2 }, C, r)
  near(r.omega, O("EPS-P1b", "w"), TOL, "EPSON P1b omega")
  near(r.rpm, O("EPS-P1b", "rpm"), TOL, "EPSON P1b rpm")
  r = {}
  St.st_visc_bearing({ mu = 0.2, D = 0.04, L = 0.06, e = 1e-4, mode = 0, val = 1250 }, C, r)
  near(r.T, O("P1-2024-P1", "T"), TOL, "2024 P1 T")
  near(r.P, O("P1-2024-P1", "P"), TOL, "2024 P1 P")
  -- mode 2 (potencia dada) es el inverso de mode 0
  local r2 = {}
  St.st_visc_bearing({ mu = 0.2, D = 0.04, L = 0.06, e = 1e-4, mode = 2, val = r.P }, C, r2)
  near(r2.rpm, 1250, 1e-9, "cojinete: rpm desde potencia")
  check(St.st_visc_bearing({ mu = 0, D = 1, L = 1, e = 1, mode = 0, val = 1 }, C, {}) ~= 0, "cojinete: mu = 0 es error")
  r = {}
  check(St.st_visc_plate({ mu = 0.0027, A = 0.16, V = 1, Vu = 0, Vl = -0.3, t1 = 1e-3, t2 = 2.6e-3 }, C, r) == 0, "placa ok")
  near(r.F, O("P1-2018-P4", "F"), TOL, "2018 P4 F")
  near(r.y0 * 1000, O("P1-2018-P4", "y0_mm"), TOL, "2018 P4 y0")
  check(r.s0 == nil, "2018 P4: la capa superior no tiene cero interior")
  r = {}
  St.st_visc_plate({ mu = 0.001, A = 1, V = 1, Vu = -1, Vl = 1, t1 = 2e-3, t2 = 1e-3 }, C, r)
  near(r.s0, 1e-3, 1e-9, "placa: cero a mitad de la capa superior")
  check(r.y0 == nil, "placa: V = Vl no da cero")
  r = {}
  St.st_visc_block({ W = 150, th = 20, A = 0.25, V = 1.2, t = 5e-4, mu = 0.015, mode = 0 }, C, r)
  near(r.F, O("P1-2022-P1", "F"), TOL, "2022 P1 F")
  r = {}
  St.st_visc_block({ W = 150, th = 20, A = 0.25, V = 0.8, t = 4e-4, mu = 0.012, mode = 0 }, C, r)
  near(r.F, O("P1-2017-P3a", "F"), TOL, "2017 P3a F")
  r = {}
  St.st_visc_block({ W = 150, th = 20, mode = 1, mus = 0.27 }, C, r)
  near(r.F, O("P1-2017-P3b", "F"), TOL, "2017 P3b F")
  check(St.st_visc_block({ W = 150, th = 80, mode = 1, mus = 0.3 }, C, {}) ~= 0, "bloque seco: se atasca")
end

-- E2 manometria
do
  local r = {}
  check(St.st_mano_chain({ pA = 0, n = 3, S = { 13.6, 0.85, 1 }, dz = { 0.45, -0.3, -0.2 }, mode = 0 }, C, r) == 0, "mano ok")
  near(r.pB, O("P1-2018-P3", "Pa"), TOL, "2018 P3 Pa")
  near(r.pp[1], 9810 * 13.6 * 0.45, 1e-9, "mano: presion tras el primer tramo")
  r = {}
  St.st_mano_chain({ pA = 0, n = 3, S = { 1.4, 13.6, 0.6 }, dz = { 0, 0.02, -0.06 }, mode = 1, pB = 2700, k = 1 }, C, r)
  near(r.dzk * 1000, O("P1-2017-P1", "d_mm"), TOL, "2017 P1 d")
  check(St.st_mano_chain({ pA = 0, n = 9, S = {}, dz = {}, mode = 0 }, C, {}) ~= 0, "mano: mas de 8 tramos")
end

-- E3 superficies planas
do
  local r = {}
  check(St.st_plane({ S = 2.5, plates = { { shape = 0, th = 90, hs = 0, b = 6, L = 1.5 } } }, C, r) == 0, "plana ok")
  near(r.F, O("EPS-P2-1", "F"), TOL, "EPSON P2-1")
  r = {}
  St.st_plane({ S = 2.5, plates = { { shape = 0, th = math.atan2(2.5, 1) * 180 / PI, hs = 1.5, b = 6,
    L = math.sqrt(7.25) } } }, C, r)
  near(r.F, O("EPS-P2-2", "F"), TOL, "EPSON P2-2")
  r = {}
  St.st_plane({ S = 2.5, plates = { { shape = 0, th = 90, hs = 0, b = 1, L = 4 },
    { shape = 1, th = 90, hs = 1.5, b = 1, L = 2.5 } } }, C, r)
  near(r.F, O("EPS-P2-3", "F"), TOL, "EPSON P2-3")
  check(r.same and r.yp ~= nil and r.hp > 0, "compuesta: yp resultante con theta igual")
  r = {}
  St.st_plane({ S = 1.1, plates = { { shape = 3, th = 60, hs = 3 - 1.2 * math.sin(PI / 3), b = 0, L = 2.4 } } }, C, r)
  near(r.F, O("P1-2022-P2", "F"), TOL, "2022 P2 F")
  near(r.pl[1].yp, O("P1-2022-P2", "yp"), TOL, "2022 P2 yp")
  r = {}
  St.st_plane({ S = 1, hinge = 1, plates = { { shape = 0, th = 45, hs = 0.25, b = 1, L = 1 } } },
    { g = 1, gamma = 1 }, r)
  near(r.F, O("P1-2017-P2plana", "F_gl2w"), TOL, "2017 P2 F")
  near(r.hinge.Rs, O("P1-2017-P2plana", "RA"), TOL, "2017 P2 reaccion RA")
  near(r.pl[1].dcp, O("P1-2017-P2plana", "dist_B"), TOL, "2017 P2 distancia del CP")
  near(r.hinge.Rs + r.hinge.Rh, r.F, 1e-12, "bisagra: R apoyo + R bisagra = F")
  -- triangulos: trapecio con b2 = 0 es el triangulo de base arriba
  local A1, s1, I1 = St.st_shape(4, 2, 3, 0)
  local A2, s2, I2 = St.st_shape(2, 2, 3, 0)
  near(A1, A2, 1e-12, "trapecio b2=0: A"); near(s1, s2, 1e-12, "trapecio b2=0: sc"); near(I1, I2, 1e-12, "trapecio b2=0: Ic")
  -- presion en la superficie = columna equivalente
  local ra, rb = {}, {}
  St.st_plane({ S = 1, p0 = 9810, plates = { { shape = 0, th = 90, hs = 0, b = 1, L = 1 } } }, C, ra)
  St.st_plane({ S = 1, plates = { { shape = 0, th = 90, hs = 1, b = 1, L = 1 } } }, C, rb)
  near(ra.F, rb.F, 1e-12, "p0 equivale a una columna de liquido")
  r = {}
  check(St.st_gateL({ a = 1.2, w = 3, e = 0.003, Sl = 7.9, S = 1 }, C, r) == 0, "compuerta en L ok")
  near(r.H, O("P1-2018-P2", "H"), TOL, "2018 P2 H")
  near(r.Mw, r.Ml, 1e-6, "compuerta en L: momentos iguales")
  check(r.lg.total > 10 and r.lg.n == 12, "compuerta en L: tabla de biseccion compacta")
end

-- E4 superficies curvas
do
  local r = {}
  check(St.st_curved({ type = 1, R = 5, h = 5, w = 2, side = 0, S = 1, hinge = 1, dir = 0 }, C, r) == 0, "curva ok")
  near(r.FH, O("EPS-P3b", "FH"), TOL, "EPSON P3b FH")
  near(r.FV, O("EPS-P3b", "FV"), TOL, "EPSON P3b FV")
  near(r.P, O("EPS-P3b", "F"), TOL, "EPSON P3b fuerza para mantenerla cerrada")
  r = {}
  St.st_curved({ type = 0, R = 1.2, h = 2.8, w = 1, side = 0, S = 1 }, C, r)
  near(r.FH, O("P1-2022-P3-1", "FH"), TOL, "2022 P3-1 FH")
  near(r.FV, O("P1-2022-P3-1", "FV"), TOL, "2022 P3-1 FV")
  near(r.FR, O("P1-2022-P3-1", "F"), TOL, "2022 P3-1 F")
  near(r.ang, O("P1-2022-P3-1", "ang"), TOL, "2022 P3-1 angulo")
  local rc = {}
  St.st_curved({ type = 1, R = 1.2, h = 2.8, w = 1, side = 0, S = 1 }, C, rc)
  near(rc.FV, O("P1-2022-P3-2", "FV"), TOL, "2022 P3-2 FV")
  near(rc.FR, O("P1-2022-P3-2", "F"), TOL, "2022 P3-2 F")
  near(rc.ang, O("P1-2022-P3-2", "ang"), TOL, "2022 P3-2 angulo")
  -- liquido del otro lado: mismas magnitudes, FV al reves
  local rd = {}
  St.st_curved({ type = 0, R = 1.2, h = 2.8, w = 1, side = 1, S = 1 }, C, rd)
  near(rd.FR, r.FR, 1e-12, "domo con liquido debajo: misma resultante")
  near(rd.Fz, -r.Fz, 1e-12, "domo con liquido debajo: FV al reves")
  check(not rd.real and r.real, "volumen real / imaginario")
  r = {}
  check(St.st_semicyl({ D = 1.5, L = 3, h = 3, s = 0.16, rows = 2, S = 1 }, C, r) == 0, "semicilindro ok")
  near(r.Fp, O("EPS-P3a", "Fperno"), TOL, "EPSON P3a fuerza por perno")
end

-- E5 flotacion
do
  local r = {}
  check(St.st_float({ shape = 6, mode = 0, H = 4.5, D = 3, e = 0.25, S = 1, rhob = 2500 }, C, r) == 0, "cilindro hueco ok")
  near(r.h, O("EPS-P4a", "h"), TOL, "EPSON P4a h")
  near(r.zB, O("EPS-P4a", "zB"), TOL, "EPSON P4a zB")
  near(r.zG, O("EPS-P4a", "zG"), TOL, "EPSON P4a zG")
  near(r.GM, O("EPS-P4a", "GM"), TOL, "EPSON P4a GM")
  check(not r.stable and not r.sink, "EPSON P4a: inestable y flota")
  r = {}
  St.st_float({ shape = 6, mode = 0, H = 0.75, D = 3, e = 0.25, S = 1, rhob = 2500 }, C, r)
  near(r.h, O("EPS-P4b (H=3e)", "h"), TOL, "EPSON P4b h")
  near(r.GM, O("EPS-P4b (H=3e)", "GM"), TOL, "EPSON P4b GM")
  check(r.sink, "EPSON P4b: calado mayor que la altura, se hunde")
  local b = 2 * 0.6 / math.sqrt(3)
  r = {}
  St.st_float({ shape = 1, mode = 0, H = 0.6, b = b, L = 1, S = 1, rhob = 700 }, C, r)
  near(r.h, O("P1-2018-P1a", "h"), TOL, "2018 P1a h (vertice abajo)")
  check(r.lg ~= nil and r.lg.total > 5, "prisma: biseccion con tabla")
  r = {}
  St.st_float({ shape = 2, mode = 0, H = 0.6, b = b, L = 1, S = 1, rhob = 300 }, C, r)
  near(r.h, O("P1-2018-P1b", "h"), TOL, "2018 P1b h (vertice arriba)")
  r = {}
  check(St.st_float({ shape = 3, mode = 1, H = 1.2, hk = 0.6, b = 2.4, L = 7.5, S = 1, h = 1.5 }, C, r) == 0, "barcaza ok")
  near(r.rhob, O("P1-2022-P4", "rho"), TOL, "2022 P4 rho")
  near(r.GM, O("P1-2022-P4", "GM"), TOL, "2022 P4 GM")
  near(r.zB, O("P1-2022-P4", "yB"), TOL, "2022 P4 yB")
  near(r.zG, O("P1-2022-P4", "yG"), TOL, "2022 P4 yG")
  local r2 = {}
  St.st_float({ shape = 3, mode = 0, H = 1.2, hk = 0.6, b = 2.4, L = 7.5, S = 1, rhob = 800 }, C, r2)
  near(r2.h, 1.5, 1e-6, "barcaza: calado desde rho = 800")
  r = {}
  St.st_float({ shape = 0, mode = 0, H = 1, b = 1, L = 1, S = 1, rhob = 500 }, C, r)
  near(r.h, O("P1-2017-P4i", "h"), TOL, "2017 P4i h")
  near(r.GM, O("P1-2017-P4i", "GM"), TOL, "2017 P4i GM")
  r = {}
  St.st_float({ shape = 4, mode = 0, b = 1, L = 1, S = 1, rhob = 500 }, C, r)
  near(r.h, O("P1-2017-P4ii", "h"), TOL, "2017 P4ii h")
  near(r.GM, O("P1-2017-P4ii", "GM"), TOL, "2017 P4ii GM")
  r = {}
  St.st_float({ shape = 0, mode = 0, H = 1, b = 1, L = 1, S = 1, rhob = 1500 }, C, r)
  check(r.sink, "prisma mas denso que el liquido: se hunde")
  check(St.st_float({ shape = 0, mode = 1, H = 1, b = 1, L = 1, S = 1, h = 2 }, C, {}) ~= 0, "calado mayor que la altura: error")
end

-- E6 equilibrio relativo
do
  local r = {}
  local dz = 2.5 / 9.81 * 7
  check(St.st_relative({ S = 1, ax = 2.5, az = 0, x0 = 7, z0 = 3, p0 = 100000, mode = 0, pts = {},
    tank = { x = 0, z = 0, Lx = 7, Hz = 3 } }, C, r) == 0, "relativo ok")
  near(r.pmax / 1000, O("P1-2018-P5", "Pmax_kPa"), TOL, "2018 P5 Pmax")
  near(r.pmin, 100000, 1e-12, "2018 P5 Pmin en la referencia")
  near(r.alpha, math.atan2(2.5, 9.81) * 180 / PI, 1e-9, "2018 P5 angulo de la superficie")
  r = {}
  St.st_relative({ S = 0.9, ax = 4.903, az = 0, x0 = 0, z0 = 1.2, p0 = 0, mode = 0,
    pts = { { 1.8, 0 }, { -0.15, -0.15 } } }, C, r)
  near(r.pp[1], O("P1-2022-P5", "PB"), TOL, "2022 P5 PB")
  near(r.pp[2], O("P1-2022-P5", "PC"), TOL, "2022 P5 PC")
  r = {}
  St.st_relative({ S = 0.9, ax = 0, az = 0, x0 = 0, z0 = 1.2, p0 = 0, mode = 1, xt = 1.8, zt = 0, pt = 0, pts = {} }, C, r)
  near(r.ax, O("P1-2022-P5", "ax0"), TOL, "2022 P5 ax para p(B) = 0")
  local r3 = {}
  St.st_relative({ S = 0.9, ax = 2, az = 0, x0 = 0, z0 = 1.2, p0 = 0, mode = 2, xt = 1.8, zt = 0, pt = 5000, pts = {} }, C, r3)
  local r4 = {}
  St.st_relative({ S = 0.9, ax = 2, az = r3.az, x0 = 0, z0 = 1.2, p0 = 0, mode = 0, pts = { { 1.8, 0 } } }, C, r4)
  near(r4.pp[1], 5000, 1e-9, "hallar az: la presion vuelve al valor pedido")
  r = {}
  check(St.st_pulley({ S = 1, mc1 = 0, V1 = 0.2, h1 = 0.2, mc2 = 0, V2 = 0.3, h2 = 0.3 }, C, r) == 0, "polea ok")
  near(r.a, O("EPS-P5b", "ay"), TOL, "EPSON P5b a")
  near(r.p1, O("EPS-P5b", "P1"), TOL, "EPSON P5b P1")
  near(r.p2, O("EPS-P5b", "P2"), TOL, "EPSON P5b P2")
  near(r.T, 2 * 200 * 300 * 9.81 / 500, 1e-9, "polea: tension")
end

-- ============================================================ UI
os.execute("mkdir build\\png 2>nul")
local function reset_set()
  local g = U.g_set
  for k in pairs(g) do g[k] = nil end
  g.dec = 6
  F.gset()
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
local CLEAR, UP, DOWN, LEFT, RIGHT, ENTER = "esc", "up", "down", "left", "right", "enter"
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
local function menu() W.APP_NAME = "FLUJOS"; run_fn(function() Sx.scr_stat_menu() end) end
local function scr_has(s) mock.paint(); return (mock.has_text(s)) end
local function has_line(s)
  for i = 1, W.view_n do
    if W.view_line[i]:find(s, 1, true) then return true end
  end
  return false
end
local function line_of(prefix)
  for i = 1, W.view_n do
    if W.view_line[i]:sub(1, #prefix) == prefix then return W.view_line[i] end
  end
end
local function val_of(prefix)               -- numero tras "prefijo" (p. ej. "> F = ")
  local l = line_of(prefix)
  if not l then return nil end
  return tonumber(l:sub(#prefix + 1):match("^(%S+)"))
end
local function memo_clean()
  for i = 1, W.view_n do
    local l = W.view_line[i]
    if l:find("?", 1, true) or l:find("{", 1, true) or l:find("nil", 1, true) or #l > 40 then
      return false, l
    end
  end
  return W.view_n < W.VIEW_MAX
end
local function inside(label)
  mock.paint()
  for _, t in ipairs(mock.screen_text()) do
    local ok = t.x >= 0 and t.x + t.w <= mock.W + 2 and t.y >= 0 and t.y + t.h <= mock.H + 2
    if not ok then
      check(false, label .. ": texto fuera de pantalla '" .. t.text .. "'")
    end
  end
end

-- ---- menus
do
  menu()
  check(scr_has("ESTATICA DE FLUIDOS"), "menu: titulo")
  for _, s in ipairs({ "(E1)", "(E2)", "(E3)", "(E4)", "(E5)", "(E6)", "Ejemplos de examen" }) do
    check(scr_has(s), "menu: " .. s)
  end
  inside("menu estatica")
  local subs = {
    { "1", "VISCOSIDAD (E1)", { "Placa entre dos paredes", "Eje y cojinete", "Bloque en plano inclinado" } },
    { "3", "SUPERFICIES PLANAS (E3)", { "Placas planas y bisagra", "Compuerta en L" } },
    { "4", "SUPERFICIES CURVAS (E4)", { "Cuarto de circulo", "Semicilindro con pernos" } },
    { "6", "EQUILIBRIO RELATIVO (E6)", { "Tanque con aceleracion", "Recipientes en polea" } },
  }
  for _, s in ipairs(subs) do
    T(s[1]); menu()
    check(scr_has(s[2]), "submenu " .. s[2])
    for _, it in ipairs(s[3]) do check(scr_has(it), s[2] .. ": " .. it) end
    inside("submenu " .. s[2])
  end
  -- ESC sale del submenu y luego del menu
  T("1"); K(CLEAR); menu()
  check(scr_has("ESTATICA DE FLUIDOS") and not R.done, "ESC vuelve del submenu al menu")
  K(CLEAR); play()
  check(R.done, "ESC sale del menu de estatica")
  -- ejemplos: lista con las 30 entradas
  T("7"); menu()
  check(scr_has("EJEMPLOS DE EXAMEN") and scr_has("EPSON P1a"), "lista de ejemplos")
  inside("lista de ejemplos")
  check(Sx.example_count() >= 29, "ejemplos: al menos 29")
  for i = 1, Sx.example_count() do
    check(#Sx.example_name(i) <= 40, "nombre de ejemplo cabe en 40 columnas: " .. Sx.example_name(i))
  end
  K(ENTER); play()
  check(has_line("Par T") and has_line("Potencia P"), "ENTER en la lista carga EPSON P1a y calcula")
end

-- ---- pantallas con sus datos por defecto, por el menu
do
  local routes = {
    { { "1", "1" }, "F TOTAL", "placa entre paredes" },
    { { "1", "2" }, "Potencia P", "cojinete" },
    { { "1", "3" }, "F HORIZONTAL", "bloque" },
    { { "2" }, "p final", "manometria" },
    { { "3", "1" }, "Fuerza F", "superficie plana" },
    { { "3", "2" }, "Momento volcador", "compuerta en L" },
    { { "4", "1" }, "Fuerza P", "cuarto de circulo" },
    { { "4", "2" }, "Fuerza por perno", "semicilindro" },
    { { "5" }, "GM", "flotacion" },
    { { "6", "1" }, "Pendiente dz/dx", "tanque acelerado" },
    { { "6", "2" }, "Tension T", "polea" },
  }
  for _, rt_ in ipairs(routes) do
    reset_set()
    for _, d in ipairs(rt_[1]) do T(d) end
    K("F5")
    menu()
    check(has_line(rt_[2]), "ruta " .. rt_[3] .. ": resumen con '" .. rt_[2] .. "'")
    inside("resumen " .. rt_[3])
    -- memoria con F1
    for _, d in ipairs(rt_[1]) do T(d) end
    K("F5"); K("F1")
    menu()
    check(memo_clean(), "ruta " .. rt_[3] .. ": memoria sin '?', '{' ni lineas largas")
    check(has_line("RESULTADO") and has_line("> "), "ruta " .. rt_[3] .. ": memoria con resultado")
    inside("memoria " .. rt_[3])
  end
  -- ESC del resultado vuelve al formulario y otro ESC al submenu
  T("1"); T("1"); K("F5"); K(CLEAR); menu()
  check(scr_has("Viscosidad mu"), "ESC del resultado vuelve al formulario")
  K(CLEAR); play()
  check(scr_has("VISCOSIDAD (E1)") or scr_has("Placa entre dos paredes"), "ESC del formulario vuelve al submenu")
end

-- ---- formularios dinamicos
do
  reset_set()
  -- superficies planas: 2 placas muestra la placa que se edita y quita la bisagra
  T("3"); T("1"); TE("2"); menu()
  check(scr_has("Placa que se edita"), "plana: 2 placas muestra 'Placa que se edita'")
  check(not scr_has("Bisagra"), "plana: con 2 placas no hay bisagra")
  K("F5"); menu()
  -- (la secuencia empieza de nuevo: n ya es 2 en el estado)
  T("3"); T("1"); K("F5"); menu()
  check(has_line("TOTAL") and has_line("F total"), "plana: resumen con 2 placas")
  -- flotacion: cambiar de forma cambia los campos
  T("5"); K(RIGHT); menu()
  check(scr_has("Largo L") or scr_has("Altura H"), "flotacion: la forma cambia los campos")
  -- cojinete: dato conocido cambia la unidad
  T("1"); T("2"); K(DOWN); K(DOWN); K(DOWN); K(DOWN); K(RIGHT); menu()
  check(scr_has("N.m"), "cojinete: dato par T muestra N.m")
  -- campo invalido: mu = 0 da error en pantalla y no calcula
  T("1"); T("1"); TE("0"); menu()
  check(scr_has("Debe ser mayor que 0"), "formulario rechaza mu = 0")
  reset_set()
end

-- ---- ejemplos de examen: valores y memoria
local function example(i, keys)
  reset_set()
  for _, k in ipairs(keys or {}) do K(k) end
  run_fn(function() Sx.example_run(i) end)
end
local function idx(name)
  for i = 1, Sx.example_count() do
    if Sx.example_name(i):find(name, 1, true) then return i end
  end
  check(false, "ejemplo no encontrado: " .. name)
  return 1
end
local expected = {
  { "EPSON P1a", { { "> T = ", O("EPS-P1a", "T") } } },
  { "EPSON P1b", { { "> Velocidad = ", O("EPS-P1b", "rpm") } } },
  { "EPSON P2-1", { { "> F = ", O("EPS-P2-1", "F") } } },
  { "EPSON P2-2", { { "> F = ", O("EPS-P2-2", "F") } } },
  { "EPSON P2-3", { { "> F = ", O("EPS-P2-3", "F") } } },
  { "EPSON P3a", { { "> Fuerza por perno = ", O("EPS-P3a", "Fperno") } } },
  { "EPSON P3b", { { "> FV = ", O("EPS-P3b", "FV") }, { "> P = ", O("EPS-P3b", "F") } } },
  { "EPSON P4a", { { "> h = ", O("EPS-P4a", "h") }, { "> GM = ", O("EPS-P4a", "GM") } } },
  { "EPSON P4b", { { "> h = ", O("EPS-P4b (H=3e)", "h") } } },
  { "EPSON P5b", { { "> a = ", O("EPS-P5b", "ay") }, { "> p fondo 1 = ", O("EPS-P5b", "P1") },
    { "> p fondo 2 = ", O("EPS-P5b", "P2") } } },
  { "P1-2024 P1", { { "> Potencia = ", O("P1-2024-P1", "P") }, { "> T = ", O("P1-2024-P1", "T") } } },
  { "P1-2018 P1a", { { "> h = ", O("P1-2018-P1a", "h") } } },
  { "P1-2018 P1b", { { "> h = ", O("P1-2018-P1b", "h") } } },
  { "P1-2018 P2", { { "> H = ", O("P1-2018-P2", "H") } } },
  { "P1-2018 P3", { { "> p final = ", O("P1-2018-P3", "Pa") / 1000 } } },
  { "P1-2018 P4", { { "> F total = ", O("P1-2018-P4", "F") } } },
  { "P1-2018 P5", { { "> p maxima = ", O("P1-2018-P5", "Pmax_kPa") } } },
  { "P1-2022 P1", { { "> F horizontal = ", O("P1-2022-P1", "F") } } },
  { "P1-2022 P2", { { "> F = ", O("P1-2022-P2", "F") }, { "> yp = ", O("P1-2022-P2", "yp") } } },
  { "P1-2022 P3 Cuarto circ. convexo", { { "> FR = ", O("P1-2022-P3-1", "F") },
    { "> FH = ", O("P1-2022-P3-1", "FH") } } },
  { "P1-2022 P3 Cuarto circ. concavo", { { "> FR = ", O("P1-2022-P3-2", "F") },
    { "> FV = ", O("P1-2022-P3-2", "FV") } } },
  { "P1-2022 P4", { { "> rho cuerpo = ", O("P1-2022-P4", "rho") }, { "> GM = ", O("P1-2022-P4", "GM") } } },
  { "P1-2022 P5 Aceleracion", { { "> p punto 1 = ", O("P1-2022-P5", "PB") },
    { "> p punto 2 = ", O("P1-2022-P5", "PC") } } },
  { "P1-2022 P5 a para", { { "> ax = ", O("P1-2022-P5", "ax0") } } },
  { "P1-2017 P1", { { "> dz = ", O("P1-2017-P1", "d_mm") / 1000 } } },
  { "P1-2017 P2", { { "> F = ", O("P1-2017-P2plana", "F_gl2w") * 9810 },
    { "> R apoyo = ", O("P1-2017-P2plana", "RA") * 9810 } } },
  { "P1-2017 P3a", { { "> F horizontal = ", O("P1-2017-P3a", "F") } } },
  { "P1-2017 P3b", { { "> F horizontal = ", O("P1-2017-P3b", "F") } } },
  { "P1-2017 P4a", { { "> h = ", O("P1-2017-P4i", "h") }, { "> GM = ", O("P1-2017-P4i", "GM") } } },
  { "P1-2017 P4b", { { "> h = ", O("P1-2017-P4ii", "h") }, { "> GM = ", O("P1-2017-P4ii", "GM") } } },
}
check(#expected >= 29, "tabla de ejemplos esperados")
do
  local covered = {}
  for _, e in ipairs(expected) do
    local i = idx(e[1])
    covered[i] = true
    example(i, { "F1" })               -- memoria de calculo
    check(R.done == false and memo_clean(), e[1] .. ": memoria limpia")
    for _, c in ipairs(e[2]) do
      local v = val_of(c[1])
      check(v ~= nil, e[1] .. ": memoria sin '" .. c[1] .. "'")
      if v then near(v, c[2], TOL, e[1] .. " memoria " .. c[1]) end
    end
    example(i)                         -- resumen
    check(W.view_n >= 3, e[1] .. ": resumen con lineas")
  end
  local n = 0
  for i = 1, Sx.example_count() do if covered[i] then n = n + 1 end end
  check(n == Sx.example_count(), "todos los ejemplos tienen su comprobacion (" .. n .. "/" .. Sx.example_count() .. ")")
  -- avisos y contenido especifico
  example(idx("EPSON P4b"), { "F1" })
  check(has_line("se hunde"), "EPSON P4b: la memoria avisa que se hunde")
  example(idx("EPSON P4a"), { "F1" })
  check(has_line("INESTABLE"), "EPSON P4a: inestable")
  example(idx("P1-2018 P2"), { "F1" })
  check(has_line("BISECCION EN H") and has_line("..."), "compuerta en L: tabla de iteraciones en la memoria")
  example(idx("P1-2018 P1a"), { "F1" })
  check(has_line("BISECCION EN EL CALADO"), "prisma triangular: tabla de iteraciones")
  example(idx("P1-2018 P4"), { "F1" })
  check(has_line("y0 = ") and has_line("s0") == false, "placa: y0 en la memoria")
  example(idx("EPSON P3b"), { "F1" })
  check(has_line("FUERZA PARA MANTENERLA CERRADA") and has_line("IMAGINARIO") == false and has_line("REAL"),
    "cuarto de circulo: volumen real y fuerza de cierre")
  example(idx("P1-2018 P5"), { "F1" })
  check(has_line("TANQUE CERRADO LLENO"), "tanque acelerado: seccion de extremos")
  example(idx("P1-2017 P1"), { "F1" })
  check(has_line("dz1 = (pB - pA - Sum)/(gamma S)"), "manometria: despeje del desnivel")
  -- el formato numerico de Ajustes cambia las memorias (2 decimales)
  reset_set()
  U.g_set.dec = 2
  run_fn(function() Sx.example_run(idx("P1-2018 P4")) end)
  K("F1"); play()
  check(has_line("> F total = 0.65 N"), "memoria usa los decimales de Ajustes")
  reset_set()
  -- cada resumen y cada memoria caben en pantalla
  for _, name in ipairs({ "EPSON P2-3", "EPSON P4a", "P1-2018 P2", "P1-2022 P5 Aceleracion" }) do
    example(idx(name))
    inside("resumen " .. name)
    example(idx(name), { "F1" })
    inside("memoria " .. name)
  end
  example(idx("EPSON P4a"))
end

-- ---- Mis casos: case_get / case_set / case_run
do
  reset_set()
  check(Sx.case_count() == 11 and Sx.kind_name(5) == "plane" and Sx.kind_name("float") == "float",
    "kinds: 11 tipos con nombre")
  for k = 1, Sx.case_count() do
    local t = Sx.case_get(k)
    check(type(t) == "table" and next(t) ~= nil, "case_get(" .. k .. ") tabla no vacia")
    for key, v in pairs(t) do
      if type(v) ~= "number" then check(false, "case_get(" .. k .. ")." .. key .. " no es numero") end
    end
    check(Sx.case_set(k, t), "case_set(" .. k .. ") acepta su propia tabla")
    local t2 = Sx.case_get(Sx.kind_name(k))
    local same = true
    for key, v in pairs(t) do if t2[key] ~= v then same = false end end
    check(same, "case_get/case_set(" .. k .. ") ida y vuelta")
  end
  check(not Sx.case_set(1, nil) and not Sx.case_set("nada", {}) and Sx.case_get(99) == nil,
    "case_set/case_get rechazan datos invalidos")
  -- un caso guardado se ejecuta con case_run y reproduce el resultado
  local ex_i = idx("P1-2022 P2")
  example(ex_i)
  local t = Sx.case_get("plane")
  Sx.case_set("plane", { n = 1, S = 1 })              -- estropea el estado
  Sx.case_set("plane", t)
  run_fn(function() Sx.case_run("plane") end)
  check(has_line("Fuerza F") and has_line("TOTAL") == false, "case_run: resultado de una placa")
  K("F1"); run_fn(function() Sx.case_run(5) end)
  near(val_of("> F = ") or 0, O("P1-2022-P2", "F"), TOL, "case_run: F del caso restaurado")
  check(not R.done, "case_run espera en el resultado")
  -- con KT_BASE asignado, F3 GUARDAR llama a case_save_ui
  local saved
  local orig = F.case_save_ui
  F.case_save_ui = function(tipo) saved = tipo end
  Sx.KT_BASE = 40
  K("F3"); run_fn(function() Sx.case_run("float") end)
  check(saved == 40 + 9 - 1, "F3 GUARDAR usa KT_BASE + kind - 1 (" .. tostring(saved) .. ")")
  Sx.KT_BASE = nil
  F.case_save_ui = orig
  reset_set()
end

-- ---- limites del visor: 4 placas y biseccion larga
do
  reset_set()
  local sp = { n = 4, cur = 1, S = 1.3, p0 = 5, sp0 = 1, hinge = 3, dh = 0.2 }
  for i = 1, 4 do
    sp["sh" .. i], sp["th" .. i], sp["hs" .. i], sp["b" .. i], sp["L" .. i], sp["b2" .. i] =
      (i - 1) % 5, 60 + i, i * 0.3, 2, 1.5, 1
  end
  sp.sh4 = 4
  Sx.case_set("plane", sp)
  run_fn(function() Sx.case_run("plane") end)
  K("F1"); run_fn(function() Sx.case_run("plane") end)
  check(has_line("SUMA DE PLACAS") and has_line("PLACA 4"), "4 placas: memoria completa")
  check(memo_clean() and W.view_n < W.VIEW_MAX, "4 placas: memoria cabe en el visor (" .. W.view_n .. ")")
  Sx.case_set("float", { shape = 3, mode = 0, S = 1, rhob = 800, b = 2.4, H = 1.2, hk = 0.6, L = 7.5 })
  K("F1"); run_fn(function() Sx.case_run("float") end)
  check(has_line("BISECCION EN EL CALADO") and memo_clean() and W.view_n < W.VIEW_MAX,
    "flotacion con biseccion larga: cabe en el visor (" .. W.view_n .. ")")
  reset_set()
end

print(string.format("test_statics: %d comprobaciones, %d fallo(s)", checks, fails))
if fails > 0 then os.exit(1) end
print("test_statics OK")
