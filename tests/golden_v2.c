/*
 * golden_v2.c - Casos dorados de la v2.0 (prompt v2, sec. 8): arrastre y
 * sustentacion, vertedores y orificios, canales y "Calcular f".
 * Se incluye desde golden.c (usa begin, put, end, cfg, P y C).
 */
#include "../src/hydro/drag.h"
#include "../src/hydro/weir.h"
#include "../src/hydro/chan.h"

static const real ld_x[5] = { 1, 2, 5, 10, 40 };
static const real ld_y[5] = { 0.6, 0.7, 0.8, 0.9, 1.0 };

static void tower(double cdc, double cds)
{
    drag_body b[2];
    drag_struct_res r;
    real V = (real)(100.0 / 3.6);
    b[0].Cd = (real)cdc; b[0].A = 60; b[0].y = 15; b[0].V = V;
    b[0].Lref = 2; b[0].kind = DK_LONGCYL;
    b[1].Cd = (real)cds; b[1].A = hydro_area(12); b[1].y = 36; b[1].V = V;
    b[1].Lref = 12; b[1].kind = DK_SPHERE;
    drag_struct(b, 2, (real)1.2, (real)1.5e-5, &r);
    put("q [Pa]", drag_q((real)1.2, V));
    put("F1 [kN]", r.F[0] / 1000);
    put("F2 [kN]", r.F[1] / 1000);
    put("M [kN m]", r.M / 1000);
    put("ycp [m]", r.ycp);
    put("aviso crisis esf", (r.w[1] & DW_CRISIS) ? 1 : 0);
}

static void term(drag_term_res *t, double W, double rho, double vol,
                 double cd, double A, double L, double nu)
{
    drag_terminal((real)W, (real)rho, (real)vol, (real)cd, (real)A, (real)L,
                  (real)nu, (real)9.81, DK_GENERIC, t);
}

static void case_AR(void)
{
    drag_term_res t;
    drag_plane_res pl;
    drag_plate_res pp;
    unsigned char i0;
    unsigned int w = 0;
    real A = hydro_area(8), cd, rho, V;

    begin("AR-01");
    term(&t, 950, 1.2, 0, 1.3, A, 8, 1.5e-5);
    put("vt CD=1.3 [m/s]", t.v);
    put("Re", t.Re);
    term(&t, 950, 1.2, 0, 1.42, A, 8, 1.5e-5);
    put("vt CD=1.42 [m/s]", t.v);
    end();

    begin("AR-02a");
    cd = drag_interp(ld_x, ld_y, 5, 15, &i0, &w);
    put("CD cil interp", cd);
    tower(cd, 0.5);
    end();
    begin("AR-02b");
    tower(1.2, 0.5);
    end();
    begin("AR-02c");
    tower(0.3, 0.2);
    end();

    begin("AR-03a");
    term(&t, 19.8, 1000, 1e-3, 0.8, 0.01, 0.1, 1e-6);
    put("B [N]", t.B);
    put("vt [m/s]", t.v);
    end();
    begin("AR-03b");
    term(&t, 19.8, 1000, 1e-3, 0.8, 0.01 * 1.41421356, 0.1, 1e-6);
    put("vt [m/s]", t.v);
    end();
    begin("AR-03c");
    term(&t, 19.8, 1000, 1e-3, 1.05, 0.01, 0.1, 1e-6);
    put("vt [m/s]", t.v);
    end();

    begin("AR-04");
    rho = drag_rho_alt(10675);
    V = (real)(480 * 1.85 / 3.6);
    put("rho [kg/m3]", rho);
    drag_plane_lift((real)3.9e6, rho, V, (real)180.8, 2, &pl);
    put("q [Pa]", pl.q);
    put("CL", pl.CL);
    drag_plane_thrust((real)3.9e6, rho, V, (real)0.0088, 1, (real)5.28, 0,
                      &pl);
    put("Afus [m2]", pl.Afus);
    put("Dfus [kN]", pl.Df / 1000);
    put("Dalas [kN]", pl.Dw / 1000);
    put("T [kN]", pl.T / 1000);
    end();

    begin("AR-05");
    put("Re", drag_re((real)1e-3, (real)1e-3, (real)1e-6));
    put("FD Stokes [nN]",
        drag_stokes((real)1e-3, (real)1e-3, (real)1e-3) * 1e9);
    put("aviso Stokes",
        (drag_re_warn((real)0.999, DK_SPHERE) & DW_STOKES) ? 1 : 0);
    end();

    begin("AR-06");
    drag_plate(2, 1, 10, (real)1.2, (real)1.5e-5, 1, PL_TURB, &pp);
    put("ReL", pp.Re);
    put("Cf turb", pp.Cf_turb);
    put("Cf mixto", pp.Cf_mix);
    put("FD turb [N]", pp.F);
    put("aviso laminar NA", (pp.warn & DW_LAM_NA) ? 1 : 0);
    drag_plate(2, 1, 10, (real)1.2, (real)1.5e-5, 1, PL_MIX, &pp);
    put("FD mixto [N]", pp.F);
    end();

    begin("AR-07");
    put("error flota", drag_terminal(5, 1000, (real)1e-3, 1, (real)0.01,
                                     (real)0.1, (real)1e-6, (real)9.81,
                                     DK_GENERIC, &t));
    w = 0;
    put("interp L/D=15", drag_interp(ld_x, ld_y, 5, 15, &i0, &w));
    w = 0;
    put("interp clamp", drag_interp(ld_x, ld_y, 5, 80, &i0, &w));
    put("aviso clamp", (w & DW_CLAMP) ? 1 : 0);
    end();
}

