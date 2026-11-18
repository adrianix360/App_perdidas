/*
 * hydro.c - Motor hidraulico de la app PERDIDAS (TI-84 Plus CE)
 * Ver hydro.h. Toda iteracion tiene tope; ninguna division sin control.
 */
#include "hydro.h"

/* Coeficiente de Haaland segun el material del curso */
/* v2.1: FLUJOS (chorro EX-3) usa el caudal maximo como en la v2.0; ahi
 * se compila sin la secante ni el arranque de Hazen-Williams, porque en
 * la calculadora cada byte de codigo es RAM. */
#ifdef PROG_FLUJOS
#define ITER_OPT 0
#else
#define ITER_OPT 1
#endif
#if defined(__GNUC__) || defined(__clang__)
#define NOINLINE __attribute__((noinline))
#else
#define NOINLINE
#endif

#ifndef HAALAND_COEF
#define HAALAND_COEF 1.8
#endif

void hydro_cfg_default(hydro_cfg *c)
{
    c->g = 9.81;
    c->gamma = 9810.0;
    c->nu = 1.0e-6;
    c->tol = 1.0e-5;
    c->re_lam = 2000.0;
    c->re_turb = 4000.0;
    c->ld_limit = 4000.0;
    c->v_min = 0.3;
    c->v_max = 5.0;
    c->pv = 2339.0;
    c->hm_ratio = 0.3;
    c->method = FM_CW;
    c->max_iter = 200;
}

void hydro_log_clear(hydro_log *lg)
{
    if (lg) {
        lg->n = 0;
        lg->total = 0;
    }
}

/* Guarda las primeras HYDRO_LOG_MAX/2 filas y, si hay mas, las ultimas
 * HYDRO_LOG_MAX/2 (la memoria de calculo muestra "..." entre ambas). */
static void log_row(hydro_log *lg, real a, real b, real c, real d, real e)
{
    real *r;
    unsigned char k, j;
    if (!lg)
        return;
    lg->total++;
    if (lg->n < HYDRO_LOG_MAX) {
        r = lg->r[lg->n++];
    } else {
        for (k = HYDRO_LOG_MAX / 2; k + 1 < HYDRO_LOG_MAX; k++)
            for (j = 0; j < HYDRO_LOG_COLS; j++)
                lg->r[k][j] = lg->r[k + 1][j];
        r = lg->r[HYDRO_LOG_MAX - 1];
    }
    r[0] = a; r[1] = b; r[2] = c; r[3] = d; r[4] = e;
}

real hydro_area(real D)
{
    return HYDRO_PI * D * D / 4.0;
}

/* ------------------------------------------------------------------ */
/* Factor de friccion                                                  */
/* ------------------------------------------------------------------ */
/* Colebrook-White por sustitucion sucesiva sobre x = 1/sqrt(f),
 * partiendo de f1 = 0,0001 como la hoja del ejemplo 4 de la
 * presentacion (diapositiva 25). Si lg, guarda (i, f_i): la fila 1 es
 * el valor inicial. */
static real cw_iter(real Re, real a, unsigned char *iters, hydro_log *lg)
{
    real x = 100.0, xn;
    unsigned char i;
    hydro_log_clear(lg);
    log_row(lg, 1, 1.0 / (x * x), 0, 0, 0);
    for (i = 1; i <= 60; i++) {
        xn = -2.0 * R_LOG10(a + 2.51 * x / Re);
        *iters = i;
        log_row(lg, (real)(i + 1), 1.0 / (xn * xn), 0, 0, 0);
        if (R_FABS(xn - x) <= HYDRO_EPS_REL * xn) {
            x = xn;
            break;
        }
        x = xn;
    }
    return 1.0 / (x * x);
}

int hydro_friction(real Re, real ksD, unsigned char method,
                   const hydro_cfg *c, hydro_fric *o)
{
    real a, x, t, C;

    o->iters = 0;
    o->f = 0;
    if (!(Re > 0))
        return H_ERR_Q;
    if (!(ksD >= 0))
        return H_ERR_KS;

    if (Re < c->re_lam) {
        o->regime = REG_LAMINAR;
        o->f = 64.0 / Re;
        return H_OK;
    }
    o->regime = (Re <= c->re_turb) ? REG_TRANSITION : REG_TURBULENT;
    a = ksD / 3.7;

    switch (method) {
    case FM_SJ:
        t = R_LOG10(a + 5.74 / R_POW(Re, 0.9));
        o->f = 0.25 / (t * t);
        break;
    case FM_HAALAND:
        x = -HAALAND_COEF * R_LOG10(R_POW(a, 1.11) + 6.9 / Re);
        o->f = 1.0 / (x * x);
        break;
    case FM_GOUDAR:
        C = 0.124 * Re * ksD + R_LOG(0.4587 * Re);
        x = 0.8686 * R_LOG(0.4587 * Re / R_POW(C - 0.31, C / (C + 1.0)));
        o->f = 1.0 / (x * x);
        break;
    default:
        o->f = cw_iter(Re, a, &o->iters, 0);
        break;
    }
    return H_OK;
}

