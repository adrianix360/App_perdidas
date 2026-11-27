-- test_examenes.lua - Ejercicios de los examenes IC-605 (ampliacion): los marcados "Y" en
-- PLAN_AMPLIACION_EXAMENES.md se resuelven con los motores existentes (core/hydro, weir,
-- chan) y se comparan con tools/oracle_examenes.py (tolerancia relativa 2e-3); ademas VE-8
-- (tanques acoplados), la potencia de AR-1 y AR-5 (Magnus), con pruebas de pantalla.
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
local TOL = 2e-3
local function near(a, b, msg, tol)
  tol = tol or TOL
  local ok = type(a) == "number" and type(b) == "number" and
    math.abs(a - b) <= tol * math.max(math.abs(b), 1e-12) + 1e-12
  check(ok, (msg or "near") .. ": esperado " .. tostring(b) .. ", obtenido " .. tostring(a))
end

local U = env.require("ui.ui")
local W = env.require("ui.widgets")
local rt = env.require("ui.rt")
local MR = env.require("memo_run")
local H = env.require("core.hydro")
local We = env.require("core.weir")
local Ch = env.require("core.chan")
local Dr = env.require("core.drag")
local F = env.require("scr.flu_util")
local FL = env.require("scr.flujos")
local Cs = env.require("scr.cases")
local dc = env.require("data.dragcat")
local Sd, Sw, Sc = env.require("scr.scr_drag"), env.require("scr.scr_weir"),
  env.require("scr.scr_chan")

local g = 9.81
local PI = H.HYDRO_PI

-- =============================================================== motores
local function cfg(nu, method)
  local c = H.new_cfg()
  c.nu = nu
  c.method = method or H.FM_CW
  return c
end
local C = cfg(1e-6)
local L_PVC25 = { 0.05321, 0.06445, 0.07844, 0.10084, 0.14846, 0.19328,
                  0.24095, 0.28575, 0.35864 }

-- ---- Final-2025 P1 a,b: diametro de diseno (SumK = 12.8) y caudal de D = 285.75 mm
do
  local p = H.new_pipe(0, 1900, 1.5e-6, 12.8, 0)
  local r = {}
  check(H.hydro_design(p, 0.2, 76, L_PVC25, 9, C, r, nil) == 0, "FIN-2025-P1a: motor")
  near(r.D_exact * 1000, 256.832, "FIN-2025-P1a D exacto [mm]")
  near(r.D_com * 1000, 285.75, "FIN-2025-P1a D comercial [mm]")
  near(r.qmax.st.Q * 1000, 262.384, "FIN-2025-P1b Qmax [l/s]")
  near(r.qmax.st.v, 4.09143, "FIN-2025-P1b v [m/s]")
end

-- ---- Final-2025 P2 a,b: hf y valvula (Kv)
local p285 = H.new_pipe(0.28575, 1900, 1.5e-6, 12.8, 0)
do
  local vr = {}
  check(H.hydro_valve(p285, 0.2, 76, C, vr) == 0, "FIN-2025-P2: motor")
  near(vr.st.f, 0.0119894, "FIN-2025-P2 f")
  near(vr.st.v, 3.11866, "FIN-2025-P2 v")
  near(vr.st.hf, 39.5187, "FIN-2025-P2 hf")
  near(vr.st.hm, 6.34521, "FIN-2025-P2 hm")
  near(vr.hv, 30.1361, "FIN-2025-P2 hv")
  near(vr.Kv, 60.7926, "FIN-2025-P2 Kv")
end

-- ---- Final-2025 P3 a,b: turbina 65 % y bomba 60 %
do
  local m = {}
  check(H.hydro_turbine(p285, 0.2, 76, 0.65, C, m) == 0, "FIN-2025-P3a: motor")
  near(m.Pb / 1000, 59.127, "FIN-2025-P3a Pb [kW]")
  near(m.Pn / 1000, 38.4325, "FIN-2025-P3a Pn [kW]")
  check(H.hydro_pump(p285, 0.2, 76, 0.60, C, m) == 0, "FIN-2025-P3b: motor")
  near(m.Hm, 121.864, "FIN-2025-P3b HB [m]")
  near(m.Pn / 1000, 239.097, "FIN-2025-P3b Pn [kW]")
  near(m.Pb / 1000, 398.495, "FIN-2025-P3b Peje [kW]")
end

