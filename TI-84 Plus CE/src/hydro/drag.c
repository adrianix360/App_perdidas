/*
 * drag.c - Ver drag.h
 */
#include "drag.h"

real drag_q(real rho, real V)
{
    return 0.5 * rho * V * V;
}

real drag_force(real rho, real C, real A, real V)
{
    return drag_q(rho, V) * C * A;
}

real drag_re(real V, real L, real nu)
{
    return (nu > 0) ? R_FABS(V) * L / nu : 0;
}

unsigned int drag_re_warn(real Re, unsigned char kind)
{
    unsigned int w = 0;
    if (Re < 1.0)
        w |= DW_STOKES;
    if (Re < 1.0e4)
        w |= DW_RE_LOW;
    if ((kind == DK_SPHERE && Re > 2.0e5) ||
        (kind == DK_LONGCYL && Re > 5.0e5))
        w |= DW_CRISIS;
    return w;
}

real drag_interp(const real *x, const real *y, unsigned char n, real xv,
                 unsigned char *i0, unsigned int *warn)
{
    unsigned char i;
    if (xv <= x[0]) {
        *i0 = 0;
        if (xv < x[0])
            *warn |= DW_CLAMP;
        return y[0];
    }
    if (xv >= x[n - 1]) {
        *i0 = (unsigned char)(n - 2);
        if (xv > x[n - 1])
            *warn |= DW_CLAMP;
        return y[n - 1];
    }
    for (i = 0; i + 2 < n && xv > x[i + 1]; i++)
        ;
    *i0 = i;
    *warn |= DW_INTERP;
    return y[i] + (y[i + 1] - y[i]) * (xv - x[i]) / (x[i + 1] - x[i]);
}

int drag_terminal(real W, real rho, real vol, real Cd, real A, real Lref,
                  real nu, real g, unsigned char kind, drag_term_res *r)
{
    r->warn = 0;
    r->v = r->Re = 0;
    if (!(W > 0) || !(rho > 0) || !(Cd > 0) || !(A > 0) || !(vol >= 0) ||
        !(g > 0))
        return H_ERR_ARG;
    r->B = rho * g * vol;
    if (vol > 0)
        r->warn |= DW_BUOY;
    r->net = W - r->B;
    if (!(r->net > 0))
        return H_ERR_FLOATS;
    r->v = R_SQRT(2.0 * r->net / (rho * Cd * A));
    r->Re = drag_re(r->v, Lref, nu);
    r->warn |= drag_re_warn(r->Re, kind);
    return H_OK;
}

int drag_struct(const drag_body *b, unsigned char n, real rho, real nu,
                drag_struct_res *r)
{
    unsigned char i;
    r->Ftot = r->M = r->ycp = 0;
    r->warn = 0;
    if (n < 1 || n > DRAG_BODIES || !(rho > 0))
        return H_ERR_ARG;
    for (i = 0; i < n; i++) {
        if (!(b[i].Cd >= 0) || !(b[i].A >= 0))
            return H_ERR_ARG;
        r->F[i] = drag_force(rho, b[i].Cd, b[i].A, b[i].V);
        r->Re[i] = drag_re(b[i].V, b[i].Lref, nu);
        r->w[i] = drag_re_warn(r->Re[i], b[i].kind);
        r->warn |= r->w[i];
        r->Ftot += r->F[i];
        r->M += r->F[i] * b[i].y;
    }
    if (r->Ftot > 0)
        r->ycp = r->M / r->Ftot;
    return H_OK;
}

real drag_rho_alt(real h)
{
    real t = 1.0 - 2.26e-5 * h;
    return (t > 0) ? 1.3 * R_POW(t, 4.256) : 0;
}

int drag_plane_lift(real W, real rho, real V, real Aw, unsigned char nw,
                    drag_plane_res *r)
{
    if (!(W > 0) || !(rho > 0) || !(V > 0) || !(Aw > 0) || nw < 1)
        return H_ERR_ARG;
    r->q = drag_q(rho, V);
    r->Atot = Aw * nw;
    r->CL = W / (r->q * r->Atot);
    return H_OK;
}

int drag_plane_thrust(real W, real rho, real V, real CDw, real CDf,
                      real Df, real CLmax, drag_plane_res *r)
{
    if (!(CDw >= 0) || !(CDf >= 0) || !(Df >= 0) || !(r->Atot > 0))
        return H_ERR_ARG;
    r->Afus = hydro_area(Df);
    r->Dw = r->q * r->Atot * CDw;
    r->Df = r->q * CDf * r->Afus;
    r->T = r->Dw + r->Df;
    r->P = r->T * V;
    r->Vst = (CLmax > 0) ? R_SQRT(2.0 * W / (rho * CLmax * r->Atot)) : 0;
    return H_OK;
}

real drag_stokes(real mu, real V, real D)
{
    return 3.0 * HYDRO_PI * mu * V * D;
}

int drag_plate(real L, real w, real V, real rho, real nu,
               unsigned char faces, unsigned char mode, drag_plate_res *r)
{
    r->warn = 0;
    if (!(L > 0) || !(w > 0) || !(V > 0) || !(rho > 0) || !(nu > 0) ||
        faces < 1 || faces > 2 || mode > PL_MIX)
        return H_ERR_ARG;
    r->Re = V * L / nu;
    r->Cf_lam = 1.328 / R_SQRT(r->Re);
    r->Cf_turb = 0.074 / R_POW(r->Re, 0.2);
    r->Cf_mix = r->Cf_turb - 1742.0 / r->Re;
    if (r->Re > 5.0e5)
        r->warn |= DW_LAM_NA;
    if (r->Re > 1.0e7)
        r->warn |= DW_TURB_NA;
    if (mode == PL_AUTO)
        mode = (r->Re < 5.0e5) ? PL_LAM : PL_TURB;
    r->regime = mode;
    r->Cf = (mode == PL_LAM) ? r->Cf_lam :
            (mode == PL_MIX) ? r->Cf_mix : r->Cf_turb;
    r->A = L * w;
    r->F = r->Cf * drag_q(rho, V) * r->A * faces;
    return H_OK;
}
