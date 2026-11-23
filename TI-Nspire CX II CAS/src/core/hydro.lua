--[[
hydro.lua - Motor hidraulico de la app PERDIDAS (puerto 1:1 de src/hydro/hydro.c,
compilacion HYDRO_USE_DOUBLE). Todo en SI: m, s, m^3/s, Pa, W.

CONVENCIONES DEL PUERTO (valen tambien para drag, weir, chan)
  * Nombres, constantes, enumeraciones y codigos de error iguales a los del C
    (p. ej. H.hydro_pipe_state, H.FM_CW, H.H_ERR_D, H.W_LAMINAR).
  * Las funciones que en C devuelven int devuelven el codigo de error (0 = OK).
    Las estructuras de salida se pasan como tabla vacia `{}` (como el `&r` de C)
    y la funcion rellena sus campos (con los mismos nombres que en C; las
    subestructuras, p. ej. r.st, r.qmax, se crean solas).
  * Las salidas por puntero que no son estructuras se devuelven despues del
    codigo: `err, valor, ...` (se documenta en cada funcion).
  * Listas Lua = arreglos de base 1 (listas de diametros, kids, elementos de
    vertedero, cuerpos). Los indices de esas listas que devuelve o recibe el
    motor son de base 1 (nodo de red 1..n, idx_com 1..n o nil si no hay).
    Los arreglos indexados por un codigo enumerado (t.f[FM_CW], t.dpct, t.out)
    usan el codigo tal cual (base 0: claves 0..3).
  * Avisos (mascara de bits): sin operadores de bits en Lua 5.1. Usar
    H.warn_has(w, flag) -> boolean y H.warn_set(w, flag) -> w con el bit.
  * Registro de iteraciones (hydro_log): H.new_log() -> {n=0,total=0,r={}};
    r[i] = {a,b,c,d,e} (i = 1..n). Todas las funciones aceptan lg = nil.

API PUBLICA
  Constantes: HYDRO_PI, HYDRO_EPS_REL, HYDRO_BIS_REL, HYDRO_SEC_REL,
    HYDRO_SEC_MAX, HYDRO_LOG_MAX, HYDRO_LOG_COLS, NET_MAX, NET_MAX_CHILD,
    FM_CW FM_SJ FM_HAALAND FM_GOUDAR FM_COUNT, REG_LAMINAR REG_TRANSITION
    REG_TURBULENT, SOLV_DIRECT SOLV_COURSE SOLV_BISECTION SOLV_SECANT,
    IT_DEFAULT IT_SECANT, NODE_PIPE NODE_SERIES NODE_PARALLEL,
    H_OK H_ERR_D H_ERR_L H_ERR_Q H_ERR_NU H_ERR_KS H_ERR_K H_ERR_NOFLOW
    H_ERR_ETA H_ERR_NOCONV H_ERR_NOROOT H_ERR_KS_NEG H_ERR_HV_NEG
    H_ERR_HT_NEG H_ERR_HF_NEG H_ERR_LIST H_ERR_NET H_ERR_CH H_ERR_ARG
    H_ERR_FLOATS H_ERR_NOJUMP H_ERR_COUNT,
    W_LAMINAR W_TRANSITION W_KSD_RANGE W_V_HIGH W_V_LOW W_HM_HIGH W_P_NEG
    W_FALLBACK W_LOCAL_SMALL W_SJ_RANGE W_CAVIT W_KS_NEG.
  Utilidades: warn_has(w, flag), warn_set(w, flag), new_cfg(), new_pipe(D,L,ks,
    sumK,f_fixed), new_log(), new_net().
  hydro_cfg_default(c) -> c          campos g gamma nu tol re_lam re_turb
                                     ld_limit v_min v_max pv hm_ratio method max_iter
  hydro_log_clear(lg), hydro_log_row(lg, a,b,c,d,e)
  hydro_area(D)
  hydro_friction(Re, ksD, method, c, o) -> err      o: f, regime, iters
  hydro_fric_all(Re, ksD, c, t, lg) -> err          t: f[0..3], dpct[0..3], out[0..3], regime, iters
  hydro_check_pipe(p, c) -> err
  hydro_pipe_state(p, Q, c, s) -> err               s: Q A v Re ksD f hf hm hT hv2g LD regime f_iters warn
  hydro_qmax_o(p, H, c, o, r, lg) -> err            o = nil o {CH=, solver=IT_*}
  hydro_qmax(p, H, c, r, lg) -> err                 (= qmax_o con o = nil)
                                                    r: st, solver, course_ok, hw, iters, hf1, Q0
  hydro_pump(p, Q, Hs, eta, c, r) -> err            r: st, Hm, Pn, Pb
  hydro_turbine(p, Q, Ha, eta, c, r) -> err
  hydro_head_from_power(P, eta, Q, c)
  hydro_design_o(p, Qd, H, list, n, c, o, r, lg) -> err
  hydro_design(p, Qd, H, list, n, c, r, lg) -> err  list = lista Lua de D en m (o nil)
                                                    r: D_exact iters D_com idx_com(1..n|nil) st_exact
                                                       st_com_qd qmax vp warn D0 solver hw fb
  hydro_calibrate(D, L, Q, sumK, dz, dp, c, r) -> err   r: A v hm htot hf f Re ksD ks warn
  hydro_valve(p, Q, Ha, c, r) -> err                r: st, hv, Kv
  hydro_hw_hf(Q, D, L, CH), hydro_hw_q(H, D, L, CH)
  hydro_pressure_head(head_up, HB, v, h_loss, c, warn) -> p, warn
  hydro_vp(H, hf, sumK, c)
  hydro_module_coef(c), hydro_net_init(n)
  hydro_net_add_pipe(n, L, D, f, ks, sumK) -> idx (base 1) o -1
  hydro_net_add_group(n, type, kids, nk) -> idx o -1   kids = {i1, i2, ...} (indices base 1)
  hydro_net_solve(n, H, c) -> err
  hydro_net_solve_back(n, k, Qk, c) -> err, H
  net: n.n, n.root, n.node[i] {type nchild child[1..nchild] pipe f Mf Mk M Q h},
       n.outer_iters, n.res_q, n.res_h
  hydro_err_text(err), hydro_method_name(m)
]]

