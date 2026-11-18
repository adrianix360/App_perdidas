/*
 * secant_check.c - v2.1: barrido de la secante y del arranque de
 * Hazen-Williams (tipos B y D) sobre los 500 casos B y D del oraculo
 * (tests/random_cases.csv). Para cada caso compara el resultado de cada
 * variante con el de la v2.0 (curso o biseccion) y con el oraculo, y
 * cuenta vueltas y respaldos. Incluye arranques malos (C_H absurdo,
 * SumK x 50) para comprobar que el respaldo entra y el resultado no
 * cambia.
 * Uso: secant_check tests/random_cases.csv
 */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "../src/hydro/hydro.h"

#ifdef HYDRO_USE_DOUBLE
#define TOL_REF 1e-6     /* contra la v2.0 (D) y contra el oraculo (B) */
#else
#define TOL_REF 2e-5
#endif

typedef struct {
    const char *name;
    real CH;
    unsigned char solver;
    real kmul;          /* SumK x kmul (arranque malo)                 */
} variant;

static const variant VB[] = {
    { "curso (v2.0)", 0, IT_DEFAULT, 1 },
    { "curso desde HW 130", 130, IT_DEFAULT, 1 },
    { "secante desde H", 0, IT_SECANT, 1 },
    { "secante desde HW 130", 130, IT_SECANT, 1 },
    { "secante desde HW 150", 150, IT_SECANT, 1 },
    { "secante HW C_H=1", 1, IT_SECANT, 1 },
    { "secante HW C_H=1e4", 10000, IT_SECANT, 1 },
    { "curso, SumK x50", 0, IT_DEFAULT, 50 },
    { "secante HW 130, SumK x50", 130, IT_SECANT, 50 },
};
static const variant VD[] = {
    { "biseccion (v2.0)", 0, IT_DEFAULT, 1 },
    { "secante f=0.02", 0, IT_SECANT, 1 },
    { "secante HW 130", 130, IT_DEFAULT, 1 },
    { "secante HW 150", 150, IT_SECANT, 1 },
    { "secante HW C_H=1", 1, IT_SECANT, 1 },
    { "secante HW C_H=1e4", 10000, IT_SECANT, 1 },
    { "biseccion, SumK x50", 0, IT_DEFAULT, 50 },
    { "secante HW 130, SumK x50", 130, IT_SECANT, 50 },
};
#define NB (sizeof VB / sizeof VB[0])
#define ND (sizeof VD / sizeof VD[0])

typedef struct {
    int n, err, fb, itmax, newfail;
    long itsum;
    double wref, worc;
} stat_t;
static stat_t sb[NB], sd[ND];

static void acc(stat_t *s, int it, int fb, double ref_rel, double orc_rel)
{
    s->n++;
    s->itsum += it;
    if (it > s->itmax)
        s->itmax = it;
    s->fb += fb;
    if (ref_rel > s->wref)
        s->wref = ref_rel;
    if (orc_rel > s->worc)
        s->worc = orc_rel;
}

static double rel(double a, double b)
{
    return fabs(a - b) / fabs(b);
}

