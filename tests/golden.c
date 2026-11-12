/*
 * golden.c - Ejecuta los casos dorados (memoria, sec. 9) contra el motor.
 * Compila en el PC (gcc, float o double) y, mas adelante, en el eZ80.
 * Uso: golden [-v]   (-v muestra tambien los valores informativos)
 */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "../src/hydro/hydro.h"
#include "golden_table.h"

/* Salida: printf en el PC; en la calculadora, consola de CEmu (dbg) */
#ifndef OUT
#define OUT printf
#endif

#define MAX_OUT 48
static struct { const char *name; double v; } out[MAX_OUT];
static int nout;
static const char *cur_id;
static int verbose;
static int n_pass, n_pass_r, n_fail, n_missing;

/* Valor obtenido de cada fila de la tabla (en el eZ80 se lee de la RAM
 * emulada para compararlo con el PC; ver tools/cemu_golden.py) */
volatile double golden_got[GOLDEN_N];

static void put(const char *name, double v)
{
    if (nout < MAX_OUT) {
        out[nout].name = name;
        out[nout].v = v;
        nout++;
    }
}

static void begin(const char *id)
{
    cur_id = id;
    nout = 0;
}

static void end(void)
{
    size_t i;
    int j, found;
    for (i = 0; i < GOLDEN_N; i++) {
        const golden_t *g = &golden[i];
        double got, err, rel, tol, tol_r;
        const char *res;
        if (strcmp(g->id, cur_id) != 0)
            continue;
        found = -1;
        for (j = 0; j < nout; j++)
            if (strcmp(out[j].name, g->name) == 0)
                found = j;
        if (found < 0) {
            OUT("| %s | %s | %.10g | (sin dato) | | FALTA |\n",
                   g->id, g->name, g->expected);
            n_missing++;
            continue;
        }
        got = out[found].v;
        golden_got[i] = got;
        err = fabs(got - g->expected);
        rel = g->expected != 0 ? (got - g->expected) / fabs(g->expected) : 0;
        tol = g->tol_rel * fabs(g->expected);
        if (g->tol_abs > tol)
            tol = g->tol_abs;
        tol_r = 0.5 * pow(10.0, -g->dec);
        if (g->tol_rel == 0 && g->tol_abs == 0) {   /* exacto */
            tol = 0.5;
            tol_r = 0;
        }
        if (err <= tol) {
            res = "pasa";
            n_pass++;
        } else if (err <= tol_r) {
            res = "pasa (r)";
            n_pass_r++;
        } else {
            res = "**FALLA**";
            n_fail++;
        }
        OUT("| %s | %s | %.10g | %.7g | %+.3f %% | %s |\n",
               g->id, g->name, g->expected, got, 100.0 * rel, res);
    }
    if (verbose) {
        for (j = 0; j < nout; j++) {
            int has = 0;
            for (i = 0; i < GOLDEN_N; i++)
                if (!strcmp(golden[i].id, cur_id) &&
                    !strcmp(golden[i].name, out[j].name))
                    has = 1;
            if (!has)
                OUT("| %s | %s | (info) | %.7g | | |\n",
                       cur_id, out[j].name, out[j].v);
        }
    }
}

static hydro_cfg C;

static void cfg(double nu, unsigned char m)
{
    hydro_cfg_default(&C);
    C.nu = (real)nu;
    C.method = m;
}

static hydro_pipe P(double D, double L, double ks, double K, double f)
{
    hydro_pipe p;
    p.D = (real)D;
    p.L = (real)L;
    p.ks = (real)ks;
    p.sumK = (real)K;
    p.f_fixed = (real)f;
    return p;
}