static weir_el WE(unsigned char type, double a, double z, unsigned char n)
{
    weir_el e;
    e.type = type; e.count = n; e.ncon = 0; e.Cd = (real)0.6;
    e.z = (real)z; e.a = (real)a; e.b = 0;
    return e;
}

static void case_VE(void)
{
    weir_el e[2], s1, s2[2];
    real Q, Qi[2], h, h1, h2, vm, Qp;
    real yp[5] = { 0, 0.25, 0.5, 0.75, 1 }, vp[5];
    unsigned int w = 0;
    unsigned char simp, i;
    int it;
    const real g = (real)9.81;

    e[0] = WE(WE_TRI, 90, 1.4, 1);
    e[1] = WE(WE_ORC, 0.2, 0.1, 3);
    begin("VE-01");
    weir_total(e, 2, 2, g, &Q, Qi, &w);
    put("Q tri [m3/s]", Qi[0]);
    put("Q orif c/u [m3/s]", Qi[1] / 3);
    put("Q total [m3/s]", Q);
    end();
    begin("VE-02");
    weir_level(e, 2, (real)0.5, g, &h, Qi, &w, &it);
    put("h [m]", h);
    end();

    e[0] = WE(WE_TRI, 90, 0, 1);
    begin("VE-03");
    weir_level(e, 1, (real)0.2, g, &h, Qi, &w, &it);
    put("H [m]", h);
    end();
    begin("VE-04");
    weir_level(e, 1, (real)0.26064, g, &h, Qi, &w, &it);
    put("H [m]", h);
    end();
    begin("VE-05");
    e[0] = WE(WE_TRI, 60, 0, 1);
    weir_level(e, 1, (real)0.016, g, &h, Qi, &w, &it);
    put("H [m]", h);
    end();
    begin("VE-06");
    e[1] = WE(WE_RECT, 1.3, h, 1);
    weir_level(e, 2, (real)0.036, g, &h, Qi, &w, &it);
    put("h [m]", h);
    put("Q tri [l/s]", Qi[0] * 1000);
    put("Q rec [l/s]", Qi[1] * 1000);
    end();

    begin("VE-07");
    weir_profile_pow(2, 2, 2, 1, &Q, &vm);
    put("Q [m3/s]", Q);
    put("v media [m/s]", vm);
    for (i = 0; i < 5; i++)
        vp[i] = 2 * yp[i] * yp[i];
    weir_profile_pts(yp, vp, 5, 2, &Qp, &vm, &simp);
    put("Q puntos [m3/s]", Qp);
    end();
    begin("VE-08");
    e[0] = WE(WE_TRI, 90, 0, 1);
    weir_level(e, 1, Q, g, &h, Qi, &w, &it);
    put("H [m]", h);
    put("h0 [m]", 1 - h);
    end();

    begin("VE-09");
    s1 = WE(WE_TRI, 90, 0, 1);
    s2[0] = s1;
    s2[1] = WE(WE_RECT, 1, 100, 1);     /* nunca recibe agua */
    weir_level(&s1, 1, (real)0.2, g, &h1, Qi, &w, &it);
    weir_level(s2, 2, (real)0.2, g, &h2, Qi, &w, &it);
    put("equivalencia 1 tri", fabs((double)(h1 - h2)) < 1e-5 * h1);
    put("error Q=0", weir_level(&s1, 1, 0, g, &h1, Qi, &w, &it));
    s1 = WE(WE_ORC, 0, 0, 1);
    put("error d=0", weir_total(&s1, 1, 1, g, &Q, Qi, &w));
    s1 = WE(WE_ORC, 0.2, 1, 1);
    w = 0;
    weir_total(&s1, 1, (real)1.05, g, &Q, Qi, &w);
    put("aviso carga parcial", (w & VW_PARTIAL) ? 1 : 0);
    end();
}

