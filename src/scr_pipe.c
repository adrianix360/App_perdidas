/*
 * scr_pipe.c - Tuberia simple: tipos A, B, C, D, E, F e I.
 * Cada tipo: formulario -> calculo con el motor -> resumen y memoria de
 * calculo paso a paso (DATOS, CALCULOS, ITERACIONES, RESULTADOS,
 * OBSERVACIONES). Los datos se comparten entre tipos (ultimo valor).
 * Unidades en pantalla: Q l/s, D mm, ks mm, L m, H m; motor en SI.
 */
#include <string.h>
#include <fileioc.h>
#include "app.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "ui/numfmt.h"
#include "ui/memo.h"
#include "data/data.h"
#include "pipe.h"
#include "ui/graph.h"

/* ------------------------------------------------------------------ */
/* Datos compartidos (unidades de pantalla)                            */
/* ------------------------------------------------------------------ */
pipe_inputs pin;

static const char *const mach_names[2] = { "Bomba", "Turbina" };
static const char *const yesno[2] = { "No", "Si" };
static const char *const modeI_names[2] = { "hf dado Q", "Q dado H" };

/* Resultados del ultimo calculo */
static hydro_cfg C;
static hydro_pipe P;
#define LG memo_lg      /* registro compartido (memo_run.c) */
static union {
    hydro_state st;
    hydro_qmax_res q;
    hydro_machine_res m;
    hydro_design_res d;
    hydro_calib_res k;
    hydro_valve_res v;
} R;
static struct {          /* extras de algunos tipos */
    real ph, hw, err, Qhw;
    hydro_state st2;     /* D: valvula con D comercial */
    hydro_valve_res val;
    uint8_t has_val;
} X;
static real dlist[24];
static uint8_t dlist_n;
static uint8_t tipo;

static const char *const titles[PT_COUNT] = {
    "PERDIDAS DADO Q  (A)", "CAUDAL MAXIMO  (B)", "DIAMETRO DE DISENO (D)",
    "BOMBA O TURBINA  (C)", "VALVULA DE CONTROL (F)", "CALIBRAR RUGOSIDAD (E)",
    "DARCY-W. vs HAZEN-W. (I)"
};

/* ------------------------------------------------------------------ */
/* Campos                                                              */
/* ------------------------------------------------------------------ */
#define FLD(lab, un, v, s, fl) { lab, un, &pin.v, 0, &pin.s, fl, 0, 0, 0, 0 }
#define F_Q   FLD("Caudal Q", "l/s", Q, sQ, FF_POS)
#define F_D   FLD("Diametro D", "mm", D, sD, FF_POS)
#define F_L   FLD("Longitud L", "m", L, sL, FF_POS)
#define F_KS  FLD("Rugosidad ks", "mm", ks, sks, FF_NONNEG)
#define F_K   FLD("Suma K", 0, K, sK, FF_NONNEG)
#define F_NU  FLD("Viscosidad nu", "m2/s", nu, snu, FF_POS)
#define F_F   FLD("f dado (opc.)", 0, f, sf, FF_POS | FF_OPT)
#define F_MET { "Metodo de f", 0, 0, &g_set.h.method, 0, FF_CHOICE, method_names, FM_COUNT, 0, 0 }

static form_field f_A[] = { F_Q, F_D, F_L, F_KS, F_K, F_NU, F_F,
    FLD("H sobre punto(opc)", "m", Hp, sHp, FF_ANY | FF_OPT), F_MET };
static form_field f_B[] = { FLD("Carga H", "m", H, sH, FF_ANY), F_D, F_L,
    F_KS, F_K, F_NU, F_F, F_MET };
static form_field f_C[] = {
    { "Equipo", 0, 0, &pin.mach, 0, FF_CHOICE, mach_names, 2, 0, 0 },
    F_Q, F_D, F_L, F_KS, F_K, F_NU,
    FLD("Desnivel Hs/Ha", "m", Hs, sHs, FF_ANY),
    { "Eficiencia eta", "0-1", &pin.eta, 0, &pin.seta, FF_RANGE, 0, 0, 0.001, 1 },
    F_F, FLD("Cota z equipo(opc)", "m", zb, szb, FF_ANY | FF_OPT), F_MET };
