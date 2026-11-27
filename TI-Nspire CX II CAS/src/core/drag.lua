--[[
drag.lua - Arrastre y sustentacion (v2.0). Puerto 1:1 de src/hydro/drag.c.
Todo en SI. Convenciones del puerto: ver core/hydro.lua (estructuras de salida
como tabla `{}`, err devuelto primero, listas de base 1, avisos con
warn_has/warn_set de core.hydro).

API PUBLICA
  Constantes: DW_RE_LOW DW_CRISIS DW_STOKES DW_INTERP DW_CLAMP DW_LAM_NA
    DW_TURB_NA DW_BUOY; DK_GENERIC DK_SPHERE DK_LONGCYL; PL_AUTO PL_LAM
    PL_TURB PL_MIX; DRAG_BODIES.
  drag_q(rho, V), drag_force(rho, C, A, V), drag_re(V, L, nu)
  drag_re_warn(Re, kind) -> warn
  drag_interp(x, y, n, xv, warn) -> valor, i0 (base 1: vecino de abajo), warn
        x, y = listas Lua (base 1) con n puntos, x creciente
  drag_terminal(W, rho, vol, Cd, A, Lref, nu, g, kind, r) -> err
        r: B net v Re warn
  drag_struct(b, n, rho, nu, r) -> err
        b[i] = {Cd, A, y, V, Lref, kind} (i = 1..n, n <= DRAG_BODIES)
        r: F[i] Re[i] w[i] (base 1), Ftot M ycp warn
  drag_rho_alt(h)
  drag_plane_lift(W, rho, V, Aw, nw, r) -> err         r: q Atot CL
  drag_plane_thrust(W, rho, V, CDw, CDf, Df, CLmax, r) -> err
        (usa r.q y r.Atot del paso 1)   r: Afus Dw Df T P Vst
  drag_stokes(mu, V, D)
  drag_plate(L, w, V, rho, nu, faces, mode, r) -> err
        r: Re Cf_lam Cf_turb Cf_mix Cf A F regime warn
  drag_power(F, V) -> P (W);  HP_W = 745.69987 W por hp (potencia de arrastre P = FD V)
  drag_magnus(m, Dm, V, rpm, rho, CL, CD, g, up, r) -> err      (AR-5: esfera con giro)
        CL, CD <= 0 = sin dato; up = true: FL hacia arriba (false: hacia abajo)
        r: W vol B A q SR FL FD Fnet az lift (true si hay CL) rises (Fnet > 0)
]]

local H = require("core.hydro")

local D = {}

local sqrt, abs = math.sqrt, math.abs
local warn_set, warn_has = H.warn_set, H.warn_has
local H_OK, H_ERR_ARG, H_ERR_FLOATS = H.H_OK, H.H_ERR_ARG, H.H_ERR_FLOATS
local PI = H.HYDRO_PI

D.DW_RE_LOW, D.DW_CRISIS, D.DW_STOKES, D.DW_INTERP = 1, 2, 4, 8
D.DW_CLAMP, D.DW_LAM_NA, D.DW_TURB_NA, D.DW_BUOY = 16, 32, 64, 128
local DW_RE_LOW, DW_CRISIS, DW_STOKES, DW_INTERP = 1, 2, 4, 8
local DW_CLAMP, DW_LAM_NA, DW_TURB_NA, DW_BUOY = 16, 32, 64, 128

D.DK_GENERIC, D.DK_SPHERE, D.DK_LONGCYL = 0, 1, 2
local DK_SPHERE, DK_LONGCYL = 1, 2
D.PL_AUTO, D.PL_LAM, D.PL_TURB, D.PL_MIX = 0, 1, 2, 3
local PL_AUTO, PL_LAM, PL_TURB, PL_MIX = 0, 1, 2, 3
D.DRAG_BODIES = 6
local DRAG_BODIES = 6