-- ---- Final-2025 P4 a,b: vertedero triangular de 90 grados (VE-2) y c: Venturi (EX-1)
do
  local tri = { { type = We.WE_TRI, count = 1, ncon = 0, Cd = 0.6, z = 0, a = 90, b = 0 } }
  local e, h = We.weir_level(tri, 1, 0.2, g, 0, nil)
  near(h, 0.456891, "FIN-2025-P4a H [m]")
  e, h = We.weir_level(tri, 1, 0.26064, g, 0, nil)
  near(h, 0.507945, "FIN-2025-P4b H [m]")
  local D1 = 0.28575
  local v = {}
  check(Ch.chan_venturi(D1, 0.6 * D1, 0.262384, 1, 4, Ch.MANO_PHYS, C, v) == 0, "FIN-2025-P4c: motor")
  near(v.dp, 56212.6, "FIN-2025-P4c dP [Pa]")
  near(v.h, 1.91005, "FIN-2025-P4c h con (S-1) [m]")
  near(v.v1, 4.09143, "FIN-2025-P4c V1")
  near(v.v2, 11.3651, "FIN-2025-P4c V2")
end

-- ---- Parcial 2-2025 P1: aire en una reduccion, manometro de agua (S = rho_w / rho_a)
do
  local ca = H.new_cfg()
  ca.gamma = 1.2 * ca.g                      -- fluido que circula: aire (rho = 1.2)
  local v = {}
  check(Ch.chan_venturi(0.22, 0.10, 0.12, 1, 1000 / 1.2, Ch.MANO_PHYS, ca, v) == 0, "P2-2025-P1: motor")
  near(v.v1, 3.15679, "P2-2025-P1 V1")
  near(v.v2, 15.2789, "P2-2025-P1 V2")
  near(v.dp, 134.087, "P2-2025-P1 dP [Pa]")
  near(v.h * 1000, 13.6848, "P2-2025-P1 h [mm]")
end

-- ---- Final-2025 P5: A en paralelo con B, en serie con C (f fijo)
do
  local n = H.new_net()
  H.hydro_net_init(n)
  local a = H.hydro_net_add_pipe(n, 500, 0.15, 0.014, 0, 0)
  local b = H.hydro_net_add_pipe(n, 600, 0.10, 0.018, 0, 0)
  local c = H.hydro_net_add_pipe(n, 700, 0.20, 0.015, 0, 5)
  local par = H.hydro_net_add_group(n, H.NODE_PARALLEL, { a, b }, 2)
  H.hydro_net_add_group(n, H.NODE_SERIES, { par, c }, 2)
  check(H.hydro_net_solve(n, 20, C) == 0, "FIN-2025-P5: motor")
  near(n.node[a].Q * 1000, 39.8813, "FIN-2025-P5 QA [l/s]")
  near(n.node[b].Q * 1000, 11.6514, "FIN-2025-P5 QB [l/s]")
  near(n.node[c].Q * 1000, 51.5327, "FIN-2025-P5 QC [l/s]")
end

-- ---- Final-2025: chorro desde un tubo (EX-3), con v^2/2g de salida
do
  local c = cfg(1e-6)
  local p = H.new_pipe(0.03, 5, 0.045e-3, 1, 0)
  local q, je = {}, {}
  check(H.hydro_qmax(p, 7.5, c, q, nil) == 0, "chorro: motor")
  Ch.chan_jet(q.st.v, 30, c.g, je)
  near(q.st.Q * 1000, 3.89973, "chorro Q [l/s]")
  near(q.st.v, 5.51699, "chorro v [m/s]")
  near(je.hmax, 0.387833, "chorro hmax [m]")
end

-- ---- Parcial 2-2024 P4 b,c: vertedero triangular y tirante alterno (VE-2 / VE-7)
do
  local Q = 4 / 3
  local tri = { { type = We.WE_TRI, count = 1, ncon = 0, Cd = 0.6, z = 0, a = 90, b = 0 } }
  local _, h = We.weir_level(tri, 1, Q, g, 0, nil)
  near(h, 0.975833, "P2-2024-P4b H [m]")
  local e, v1, E = We.weir_section(Q, 2, 1, g)
  local e2, hsub, hsup = We.weir_alt_depths(Q / 2, E, g)
  near(hsub, 1, "P2-2024-P4c tirante lento")
  near(hsup, 0.16226, "P2-2024-P4c h1 [m]")
  near(Q / 2 / hsup, 4.10864, "P2-2024-P4c v [m/s]")
end