int hydro_fric_all(real Re, real ksD, const hydro_cfg *c,
                   hydro_fric_tab *t, hydro_log *lg)
{
    hydro_fric fr;
    unsigned char m;
    int e;
    hydro_log_clear(lg);
    for (m = 0; m < FM_COUNT; m++) {
        e = hydro_friction(Re, ksD, m, c, &fr);
        if (e)
            return e;
        t->f[m] = fr.f;
        t->out[m] = 0;
    }
    t->regime = fr.regime;
    t->iters = 0;
    if (fr.regime != REG_LAMINAR) {
        t->f[FM_CW] = cw_iter(Re, ksD / 3.7, &t->iters, lg);
        t->out[FM_CW] = ksD > 0.05;
        t->out[FM_SJ] = Re < 4000.0 || Re > 1.0e8 || ksD < 1.0e-6 ||
                        ksD > 1.0e-2;
        t->out[FM_HAALAND] = Re < 4000.0 || Re > 1.0e8 || ksD > 0.05;
        t->out[FM_GOUDAR] = Re < 4000.0 || ksD > 0.05;
    }
    for (m = 0; m < FM_COUNT; m++)
        t->dpct[m] = 100.0 * (t->f[m] - t->f[FM_CW]) / t->f[FM_CW];
    return H_OK;
}

/* ------------------------------------------------------------------ */
/* Tubo con caudal dado                                                */
/* ------------------------------------------------------------------ */
int hydro_check_pipe(const hydro_pipe *p, const hydro_cfg *c)
{
    if (!(p->D > 0))
        return H_ERR_D;
    if (!(p->L > 0))
        return H_ERR_L;
    if (!(p->sumK >= 0))
        return H_ERR_K;
    if (!(p->f_fixed >= 0))
        return H_ERR_KS;
    if (p->f_fixed > 0)
        return H_OK;
    if (!(p->ks >= 0))
        return H_ERR_KS;
    if (!(c->nu > 0))
        return H_ERR_NU;
    return H_OK;
}

static unsigned int state_warn(const hydro_state *s, const hydro_pipe *p,
                               const hydro_cfg *c)
{
    unsigned int w = 0;
    if (p->f_fixed <= 0) {
        if (s->regime == REG_LAMINAR)
            w |= W_LAMINAR;
        else if (s->regime == REG_TRANSITION)
            w |= W_TRANSITION;
        if (s->ksD > 0.05)
            w |= W_KSD_RANGE;
        if (c->method == FM_SJ && s->regime != REG_LAMINAR &&
            (s->Re < 4000.0 || s->Re > 1.0e8 ||
             s->ksD < 1.0e-6 || s->ksD > 1.0e-2))
            w |= W_SJ_RANGE;
    }
    if (s->v > c->v_max)
        w |= W_V_HIGH;
    if (s->v < c->v_min)
        w |= W_V_LOW;
    if (s->hm > c->hm_ratio * s->hf)
        w |= W_HM_HIGH;
    if (p->sumK > 0 && s->LD > c->ld_limit)
        w |= W_LOCAL_SMALL;
    return w;
}

int hydro_pipe_state(const hydro_pipe *p, real Q, const hydro_cfg *c,
                     hydro_state *s)
{
    hydro_fric fr;
    int e = hydro_check_pipe(p, c);
    if (e)
        return e;
    if (!(Q > 0))
        return H_ERR_Q;

    s->Q = Q;
    s->A = hydro_area(p->D);
    s->v = Q / s->A;
    s->Re = s->v * p->D / c->nu;
    s->ksD = p->ks / p->D;
    s->LD = p->L / p->D;
    s->hv2g = s->v * s->v / (2.0 * c->g);
    if (p->f_fixed > 0) {
        s->f = p->f_fixed;
        s->f_iters = 0;
        s->regime = (s->Re < c->re_lam) ? REG_LAMINAR :
                    (s->Re <= c->re_turb) ? REG_TRANSITION : REG_TURBULENT;
    } else {
        e = hydro_friction(s->Re, s->ksD, c->method, c, &fr);
        if (e)
            return e;
        s->f = fr.f;
        s->f_iters = fr.iters;
        s->regime = fr.regime;
    }
    s->hf = s->f * s->LD * s->hv2g;
    s->hm = p->sumK * s->hv2g;
    s->hT = s->hf + s->hm;
    s->warn = state_warn(s, p, c);
    return H_OK;
}