static form_field f_D[] = { FLD("Caudal diseno Qd", "l/s", Q, sQ, FF_POS),
    FLD("Carga H", "m", H, sH, FF_ANY), F_L, F_KS, F_K, F_NU,
    { "Lista diametros", 0, 0, &pin.dset, 0, FF_CHOICE, diam_set_names, DIAM_CHOICES, 0, 0 },
    { "Valvula control", 0, 0, &pin.valve, 0, FF_CHOICE, yesno, 2, 0, 0 },
    F_MET };
static form_field f_F[] = { F_Q, F_D, F_L, F_KS, F_K, F_NU,
    FLD("Carga H", "m", H, sH, FF_ANY), F_F, F_MET };
static form_field f_E[] = {
    FLD("Cota z1", "m", z1, sz1, FF_ANY), FLD("Cota z2", "m", z2, sz2, FF_ANY),
    FLD("Presion p1/gamma", "m", p1, sp1, FF_ANY),
    FLD("Presion p2/gamma", "m", p2, sp2, FF_ANY),
    F_L, F_D, F_Q, F_K, F_NU };
static form_field f_I[] = {
    { "Calcular", 0, 0, &pin.modeI, 0, FF_CHOICE, modeI_names, 2, 0, 0 },
    FLD("Q (modo hf)", "l/s", Q, sQ, FF_POS | FF_OPT),
    FLD("H (modo Q)", "m", H, sH, FF_POS | FF_OPT),
    F_D, F_L, F_KS, FLD("Suma K (solo DW)", 0, K, sK, FF_NONNEG), F_NU,
    { "C_H Hazen-W.", 0, &pin.CH, 0, &pin.sCH, FF_RANGE, 0, 0, 1, 200 },
    F_MET };

static form_field *const forms[PT_COUNT] = { f_A, f_B, f_D, f_C, f_F, f_E, f_I };
static const uint8_t nforms[PT_COUNT] = {
    sizeof f_A / sizeof f_A[0], sizeof f_B / sizeof f_B[0],
    sizeof f_D / sizeof f_D[0], sizeof f_C / sizeof f_C[0],
    sizeof f_F / sizeof f_F[0], sizeof f_E / sizeof f_E[0],
    sizeof f_I / sizeof f_I[0] };

/* ------------------------------------------------------------------ */
/* ------------------------------------------------------------------ */
/* Memoria de calculo y resumen: interprete del AppVar PERDTXT          */
/* ------------------------------------------------------------------ */
#include "memo_run.h"

#define SETF MSETF