local H = {}

local sqrt, abs = math.sqrt, math.abs
local log10, log = math.log10, math.log

-- double (HYDRO_USE_DOUBLE)
H.HYDRO_EPS_REL = 1e-12
H.HYDRO_BIS_REL = 1e-12
H.HYDRO_SEC_REL = 1e-10
H.HYDRO_PI = 3.14159265358979
local PI = H.HYDRO_PI
local EPS_REL, BIS_REL, SEC_REL = H.HYDRO_EPS_REL, H.HYDRO_BIS_REL, H.HYDRO_SEC_REL

H.FM_CW, H.FM_SJ, H.FM_HAALAND, H.FM_GOUDAR, H.FM_COUNT = 0, 1, 2, 3, 4
H.REG_LAMINAR, H.REG_TRANSITION, H.REG_TURBULENT = 0, 1, 2
H.SOLV_DIRECT, H.SOLV_COURSE, H.SOLV_BISECTION, H.SOLV_SECANT = 0, 1, 2, 3
H.IT_DEFAULT, H.IT_SECANT = 0, 1
H.HYDRO_SEC_MAX = 12
H.HYDRO_LOG_MAX = 32
H.HYDRO_LOG_COLS = 5
H.NET_MAX = 16
H.NET_MAX_CHILD = 8
H.NODE_PIPE, H.NODE_SERIES, H.NODE_PARALLEL = 0, 1, 2

local FM_CW, FM_SJ, FM_HAALAND, FM_COUNT = 0, 1, 2, 4
local REG_LAMINAR, REG_TRANSITION, REG_TURBULENT = 0, 1, 2
local SOLV_DIRECT, SOLV_COURSE, SOLV_BISECTION, SOLV_SECANT = 0, 1, 2, 3
local IT_SECANT = 1
local SEC_MAX, LOG_MAX = 12, 32
local NET_MAX, NET_MAX_CHILD = 16, 8
local NODE_PIPE, NODE_SERIES, NODE_PARALLEL = 0, 1, 2

local errnames = { "H_OK", "H_ERR_D", "H_ERR_L", "H_ERR_Q", "H_ERR_NU",
    "H_ERR_KS", "H_ERR_K", "H_ERR_NOFLOW", "H_ERR_ETA", "H_ERR_NOCONV",
    "H_ERR_NOROOT", "H_ERR_KS_NEG", "H_ERR_HV_NEG", "H_ERR_HT_NEG",
    "H_ERR_HF_NEG", "H_ERR_LIST", "H_ERR_NET", "H_ERR_CH", "H_ERR_ARG",
    "H_ERR_FLOATS", "H_ERR_NOJUMP", "H_ERR_COUNT" }
for i = 1, #errnames do H[errnames[i]] = i - 1 end
local H_OK, H_ERR_D, H_ERR_L, H_ERR_Q, H_ERR_NU, H_ERR_KS, H_ERR_K =
    0, 1, 2, 3, 4, 5, 6
local H_ERR_NOFLOW, H_ERR_ETA, H_ERR_NOCONV, H_ERR_NOROOT = 7, 8, 9, 10
local H_ERR_KS_NEG, H_ERR_HV_NEG, H_ERR_HT_NEG, H_ERR_HF_NEG = 11, 12, 13, 14
local H_ERR_LIST, H_ERR_NET, H_ERR_COUNT = 15, 16, 21

local W_LAMINAR, W_TRANSITION, W_KSD_RANGE, W_V_HIGH = 1, 2, 4, 8
local W_V_LOW, W_HM_HIGH, W_P_NEG, W_FALLBACK = 16, 32, 64, 128
local W_LOCAL_SMALL, W_SJ_RANGE, W_CAVIT, W_KS_NEG = 256, 512, 1024, 2048
H.W_LAMINAR, H.W_TRANSITION, H.W_KSD_RANGE, H.W_V_HIGH = 1, 2, 4, 8
H.W_V_LOW, H.W_HM_HIGH, H.W_P_NEG, H.W_FALLBACK = 16, 32, 64, 128
H.W_LOCAL_SMALL, H.W_SJ_RANGE, H.W_CAVIT, H.W_KS_NEG = 256, 512, 1024, 2048

-- Mascaras de bits sin operadores de bits (flag = potencia de 2)
local function warn_has(w, flag)
    return (w or 0) % (flag * 2) >= flag
end
local function warn_set(w, flag)
    w = w or 0
    if w % (flag * 2) >= flag then return w end
    return w + flag
end
H.warn_has, H.warn_set = warn_has, warn_set

local function sub(t, k)
    local v = t[k]
    if not v then v = {}; t[k] = v end
    return v
end

local function copy(t)
    local r = {}
    for k, v in pairs(t) do r[k] = v end
    return r
end