/* Perdida total en funcion de la velocidad (para la biseccion) */
static real hT_of_v(const hydro_pipe *p, real v, const hydro_cfg *c)
{
    hydro_fric fr;
    real f;
    if (!(v > 0))
        return 0;
    if (p->f_fixed > 0) {
        f = p->f_fixed;
    } else {
        if (hydro_friction(v * p->D / c->nu, p->ks / p->D, c->method, c, &fr))
            return 0;
        f = fr.f;
    }
    return (f * p->L / p->D + p->sumK) * v * v / (2.0 * c->g);
}

/* Biseccion sobre v: hT(v) = H (hT crece con v) */
static int solve_v_bisection(const hydro_pipe *p, real H, const hydro_cfg *c,
                             real *v_out, int *iters, hydro_log *lg)
{
    real lo = 0, hi = 1.0, mid, g;
    int it;

    for (it = 0; hT_of_v(p, hi, c) < H; it++) {
        if (it > 40)
            return H_ERR_NOROOT;
        lo = hi;
        hi *= 2.0;
    }
    for (it = 1; it <= 200; it++) {
        mid = 0.5 * (lo + hi);
        g = hT_of_v(p, mid, c) - H;
        log_row(lg, (real)it, lo, hi, mid, g);
        if (g > 0)
            hi = mid;
        else
            lo = mid;
        if (hi - lo <= HYDRO_BIS_REL * hi)
            break;
    }
    *iters = it;
    *v_out = 0.5 * (lo + hi);
    return H_OK;
}

/* ------------------------------------------------------------------ */
/* Tipo B: caudal maximo                                               */
/* ------------------------------------------------------------------ */
/* Velocidad de la formula del curso (diapositivas 10 y 11) dado hf */
static NOINLINE real v_course(const hydro_pipe *p, real hf,
                               const hydro_cfg *c)
{
    real g2 = 2.0 * c->g;
    real arg = p->ks / (3.7 * p->D) +
               2.51 * c->nu * R_SQRT(p->L) /
               R_SQRT(g2 * p->D * p->D * p->D * hf);
    return -R_SQRT(4.0 * g2 * p->D * hf / p->L) * R_LOG10(arg);
}

/* v2.1: valor inicial. Raiz x > 0 de a x^p + b x^q = H (suma de dos
 * potencias, monotona) por Newton, partiendo de la raiz sin el termino
 * b. Con D (p, q < 0) parte por la izquierda; con Q, por la derecha:
 * en ambos casos converge sin pasarse. Solo es un arranque. */
static NOINLINE real pow_root(real a, real p, real b, real q, real H)
{
    real x = R_POW(H / a, 1.0 / p), t1, t2;
    unsigned char i;
    for (i = 0; i < 8; i++) {
        t1 = a * R_POW(x, p);
        t2 = b * R_POW(x, q);
        x -= x * (t1 + t2 - H) / (p * t1 + q * t2);
    }
    return x;
}

/* v2.1: secante protegida, comun a los tipos B y D. fn(s, x, o) llena
 * o[0] y o[1] (columnas de la memoria) y o[2] = F(x); devuelve 0 si x
 * no sirve. sg = signo de F en lo. Fila 0: x0; fila 1: k x0 (k > 0) o
 * x0 - F(x0) (k = 0: un paso del curso); despues, secante. Si una vuelta
 * sale de (lo, hi), punto medio del intervalo que encierra la raiz.
 * Vueltas = filas de secante (desde la 2). Devuelve 1 si converge. */
typedef struct {
    const hydro_pipe *p;
    const hydro_cfg *c;
    real Q, H;
} sec_ctx;
typedef unsigned char (*sec_fn)(const sec_ctx *s, real x, real *o);