-- ---- AR-1: potencia de arrastre (Parcial 2-2025 P4) con el motor
do
  for _, c in ipairs({ { 120, 0.21, 2.4, 11.2 }, { 120, 0.20, 2.45, 10.8889 },
    { 90, 0.21, 2.4, 4.725 }, { 90, 0.20, 2.45, 4.59375 } }) do
    local v = c[1] / 3.6
    local FD = Dr.drag_force(1.2, c[2], c[3], v)
    near(Dr.drag_power(FD, v) / 1000, c[4], "P2-2025-P4 " .. c[1] .. " km/h, CD " .. c[2] .. ": P [kW]")
  end
  near(Dr.drag_power(1000, 1) / Dr.HP_W, 1.34102, "kW -> hp")
end

-- ---- AR-5: Magnus (Parcial 2-2024 P5)
do
  local r = {}
  local V = 125 / 3.6
  check(Dr.drag_magnus(0.06, 0.065, V, 4800, 1.25, 0.12, 0, g, true, r) == 0, "P2-2024-P5: motor")
  near(r.SR, 0.470485, "P2-2024-P5 wD/2V")
  near(r.W, 0.5886, "P2-2024-P5 W [N]")
  near(r.B, 0.00176327, "P2-2024-P5 FB [N]")
  near(r.FL, 0.300049, "P2-2024-P5 FL [N]")
  near(r.Fnet, 0.300049 + 0.00176327 - 0.5886, "P2-2024-P5 Fnet [N]")
  check(not r.rises, "P2-2024-P5: la pelota cae")
  check(Dr.drag_magnus(0.06, 0.065, V, 4800, 1.25, 0, 0, g, true, r) == 0 and not r.lift and r.FL == 0,
    "Magnus sin CL: solo el parametro de giro")
  check(Dr.drag_magnus(0, 0.065, V, 4800, 1.25, 0.1, 0, g, true, r) ~= 0, "Magnus: m = 0 es invalido")
  check(Dr.drag_magnus(0.06, 0.065, V, 4800, 1.25, 0.12, 0, g, false, r) == 0 and r.Fnet < 0.3 - 0.5886,
    "Magnus: FL hacia abajo resta")
end

-- ---- VE-8: dos tanques acoplados (Vertedores P4 y Parcial 2-2025 P3)
local function el(type, n, a, z, Cd, b)
  return { type = type, count = n, ncon = 0, Cd = Cd or 0.6, z = z, a = a, b = b or 0 }
end
local function p4(extra)
  local t = { na = 0, a = {}, nb = 1, b = { el(We.WE_RECT, 1, 1.5, 2) },
              con = { type = We.WE_ORC, Cd = 0.6, a = 0.35, b = 0, z = 0.5 } }
  for k, v in pairs(extra) do t[k] = v end
  return t
end
local function p3(extra)
  local t = { na = 1, a = { el(We.WE_RECT, 1, 1.0, 1.1) }, nb = 3,
    b = { el(We.WE_ORC, 1, 0.2, 0.1), el(We.WE_RECT, 1, 0.6, 1.0), el(We.WE_TRI, 1, 90, 1.059) },
    con = { type = We.WE_ORR, Cd = 0.6, a = 0.2, b = 0.5, z = 0.5 } }
  for k, v in pairs(extra) do t[k] = v end
  return t
