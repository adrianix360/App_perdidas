/*
 * weir.c - Ver weir.h
 */
#include "weir.h"

#define DEG2RAD ((real)0.01745329251994)

int weir_check(const weir_el *e)
{
    if (e->type >= WE_COUNT || e->count < 1 || !(e->Cd > 0) ||
        !(e->a > 0) || e->ncon > 2)
        return H_ERR_ARG;
    if (e->type == WE_TRI && !(e->a < 180))
        return H_ERR_ARG;
    if (e->type == WE_ORR && !(e->b > 0))
        return H_ERR_ARG;
    if ((e->type == WE_TRI || e->type == WE_RECT) && !(e->b >= 0))
        return H_ERR_ARG;
    return H_OK;
}

/* coeficiente K tal que Q = K H^p (sin Francis), para el inverso */
static real weir_k(const weir_el *e, real g)
{
    real s = R_SQRT(2.0 * g) * e->Cd * e->count;
    if (e->type == WE_TRI)
        return s * (8.0 / 15.0) * R_TAN(0.5 * e->a * DEG2RAD);
    return s * (2.0 / 3.0) * e->a;
}

real weir_q(const weir_el *e, real h, real g, real *H, unsigned int *warn)
{
    real hc = h - e->z, s, A, be, half;
    *H = 0;
    if (!(hc > 0)) {
        *warn |= VW_DRY;
        return 0;
    }
    *H = hc;
    s = R_SQRT(2.0 * g);
    switch (e->type) {
    case WE_TRI:
        if (e->b > 0 && hc > e->b)
            *warn |= VW_HIGH;
        return weir_k(e, g) * hc * hc * R_SQRT(hc);
    case WE_RECT:
        if (e->b > 0 && hc > e->b)
            *warn |= VW_HIGH;
        be = e->a;
        if (e->ncon) {
            *warn |= VW_FRANCIS;
            be -= 0.1 * e->ncon * hc;
            if (!(be > 0)) {
                *warn |= VW_BE_NEG;
                return 0;
            }
        }
        return e->Cd * e->count * (2.0 / 3.0) * s * be * hc * R_SQRT(hc);
    default:
        if (e->type == WE_ORC) {
            A = hydro_area(e->a);
            half = 0.5 * e->a;
        } else {
            A = e->a * e->b;
            half = 0.5 * e->b;
        }
        if (hc < half)
            *warn |= VW_PARTIAL;
        return e->Cd * e->count * A * s * R_SQRT(hc);
    }
}

int weir_total(const weir_el *e, unsigned char n, real h, real g,
               real *Q, real *Qi, unsigned int *warn)
{
    unsigned char i;
    real q, H;
    *Q = 0;
    if (n < 1 || n > WEIR_MAX || !(g > 0))
        return H_ERR_ARG;
    for (i = 0; i < n; i++)
        if (weir_check(&e[i]))
            return H_ERR_ARG;
    for (i = 0; i < n; i++) {
        q = weir_q(&e[i], h, g, &H, warn);
        if (Qi)
            Qi[i] = q;
        *Q += q;
    }
    return H_OK;
}

