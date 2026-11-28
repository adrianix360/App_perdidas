-- test_jv.lua - Funciones de las Modificaciones JV (tuberias_2.lua) integradas:
-- programa original, bomba en la linea (A, B, D, G) y redondeo a 3 decimales.
-- Valores de referencia: los da el propio tuberias_2.lua con los mismos datos.
local mock = dofile("tests/mock_nspire.lua")
local env = mock.load_app("build/app.lua")

local fails, checks = 0, 0
local function check(cond, msg)
  checks = checks + 1
  if not cond then fails = fails + 1; print("FALLO: " .. tostring(msg)) end
  return cond
end
local function rel(a, b) return math.abs(a - b) / math.abs(b) end

local rt = env.require("ui.rt")
local U = env.require("ui.ui")
local W = env.require("ui.widgets")
local H = env.require("core.hydro")
local O = env.require("scr.scr_orig")
local Pipe = env.require("scr.scr_pipe")
local Net = env.require("scr.scr_net")

local function view()
  local s = {}
  for i = 1, W.view_n do s[i] = W.view_line[i] end
  return table.concat(s, "\n")
end
local function num(label)
  for i = 1, W.view_n do
    local l = W.view_line[i]
    local lab, v = l:match("^%s*(.-)%s*=%s*([%-%d%.Ee]+)")
    if lab == label and v then return tonumber(v) end
  end
end
local function rowv(res, label)
  for _, r in ipairs(res.r) do
    if r[1] == label then return tonumber(r[2]:match("^([%-%d%.Ee]+)")) end
  end
end

