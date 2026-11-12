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
static hydro_log LG;
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
#include "memo_defs.h"

static real V[V_COUNT];
static uint32_t FL;           /* banderas para las condiciones */
static unsigned int W;        /* advertencias a mostrar        */

/* PERDTXT: programas de la memoria de calculo en un AppVar (normalmente
 * archivado; se lee en su lugar, sin copiarlo a la RAM). El puntero se
 * vuelve a pedir en cada uso, porque archivar otra variable puede mover
 * los datos de la memoria flash. */
static const uint8_t *TX;
static uint16_t TXN;

static bool tx_open(void)
{
    uint8_t h = ti_Open(TX_APPVAR, "r");
    TX = 0;
    if (!h)
        return false;
    TX = (const uint8_t *)ti_GetDataPtr(h);
    TXN = (uint16_t)ti_GetSize(h);
    ti_Close(h);
    if (TXN < 5 + 2 * PROG_COUNT || TX[0] != 'P' || TX[1] != 'T' ||
        TX[2] != 'X' || TX[3] != TX_VERSION || TX[4] != PROG_COUNT) {
        TX = 0;
        return false;
    }
    return true;
}

static uint16_t rd16(const uint8_t *p)
{
    return (uint16_t)(p[0] | p[1] << 8);
}

/* texto en el desplazamiento o, o NULL */
static const char *txs(uint16_t o)
{
    return (o == TX_NONE || o >= TXN) ? 0 : (const char *)(TX + o);
}

static char tb[200], tb2[200];

/* Expande los codigos de valor de una plantilla */
static const char *tpl(const char *t, char *out, size_t n)
{
    size_t k = 0;
    char num[NUMFMT_LEN];
    const char *s;
    uint8_t code, id;
    if (!t)
        return 0;
    while (*t && k + 1 < n) {
        code = (uint8_t)*t;
        if (code != TX_FULL && code != TX_SHORT) {
            out[k++] = *t++;
            continue;
        }
        if (!t[1])
            break;
        id = (uint8_t)(t[1] - 1);       /* el generador guarda id + 1 */
        t += 2;
        if (id == V_METHOD)
            s = method_names[C.method];
        else if (id == V_LISTNAME)
            s = pin.dset < DIAM_CHOICES ? diam_set_names[pin.dset] : "?";
        else if (id < V_COUNT)
            s = code == TX_SHORT ? fmt_w(V[id], 7, num)
                                 : fmt_real(V[id], g_set.dec, num);
        else
            s = "?";
        while (*s && k + 1 < n)
            out[k++] = *s++;
    }
    out[k] = 0;
    return out;
}

static const char *const hB_course[5] = { "i", "hf", "v", "hm", "hf+1" };
static const char *const hB_bis[5] = { "i", "v min", "v max", "v", "hT-H" };
static const char *const hD[5] = { "i", "D min", "D max", "D mm", "hT-H" };
static const real m_one[5] = { 1, 1, 1, 1, 1 };
static const real m_D[5] = { 1, 1000, 1000, 1000, 1 };