-- Coeficiente de Haaland segun el material del curso
local HAALAND_COEF = 1.8
-- v2.1: opciones de iteracion (en PERDIDAS siempre activas)
local ITER_OPT = true

function H.hydro_cfg_default(c)
    c.g = 9.81
    c.gamma = 9810.0
    c.nu = 1.0e-6
    c.tol = 1.0e-5
    c.re_lam = 2000.0
    c.re_turb = 4000.0
    c.ld_limit = 4000.0
    c.v_min = 0.3
    c.v_max = 5.0
    c.pv = 2339.0
    c.hm_ratio = 0.3
    c.method = FM_CW
    c.max_iter = 200
    return c
end

function H.new_cfg() return H.hydro_cfg_default({}) end

function H.new_pipe(D, L, ks, sumK, f_fixed)
    return { D = D or 0, L = L or 0, ks = ks or 0, sumK = sumK or 0,
             f_fixed = f_fixed or 0 }
end

function H.new_log() return { n = 0, total = 0, r = {} } end
function H.new_net()
    return { n = 0, root = 0, node = {}, outer_iters = 0, res_q = 0, res_h = 0 }
end

local function hydro_log_clear(lg)
    if lg then
        lg.n = 0
        lg.total = 0
        lg.r = lg.r or {}
    end
end
H.hydro_log_clear = hydro_log_clear

-- Guarda las primeras LOG_MAX/2 filas y, si hay mas, las ultimas LOG_MAX/2.
local function log_row(lg, a, b, c, d, e)
    if not lg then return end
    lg.total = lg.total + 1
    local r = { a, b, c, d, e }
    if lg.n < LOG_MAX then
        lg.n = lg.n + 1
        lg.r[lg.n] = r
    else
        for k = LOG_MAX / 2 + 1, LOG_MAX - 1 do
            lg.r[k] = lg.r[k + 1]
        end
        lg.r[LOG_MAX] = r
    end
end
H.hydro_log_row = log_row

local function hydro_area(D)
    return PI * D * D / 4.0
end
H.hydro_area = hydro_area

-- ------------------------------------------------------------------
-- Factor de friccion
-- ------------------------------------------------------------------
-- Colebrook-White por sustitucion sucesiva sobre x = 1/sqrt(f), desde
-- f1 = 0,0001. Devuelve f, iters.
local function cw_iter(Re, a, lg)
    local x, xn = 100.0, 0
    local iters = 0
    hydro_log_clear(lg)
    log_row(lg, 1, 1.0 / (x * x), 0, 0, 0)
    for i = 1, 60 do
        xn = -2.0 * log10(a + 2.51 * x / Re)
        iters = i
        log_row(lg, i + 1, 1.0 / (xn * xn), 0, 0, 0)
        if abs(xn - x) <= EPS_REL * xn then
            x = xn
            break
        end
        x = xn
    end
    return 1.0 / (x * x), iters
end

local function hydro_friction(Re, ksD, method, c, o)
    o.iters = 0
    o.f = 0
    if not (Re > 0) then return H_ERR_Q end
    if not (ksD >= 0) then return H_ERR_KS end

    if Re < c.re_lam then
        o.regime = REG_LAMINAR
        o.f = 64.0 / Re
        return H_OK
    end
    o.regime = (Re <= c.re_turb) and REG_TRANSITION or REG_TURBULENT
    local a = ksD / 3.7

    if method == FM_SJ then
        local t = log10(a + 5.74 / Re ^ 0.9)
        o.f = 0.25 / (t * t)
    elseif method == FM_HAALAND then
        local x = -HAALAND_COEF * log10(a ^ 1.11 + 6.9 / Re)
        o.f = 1.0 / (x * x)
    elseif method == 3 then -- FM_GOUDAR
        local C = 0.124 * Re * ksD + log(0.4587 * Re)
        local x = 0.8686 * log(0.4587 * Re / (C - 0.31) ^ (C / (C + 1.0)))
        o.f = 1.0 / (x * x)
    else
        o.f, o.iters = cw_iter(Re, a, nil)
    end
    return H_OK
end
H.hydro_friction = hydro_friction

function H.hydro_fric_all(Re, ksD, c, t, lg)
    local fr = {}
    hydro_log_clear(lg)
    t.f, t.dpct, t.out = t.f or {}, t.dpct or {}, t.out or {}
    for m = 0, FM_COUNT - 1 do
        local e = hydro_friction(Re, ksD, m, c, fr)
        if e ~= 0 then return e end
        t.f[m] = fr.f
        t.out[m] = 0
    end
    t.regime = fr.regime
    t.iters = 0
    if fr.regime ~= REG_LAMINAR then
        t.f[FM_CW], t.iters = cw_iter(Re, ksD / 3.7, lg)
        t.out[FM_CW] = ksD > 0.05 and 1 or 0
        t.out[FM_SJ] = (Re < 4000.0 or Re > 1.0e8 or ksD < 1.0e-6 or
                        ksD > 1.0e-2) and 1 or 0
        t.out[FM_HAALAND] = (Re < 4000.0 or Re > 1.0e8 or ksD > 0.05) and 1 or 0
        t.out[3] = (Re < 4000.0 or ksD > 0.05) and 1 or 0
    end
    for m = 0, FM_COUNT - 1 do
        t.dpct[m] = 100.0 * (t.f[m] - t.f[FM_CW]) / t.f[FM_CW]
    end
    return H_OK
end