int weir_level(const weir_el *e, unsigned char n, real Q, real g,
               real *h, real *Qi, unsigned int *warn, int *iters)
{
    unsigned char i;
    real lo, hi, mid, q, zmin;
    unsigned int w;
    int k;

    *iters = 0;
    if (n < 1 || n > WEIR_MAX || !(g > 0))
        return H_ERR_ARG;
    for (i = 0; i < n; i++)
        if (weir_check(&e[i]))
            return H_ERR_ARG;
    if (!(Q > 0))
        return H_ERR_Q;
    if (n == 1 && (e->type == WE_TRI || (e->type == WE_RECT && !e->ncon))) {
        /* formula cerrada: H = (Q / K)^(1/p) */
        q = Q / weir_k(e, g);
        *h = e->z + R_POW(q, (e->type == WE_TRI) ? 0.4 : (real)(2.0 / 3.0));
        return weir_total(e, 1, *h, g, &q, Qi, warn);
    }
    zmin = e[0].z;
    for (i = 1; i < n; i++)
        if (e[i].z < zmin)
            zmin = e[i].z;
    lo = zmin;
    hi = zmin + 1.0;
    for (k = 0; k < 40; k++) {
        w = 0;
        weir_total(e, n, hi, g, &q, 0, &w);
        if (q >= Q)
            break;
        lo = hi;
        hi = zmin + 2.0 * (hi - zmin);
    }
    if (k == 40)
        return H_ERR_NOROOT;
    for (k = 0; k < 200; k++) {
        mid = 0.5 * (lo + hi);
        w = 0;
        weir_total(e, n, mid, g, &q, 0, &w);
        if (q > Q)
            hi = mid;
        else
            lo = mid;
        if (hi - lo <= HYDRO_BIS_REL * (R_FABS(hi) + 1e-3))
            break;
    }
    *iters = k + 1;
    *h = 0.5 * (lo + hi);
    return weir_total(e, n, *h, g, &q, Qi, warn);
}

int weir_profile_pow(real k, real n, real b, real h, real *Q, real *vm)
{
    if (!(k > 0) || !(n >= 0) || !(b > 0) || !(h > 0))
        return H_ERR_ARG;
    *Q = b * k * R_POW(h, n + 1.0) / (n + 1.0);
    *vm = *Q / (b * h);
    return H_OK;
}

int weir_profile_pts(const real *y, const real *v, unsigned char n, real b,
                     real *Q, real *vm, unsigned char *simpson)
{
    unsigned char i, eq = 1;
    real s = 0, dy, hgt;
    if (n < 2 || !(b > 0))
        return H_ERR_ARG;
    for (i = 1; i < n; i++)
        if (!(y[i] > y[i - 1]))
            return H_ERR_ARG;
    dy = (y[n - 1] - y[0]) / (n - 1);
    for (i = 1; i < n; i++)
        if (R_FABS(y[i] - y[i - 1] - dy) > 1e-4 * dy)
            eq = 0;
    *simpson = (unsigned char)(eq && n >= 3 && (n & 1));
    if (*simpson) {
        for (i = 0; i < n; i++)
            s += v[i] * ((i == 0 || i == n - 1) ? 1 : (i & 1) ? 4 : 2);
        s *= dy / 3.0;
    } else {
        for (i = 1; i < n; i++)
            s += 0.5 * (v[i] + v[i - 1]) * (y[i] - y[i - 1]);
    }
    *Q = b * s;
    hgt = y[n - 1] - y[0];
    *vm = *Q / (b * hgt);
    return H_OK;
}

int weir_section(real Q, real b, real h, real g, real *v, real *E)
{
    if (!(Q > 0) || !(b > 0) || !(h > 0) || !(g > 0))
        return H_ERR_ARG;
    *v = Q / (b * h);
    *E = h + *v * *v / (2.0 * g);
    return H_OK;
}

/* biseccion de E(h) - E en [lo, hi] (E(h) es monotona en cada rama) */
static real alt_bis(real q, real E, real g, real lo, real hi)
{
    unsigned char k;
    real m, f0 = lo + q * q / (2.0 * g * lo * lo) - E, fm;
    for (k = 0; k < 80; k++) {
        m = 0.5 * (lo + hi);
        fm = m + q * q / (2.0 * g * m * m) - E;
        if ((fm > 0) == (f0 > 0)) {
            lo = m;
            f0 = fm;
        } else {
            hi = m;
        }
    }
    return 0.5 * (lo + hi);
}

int weir_alt_depths(real q, real E, real g, real *hsub, real *hsup, real *hc)
{
    if (!(q > 0) || !(E > 0) || !(g > 0))
        return H_ERR_ARG;
    *hc = R_POW(q * q / g, (real)(1.0 / 3.0));
    if (E < 1.5 * *hc)
        return H_ERR_NOROOT;
    *hsub = alt_bis(q, E, g, *hc, E);              /* rama lenta  */
    *hsup = alt_bis(q, E, g, *hc * 1e-3, *hc);     /* rama rapida */
    return H_OK;
}