/* ------------------------------------------------------------------ */
static void case_P01_P02(void)
{
    hydro_pipe p = P(0.2, 1000, 0.0015e-3, 0, 0);
    hydro_state s, sc;
    double hw;

    begin("P-01");
    cfg(1.007e-6, FM_SJ);
    hydro_pipe_state(&p, (real)0.072, &C, &s);
    cfg(1.007e-6, FM_CW);
    hydro_pipe_state(&p, (real)0.072, &C, &sc);
    hw = hydro_hw_hf((real)0.072, p.D, p.L, (real)150);
    put("v [m/s]", s.v);
    put("Re", s.Re);
    put("f SJ", s.f);
    put("f CW", sc.f);
    put("hf SJ [m]", s.hf);
    put("hf CW [m]", sc.hf);
    put("hf HW [m]", hw);
    put("error HW vs SJ [%]", 100.0 * (hw - s.hf) / s.hf);
    put("error HW vs CW [%]", 100.0 * (hw - sc.hf) / sc.hf);
    end();

    begin("P-02");
    p.sumK = (real)6.7;
    cfg(1.007e-6, FM_SJ);
    hydro_pipe_state(&p, (real)0.072, &C, &s);
    put("hm [m]", s.hm);
    put("hT SJ [m]", s.hT);
    put("p/gamma [m]", hydro_pressure_head(53, 0, s.v, s.hT, &C, 0));
    put("p/gamma sin hm [m]", hydro_pressure_head(53, 0, s.v, s.hf, &C, 0));
    end();
}

static void qmax_case(const char *id, double D, double L, double ks,
                      double K, double H, double nu)
{
    hydro_pipe p = P(D, L, ks, K, 0);
    hydro_qmax_res r;
    hydro_log lg;
    int e;
    begin(id);
    cfg(nu, FM_CW);
    e = hydro_qmax(&p, (real)H, &C, &r, &lg);
    put("error", e);
    put("Q [l/s]", 1000.0 * r.st.Q);
    put("v [m/s]", r.st.v);
    put("f", r.st.f);
    put("hf [m]", r.st.hf);
    put("hm [m]", r.st.hm);
    put("metodo (1 curso)", r.solver);
    put("metodo (2 biseccion)", r.solver);
    put("iteraciones", r.iters);
    put("aviso de respaldo", (r.st.warn & W_FALLBACK) ? 1 : 0);
    end();
}

static void case_B(void)
{
    hydro_pipe p;
    hydro_qmax_res r9;
    double qhw;

    qmax_case("P-03", 0.293, 700, 1.5e-6, 11.5, 43.5, 1e-6);
    qmax_case("P-04", 0.391, 4250, 2.0e-6, 8, 125, 1e-6);
    qmax_case("P-05", 1.050, 23778, 4.6e-5, 7, 80, 1e-6);
    qmax_case("P-06", 0.050, 2, 0.045e-3, 0.7, 5, 1.007e-6);
    qmax_case("P-07", 0.050, 2.06, 0.045e-3, 10.8, 5, 1.007e-6); /* L del manuscrito */
    qmax_case("P-08", 0.200, 1500, 0.0015e-3, 21.4, 100, 1e-6);
    qmax_case("P-09", 0.300, 4500, 0.045e-3, 5, 100, 1e-6);
    qmax_case("R-01", 0.050, 2.06, 0.045e-3, 10.8, 5, 1.007e-6);

    begin("P-10");
    p = P(0.3, 4500, 0.045e-3, 5, 0);
    cfg(1e-6, FM_CW);
    hydro_qmax(&p, 100, &C, &r9, 0);
    qhw = hydro_hw_q(100, p.D, p.L, 130);
    put("Q HW [l/s]", 1000.0 * qhw);
    put("diferencia [%]", 100.0 * (qhw - r9.st.Q) / r9.st.Q);
    end();
}