static NOINLINE unsigned char secant(sec_fn fn, const sec_ctx *s, real x,
                                     real k, real lo, real hi, real sg,
                                     hydro_log *lg, int *iters, real *root)
{
    real o[3], xp = x, Fp = 0, n;
    int i;
    hydro_log_clear(lg);
    for (i = 0; i <= HYDRO_SEC_MAX + 1; i++) {
        if (!fn(s, x, o))
            return 0;
        log_row(lg, (real)i, x, o[0], o[1], o[2]);
        if (o[2] == 0 || (i > 1 && R_FABS(o[2]) <= 1e-3 * s->H &&
                          R_FABS(x - xp) <= HYDRO_SEC_REL * x)) {
            *iters = i > 1 ? i - 1 : 0;
            *root = x;
            return 1;
        }
        n = i ? x - o[2] * (x - xp) / (o[2] - Fp)
              : (k > 0 ? k * x : x - o[2]);
        if (!(n > lo && n < hi))
            n = 0.5 * (lo + hi);
        if (o[2] * sg > 0)      /* despues: el 2.o punto no se recorta */
            lo = x;
        else
            hi = x;
        xp = x;
        Fp = o[2];
        x = n;
    }
    return 0;
}

/* B: G(hf) = hf + SumK v(hf)^2/2g - H, con v(hf) de la formula del curso */
static unsigned char fB(const sec_ctx *s, real hf, real *o)
{
    real v = v_course(s->p, hf, s->c);
    o[0] = v;
    o[1] = s->p->sumK * v * v / (2.0 * s->c->g);
    o[2] = hf + o[1] - s->H;
    return v > 0;
}

int hydro_qmax_o(const hydro_pipe *p, real H, const hydro_cfg *c,
                 const hydro_iter_opt *o, hydro_qmax_res *r, hydro_log *lg)
{
    real A, v = 0, hf, hfn, hm, g2 = 2.0 * c->g;
    int i, e = hydro_check_pipe(p, c);

    hydro_log_clear(lg);
    r->iters = 0;
    r->course_ok = 0;
    r->hw = 0;
    r->Q0 = 0;
    r->hf1 = H;
    r->solver = SOLV_BISECTION;
    if (e)
        return e;
    if (!(H > 0))
        return H_ERR_NOFLOW;
    A = hydro_area(p->D);

    if (p->f_fixed > 0) {
        v = R_SQRT(g2 * H / (p->f_fixed * p->L / p->D + p->sumK));
        r->solver = SOLV_DIRECT;
        r->iters = 1;
    } else if (c->method == FM_CW) {
        /* v2.1: hf1 de Hazen-Williams, con Q_HW tal que
         * hf_HW(Q) + SumK v^2/2g = H. Si falla, hf1 = H como antes. */
        if (ITER_OPT && o && o->CH > 0) {
            /* hf_HW(Q) = hydro_hw_hf(1, D, L, C_H) Q^1.852 */
            r->Q0 = pow_root(hydro_hw_hf(1, p->D, p->L, o->CH), 1.852,
                             p->sumK / (g2 * A * A), 2.0, H);
            r->hf1 = hydro_hw_hf(r->Q0, p->D, p->L, o->CH);
            if (r->hf1 > 0 && r->hf1 < H) {
                r->hw = 1;
                v = r->Q0 / A;
                hm = p->sumK * v * v / g2;
                log_row(lg, 0, r->hf1, v, hm, r->hf1);
            } else {
                r->hf1 = H;
            }
        }
        hf = r->hf1;
        if (ITER_OPT && o && o->solver == IT_SECANT) {
            /* v2.1: secante sobre G(hf); G crece con hf: G(0) < 0.
             * Criterio relativo: con hf pequeno, 1e-5 m no basta. */
            sec_ctx s;
            s.p = p;
            s.c = c;
            s.H = H;
            if (secant(fB, &s, hf, 0, 0, H, -1, lg, &r->iters, &hf)) {
                v = v_course(p, hf, c);
                r->course_ok = 1;
            }
        } else {
            /* Iteracion del curso (diapositivas 10 y 11) */
            for (i = 1; i <= c->max_iter; i++) {
                v = v_course(p, hf, c);
                if (!(v > 0))
                    break;
                hm = p->sumK * v * v / g2;
                hfn = H - hm;
                log_row(lg, (real)i, hf, v, hm, hfn);
                r->iters = i;
                if (!(hfn > 0))
                    break;
                if (R_FABS(hfn - hf) <= c->tol + HYDRO_EPS_REL * hf) {
                    /* velocidad final con el ultimo hf */
                    v = v_course(p, hfn, c);
                    r->course_ok = 1;
                    break;
                }
                hf = hfn;
            }
        }
        /* La formula del curso supone Colebrook-White (Re > 2000) */
        if (r->course_ok && v * p->D / c->nu < c->re_lam)
            r->course_ok = 0;
        if (r->course_ok)
            r->solver = (ITER_OPT && o && o->solver == IT_SECANT)
                            ? SOLV_SECANT : SOLV_COURSE;
    }

    if (r->solver == SOLV_BISECTION) {
        hydro_log_clear(lg); /* el registro mostrara la biseccion */
        e = solve_v_bisection(p, H, c, &v, &r->iters, lg);
        if (e)
            return e;
    }

    e = hydro_pipe_state(p, v * A, c, &r->st);
    if (e)
        return e;
    if (r->solver == SOLV_BISECTION && c->method == FM_CW && p->f_fixed <= 0)
        r->st.warn |= W_FALLBACK;
    return H_OK;
}