end
do
  local r, lg = {}, { n = 0, total = 0, r = {} }
  check(We.weir_tanks(p4({ mode = We.TK_QE, Qe = 0.25 }), g, r, lg) == 0, "VERT-P4a: motor")
  near(r.HB, 2.20684, "VERT-P4a HB [m]")
  near(r.HA, 3.16277, "VERT-P4a HA [m]")
  near(r.dh, 0.955931, "VERT-P4a dh [m]")
  near(r.Qe, 0.25, "VERT-P4a: balance Qe", 1e-9)
  near(r.Qcon, r.sumB, "VERT-P4a: Qcon = suma QB", 1e-12)
  check(r.iters > 5 and lg.n > 5, "VERT-P4a: bisecciion registrada")
  -- c) el nivel de T-A sube hasta el borde (HA = 3.5): Q limite
  check(We.weir_tanks(p4({ mode = We.TK_HA, HA = 3.5, wA = 3.5 }), g, r, lg) == 0, "VERT-P4c: motor")
  near(r.Qe * 1000, 288.437, "VERT-P4c Qlim [l/s]")
  near(r.HB - 2, 0.227527, "VERT-P4c carga del vertedero [m]")
  check(not H.warn_has(r.warn, We.VW_OVA), "VERT-P4c: HA justo en la pared no rebalsa")
  check(We.weir_tanks(p4({ mode = We.TK_QE, Qe = 0.30, wA = 3.5 }), g, r, lg) == 0 and
    H.warn_has(r.warn, We.VW_OVA), "VERT-P4: Qe sobre el limite avisa el rebalse")
  -- el nivel de T-B dado da lo mismo hacia aguas arriba
  check(We.weir_tanks(p4({ mode = We.TK_HB, HB = 2.20684 }), g, r, lg) == 0, "VERT-P4 modo HB")
  near(r.Qe * 1000, 250, "VERT-P4 modo HB: Qe [l/s]", 1e-4)
  -- caudal de un elemento dado: el vertedero de T-B con 250 l/s
  check(We.weir_tanks(p4({ mode = We.TK_ELEM, tank = 1, idx = 1, q = 0.25 }), g, r, lg) == 0,
    "VERT-P4 modo elemento")
  near(r.HA, 3.16277, "VERT-P4 modo elemento: HA", 1e-5)
  -- P3a: el triangular justo en su cresta (Q = 0)
  check(We.weir_tanks(p3({ mode = We.TK_ELEM, tank = 1, idx = 3, q = 0 }), g, r, lg) == 0, "P2-2025-P3a: motor")
  near(r.HB, 1.059, "P2-2025-P3a H1 [m]")
  near(r.QB[1] * 1000, 81.7636, "P2-2025-P3a Qr [l/s]")
  near(r.QB[2] * 1000, 15.2349, "P2-2025-P3a Q1 [l/s]")
  check(r.QB[3] == 0, "P2-2025-P3a: triangular sin carga")
  near(r.Qcon * 1000, 96.9985, "P2-2025-P3a Qor [l/s]")
  near(r.HA, 1.19221, "P2-2025-P3a H2 [m]")
  near(r.QA[1] * 1000, 49.6087, "P2-2025-P3a Q2 [l/s]")
  near(r.Qe * 1000, 146.607, "P2-2025-P3a QE [l/s]")
  -- P3b: el triangular entrega 50 l/s
  check(We.weir_tanks(p3({ mode = We.TK_ELEM, tank = 1, idx = 3, q = 0.05 }), g, r, lg) == 0, "P2-2025-P3b: motor")
  near(r.HB, 1.32141, "P2-2025-P3b H1 [m]")
  near(r.QB[1] * 1000, 92.2746, "P2-2025-P3b Qr [l/s]")
  near(r.Qcon * 1000, 335.988, "P2-2025-P3b Qor [l/s]")
  near(r.HA, 2.91967, "P2-2025-P3b H2 [m]")
  near(r.QA[1] * 1000, 4349.09, "P2-2025-P3b Q2 [l/s]")
  near(r.Qe * 1000, 4685.07, "P2-2025-P3b QE [l/s]")
  -- y el sentido inverso: dado QE, se recuperan los niveles
  check(We.weir_tanks(p3({ mode = We.TK_QE, Qe = 4.68507 }), g, r, lg) == 0, "P2-2025-P3b inverso")
  near(r.HB, 1.32141, "P2-2025-P3b inverso H1", 1e-4)
  near(r.HA, 2.91967, "P2-2025-P3b inverso H2", 1e-4)
  -- sin salida en T-A (na = 0) y con Q de A dado: nivel de T-A por el vertedero de A
  check(We.weir_tanks(p3({ mode = We.TK_ELEM, tank = 0, idx = 1, q = 0.0496087 }), g, r, lg) == 0,
    "VE-8: elemento de T-A dado")
  near(r.HA, 1.19221, "VE-8: elemento de T-A dado: HA", 1e-3)
  -- errores
  check(We.weir_tanks(p4({ mode = We.TK_QE, Qe = 0 }), g, r, lg) ~= 0, "VE-8: Qe = 0 es error")
  check(We.weir_tanks(p4({ mode = We.TK_QE, Qe = 0.1, nb = 0 }), g, r, lg) ~= 0, "VE-8: T-B sin salidas es error")
  local bad = p4({ mode = We.TK_QE, Qe = 0.1 })
  bad.con.Cd = 0
  check(We.weir_tanks(bad, g, r, lg) ~= 0, "VE-8: Cd = 0 es error")
  local uns = p4({ mode = We.TK_QE, Qe = 0.25 })
  uns.con.z = 2.2
  check(We.weir_tanks(uns, g, r, lg) == 0 and H.warn_has(r.warn, We.VW_UNSUB),
    "VE-8: orificio por encima del nivel de T-B avisa")
  -- barrido: Qe -> niveles -> Qe (todo coherente)
  local worst = 0
  for i = 1, 40 do
    local Qe = 0.005 * i * i / 4
    local t = p3({ mode = We.TK_QE, Qe = Qe })
    We.weir_tanks(t, g, r, lg)
    local q1 = r.Qe
    t.mode = We.TK_HA; t.HA = r.HA
    We.weir_tanks(t, g, r, lg)
    worst = math.max(worst, math.abs(r.Qe - Qe) / Qe, math.abs(q1 - Qe) / Qe)
  end
  check(worst < 1e-6, "VE-8: Qe -> HA -> Qe cierra (peor error " .. worst .. ")")