/* Llena V[] y FL con el resultado del ultimo calculo */
static void fill_values(void)
{
    const hydro_state *s = 0;
    real D = P.D;
    memo_reset();
    switch (tipo) {
    case PT_A: case PT_F: s = &R.st; break;      /* v.st y st coinciden */
    case PT_C: s = &R.m.st; break;
    case PT_B: s = &R.q.st; break;
    case PT_D: s = &R.d.qmax.st; D = R.d.D_com; break;
    case PT_I: s = pin.modeI ? &R.q.st : &R.st; break;
    default: break;
    }
    memo_V[V_D] = D; memo_V[V_L] = P.L; memo_V[V_KS] = P.ks; memo_V[V_K] = P.sumK;
    memo_V[V_NU] = C.nu; memo_V[V_G] = C.g; memo_V[V_GAM] = C.gamma; memo_V[V_TOL] = C.tol;
    memo_V[V_H] = pin.H; memo_V[V_QD] = pin.Q / 1000; memo_V[V_KSMM] = P.ks * 1000;
    if (s) {
        memo_V[V_Q] = s->Q; memo_V[V_QLS] = s->Q * 1000; memo_V[V_A] = s->A; memo_V[V_V] = s->v;
        memo_V[V_RE] = s->Re; memo_V[V_KSD] = s->ksD; memo_V[V_F] = s->f;
        memo_V[V_INVSF] = 1 / R_SQRT(s->f); memo_V[V_HV2G] = s->hv2g;
        memo_V[V_HF] = s->hf; memo_V[V_HM] = s->hm; memo_V[V_HT] = s->hT; memo_V[V_LD] = s->LD;
        memo_V[V_HMHF] = s->hf > 0 ? 100 * s->hm / s->hf : 0;
        memo_V[V_FIT] = s->f_iters;
        memo_V[V_A37] = D > 0 ? P.ks / (3.7 * D) : 0;
        memo_W = s->warn;
        SETF(G_LAM, s->regime == REG_LAMINAR);
        SETF(G_TRANS, s->regime == REG_TRANSITION);
    }
    SETF(G_FIX, P.f_fixed > 0);
    SETF(G_CW, C.method == FM_CW);
    SETF(G_SJ, C.method == FM_SJ);
    SETF(G_HA, C.method == FM_HAALAND);
    SETF(G_GO, C.method == FM_GOUDAR);
    SETF(G_KPOS, P.sumK > 0);
    SETF(G_WITHQ, tipo == PT_A || tipo == PT_C || tipo == PT_F ||
                  (tipo == PT_I && !pin.modeI));
    SETF(G_HASD, tipo != PT_D);
    switch (tipo) {
    case PT_A:
        memo_V[V_HP] = pin.Hp; memo_V[V_PH] = X.ph; memo_V[V_PKPA] = X.ph * C.gamma / 1000;
        SETF(G_HP, pin.sHp);
        break;
    case PT_B: case PT_I:
        memo_V[V_ITER] = R.q.iters;
        SETF(G_COURSE, R.q.solver == SOLV_COURSE);
        SETF(G_BIS, R.q.solver == SOLV_BISECTION);
        SETF(G_DIRECT, R.q.solver == SOLV_DIRECT);
        SETF(G_FB, R.q.st.warn & W_FALLBACK);
        if (tipo == PT_I) {
            memo_V[V_CH] = pin.CH; memo_V[V_HW] = X.hw; memo_V[V_ERR] = X.err;
            memo_V[V_QHW] = X.Qhw; memo_V[V_QHWLS] = X.Qhw * 1000;
            SETF(G_MODEQ, pin.modeI);
            if (!pin.modeI)
                memo_FL &= ~(((uint32_t)1 << G_COURSE) | ((uint32_t)1 << G_BIS));
        }
        break;
    case PT_C:
        memo_V[V_HS] = pin.Hs; memo_V[V_ETA] = pin.eta; memo_V[V_HMACH] = R.m.Hm;
        memo_V[V_PN] = R.m.Pn; memo_V[V_PB] = R.m.Pb; memo_V[V_PNKW] = R.m.Pn / 1000;
        memo_V[V_PBKW] = R.m.Pb / 1000; memo_V[V_PBHP] = R.m.Pb / 745.7;
        memo_V[V_ZB] = pin.zb;
        memo_V[V_COTA] = pin.zb + (pin.mach == 0 ? R.m.Hm : -R.m.Hm);
        SETF(G_PUMP, pin.mach == 0);
        SETF(G_ZB, pin.szb);
        break;
    case PT_F:
        memo_V[V_HV] = R.v.hv; memo_V[V_KV] = R.v.Kv;
        break;
    case PT_D:
        memo_V[V_ITER] = R.d.iters; memo_V[V_DEX] = R.d.D_exact * 1000;
        memo_V[V_DCOM] = R.d.D_com * 1000; memo_V[V_VP] = R.d.vp;
        memo_V[V_HFCQ] = R.d.st_com_qd.hf; memo_V[V_VCQ] = R.d.st_com_qd.v;
        memo_V[V_EXV] = R.d.st_exact.v; memo_V[V_EXRE] = R.d.st_exact.Re;
        memo_V[V_EXF] = R.d.st_exact.f; memo_V[V_EXHF] = R.d.st_exact.hf;
        memo_V[V_EXHM] = R.d.st_exact.hm; memo_V[V_EXHT] = R.d.st_exact.hT;
        memo_V[V_VALHT] = X.val.st.hT; memo_V[V_VALHV] = X.val.hv;
        memo_V[V_VALKV] = X.val.Kv; memo_V[V_VALV] = X.val.st.v;
        memo_W |= R.d.warn;
        SETF(G_COURSE, R.d.qmax.solver == SOLV_COURSE);
        SETF(G_VP, R.d.vp > 0);
        SETF(G_VAL, X.has_val);
        break;
    case PT_E:
        memo_V[V_D] = pin.D / 1000; memo_V[V_Q] = pin.Q / 1000;
        memo_V[V_Z1] = pin.z1; memo_V[V_Z2] = pin.z2; memo_V[V_P1] = pin.p1; memo_V[V_P2] = pin.p2;
        memo_V[V_A] = R.k.A; memo_V[V_V] = R.k.v; memo_V[V_HTOT] = R.k.htot;
        memo_V[V_HM] = R.k.hm; memo_V[V_HF] = R.k.hf; memo_V[V_F] = R.k.f; memo_V[V_RE] = R.k.Re;
        memo_V[V_SF] = R_SQRT(R.k.f); memo_V[V_KS] = R.k.ks; memo_V[V_KSMM] = R.k.ks * 1000;
        memo_V[V_KSD] = R.k.ksD;
        memo_W = R.k.warn;
        break;
    default:
        break;
    }
}