-- ------------------------------------------------------------ programa original
local oi = O.oi
local function set(t) for k, v in pairs(t) do oi[k] = v; if oi["s" .. k] ~= nil then oi["s" .. k] = 1 end end end
set({ dz = 30, D = 200, L = 500, ks = 0.05, nu0 = 1.02e-6, K = 5, f0 = 0.02, cs = 0, bom = 0 })
local r = O.compute(1, false)
check(r and rowv(r, "Caudal Q") == 113.995 and #r.t.rows == 3, "original Q: 113.995 l/s, 3 iteraciones (JV)")
set({ bom = 1, bdato = 1, bHB = 10 })
r = O.compute(1, false)
check(r and rowv(r, "Caudal Q") == 132.149, "original Q con HB = 10: 132.149 l/s (JV)")
set({ bdato = 0, bP = 20, bEta = 0.75 })
r = O.compute(1, false)
check(r and rowv(r, "Caudal Q") == 134.437 and rowv(r, "HB bomba") == 11.374,
  "original Q con P = 20 kW: 134.437 l/s, HB 11.374 (JV)")
set({ bom = 0, Q = 60, D0 = 100 })
r = O.compute(2, false)
check(r and rowv(r, "Diametro D") == 155.511 and #r.t.rows == 9, "original D: 155.511 mm, 9 iteraciones (JV)")
set({ cs = 1, dz = 20, eta = 0.8 })
r = O.compute(3, false)
check(r and rowv(r, "Altura bomba HB") == 28.487, "original H bomba: 28.487 m (JV)")
set({ dz = 60 })
r = O.compute(4, false)
check(r and rowv(r, "Altura turbina HTur") == 51.513, "original H turbina: 51.513 m (JV)")
set({ cs = 0 })
r = O.compute(5, false)
check(r and rowv(r, "dZ = hT+Vs2/2g") == 8.673, "original perdidas totales: dZ 8.673 m (JV)")
W.view_clear(); r.memo()
check(view():find("f: ITERACION 1", 1, true) and W.view_n < W.VIEW_MAX, "original: memoria de la 1.a iteracion")
for i = 1, #O.ORIG_IND do
  set({ Q = 60, D = 200, V = 2, nu0 = 1e-6, ks = 0.05, Re = 1e5, eD = 1e-4, L = 100, hl = 1, HB = 20,
        HTu = 20, eta = 0.8, K = 2 })
  local x, err = O.compute(i, true)
  check(x and #x.r > 0, "calculo individual " .. i .. " (" .. tostring(err) .. ")")
end

-- ------------------------------------------------------------ bomba en la linea
local pin = Pipe.pin
local function run_pipe(t)
  rt.start(function() Pipe.scr_pipe_run(t, true) end)
  mock.paint()
end
Pipe.pin_reset()
pin.H, pin.D, pin.L, pin.ks, pin.K, pin.nu = 30, 200, 500, 0.05, 5, 1e-6
pin.sH, pin.sD, pin.sL, pin.sks, pin.sK, pin.snu = 1, 1, 1, 1, 1, 1
pin.bom, pin.bdato, pin.bP, pin.bEta, pin.sbP, pin.sbEta = 1, 0, 20, 0.75, 1, 1
U.g_set.h.method = 0
run_pipe(1)
local q, hb = num("Q"), num("HB bomba")
check(not rt.fatal and q and hb and rel(q, 135.875) < 2e-3 and rel(hb, 11.253) < 2e-3,
  "B con bomba P: Q " .. tostring(q) .. " ~ 135.875, HB " .. tostring(hb) .. " ~ 11.253 (JV)")
pin.bdato, pin.bHB, pin.sbHB = 1, 10, 1
run_pipe(1)
q = num("Q")
check(q and rel(q, 133.755) < 2e-3, "B con HB = 10: Q " .. tostring(q) .. " ~ 133.755 (JV)")
pin.Q, pin.sQ = 60, 1
run_pipe(2)
local d = num("D exacto")
check(d and rel(d, 146.276) < 2e-3, "D con HB = 10: D exacto " .. tostring(d) .. " ~ 146.276 (JV)")
mock.paint(); mock.click(math.floor(0.5 * mock.W / 5), mock.H - 5)
check(not rt.fatal and view():find("BOMBA EN LA LINEA", 1, true), "D con bomba: memoria con la seccion BOMBA")
check(not view():find("Hazen-Williams, C_H = 0", 1, true), "sin C_H no anuncia arranque Hazen-Williams")

-- G: dos tubos en serie con HB dada = mismo Q que sin bomba y H + HB
local ni = Net.ni
ni.np, ni.snp, ni.mode, ni.H, ni.sH, ni.nu, ni.snu = 2, 1, 0, 20, 1, 1e-6, 1
for i = 1, 2 do
  ni.p[i] = { tr = i, L = 100, D = 150, f = 0.02, ks = 0, K = 0,
              str = 1, sL = 1, sD = 1, sf = 1, sks = 0, sK = 1 }
end
ni.bom, ni.bdato, ni.bHB, ni.sbHB = 1, 1, 10, 1
rt.start(function() Net.scr_net() end)
mock.paint(); mock.click(math.floor(4.5 * mock.W / 5), mock.H - 5)
local qg = num("Q total")
local net = H.new_net()
H.hydro_net_init(net)
local a = H.hydro_net_add_pipe(net, 100, 0.15, 0.02, 0, 0)
local c2 = H.hydro_net_add_pipe(net, 100, 0.15, 0.02, 0, 0)
H.hydro_net_add_group(net, H.NODE_SERIES, { a, c2 }, 2)
H.hydro_net_solve(net, 30, H.new_cfg())
check(not rt.fatal and qg and rel(qg, 1000 * net.node[net.root].Q) < 1e-4,
  "G con HB = 10: Q total = red con H = 30 (" .. tostring(qg) .. ")")
ni.bdato, ni.bP, ni.bEta, ni.sbP, ni.sbEta = 0, 5, 0.8, 1, 1
rt.start(function() Net.scr_net() end)
mock.paint(); mock.click(math.floor(4.5 * mock.W / 5), mock.H - 5)
qg, hb = num("Q total"), num("HB bomba")
H.hydro_net_solve(net, 20 + hb, H.new_cfg())
check(qg and rel(qg, 1000 * net.node[net.root].Q) < 1e-6 and
  math.abs(hb - 0.8 * 5000 / (9810 * qg / 1000)) < 1e-6, "G con bomba P: HB = eta P/(gamma Q) consistente")

-- ------------------------------------------------------------ redondeo a mano
-- Con Ajustes > "Redondeo a mano" = Si el motor reproduce tuberias_2.lua exacto.
local hs = U.g_set.h
hs.r3 = 1
local c = {}
for k, v in pairs(hs) do c[k] = v end
c.nu = 1e-6
local function P() return H.new_pipe(0.2, 500, 0.05e-3, 5, 0) end
local s = {}
H.hydro_pipe_state(P(), 0.06, c, s)
check(s.hT == 8.478 and s.f == 0.01624 and s.Re == 382000, "r3 A: hT 8.478, f 0.01624 (JV)")
check(H.hydro_pressure_head(40, 0, s.v, s.hT, c, 0) == 31.336, "r3 A: p/gamma 31.336 (JV)")
local rr = {}
H.hydro_qmax_o(P(), 30, c, { solver = 0 }, rr, H.new_log())
check(math.abs(1000 * rr.st.Q - 115.406) < 1e-9 and rr.iters == 6, "r3 B: Q 115.406, 6 vueltas (JV)")
rr = {}
H.hydro_pump(P(), 0.06, 25, 0.8, c, rr)
check(rr.Hm == 33.478 and rr.Pb == 24631.439, "r3 C: HB 33.478, Pb 24631.439 (JV)")
rr = {}
H.hydro_calibrate(0.2, 500, 0.06, 5, 30, 0, c, rr)
check(rr.ks == 0.007394 and rr.f == 0.06254, "r3 E: ks 7.394E-3, f 6.254E-2 (JV)")
local t = {}
H.hydro_fric_all(1e5, 1e-4, c, t, nil)
check(math.abs(t.f[0] - 0.01852) < 1e-12 and t.iters == 6, "r3 f: 1.852E-2, 6 vueltas (JV) " .. t.f[0] .. " " .. t.iters)
local n = H.new_net()
H.hydro_net_init(n)
local a1 = H.hydro_net_add_pipe(n, 100, 0.15, 0, 0.05e-3, 0)
local b1 = H.hydro_net_add_pipe(n, 200, 0.10, 0, 0.05e-3, 2)
local b2 = H.hydro_net_add_pipe(n, 150, 0.12, 0.02, 0, 0)
local par = H.hydro_net_add_group(n, H.NODE_PARALLEL, { b1, b2 }, 2)
H.hydro_net_add_group(n, H.NODE_SERIES, { a1, par }, 2)
check(H.hydro_net_solve(n, 20, c) == 0 and math.abs(1000 * n.node[n.root].Q - 58.2) < 1e-9,
  "r3 G: Q 58.2 l/s (JV)")
-- pantalla con redondeo: formato de 3 decimales
Pipe.pin_reset()
pin.H, pin.D, pin.L, pin.ks, pin.K, pin.nu = 30, 200, 500, 0.05, 5, 1e-6
pin.sH, pin.sD, pin.sL, pin.sks, pin.sK, pin.snu = 1, 1, 1, 1, 1, 1
run_pipe(1)
check(not rt.fatal and view():find("115.406 l/s", 1, true) and view():find("E-2", 1, true),
  "r3 pantalla B: Q = 115.406 l/s y f en cientifica con 3 decimales")
hs.r3 = 0

print(string.format("test_jv: %d comprobaciones, %d fallo(s)", checks, fails))
if fails > 0 then os.exit(1) end
print("test_jv OK")
