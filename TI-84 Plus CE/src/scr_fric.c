/*
 * scr_fric.c - v2.0 "Calcular f": factor de friccion solo, sin datos de
 * tuberia que no hacen falta. Dos modos (F2 MODO):
 *   1 Re y ks/D (o ks y D en mm)
 *   2 datos de la tuberia: Q o v, D, ks, nu (comparte pin con la
 *     tuberia simple, asi los selectores de material y fluido sirven)
 * Resultado: regimen, zona, f con el metodo de Ajustes y la tabla de los
 * 4 metodos con su diferencia respecto a Colebrook-White. [USAR f]
 * devuelve el valor al formulario que abrio esta pantalla.
 */
#include <string.h>
#include "app.h"
#include "pipe.h"
#include "memo_run.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "ui/numfmt.h"

static struct {
    real Re, ksd, ks1, D1, v;
    uint8_t sRe, sksd, sks1, sD1, sv;
    uint8_t mode;               /* 0 Re y ks/D, 1 datos de tuberia */
} fi;

static const char *const mode_names[2] = { "Re y ks/D", "Datos tuberia" };

#define F_MODE { "Modo", 0, 0, &fi.mode, 0, FF_CHOICE, mode_names, 2, 0, 0 }
#define F_MET  { "Metodo de f", 0, 0, &g_set.h.method, 0, FF_CHOICE, method_names, FM_COUNT, 0, 0 }

static form_field f_m1[] = {
    F_MODE,
    { "Reynolds Re", 0, &fi.Re, 0, &fi.sRe, FF_POS, 0, 0, 0, 0 },
    { "ks/D (o ks y D)", 0, &fi.ksd, 0, &fi.sksd, FF_NONNEG | FF_OPT, 0, 0, 0, 0 },
    { "ks (opc.)", "mm", &fi.ks1, 0, &fi.sks1, FF_NONNEG | FF_OPT, 0, 0, 0, 0 },
    { "D (opc.)", "mm", &fi.D1, 0, &fi.sD1, FF_POS | FF_OPT, 0, 0, 0, 0 },
    F_MET
};
static form_field f_m2[] = {
    F_MODE,
    { "Caudal Q (o v)", "l/s", &pin.Q, 0, &pin.sQ, FF_POS | FF_OPT, 0, 0, 0, 0 },
    { "Velocidad (opc.)", "m/s", &fi.v, 0, &fi.sv, FF_POS | FF_OPT, 0, 0, 0, 0 },
    { "Diametro D", "mm", &pin.D, 0, &pin.sD, FF_POS, 0, 0, 0, 0 },
    { "Rugosidad ks", "mm", &pin.ks, 0, &pin.sks, FF_NONNEG, 0, 0, 0, 0 },
    { "Viscosidad nu", "m2/s", &pin.nu, 0, &pin.snu, FF_POS, 0, 0, 0, 0 },
    F_MET
};

static form_t *fm_now;

static void set_mode_form(form_t *fm)
{
    fm->f = fi.mode ? f_m2 : f_m1;
    fm->n = fi.mode ? sizeof f_m2 / sizeof f_m2[0]
                    : sizeof f_m1 / sizeof f_m1[0];
    if (fm->cur >= fm->n)
        fm->cur = 0;
}

static void mode_changed(void)
{
    if (fm_now && fm_now->f != (fi.mode ? f_m2 : f_m1))
        set_mode_form(fm_now);
}

static hydro_cfg C;
#define LG memo_lg      /* registro compartido (memo_run.c) */
static hydro_fric_tab T;

