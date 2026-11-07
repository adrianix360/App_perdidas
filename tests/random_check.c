/*
 * random_check.c - Compara el motor contra el oraculo de Python
 * (tools/oracle.py -> tests/random_cases.csv) en f, hf, Qmax y D.
 * Tolerancia: 0,1 % relativa. Uso: random_check tests/random_cases.csv
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "../src/hydro/hydro.h"

#define TOL 1e-3

typedef struct {
    const char *name;
    double worst;
    char where[96];
    int n, fail;
} stat_t;

static stat_t st[4] = { { "f (dado Q)", 0, "", 0, 0 },
                        { "hf (dado Q)", 0, "", 0, 0 },
                        { "Qmax (dado H)", 0, "", 0, 0 },
                        { "D de diseno", 0, "", 0, 0 } };

static void cmp(int k, double got, double ref, const char *tipo, int i,
                double re)
{
    double e = fabs(got - ref) / fabs(ref);
    st[k].n++;
    if (e > TOL) {
        st[k].fail++;
        printf("  FALLA %s caso %s-%d: ref %.9g obtenido %.9g (%.4f %%) Re=%.0f\n",
               st[k].name, tipo, i, ref, got, 100 * e, re);
    }
    if (e > st[k].worst || st[k].n == 1) {
        st[k].worst = e;
        snprintf(st[k].where, sizeof st[k].where, "%s-%d (Re = %.0f)",
                 tipo, i, re);
    }
}

int main(int argc, char **argv)
{
    FILE *fp;
    char line[512], tipo[4];
    int i, k, nf = 0, err;
    double D, L, ks, K, nu, a, b, c, Re;
    hydro_cfg C;
    hydro_pipe p;
    hydro_state s;
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
        p.sumK = (real)K;
        p.f_fixed = 0;
        if (tipo[0] == 'F') {
            err = hydro_pipe_state(&p, (real)a, &C, &s);
            if (err) { printf("  error %d en F-%d\n", err, i); nf++; continue; }
            cmp(0, s.f, b, tipo, i, Re);
            cmp(1, s.hf, c, tipo, i, Re);
        } else if (tipo[0] == 'B') {
            err = hydro_qmax(&p, (real)a, &C, &q, 0);
            if (err) { printf("  error %d en B-%d\n", err, i); nf++; continue; }
            cmp(2, q.st.Q, b, tipo, i, Re);
        } else if (tipo[0] == 'D') {
            err = hydro_design(&p, (real)a, (real)b, 0, 0, &C, &d, 0);
            if (err) { printf("  error %d en D-%d\n", err, i); nf++; continue; }
            cmp(3, d.D_exact, D, tipo, i, Re);
        }
    }
    fclose(fp);
    printf("\nreal = %s, tolerancia %.2g %%\n\n",
           sizeof(real) == sizeof(double) ? "double" : "float", 100 * TOL);
    printf("| Magnitud | Casos | Fallan | Peor error rel. | Donde |\n");
    printf("|---|---|---|---|---|\n");
    for (k = 0; k < 4; k++) {
        printf("| %s | %d | %d | %.2e | %s |\n", st[k].name, st[k].n,
               st[k].fail, st[k].worst, st[k].where);
        nf += st[k].fail;
    }
    return nf ? 1 : 0;
}