static void case_C(void)
{
    hydro_pipe p;
    hydro_machine_res m;

    begin("P-11");
    p = P(0.150, 970, 1.5e-6, 9.4, 0);
    cfg(1.14e-6, FM_CW);
    C.gamma = (real)(999.1 * 9.81);   /* gamma implicito en la hoja */
    put("error", hydro_pump(&p, (real)0.042, 16, (real)0.65, &C, &m));
    put("v [m/s]", m.st.v);
    put("Re", m.st.Re);
    put("f", m.st.f);
    put("hf [m]", m.st.hf);
    put("hm [m]", m.st.hm);
    put("H [m]", m.Hm);
    put("P [kW]", m.Pb / 1000.0);
    put("P [Hp]", m.Pb / 745.7);
    end();

    begin("P-12");
    p = P(0.200, 1000, 0, 0, 0.014);
    cfg(1e-6, FM_CW);
    put("error", hydro_pump(&p, (real)0.075, 102, (real)0.85, &C, &m));
    put("v [m/s]", m.st.v);
    put("hf [m]", m.st.hf);
    put("HB [m]", m.Hm);
    put("Pn [kW]", m.Pn / 1000.0);
    put("Pb [kW]", m.Pb / 1000.0);
    end();

    begin("P-13");
    p = P(0.040, 800, 0.045e-3, 0, 0);
    cfg(1.007e-6, FM_CW);
    put("error", hydro_pump(&p, (real)0.010, 70, (real)0.85, &C, &m));
    put("v [m/s]", m.st.v);
    put("Re", m.st.Re);
    put("f CW", m.st.f);
    put("hf [m]", m.st.hf);
    put("HB [m]", m.Hm);
    put("Pn [kW]", m.Pn / 1000.0);
    put("Pb [kW]", m.Pb / 1000.0);
    end();

    begin("P-14");
    p = P(0.150, 1300, 0.0015e-3, 5, 0);
    cfg(1e-6, FM_CW);
    put("error", hydro_pump(&p, (real)0.025, 40, (real)0.60, &C, &m));
    put("v [m/s]", m.st.v);
    put("Re", m.st.Re);
    put("f", m.st.f);
    put("hf [m]", m.st.hf);
    put("hm [m]", m.st.hm);
    put("HB [m]", m.Hm);
    put("Pn [kW]", m.Pn / 1000.0);
    put("Pb [kW]", m.Pb / 1000.0);
    end();
}

static const real L_150_400[] = { 0.150, 0.200, 0.250, 0.300, 0.350, 0.400 };
static const real L_PVC25[] = { 0.05321, 0.06445, 0.07844, 0.10084, 0.14846,
                                0.19328, 0.24095, 0.28575, 0.35864 };
static const real L_200_500[] = { 0.200, 0.250, 0.300, 0.350, 0.400,
                                  0.450, 0.500 };
static const real L_P22[] = { 0.100, 0.150, 0.200, 0.250, 0.300 };

static void design_basic(const char *id, double Qd, double L, double H,
                         double ks, double K, double nu, const real *list,
                         int n)
{
    hydro_pipe p = P(0, L, ks, K, 0);
    hydro_design_res r;
    hydro_log lg;
    begin(id);
    cfg(nu, FM_CW);
    put("error", hydro_design(&p, (real)Qd, (real)H, list, n, &C, &r, &lg));
    put("D exacto [mm]", 1000.0 * r.D_exact);
    put("D comercial [mm]", 1000.0 * r.D_com);
    put("Qmax [l/s]", 1000.0 * r.qmax.st.Q);
    put("hm/hf [%]", 100.0 * r.qmax.st.hm / r.qmax.st.hf);
    put("hm/hf D exacto Qd [%]", 100.0 * r.st_exact.hm / r.st_exact.hf);
    put("hm/hf D com Qd [%]", 100.0 * r.st_com_qd.hm / r.st_com_qd.hf);
    put("iteraciones", r.iters);
    put("vp [m/s]", r.vp);
    end();
}