local function drag_q(rho, V)
    return 0.5 * rho * V * V
end
D.drag_q = drag_q

local function drag_force(rho, C, A, V)
    return drag_q(rho, V) * C * A
end
D.drag_force = drag_force

local function drag_re(V, L, nu)
    return (nu > 0) and (abs(V) * L / nu) or 0
end
D.drag_re = drag_re

local function drag_re_warn(Re, kind)
    local w = 0
    -- tolerancia: Re = 1 exacto cuenta como valido (en double 1.0000000000000002)
    if Re <= 1.0 + 1.0e-9 then w = warn_set(w, DW_STOKES) end
    if Re < 1.0e4 then w = warn_set(w, DW_RE_LOW) end
    if (kind == DK_SPHERE and Re > 2.0e5) or
        (kind == DK_LONGCYL and Re > 5.0e5) then
        w = warn_set(w, DW_CRISIS)
    end
    return w
end
D.drag_re_warn = drag_re_warn

-- -> valor, i0 (base 1), warn
function D.drag_interp(x, y, n, xv, warn)
    warn = warn or 0
    if xv <= x[1] then
        if xv < x[1] then warn = warn_set(warn, DW_CLAMP) end
        return y[1], 1, warn
    end
    if xv >= x[n] then
        if xv > x[n] then warn = warn_set(warn, DW_CLAMP) end
        return y[n], n - 1, warn
    end
    local i = 0 -- base 0 como en C; indices Lua = i + 1
    while i + 2 < n and xv > x[i + 2] do
        i = i + 1
    end
    warn = warn_set(warn, DW_INTERP)
    return y[i + 1] + (y[i + 2] - y[i + 1]) * (xv - x[i + 1]) /
           (x[i + 2] - x[i + 1]), i + 1, warn
end

function D.drag_terminal(W, rho, vol, Cd, A, Lref, nu, g, kind, r)
    r.warn = 0
    r.v = 0
    r.Re = 0
    if not (W > 0) or not (rho > 0) or not (Cd > 0) or not (A > 0) or
        not (vol >= 0) or not (g > 0) then
        return H_ERR_ARG
    end
    r.B = rho * g * vol
    if vol > 0 then r.warn = warn_set(r.warn, DW_BUOY) end
    r.net = W - r.B
    if not (r.net > 0) then return H_ERR_FLOATS end
    r.v = sqrt(2.0 * r.net / (rho * Cd * A))
    r.Re = drag_re(r.v, Lref, nu)
    -- r.warn |= drag_re_warn(...)
    local w = drag_re_warn(r.Re, kind)
    for _, f in ipairs({ DW_RE_LOW, DW_CRISIS, DW_STOKES }) do
        if warn_has(w, f) then r.warn = warn_set(r.warn, f) end
    end
    return H_OK
end

function D.drag_struct(b, n, rho, nu, r)
    r.Ftot, r.M, r.ycp = 0, 0, 0
    r.warn = 0
    r.F, r.Re, r.w = r.F or {}, r.Re or {}, r.w or {}
    if n < 1 or n > DRAG_BODIES or not (rho > 0) then return H_ERR_ARG end
    for i = 1, n do
        if not (b[i].Cd >= 0) or not (b[i].A >= 0) then return H_ERR_ARG end
        r.F[i] = drag_force(rho, b[i].Cd, b[i].A, b[i].V)
        r.Re[i] = drag_re(b[i].V, b[i].Lref, nu)
        r.w[i] = drag_re_warn(r.Re[i], b[i].kind or 0)
        for _, f in ipairs({ DW_RE_LOW, DW_CRISIS, DW_STOKES }) do
            if warn_has(r.w[i], f) then r.warn = warn_set(r.warn, f) end
        end
        r.Ftot = r.Ftot + r.F[i]
        r.M = r.M + r.F[i] * b[i].y
    end
    if r.Ftot > 0 then r.ycp = r.M / r.Ftot end
    return H_OK