end

-- ================================================================= pantallas
local function reset_set()
  local g_ = U.g_set
  for k in pairs(g_) do g_[k] = nil end
  g_.dec = 6
  dc.cd_user = {}
  F.gset()
  g_.cd_user = dc.cd_user
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
local ENTER, CLEAR, DOWN, PGUP = "enter", "esc", "down", "backtab"
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
  W.APP_NAME = "FLUJOS"
  start(function() FL.flujos_main() end)
  play()
end
local function run_fn(fn) start(fn); play() end
local function scr_has(s) mock.paint(); return (mock.has_text(s)) end
local function has_line(s)
  for i = 1, W.view_n do
    if W.view_line[i]:find(s, 1, true) then return true end
  end
  return false
end
local function line_of(s)
  for i = 1, W.view_n do
    if W.view_line[i]:find(s, 1, true) then return W.view_line[i] end
  end
end
local function memo_clean()
  for i = 1, W.view_n do
    local l = W.view_line[i]
    if l:find("?", 1, true) or l:find("{", 1, true) or #l > 40 then return false, l end
  end
  return W.view_n < W.VIEW_MAX
end
local function inside(label)
  mock.paint()
  for _, t in ipairs(mock.screen_text()) do
    local ok = t.x >= 0 and t.x + t.w <= mock.W + 2 and t.y >= 0 and t.y + t.h <= mock.H + 2
    if not ok then check(false, label .. ": texto fuera de pantalla '" .. t.text .. "'") end
  end
end
local function num_after(line, label)       -- numero tras "label = " en una linea del visor
  local l = line_of(label)
  if not l then return nil end
  return tonumber(l:match("=%s*([%-%d%.Ee+]+)"))
end

-- ---- EX-1 en la pantalla: Final-2025 P4c (Q -> dP y h con S-1) y aire (P2-2025 P1)
do
  Sc.chan_load({ D1 = 285.75, sD1 = 1, beta = 0.6, sbeta = 1, Q = 262.384, sQ = 1, Cv = 1, sCv = 1,
    S = 4, sS = 1, conv = 0 })
  run_fn(function() Sc.scr_chan_run(0, true) end)
  check(not rt.fatal and has_line("> dp = p1 - p2 = 5621"), "EX-1 pantalla: dP = 56.21 kPa")
  near(MR.V[MR.V_VDP], 56212.6, "EX-1 pantalla dP")
  near(MR.V[MR.V_VH], 1.91005, "EX-1 pantalla h con (S-1)")
  K("F1"); play()
  check(memo_clean(), "EX-1: memoria limpia")
  -- aire: rho fluido = 1.2 y S = rho_w / rho_a
  Sc.chan_load({ D1 = 220, sD1 = 1, D2 = 100, sD2 = 1, Q = 120, sQ = 1, Cv = 1, sCv = 1,
    S = 1000 / 1.2, sS = 1, conv = 0, rho = 1.2, srho = 1 })
  run_fn(function() Sc.scr_chan_run(0, true) end)
  near(MR.V[MR.V_VDP], 134.087, "EX-1 con aire: dP [Pa]")
  near(MR.V[MR.V_VH] * 1000, 13.6848, "EX-1 con aire: h [mm]")
  -- sin rho: agua de Ajustes (como antes)
  Sc.chan_load({ D1 = 285.75, sD1 = 1, beta = 0.6, sbeta = 1, Q = 200, sQ = 1, Cv = 1, sCv = 1,
    S = 4, sS = 1, conv = 1 })
  run_fn(function() Sc.scr_chan_run(0, true) end)
  near(MR.V[MR.V_VH], MR.V[MR.V_VDP] / (4 * 9810), "EX-1 sin rho: igual que antes (S g h del examen)", 1e-9)
  Sc.chan_load({})
