/*
 * random_check2.c - Compara el motor v2.0 (drag, weir, chan y la tabla de
 * f) contra el oraculo independiente tools/oracle2.py
 * (tests/random_cases2.csv). Tolerancia: 0,1 % relativa.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "../src/hydro/hydro.h"
#include "../src/hydro/drag.h"
#include "../src/hydro/weir.h"
#include "../src/hydro/chan.h"

#define TOL 1e-3
#define NK 8
static const char kinds[NK] = { 'T', 'S', 'Q', 'H', 'V', 'J', 'P', 'F' };
static const char *const knames[NK] = {
    "velocidad terminal", "estructura (F, M)", "compuesto Q(h)",
    "compuesto h(Q)", "Venturi (dp, h)", "salto (y2, dE)",
    "placa (Cf)", "f (4 metodos)"
};
static int n_[NK], fail_[NK];
static double worst_[NK];

static void cmp(int k, double got, double ref, int line)
{
    double e = fabs(got - ref) / (fabs(ref) > 0 ? fabs(ref) : 1);
    n_[k]++;
    if (e > worst_[k])
        worst_[k] = e;
    if (e > TOL) {
        fail_[k]++;
        printf("  FALLA %s (linea %d): ref %.9g obtenido %.9g (%.4f %%)\n",
               knames[k], line, ref, got, 100 * e);
    }
}

static void comp_els(weir_el *e, const double *x)
{
    memset(e, 0, 3 * sizeof *e);
    e[0].type = WE_TRI; e[0].a = (real)x[0]; e[0].z = (real)x[1];
    e[1].type = WE_RECT; e[1].a = (real)x[2]; e[1].z = (real)x[3];
    e[2].type = WE_ORC; e[2].a = (real)x[4]; e[2].z = (real)x[5];
    e[0].count = e[1].count = 1;
    e[2].count = (unsigned char)x[6];
    e[0].Cd = e[1].Cd = e[2].Cd = (real)x[7];
}

int main(int argc, char **argv)
{
    FILE *fp = fopen(argc > 1 ? argv[1] : "tests/random_cases2.csv", "r");
    char line[512], *t;
    double x[9], r1, r2;
    int ln = 0, k, i, it, st = 0;
    hydro_cfg C;

    if (!fp) {
        printf("No se pudo abrir el CSV\n");
        return 2;
    }
    hydro_cfg_default(&C);
    while (fgets(line, sizeof line, fp)) {
        char kind = line[0];
        ln++;
        t = strtok(line, ";");
        for (i = 0; i < 9; i++)
            x[i] = atof(strtok(0, ";"));
        r1 = atof(strtok(0, ";"));
        r2 = atof(strtok(0, ";\r\n"));
        for (k = 0; k < NK && kinds[k] != kind; k++)
            ;
        if (k == NK)
            continue;
        (void)t;
        switch (kind) {
        case 'T': {
            drag_term_res r;
            drag_terminal((real)x[0], (real)x[1], (real)x[2], (real)x[3],
                          (real)x[4], 1, (real)1e-6, C.g, DK_GENERIC, &r);
            cmp(k, r.v, r1, ln);
            break;
        }
        case 'S': {
            drag_body b[3];
            drag_struct_res r;
            memset(b, 0, sizeof b);
            for (i = 0; i < 2; i++) {
                b[i].Cd = (real)x[2 + 3 * i];
                b[i].A = (real)x[3 + 3 * i];
                b[i].y = (real)x[4 + 3 * i];
                b[i].V = (real)x[0];
            }
            b[2].Cd = (real)x[8]; b[2].A = 10; b[2].y = 5; b[2].V = (real)x[0];
            drag_struct(b, 3, (real)x[1], (real)1.5e-5, &r);
            cmp(k, r.Ftot, r1, ln);
            cmp(k, r.M, r2, ln);
            break;
        }
        case 'Q':
        case 'H': {
            weir_el e[3];
            real Q, h, Qi[3];
            unsigned int w = 0;
            comp_els(e, x);
            if (kind == 'Q') {
                weir_total(e, 3, (real)x[8], C.g, &Q, Qi, &w);
                cmp(k, Q, r1, ln);
            } else {
                weir_level(e, 3, (real)x[8], C.g, &h, Qi, &w, &it, 0);
                cmp(k, h, r1, ln);
            }
            break;
        }
        case 'V': {
            chan_venturi_res r;
            chan_venturi((real)x[0], (real)(x[0] * x[1]), (real)x[2], 1,
                         (real)x[3], MANO_PHYS, &C, &r);
            cmp(k, r.dp, r1, ln);
            cmp(k, r.h, r2, ln);
            break;
        }
        case 'J': {
            chan_jump_res r;
            chan_jump((real)x[0], (real)x[1], (real)x[2], 0, &C, &r);
            cmp(k, r.y2, r1, ln);
            cmp(k, r.dE, r2, ln);
            break;
        }
        case 'P': {
            drag_plate_res r;
            drag_plate((real)x[0], 1, (real)x[1], (real)1.2, (real)x[2], 1,
                       PL_TURB, &r);
            cmp(k, r.Cf_turb, r1, ln);
            cmp(k, r.Cf_mix, r2, ln);
            break;
        }
        case 'F': {
            hydro_fric_tab r;
            hydro_fric_all((real)x[0], (real)x[1], &C, &r, 0);
            cmp(k, r.f[(int)x[2]], r1, ln);
            break;
        }
        }
    }
    fclose(fp);
    printf("real = %s, tolerancia 0.1 %%\n",
           sizeof(real) == sizeof(double) ? "double" : "float");
    printf("| Formula | Comparaciones | Fallan | Peor error rel. |\n|---|---|---|---|\n");
    for (k = 0; k < NK; k++) {
        printf("| %s | %d | %d | %.2e |\n", knames[k], n_[k], fail_[k],
               worst_[k]);
        if (fail_[k])
            st = 1;
    }
    printf("Casos: %d\n", ln);
    return st;
}