/* ------------------------------------------------------------------ */
/* Tipo C: bomba y turbina                                             */
/* ------------------------------------------------------------------ */
real hydro_head_from_power(real P, real eta, real Q, const hydro_cfg *c)
{
    if (!(Q > 0))
        return 0;
    return eta * P / (c->gamma * Q);
}

int hydro_pump(const hydro_pipe *p, real Q, real Hs, real eta,
               const hydro_cfg *c, hydro_machine_res *r)
{
    int e;
    if (!(eta > 0 && eta <= 1.0))
        return H_ERR_ETA;
    e = hydro_pipe_state(p, Q, c, &r->st);
    if (e)
        return e;
    r->Hm = Hs + r->st.hT;
    r->Pn = c->gamma * Q * r->Hm;
    r->Pb = r->Pn / eta;
    if (!(r->Hm > 0))
        return H_ERR_HT_NEG;
    return H_OK;
}

int hydro_turbine(const hydro_pipe *p, real Q, real Ha, real eta,
                  const hydro_cfg *c, hydro_machine_res *r)
{
    int e;
    if (!(eta > 0 && eta <= 1.0))
        return H_ERR_ETA;
    e = hydro_pipe_state(p, Q, c, &r->st);
    if (e)
        return e;
    r->Hm = Ha - r->st.hT;
    r->Pb = c->gamma * Q * r->Hm;
    r->Pn = eta * r->Pb;
    if (!(r->Hm > 0))
        return H_ERR_HT_NEG;
    return H_OK;
}

/* ------------------------------------------------------------------ */
/* Tipo D: diseno del diametro                                         */
/* ------------------------------------------------------------------ */
static real hT_of_D(const hydro_pipe *p, real D, real Q, const hydro_cfg *c)
{
    hydro_pipe q = *p;
    hydro_state s;
    q.D = D;
    if (hydro_pipe_state(&q, Q, c, &s))
        return -1;
    return s.hT;
}

static unsigned char fD(const sec_ctx *s, real D, real *o)
{
    o[0] = s->Q / hydro_area(D);
    o[1] = hT_of_D(s->p, D, s->Q, s->c);
    o[2] = o[1] - s->H;
    return o[1] > 0;
}

real hydro_vp(real H, real hf, real sumK, const hydro_cfg *c)
{
    if (!(sumK > 0) || !(H > hf))
        return 0;
    return R_SQRT(2.0 * c->g * (H - hf) / sumK);
}