/* Carga un caso del curso en el formulario del tipo dado */
void pipe_load_example(uint8_t t, const real *v, uint8_t n)
{
    uint8_t i;
    form_field *f;
    if (t >= PT_COUNT)
        return;
    for (i = 0; i < n && i < nforms[t]; i++) {
        f = &forms[t][i];
        if (f->flags & FF_CHOICE) {
            uint8_t c = (uint8_t)v[i];
            if (c < f->nchoices) {
                if (f->ch == &g_set.h.method && *f->ch != c)
                    g_set_dirty = true;
                *f->ch = c;
            }
        } else if (v[i] <= EX_NONE) {
            if (f->set)
                *f->set = 0;
        } else {
            *f->val = v[i];
            if (f->set)
                *f->set = 1;
        }
    }
}

/* Ayuda: dibuja el tema i (programa de PERDTXT) en el visor */
bool help_topic(uint8_t i)
{
    view_clear();
    if (!memo_tx_open())
        return false;
    memo_run_prog(PROG_HELP(i));
    return true;
}

static void show(bool memo)
{
    fill_values();
    memo_cfg = &C;
    memo_log = &LG;
    memo_dlist = dlist;
    memo_dlist_n = dlist_n;
    memo_show(memo ? PROG_MEMO(tipo) : PROG_SUM(tipo));
}

/* ------------------------------------------------------------------ */
/* Calculo                                                             */
/* ------------------------------------------------------------------ */
static void make_pipe(void)
{
    C = g_set.h;
    C.nu = pin.nu;
    P.D = pin.D / 1000;
    P.L = pin.L;
    P.ks = pin.ks / 1000;
    P.sumK = pin.sK ? pin.K : 0;
    P.f_fixed = pin.sf ? pin.f : 0;
}

