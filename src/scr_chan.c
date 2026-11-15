/*
 * scr_chan.c - v2.0: canales y medicion (prompt v2, sec. 4.6).
 *   0 EX-1 Venturi con manometro diferencial (convencion fisica o la de la
 *     solucion del examen 2025)
 *   1 EX-2 salto hidraulico en canal rectangular (dado y1 o dado y2)
 *   2 EX-3 chorro desde un tubo: Q con el motor de tuberia tipo B (caudal
 *     maximo) y luego la trayectoria
 * (EX-4 placa plana y Stokes esta en scr_drag.c.)
 */
#include <string.h>
#include "app.h"
#include "memo_run.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "hydro/chan.h"

enum { CT_VENT = 0, CT_JUMP, CT_JET, CT_COUNT };

static struct {
    real D1, D2, beta, Q, v1, Cv, S, b, y, H, L, D, ks, nu, K, th;
    uint8_t sD1, sD2, sbeta, sQ, sv1, sCv, sS, sb, sy, sH, sL, sD, sks, snu, sK, sth;
    uint8_t qunit, conv, ymode, exitk, init;
} ci;

static const char *const qu_names[2] = { "l/s", "m3/s" };
static const char *const cv_names[2] = { "(S-1) g h fisico", "S g h examen" };
static const char *const ym_names[2] = { "Dado y1", "Dado y2" };
static const char *const yn_names[2] = { "No (SumK = K)", "Si (SumK + 1)" };

#define FN(lab, un, v, fl) { lab, un, &ci.v, 0, &ci.s##v, fl, 0, 0, 0, 0 }
#define FC(lab, v, names, n) { lab, 0, 0, &ci.v, 0, FF_CHOICE, names, n, 0, 0 }

static form_field f_vent[] = {
    FN("D1 entrada", "mm", D1, FF_POS),
    FN("D2 garganta (opc)", "mm", D2, FF_POS | FF_OPT),
    FN("o D2/D1 (opc)", 0, beta, FF_POS | FF_OPT),
    FN("Caudal Q (o v1)", "l/s", Q, FF_POS | FF_OPT),
    FC("Unidad de Q", qunit, qu_names, 2),
    FN("o v1 (opc)", "m/s", v1, FF_POS | FF_OPT),
    { "Cv", 0, &ci.Cv, 0, &ci.sCv, FF_RANGE, 0, 0, 0.01, 1 },
    FN("S manometro (opc)", 0, S, FF_POS | FF_OPT),
    FC("Manometro", conv, cv_names, 2),
};
static form_field f_jump[] = {
    FN("Caudal Q", "m3/s", Q, FF_POS),
    FN("Ancho b", "m", b, FF_POS),
    FC("Dato", ymode, ym_names, 2),
    FN("Tirante y1 o y2", "m", y, FF_POS),
};
static form_field f_jet[] = {
    FN("Carga H", "m", H, FF_POS),
    FN("Longitud L", "m", L, FF_POS),
    FN("Diametro D", "mm", D, FF_POS),
    FN("Rugosidad ks", "mm", ks, FF_NONNEG),
    FN("Viscosidad nu", "m2/s", nu, FF_POS),
    FN("Suma K", 0, K, FF_NONNEG),
    FC("Energia salida", exitk, yn_names, 2),
    FN("Angulo theta", "grad", th, FF_RANGE),
};

static const char *const titles[CT_COUNT] = {
    "VENTURI Y MANOMETRO (EX-1)", "SALTO HIDRAULICO (EX-2)",
    "CHORRO DESDE UN TUBO (EX-3)"
};
static form_field *const forms[CT_COUNT] = { f_vent, f_jump, f_jet };
static const uint8_t nforms[CT_COUNT] = {
    sizeof f_vent / sizeof f_vent[0], sizeof f_jump / sizeof f_jump[0],
    sizeof f_jet / sizeof f_jet[0] };

static uint8_t tipo;
static hydro_cfg C;
#define LG memo_lg

static void on_commit(void)
{
    f_vent[3].unit = qu_names[ci.qunit];
}