-- ------------------------------------------------------------------
-- Tubo con caudal dado
-- ------------------------------------------------------------------
local function hydro_check_pipe(p, c)
    if not (p.D > 0) then return H_ERR_D end
    if not (p.L > 0) then return H_ERR_L end
    if not (p.sumK >= 0) then return H_ERR_K end
    if not (p.f_fixed >= 0) then return H_ERR_KS end
    if p.f_fixed > 0 then return H_OK end
    if not (p.ks >= 0) then return H_ERR_KS end
    if not (c.nu > 0) then return H_ERR_NU end
    return H_OK
end
H.hydro_check_pipe = hydro_check_pipe

local function state_warn(s, p, c)
    local w = 0
    if p.f_fixed <= 0 then
        if s.regime == REG_LAMINAR then
            w = warn_set(w, W_LAMINAR)
        elseif s.regime == REG_TRANSITION then
            w = warn_set(w, W_TRANSITION)
        end
        if s.ksD > 0.05 then w = warn_set(w, W_KSD_RANGE) end
        if c.method == FM_SJ and s.regime ~= REG_LAMINAR and
            (s.Re < 4000.0 or s.Re > 1.0e8 or s.ksD < 1.0e-6 or
             s.ksD > 1.0e-2) then
            w = warn_set(w, W_SJ_RANGE)
        end
    end
    if s.v > c.v_max then w = warn_set(w, W_V_HIGH) end
    if s.v < c.v_min then w = warn_set(w, W_V_LOW) end
    if s.hm > c.hm_ratio * s.hf then w = warn_set(w, W_HM_HIGH) end
    if p.sumK > 0 and s.LD > c.ld_limit then w = warn_set(w, W_LOCAL_SMALL) end
    return w
end

local function hydro_pipe_state(p, Q, c, s)
    local e = hydro_check_pipe(p, c)
    if e ~= 0 then return e end
    if not (Q > 0) then return H_ERR_Q end

    s.Q = Q
    s.A = hydro_area(p.D)
    s.v = Q / s.A
    s.Re = s.v * p.D / c.nu
    s.ksD = p.ks / p.D
    s.LD = p.L / p.D
    s.hv2g = s.v * s.v / (2.0 * c.g)
    if p.f_fixed > 0 then
        s.f = p.f_fixed
        s.f_iters = 0
        s.regime = (s.Re < c.re_lam) and REG_LAMINAR or
                   ((s.Re <= c.re_turb) and REG_TRANSITION or REG_TURBULENT)
    else
        local fr = {}
        e = hydro_friction(s.Re, s.ksD, c.method, c, fr)
        if e ~= 0 then return e end
        s.f = fr.f
        s.f_iters = fr.iters
        s.regime = fr.regime
    end
    s.hf = s.f * s.LD * s.hv2g
    s.hm = p.sumK * s.hv2g
    s.hT = s.hf + s.hm
    s.warn = state_warn(s, p, c)
    return H_OK
end
H.hydro_pipe_state = hydro_pipe_state

-- Perdida total en funcion de la velocidad (para la biseccion)
local function hT_of_v(p, v, c)
    local f
    if not (v > 0) then return 0 end
    if p.f_fixed > 0 then
        f = p.f_fixed
    else
        local fr = {}
        if hydro_friction(v * p.D / c.nu, p.ks / p.D, c.method, c, fr) ~= 0 then
            return 0
        end
        f = fr.f
    end
    return (f * p.L / p.D + p.sumK) * v * v / (2.0 * c.g)
end

-- Biseccion sobre v: hT(v) = H (hT crece con v). -> err, v, iters
local function solve_v_bisection(p, Hh, c, lg)
    local lo, hi, mid, g = 0, 1.0, 0, 0
    local it = 0
    while hT_of_v(p, hi, c) < Hh do
        if it > 40 then return H_ERR_NOROOT end
        lo = hi
        hi = hi * 2.0
        it = it + 1
    end
    it = 1
    while it <= 200 do
        mid = 0.5 * (lo + hi)
        g = hT_of_v(p, mid, c) - Hh
        log_row(lg, it, lo, hi, mid, g)
        if g > 0 then hi = mid else lo = mid end
        if hi - lo <= BIS_REL * hi then break end
        it = it + 1
    end
    return H_OK, 0.5 * (lo + hi), it
end

-- ------------------------------------------------------------------
-- Tipo B: caudal maximo
-- ------------------------------------------------------------------
-- Velocidad de la formula del curso (diapositivas 10 y 11) dado hf
local function v_course(p, hf, c)
    local g2 = 2.0 * c.g
    local arg = p.ks / (3.7 * p.D) +
                2.51 * c.nu * sqrt(p.L) /
                sqrt(g2 * p.D * p.D * p.D * hf)
    return -sqrt(4.0 * g2 * p.D * hf / p.L) * log10(arg)
end

-- v2.1: raiz x > 0 de a x^p + b x^q = H por Newton (arranque)
local function pow_root(a, p, b, q, Hh)
    local x = (Hh / a) ^ (1.0 / p)
    for _ = 0, 7 do
        local t1 = a * x ^ p
        local t2 = b * x ^ q
        x = x - x * (t1 + t2 - Hh) / (p * t1 + q * t2)
    end
    return x
end

