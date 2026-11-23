--[[
chan.lua - Canales y medicion (v2.0): Venturi con manometro, salto hidraulico
en canal rectangular y chorro. Puerto 1:1 de src/hydro/chan.c. Todo en SI.
Convenciones del puerto: ver core/hydro.lua (estructura de salida `r` como
tabla `{}`, err devuelto).

API PUBLICA
  Constantes: MANO_PHYS MANO_EXAM
  chan_venturi(D1, D2, Q, Cv, S, conv, c, r) -> err
        r: A1 A2 v1 v2 beta dp h
  chan_jump(Q, b, y, from_y2, c, r) -> err
        from_y2 = 0/1 (o false/true)   r: q y1 y2 v1 v2 Fr1 Fr2 E1 E2 dE P eff
  chan_jet(v, theta, g, r) -> err            r: vx vy hmax R t
]]

local H = require("core.hydro")

local C = {}

local sqrt, sin, cos = math.sqrt, math.sin, math.cos
local H_OK, H_ERR_ARG, H_ERR_NOJUMP = H.H_OK, H.H_ERR_ARG, H.H_ERR_NOJUMP

local DEG2RAD = 0.01745329251994

C.MANO_PHYS, C.MANO_EXAM = 0, 1
local MANO_EXAM = 1

function C.chan_venturi(D1, D2, Q, Cv, S, conv, c, r)
    if not (D1 > 0) or not (D2 > 0) or not (D2 < D1) or not (Q > 0) or
        not (Cv > 0) or not (Cv <= 1) or not (S >= 0) or conv > MANO_EXAM then
        return H_ERR_ARG
    end
    local rho = c.gamma / c.g
    r.A1 = H.hydro_area(D1)
    r.A2 = H.hydro_area(D2)
    r.v1 = Q / r.A1
    r.v2 = Q / r.A2
    r.beta = D2 / D1
    local b4 = r.beta * r.beta * r.beta * r.beta
    local u = Q / (Cv * r.A2)
    r.dp = 0.5 * rho * u * u * (1.0 - b4)
    r.h = 0
    if S > 0 then
        u = (conv == MANO_EXAM) and S or (S - 1.0)
        if not (u > 0) then return H_ERR_ARG end
        r.h = r.dp / (u * c.gamma)
    end
    return H_OK
end

function C.chan_jump(Q, b, y, from_y2, c, r)
    local g = c.g
    if not (Q > 0) or not (b > 0) or not (y > 0) then return H_ERR_ARG end
    r.q = Q / b
    local v = r.q / y
    local Fr = v / sqrt(g * y)
    if not from_y2 or from_y2 == 0 then
        if not (Fr > 1 + 1e-9) then return H_ERR_NOJUMP end
        r.y1 = y
        r.y2 = 0.5 * y * (sqrt(1.0 + 8.0 * Fr * Fr) - 1.0)
    else
        if not (Fr < 1 - 1e-9) then return H_ERR_NOJUMP end
        r.y2 = y
        r.y1 = 0.5 * y * (sqrt(1.0 + 8.0 * Fr * Fr) - 1.0)
    end
    r.v1 = r.q / r.y1
    r.v2 = r.q / r.y2
    r.Fr1 = r.v1 / sqrt(g * r.y1)
    r.Fr2 = r.v2 / sqrt(g * r.y2)
    r.E1 = r.y1 + r.v1 * r.v1 / (2.0 * g)
    r.E2 = r.y2 + r.v2 * r.v2 / (2.0 * g)
    r.dE = r.E1 - r.E2
    r.P = c.gamma * Q * r.dE
    r.eff = r.E2 / r.E1
    return H_OK
end

function C.chan_jet(v, theta, g, r)
    local a = theta * DEG2RAD
    if not (v > 0) or not (g > 0) or not (theta >= 0) or not (theta <= 90) then
        return H_ERR_ARG
    end
    local s = sin(a)
    r.vx = v * cos(a)
    r.vy = v * s
    r.hmax = r.vy * r.vy / (2.0 * g)
    r.R = 2.0 * r.vx * r.vy / g
    r.t = 2.0 * r.vy / g
    return H_OK
end

return C