static void case_D(void)
{
    hydro_pipe p;
    hydro_design_res r, rs;
    hydro_qmax_res q;
    hydro_valve_res vr;
    hydro_machine_res m;
    hydro_state s;
    double HB, Hd;

    design_basic("P-15", 0.200, 450, 8, 0.25e-3, 2.5, 1.17e-6, L_150_400, 6);
    design_basic("P-16a", 0.300, 1250, 16, 0.046e-3, 2.5, 1.17e-6,
                 L_150_400, 6);
    design_basic("P-16b", 0.300, 1250, 16, 0.0015e-3, 2.5, 1.17e-6,
                 L_150_400, 6);

    begin("P-17");
    p = P(0, 1900, 0.0015e-3, 12.8, 0);
    cfg(1e-6, FM_CW);
    put("error", hydro_design(&p, (real)0.2, 76, L_PVC25, 9, &C, &r, 0));
    cfg(1e-6, FM_SJ);
    hydro_design(&p, (real)0.2, 76, L_PVC25, 9, &C, &rs, 0);
    put("D exacto CW [mm]", 1000.0 * r.D_exact);
    put("D exacto SJ [mm]", 1000.0 * rs.D_exact);
    put("D comercial [mm]", 1000.0 * r.D_com);
    put("Qmax 285.75 [l/s]", 1000.0 * r.qmax.st.Q);
    cfg(1e-6, FM_CW);
    p.D = (real)0.285;
    hydro_qmax(&p, 76, &C, &q, 0);
    put("Qmax 285.00 [l/s]", 1000.0 * q.st.Q);
    put("v 285.00 [m/s]", q.st.v);
    put("hf 285.00 [m]", q.st.hf);
    put("hm 285.00 [m]", q.st.hm);
    end();

    begin("P-18");
    p = P(0.28575, 1900, 0.0015e-3, 12.8, 0);
    cfg(1e-6, FM_SJ);
    hydro_pipe_state(&p, (real)0.2, &C, &s);
    put("f SJ", s.f);
    cfg(1e-6, FM_CW);
    put("error", hydro_valve(&p, (real)0.2, 76, &C, &vr));
    put("v [m/s]", vr.st.v);
    put("Re", vr.st.Re);
    put("f CW", vr.st.f);
    put("hf [m]", vr.st.hf);
    put("hm [m]", vr.st.hm);
    put("hT [m]", vr.st.hT);
    put("hv [m]", vr.hv);
    put("Kv", vr.Kv);
    end();

    begin("P-19");
    put("error", hydro_turbine(&p, (real)0.2, 76, (real)0.65, &C, &m));
    put("HT [m]", m.Hm);
    put("Pb [kW]", m.Pb / 1000.0);
    put("Pn [kW]", m.Pn / 1000.0);
    end();

    begin("P-20");
    put("error", hydro_pump(&p, (real)0.2, 76, (real)0.60, &C, &m));
    put("HB [m]", m.Hm);
    put("Pn [kW]", m.Pn / 1000.0);
    put("Pb [kW]", m.Pb / 1000.0);
    put("cota piezometrica [m]", 1015.0 + m.Hm);
    end();

    begin("P-21");
    p = P(0, 600, 0.0015e-3, 5, 0);
    cfg(1.02e-6, FM_CW);
    put("error", hydro_design(&p, (real)0.4, 8, L_200_500, 7, &C, &r, 0));
    cfg(1.02e-6, FM_SJ);
    hydro_design(&p, (real)0.4, 8, L_200_500, 7, &C, &rs, 0);
    put("D exacto CW [mm]", 1000.0 * r.D_exact);
    put("D exacto SJ [mm]", 1000.0 * rs.D_exact);
    put("D comercial [mm]", 1000.0 * r.D_com);
    put("Qmax [l/s]", 1000.0 * r.qmax.st.Q);
    put("hf [m]", r.qmax.st.hf);
    put("hm [m]", r.qmax.st.hm);
    end();

    begin("P-22");
    cfg(1.007e-6, FM_CW);
    HB = hydro_head_from_power(15000, (real)0.75, (real)0.03, &C);
    Hd = HB - 30.0;
    p = P(0, 800, 0.15e-3, 2.8, 0);
    put("HB [m]", HB);
    put("hT disponible [m]", Hd);
    put("error", hydro_design(&p, (real)0.03, (real)Hd, L_P22, 5, &C, &r, 0));
    put("D exacto [mm]", 1000.0 * r.D_exact);
    put("D comercial [mm]", 1000.0 * r.D_com);
    put("Qmax 200 [l/s]", 1000.0 * r.qmax.st.Q);
    put("hf 200 [m]", r.qmax.st.hf);
    put("hm 200 [m]", r.qmax.st.hm);
    p.D = (real)0.150;
    hydro_qmax(&p, (real)Hd, &C, &q, 0);
    put("Qmax 150 [l/s]", 1000.0 * q.st.Q);
    end();
}

static void case_E(void)
{
    hydro_fric fr;
    hydro_calib_res c;

    cfg(1e-6, FM_CW);
    begin("P-24a");
    hydro_friction(20000, (real)1e-4, FM_CW, &C, &fr);
    put("f CW", fr.f);
    put("iteraciones", fr.iters);
    end();
    begin("P-24b");
    hydro_friction(200000, (real)1.5e-4, FM_CW, &C, &fr);
    put("f CW", fr.f);
    put("iteraciones", fr.iters);
    end();

    begin("P-25");
    cfg(1.17e-6, FM_CW);
    put("error", hydro_calibrate((real)0.274, 405, (real)0.172, (real)3.5,
                                 1135 - 1070, 36 - 84, &C, &c));
    put("hf+hm [m]", c.htot);
    put("v [m/s]", c.v);
    put("hm [m]", c.hm);
    put("hf [m]", c.hf);
    put("f", c.f);
    put("ks [mm]", 1000.0 * c.ks);
    put("Re", c.Re);
    end();
}

