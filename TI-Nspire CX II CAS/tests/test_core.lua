-- test_core.lua - Pruebas del nucleo numerico (puerto de golden.c, golden_v2.c,
-- random_check.c, random_check2.c, secant_check.c y test_ui_pure.c de la app TI-84).
-- Ejecutar desde la raiz del repo (tools/run_tests.sh). Los datos salen de
-- tests/data/*.lua (tools/export_golden.py). Falla si hay cualquier diferencia.

-- ---------------------------------------------------------------- carga
local env_require
do
    local ok, mock = pcall(dofile, "tests/mock_nspire.lua")
    local loaded = false
    if ok then
        local ok2, env = pcall(mock.load_app, "build/app.lua")
        if ok2 and env and env.require then
            env_require = env.require
            loaded = true
        end
    end
    if not loaded then
        -- build/app.lua no arranca (p. ej. main.lua en obras): usar los fuentes
        print("AVISO: no se pudo cargar build/app.lua; se usan los fuentes con require nativo")
        env_require = require
    end
end

local H = env_require("core.hydro")
local Dr = env_require("core.drag")
local Wr = env_require("core.weir")
local Ch = env_require("core.chan")
local X = env_require("ui.expr")
local N = env_require("ui.numfmt")
local DI = env_require("data.diams")
local LIB = env_require("data.lib")
local EXD = env_require("data.examples")
local DC = env_require("data.dragcat")

local abs, floor, sqrt = math.abs, math.floor, math.sqrt
local fmt = string.format
local FM_CW, FM_SJ, FM_HAALAND, FM_GOUDAR = H.FM_CW, H.FM_SJ, H.FM_HAALAND, H.FM_GOUDAR
local warn_has = H.warn_has
local PI = 3.14159265358979

local total_fail = 0
local function fail(msg)
    total_fail = total_fail + 1
    print("  FALLA " .. msg)
end
local function b(x) return x and 1 or 0 end

-- ------------------------------------------------------- 0. codigo sandbox
do
    local forbidden = { "io%.", "os%.", "loadstring", "dofile", "loadfile", "goto ",
        "table%.unpack", "utf8", "setfenv", "getfenv", "%f[%w_]load%(", "%f[%w_]require%(\"tests" }
    local files = { "src/core/hydro.lua", "src/core/drag.lua", "src/core/weir.lua",
        "src/core/chan.lua", "src/ui/expr.lua", "src/ui/numfmt.lua", "src/data/diams.lua",
        "src/data/lib.lua", "src/data/examples.lua", "src/data/dragcat.lua" }
    local nbad = 0
    for _, f in ipairs(files) do
        local fh = io.open(f, "rb")
        if not fh then
            fail("no se puede leer " .. f)
        else
            local src = fh:read("*a")
            fh:close()
            -- quitar comentarios largos y de linea
            src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
            for _, pat in ipairs(forbidden) do
                if src:find(pat) then
                    nbad = nbad + 1
                    fail(f .. ": uso prohibido en el sandbox: " .. pat)
                end
            end
        end
    end
    print(fmt("sandbox: %d archivos revisados, %d usos prohibidos", #files, nbad))
end

-- ============================================================ 1. GOLDEN
local golden = dofile("tests/data/golden_table.lua")
local C = {}
local cur_id
local out = {}
local n_pass, n_pass_r, n_fail, n_missing, n_ref_bad = 0, 0, 0, 0, 0
local seen = {}

local function put(name, v)
    if v == true then v = 1 elseif v == false then v = 0 end
    out[#out + 1] = { name = name, v = v }
end

local function begin(id)
    cur_id = id
    out = {}
end

local function end_()
    for i, g in ipairs(golden) do
        if g.id == cur_id then
            local found
            for j = 1, #out do
                if out[j].name == g.name then found = j end
            end
            seen[i] = true
            if not found then
                print(fmt("  FALTA %s | %s", g.id, g.name))
                n_missing = n_missing + 1
            else
                local got = out[found].v
                local err = abs(got - g.expected)
                local tol = g.tol_rel * abs(g.expected)
                if g.tol_abs > tol then tol = g.tol_abs end
                local tol_r = 0.5 * 10 ^ (-g.dec)
                if g.tol_rel == 0 and g.tol_abs == 0 then
                    tol = 0.5
                    tol_r = 0
                end
                if err <= tol then
                    n_pass = n_pass + 1
                elseif err <= tol_r then
                    n_pass_r = n_pass_r + 1
                else
                    n_fail = n_fail + 1
                    print(fmt("  FALLA %s | %s | esperado %.10g obtenido %.7g", g.id, g.name,
                        g.expected, got))
                end
                -- contra el C (double): mismo algoritmo, debe coincidir casi exacto
                if g.ref then
                    local d = abs(got - g.ref)
                    if not (d <= 1e-9 * abs(g.ref) + 1e-12) then
                        n_ref_bad = n_ref_bad + 1
                        print(fmt("  DIFIERE DEL C %s | %s | C %.17g Lua %.17g", g.id, g.name,
                            g.ref, got))
                    end
                end
            end
        end
    end
end

local function cfg(nu, m)
    H.hydro_cfg_default(C)
    C.nu = nu
    C.method = m
end

local function P(D, L, ks, K, f) return H.new_pipe(D, L, ks, K, f) end

local pstate, qmax, qmax_o = H.hydro_pipe_state, H.hydro_qmax, H.hydro_qmax_o
local hwhf, hwq = H.hydro_hw_hf, H.hydro_hw_q

local function case_P01_P02()
    local p = P(0.2, 1000, 0.0015e-3, 0, 0)
    local s, sc = {}, {}
    begin("P-01")
    cfg(1.007e-6, FM_SJ)
    pstate(p, 0.072, C, s)
    cfg(1.007e-6, FM_CW)
    pstate(p, 0.072, C, sc)
    local hw = hwhf(0.072, p.D, p.L, 150)
    put("v [m/s]", s.v)
    put("Re", s.Re)
    put("f SJ", s.f)
    put("f CW", sc.f)
    put("hf SJ [m]", s.hf)
    put("hf CW [m]", sc.hf)
    put("hf HW [m]", hw)
    put("error HW vs SJ [%]", 100.0 * (hw - s.hf) / s.hf)
    put("error HW vs CW [%]", 100.0 * (hw - sc.hf) / sc.hf)
    end_()

    begin("P-02")
    p.sumK = 6.7
    cfg(1.007e-6, FM_SJ)
    pstate(p, 0.072, C, s)
    put("hm [m]", s.hm)
    put("hT SJ [m]", s.hT)
    put("p/gamma [m]", (H.hydro_pressure_head(53, 0, s.v, s.hT, C, nil)))
    put("p/gamma sin hm [m]", (H.hydro_pressure_head(53, 0, s.v, s.hf, C, nil)))
    end_()
end

local function qmax_case(id, D, L, ks, K, Hh, nu)
    local p = P(D, L, ks, K, 0)
    local r, lg = {}, H.new_log()
    begin(id)
    cfg(nu, FM_CW)
    local e = qmax(p, Hh, C, r, lg)
    put("error", e)
    put("Q [l/s]", 1000.0 * r.st.Q)
    put("v [m/s]", r.st.v)
    put("f", r.st.f)
    put("hf [m]", r.st.hf)
    put("hm [m]", r.st.hm)
    put("metodo (1 curso)", r.solver)
    put("metodo (2 biseccion)", r.solver)
    put("iteraciones", r.iters)
    put("aviso de respaldo", b(warn_has(r.st.warn, H.W_FALLBACK)))
    end_()
end

local function case_B()
    qmax_case("P-03", 0.293, 700, 1.5e-6, 11.5, 43.5, 1e-6)
    qmax_case("P-04", 0.391, 4250, 2.0e-6, 8, 125, 1e-6)
    qmax_case("P-05", 1.050, 23778, 4.6e-5, 7, 80, 1e-6)
    qmax_case("P-06", 0.050, 2, 0.045e-3, 0.7, 5, 1.007e-6)
    qmax_case("P-07", 0.050, 2.06, 0.045e-3, 10.8, 5, 1.007e-6)
    qmax_case("P-08", 0.200, 1500, 0.0015e-3, 21.4, 100, 1e-6)
    qmax_case("P-09", 0.300, 4500, 0.045e-3, 5, 100, 1e-6)
    qmax_case("R-01", 0.050, 2.06, 0.045e-3, 10.8, 5, 1.007e-6)

    begin("P-10")
    local p = P(0.3, 4500, 0.045e-3, 5, 0)
    local r9 = {}
    cfg(1e-6, FM_CW)
    qmax(p, 100, C, r9, nil)
    local qhw = hwq(100, p.D, p.L, 130)
    put("Q HW [l/s]", 1000.0 * qhw)
    put("diferencia [%]", 100.0 * (qhw - r9.st.Q) / r9.st.Q)
    end_()
end

local function case_C()
    local m = {}
    begin("P-11")
    local p = P(0.150, 970, 1.5e-6, 9.4, 0)
    cfg(1.14e-6, FM_CW)
    C.gamma = 999.1 * 9.81
    put("error", H.hydro_pump(p, 0.042, 16, 0.65, C, m))
    put("v [m/s]", m.st.v)
    put("Re", m.st.Re)
    put("f", m.st.f)
    put("hf [m]", m.st.hf)
    put("hm [m]", m.st.hm)
    put("H [m]", m.Hm)
    put("P [kW]", m.Pb / 1000.0)
    put("P [Hp]", m.Pb / 745.7)
    end_()

    begin("P-12")
    p = P(0.200, 1000, 0, 0, 0.014)
    cfg(1e-6, FM_CW)
    put("error", H.hydro_pump(p, 0.075, 102, 0.85, C, m))
    put("v [m/s]", m.st.v)
    put("hf [m]", m.st.hf)
    put("HB [m]", m.Hm)
    put("Pn [kW]", m.Pn / 1000.0)
    put("Pb [kW]", m.Pb / 1000.0)
    end_()

    begin("P-13")
    p = P(0.040, 800, 0.045e-3, 0, 0)
    cfg(1.007e-6, FM_CW)
    put("error", H.hydro_pump(p, 0.010, 70, 0.85, C, m))
    put("v [m/s]", m.st.v)
    put("Re", m.st.Re)
    put("f CW", m.st.f)
    put("hf [m]", m.st.hf)
    put("HB [m]", m.Hm)
    put("Pn [kW]", m.Pn / 1000.0)
    put("Pb [kW]", m.Pb / 1000.0)
    end_()

    begin("P-14")
    p = P(0.150, 1300, 0.0015e-3, 5, 0)
    cfg(1e-6, FM_CW)
    put("error", H.hydro_pump(p, 0.025, 40, 0.60, C, m))
    put("v [m/s]", m.st.v)
    put("Re", m.st.Re)
    put("f", m.st.f)
    put("hf [m]", m.st.hf)
    put("hm [m]", m.st.hm)
    put("HB [m]", m.Hm)
    put("Pn [kW]", m.Pn / 1000.0)
    put("Pb [kW]", m.Pb / 1000.0)
    end_()
end

local L_150_400 = { 0.150, 0.200, 0.250, 0.300, 0.350, 0.400 }
local L_PVC25 = { 0.05321, 0.06445, 0.07844, 0.10084, 0.14846, 0.19328,
                  0.24095, 0.28575, 0.35864 }
local L_200_500 = { 0.200, 0.250, 0.300, 0.350, 0.400, 0.450, 0.500 }
local L_P22 = { 0.100, 0.150, 0.200, 0.250, 0.300 }

local function design_basic(id, Qd, L, Hh, ks, K, nu, list, n)
    local p = P(0, L, ks, K, 0)
    local r, lg = {}, H.new_log()
    begin(id)
    cfg(nu, FM_CW)
    put("error", H.hydro_design(p, Qd, Hh, list, n, C, r, lg))
    put("D exacto [mm]", 1000.0 * r.D_exact)
    put("D comercial [mm]", 1000.0 * r.D_com)
    put("Qmax [l/s]", 1000.0 * r.qmax.st.Q)
    put("hm/hf [%]", 100.0 * r.qmax.st.hm / r.qmax.st.hf)
    put("hm/hf D exacto Qd [%]", 100.0 * r.st_exact.hm / r.st_exact.hf)
    put("hm/hf D com Qd [%]", 100.0 * r.st_com_qd.hm / r.st_com_qd.hf)
    put("iteraciones", r.iters)
    put("vp [m/s]", r.vp)
    end_()
end

local function case_D()
    local r, rs, q, vr, m, s = {}, {}, {}, {}, {}, {}

    design_basic("P-15", 0.200, 450, 8, 0.25e-3, 2.5, 1.17e-6, L_150_400, 6)
    design_basic("P-16a", 0.300, 1250, 16, 0.046e-3, 2.5, 1.17e-6, L_150_400, 6)
    design_basic("P-16b", 0.300, 1250, 16, 0.0015e-3, 2.5, 1.17e-6, L_150_400, 6)

    begin("P-17")
    local p = P(0, 1900, 0.0015e-3, 12.8, 0)
    cfg(1e-6, FM_CW)
    put("error", H.hydro_design(p, 0.2, 76, L_PVC25, 9, C, r, nil))
    cfg(1e-6, FM_SJ)
    H.hydro_design(p, 0.2, 76, L_PVC25, 9, C, rs, nil)
    put("D exacto CW [mm]", 1000.0 * r.D_exact)
    put("D exacto SJ [mm]", 1000.0 * rs.D_exact)
    put("D comercial [mm]", 1000.0 * r.D_com)
    put("Qmax 285.75 [l/s]", 1000.0 * r.qmax.st.Q)
    cfg(1e-6, FM_CW)
    p.D = 0.285
    qmax(p, 76, C, q, nil)
    put("Qmax 285.00 [l/s]", 1000.0 * q.st.Q)
    put("v 285.00 [m/s]", q.st.v)
    put("hf 285.00 [m]", q.st.hf)
    put("hm 285.00 [m]", q.st.hm)
    end_()

    begin("P-18")
    p = P(0.28575, 1900, 0.0015e-3, 12.8, 0)
    cfg(1e-6, FM_SJ)
    pstate(p, 0.2, C, s)
    put("f SJ", s.f)
    cfg(1e-6, FM_CW)
    put("error", H.hydro_valve(p, 0.2, 76, C, vr))
    put("v [m/s]", vr.st.v)
    put("Re", vr.st.Re)
    put("f CW", vr.st.f)
    put("hf [m]", vr.st.hf)
    put("hm [m]", vr.st.hm)
    put("hT [m]", vr.st.hT)
    put("hv [m]", vr.hv)
    put("Kv", vr.Kv)
    end_()

    begin("P-19")
    put("error", H.hydro_turbine(p, 0.2, 76, 0.65, C, m))
    put("HT [m]", m.Hm)
    put("Pb [kW]", m.Pb / 1000.0)
    put("Pn [kW]", m.Pn / 1000.0)
    end_()

    begin("P-20")
    put("error", H.hydro_pump(p, 0.2, 76, 0.60, C, m))
    put("HB [m]", m.Hm)
    put("Pn [kW]", m.Pn / 1000.0)
    put("Pb [kW]", m.Pb / 1000.0)
    put("cota piezometrica [m]", 1015.0 + m.Hm)
    end_()

    begin("P-21")
    p = P(0, 600, 0.0015e-3, 5, 0)
    cfg(1.02e-6, FM_CW)
    put("error", H.hydro_design(p, 0.4, 8, L_200_500, 7, C, r, nil))
    cfg(1.02e-6, FM_SJ)
    H.hydro_design(p, 0.4, 8, L_200_500, 7, C, rs, nil)
    put("D exacto CW [mm]", 1000.0 * r.D_exact)
    put("D exacto SJ [mm]", 1000.0 * rs.D_exact)
    put("D comercial [mm]", 1000.0 * r.D_com)
    put("Qmax [l/s]", 1000.0 * r.qmax.st.Q)
    put("hf [m]", r.qmax.st.hf)
    put("hm [m]", r.qmax.st.hm)
    end_()

    begin("P-22")
    cfg(1.007e-6, FM_CW)
    local HB = H.hydro_head_from_power(15000, 0.75, 0.03, C)
    local Hd = HB - 30.0
    p = P(0, 800, 0.15e-3, 2.8, 0)
    put("HB [m]", HB)
    put("hT disponible [m]", Hd)
    put("error", H.hydro_design(p, 0.03, Hd, L_P22, 5, C, r, nil))
    put("D exacto [mm]", 1000.0 * r.D_exact)
    put("D comercial [mm]", 1000.0 * r.D_com)
    put("Qmax 200 [l/s]", 1000.0 * r.qmax.st.Q)
    put("hf 200 [m]", r.qmax.st.hf)
    put("hm 200 [m]", r.qmax.st.hm)
    p.D = 0.150
    qmax(p, Hd, C, q, nil)
    put("Qmax 150 [l/s]", 1000.0 * q.st.Q)
    end_()
end

local function case_E()
    local fr, c = {}, {}
    cfg(1e-6, FM_CW)
    begin("P-24a")
    H.hydro_friction(20000, 1e-4, FM_CW, C, fr)
    put("f CW", fr.f)
    put("iteraciones", fr.iters)
    end_()
    begin("P-24b")
    H.hydro_friction(200000, 1.5e-4, FM_CW, C, fr)
    put("f CW", fr.f)
    put("iteraciones", fr.iters)
    end_()

    begin("P-25")
    cfg(1.17e-6, FM_CW)
    put("error", H.hydro_calibrate(0.274, 405, 0.172, 3.5, 1135 - 1070, 36 - 84, C, c))
    put("hf+hm [m]", c.htot)
    put("v [m/s]", c.v)
    put("hm [m]", c.hm)
    put("hf [m]", c.hf)
    put("f", c.f)
    put("ks [mm]", 1000.0 * c.ks)
    put("Re", c.Re)
    end_()
end

local function new_n()
    local n = H.new_net()
    H.hydro_net_init(n)
    return n
end

local function case_S()
    local NP, NS = H.NODE_PARALLEL, H.NODE_SERIES
    local add_pipe, add_group = H.hydro_net_add_pipe, H.hydro_net_add_group
    local n, a, bb, cc, d, par, e

    -- S-01: Serie[A, Paralelo[B, C, D]]
    begin("S-01")
    cfg(1e-6, FM_CW)
    n = new_n()
    a = add_pipe(n, 100, 0.15, 0.020, 0, 0)
    bb = add_pipe(n, 100, 0.10, 0.015, 0, 5)
    cc = add_pipe(n, 100, 0.10, 0.015, 0, 5)
    d = add_pipe(n, 100, 0.10, 0.015, 0, 5)
    par = add_group(n, NP, { bb, cc, d }, 3)
    add_group(n, NS, { a, par }, 2)
    put("error", H.hydro_net_solve(n, 20, C))
    put("M_A", n.node[a].M)
    put("M_B", n.node[bb].M)
    put("M_B friccion", n.node[bb].Mf)
    put("M_B local", n.node[bb].Mk)
    put("M_BCD", n.node[par].M)
    put("M total", n.node[n.root].M)
    put("Q [l/s]", 1000.0 * n.node[n.root].Q)
    put("h_A [m]", n.node[a].h)
    put("h_B [m]", n.node[bb].h)
    put("Q_B [l/s]", 1000.0 * n.node[bb].Q)
    put("residuo Q", n.res_q)
    put("residuo h", n.res_h)
    end_()

    -- S-02: Serie[Paralelo[A, B], C]
    begin("S-02")
    n = new_n()
    a = add_pipe(n, 500, 0.15, 0.014, 0, 0)
    bb = add_pipe(n, 600, 0.10, 0.018, 0, 0)
    cc = add_pipe(n, 700, 0.20, 0.015, 0, 5)
    par = add_group(n, NP, { a, bb }, 2)
    add_group(n, NS, { par, cc }, 2)
    put("error", H.hydro_net_solve(n, 20, C))
    put("M_A", n.node[a].M)
    put("M_B", n.node[bb].M)
    put("M_C", n.node[cc].M)
    put("M_C friccion", n.node[cc].Mf)
    put("M_C local", n.node[cc].Mk)
    put("M_AB", n.node[par].M)
    put("M total", n.node[n.root].M)
    put("Q [l/s]", 1000.0 * n.node[n.root].Q)
    put("h_C [m]", n.node[cc].h)
    put("h_A [m]", n.node[a].h)
    put("Q_A [l/s]", 1000.0 * n.node[a].Q)
    put("Q_B [l/s]", 1000.0 * n.node[bb].Q)
    put("residuo Q", n.res_q)
    put("residuo h", n.res_h)
    end_()

    -- S-03: Serie[1, Paralelo[2, 3], 4]
    begin("S-03")
    n = new_n()
    a = add_pipe(n, 100, 0.10, 0.025, 0, 0)
    bb = add_pipe(n, 100, 0.10, 0.025, 0, 0)
    cc = add_pipe(n, 100, 0.20, 0.020, 0, 30)
    d = add_pipe(n, 100, 0.10, 0.025, 0, 0)
    par = add_group(n, NP, { bb, cc }, 2)
    add_group(n, NS, { a, par, d }, 3)
    put("error", H.hydro_net_solve(n, 24, C))
    put("M_1", n.node[a].M)
    put("M_3", n.node[cc].M)
    put("M_3 friccion", n.node[cc].Mf)
    put("M_3 local", n.node[cc].Mk)
    put("M_23", n.node[par].M)
    put("Q [l/s]", 1000.0 * n.node[n.root].Q)
    put("h_1 [m]", n.node[a].h)
    put("h_23 [m]", n.node[par].h)
    put("Q_3 [l/s]", 1000.0 * n.node[cc].Q)
    put("Q_2 [l/s]", 1000.0 * n.node[bb].Q)
    put("h_4 [m]", n.node[d].h)
    end_()

    -- S-04: Serie[1, Paralelo[2, 3, 4]], hacia atras con Q4 = 40 l/s
    begin("S-04")
    n = new_n()
    a = add_pipe(n, 400, 0.20, 0.020, 0, 0)
    bb = add_pipe(n, 180, 0.10, 0.025, 0, 0)
    cc = add_pipe(n, 50, 0.10, 0.025, 0, 0)
    d = add_pipe(n, 400, 0.20, 0.020, 0, 0)
    par = add_group(n, NP, { bb, cc, d }, 3)
    add_group(n, NS, { a, par }, 2)
    local Hh = 0
    e, Hh = H.hydro_net_solve_back(n, d, 0.040, C)
    Hh = Hh or 0
    put("error", e)
    put("M_1", n.node[a].M)
    put("M_2", n.node[bb].M)
    put("M_3", n.node[cc].M)
    put("M_234", n.node[par].M)
    put("h_4 [m]", n.node[d].h)
    put("Q_2 [l/s]", 1000.0 * n.node[bb].Q)
    put("Q_3 [l/s]", 1000.0 * n.node[cc].Q)
    put("Q_1 [l/s]", 1000.0 * n.node[a].Q)
    put("h_1 [m]", n.node[a].h)
    put("carga total [m]", Hh)
    put("p tanque A [kPa]", Hh * C.gamma / 1000.0)
    put("Q_4 [l/s]", 1000.0 * n.node[d].Q)
    end_()

    -- S-05: Serie[A, Paralelo[B, C], D]
    begin("S-05")
    n = new_n()
    a = add_pipe(n, 700, 0.30, 0.014, 0, 5)
    bb = add_pipe(n, 600, 0.15, 0.020, 0, 0)
    cc = add_pipe(n, 500, 0.20, 0.011, 0, 0)
    d = add_pipe(n, 600, 0.25, 0.028, 0, 3)
    par = add_group(n, NP, { bb, cc }, 2)
    add_group(n, NS, { a, par, d }, 3)
    put("error", H.hydro_net_solve(n, 75, C))
    put("M_A", n.node[a].M)
    put("M_B", n.node[bb].M)
    put("M_C", n.node[cc].M)
    put("M_D", n.node[d].M)
    put("M_BC", n.node[par].M)
    put("M total", n.node[n.root].M)
    put("Q [l/s]", 1000.0 * n.node[n.root].Q)
    put("h_A [m]", n.node[a].h)
    put("h_BC [m]", n.node[par].h)
    put("h_D [m]", n.node[d].h)
    put("Q_B [l/s]", 1000.0 * n.node[bb].Q)
    put("Q_C [l/s]", 1000.0 * n.node[cc].Q)
    end_()
end

local function case_R()
    local s, q, dr = {}, {}, {}

    begin("R-02")
    cfg(1e-6, FM_CW)
    local p = P(0.020, 50, 0.0015e-3, 0, 0)
    pstate(p, 2e-5, C, s)
    local hp = 128.0 * 1e-6 * 50 * 2e-5 / (9.81 * 3.14159265358979 * 0.02 ^ 4)
    put("Re", s.Re)
    put("aviso laminar", b(warn_has(s.warn, H.W_LAMINAR)))
    put("f*Re", s.f * s.Re)
    put("hf / Hagen-Poiseuille", s.hf / hp)
    qmax(p, s.hT, C, q, nil)
    put("Q de vuelta [l/s]", 1000.0 * q.st.Q)
    end_()

    begin("R-03")
    p = P(0.050, 100, 0.0015e-3, 0, 0)
    pstate(p, 3000 * 1e-6 / 0.05 * 3.14159265358979 * 0.05 * 0.05 / 4, C, s)
    put("Re", s.Re)
    put("aviso transicion", b(warn_has(s.warn, H.W_TRANSITION)))
    put("f indicativo", s.f)
    end_()

    begin("R-04")
    p = P(0, 100, 0, 0, 0)
    put("error D=0", pstate(p, 1, C, s))
    put("error Qmax D=0", qmax(p, 10, C, q, nil))
    p = P(0.1, -5, 0, 0, 0)
    put("error L<0", pstate(p, 1, C, s))
    put("error diseno L<0", H.hydro_design(p, 1, 10, nil, 0, C, dr, nil))
    p = P(0.1, 100, 0, 0, 0)
    put("error Q=0", pstate(p, 0, C, s))
    p = P(0.1, 100, 0, -1, 0)
    put("error K<0", pstate(p, 1, C, s))
    p = P(0.1, 100, 0, 0, 0)
    C.nu = 0
    put("error nu=0", pstate(p, 1, C, s))
    end_()

    begin("R-05")
    cfg(1e-6, FM_CW)
    p = P(0.1, 100, 0.0015e-3, 2, 0)
    put("error H<0", qmax(p, -5, C, q, nil))
    put("error H=0", qmax(p, 0, C, q, nil))
    local n = new_n()
    H.hydro_net_add_pipe(n, 100, 0.1, 0.02, 0, 0)
    put("error red H=0", H.hydro_net_solve(n, 0, C))
    end_()
end

-- v2.1: arranque de Hazen-Williams y secante (tipos D y B)
local SEC_TOL = 1e-6
local function relx(x, y) return abs(x - y) / abs(y) end

local function qmax_hw(id, D)
    local p = P(D, 500, 0.0015e-3, 5, 0)
    local o = { CH = 150, solver = H.IT_SECANT }
    local oc = { CH = 150, solver = H.IT_DEFAULT }
    local r, rc, rh = {}, {}, {}
    begin(id)
    cfg(1e-6, FM_CW)
    put("error", qmax_o(p, 8, C, o, r, nil))
    qmax(p, 8, C, rc, nil)
    qmax_o(p, 8, C, oc, rh, nil)
    put("Q [l/s]", 1000.0 * r.st.Q)
    put("metodo (3 secante)", r.solver)
    put("arranque HW", r.hw)
    put("hf1 HW [m]", r.hf1)
    put("Q HW [l/s]", 1000.0 * r.Q0)
    put("vueltas secante", r.iters)
    put("vueltas <= 6", r.iters <= 6)
    put("vueltas curso desde H", rc.iters)
    put("vueltas curso desde HW", rh.iters)
    put("dif secante-curso ok", relx(r.st.Q, rc.st.Q) <= SEC_TOL)
    end_()
end

local function case_HW()
    local p = P(0, 500, 0.0015e-3, 5, 0)
    local o = { CH = 150, solver = H.IT_SECANT }
    local bad = { CH = 1, solver = H.IT_SECANT }
    local r, rb, rs, q, qb = {}, {}, {}, {}, {}

    begin("P-26")
    cfg(1e-6, FM_CW)
    put("error", H.hydro_design_o(p, 0.305, 8, nil, 0, C, o, r, nil))
    H.hydro_design(p, 0.305, 8, nil, 0, C, rb, nil)
    put("D exacto CW [mm]", 1000.0 * r.D_exact)
    put("f", r.st_exact.f)
    put("v [m/s]", r.st_exact.v)
    put("D0 HW con SumK [mm]", 1000.0 * r.D0)
    put("D0 HW sin SumK [mm]", 1000.0 * (10.675 * 500 * 0.305 ^ 1.852 /
        (150 ^ 1.852 * 8)) ^ (1 / 4.87))
    put("metodo (3 secante)", r.solver)
    put("arranque HW", r.hw)
    put("vueltas secante", r.iters)
    put("vueltas <= 6", r.iters <= 6)
    put("vueltas biseccion", rb.iters)
    put("dif secante-biseccion ok", relx(r.D_exact, rb.D_exact) <= SEC_TOL)
    cfg(1e-6, FM_SJ)
    H.hydro_design_o(p, 0.305, 8, nil, 0, C, o, rs, nil)
    put("D exacto SJ [mm]", 1000.0 * rs.D_exact)
    end_()

    qmax_hw("P-27", 0.400)
    qmax_hw("P-27b", 0.375)

    -- Arranques malos: el respaldo entra y el resultado no cambia
    begin("P-26m")
    cfg(1e-6, FM_CW)
    H.hydro_design_o(p, 0.305, 8, nil, 0, C, bad, r, nil)
    put("respaldo C_H=1 (info)", r.fb)
    put("vueltas C_H=1 (info)", r.iters)
    put("dif C_H=1 ok", relx(r.D_exact, rb.D_exact) <= SEC_TOL)
    p.sumK = 300
    H.hydro_design(p, 0.305, 8, nil, 0, C, rb, nil)
    H.hydro_design_o(p, 0.305, 8, nil, 0, C, o, r, nil)
    put("dif SumK=300 ok", relx(r.D_exact, rb.D_exact) <= SEC_TOL)
    put("D SumK=300 [mm]", 1000.0 * r.D_exact)
    put("vueltas SumK=300", r.iters)
    p = P(0.4, 500, 0.0015e-3, 5, 0)
    cfg(1e-2, FM_CW)
    qmax(p, 8, C, qb, nil)
    qmax_o(p, 8, C, o, q, nil)
    put("B laminar: biseccion", q.solver == H.SOLV_BISECTION)
    put("B laminar: dif ok", relx(q.st.Q, qb.st.Q) <= SEC_TOL)
    end_()
end

-- ------------------------------------------------------------- golden_v2
local ld_x = { 1, 2, 5, 10, 40 }
local ld_y = { 0.6, 0.7, 0.8, 0.9, 1.0 }
local DK_GENERIC, DK_SPHERE, DK_LONGCYL = Dr.DK_GENERIC, Dr.DK_SPHERE, Dr.DK_LONGCYL
local DW_CRISIS, DW_STOKES, DW_CLAMP = Dr.DW_CRISIS, Dr.DW_STOKES, Dr.DW_CLAMP

local function tower(cdc, cds)
    local bd = {}
    local r = {}
    local V = 100.0 / 3.6
    bd[1] = { Cd = cdc, A = 60, y = 15, V = V, Lref = 2, kind = DK_LONGCYL }
    bd[2] = { Cd = cds, A = H.hydro_area(12), y = 36, V = V, Lref = 12, kind = DK_SPHERE }
    Dr.drag_struct(bd, 2, 1.2, 1.5e-5, r)
    put("q [Pa]", Dr.drag_q(1.2, V))
    put("F1 [kN]", r.F[1] / 1000)
    put("F2 [kN]", r.F[2] / 1000)
    put("M [kN m]", r.M / 1000)
    put("ycp [m]", r.ycp)
    put("aviso crisis esf", b(warn_has(r.w[2], DW_CRISIS)))
end

local function term(t, W, rho, vol, cd, A, L, nu)
    return Dr.drag_terminal(W, rho, vol, cd, A, L, nu, 9.81, DK_GENERIC, t)
end

local function case_AR()
    local t, pl, pp = {}, {}, {}
    local w = 0
    local A = H.hydro_area(8)
    local cd, rho, V, i0

    begin("AR-01")
    term(t, 950, 1.2, 0, 1.3, A, 8, 1.5e-5)
    put("vt CD=1.3 [m/s]", t.v)
    put("Re", t.Re)
    term(t, 950, 1.2, 0, 1.42, A, 8, 1.5e-5)
    put("vt CD=1.42 [m/s]", t.v)
    end_()

    begin("AR-02a")
    cd, i0, w = Dr.drag_interp(ld_x, ld_y, 5, 15, w)
    put("CD cil interp", cd)
    tower(cd, 0.5)
    end_()
    begin("AR-02b")
    tower(1.2, 0.5)
    end_()
    begin("AR-02c")
    tower(0.3, 0.2)
    end_()

    begin("AR-03a")
    term(t, 19.8, 1000, 1e-3, 0.8, 0.01, 0.1, 1e-6)
    put("B [N]", t.B)
    put("vt [m/s]", t.v)
    end_()
    begin("AR-03b")
    term(t, 19.8, 1000, 1e-3, 0.8, 0.01 * 1.41421356, 0.1, 1e-6)
    put("vt [m/s]", t.v)
    end_()
    begin("AR-03c")
    term(t, 19.8, 1000, 1e-3, 1.05, 0.01, 0.1, 1e-6)
    put("vt [m/s]", t.v)
    end_()

    begin("AR-04")
    rho = Dr.drag_rho_alt(10675)
    V = 480 * 1.85 / 3.6
    put("rho [kg/m3]", rho)
    Dr.drag_plane_lift(3.9e6, rho, V, 180.8, 2, pl)
    put("q [Pa]", pl.q)
    put("CL", pl.CL)
    Dr.drag_plane_thrust(3.9e6, rho, V, 0.0088, 1, 5.28, 0, pl)
    put("Afus [m2]", pl.Afus)
    put("Dfus [kN]", pl.Df / 1000)
    put("Dalas [kN]", pl.Dw / 1000)
    put("T [kN]", pl.T / 1000)
    end_()

    begin("AR-05")
    put("Re", Dr.drag_re(1e-3, 1e-3, 1e-6))
    put("FD Stokes [nN]", Dr.drag_stokes(1e-3, 1e-3, 1e-3) * 1e9)
    put("aviso Stokes", b(warn_has(Dr.drag_re_warn(0.999, DK_SPHERE), DW_STOKES)))
    end_()

    begin("AR-06")
    Dr.drag_plate(2, 1, 10, 1.2, 1.5e-5, 1, Dr.PL_TURB, pp)
    put("ReL", pp.Re)
    put("Cf turb", pp.Cf_turb)
    put("Cf mixto", pp.Cf_mix)
    put("FD turb [N]", pp.F)
    put("aviso laminar NA", b(warn_has(pp.warn, Dr.DW_LAM_NA)))
    Dr.drag_plate(2, 1, 10, 1.2, 1.5e-5, 1, Dr.PL_MIX, pp)
    put("FD mixto [N]", pp.F)
    end_()

    begin("AR-07")
    put("error flota", Dr.drag_terminal(5, 1000, 1e-3, 1, 0.01, 0.1, 1e-6, 9.81,
        DK_GENERIC, t))
    w = 0
    put("interp L/D=15", (Dr.drag_interp(ld_x, ld_y, 5, 15, w)))
    w = 0
    local _
    _, i0, w = Dr.drag_interp(ld_x, ld_y, 5, 80, w)
    put("interp clamp", (Dr.drag_interp(ld_x, ld_y, 5, 80, 0)))
    put("aviso clamp", b(warn_has(w, DW_CLAMP)))
    end_()
end

local function WE(type, a, z, n)
    return { type = type, count = n, ncon = 0, Cd = 0.6, z = z, a = a, b = 0 }
end

local function case_VE()
    local WE_TRI, WE_RECT, WE_ORC = Wr.WE_TRI, Wr.WE_RECT, Wr.WE_ORC
    local g = 9.81
    local e = {}
    local Q, Qi, h, vm, Qp
    local w = 0
    local err, it

    local function level(el, n, Qv)
        local er, hh, qi, ww, i = Wr.weir_level(el, n, Qv, g, w, nil)
        w = ww
        if hh then h = hh end
        if qi then Qi = qi end
        it = i
        return er
    end

    e[1] = WE(WE_TRI, 90, 1.4, 1)
    e[2] = WE(WE_ORC, 0.2, 0.1, 3)
    begin("VE-01")
    err, Q, Qi, w = Wr.weir_total(e, 2, 2, g, w)
    put("Q tri [m3/s]", Qi[1])
    put("Q orif c/u [m3/s]", Qi[2] / 3)
    put("Q total [m3/s]", Q)
    end_()
    begin("VE-02")
    level(e, 2, 0.5)
    put("h [m]", h)
    end_()

    e[1] = WE(WE_TRI, 90, 0, 1)
    begin("VE-03")
    level(e, 1, 0.2)
    put("H [m]", h)
    end_()
    begin("VE-04")
    level(e, 1, 0.26064)
    put("H [m]", h)
    end_()
    begin("VE-05")
    e[1] = WE(WE_TRI, 60, 0, 1)
    level(e, 1, 0.016)
    put("H [m]", h)
    end_()
    begin("VE-06")
    e[2] = WE(WE_RECT, 1.3, h, 1)
    level(e, 2, 0.036)
    put("h [m]", h)
    put("Q tri [l/s]", Qi[1] * 1000)
    put("Q rec [l/s]", Qi[2] * 1000)
    end_()

    begin("VE-07")
    err, Q, vm = Wr.weir_profile_pow(2, 2, 2, 1)
    put("Q [m3/s]", Q)
    put("v media [m/s]", vm)
    local yp = { 0, 0.25, 0.5, 0.75, 1 }
    local vp = {}
    for i = 1, 5 do vp[i] = 2 * yp[i] * yp[i] end
    local simp
    err, Qp, vm, simp = Wr.weir_profile_pts(yp, vp, 5, 2)
    put("Q puntos [m3/s]", Qp)
    end_()
    begin("VE-08")
    e[1] = WE(WE_TRI, 90, 0, 1)
    level(e, 1, Q)
    put("H [m]", h)
    put("h0 [m]", 1 - h)
    end_()

    begin("VE-10")
    do
        local v1, E1, hs, hp, hc
        err, v1, E1 = Wr.weir_section(4.0 / 3.0, 2, 1, g)
        put("v1 [m/s]", v1)
        put("E1 [m]", E1)
        err, hs, hp, hc = Wr.weir_alt_depths(2.0 / 3.0, E1, g)
        put("hc [m]", hc)
        put("h sub [m]", hs)
        put("h sup [m]", hp)
        put("error E<Emin", (Wr.weir_alt_depths(1, 0.1, g)))
    end
    end_()

    begin("VE-09")
    local s1 = WE(WE_TRI, 90, 0, 1)
    local s2 = { s1, WE(WE_RECT, 1, 100, 1) } -- nunca recibe agua
    local _, h1, h2
    _, h1 = Wr.weir_level({ s1 }, 1, 0.2, g, w, nil)
    _, h2 = Wr.weir_level(s2, 2, 0.2, g, w, nil)
    put("equivalencia 1 tri", abs(h1 - h2) < 1e-5 * h1)
    put("error Q=0", (Wr.weir_level({ s1 }, 1, 0, g, w, nil)))
    s1 = WE(WE_ORC, 0, 0, 1)
    put("error d=0", (Wr.weir_total({ s1 }, 1, 1, g, w)))
    s1 = WE(WE_ORC, 0.2, 1, 1)
    w = 0
    _, _, _, w = Wr.weir_total({ s1 }, 1, 1.05, g, w)
    put("aviso carga parcial", b(warn_has(w, Wr.VW_PARTIAL)))
    end_()
end

local function case_EX()
    local v, j, je, q = {}, {}, {}, {}
    local D1 = 0.28575
    local D2 = 0.6 * 0.28575
    local MP, ME = Ch.MANO_PHYS, Ch.MANO_EXAM

    cfg(1e-6, FM_CW)
    begin("EX-01a")
    Ch.chan_venturi(D1, D2, 0.2, 1, 4, ME, C, v)
    put("v1 [m/s]", v.v1)
    put("v2 [m/s]", v.v2)
    put("dp [Pa]", v.dp)
    put("h S [m]", v.h)
    Ch.chan_venturi(D1, D2, 0.2, 1, 4, MP, C, v)
    put("h S-1 [m]", v.h)
    end_()
    begin("EX-01b")
    Ch.chan_venturi(D1, D2, 0.26064, 1, 4, MP, C, v)
    put("dp [Pa]", v.dp)
    put("h S-1 [m]", v.h)
    Ch.chan_venturi(D1, D2, 0.26064, 1, 4, ME, C, v)
    put("h S [m]", v.h)
    end_()

    begin("EX-02")
    Ch.chan_jump(12, 2, 0.4, 0, C, j)
    put("q [m2/s]", j.q)
    put("v1 [m/s]", j.v1)
    put("Fr1", j.Fr1)
    put("y2 [m]", j.y2)
    put("v2 [m/s]", j.v2)
    put("E1 [m]", j.E1)
    put("E2 [m]", j.E2)
    put("dE [m]", j.dE)
    put("P [kW]", j.P / 1000)
    Ch.chan_jump(12, 2, j.y2, 1, C, j)
    put("y1 desde y2 [m]", j.y1)
    put("error sin salto", Ch.chan_jump(1, 2, 2, 0, C, j))
    end_()

    cfg(1.007e-6, FM_CW)
    local p = P(0.03, 5, 0.045e-3, 0, 0)
    begin("EX-03a")
    qmax(p, 7.5, C, q, nil)
    Ch.chan_jet(q.st.v, 30, C.g, je)
    put("Q [l/s]", q.st.Q * 1000)
    put("v [m/s]", q.st.v)
    put("Re", q.st.Re)
    put("f", q.st.f)
    put("hmax [m]", je.hmax)
    put("vx [m/s]", je.vx)
    put("R [m]", je.R)
    end_()
    p.sumK = 1
    begin("EX-03b")
    qmax(p, 7.5, C, q, nil)
    Ch.chan_jet(q.st.v, 30, C.g, je)
    put("Q [l/s]", q.st.Q * 1000)
    put("v [m/s]", q.st.v)
    put("hmax [m]", je.hmax)
    end_()
end

local function fcase(id, Re, ksd)
    local t = {}
    begin(id)
    H.hydro_fric_all(Re, ksd, C, t, nil)
    put("Re", Re)
    put("f CW", t.f[FM_CW])
    put("f SJ", t.f[FM_SJ])
    put("f Haaland", t.f[FM_HAALAND])
    put("f GS", t.f[FM_GOUDAR])
    put("dif SJ [%]", t.dpct[FM_SJ])
    end_()
end

local function case_F()
    local t, lg = {}, H.new_log()
    cfg(1e-6, FM_CW)
    fcase("F-01", 20000, 1e-4)
    fcase("F-02", 200000, 1.5e-4)
    local v = 0.2 / H.hydro_area(0.28575)
    fcase("F-03", v * 0.28575 / 1e-6, 0.0015 / 285.75)
    fcase("F-04", 455180, 7.5e-6)
    begin("F-05")
    local Re = 2e-5 / H.hydro_area(0.02) * 0.02 / 1e-6
    H.hydro_fric_all(Re, 0, C, t, lg)
    put("Re laminar", Re)
    put("f laminar", t.f[FM_CW])
    put("regimen laminar", t.regime)
    H.hydro_fric_all(3000, 1e-4, C, t, lg)
    put("regimen transicion", t.regime)
    put("log CW filas>2", lg.n > 2)
    put("error Re=0", H.hydro_fric_all(0, 0, C, t, lg))
    put("error ks/D<0", H.hydro_fric_all(100000, -1, C, t, lg))
    end_()
end

print("== Casos dorados ==")
case_P01_P02()
case_B()
case_C()
case_D()
case_E()
case_S()
case_R()
case_HW()
case_AR()
case_VE()
case_EX()
case_F()
local n_unseen = 0
for i, g in ipairs(golden) do
    if not seen[i] then
        n_unseen = n_unseen + 1
        print(fmt("  SIN EVALUAR %s | %s", g.id, g.name))
    end
end
print(fmt("Dorados: %d filas; %d pasan (0,1 %%), %d pasan por redondeo (r), %d fallan, %d sin dato, " ..
    "%d sin evaluar, %d difieren del C", #golden, n_pass, n_pass_r, n_fail, n_missing, n_unseen,
    n_ref_bad))
if n_fail + n_missing + n_unseen + n_ref_bad > 0 then
    total_fail = total_fail + n_fail + n_missing + n_unseen + n_ref_bad
end

-- ============================================== 2. ALEATORIOS (oraculo 1)
do
    print("== Aleatorios (oraculo 1: f, hf, Qmax, D) ==")
    local rows = dofile("tests/data/random1.lua")
    local TOL = 1e-3
    local st = {
        { name = "f (dado Q)", worst = 0, n = 0, fail = 0, where = "" },
        { name = "hf (dado Q)", worst = 0, n = 0, fail = 0, where = "" },
        { name = "Qmax (dado H)", worst = 0, n = 0, fail = 0, where = "" },
        { name = "D de diseno", worst = 0, n = 0, fail = 0, where = "" },
    }
    local nf = 0
    local function cmp(k, got, ref, tipo, i, re)
        local e = abs(got - ref) / abs(ref)
        local s = st[k]
        s.n = s.n + 1
        if not (e <= TOL) then
            s.fail = s.fail + 1
            print(fmt("  FALLA %s caso %s-%d: ref %.9g obtenido %.9g (%.4f %%) Re=%.0f", s.name,
                tipo, i, ref, got, 100 * e, re))
        end
        if e > s.worst or s.n == 1 then
            s.worst = e
            s.where = fmt("%s-%d (Re = %.0f)", tipo, i, re)
        end
    end
    local Cc = H.new_cfg()
    local p = {}
    local count = {}
    for _, r in ipairs(rows) do
        local tipo, i, D, L, ks, K, nu, a, bq, c, Re = unpack(r)
        count[tipo] = (count[tipo] or 0) + 1
        Cc.nu = nu
        p.D, p.L, p.ks, p.sumK, p.f_fixed = D, L, ks, K, 0
        if tipo == "F" then
            local s = {}
            local err = pstate(p, a, Cc, s)
            if err ~= 0 then
                print(fmt("  error %d en F-%d", err, i)); nf = nf + 1
            else
                cmp(1, s.f, bq, tipo, i, Re)
                cmp(2, s.hf, c, tipo, i, Re)
            end
        elseif tipo == "B" then
            local q = {}
            local err = qmax(p, a, Cc, q, nil)
            if err ~= 0 then
                print(fmt("  error %d en B-%d", err, i)); nf = nf + 1
            else
                cmp(3, q.st.Q, bq, tipo, i, Re)
            end
        elseif tipo == "D" then
            local d = {}
            local err = H.hydro_design(p, a, bq, nil, 0, Cc, d, nil)
            if err ~= 0 then
                print(fmt("  error %d en D-%d", err, i)); nf = nf + 1
            else
                cmp(4, d.D_exact, D, tipo, i, Re)
            end
        end
    end
    print("| Magnitud | Casos | Fallan | Peor error rel. | Donde |")
    for k = 1, 4 do
        local s = st[k]
        print(fmt("| %s | %d | %d | %.2e | %s |", s.name, s.n, s.fail, s.worst, s.where))
        nf = nf + s.fail
    end
    print(fmt("Aleatorios 1: %d filas (F %d, B %d, D %d), %d comparaciones, %d fallos",
        #rows, count.F or 0, count.B or 0, count.D or 0, st[1].n + st[2].n + st[3].n + st[4].n, nf))
    total_fail = total_fail + nf
end

-- ============================================== 3. ALEATORIOS (oraculo 2)
do
    print("== Aleatorios (oraculo 2: v2.0) ==")
    local rows = dofile("tests/data/random2.lua")
    local TOL = 1e-3
    local kinds = { T = 1, S = 2, Q = 3, H = 4, V = 5, J = 6, P = 7, F = 8 }
    local knames = { "velocidad terminal", "estructura (F, M)", "compuesto Q(h)",
        "compuesto h(Q)", "Venturi (dp, h)", "salto (y2, dE)", "placa (Cf)", "f (4 metodos)" }
    local n_, fail_, worst_ = {}, {}, {}
    for k = 1, 8 do n_[k], fail_[k], worst_[k] = 0, 0, 0 end
    local Cc = H.new_cfg()
    local function cmp(k, got, ref, line)
        local e = abs(got - ref) / ((abs(ref) > 0) and abs(ref) or 1)
        n_[k] = n_[k] + 1
        if not (e <= TOL) then
            fail_[k] = fail_[k] + 1
            print(fmt("  FALLA %s (linea %d): ref %.9g obtenido %s (%s %%)", knames[k], line, ref,
                tostring(got), tostring(100 * e)))
        elseif e > worst_[k] then
            worst_[k] = e
        end
    end
    for ln, row in ipairs(rows) do
        local kind = row[1]
        local x = {}
        for i = 0, 8 do x[i] = row[i + 2] end
        local r1, r2 = row[11], row[12]
        local k = kinds[kind]
        if kind == "T" then
            local r = {}
            Dr.drag_terminal(x[0], x[1], x[2], x[3], x[4], 1, 1e-6, Cc.g, DK_GENERIC, r)
            cmp(k, r.v, r1, ln)
        elseif kind == "S" then
            local bd = {}
            local r = {}
            for i = 0, 1 do
                bd[i + 1] = { Cd = x[2 + 3 * i], A = x[3 + 3 * i], y = x[4 + 3 * i], V = x[0],
                    Lref = 0, kind = 0 }
            end
            bd[3] = { Cd = x[8], A = 10, y = 5, V = x[0], Lref = 0, kind = 0 }
            Dr.drag_struct(bd, 3, x[1], 1.5e-5, r)
            cmp(k, r.Ftot, r1, ln)
            cmp(k, r.M, r2, ln)
        elseif kind == "Q" or kind == "H" then
            local e = {
                { type = Wr.WE_TRI, a = x[0], z = x[1], count = 1, ncon = 0, b = 0, Cd = x[7] },
                { type = Wr.WE_RECT, a = x[2], z = x[3], count = 1, ncon = 0, b = 0, Cd = x[7] },
                { type = Wr.WE_ORC, a = x[4], z = x[5], count = x[6], ncon = 0, b = 0, Cd = x[7] },
            }
            if kind == "Q" then
                local _, Q = Wr.weir_total(e, 3, x[8], Cc.g, 0)
                cmp(k, Q, r1, ln)
            else
                local err, h = Wr.weir_level(e, 3, x[8], Cc.g, 0, nil)
                if err ~= 0 then print(fmt("  error %d en H (linea %d)", err, ln)) end
                cmp(k, h or 0 / 0, r1, ln)
            end
        elseif kind == "V" then
            local r = {}
            Ch.chan_venturi(x[0], x[0] * x[1], x[2], 1, x[3], Ch.MANO_PHYS, Cc, r)
            cmp(k, r.dp, r1, ln)
            cmp(k, r.h, r2, ln)
        elseif kind == "J" then
            local r = {}
            local err = Ch.chan_jump(x[0], x[1], x[2], 0, Cc, r)
            if err ~= 0 then print(fmt("  error %d en J (linea %d)", err, ln)) end
            cmp(k, r.y2 or 0 / 0, r1, ln)
            cmp(k, r.dE or 0 / 0, r2, ln)
        elseif kind == "P" then
            local r = {}
            Dr.drag_plate(x[0], 1, x[1], 1.2, x[2], 1, Dr.PL_TURB, r)
            cmp(k, r.Cf_turb, r1, ln)
            cmp(k, r.Cf_mix, r2, ln)
        elseif kind == "F" then
            local r = {}
            H.hydro_fric_all(x[0], x[1], Cc, r, nil)
            cmp(k, r.f[floor(x[2])], r1, ln)
        end
    end
    local nf = 0
    print("| Formula | Comparaciones | Fallan | Peor error rel. |")
    for k = 1, 8 do
        print(fmt("| %s | %d | %d | %.2e |", knames[k], n_[k], fail_[k], worst_[k]))
        nf = nf + fail_[k]
    end
    print(fmt("Aleatorios 2: %d filas, %d fallos", #rows, nf))
    total_fail = total_fail + nf
end

-- ================================== 4. SECANTE Y ARRANQUE HW (secant_check)
do
    print("== Secante y arranque Hazen-Williams (v2.1) ==")
    local rows = dofile("tests/data/random1.lua")
    local TOL_REF = 1e-6
    local IT_D, IT_S = H.IT_DEFAULT, H.IT_SECANT
    local VB = {
        { "curso (v2.0)", 0, IT_D, 1 },
        { "curso desde HW 130", 130, IT_D, 1 },
        { "secante desde H", 0, IT_S, 1 },
        { "secante desde HW 130", 130, IT_S, 1 },
        { "secante desde HW 150", 150, IT_S, 1 },
        { "secante HW C_H=1", 1, IT_S, 1 },
        { "secante HW C_H=1e4", 10000, IT_S, 1 },
        { "curso, SumK x50", 0, IT_D, 50 },
        { "secante HW 130, SumK x50", 130, IT_S, 50 },
    }
    local VD = {
        { "biseccion (v2.0)", 0, IT_D, 1 },
        { "secante f=0.02", 0, IT_S, 1 },
        { "secante HW 130", 130, IT_D, 1 },
        { "secante HW 150", 150, IT_S, 1 },
        { "secante HW C_H=1", 1, IT_S, 1 },
        { "secante HW C_H=1e4", 10000, IT_S, 1 },
        { "biseccion, SumK x50", 0, IT_D, 50 },
        { "secante HW 130, SumK x50", 130, IT_S, 50 },
    }
    local function newstats(v)
        local t = {}
        for k = 1, #v do
            t[k] = { n = 0, err = 0, fb = 0, itmax = 0, newfail = 0, itsum = 0, wref = 0, worc = 0 }
        end
        return t
    end
    local sb, sd = newstats(VB), newstats(VD)
    local function acc(s, it, fb, ref_rel, orc_rel)
        s.n = s.n + 1
        s.itsum = s.itsum + it
        if it > s.itmax then s.itmax = it end
        s.fb = s.fb + fb
        if ref_rel > s.wref then s.wref = ref_rel end
        if orc_rel > s.worc then s.worc = orc_rel end
    end
    local function rel(x, y) return abs(x - y) / abs(y) end

    local Cc = H.new_cfg()
    local p = { f_fixed = 0 }
    local ref, refK50 = 0, 0
    local nB, nD = 0, 0
    for _, row in ipairs(rows) do
        local tipo, i, D, L, ks, K, nu, a, bq = row[1], row[2], row[3], row[4], row[5], row[6],
            row[7], row[8], row[9]
        Cc.nu = nu
        p.D, p.L, p.ks, p.f_fixed = D, L, ks, 0
        if tipo == "B" then
            nB = nB + 1
            for k = 1, #VB do
                local v = VB[k]
                p.sumK = K * v[4]
                local o = { CH = v[2], solver = v[3] }
                local q = {}
                local e = qmax_o(p, a, Cc, o, q, nil)
                if e ~= 0 then
                    sb[k].err = sb[k].err + 1
                    if not (k == 1 or k == 8) then
                        sb[k].newfail = sb[k].newfail + 1
                        print(fmt("  B-%d %s: error %d", i, v[1], e))
                    end
                else
                    if k == 1 then ref = q.st.Q end
                    if k == 8 then refK50 = q.st.Q end
                    acc(sb[k], q.iters, (v[3] == IT_S and q.solver ~= H.SOLV_SECANT) and 1 or 0,
                        rel(q.st.Q, v[4] > 1 and refK50 or ref),
                        v[4] > 1 and 0 or rel(q.st.Q, bq))
                end
            end
        elseif tipo == "D" then
            nD = nD + 1
            for k = 1, #VD do
                local v = VD[k]
                p.sumK = K * v[4]
                local o = { CH = v[2], solver = v[3] }
                local d = {}
                local e = H.hydro_design_o(p, a, bq, nil, 0, Cc, o, d, nil)
                if e ~= 0 then
                    sd[k].err = sd[k].err + 1
                    if not (k == 1 or k == 7) then
                        sd[k].newfail = sd[k].newfail + 1
                        print(fmt("  D-%d %s: error %d", i, v[1], e))
                    end
                else
                    if k == 1 then ref = d.D_exact end
                    if k == 7 then refK50 = d.D_exact end
                    acc(sd[k], d.iters, d.fb, rel(d.D_exact, v[4] > 1 and refK50 or ref),
                        v[4] > 1 and 0 or rel(d.D_exact, D))
                end
            end
        end
    end
    local nf = 0
    local function report(title, V, S, isB)
        print(fmt("| %s | Casos | Errores | Vueltas media | max | Respaldo | Dif. vs v2.0 | Dif. vs oraculo |",
            title))
        for k = 1, #V do
            local s = S[k]
            print(fmt("| %s | %d | %d | %.2f | %d | %d | %.2e | %.2e |", V[k][1], s.n, s.err,
                s.n > 0 and s.itsum / s.n or 0, s.itmax, s.fb, s.wref, s.worc))
            nf = nf + s.newfail
            if isB then
                if V[k][3] == IT_S and V[k][4] == 1 and s.worc > TOL_REF then
                    nf = nf + 1
                    print("  FALLA: secante B difiere del oraculo")
                end
            elseif s.wref > TOL_REF then
                nf = nf + 1
                print("  FALLA: D difiere de la biseccion")
            end
        end
    end
    report("Tipo B: variante", VB, sb, true)
    report("Tipo D: variante", VD, sd, false)
    print(fmt("Secante: %d casos B x %d variantes, %d casos D x %d variantes, %d fallos", nB, #VB,
        nD, #VD, nf))
    total_fail = total_fail + nf
end

-- ============================================ 5. EXPR y NUMFMT (pure)
do
    print("== Expr y numfmt ==")
    local EXPR_OK, EXPR_EMPTY, EXPR_SYNTAX, EXPR_DIV0, EXPR_RANGE, EXPR_DEPTH =
        X.EXPR_OK, X.EXPR_EMPTY, X.EXPR_SYNTAX, X.EXPR_DIV0, X.EXPR_RANGE, X.EXPR_DEPTH
    local total, fails = 0, 0
    local function ev(s, expect, err_expect)
        local e, v = X.expr_eval(s)
        local ok = (e == err_expect) and
            (e ~= EXPR_OK or abs(v - expect) <= 1e-6 * (abs(expect) + 1e-30))
        total = total + 1
        if not ok then
            fails = fails + 1
            print(fmt("  FALLA expr \"%s\": err %d (esp. %d) valor %s (esp. %.9g)", s, e, err_expect,
                tostring(v), expect))
        end
    end
    local function fm(x, dec, expect)
        local s = N.fmt_real(x, dec)
        total = total + 1
        if s ~= expect then
            fails = fails + 1
            print(fmt("  FALLA fmt %.10g dec %d: \"%s\" (esp. \"%s\")", x, dec, s, expect))
        end
    end
    ev("0.5+1.0+4*1.10+10*0.30+3*0.3+3.0", 12.8, EXPR_OK)
    ev("0.5+3*0.15+167*0.01+12*0.18+6*0.32", 6.7, EXPR_OK)
    ev("8.0+1.0+0.7+1.0+0.7+6.0+1.0+3.0", 21.4, EXPR_OK)
    ev("1.5E-6", 1.5e-6, EXPR_OK)
    ev("1.007E-6", 1.007e-6, EXPR_OK)
    ev("2E3", 2000, EXPR_OK)
    ev("2E+3", 2000, EXPR_OK)
    ev(".5", 0.5, EXPR_OK)
    ev("-3+5", 2, EXPR_OK)
    ev("--3", 3, EXPR_OK)
    ev("2^3^2", 512, EXPR_OK)
    ev("-2^2", -4, EXPR_OK)
    ev("4(0.2)", 0.8, EXPR_OK)
    ev("(1+2)(3+4)", 21, EXPR_OK)
    ev("10/4", 2.5, EXPR_OK)
    ev("1252-1193", 59, EXPR_OK)
    ev(" 3 * ( 2 + 1 ) ", 9, EXPR_OK)
    ev("", 0, EXPR_EMPTY)
    ev("   ", 0, EXPR_EMPTY)
    ev("3+", 0, EXPR_SYNTAX)
    ev("(3+2", 0, EXPR_SYNTAX)
    ev("3+2)", 0, EXPR_SYNTAX)
    ev("1/0", 0, EXPR_DIV0)
    ev("1/(2-2)", 0, EXPR_DIV0)
    ev("0^-1", 0, EXPR_DIV0)
    ev("1E", 0, EXPR_SYNTAX)
    ev(".", 0, EXPR_SYNTAX)
    ev("1..2", 0, EXPR_SYNTAX)
    ev("E5", 0, EXPR_SYNTAX)
    ev("((((((((((((((1))))))))))))))", 0, EXPR_DEPTH)
    ev("1E30*1E30", 1e60, EXPR_OK)
    ev("--------------------1", 0, EXPR_DEPTH)
    -- extras de Nspire: U+2212 (menos) y U+1D07 (tecla EE)
    ev("5\226\136\1463", 2, EXPR_OK)
    ev("\226\136\1463+5", 2, EXPR_OK)
    ev("2^\226\136\1462", 0.25, EXPR_OK)
    ev("1.5\225\180\1356", 1.5e6, EXPR_OK)
    ev("1.5\225\180\135\226\136\1466", 1.5e-6, EXPR_OK)
    ev("1.5e-6", 1.5e-6, EXPR_OK)
    ev("1e400", 0, EXPR_RANGE)
    ev("1 2", 0, EXPR_SYNTAX)
    ev("abc", 0, EXPR_SYNTAX)
    if X.expr_err_text(EXPR_DIV0) ~= "Division entre cero" or X.expr_err_text(99) ~= "Error" or
        X.expr_err_text(EXPR_OK) ~= "OK" then
        fails = fails + 1
        print("  FALLA expr_err_text")
    end
    total = total + 1

    fm(17.969841, 6, "17.96984")
    fm(455180.6, 6, "455180.6")
    fm(0.01349, 6, "0.01349")
    fm(0.0261015, 6, "0.026102")
    fm(9.81, 6, "9.81")
    fm(9810, 6, "9810")
    fm(1.0e-6, 6, "1E-6")
    fm(1.5e-6, 6, "1.5E-6")
    fm(1.007e-6, 6, "1.007E-6")
    fm(2.5e7, 6, "2.5E7")
    fm(0, 6, "0")
    fm(-7.8, 6, "-7.8")
    fm(318.8, 1, "318.8")
    fm(2.376714, 3, "2.377")
    fm(99.99996, 4, "100")
    fm(0.5, 0, "1")
    fm(1234567, 6, "1234567")
    fm(9999999.6, 6, "1E7")
    fm(1.23456789e-5, 6, "1.23457E-5")
    fm(0.000123, 6, "0.000123")
    fm(0.00009999, 6, "9.999E-5")
    -- extras
    fm(-1.5e-6, 6, "-1.5E-6")
    fm(1 / 0, 6, "ERR")
    fm(0 / 0, 6, "ERR")
    fm(123, 0, "123")
    fm(0.1, 6, "0.1")
    fm(100, 6, "100")
    fm(1e7, 6, "1E7")
    total = total + 1
    if N.fmt_int(-42) ~= "-42" or N.fmt_int(0) ~= "0" or N.fmt_int(2147483647) ~= "2147483647" then
        fails = fails + 1
        print("  FALLA fmt_int")
    end
    print(fmt("%d de %d pruebas de expr/numfmt pasan", total - fails, total))
    total_fail = total_fail + fails
end

-- ================================================ 6. DATOS (data/*.lua)
do
    print("== Datos ==")
    local nfail = 0
    local function chk(cond, msg)
        if not cond then nfail = nfail + 1; fail("datos: " .. msg) end
    end
    chk(#LIB.materials == LIB.MATERIALS, "materiales " .. #LIB.materials)
    chk(#LIB.fittings == LIB.FITTINGS, "accesorios " .. #LIB.fittings)
    chk(#LIB.k_presets == LIB.K_PRESETS, "presets " .. #LIB.k_presets)
    chk(#LIB.waters == LIB.WATERS, "aguas " .. #LIB.waters)
    for i, p in ipairs(LIB.k_presets) do chk(#p.items == p.n, "preset " .. i) end
    chk(#DI.diam_sets == DI.DIAM_SETS, "listas de diametros")
    chk(#DI.diam_set_names == DI.DIAM_CHOICES, "nombres de listas")
    for i, s in ipairs(DI.diam_sets) do
        chk(#s.mm == s.n, "lista " .. i)
        chk(s.name == DI.diam_set_names[i], "nombre lista " .. i)
    end
    chk(#DI.diam_custom == DI.DIAM_CUSTOM_MAX, "lista propia")
    chk(#EXD.examples == EXD.EXAMPLES, "casos del curso " .. #EXD.examples)
    local nvals = { [EXD.PT_A] = 9, [EXD.PT_I] = 10, [EXD.PT_B] = 10, [EXD.PT_C] = 12,
        [EXD.PT_D] = 11, [EXD.PT_F] = 9, [EXD.PT_E] = 9 }
    for i, e in ipairs(EXD.examples) do
        if e.tipo == EXD.PT_COUNT then
            chk(e.vals == nil and e.n == i - 19, "sistema " .. e.name)
        else
            chk(e.n == nvals[e.tipo], "n valores de " .. e.name)
        end
    end
    chk(#DC.drag_shapes == DC.CAT_N, "figuras " .. #DC.drag_shapes)
    chk(#DC.area_txt == 5, "area_txt")
    -- tablas del catalogo, interpolacion y areas
    local cd, x0, y0, x1, y1, w = DC.dragcat_param(10, 15, 0) -- cilindro finito perpend.
    chk(abs(cd - 0.9 - 0.1 * (15 - 10) / 30) < 1e-12 and x0 == 10 and x1 == 40, "param L/D 15")
    chk(warn_has(w, Dr.DW_INTERP), "aviso interp")
    cd = DC.dragcat_param(10, 5000, 0)
    chk(cd == 1.2, "L/D infinito")
    cd = DC.dragcat_param(6, 45, 0) -- cono
    chk(abs(cd - 0.65 - 0.15 * 5 / 20) < 1e-12, "cono 45")
    chk(DC.dragcat_cd(0) == 0.5 and DC.dragcat_cd(99) == 0, "cd catalogo")
    DC.cd_user[0] = 0.47
    chk(DC.dragcat_cd(0) == 0.47, "cd propio")
    DC.cd_user[0] = nil
    chk(abs(DC.dragcat_area(DC.AR_CIRC, 2) - PI) < 1e-12, "area circular")
    chk(DC.dragcat_area(DC.AR_SQ, 3) == 9 and DC.dragcat_area(DC.AR_LD, 2, 5) == 10, "areas")
    chk(abs(DC.dragcat_area(DC.AR_SQ2, 1) - 1.41421356) < 1e-12, "area sqrt2")
    chk(H.hydro_err_text(H.H_ERR_NOJUMP) == "Fr1 <= 1: no hay salto hidraulico", "err_text")
    chk(H.hydro_err_text(99) == "Error" and H.hydro_method_name(FM_GOUDAR) == "Goudar-Sonnad", "textos")
    -- registro de iteraciones: primeras 16 y ultimas 16 filas
    local lg = H.new_log()
    for i = 1, 40 do H.hydro_log_row(lg, i, 0, 0, 0, 0) end
    chk(lg.n == 32 and lg.total == 40 and lg.r[16][1] == 16 and lg.r[17][1] == 25 and
        lg.r[32][1] == 40, "hydro_log_row")
    print(fmt("Datos: %d fallos", nfail))
    total_fail = total_fail + nfail
end

if total_fail > 0 then
    print(fmt("test_core FALLO: %d problemas", total_fail))
    os.exit(1)
end
print("test_core OK")
