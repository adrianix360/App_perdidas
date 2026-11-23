--[[
weir.lua - Vertedores y orificios (v2.0). Puerto 1:1 de src/hydro/weir.c.
Cotas desde un mismo nivel de referencia. Convenciones del puerto: ver
core/hydro.lua (err primero; listas de base 1; avisos con warn_set/warn_has).

API PUBLICA
  Constantes: WE_TRI WE_RECT WE_ORC WE_ORR WE_COUNT; VW_PARTIAL VW_DRY
    VW_HIGH VW_FRANCIS VW_BE_NEG; WEIR_MAX.
  Elemento e = {type, count, ncon, Cd, z, a, b} (campos como en weir_el de C).
  weir_check(e) -> err
  weir_q(e, h, g, warn) -> q, H, warn            (q ya multiplicado por count)
  weir_total(e, n, h, g, warn) -> err, Q, Qi, warn
        e = lista Lua de n elementos; Qi[i] caudal por elemento
  weir_level(e, n, Q, g, warn, lg) -> err, h, Qi, warn, iters
        (h y Qi solo validos si err = 0; lg opcional = registro de biseccion)
  weir_profile_pow(k, n, b, h) -> err, Q, vm
  weir_profile_pts(y, v, n, b) -> err, Q, vm, simpson (0/1)
        y, v = listas Lua (base 1) de n puntos
  weir_section(Q, b, h, g) -> err, v, E
  weir_alt_depths(q, E, g) -> err, hsub, hsup, hc
]]

local H = require("core.hydro")

local W = {}

local sqrt, abs, tan = math.sqrt, math.abs, math.tan
local warn_set = H.warn_set
local H_OK, H_ERR_ARG, H_ERR_Q, H_ERR_NOROOT = H.H_OK, H.H_ERR_ARG, H.H_ERR_Q, H.H_ERR_NOROOT
local BIS_REL = H.HYDRO_BIS_REL
local log_row, log_clear = H.hydro_log_row, H.hydro_log_clear

local DEG2RAD = 0.01745329251994

W.WE_TRI, W.WE_RECT, W.WE_ORC, W.WE_ORR, W.WE_COUNT = 0, 1, 2, 3, 4
local WE_TRI, WE_RECT, WE_ORC, WE_ORR, WE_COUNT = 0, 1, 2, 3, 4
W.VW_PARTIAL, W.VW_DRY, W.VW_HIGH, W.VW_FRANCIS, W.VW_BE_NEG = 1, 2, 4, 8, 16
local VW_PARTIAL, VW_DRY, VW_HIGH, VW_FRANCIS, VW_BE_NEG = 1, 2, 4, 8, 16
W.WEIR_MAX = 8
local WEIR_MAX = 8

local function weir_check(e)
    if e.type >= WE_COUNT or e.count < 1 or not (e.Cd > 0) or
        not (e.a > 0) or e.ncon > 2 then
        return H_ERR_ARG
    end
    if e.type == WE_TRI and not (e.a < 180) then return H_ERR_ARG end
    if e.type == WE_ORR and not (e.b > 0) then return H_ERR_ARG end
    if (e.type == WE_TRI or e.type == WE_RECT) and not (e.b >= 0) then
        return H_ERR_ARG
    end
    return H_OK
end
W.weir_check = weir_check

-- coeficiente K tal que Q = K H^p (sin Francis), para el inverso
local function weir_k(e, g)
    local s = sqrt(2.0 * g) * e.Cd * e.count
    if e.type == WE_TRI then
        return s * (8.0 / 15.0) * tan(0.5 * e.a * DEG2RAD)
    end
    return s * (2.0 / 3.0) * e.a
end

-- -> q, H, warn
local function weir_q(e, h, g, warn)
    local hc = h - e.z
    warn = warn or 0
    if not (hc > 0) then
        return 0, 0, warn_set(warn, VW_DRY)
    end
    local s = sqrt(2.0 * g)
    if e.type == WE_TRI then
        if e.b > 0 and hc > e.b then warn = warn_set(warn, VW_HIGH) end
        return weir_k(e, g) * hc * hc * sqrt(hc), hc, warn
    elseif e.type == WE_RECT then
        if e.b > 0 and hc > e.b then warn = warn_set(warn, VW_HIGH) end
        local be = e.a
        if e.ncon ~= 0 then
            warn = warn_set(warn, VW_FRANCIS)
            be = be - 0.1 * e.ncon * hc
            if not (be > 0) then
                return 0, hc, warn_set(warn, VW_BE_NEG)
            end
        end
        return e.Cd * e.count * (2.0 / 3.0) * s * be * hc * sqrt(hc), hc, warn
    else
        local A, half
        if e.type == WE_ORC then
            A = H.hydro_area(e.a)
            half = 0.5 * e.a
        else
            A = e.a * e.b
            half = 0.5 * e.b
        end
        if hc < half then warn = warn_set(warn, VW_PARTIAL) end
        return e.Cd * e.count * A * s * sqrt(hc), hc, warn
    end
end
W.weir_q = weir_q

-- -> err, Q, Qi, warn
local function weir_total(e, n, h, g, warn)
    local Q = 0
    local Qi = {}
    warn = warn or 0
    if n < 1 or n > WEIR_MAX or not (g > 0) then
        return H_ERR_ARG, Q, Qi, warn
    end
    for i = 1, n do
        if weir_check(e[i]) ~= 0 then return H_ERR_ARG, Q, Qi, warn end
    end
    for i = 1, n do
        local q, hh
        q, hh, warn = weir_q(e[i], h, g, warn)
        Qi[i] = q
        Q = Q + q
    end
    return H_OK, Q, Qi, warn