/* ------------------------------------------------------------------ */
static void case_S(void)
{
    hydro_net n;
    unsigned char k[4];
    int a, b, cc, d, par, e;
    real H;

    /* S-01: Serie[A, Paralelo[B, C, D]] */
    begin("S-01");
    cfg(1e-6, FM_CW);
    hydro_net_init(&n);
    a = hydro_net_add_pipe(&n, 100, (real)0.15, (real)0.020, 0, 0);
    b = hydro_net_add_pipe(&n, 100, (real)0.10, (real)0.015, 0, 5);
    cc = hydro_net_add_pipe(&n, 100, (real)0.10, (real)0.015, 0, 5);
    d = hydro_net_add_pipe(&n, 100, (real)0.10, (real)0.015, 0, 5);
    k[0] = b; k[1] = cc; k[2] = d;
    par = hydro_net_add_group(&n, NODE_PARALLEL, k, 3);
    k[0] = a; k[1] = par;
    hydro_net_add_group(&n, NODE_SERIES, k, 2);
    put("error", hydro_net_solve(&n, 20, &C));
    put("M_A", n.node[a].M);
    put("M_B", n.node[b].M);
    put("M_B friccion", n.node[b].Mf);
    put("M_B local", n.node[b].Mk);
    put("M_BCD", n.node[par].M);
    put("M total", n.node[n.root].M);
    put("Q [l/s]", 1000.0 * n.node[n.root].Q);
    put("h_A [m]", n.node[a].h);
    put("h_B [m]", n.node[b].h);
    put("Q_B [l/s]", 1000.0 * n.node[b].Q);
    put("residuo Q", n.res_q);
    put("residuo h", n.res_h);
    end();

    /* S-02: Serie[Paralelo[A, B], C] */
    begin("S-02");
    hydro_net_init(&n);
    a = hydro_net_add_pipe(&n, 500, (real)0.15, (real)0.014, 0, 0);
    b = hydro_net_add_pipe(&n, 600, (real)0.10, (real)0.018, 0, 0);
    cc = hydro_net_add_pipe(&n, 700, (real)0.20, (real)0.015, 0, 5);
    k[0] = a; k[1] = b;
    par = hydro_net_add_group(&n, NODE_PARALLEL, k, 2);
    k[0] = par; k[1] = cc;
    hydro_net_add_group(&n, NODE_SERIES, k, 2);
    put("error", hydro_net_solve(&n, 20, &C));
    put("M_A", n.node[a].M);
    put("M_B", n.node[b].M);
    put("M_C", n.node[cc].M);
    put("M_C friccion", n.node[cc].Mf);
    put("M_C local", n.node[cc].Mk);
    put("M_AB", n.node[par].M);
    put("M total", n.node[n.root].M);
    put("Q [l/s]", 1000.0 * n.node[n.root].Q);
    put("h_C [m]", n.node[cc].h);
    put("h_A [m]", n.node[a].h);
    put("Q_A [l/s]", 1000.0 * n.node[a].Q);
    put("Q_B [l/s]", 1000.0 * n.node[b].Q);
    put("residuo Q", n.res_q);
    put("residuo h", n.res_h);
    end();

    /* S-03: Serie[1, Paralelo[2, 3], 4] */
    begin("S-03");
    hydro_net_init(&n);
    a = hydro_net_add_pipe(&n, 100, (real)0.10, (real)0.025, 0, 0);
    b = hydro_net_add_pipe(&n, 100, (real)0.10, (real)0.025, 0, 0);
    cc = hydro_net_add_pipe(&n, 100, (real)0.20, (real)0.020, 0, 30);
    d = hydro_net_add_pipe(&n, 100, (real)0.10, (real)0.025, 0, 0);
    k[0] = b; k[1] = cc;
    par = hydro_net_add_group(&n, NODE_PARALLEL, k, 2);
    k[0] = a; k[1] = par; k[2] = d;
    hydro_net_add_group(&n, NODE_SERIES, k, 3);
    put("error", hydro_net_solve(&n, 24, &C));
    put("M_1", n.node[a].M);
    put("M_3", n.node[cc].M);
    put("M_3 friccion", n.node[cc].Mf);
    put("M_3 local", n.node[cc].Mk);
    put("M_23", n.node[par].M);
    put("Q [l/s]", 1000.0 * n.node[n.root].Q);
    put("h_1 [m]", n.node[a].h);
    put("h_23 [m]", n.node[par].h);
    put("Q_3 [l/s]", 1000.0 * n.node[cc].Q);
    put("Q_2 [l/s]", 1000.0 * n.node[b].Q);
    put("h_4 [m]", n.node[d].h);
    end();

    /* S-04: Serie[1, Paralelo[2, 3, 4]], hacia atras con Q4 = 40 l/s */
    begin("S-04");
    hydro_net_init(&n);
    a = hydro_net_add_pipe(&n, 400, (real)0.20, (real)0.020, 0, 0);
    b = hydro_net_add_pipe(&n, 180, (real)0.10, (real)0.025, 0, 0);
    cc = hydro_net_add_pipe(&n, 50, (real)0.10, (real)0.025, 0, 0);
    d = hydro_net_add_pipe(&n, 400, (real)0.20, (real)0.020, 0, 0);
    k[0] = b; k[1] = cc; k[2] = d;
    par = hydro_net_add_group(&n, NODE_PARALLEL, k, 3);
    k[0] = a; k[1] = par;
    hydro_net_add_group(&n, NODE_SERIES, k, 2);
    H = 0;
    e = hydro_net_solve_back(&n, (unsigned char)d, (real)0.040, &C, &H);
    put("error", e);
    put("M_1", n.node[a].M);
    put("M_2", n.node[b].M);
    put("M_3", n.node[cc].M);
    put("M_234", n.node[par].M);
    put("h_4 [m]", n.node[d].h);
    put("Q_2 [l/s]", 1000.0 * n.node[b].Q);
    put("Q_3 [l/s]", 1000.0 * n.node[cc].Q);
    put("Q_1 [l/s]", 1000.0 * n.node[a].Q);
    put("h_1 [m]", n.node[a].h);
    put("carga total [m]", H);
    put("p tanque A [kPa]", H * C.gamma / 1000.0);
    put("Q_4 [l/s]", 1000.0 * n.node[d].Q);
    end();

    /* S-05: Serie[A, Paralelo[B, C], D] */
    begin("S-05");
    hydro_net_init(&n);
    a = hydro_net_add_pipe(&n, 700, (real)0.30, (real)0.014, 0, 5);
    b = hydro_net_add_pipe(&n, 600, (real)0.15, (real)0.020, 0, 0);
    cc = hydro_net_add_pipe(&n, 500, (real)0.20, (real)0.011, 0, 0);
    d = hydro_net_add_pipe(&n, 600, (real)0.25, (real)0.028, 0, 3);
    k[0] = b; k[1] = cc;
    par = hydro_net_add_group(&n, NODE_PARALLEL, k, 2);
    k[0] = a; k[1] = par; k[2] = d;
    hydro_net_add_group(&n, NODE_SERIES, k, 3);
    put("error", hydro_net_solve(&n, 75, &C));
    put("M_A", n.node[a].M);
    put("M_B", n.node[b].M);
    put("M_C", n.node[cc].M);
    put("M_D", n.node[d].M);
    put("M_BC", n.node[par].M);
    put("M total", n.node[n.root].M);
    put("Q [l/s]", 1000.0 * n.node[n.root].Q);
    put("h_A [m]", n.node[a].h);
    put("h_BC [m]", n.node[par].h);
    put("h_D [m]", n.node[d].h);
    put("Q_B [l/s]", 1000.0 * n.node[b].Q);
    put("Q_C [l/s]", 1000.0 * n.node[cc].Q);
    end();
}