int hydro_design_o(const hydro_pipe *p, real Qd, real H,
                   const real *list, int n, const hydro_cfg *c,
                   const hydro_iter_opt *o, hydro_design_res *r,
                   hydro_log *lg)
{
    hydro_pipe q = *p;
    real lo = 0.001, hi = 20.0, mid, g, k8;
    sec_ctx s;
    int it, i, e;

    hydro_log_clear(lg);
    r->D_exact = 0;
    r->D_com = 0;
    r->idx_com = -1;
    r->vp = 0;
    r->warn = 0;
    r->iters = 0;
    r->D0 = 0;
    r->solver = SOLV_BISECTION;
    r->hw = 0;
    r->fb = 0;
    q.D = 1.0;
    e = hydro_check_pipe(&q, c);
    if (e)
        return e;
    if (!(Qd > 0))
        return H_ERR_Q;
    if (!(H > 0))
        return H_ERR_NOFLOW;
    if (hT_of_D(&q, hi, Qd, c) > H || hT_of_D(&q, lo, Qd, c) < H)
        return H_ERR_NOROOT;

    /* v2.1: secante sobre F(D) = hT(Qd, D) - H desde D0 y 1,02 D0. D0
     * cumple hf + SumK v^2/2g = H con hf de Hazen-Williams (si hay C_H)
     * o de Darcy con f = 0,02. Si una vuelta sale de [lo, hi], da un
     * error o no converge, se usa la biseccion de siempre. */
    if (ITER_OPT && o && (o->solver == IT_SECANT || o->CH > 0)) {
        k8 = 8.0 * Qd * Qd / (HYDRO_PI * HYDRO_PI * c->g);
        /* hf_HW(D) = hydro_hw_hf(Qd, 1, L, C_H) D^-4.87 */
        r->hw = o->CH > 0;
        r->D0 = pow_root(r->hw ? hydro_hw_hf(Qd, 1, q.L, o->CH)
                               : 0.02 * q.L * k8,
                         r->hw ? -4.87 : -5.0, q.sumK * k8, -4.0, H);
        /* F = hT - H baja al crecer D: F(lo) > 0 */
        s.p = &q;
        s.c = c;
        s.Q = Qd;
        s.H = H;
        if (secant(fD, &s, r->D0, 1.02, lo, hi, 1, lg, &r->iters,
                   &r->D_exact))
            r->solver = SOLV_SECANT;
        if (r->solver != SOLV_SECANT) {
            r->fb = 1;
            hydro_log_clear(lg);
        }
    }

    if (r->solver == SOLV_BISECTION) {
        /* Biseccion geometrica sobre D (hT decrece con D) */
        for (it = 1; it <= 200; it++) {
            mid = R_SQRT(lo * hi);
            g = hT_of_D(&q, mid, Qd, c) - H;
            log_row(lg, (real)it, lo, hi, mid, g);
            if (g > 0)
                lo = mid;
            else
                hi = mid;
            if (hi - lo <= HYDRO_BIS_REL * hi)
                break;
        }
        r->iters = it;
        r->D_exact = 0.5 * (lo + hi);
    }
    q.D = r->D_exact;
    hydro_pipe_state(&q, Qd, c, &r->st_exact);

    if (!list || n <= 0)
        return H_OK;
    for (i = 0; i < n; i++) {
        if (list[i] >= r->D_exact &&
            (r->idx_com < 0 || list[i] < r->D_com)) {
            r->D_com = list[i];
            r->idx_com = i;
        }
    }
    if (r->idx_com < 0)
        return H_ERR_LIST;

    q.D = r->D_com;
    e = hydro_pipe_state(&q, Qd, c, &r->st_com_qd);
    if (e)
        return e;
    e = hydro_qmax_o(&q, H, c, o, &r->qmax, 0);
    if (e)
        return e;
    if (r->st_com_qd.hm > c->hm_ratio * r->st_com_qd.hf) {
        r->warn |= W_HM_HIGH;
        r->vp = hydro_vp(H, r->st_com_qd.hf, q.sumK, c);
    }
    return H_OK;
}

/* ------------------------------------------------------------------ */
/* Tipo E: calibracion                                                 */
/* ------------------------------------------------------------------ */
int hydro_calibrate(real D, real L, real Q, real sumK, real dz, real dp,
                    const hydro_cfg *c, hydro_calib_res *r)
{
    real sf;
    r->warn = 0;
    if (!(D > 0))
        return H_ERR_D;
    if (!(L > 0))
        return H_ERR_L;
    if (!(Q > 0))
        return H_ERR_Q;
    if (!(sumK >= 0))
        return H_ERR_K;
    if (!(c->nu > 0))
        return H_ERR_NU;
    r->A = hydro_area(D);
    r->v = Q / r->A;
    r->hm = sumK * r->v * r->v / (2.0 * c->g);
    r->htot = dz + dp;
    r->hf = r->htot - r->hm;
    r->Re = r->v * D / c->nu;
    if (!(r->hf > 0))
        return H_ERR_HF_NEG;
    r->f = 2.0 * c->g * D * r->hf / (L * r->v * r->v);
    sf = R_SQRT(r->f);
    r->ks = 3.7 * D * (R_POW(10.0, -1.0 / (2.0 * sf)) - 2.51 / (r->Re * sf));
    r->ksD = r->ks / D;
    if (r->Re < c->re_lam)
        r->warn |= W_LAMINAR;
    else if (r->Re <= c->re_turb)
        r->warn |= W_TRANSITION;
    if (r->ks < 0) {
        r->warn |= W_KS_NEG;
        return H_ERR_KS_NEG;
    }
    if (r->ksD > 0.05)
        r->warn |= W_KSD_RANGE;
    return H_OK;
}

/* ------------------------------------------------------------------ */
/* Tipo F: valvula de control                                          */
/* ------------------------------------------------------------------ */
int hydro_valve(const hydro_pipe *p, real Q, real Ha, const hydro_cfg *c,
                hydro_valve_res *r)
{
    int e = hydro_pipe_state(p, Q, c, &r->st);
    if (e)
        return e;
    r->hv = Ha - r->st.hT;
    r->Kv = 2.0 * c->g * r->hv / (r->st.v * r->st.v);
    if (r->hv < 0)
        return H_ERR_HV_NEG;
    return H_OK;
}