end

-- ---- AR-1: potencia de arrastre P = FD V
do
  reset_set()
  Sd.drag_load({ b = {}, rho = 1.2, srho = 1, nu = 1.5e-5, snu = 1, V = 120, sV = 1, vunit = 1,
    cd = 0.21, scd = 1, A = 2.4, sA = 1, nw = 2, snw = 1, nb = 2, snb = 1 })
  run_fn(function() Sd.scr_drag_run(0, true) end)
  check(not rt.fatal and has_line("POTENCIA DE ARRASTRE"), "AR-1: resultado con potencia")
  near(num_after("", "> P = FD V"), 11200, "AR-1 pantalla P [W]", 1e-3)
  check(has_line("> P = 11.2") and has_line("kW") and has_line("hp"), "AR-1: P en kW y hp")
  K("F1"); play()
  check(has_line("P = FD V") and has_line("= 11200") and memo_clean(), "AR-1: memoria con P = FD V")
  -- sustentacion: sin potencia
  Sd.drag_load({ b = {}, rho = 1.2, srho = 1, nu = 1.5e-5, snu = 1, V = 120, sV = 1, vunit = 1,
    cd = 0.21, scd = 1, A = 2.4, sA = 1, lift = 1, nw = 2, snw = 1, nb = 2, snb = 1 })
  run_fn(function() Sd.scr_drag_run(0, true) end)
  check(not has_line("POTENCIA DE ARRASTRE"), "AR-1 sustentacion: sin potencia")
  reset_set()
end

-- ---- AR-5: Magnus, desde el menu FLUJOS y con el caso del curso
do
  reset_set()
  Sd.drag_load({ b = {} })
  T("16"); runf()
  check(scr_has("BALANCE VERTICAL (AR-5)") and scr_has("Masa m") and scr_has("Giro w"),
    "AR-5: abre desde Arrastre (menu 1, opcion 6)")
  inside("AR-5 formulario")
  K(CLEAR); K(CLEAR); K(CLEAR); play()
  -- caso del curso
  run_fn(function() Sd.scr_drag_run(Sd.drag_preset(6), true) end)
  check(not rt.fatal and has_line("> w D / (2 V) = 0.47048") and has_line("> W = m g = 0.5886"),
    "AR-5: parametro de giro y peso")
  near(num_after("", "> Empuje FB"), 0.00176327, "AR-5 FB", 1e-3)
  near(num_after("", "> Sustentacion FL"), 0.300049, "AR-5 FL", 1e-3)
  near(num_after("", "> Fuerza neta"), -0.285, "AR-5 Fnet", 1e-2)
  check(has_line("> CAE"), "AR-5: conclusion cae")
  inside("AR-5 resultado")
  K("F1"); play()
  check(has_line("wD/2V = w D / (2 V)") and has_line("FL = CL q A") and has_line("Fnet = FL + FB - W") and
    memo_clean(), "AR-5: memoria con formulas")
  -- sin CL: da el parametro y pide la lectura
  Sd.drag_load(F.deep_copy(Sd.drag_save()))
  local d = Sd.drag_save()
  d.scl = 0
  Sd.drag_load(d)
  run_fn(function() Sd.scr_drag_run(5, true) end)
  check(has_line("Lea C_L en la grafica") and has_line("> w D / (2 V) = 0.47048") and
    not has_line("> Fuerza neta"), "AR-5 sin CL: pide la lectura de la grafica")
  -- con CL alto sube
  d.scl, d.cl = 1, 1.2
  Sd.drag_load(d)
  run_fn(function() Sd.scr_drag_run(5, true) end)
  check(has_line("> SUBE"), "AR-5 CL = 1.2: la pelota sube")
  d.lsgn = 1
  Sd.drag_load(d)
  run_fn(function() Sd.scr_drag_run(5, true) end)
  check(has_line("> CAE"), "AR-5: FL hacia abajo cae")
  reset_set()
end