static const char *compute(void)
{
    int err = 0;
    memo_reset();
    C = g_set.h;
    memo_cfg = &C;
    memo_hook = 0;
    memo_log = 0;
    memo_V[V_G] = C.g;
    memo_V[V_GAM] = C.gamma;
    if (tipo == CT_VENT) {
        chan_venturi_res r;
        real D1 = ci.D1 / 1000, D2, Q;
        if (ci.sD2)
            D2 = ci.D2 / 1000;
        else if (ci.sbeta)
            D2 = ci.beta * D1;
        else
            return "Falta D2 o D2/D1";
        if (ci.sv1) {
            Q = ci.v1 * hydro_area(D1);
            MSETF(G_VV1, 1);
        } else if (ci.sQ) {
            Q = ci.qunit ? ci.Q : ci.Q / 1000;
        } else {
            return "Falta Q o v1";
        }
        err = chan_venturi(D1, D2, Q, ci.Cv, ci.sS ? ci.S : 0, ci.conv, &C, &r);
        if (err)
            return D2 >= D1 ? "D2 debe ser menor que D1" : hydro_err_text(err);
        memo_V[V_VD1] = D1;
        memo_V[V_VD2] = D2;
        memo_V[V_VBETA] = r.beta;
        memo_V[V_VB4] = r.beta * r.beta * r.beta * r.beta;
        memo_V[V_VA1] = r.A1;
        memo_V[V_VA2] = r.A2;
        memo_V[V_VV1] = r.v1;
        memo_V[V_VV2] = r.v2;
        memo_V[V_VDP] = r.dp;
        memo_V[V_VDPK] = r.dp / 1000;
        memo_V[V_VH] = r.h;
        memo_V[V_VS] = ci.S;
        memo_V[V_VSF] = ci.conv ? ci.S : ci.S - 1;
        memo_V[V_VCV] = ci.Cv;
        memo_V[V_VQ] = Q;
        memo_V[V_VQLS] = Q * 1000;
        MSETF(G_VMANO, ci.sS);
        MSETF(G_VEXAM, ci.conv);
        MSETF(G_VCV, ci.Cv != 1);
    } else if (tipo == CT_JUMP) {
        chan_jump_res r;
        err = chan_jump(ci.Q, ci.b, ci.y, ci.ymode, &C, &r);
        if (err == H_ERR_NOJUMP)
            return ci.ymode ? "Fr2 >= 1: y2 no es subcritico"
                            : "Fr1 <= 1: no hay salto hidraulico";
        if (err)
            return hydro_err_text(err);
        memo_V[V_JQ] = ci.Q;
        memo_V[V_JB] = ci.b;
        memo_V[V_JQQ] = r.q;
        memo_V[V_JY1] = r.y1;
        memo_V[V_JY2] = r.y2;
        memo_V[V_JV1] = r.v1;
        memo_V[V_JV2] = r.v2;
        memo_V[V_JFR1] = r.Fr1;
        memo_V[V_JFR2] = r.Fr2;
        memo_V[V_JE1] = r.E1;
        memo_V[V_JE2] = r.E2;
        memo_V[V_JDE] = r.dE;
        memo_V[V_JP] = r.P / 1000;
        memo_V[V_JEFF] = 100 * r.eff;
        MSETF(G_JY2, ci.ymode);
    } else {
        hydro_pipe p;
        hydro_qmax_res q;
        chan_jet_res j;
        C.nu = ci.nu;
        p.D = ci.D / 1000;
        p.L = ci.L;
        p.ks = ci.ks / 1000;
        p.sumK = ci.K + (ci.exitk ? 1 : 0);
        p.f_fixed = 0;
        hydro_log_clear(&LG);
        err = hydro_qmax(&p, ci.H, &C, &q, &LG);
        if (err)
            return hydro_err_text(err);
        err = chan_jet(q.st.v, ci.th, C.g, &j);
        if (err)
            return hydro_err_text(err);
        memo_V[V_EH] = ci.H;
        memo_V[V_EL] = ci.L;
        memo_V[V_ED] = p.D;
        memo_V[V_EKS] = p.ks;
        memo_V[V_NU] = ci.nu;
        memo_V[V_EK] = p.sumK;
        memo_V[V_EQ] = q.st.Q;
        memo_V[V_EQLS] = q.st.Q * 1000;
        memo_V[V_EV] = q.st.v;
        memo_V[V_ERE] = q.st.Re;
        memo_V[V_EF] = q.st.f;
        memo_V[V_ELD] = p.L / p.D;
        memo_V[V_EIT] = q.iters;
        memo_V[V_ETH] = ci.th;
        memo_V[V_EVX] = j.vx;
        memo_V[V_EVY] = j.vy;
        memo_V[V_EHM] = j.hmax;
        memo_V[V_ER] = j.R;
        memo_V[V_ET] = j.t;
        memo_W = q.st.warn;
        memo_log = &LG;
        MSETF(G_EK1, ci.exitk);
        MSETF(G_EBIS, q.solver == SOLV_BISECTION);
    }
    return 0;
}

static void result_loop(void)
{
    static const char *const fk_sum[5] = { "MEMORIA", "", "", "", "VOLVER" };
    static const char *const fk_memo[5] = { "RESUMEN", "", "", "", "VOLVER" };
    bool memo = false;
    uint8_t k;
    for (;;) {
        memo_show(PROG_X(XP_EX1_SUM + 2 * tipo + memo));
        k = view_run(titles[tipo], memo ? fk_memo : fk_sum);
        if (k == K_F1)
            memo = !memo;
        else if (k == K_MODE)
            scr_settings();
        else
            return;
        if (ui_quit)
            return;
    }
}

void scr_chan(uint8_t t)
{
    static uint8_t cur[CT_COUNT];
    form_t fm;
    uint8_t k;
    const char *err;
    if (t >= CT_COUNT)
        return;
    tipo = t;
    if (!ci.init) {
        ci.init = 1;
        ci.Cv = 1;
        ci.nu = g_set.h.nu;
        ci.K = 0;
        ci.th = 30;
        ci.sCv = ci.snu = ci.sK = ci.sth = 1;
        ci.conv = g_set.mano;
    }
    f_jet[7].lo = 0;
    f_jet[7].hi = 90;
    memset(&fm, 0, sizeof fm);
    fm.title = titles[t];
    fm.f = forms[t];
    fm.n = nforms[t];
    fm.cur = cur[t];
    fm.fk[3] = "AJUSTES";
    fm.fk[4] = "CALC";
    fm.on_commit = on_commit;
    on_commit();
    fm.hint = t == CT_VENT ? "Use el Q que pide el enunciado"
            : t == CT_JUMP ? "Canal rectangular" : "theta sobre la horizontal";
    for (;;) {
        k = form_run(&fm);
        if (k == K_QUIT || k == K_CLEAR)
            break;
        if (k == K_F4 || k == K_MODE) {
            scr_settings();
            continue;
        }
        if (k == K_F5 || k == K_ENTER) {
            if (!form_check(&fm))
                continue;
            err = compute();
            if (err) {
                fm.msg = err;
                fm.msg_color = C_ERR;
                continue;
            }
            result_loop();
            if (ui_quit)
                break;
        }
    }
    cur[t] = fm.cur;
}