/* ------------------------------------------------------------------ */
/* Tipo I: Hazen-Williams                                              */
/* ------------------------------------------------------------------ */
real hydro_hw_hf(real Q, real D, real L, real CH)
{
    if (!(Q > 0 && D > 0 && L > 0 && CH > 0))
        return 0;
    return 10.675 * L * R_POW(Q, 1.852) /
           (R_POW(CH, 1.852) * R_POW(D, 4.87));
}

real hydro_hw_q(real H, real D, real L, real CH)
{
    if (!(H > 0 && D > 0 && L > 0 && CH > 0))
        return 0;
    return R_POW(H * R_POW(CH, 1.852) * R_POW(D, 4.87) / (10.675 * L),
                 1.0 / 1.852);
}

/* ------------------------------------------------------------------ */
/* Presion en un punto                                                 */
/* ------------------------------------------------------------------ */
real hydro_pressure_head(real head_up, real HB, real v, real h_loss,
                         const hydro_cfg *c, unsigned int *warn)
{
    real p = head_up + HB - v * v / (2.0 * c->g) - h_loss;
    if (warn) {
        if (p < 0)
            *warn |= W_P_NEG;
        if (p < -101325.0 / c->gamma)
            *warn |= W_CAVIT;
    }
    return p;
}

/* ------------------------------------------------------------------ */
/* Tipo G: redes en serie y paralelo                                   */
/* ------------------------------------------------------------------ */
real hydro_module_coef(const hydro_cfg *c)
{
    return 8.0 / (HYDRO_PI * HYDRO_PI * c->g);
}

void hydro_net_init(hydro_net *n)
{
    n->n = 0;
    n->root = 0;
    n->outer_iters = 0;
    n->res_q = 0;
    n->res_h = 0;
}

int hydro_net_add_pipe(hydro_net *n, real L, real D, real f, real ks,
                       real sumK)
{
    net_node *nd;
    if (n->n >= NET_MAX)
        return -1;
    nd = &n->node[n->n];
    nd->type = NODE_PIPE;
    nd->nchild = 0;
    nd->pipe.L = L;
    nd->pipe.D = D;
    nd->pipe.f_fixed = f;
    nd->pipe.ks = ks;
    nd->pipe.sumK = sumK;
    nd->f = f;
    nd->M = nd->Mf = nd->Mk = nd->Q = nd->h = 0;
    n->root = n->n;
    return n->n++;
}

int hydro_net_add_group(hydro_net *n, unsigned char type,
                        const unsigned char *kids, unsigned char nk)
{
    net_node *nd;
    unsigned char i;
    if (n->n >= NET_MAX || nk == 0 || nk > NET_MAX_CHILD ||
        (type != NODE_SERIES && type != NODE_PARALLEL))
        return -1;
    for (i = 0; i < nk; i++)
        if (kids[i] >= n->n)
            return -1;
    nd = &n->node[n->n];
    nd->type = type;
    nd->nchild = nk;
    for (i = 0; i < nk; i++)
        nd->child[i] = kids[i];
    nd->M = nd->Mf = nd->Mk = nd->Q = nd->h = nd->f = 0;
    n->root = n->n;
    return n->n++;
}

/* Modulo de cada nodo; devuelve error si algo no cuadra */
static int net_reduce(hydro_net *n, unsigned char idx, const hydro_cfg *c,
                      unsigned char depth)
{
    net_node *nd = &n->node[idx];
    real s, k0, D;
    unsigned char i;
    int e;

    if (depth > NET_MAX)
        return H_ERR_NET;
    if (nd->type == NODE_PIPE) {
        D = nd->pipe.D;
        k0 = hydro_module_coef(c);
        nd->Mf = k0 * nd->f * nd->pipe.L / (D * D * D * D * D);
        nd->Mk = k0 * nd->pipe.sumK / (D * D * D * D);
        nd->M = nd->Mf + nd->Mk;
        return H_OK;
    }
    s = 0;
    for (i = 0; i < nd->nchild; i++) {
        e = net_reduce(n, nd->child[i], c, depth + 1);
        if (e)
            return e;
        if (nd->type == NODE_SERIES) {
            s += n->node[nd->child[i]].M;
        } else {
            if (!(n->node[nd->child[i]].M > 0))
                return H_ERR_NET;
            s += 1.0 / R_SQRT(n->node[nd->child[i]].M);
        }
    }
    nd->M = (nd->type == NODE_SERIES) ? s : 1.0 / (s * s);
    return H_OK;
}