-- ---- VE-8 en la pantalla: menu FLUJOS > Vertedores > Tanques acoplados
do
  reset_set()
  Sw.weir_load({ e = {} })
  T("25"); runf()
  check(scr_has("TANQUES ACOPLADOS (VE-8)") and scr_has("Calcular") and scr_has("Orificio conexion"),
    "VE-8: abre desde Vertedores (menu 2, opcion 5)")
  inside("VE-8 formulario")
  -- sin datos: avisa
  K("F5"); play()
  check(scr_has("Falta") or scr_has("Faltan"), "VE-8: sin datos avisa")
  K(CLEAR); K(CLEAR); K(CLEAR); play()
  -- casos del curso VE-9..VE-12 (los 4 ejercicios) y AR-07
  local checks = {
    { 17, { "> HB (nivel T-B) = 2.2068", "> HA (nivel T-A) = 3.1627", "> Qe (entra a T-A) = 250" } },
    { 18, { "> Qe (entra a T-A) = 288.43", "> HA (nivel T-A) = 3.5" } },
    { 19, { "> Qe (entra a T-A) = 146.60", "> HB (nivel T-B) = 1.059", "> HA (nivel T-A) = 1.1922" } },
    { 20, { "> Qe (entra a T-A) = 4685.0", "> HA (nivel T-A) = 2.9196", "> HB (nivel T-B) = 1.3214" } },
    { 21, { "> w D / (2 V) = 0.47048" } },
  }
  for _, c in ipairs(checks) do
    reset_set()
    T("75"); K(PGUP); K(PGUP)
    for _ = 1, c[1] do K(DOWN) end
    K(ENTER); runf()
    for _, s in ipairs(c[2]) do
      check(has_line(s), "caso del curso " .. (c[1] + 1) .. ": " .. s)
    end
    check(not rt.fatal, "caso del curso " .. (c[1] + 1) .. ": sin error")
  end
  -- VE-9 detalle: resumen, memoria paso a paso
  run_fn(function() Sw.scr_weir_run(Sw.weir_preset(8), true) end)
  check(has_line("> Q conexion A->B = 250") and has_line("B1 Rectangular: Q = 250") and
    has_line("Sin advertencias"), "VE-9: resumen")
  inside("VE-9 resumen")
  K("F1"); play()
  check(has_line("QB1 = n Cd (2/3) sqrt(2g) b H^1.5") and has_line("dh = (Qcon/(Cd A))^2/(2g)") and
    has_line("HA = HB + dh") and has_line("Qe = Qcon + suma QA") and has_line("5. BISECCION DE HB") and
    has_line("HB min"), "VE-9: memoria con formulas, balance y tabla")
  check(memo_clean(), "VE-9: memoria sin plantillas ni lineas largas")
  inside("VE-9 memoria")
  -- VE-10: rebalse, nivel de T-A = pared
  run_fn(function() Sw.scr_weir_run(Sw.weir_preset(9), true) end)
  check(has_line("> Qe (entra a T-A) = 288.43"), "VE-10: caudal limite")
  K("F1"); play()
  check(has_line("Dado nivel de T-A: HA = 3.5") and has_line("Pared T-A"), "VE-10: memoria con la pared")
  -- VE-11 / VE-12: dos tanques con T-A
  run_fn(function() Sw.scr_weir_run(Sw.weir_preset(10), true) end)
  K("F1"); play()
  check(has_line("3. SALIDAS DE T-A") and has_line("QA1 = n Cd (2/3) sqrt(2g) b H^1.5") and
    has_line("B3 Triangular x1 theta=90") and has_line("no recibe agua") and memo_clean(),
    "VE-11: memoria con T-A y el triangular sin carga")
  run_fn(function() Sw.scr_weir_run(Sw.weir_preset(11), true) end)
  check(has_line("> Qe (entra a T-A) = 4685.0") and has_line("B3 Triangular: Q = 50"), "VE-12: resultado")
  K("F1"); play()
  check(has_line("QB3 = n Cd 8/15 sqrt(2g) tan(t/2) H^2.5") and memo_clean(), "VE-12: memoria del triangular")
  -- Qe dado a mano en la pantalla (modo 0) sobre el caso VE-11
  local d = Sw.weir_save()
  d.tmode, d.Qe, d.sQe = 0, 146.607, 1
  Sw.weir_load(d)
  run_fn(function() Sw.scr_weir_run(4, true) end)
  check(has_line("> HB (nivel T-B) = 1.0589") or has_line("> HB (nivel T-B) = 1.059"), "VE-8 modo Qe: HB")
  -- modo nivel de T-B
  d.tmode, d.HBv, d.sHBv = 3, 2.2, 1
  Sw.weir_load(d)
  run_fn(function() Sw.scr_weir_run(4, true) end)
  check(has_line("> HB (nivel T-B) = 2.2") and not rt.fatal, "VE-8 modo HB dado")
  -- nivel de T-B vacio sin pared: avisa
  d.sHBv, d.swB = 0, 0
  Sw.weir_load(d)
  run_fn(function() Sw.scr_weir_run(4, true) end)
  check(scr_has("Falta el nivel de T-B"), "VE-8: nivel de T-B sin dato ni pared avisa")
  reset_set()