/* ------------------------------------------------------------------ */
static void case_R(void)
{
    hydro_pipe p;
    hydro_state s;
    hydro_qmax_res q;
    hydro_design_res dr;
    hydro_net n;
    unsigned char k[1];
    double hp;

    begin("R-02");
    cfg(1e-6, FM_CW);
    p = P(0.020, 50, 0.0015e-3, 0, 0);
    hydro_pipe_state(&p, (real)2e-5, &C, &s);
    hp = 128.0 * 1e-6 * 50 * 2e-5 / (9.81 * 3.14159265358979 * pow(0.02, 4));
    put("Re", s.Re);
    put("aviso laminar", (s.warn & W_LAMINAR) ? 1 : 0);
    put("f*Re", s.f * s.Re);
    put("hf / Hagen-Poiseuille", s.hf / hp);
    hydro_qmax(&p, s.hT, &C, &q, 0);
    put("Q de vuelta [l/s]", 1000.0 * q.st.Q);
    end();

    begin("R-03");
    p = P(0.050, 100, 0.0015e-3, 0, 0);
    /* Re = 3000: v = 3000 nu / D */
    hydro_pipe_state(&p, (real)(3000 * 1e-6 / 0.05 * 3.14159265358979 *
                                0.05 * 0.05 / 4), &C, &s);
    put("Re", s.Re);
    put("aviso transicion", (s.warn & W_TRANSITION) ? 1 : 0);
    put("f indicativo", s.f);
    end();

    begin("R-04");
    p = P(0, 100, 0, 0, 0);
    put("error D=0", hydro_pipe_state(&p, 1, &C, &s));
    put("error Qmax D=0", hydro_qmax(&p, 10, &C, &q, 0));
    p = P(0.1, -5, 0, 0, 0);
    put("error L<0", hydro_pipe_state(&p, 1, &C, &s));
    put("error diseno L<0", hydro_design(&p, 1, 10, 0, 0, &C, &dr, 0));
    p = P(0.1, 100, 0, 0, 0);
    put("error Q=0", hydro_pipe_state(&p, 0, &C, &s));
    p = P(0.1, 100, 0, -1, 0);
    put("error K<0", hydro_pipe_state(&p, 1, &C, &s));
    p = P(0.1, 100, 0, 0, 0);
    C.nu = 0;
    put("error nu=0", hydro_pipe_state(&p, 1, &C, &s));
    end();

    begin("R-05");
    cfg(1e-6, FM_CW);
    p = P(0.1, 100, 0.0015e-3, 2, 0);
    put("error H<0", hydro_qmax(&p, -5, &C, &q, 0));
    put("error H=0", hydro_qmax(&p, 0, &C, &q, 0));
    hydro_net_init(&n);
    hydro_net_add_pipe(&n, 100, (real)0.1, (real)0.02, 0, 0);
    (void)k;
    put("error red H=0", hydro_net_solve(&n, 0, &C));
    end();
}