static void net_distribute(hydro_net *n, unsigned char idx, real Q,
                           unsigned char depth)
{
    net_node *nd = &n->node[idx];
    unsigned char i;
    real sq, sh, d;

    nd->Q = Q;
    nd->h = nd->M * Q * Q;
    if (nd->type == NODE_PIPE || depth > NET_MAX)
        return;
    sq = 0;
    sh = 0;
    for (i = 0; i < nd->nchild; i++) {
        net_node *ch = &n->node[nd->child[i]];
        if (nd->type == NODE_SERIES)
            net_distribute(n, nd->child[i], Q, depth + 1);
        else
            net_distribute(n, nd->child[i], R_SQRT(nd->h / ch->M), depth + 1);
        sq += ch->Q;
        sh += ch->h;
        if (nd->type == NODE_PARALLEL) {
            d = R_FABS(ch->h - nd->h);
            if (d > n->res_h)
                n->res_h = d;
        }
    }
    if (nd->type == NODE_SERIES) {
        d = R_FABS(sh - nd->h);
        if (d > n->res_h)
            n->res_h = d;
    } else {
        d = R_FABS(sq - nd->Q);
        if (d > n->res_q)
            n->res_q = d;
    }
}

int hydro_net_solve(hydro_net *n, real H, const hydro_cfg *c)
{
    unsigned char i, autof = 0;
    int it, e;
    real Q, ch, fnew;
    hydro_fric fr;

    if (n->n == 0)
        return H_ERR_NET;
    if (!(H > 0))
        return H_ERR_NOFLOW;
    for (i = 0; i < n->n; i++) {
        net_node *nd = &n->node[i];
        if (nd->type != NODE_PIPE)
            continue;
        e = hydro_check_pipe(&nd->pipe, c);
        if (e)
            return e;
        if (nd->pipe.f_fixed > 0) {
            nd->f = nd->pipe.f_fixed;
        } else {
            nd->f = 0.02;
            autof = 1;
        }
    }
    for (it = 1; it <= 50; it++) {
        n->res_q = 0;
        n->res_h = 0;
        e = net_reduce(n, n->root, c, 0);
        if (e)
            return e;
        Q = R_SQRT(H / n->node[n->root].M);
        net_distribute(n, n->root, Q, 0);
        n->outer_iters = it;
        if (!autof)
            break;
        ch = 0;
        for (i = 0; i < n->n; i++) {
            net_node *nd = &n->node[i];
            if (nd->type != NODE_PIPE || nd->pipe.f_fixed > 0)
                continue;
            e = hydro_friction(nd->Q / hydro_area(nd->pipe.D) * nd->pipe.D /
                               c->nu, nd->pipe.ks / nd->pipe.D, c->method,
                               c, &fr);
            if (e)
                return e;
            fnew = fr.f;
            if (R_FABS(fnew - nd->f) > ch * nd->f)
                ch = R_FABS(fnew - nd->f) / nd->f;
            nd->f = fnew;
        }
        if (ch <= 10.0 * HYDRO_EPS_REL)
            break;
    }
    if (autof && it > 50)
        return H_ERR_NOCONV;
    return H_OK;
}

int hydro_net_solve_back(hydro_net *n, unsigned char k, real Qk,
                         const hydro_cfg *c, real *H)
{
    int e, it;
    real h = 1.0, q;

    if (k >= n->n)
        return H_ERR_NET;
    if (!(Qk > 0))
        return H_ERR_Q;
    for (it = 0; it < 50; it++) {
        e = hydro_net_solve(n, h, c);
        if (e)
            return e;
        q = n->node[k].Q;
        if (!(q > 0))
            return H_ERR_NET;
        if (it > 0 && R_FABS(q - Qk) <= 10.0 * HYDRO_EPS_REL * Qk)
            break;
        h *= (Qk / q) * (Qk / q);
    }
    *H = h;
    return H_OK;
}

/* ------------------------------------------------------------------ */
/* Textos                                                              */
/* ------------------------------------------------------------------ */
static const char *const err_txt[H_ERR_COUNT] = {
    "OK",
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
};

const char *hydro_err_text(int err)
{
    if (err < 0 || err >= H_ERR_COUNT)
        return "Error";
    return err_txt[err];
}

const char *hydro_method_name(unsigned char m)
{
    switch (m) {
    case FM_SJ: return "Swamee-Jain";
    case FM_HAALAND: return "Haaland";
    case FM_GOUDAR: return "Goudar-Sonnad";
    default: return "Colebrook-White";
    }
}