static void run_prog(uint8_t prog, uint8_t depth)
{
    const uint8_t *p;
    uint16_t o;
    uint8_t skip = 0, i, op, id;
    char num[NUMFMT_LEN];
    if (!TX || prog >= PROG_COUNT)
        return;
    o = rd16(TX + 5 + 2 * prog);
    for (; o + TX_STEP <= TXN; o += TX_STEP) {
        p = TX + o;
        op = p[0];
        id = p[1];
        if (op == M_END)
            break;
        if (skip) {                       /* dentro de un IF falso */
            if (op == M_IF || op == M_IFN)
                skip++;
            else if (op == M_ENDIF)
                skip--;
            continue;
        }
        switch (op) {
        case M_SEC: memo_sec(txs(rd16(p + 2))); break;
        case M_SEP: view_add_sep(); break;
        case M_DATA: view_add_val(txs(rd16(p + 2)), V[id], txs(rd16(p + 8))); break;
        case M_RES: memo_res(txs(rd16(p + 2)), V[id], txs(rd16(p + 8))); break;
        case M_EQ:
            memo_eq(txs(rd16(p + 2)), txs(rd16(p + 4)),
                    tpl(txs(rd16(p + 6)), tb, sizeof tb), V[id], txs(rd16(p + 8)));
            break;
        case M_LINE: memo_line(tpl(txs(rd16(p + 2)), tb2, sizeof tb2), id); break;
        case M_IF:
            if (!(FL & ((uint32_t)1 << id)))
                skip = 1;
            break;
        case M_IFN:
            if (FL & ((uint32_t)1 << id))
                skip = 1;
            break;
        case M_CALL:
            if (depth < 3)
                run_prog(id, depth + 1);
            break;
        case M_TABLE:
            if (id == 0)
                memo_table(hB_course, 5, &LG, m_one);
            else if (id == 1)
                memo_table(hB_bis, 5, &LG, m_one);
            else
                memo_table(hD, 5, &LG, m_D);
            break;
        case M_WARN: memo_warn(W, &C); break;
        case M_DLIST:
            tb2[0] = ' ';
            tb2[1] = 0;
            for (i = 0; i < dlist_n; i++) {
                if (strlen(tb2) > 30) {
                    memo_line(tb2, C_GRAY);
                    tb2[0] = ' ';
                    tb2[1] = 0;
                }
                strcat(tb2, fmt_w(dlist[i] * 1000, 7, num));
                strcat(tb2, " ");
            }
            memo_line(tb2, C_GRAY);
            break;
        default: break;
        }
    }
}

#define SETF(g, cond) do { if (cond) FL |= (uint32_t)1 << (g); } while (0)