end

-- ---- Mis casos: VE-8 y AR-5 se guardan y recargan; los casos viejos siguen leyendose
do
  reset_set()
  for k in pairs(U.state.cas) do U.state.cas[k] = nil end
  local function save_seq(name) K("F3"); T(name); K(ENTER); K(ENTER) end
  -- VE-8 (preset VE-11): calcular y guardar
  Sw.weir_preset(10)
  Sw.weir_load(Sw.weir_save())
  start(function() Sw.scr_weir_run(Sw.weir_preset(10), true) end)
  save_seq("TANQUES"); play()
  -- AR-5
  start(function() Sd.scr_drag_run(Sd.drag_preset(6), true) end)
  save_seq("MAGNUS"); play()
  check(#U.state.cas == 2 and U.state.cas[1].tipo == 20 and U.state.cas[2].tipo == 21,
    "Mis casos: VE-8 (tipo 20) y AR-5 (tipo 21) guardados")
  check(Cs.tipo_txt[20] and Cs.tipo_txt[21], "Mis casos: nombres de tipo")
  -- recargar tras borrar los datos
  Sw.weir_load({ e = {} }); Sd.drag_load({ b = {} })
  W.APP_NAME = "FLUJOS"
  T("5"); K(ENTER); runf()
  check(has_line("> Qe (entra a T-A) = 146.60") and has_line("> HB (nivel T-B) = 1.059"),
    "Mis casos: VE-8 recarga y calcula")
  Sw.weir_load({ e = {} }); Sd.drag_load({ b = {} })
  T("5"); K(DOWN); K(ENTER); runf()
  check(has_line("> w D / (2 V) = 0.47048") and has_line("> CAE"), "Mis casos: AR-5 recarga y calcula")
  -- on.save / on.restore
  local saved = mock.save()
  check(type(saved.cas) == "table" and #saved.cas == 2 and saved.cas[1].tipo == 20, "on.save conserva VE-8 y AR-5")
  for k in pairs(U.state.cas) do U.state.cas[k] = nil end
  mock.restore(saved)
  check(#U.state.cas == 2 and U.state.cas[2].tipo == 21, "on.restore recupera VE-8 y AR-5")
  -- datos de la version anterior (sin los campos nuevos y con tipos 0..19): se leen igual
  local old = Sw.weir_save()
  for _, k in ipairs({ "Qe", "qel", "HAv", "HBv", "wA", "wB", "nA", "nB", "ccd", "cd1", "cd2", "cz",
    "tmode", "esel", "ctype", "tinit" }) do old[k] = nil; old["s" .. k] = nil end
  saved.cas[#saved.cas + 1] = { nombre = "VIEJO", tipo = 14, datos = old }
  saved.cas[#saved.cas + 1] = { nombre = "FUTURO", tipo = 99, datos = old }       -- tipo desconocido
  mock.restore(saved)
  check(#U.state.cas == 3 and U.state.cas[3].nombre == "VIEJO", "store: caso viejo (VE-4) se conserva, tipo 99 se descarta")
  Sw.weir_load({ e = {} })
  T("5"); K(DOWN); K(DOWN); K(ENTER); runf()
  check(not rt.fatal and #U.state.cas == 3, "store: el caso viejo carga sin errores")
  -- un caso VE-4 viejo guardado antes de la ampliacion
  Sw.weir_load(old)
  run_fn(function() Sw.scr_weir_run(Sw.weir_preset(0), true) end)
  check(has_line("> Q total = 0.7405"), "VE-01 sigue dando Q = 0.7405")
  -- version vieja de ajustes (ver 3): se sigue leyendo
  local st = mock.save()
  check(st.ver == 3 or st.ver == nil or type(st.ver) == "number", "store: version de ajustes")
  for k in pairs(U.state.cas) do U.state.cas[k] = nil end
  reset_set()
end

print(string.format("test_examenes: %d comprobaciones, %d fallo(s)", checks, fails))
if fails > 0 then os.exit(1) end
print("test_examenes OK")