/* Devuelve 0 si todo bien, o un texto de error */
static const char *compute(void)
{
    int e = H_OK;
    uint8_t i;
    make_pipe();
    hydro_log_clear(&LG);
    memset(&X, 0, sizeof X);
    switch (tipo) {
    case PT_A:
        e = hydro_pipe_state(&P, pin.Q / 1000, &C, &R.st);
        if (!e && pin.sHp)
            X.ph = hydro_pressure_head(pin.Hp, 0, R.st.v, R.st.hT, &C, &R.st.warn);
        break;
    case PT_B:
        e = hydro_qmax(&P, pin.H, &C, &R.q, &LG);
        break;
    case PT_C:
        e = (pin.mach == 0) ? hydro_pump(&P, pin.Q / 1000, pin.Hs, pin.eta, &C, &R.m)
                           : hydro_turbine(&P, pin.Q / 1000, pin.Hs, pin.eta, &C, &R.m);
        break;
    case PT_D:
        P.f_fixed = 0;
        dlist_n = 0;
        if (pin.dset == DIAM_CUSTOM) {
            for (i = 0; i < DIAM_CUSTOM_MAX; i++)
                if (diam_custom[i] > 0)
                    dlist[dlist_n++] = diam_custom[i] / 1000;
            if (!dlist_n)
                return "Lista propia vacia (Biblioteca)";
        } else {
            dlist_n = diam_sets[pin.dset].n;
            for (i = 0; i < dlist_n; i++)
                dlist[i] = diam_sets[pin.dset].mm[i] / 1000;
        }
        e = hydro_design(&P, pin.Q / 1000, pin.H, dlist, dlist_n, &C, &R.d, &LG);
        if (!e && pin.valve) {
            P.D = R.d.D_com;
            X.has_val = 1;   /* si hv < 0 se muestra igual, con su aviso */
            hydro_valve(&P, pin.Q / 1000, pin.H, &C, &X.val);
        }
        break;
    case PT_F:
        e = hydro_valve(&P, pin.Q / 1000, pin.H, &C, &R.v);
        break;
    case PT_E:
        P.f_fixed = 0;
        e = hydro_calibrate(pin.D / 1000, pin.L, pin.Q / 1000, P.sumK,
                            pin.z1 - pin.z2, pin.p1 - pin.p2, &C, &R.k);
        if (e == H_ERR_KS_NEG)
            e = H_OK;    /* se muestra con su advertencia */
        break;
    case PT_I:
        P.f_fixed = 0;
        if (pin.modeI == 0) {
            if (!pin.sQ)
                return "Falta Q (modo hf)";
            e = hydro_pipe_state(&P, pin.Q / 1000, &C, &R.st);
            X.hw = hydro_hw_hf(pin.Q / 1000, P.D, P.L, pin.CH);
            X.err = 100 * (X.hw - R.st.hf) / R.st.hf;
        } else {
            if (!pin.sH)
                return "Falta H (modo Q)";
            e = hydro_qmax(&P, pin.H, &C, &R.q, &LG);
            X.Qhw = hydro_hw_q(pin.H, P.D, P.L, pin.CH);
            X.err = 100 * (X.Qhw - R.q.st.Q) / R.q.st.Q;
        }
        break;
    default:
        break;
    }
    if (e == H_ERR_HV_NEG || e == H_ERR_HT_NEG)
        return hydro_err_text(e);
    return e ? hydro_err_text(e) : 0;
}