end
W.weir_total = weir_total

-- -> err, h, Qi, warn, iters
function W.weir_level(e, n, Q, g, warn, lg)
    local iters = 0
    warn = warn or 0
    log_clear(lg)
    if n < 1 or n > WEIR_MAX or not (g > 0) then
        return H_ERR_ARG, nil, nil, warn, iters
    end
    for i = 1, n do
        if weir_check(e[i]) ~= 0 then return H_ERR_ARG, nil, nil, warn, iters end
    end
    if not (Q > 0) then return H_ERR_Q, nil, nil, warn, iters end
    if n == 1 and (e[1].type == WE_TRI or (e[1].type == WE_RECT and e[1].ncon == 0)) then
        -- formula cerrada: H = (Q / K)^(1/p)
        local q = Q / weir_k(e[1], g)
        local h = e[1].z + q ^ ((e[1].type == WE_TRI) and 0.4 or (2.0 / 3.0))
        local err, _, Qi, w2 = weir_total(e, 1, h, g, warn)
        return err, h, Qi, w2, iters
    end
    local zmin = e[1].z
    for i = 2, n do
        if e[i].z < zmin then zmin = e[i].z end
    end
    local lo = zmin
    local hi = zmin + 1.0
    local q = 0
    local k = 0
    while k < 40 do
        local _
        _, q = weir_total(e, n, hi, g, 0)
        if q >= Q then break end
        lo = hi
        hi = zmin + 2.0 * (hi - zmin)
        k = k + 1
    end
    if k == 40 then return H_ERR_NOROOT, nil, nil, warn, iters end
    log_row(lg, 0, lo, hi, hi, q - Q)
    k = 0
    while k < 200 do
        local mid = 0.5 * (lo + hi)
        local _
        _, q = weir_total(e, n, mid, g, 0)
        log_row(lg, k + 1, lo, hi, mid, q - Q)
        if q > Q then hi = mid else lo = mid end
        if hi - lo <= BIS_REL * (abs(hi) + 1e-3) then break end
        k = k + 1
    end
    iters = k + 1
    local h = 0.5 * (lo + hi)
    local err, _, Qi, w2 = weir_total(e, n, h, g, warn)
    return err, h, Qi, w2, iters
end

-- -> err, Q, vm
function W.weir_profile_pow(k, n, b, h)
    if not (k > 0) or not (n >= 0) or not (b > 0) or not (h > 0) then
        return H_ERR_ARG
    end
    local Q = b * k * h ^ (n + 1.0) / (n + 1.0)
    return H_OK, Q, Q / (b * h)
end

-- y, v: listas de base 1 con n puntos. -> err, Q, vm, simpson
function W.weir_profile_pts(y, v, n, b)
    local eq = true
    local s = 0
    if n < 2 or not (b > 0) then return H_ERR_ARG end
    for i = 1, n - 1 do
        if not (y[i + 1] > y[i]) then return H_ERR_ARG end
    end
    local dy = (y[n] - y[1]) / (n - 1)
    for i = 1, n - 1 do
        if abs(y[i + 1] - y[i] - dy) > 1e-4 * dy then eq = false end
    end
    local simpson = (eq and n >= 3 and n % 2 == 1) and 1 or 0
    if simpson == 1 then
        for i = 0, n - 1 do
            local w
            if i == 0 or i == n - 1 then w = 1
            elseif i % 2 == 1 then w = 4
            else w = 2 end
            s = s + v[i + 1] * w
        end
        s = s * (dy / 3.0)
    else
        for i = 1, n - 1 do
            s = s + 0.5 * (v[i + 1] + v[i]) * (y[i + 1] - y[i])
        end
    end
    local Q = b * s
    local hgt = y[n] - y[1]
    return H_OK, Q, Q / (b * hgt), simpson
end

-- -> err, v, E
function W.weir_section(Q, b, h, g)
    if not (Q > 0) or not (b > 0) or not (h > 0) or not (g > 0) then
        return H_ERR_ARG
    end
    local v = Q / (b * h)
    return H_OK, v, h + v * v / (2.0 * g)
end

-- biseccion de E(h) - E en [lo, hi] (E(h) es monotona en cada rama)
local function alt_bis(q, E, g, lo, hi)
    local f0 = lo + q * q / (2.0 * g * lo * lo) - E
    for _ = 0, 79 do
        local m = 0.5 * (lo + hi)
        local fm = m + q * q / (2.0 * g * m * m) - E
        if (fm > 0) == (f0 > 0) then
            lo = m
            f0 = fm
        else
            hi = m
        end
    end
    return 0.5 * (lo + hi)
end

-- -> err, hsub, hsup, hc
function W.weir_alt_depths(q, E, g)
    if not (q > 0) or not (E > 0) or not (g > 0) then return H_ERR_ARG end
    local hc = (q * q / g) ^ (1.0 / 3.0)
    if E < 1.5 * hc then return H_ERR_NOROOT, nil, nil, hc end
    local hsub = alt_bis(q, E, g, hc, E)          -- rama lenta
    local hsup = alt_bis(q, E, g, hc * 1e-3, hc)  -- rama rapida
    return H_OK, hsub, hsup, hc
end

return W