/* 0 si todo bien, o un texto de error */
static const char *compute(void)
{
    real Re, ksd, D = 0, ks = 0, A = 0, v = 0, Q = 0, fs, kp;
    uint8_t ksdin = 0, hasv = 0;
    int e;

    C = g_set.h;
    if (!fi.mode) {
        Re = fi.Re;
        if (fi.sksd) {
            ksd = fi.ksd;
        } else if (fi.sks1 && fi.sD1) {
            ksd = fi.ks1 / fi.D1;
            ksdin = 1;
        } else {
            return "Falta ks/D (o ks y D)";
        }
    } else {
        D = pin.D / 1000;
        ks = pin.ks / 1000;
        C.nu = pin.nu;
        A = hydro_area(D);
        if (fi.sv) {
            v = fi.v;
            Q = v * A;
            hasv = 1;
        } else if (pin.sQ) {
            Q = pin.Q / 1000;
            v = Q / A;
        } else {
            return "Falta Q o v";
        }
        Re = v * D / C.nu;
        ksd = ks / D;
    }
    hydro_log_clear(&LG);
    e = hydro_fric_all(Re, ksd, &C, &T, &LG);
    if (e)
        return hydro_err_text(e);

    memo_reset();
    fs = T.f[C.method];
    memo_V[V_RE] = Re;
    memo_V[V_KSD] = ksd;
    memo_V[V_A37] = ksd / 3.7;
    memo_V[V_FCW] = T.f[FM_CW];
    memo_V[V_FSJ] = T.f[FM_SJ];
    memo_V[V_FHA] = T.f[FM_HAALAND];
    memo_V[V_FGO] = T.f[FM_GOUDAR];
    memo_V[V_DSJ] = T.dpct[FM_SJ];
    memo_V[V_DHA] = T.dpct[FM_HAALAND];
    memo_V[V_DGO] = T.dpct[FM_GOUDAR];
    memo_V[V_FSEL] = fs;
    memo_V[V_INVSF] = 1 / R_SQRT(fs);
    memo_V[V_FIT] = T.iters;
    kp = ksd * Re * R_SQRT(T.f[FM_CW] / 8);
    memo_V[V_KPLUS] = kp;
    memo_V[V_D] = D;
    memo_V[V_KS] = ks;
    memo_V[V_NU] = C.nu;
    memo_V[V_Q] = Q;
    memo_V[V_QLS] = Q * 1000;
    memo_V[V_A] = A;
    memo_V[V_V] = v;
    memo_V[V_KSMM] = fi.ks1;
    memo_V[V_DMM] = fi.D1;
    MSETF(G_FMODE2, fi.mode);
    MSETF(G_FHASV, hasv);
    MSETF(G_FKSDIN, ksdin);
    MSETF(G_LAM, T.regime == REG_LAMINAR);
    MSETF(G_TRANS, T.regime == REG_TRANSITION);
    MSETF(G_CW, C.method == FM_CW);
    MSETF(G_SJ, C.method == FM_SJ);
    MSETF(G_HA, C.method == FM_HAALAND);
    MSETF(G_GO, C.method == FM_GOUDAR);
    MSETF(G_ZSMOOTH, kp < 5);
    MSETF(G_ZTRANS, kp >= 5 && kp <= 70);
    MSETF(G_ZROUGH, kp > 70);
    MSETF(G_OCW, T.out[FM_CW]);
    MSETF(G_OSJ, T.out[FM_SJ]);
    MSETF(G_OHA, T.out[FM_HAALAND]);
    MSETF(G_OGO, T.out[FM_GOUDAR]);
    memo_cfg = &C;
    memo_log = &LG;
    return 0;
}

/* Devuelve true si se uso [USAR f] */
static bool result_loop(real *dest, uint8_t *dset)
{
    static const char *fk_sum[5] = { "MEMORIA", "", "GUARDAR", "", "VOLVER" };
    static const char *const fk_memo[5] = { "RESUMEN", "", "", "", "VOLVER" };
    bool memo = false;
    uint8_t k;
    char l2[UI_COLS + 1], num[NUMFMT_LEN];
    fk_sum[1] = dest ? "USAR f" : "";
    for (;;) {
        memo_show(memo ? PROG_X(XP_FRIC_MEMO) : PROG_X(XP_FRIC_SUM));
        k = view_run("FACTOR DE FRICCION f", memo ? fk_memo : fk_sum);
        if (k == K_F1) {
            memo = !memo;
        } else if (k == K_F2 && !memo && dest) {
            *dest = memo_V[V_FSEL];
            if (dset)
                *dset = 1;
            strcpy(l2, "f = ");
            strcat(l2, fmt_real(*dest, g_set.dec, num));
            ui_alert("USAR f", "Se copio al formulario:", l2, C_OK);
            return true;
        } else if (k == K_F3 && !memo) {
            case_save_ui(KT_FRIC);
        } else if (k == K_MODE) {
            scr_settings();
            compute();          /* el metodo pudo cambiar */
        } else if (k == K_F5 || k == K_CLEAR || k == K_QUIT) {
            return false;
        }
        if (ui_quit)
            return false;
    }
}

