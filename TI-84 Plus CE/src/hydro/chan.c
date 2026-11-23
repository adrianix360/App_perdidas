/*
 * chan.c - Ver chan.h
 */
#include "chan.h"

#define DEG2RAD ((real)0.01745329251994)

int chan_venturi(real D1, real D2, real Q, real Cv, real S,
                 unsigned char conv, const hydro_cfg *c,
                 chan_venturi_res *r)
{
    real b4, u, rho;
    if (!(D1 > 0) || !(D2 > 0) || !(D2 < D1) || !(Q > 0) || !(Cv > 0) ||
        !(Cv <= 1) || !(S >= 0) || conv > MANO_EXAM)
        return H_ERR_ARG;
    rho = c->gamma / c->g;
    r->A1 = hydro_area(D1);
    r->A2 = hydro_area(D2);
    r->v1 = Q / r->A1;
    r->v2 = Q / r->A2;
    r->beta = D2 / D1;
    b4 = r->beta * r->beta * r->beta * r->beta;
    u = Q / (Cv * r->A2);
    r->dp = 0.5 * rho * u * u * (1.0 - b4);
    r->h = 0;
    if (S > 0) {
        u = (conv == MANO_EXAM) ? S : S - 1.0;
        if (!(u > 0))
            return H_ERR_ARG;
        r->h = r->dp / (u * c->gamma);
    }
    return H_OK;
}

int chan_jump(real Q, real b, real y, unsigned char from_y2,
              const hydro_cfg *c, chan_jump_res *r)
{
    real g = c->g, v, Fr;
    if (!(Q > 0) || !(b > 0) || !(y > 0))
        return H_ERR_ARG;
    r->q = Q / b;
    v = r->q / y;
    Fr = v / R_SQRT(g * y);
    if (!from_y2) {
        if (!(Fr > 1))
            return H_ERR_NOJUMP;
        r->y1 = y;
        r->y2 = 0.5 * y * (R_SQRT(1.0 + 8.0 * Fr * Fr) - 1.0);
    } else {
        if (!(Fr < 1))
            return H_ERR_NOJUMP;
        r->y2 = y;
        r->y1 = 0.5 * y * (R_SQRT(1.0 + 8.0 * Fr * Fr) - 1.0);
    }
    r->v1 = r->q / r->y1;
    r->v2 = r->q / r->y2;
    r->Fr1 = r->v1 / R_SQRT(g * r->y1);
    r->Fr2 = r->v2 / R_SQRT(g * r->y2);
    r->E1 = r->y1 + r->v1 * r->v1 / (2.0 * g);
    r->E2 = r->y2 + r->v2 * r->v2 / (2.0 * g);
    r->dE = r->E1 - r->E2;
    r->P = c->gamma * Q * r->dE;
    r->eff = r->E2 / r->E1;
    return H_OK;
}

int chan_jet(real v, real theta, real g, chan_jet_res *r)
{
    real a = theta * DEG2RAD, s;
    if (!(v > 0) || !(g > 0) || !(theta >= 0) || !(theta <= 90))
        return H_ERR_ARG;
    s = R_SIN(a);
    r->vx = v * R_COS(a);
    r->vy = v * s;
    r->hmax = r->vy * r->vy / (2.0 * g);
    r->R = 2.0 * r->vx * r->vy / g;
    r->t = 2.0 * r->vy / g;
    return H_OK;
}