int golden_counts(int *pass, int *pass_r, int *fail, int *missing)
{
    *pass = n_pass;
    *pass_r = n_pass_r;
    *fail = n_fail;
    *missing = n_missing;
    return n_fail || n_missing;
}

int golden_run(int verb)
{
    verbose = verb;
    OUT("Motor compilado con real = %s\n\n",
           sizeof(real) == sizeof(double) ? "double" : "float");
    OUT("| Caso | Magnitud | Esperado | Obtenido | Error rel. | Resultado |\n");
    OUT("|---|---|---|---|---|---|\n");
    case_P01_P02();
    case_B();
    case_C();
    case_D();
    case_E();
    case_S();
    case_R();
    OUT("\nTotal: %d pasan (0,1 %%), %d pasan por redondeo (r), "
           "%d fallan, %d sin dato\n", n_pass, n_pass_r, n_fail, n_missing);
    return (n_fail || n_missing) ? 1 : 0;
}

#ifndef GOLDEN_NO_MAIN
int main(int argc, char **argv)
{
    if (argc > 2 && !strcmp(argv[1], "-g")) {   /* volcar valores obtenidos */
        FILE *f;
        size_t i;
        int r = golden_run(0);
        f = fopen(argv[2], "w");
        for (i = 0; f && i < GOLDEN_N; i++)
            fprintf(f, "%u;%s;%s;%.9g;%d;%g;%g;%.9g\n", (unsigned)i,
                    golden[i].id, golden[i].name, golden[i].expected,
                    golden[i].dec, golden[i].tol_rel, golden[i].tol_abs,
                    golden_got[i]);
        if (f)
            fclose(f);
        return r;
    }
    return golden_run(argc > 1 && !strcmp(argv[1], "-v"));
}
#endif