void scr_fric(real *dest, uint8_t *dset)
{
    scr_fric_run(dest, dset, 0);
}

void scr_fric_run(real *dest, uint8_t *dset, uint8_t autocalc)
{
    static uint8_t cur;
    form_t fm;
    uint8_t k, m0 = g_set.h.method;
    const char *err;

    if (!pin.snu) {
        pin.nu = g_set.h.nu;
        pin.snu = 1;
    }
    memset(&fm, 0, sizeof fm);
    fm.title = "FACTOR DE FRICCION f";
    fm.cur = cur;
    set_mode_form(&fm);
    fm.fk[0] = "MAT";
    fm.fk[1] = "MODO";
    fm.fk[2] = "FLUIDO";
    fm.fk[3] = "AJUSTES";
    fm.fk[4] = "CALC";
    fm.hint = "F2 cambia el modo de entrada";
    fm.on_commit = mode_changed;
    for (;;) {
        fm_now = &fm;
        if (autocalc) {
            autocalc = 0;
            k = K_F5;
        } else {
            k = form_run(&fm);
        }
        fm_now = 0;
        if (k == K_QUIT || k == K_CLEAR)
            break;
        if (k == K_NONE)
            continue;
        if (k == K_F1) {
            if (fi.mode)
                lib_pick_material();
            else
                fm.msg = "MAT: solo en modo datos de tuberia";
            fm.msg_color = C_WARN;
            continue;
        }
        if (k == K_F2) {
            fi.mode = (uint8_t)!fi.mode;
            fm.cur = 0;
            set_mode_form(&fm);
            continue;
        }
        if (k == K_F3) {
            if (fi.mode)
                lib_pick_fluid(0);
            else
                fm.msg = "FLUIDO: solo en modo datos de tuberia";
            fm.msg_color = C_WARN;
            continue;
        }
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
            if (result_loop(dest, dset) || ui_quit)
                break;
        }
    }
    cur = fm.cur;
    if (g_set.h.method != m0)
        g_set_dirty = true;
}

/* ---- Mis casos: modo, Re, ks/D... y los datos de tuberia (pin) ---- */
uint16_t fric_save(uint8_t *b)
{
    memcpy(b, &fi, sizeof fi);
    memcpy(b + sizeof fi, &pin, sizeof pin);
    return (uint16_t)(sizeof fi + sizeof pin);
}

bool fric_load(const uint8_t *b, uint16_t n)
{
    if (n != sizeof fi + sizeof pin)
        return false;
    memcpy(&fi, b, sizeof fi);
    memcpy(&pin, b + sizeof fi, sizeof pin);
    fi.mode &= 1;
    pin_sanitize(&pin);
    return true;
}

/* ---- Casos del curso F-01 a F-05 (prompt v2, sec. 8.5) ---- */
void fric_preset(uint8_t k)
{
    static const real re[5] = { 20000, 200000, 0, 455180, 0 };
    static const real kd[5] = { 1e-4, 1.5e-4, 0, 7.5e-6, 0 };
    memset(&fi, 0, sizeof fi);
    if (k == 2 || k == 4) {                  /* datos de tuberia */
        fi.mode = 1;
        pin.Q = k == 2 ? 200 : (real)0.02;
        pin.D = k == 2 ? (real)285.75 : 20;
        pin.ks = k == 2 ? (real)0.0015 : 0;
        pin.nu = (real)1e-6;
        pin.sQ = pin.sD = pin.sks = pin.snu = 1;
    } else {
        fi.Re = re[k];
        fi.ksd = kd[k];
        fi.sRe = fi.sksd = 1;
    }
}
