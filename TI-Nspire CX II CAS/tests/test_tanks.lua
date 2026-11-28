-- test_tanks.lua - Tres tanques: comprobaciones numericas del motor (tarea con
-- Colebrook y Q_T = 60 l/s, pizarra con f dado) y la pantalla con el ejemplo.
local mock = dofile("tests/mock_nspire.lua")
local env = mock.load_app("build/app.lua")

local fails, checks = 0, 0
local function check(cond, msg)
  checks = checks + 1
  if not cond then fails = fails + 1; print("FALLO: " .. tostring(msg)) end
  return cond
end
local function near(a, b, tol) return math.abs(a - b) <= tol end

local rt = env.require("ui.rt")
local W = env.require("ui.widgets")
local H = env.require("core.hydro")
local TK = env.require("core.tanks")
local Sc = env.require("scr.screens")
local P = H.new_pipe
local c = H.new_cfg()

-- 1. Tarea (solucion a mano: Z_J ~ 120.38, Q = -32, 129, -37 l/s; iter. 1 con
--    Z_J = 110: Q = 186, 162, -25 l/s, dQ = 263, dZ = 19.84)
local t = { n = 3, Z = { 120, 140, 100 }, QT = 0.060, ZJ0 = 110,
  pipe = { P(0.25, 200, 1.5e-6, 4, 0), P(0.20, 300, 1.5e-6, 4, 0), P(0.10, 100, 1.5e-6, 4, 0) } }
local r = {}
check(TK.tanks_solve(t, c, r) == 0, "tarea: converge")
local w1 = r.rows[1]
check(near(1000 * w1.Q[1], 186, 3) and near(1000 * w1.Q[2], 162, 3) and near(1000 * w1.Q[3], -25, 2),
  "tarea iter 1: Q como a mano")
check(near(w1.dZ, 19.84, 0.2), "tarea iter 1: dZ = 19.84 (" .. w1.dZ .. ")")
check(near(r.ZJ, 120.38, 0.05), "tarea: Z_J = 120.38 (" .. r.ZJ .. ")")
check(near(1000 * r.Q[1], -32, 2) and near(1000 * r.Q[2], 129, 2.5) and near(1000 * r.Q[3], -37, 1.5),
  "tarea: Q final como a mano")
check(math.abs(r.Q[1] + r.Q[2] + r.Q[3] - 0.060) < 1e-5, "tarea: balance en el nudo")

-- 2. Pizarra (f dado, M = 1420.1, 1919.9, 6153.4; Z_J = 62.3 m, Q_T = 0)
local t2 = { n = 3, Z = { 100, 50, 20 }, QT = 0,
  pipe = { P(0.20, 400, 0, 3.5, 0.012), P(0.18, 350, 0, 3, 0.011), P(0.15, 480, 0, 2.5, 0.011) } }
local r2 = {}
check(TK.tanks_solve(t2, c, r2) == 0, "pizarra: converge")
check(near(r2.ZJ, 62.3, 0.05), "pizarra: Z_J = 62.3 (" .. r2.ZJ .. ")")
for i, M in ipairs({ 1420.1, 1919.9, 6153.4 }) do
  check(near(math.abs(r2.h[i]) / r2.Q[i] ^ 2, M, 0.5), "pizarra: h = M Q^2 tramo " .. i)
end
check(math.abs(r2.Q[1] + r2.Q[2] + r2.Q[3]) < 1e-6, "pizarra: balance en el nudo")

-- 3. Pantalla: menu 10, F2 carga el ejemplo, CALC, memoria sin errores
rt.start(rt.app_main)
W.APP_NAME = "PERDIDAS"
Sc.reset_menus()
mock.key("1"); for _ = 1, 9 do mock.key("down") end; mock.key("enter")   -- 10 Tres tanques
local function F(i) mock.paint(); mock.click(math.floor((i - 0.5) * mock.W / 5), mock.H - 5) end
F(2); F(5)
local function view()
  local s = {}
  for i = 1, W.view_n do s[i] = W.view_line[i] end
  return table.concat(s, "\n")
end
check(not rt.fatal and view():find("Z_J nudo", 1, true), "pantalla: resumen del ejemplo")
F(1)
local v = view()
check(not rt.fatal and v:find("ITERACION 1", 1, true) and v:find("COMPROBACION", 1, true),
  "pantalla: memoria completa (" .. W.view_n .. " lineas)")
check(W.view_n < W.VIEW_MAX, "pantalla: la memoria cabe en el visor")
if os.getenv("TDUMP") then print(v) end

print(string.format("test_tanks: %d comprobaciones, %d fallo(s)", checks, fails))
if fails > 0 then os.exit(1) end
print("test_tanks OK")