/* Llena V[] y FL con el resultado del ultimo calculo */
static void fill_values(void)
{
    const hydro_state *s = 0;
    real D = P.D;
    memset(V, 0, sizeof V);
    FL = 0;
    switch (tipo) {
    case PT_A: case PT_F: s = &R.st; break;      /* v.st y st coinciden */
    case PT_C: s = &R.m.st; break;
    case PT_B: s = &R.q.st; break;
    case PT_D: s = &R.d.qmax.st; D = R.d.D_com; break;
    case PT_I: s = pin.modeI ? &R.q.st : &R.st; break;
    default: break;
    }
    V[V_D] = D; V[V_L] = P.L; V[V_KS] = P.ks; V[V_K] = P.sumK;
    V[V_NU] = C.nu; V[V_G] = C.g; V[V_GAM] = C.gamma; V[V_TOL] = C.tol;
    V[V_H] = pin.H; V[V_QD] = pin.Q / 1000; V[V_KSMM] = P.ks * 1000;
    if (s) {
        V[V_Q] = s->Q; V[V_QLS] = s->Q * 1000; V[V_A] = s->A; V[V_V] = s->v;
        V[V_RE] = s->Re; V[V_KSD] = s->ksD; V[V_F] = s->f;
        V[V_INVSF] = 1 / R_SQRT(s->f); V[V_HV2G] = s->hv2g;
        V[V_HF] = s->hf; V[V_HM] = s->hm; V[V_HT] = s->hT; V[V_LD] = s->LD;
        V[V_HMHF] = s->hf > 0 ? 100 * s->hm / s->hf : 0;
        V[V_FIT] = s->f_iters;
        V[V_A37] = D > 0 ? P.ks / (3.7 * D) : 0;
        W = s->warn;
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
        V[V_HP] = pin.Hp; V[V_PH] = X.ph; V[V_PKPA] = X.ph * C.gamma / 1000;
        SETF(G_HP, pin.sHp);
        break;
    case PT_B: case PT_I:
        V[V_ITER] = R.q.iters;
        SETF(G_COURSE, R.q.solver == SOLV_COURSE);
        SETF(G_BIS, R.q.solver == SOLV_BISECTION);
        SETF(G_DIRECT, R.q.solver == SOLV_DIRECT);
        SETF(G_FB, R.q.st.warn & W_FALLBACK);
        if (tipo == PT_I) {
            V[V_CH] = pin.CH; V[V_HW] = X.hw; V[V_ERR] = X.err;
            V[V_QHW] = X.Qhw; V[V_QHWLS] = X.Qhw * 1000;
            SETF(G_MODEQ, pin.modeI);
            if (!pin.modeI)
                FL &= ~(((uint32_t)1 << G_COURSE) | ((uint32_t)1 << G_BIS));
        }
        break;
    case PT_C:
        V[V_HS] = pin.Hs; V[V_ETA] = pin.eta; V[V_HMACH] = R.m.Hm;
        V[V_PN] = R.m.Pn; V[V_PB] = R.m.Pb; V[V_PNKW] = R.m.Pn / 1000;
        V[V_PBKW] = R.m.Pb / 1000; V[V_PBHP] = R.m.Pb / 745.7;
        V[V_ZB] = pin.zb;
        V[V_COTA] = pin.zb + (pin.mach == 0 ? R.m.Hm : -R.m.Hm);
        SETF(G_PUMP, pin.mach == 0);
        SETF(G_ZB, pin.szb);
        break;
    case PT_F:
        V[V_HV] = R.v.hv; V[V_KV] = R.v.Kv;
        break;
    case PT_D:
        V[V_ITER] = R.d.iters; V[V_DEX] = R.d.D_exact * 1000;
        V[V_DCOM] = R.d.D_com * 1000; V[V_VP] = R.d.vp;
        V[V_HFCQ] = R.d.st_com_qd.hf; V[V_VCQ] = R.d.st_com_qd.v;
        V[V_EXV] = R.d.st_exact.v; V[V_EXRE] = R.d.st_exact.Re;
        V[V_EXF] = R.d.st_exact.f; V[V_EXHF] = R.d.st_exact.hf;
        V[V_EXHM] = R.d.st_exact.hm; V[V_EXHT] = R.d.st_exact.hT;
        V[V_VALHT] = X.val.st.hT; V[V_VALHV] = X.val.hv;
        V[V_VALKV] = X.val.Kv; V[V_VALV] = X.val.st.v;
        W |= R.d.warn;
        SETF(G_COURSE, R.d.qmax.solver == SOLV_COURSE);
        SETF(G_VP, R.d.vp > 0);
        SETF(G_VAL, X.has_val);
        break;
    case PT_E:
        V[V_D] = pin.D / 1000; V[V_Q] = pin.Q / 1000;
        V[V_Z1] = pin.z1; V[V_Z2] = pin.z2; V[V_P1] = pin.p1; V[V_P2] = pin.p2;
        V[V_A] = R.k.A; V[V_V] = R.k.v; V[V_HTOT] = R.k.htot;
        V[V_HM] = R.k.hm; V[V_HF] = R.k.hf; V[V_F] = R.k.f; V[V_RE] = R.k.Re;
        V[V_SF] = R_SQRT(R.k.f); V[V_KS] = R.k.ks; V[V_KSMM] = R.k.ks * 1000;
        V[V_KSD] = R.k.ksD;
        W = R.k.warn;
        break;
    default:
        break;
    }
}

static void show(bool memo)
{
    fill_values();
    view_clear();
    if (!tx_open()) {
        view_add("Falta el archivo " TX_APPVAR " (textos", C_ERR);
        view_add("de la memoria de calculo). Envielo", C_ERR);
        view_add("con TI Connect CE y vuelva a entrar.", C_ERR);
        return;
    }
    run_prog(memo ? PROG_MEMO(tipo) : PROG_SUM(tipo), 0);
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
static void result_loop(void)
{
    static const char *const fk_sum[5] = { "MEMORIA", "", "GUARDAR", "", "VOLVER" };
    static const char *const fk_memo[5] = { "RESUMEN", "", "", "", "VOLVER" };
    bool memo = false;
    uint8_t k;
    for (;;) {
        show(memo);
        k = view_run(titles[tipo], memo ? fk_memo : fk_sum);
        if (k == K_F1) {
            memo = !memo;
        } else if (k == K_F3 && !memo) {
            case_save_ui(tipo);
        } else if (k == K_MODE) {
            scr_settings();
        } else {
            return;
        }
    }
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
    fm.fk[3] = "AJUSTES";
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