static void case_EX(void)
{
    chan_venturi_res v;
    chan_jump_res j;
    chan_jet_res je;
    hydro_qmax_res q;
    hydro_pipe p;
    real D1 = (real)0.28575, D2 = (real)0.6 * (real)0.28575;

    cfg(1e-6, FM_CW);
    begin("EX-01a");
    chan_venturi(D1, D2, (real)0.2, 1, 4, MANO_EXAM, &C, &v);
    put("v1 [m/s]", v.v1);
    put("v2 [m/s]", v.v2);
    put("dp [Pa]", v.dp);
    put("h S [m]", v.h);
    chan_venturi(D1, D2, (real)0.2, 1, 4, MANO_PHYS, &C, &v);
    put("h S-1 [m]", v.h);
    end();
    begin("EX-01b");
    chan_venturi(D1, D2, (real)0.26064, 1, 4, MANO_PHYS, &C, &v);
    put("dp [Pa]", v.dp);
    put("h S-1 [m]", v.h);
    chan_venturi(D1, D2, (real)0.26064, 1, 4, MANO_EXAM, &C, &v);
    put("h S [m]", v.h);
    end();

    begin("EX-02");
    chan_jump(12, 2, (real)0.4, 0, &C, &j);
    put("q [m2/s]", j.q);
    put("v1 [m/s]", j.v1);
    put("Fr1", j.Fr1);
    put("y2 [m]", j.y2);
    put("v2 [m/s]", j.v2);
    put("E1 [m]", j.E1);
    put("E2 [m]", j.E2);
    put("dE [m]", j.dE);
    put("P [kW]", j.P / 1000);
    chan_jump(12, 2, j.y2, 1, &C, &j);
    put("y1 desde y2 [m]", j.y1);
    put("error sin salto", chan_jump(1, 2, 2, 0, &C, &j));
    end();

    cfg(1.007e-6, FM_CW);
    p = P(0.03, 5, 0.045e-3, 0, 0);
    begin("EX-03a");
    hydro_qmax(&p, (real)7.5, &C, &q, 0);
    chan_jet(q.st.v, 30, C.g, &je);
    put("Q [l/s]", q.st.Q * 1000);
    put("v [m/s]", q.st.v);
    put("Re", q.st.Re);
    put("f", q.st.f);
    put("hmax [m]", je.hmax);
    put("vx [m/s]", je.vx);
    put("R [m]", je.R);
    end();
    p.sumK = 1;
    begin("EX-03b");
    hydro_qmax(&p, (real)7.5, &C, &q, 0);
    chan_jet(q.st.v, 30, C.g, &je);
    put("Q [l/s]", q.st.Q * 1000);
    put("v [m/s]", q.st.v);
    put("hmax [m]", je.hmax);
    end();
}

static void fcase(const char *id, real Re, double ksd)
{
    hydro_fric_tab t;
    begin(id);
    hydro_fric_all(Re, (real)ksd, &C, &t, 0);
    put("Re", Re);
    put("f CW", t.f[FM_CW]);
    put("f SJ", t.f[FM_SJ]);
    put("f Haaland", t.f[FM_HAALAND]);
    put("f GS", t.f[FM_GOUDAR]);
    put("dif SJ [%]", t.dpct[FM_SJ]);
    end();
}

static void case_F(void)
{
    hydro_fric_tab t;
    hydro_log lg;
    real v, Re;
    cfg(1e-6, FM_CW);
    fcase("F-01", 20000, 1e-4);
    fcase("F-02", 200000, 1.5e-4);
    v = (real)0.2 / hydro_area((real)0.28575);
    fcase("F-03", v * (real)0.28575 / (real)1e-6, 0.0015 / 285.75);
    fcase("F-04", 455180, 7.5e-6);
    begin("F-05");
    Re = (real)2e-5 / hydro_area((real)0.02) * (real)0.02 / (real)1e-6;
    hydro_fric_all(Re, 0, &C, &t, &lg);
    put("Re laminar", Re);
    put("f laminar", t.f[FM_CW]);
    put("regimen laminar", t.regime);
    hydro_fric_all(3000, (real)1e-4, &C, &t, &lg);
    put("regimen transicion", t.regime);
    put("log CW filas>2", lg.n > 2);
    put("error Re=0", hydro_fric_all(0, 0, &C, &t, &lg));
    put("error ks/D<0", hydro_fric_all(100000, -1, &C, &t, &lg));
    end();
}

static void golden_v2(void)
{
    case_AR();
    case_VE();
    case_EX();
    case_F();
}