-- v2.1: secante protegida, comun a los tipos B y D. fn(s, x, o) llena
-- o[1], o[2] (columnas de la memoria) y o[3] = F(x); devuelve false si x
-- no sirve. -> ok, iters, root
local function secant(fn, s, x, k, lo, hi, sg, lg)
    local o = { 0, 0, 0 }
    local xp, Fp = x, 0
    hydro_log_clear(lg)
    for i = 0, SEC_MAX + 1 do
        if not fn(s, x, o) then return false end
        log_row(lg, i, x, o[1], o[2], o[3])
        if o[3] == 0 or (i > 1 and abs(o[3]) <= 1e-3 * s.H and
                         abs(x - xp) <= SEC_REL * x) then
            return true, (i > 1) and (i - 1) or 0, x
        end
        local n
        if i ~= 0 then
            n = x - o[3] * (x - xp) / (o[3] - Fp)
        else
            n = (k > 0) and (k * x) or (x - o[3])
        end
        if not (n > lo and n < hi) then
            n = 0.5 * (lo + hi)
        end
        if o[3] * sg > 0 then lo = x else hi = x end
        xp = x
        Fp = o[3]
        x = n
    end
    return false
end

-- B: G(hf) = hf + SumK v(hf)^2/2g - H, con v(hf) de la formula del curso
local function fB(s, hf, o)
    local v = v_course(s.p, hf, s.c)
    o[1] = v
    o[2] = s.p.sumK * v * v / (2.0 * s.c.g)
    o[3] = hf + o[2] - s.H
    return v > 0
end

local hydro_hw_hf

local function hydro_qmax_o(p, Hh, c, o, r, lg)
    local v, hf, hfn, hm = 0, 0, 0, 0
    local g2 = 2.0 * c.g
    local e = hydro_check_pipe(p, c)
    local st = sub(r, "st")

    hydro_log_clear(lg)
    r.iters = 0
    r.course_ok = 0
    r.hw = 0
    r.Q0 = 0
    r.hf1 = Hh
    r.solver = SOLV_BISECTION
    if e ~= 0 then return e end
    if not (Hh > 0) then return H_ERR_NOFLOW end
    local A = hydro_area(p.D)

    if p.f_fixed > 0 then
        v = sqrt(g2 * Hh / (p.f_fixed * p.L / p.D + p.sumK))
        r.solver = SOLV_DIRECT
        r.iters = 1
    elseif c.method == FM_CW then
        -- v2.1: hf1 de Hazen-Williams, con Q_HW tal que
        -- hf_HW(Q) + SumK v^2/2g = H. Si falla, hf1 = H como antes.
        if ITER_OPT and o and o.CH and o.CH > 0 then
            r.Q0 = pow_root(hydro_hw_hf(1, p.D, p.L, o.CH), 1.852,
                            p.sumK / (g2 * A * A), 2.0, Hh)
            r.hf1 = hydro_hw_hf(r.Q0, p.D, p.L, o.CH)
            if r.hf1 > 0 and r.hf1 < Hh then
                r.hw = 1
                v = r.Q0 / A
                hm = p.sumK * v * v / g2
                log_row(lg, 0, r.hf1, v, hm, r.hf1)
            else
                r.hf1 = Hh
            end
        end
        hf = r.hf1
        local use_sec = ITER_OPT and o and o.solver == IT_SECANT
        if use_sec then
            -- v2.1: secante sobre G(hf); G crece con hf: G(0) < 0.
            local ok, it, root = secant(fB, { p = p, c = c, H = Hh }, hf, 0, 0,
                                        Hh, -1, lg)
            if ok then
                r.iters = it
                hf = root
                v = v_course(p, hf, c)
                r.course_ok = 1
            end
        else
            -- Iteracion del curso (diapositivas 10 y 11)
            for i = 1, c.max_iter do
                v = v_course(p, hf, c)
                if not (v > 0) then break end
                hm = p.sumK * v * v / g2
                hfn = Hh - hm
                log_row(lg, i, hf, v, hm, hfn)
                r.iters = i
                if not (hfn > 0) then break end
                if abs(hfn - hf) <= c.tol + EPS_REL * hf then
                    -- velocidad final con el ultimo hf
                    v = v_course(p, hfn, c)
                    r.course_ok = 1
                    break
                end
                hf = hfn
            end
        end
        -- La formula del curso supone Colebrook-White (Re > 2000)
        if r.course_ok ~= 0 and v * p.D / c.nu < c.re_lam then
            r.course_ok = 0
        end
        if r.course_ok ~= 0 then
            r.solver = use_sec and SOLV_SECANT or SOLV_COURSE
        end
    end

    if r.solver == SOLV_BISECTION then
        hydro_log_clear(lg) -- el registro mostrara la biseccion
        local it
        e, v, it = solve_v_bisection(p, Hh, c, lg)
        if e ~= 0 then return e end
        r.iters = it
    end

    e = hydro_pipe_state(p, v * A, c, st)
    if e ~= 0 then return e end
    if r.solver == SOLV_BISECTION and c.method == FM_CW and p.f_fixed <= 0 then
        st.warn = warn_set(st.warn, W_FALLBACK)
    end
    return H_OK
end
H.hydro_qmax_o = hydro_qmax_o

function H.hydro_qmax(p, Hh, c, r, lg)
    return hydro_qmax_o(p, Hh, c, nil, r, lg)
end

-- ------------------------------------------------------------------
-- Tipo C: bomba y turbina
-- ------------------------------------------------------------------
function H.hydro_head_from_power(P, eta, Q, c)
    if not (Q > 0) then return 0 end
    return eta * P / (c.gamma * Q)
end