end

function D.drag_rho_alt(h)
    local t = 1.0 - 2.26e-5 * h
    return (t > 0) and (1.3 * t ^ 4.256) or 0
end

function D.drag_plane_lift(W, rho, V, Aw, nw, r)
    if not (W > 0) or not (rho > 0) or not (V > 0) or not (Aw > 0) or
        nw < 1 then
        return H_ERR_ARG
    end
    r.q = drag_q(rho, V)
    r.Atot = Aw * nw
    r.CL = W / (r.q * r.Atot)
    return H_OK
end

function D.drag_plane_thrust(W, rho, V, CDw, CDf, Df, CLmax, r)
    if not (CDw >= 0) or not (CDf >= 0) or not (Df >= 0) or
        not ((r.Atot or 0) > 0) then
        return H_ERR_ARG
    end
    r.Afus = H.hydro_area(Df)
    r.Dw = r.q * r.Atot * CDw
    r.Df = r.q * CDf * r.Afus
    r.T = r.Dw + r.Df
    r.P = r.T * V
    r.Vst = (CLmax > 0) and sqrt(2.0 * W / (rho * CLmax * r.Atot)) or 0
    return H_OK
end

function D.drag_stokes(mu, V, Dm)
    return 3.0 * PI * mu * V * Dm
end

function D.drag_plate(L, w, V, rho, nu, faces, mode, r)
    r.warn = 0
    if not (L > 0) or not (w > 0) or not (V > 0) or not (rho > 0) or
        not (nu > 0) or faces < 1 or faces > 2 or mode > PL_MIX then
        return H_ERR_ARG
    end
    r.Re = V * L / nu
    r.Cf_lam = 1.328 / sqrt(r.Re)
    r.Cf_turb = 0.074 / r.Re ^ 0.2
    r.Cf_mix = r.Cf_turb - 1742.0 / r.Re
    if r.Re > 5.0e5 then r.warn = warn_set(r.warn, DW_LAM_NA) end
    if r.Re > 1.0e7 then r.warn = warn_set(r.warn, DW_TURB_NA) end
    if mode == PL_AUTO then
        mode = (r.Re < 5.0e5) and PL_LAM or PL_TURB
    end
    r.regime = mode
    if mode == PL_LAM then
        r.Cf = r.Cf_lam
    elseif mode == PL_MIX then
        r.Cf = r.Cf_mix
    else
        r.Cf = r.Cf_turb
    end
    r.A = L * w
    r.F = r.Cf * drag_q(rho, V) * r.A * faces
    return H_OK
end

D.HP_W = 745.69987
function D.drag_power(F, V) return F * abs(V) end

-- Balance vertical de una esfera con giro (efecto Magnus). SR = omega D / (2 V)
-- es el parametro con el que se lee C_L de la grafica. Fnet > 0 = hacia arriba.
function D.drag_magnus(m, Dm, V, rpm, rho, CL, CD, g, up, r)
    if not (m > 0) or not (Dm > 0) or not (V > 0) or not (rpm >= 0) or
        not (rho >= 0) or not (g > 0) then
        return H_ERR_ARG
    end
    r.W = m * g
    r.vol = PI * Dm * Dm * Dm / 6.0
    r.B = rho * g * r.vol
    r.A = H.hydro_area(Dm)
    r.q = drag_q(rho, V)
    r.SR = rpm * 2.0 * PI / 60.0 * Dm / (2.0 * V)
    r.lift = CL ~= nil and CL > 0
    r.FL = r.lift and (CL * r.q * r.A) or 0
    r.FD = (CD ~= nil and CD > 0) and (CD * r.q * r.A) or 0
    local fl = (up == false) and -r.FL or r.FL
    r.Fnet = fl + r.B - r.W
    r.az = r.Fnet / m
    r.rises = r.Fnet > 0
    return H_OK
end

return D