/* ------------------------------------------------------------------ */
/* Bucle de resultado: resumen <-> memoria                             */
/* ------------------------------------------------------------------ */
/* LE y LP del tubo simple (tipos A, B, C, D y F; en E e I no aplica) */
static void pipe_graph(void)
{
    gseg s[2];
    const hydro_state *st;
    real E0 = 0, Eend = 0;
    uint8_t n = 1, tank2 = 1;
    memset(s, 0, sizeof s);
    switch (tipo) {
    case PT_A: st = &R.st; break;
    case PT_B: st = &R.q.st; break;
    case PT_C: st = &R.m.st; break;
    case PT_D: st = &R.d.qmax.st; break;
    case PT_F: st = &R.v.st; break;
    default:
        ui_alert("Grafico", "No aplica a este tipo", "de problema", C_GRAY);
        return;
    }
    s[0].L = P.L;
    s[0].hloc = st->hm;
    s[0].hfr = st->hf;
    s[0].vh = st->hv2g;
    s[0].name[0] = 'L';
    switch (tipo) {
    case PT_A:
        E0 = pin.sHp ? pin.Hp : st->hT;
        tank2 = 0;
        break;
    case PT_B:
        E0 = pin.H;
        break;
    case PT_D:
        E0 = pin.H;
        break;
    case PT_C:
        if (pin.mach == 0) {          /* bomba al inicio */
            E0 = 0;
            s[0].jump = R.m.Hm;
            Eend = pin.Hs;
        } else {                      /* turbina al final */
            E0 = pin.Hs;
            s[1].L = 0;
            s[1].jump = -R.m.Hm;
            s[1].vh = st->hv2g;
            s[1].name[0] = 'T';
            n = 2;
        }
        break;
    case PT_F:                        /* valvula al final */
        E0 = pin.H;
        s[1].jump = -R.v.hv;
        s[1].vh = st->hv2g;
        s[1].name[0] = 'V';
        n = 2;
        break;
    default:
        break;
    }
    if (tank2 && tipo != PT_C)
        Eend = 0;
    graph_run(titles[tipo], E0, s, n, Eend, tank2);
}

static void result_loop(void)
{
    static const char *const fk_sum[5] = { "MEMORIA", "GRAFICO", "GUARDAR", "", "VOLVER" };
    static const char *const fk_memo[5] = { "RESUMEN", "", "", "", "VOLVER" };
    bool memo = false;
    uint8_t k;
    for (;;) {
        show(memo);
        k = view_run(titles[tipo], memo ? fk_memo : fk_sum);
        if (k == K_F1) {
            memo = !memo;
        } else if (k == K_F2) {
            pipe_graph();
        } else if (k == K_F3 && !memo) {
            case_save_ui(tipo);
        } else if (k == K_MODE) {
            scr_settings();
        } else {
            return;
        }
    }
}

static bool has_f(uint8_t t)
{
    return t == PT_A || t == PT_B || t == PT_C || t == PT_F;
}

void scr_pipe(uint8_t t)
{
    scr_pipe_run(t, 0);
}

void scr_pipe_run(uint8_t t, uint8_t autocalc)
{
    static uint8_t cur[PT_COUNT];
    form_t fm;
    uint8_t k, m0;
    const char *err;

    if (t >= PT_COUNT)
        return;
    tipo = t;
    if (!pin.snu) {
        pin.nu = g_set.h.nu;
        pin.snu = 1;
    }
    if (!pin.sK) {
        pin.K = 0;
        pin.sK = 1;
    }
    memset(&fm, 0, sizeof fm);
    fm.title = titles[t];
    fm.f = forms[t];
    fm.n = nforms[t];
    fm.cur = cur[t];
    fm.fk[0] = "MAT";
    fm.fk[1] = "SUMA K";
    fm.fk[2] = "FLUIDO";
    /* v2.0: los formularios con "f dado" abren Calcular f con F4 (MODE
     * sigue abriendo los Ajustes) */
    fm.fk[3] = has_f(t) ? "CALC f" : "AJUSTES";
    fm.fk[4] = "CALC";
    if (t == PT_C)
        fm.hint = "Hs = z2-z1 (bomba); Ha = z1-z2 (turb.)";
    m0 = g_set.h.method;
    for (;;) {
        if (autocalc) {
            autocalc = 0;
            k = K_F5;
        } else {
            k = form_run(&fm);
        }
        if (k == K_QUIT || k == K_CLEAR)
            break;
        if (k == K_F1) { lib_pick_material(); continue; }
        if (k == K_F2) { lib_sumador(); continue; }
        if (k == K_F3) { lib_pick_fluid(0); continue; }
        if (k == K_F4 && has_f(t)) { scr_fric(&pin.f, &pin.sf); continue; }
        if (k == K_F4 || k == K_MODE) { scr_settings(); continue; }
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
    if (g_set.h.method != m0)
        g_set_dirty = true;
}