function H.hydro_pump(p, Q, Hs, eta, c, r)
    if not (eta > 0 and eta <= 1.0) then return H_ERR_ETA end
    local st = sub(r, "st")
    local e = hydro_pipe_state(p, Q, c, st)
    if e ~= 0 then return e end
    r.Hm = Hs + st.hT
    r.Pn = c.gamma * Q * r.Hm
    r.Pb = r.Pn / eta
    if not (r.Hm > 0) then return H_ERR_HT_NEG end
    return H_OK
end

function H.hydro_turbine(p, Q, Ha, eta, c, r)
    if not (eta > 0 and eta <= 1.0) then return H_ERR_ETA end
    local st = sub(r, "st")
    local e = hydro_pipe_state(p, Q, c, st)
    if e ~= 0 then return e end
    r.Hm = Ha - st.hT
    r.Pb = c.gamma * Q * r.Hm
    r.Pn = eta * r.Pb
    if not (r.Hm > 0) then return H_ERR_HT_NEG end
    return H_OK
end

-- ------------------------------------------------------------------
-- Tipo D: diseno del diametro
-- ------------------------------------------------------------------
local function hT_of_D(p, D, Q, c)
    local q = copy(p)
    local s = {}
    q.D = D
    if hydro_pipe_state(q, Q, c, s) ~= 0 then return -1 end
    return s.hT
end

local function fD(s, D, o)
    o[1] = s.Q / hydro_area(D)
    o[2] = hT_of_D(s.p, D, s.Q, s.c)
    o[3] = o[2] - s.H
    return o[2] > 0
end

local function hydro_vp(Hh, hf, sumK, c)
    if not (sumK > 0) or not (Hh > hf) then return 0 end
    return sqrt(2.0 * c.g * (Hh - hf) / sumK)
end
H.hydro_vp = hydro_vp

local function hydro_design_o(p, Qd, Hh, list, n, c, o, r, lg)
    local q = copy(p)
    local lo, hi, mid, g = 0.001, 20.0, 0, 0
    local st_exact = sub(r, "st_exact")
    local st_com = sub(r, "st_com_qd")

    hydro_log_clear(lg)
    r.D_exact = 0
    r.D_com = 0
    r.idx_com = nil
    r.vp = 0
    r.warn = 0
    r.iters = 0
    r.D0 = 0
    r.solver = SOLV_BISECTION
    r.hw = 0
    r.fb = 0
    q.D = 1.0
    local e = hydro_check_pipe(q, c)
    if e ~= 0 then return e end
    if not (Qd > 0) then return H_ERR_Q end
    if not (Hh > 0) then return H_ERR_NOFLOW end
    if hT_of_D(q, hi, Qd, c) > Hh or hT_of_D(q, lo, Qd, c) < Hh then
        return H_ERR_NOROOT
    end

    -- v2.1: secante sobre F(D) = hT(Qd, D) - H desde D0 y 1,02 D0.
    if ITER_OPT and o and (o.solver == IT_SECANT or (o.CH and o.CH > 0)) then
        local k8 = 8.0 * Qd * Qd / (PI * PI * c.g)
        local hwon = (o.CH and o.CH > 0)
        r.hw = hwon and 1 or 0
        local a, pp
        if hwon then
            a, pp = hydro_hw_hf(Qd, 1, q.L, o.CH), -4.87
        else
            a, pp = 0.02 * q.L * k8, -5.0
        end
        r.D0 = pow_root(a, pp, q.sumK * k8, -4.0, Hh)
        -- F = hT - H baja al crecer D: F(lo) > 0
        local ok, it, root = secant(fD, { p = q, c = c, Q = Qd, H = Hh }, r.D0,
                                    1.02, lo, hi, 1, lg)
        if ok then
            r.iters = it
            r.D_exact = root
            r.solver = SOLV_SECANT
        end
        if r.solver ~= SOLV_SECANT then
            r.fb = 1
            hydro_log_clear(lg)
        end
    end

    if r.solver == SOLV_BISECTION then
        -- Biseccion geometrica sobre D (hT decrece con D)
        local it = 1
        while it <= 200 do
            mid = sqrt(lo * hi)
            g = hT_of_D(q, mid, Qd, c) - Hh
            log_row(lg, it, lo, hi, mid, g)
            if g > 0 then lo = mid else hi = mid end
            if hi - lo <= BIS_REL * hi then break end
            it = it + 1
        end
        r.iters = it
        r.D_exact = 0.5 * (lo + hi)
    end
    q.D = r.D_exact
    hydro_pipe_state(q, Qd, c, st_exact)

    if not list or n <= 0 then return H_OK end
    for i = 1, n do
        if list[i] >= r.D_exact and (not r.idx_com or list[i] < r.D_com) then
            r.D_com = list[i]
            r.idx_com = i
        end
    end
    if not r.idx_com then return H_ERR_LIST end

    q.D = r.D_com
    e = hydro_pipe_state(q, Qd, c, st_com)
    if e ~= 0 then return e end
    e = hydro_qmax_o(q, Hh, c, o, sub(r, "qmax"), nil)
    if e ~= 0 then return e end
    if st_com.hm > c.hm_ratio * st_com.hf then
        r.warn = warn_set(r.warn, W_HM_HIGH)
        r.vp = hydro_vp(Hh, st_com.hf, q.sumK, c)
    end
    return H_OK
end
H.hydro_design_o = hydro_design_o

function H.hydro_design(p, Qd, Hh, list, n, c, r, lg)
    return hydro_design_o(p, Qd, Hh, list, n, c, nil, r, lg)
end