int main(int argc, char **argv)
{
    FILE *fp;
    char line[512], tipo[4];
    int i, nf = 0;
    unsigned k;
    double D, L, ks, K, nu, a, b, c, Re, ref = 0, refK50 = 0;
    hydro_cfg C;
    hydro_pipe p;
    hydro_iter_opt o;
    hydro_qmax_res q;
    hydro_design_res d;

    fp = fopen(argc > 1 ? argv[1] : "tests/random_cases.csv", "r");
    if (!fp) {
        printf("No se pudo abrir el CSV\n");
        return 2;
    }
    hydro_cfg_default(&C);
    if (!fgets(line, sizeof line, fp))
        return 2;
    while (fgets(line, sizeof line, fp)) {
        if (sscanf(line, "%1[^,],%d,%lf,%lf,%lf,%lf,%lf,%lf,%lf,%lf,%lf",
                   tipo, &i, &D, &L, &ks, &K, &nu, &a, &b, &c, &Re) != 11)
            continue;
        C.nu = (real)nu;
        p.D = (real)D;
        p.L = (real)L;
        p.ks = (real)ks;
        p.f_fixed = 0;
        if (tipo[0] == 'B') {
            for (k = 0; k < NB; k++) {
                int e;
                p.sumK = (real)(K * VB[k].kmul);
                o.CH = VB[k].CH;
                o.solver = VB[k].solver;
                e = hydro_qmax_o(&p, (real)a, &C, &o, &q, 0);
                if (e) {
                    sb[k].err++;
                    if (k == 0 || k == 7)
                        continue;
                    sb[k].newfail++;
                    printf("  B-%d %s: error %d\n", i, VB[k].name, e);
                    continue;
                }
                if (k == 0)
                    ref = q.st.Q;
                if (k == 7)
                    refK50 = q.st.Q;
                acc(&sb[k], q.iters,
                    VB[k].solver == IT_SECANT && q.solver != SOLV_SECANT,
                    rel(q.st.Q, VB[k].kmul > 1 ? refK50 : ref),
                    VB[k].kmul > 1 ? 0 : rel(q.st.Q, b));
            }
        } else if (tipo[0] == 'D') {
            for (k = 0; k < ND; k++) {
                int e;
                p.sumK = (real)(K * VD[k].kmul);
                o.CH = VD[k].CH;
                o.solver = VD[k].solver;
                e = hydro_design_o(&p, (real)a, (real)b, 0, 0, &C, &o, &d, 0);
                if (e) {
                    sd[k].err++;
                    if (k == 0 || k == 6)
                        continue;
                    sd[k].newfail++;
                    printf("  D-%d %s: error %d\n", i, VD[k].name, e);
                    continue;
                }
                if (k == 0)
                    ref = d.D_exact;
                if (k == 6)
                    refK50 = d.D_exact;
                acc(&sd[k], d.iters, d.fb,
                    rel(d.D_exact, VD[k].kmul > 1 ? refK50 : ref),
                    VD[k].kmul > 1 ? 0 : rel(d.D_exact, D));
            }
        }
    }
    fclose(fp);
    printf("\nreal = %s; tolerancia %.0e\n\n",
           sizeof(real) == sizeof(double) ? "double" : "float", TOL_REF);
    printf("| Tipo B: variante | Casos | Errores | Vueltas media | max | Respaldo | Dif. vs v2.0 | Dif. vs oraculo |\n");
    printf("|---|---|---|---|---|---|---|---|\n");
    for (k = 0; k < NB; k++) {
        stat_t *s = &sb[k];
        printf("| %s | %d | %d | %.2f | %d | %d | %.2e | %.2e |\n",
               VB[k].name, s->n, s->err, s->n ? (double)s->itsum / s->n : 0,
               s->itmax, s->fb, s->wref, s->worc);
        nf += s->newfail;
        /* la secante debe dar lo mismo que el oraculo (exacto) */
        if (VB[k].solver == IT_SECANT && VB[k].kmul == 1 && s->worc > TOL_REF)
            nf++;
    }
    printf("\n| Tipo D: variante | Casos | Errores | Vueltas media | max | Respaldo | Dif. vs v2.0 | Dif. vs oraculo |\n");
    printf("|---|---|---|---|---|---|---|---|\n");
    for (k = 0; k < ND; k++) {
        stat_t *s = &sd[k];
        printf("| %s | %d | %d | %.2f | %d | %d | %.2e | %.2e |\n",
               VD[k].name, s->n, s->err, s->n ? (double)s->itsum / s->n : 0,
               s->itmax, s->fb, s->wref, s->worc);
        nf += s->newfail;
        if (s->wref > TOL_REF)
            nf++;
    }
    printf("\n%s\n", nf ? "**HAY FALLAS**" : "Sin fallas: ningun caso que resolvia deja de resolver");
    return nf ? 1 : 0;
}