-- ------------------------------------------------------------------
-- Tipo E: calibracion
-- ------------------------------------------------------------------
function H.hydro_calibrate(D, L, Q, sumK, dz, dp, c, r)
    r.warn = 0
    if not (D > 0) then return H_ERR_D end
    if not (L > 0) then return H_ERR_L end
    if not (Q > 0) then return H_ERR_Q end
    if not (sumK >= 0) then return H_ERR_K end
    if not (c.nu > 0) then return H_ERR_NU end
    r.A = hydro_area(D)
    r.v = Q / r.A
    r.hm = sumK * r.v * r.v / (2.0 * c.g)
    r.htot = dz + dp
    r.hf = r.htot - r.hm
    r.Re = r.v * D / c.nu
    if not (r.hf > 0) then return H_ERR_HF_NEG end
    r.f = 2.0 * c.g * D * r.hf / (L * r.v * r.v)
    local sf = sqrt(r.f)
    r.ks = 3.7 * D * (10.0 ^ (-1.0 / (2.0 * sf)) - 2.51 / (r.Re * sf))
    r.ksD = r.ks / D
    if r.Re < c.re_lam then
        r.warn = warn_set(r.warn, W_LAMINAR)
    elseif r.Re <= c.re_turb then
        r.warn = warn_set(r.warn, W_TRANSITION)
    end
    if r.ks < 0 then
        r.warn = warn_set(r.warn, W_KS_NEG)
        return H_ERR_KS_NEG
    end
    if r.ksD > 0.05 then r.warn = warn_set(r.warn, W_KSD_RANGE) end
    return H_OK
end

-- ------------------------------------------------------------------
-- Tipo F: valvula de control
-- ------------------------------------------------------------------
function H.hydro_valve(p, Q, Ha, c, r)
    local st = sub(r, "st")
    local e = hydro_pipe_state(p, Q, c, st)
    if e ~= 0 then return e end
    r.hv = Ha - st.hT
    r.Kv = 2.0 * c.g * r.hv / (st.v * st.v)
    if r.hv < 0 then return H_ERR_HV_NEG end
    return H_OK
end

-- ------------------------------------------------------------------
-- Tipo I: Hazen-Williams
-- ------------------------------------------------------------------
hydro_hw_hf = function(Q, D, L, CH)
    if not (Q > 0 and D > 0 and L > 0 and CH > 0) then return 0 end
    return 10.675 * L * Q ^ 1.852 / (CH ^ 1.852 * D ^ 4.87)
end
H.hydro_hw_hf = hydro_hw_hf

function H.hydro_hw_q(Hh, D, L, CH)
    if not (Hh > 0 and D > 0 and L > 0 and CH > 0) then return 0 end
    return (Hh * CH ^ 1.852 * D ^ 4.87 / (10.675 * L)) ^ (1.0 / 1.852)
end

-- ------------------------------------------------------------------
-- Presion en un punto. -> p, warn
-- ------------------------------------------------------------------
function H.hydro_pressure_head(head_up, HB, v, h_loss, c, warn)
    local p = head_up + HB - v * v / (2.0 * c.g) - h_loss
    if warn then
        if p < 0 then warn = warn_set(warn, W_P_NEG) end
        if p < -101325.0 / c.gamma then warn = warn_set(warn, W_CAVIT) end
    end
    return p, warn
end

-- ------------------------------------------------------------------
-- Tipo G: redes en serie y paralelo (indices de nodo de base 1)
-- ------------------------------------------------------------------
local function hydro_module_coef(c)
    return 8.0 / (PI * PI * c.g)
end
H.hydro_module_coef = hydro_module_coef

function H.hydro_net_init(n)
    n.n = 0
    n.root = 0
    n.node = n.node or {}
    n.outer_iters = 0
    n.res_q = 0
    n.res_h = 0
end

function H.hydro_net_add_pipe(n, L, D, f, ks, sumK)
    if n.n >= NET_MAX then return -1 end
    local idx = n.n + 1
    local nd = {}
    n.node[idx] = nd
    nd.type = NODE_PIPE
    nd.nchild = 0
    nd.child = {}
    nd.pipe = { L = L, D = D, f_fixed = f, ks = ks, sumK = sumK }
    nd.f = f
    nd.M, nd.Mf, nd.Mk, nd.Q, nd.h = 0, 0, 0, 0, 0
    n.root = idx
    n.n = idx
    return idx
end

function H.hydro_net_add_group(n, type, kids, nk)
    if n.n >= NET_MAX or nk == 0 or nk > NET_MAX_CHILD or
        (type ~= NODE_SERIES and type ~= NODE_PARALLEL) then
        return -1
    end
    for i = 1, nk do
        if not (kids[i] >= 1 and kids[i] <= n.n) then return -1 end
    end
    local idx = n.n + 1
    local nd = {}
    n.node[idx] = nd
    nd.type = type
    nd.nchild = nk
    nd.child = {}
    for i = 1, nk do nd.child[i] = kids[i] end
    nd.M, nd.Mf, nd.Mk, nd.Q, nd.h, nd.f = 0, 0, 0, 0, 0, 0
    n.root = idx
    n.n = idx
    return idx
end

-- Modulo de cada nodo; devuelve error si algo no cuadra
local function net_reduce(n, idx, c, depth)
    local nd = n.node[idx]
    if depth > NET_MAX then return H_ERR_NET end
    if nd.type == NODE_PIPE then
        local D = nd.pipe.D
        local k0 = hydro_module_coef(c)
        nd.Mf = k0 * nd.f * nd.pipe.L / (D * D * D * D * D)
        nd.Mk = k0 * nd.pipe.sumK / (D * D * D * D)
        nd.M = nd.Mf + nd.Mk
        return H_OK
    end
    local s = 0
    for i = 1, nd.nchild do
        local e = net_reduce(n, nd.child[i], c, depth + 1)
        if e ~= 0 then return e end
        if nd.type == NODE_SERIES then
            s = s + n.node[nd.child[i]].M
        else
            if not (n.node[nd.child[i]].M > 0) then return H_ERR_NET end
            s = s + 1.0 / sqrt(n.node[nd.child[i]].M)
        end
    end
    nd.M = (nd.type == NODE_SERIES) and s or (1.0 / (s * s))
    return H_OK
end

local function net_distribute(n, idx, Q, depth)
    local nd = n.node[idx]
    nd.Q = Q
    nd.h = nd.M * Q * Q
    if nd.type == NODE_PIPE or depth > NET_MAX then return end
    local sq, sh, d = 0, 0, 0
    for i = 1, nd.nchild do
        local ch = n.node[nd.child[i]]
        if nd.type == NODE_SERIES then
            net_distribute(n, nd.child[i], Q, depth + 1)
        else
            net_distribute(n, nd.child[i], sqrt(nd.h / ch.M), depth + 1)
        end
        sq = sq + ch.Q
        sh = sh + ch.h
        if nd.type == NODE_PARALLEL then
            d = abs(ch.h - nd.h)
            if d > n.res_h then n.res_h = d end
        end
    end
    if nd.type == NODE_SERIES then
        d = abs(sh - nd.h)
        if d > n.res_h then n.res_h = d end
    else
        d = abs(sq - nd.Q)
        if d > n.res_q then n.res_q = d end
    end
end

local function hydro_net_solve(n, Hh, c)
    local autof = false
    local e

    if n.n == 0 then return H_ERR_NET end
    if not (Hh > 0) then return H_ERR_NOFLOW end
    for i = 1, n.n do
        local nd = n.node[i]
        if nd.type == NODE_PIPE then
            e = hydro_check_pipe(nd.pipe, c)
            if e ~= 0 then return e end
            if nd.pipe.f_fixed > 0 then
                nd.f = nd.pipe.f_fixed
            else
                nd.f = 0.02
                autof = true
            end
        end
    end
    local it = 1
    local fr = {}
    while it <= 50 do
        n.res_q = 0
        n.res_h = 0
        e = net_reduce(n, n.root, c, 0)
        if e ~= 0 then return e end
        local Q = sqrt(Hh / n.node[n.root].M)
        net_distribute(n, n.root, Q, 0)
        n.outer_iters = it
        if not autof then break end
        local ch = 0
        for i = 1, n.n do
            local nd = n.node[i]
            if nd.type == NODE_PIPE and not (nd.pipe.f_fixed > 0) then
                e = hydro_friction(nd.Q / hydro_area(nd.pipe.D) * nd.pipe.D /
                                   c.nu, nd.pipe.ks / nd.pipe.D, c.method,
                                   c, fr)
                if e ~= 0 then return e end
                local fnew = fr.f
                if abs(fnew - nd.f) > ch * nd.f then
                    ch = abs(fnew - nd.f) / nd.f
                end
                nd.f = fnew
            end
        end
        if ch <= 10.0 * EPS_REL then break end
        it = it + 1
    end
    if autof and it > 50 then return H_ERR_NOCONV end
    return H_OK
end
H.hydro_net_solve = hydro_net_solve

-- -> err, H
function H.hydro_net_solve_back(n, k, Qk, c)
    local h = 1.0
    if not (k >= 1 and k <= n.n) then return H_ERR_NET end
    if not (Qk > 0) then return H_ERR_Q end
    for it = 0, 49 do
        local e = hydro_net_solve(n, h, c)
        if e ~= 0 then return e end
        local q = n.node[k].Q
        if not (q > 0) then return H_ERR_NET end
        if it > 0 and abs(q - Qk) <= 10.0 * EPS_REL * Qk then break end
        h = h * (Qk / q) * (Qk / q)
    end
    return H_OK, h
end

-- ------------------------------------------------------------------
-- Textos
-- ------------------------------------------------------------------
local err_txt = {
    [0] = "OK",
    "D debe ser mayor que 0",
    "L debe ser mayor que 0",
    "Q debe ser mayor que 0",
    "nu debe ser mayor que 0",
    "ks no puede ser negativo",
    "Suma K no puede ser negativa",
    "H <= 0: no hay flujo por gravedad",
    "Eficiencia debe estar en (0, 1]",
    "No convergio",
    "Sin solucion en el rango buscado",
    "ks calculado negativo: datos inconsistentes",
    "Carga insuficiente: hace falta bomba",
    "Carga neta <= 0",
    "hf <= 0: revisar datos",
    "Ningun diametro de la lista alcanza",
    "Sistema mal definido",
    "C_H debe ser mayor que 0",
    "Dato invalido: revise los valores",
    "W <= B: el cuerpo flota, no cae",
    "Fr1 <= 1: no hay salto hidraulico",
}

function H.hydro_err_text(err)
    if err < 0 or err >= H_ERR_COUNT then return "Error" end
    return err_txt[err]
end

function H.hydro_method_name(m)
    if m == FM_SJ then return "Swamee-Jain"
    elseif m == FM_HAALAND then return "Haaland"
    elseif m == 3 then return "Goudar-Sonnad"
    end
    return "Colebrook-White"
end

return H
