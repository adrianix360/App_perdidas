/*
 * scr_drag.c - v2.0: arrastre y sustentacion (prompt v2, sec. 4.2).
 *   0 AR-1 fuerza de arrastre o sustentacion
 *   1 AR-2 velocidad terminal (con empuje)
 *   2 AR-3 estructura con varios cuerpos (fuerza, momento en la base)
 *   3 AR-4 vuelo nivelado (dos pasos: C_L necesario, luego la lectura)
 *   4 EX-4 placa plana y flujo lento (Stokes)
 * Patron de siempre: formulario -> resultado -> memoria (PERDTXT).
 * F1 CD abre el catalogo y devuelve C_D y la figura.
 * Unidades en pantalla: SI; V en m/s, km/h o nudos.
 */
#include <string.h>
#include "app.h"
#include "memo_run.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "ui/numfmt.h"
#include "ui/memo.h"
#include "ui/gfxcat.h"
#include "data/dragcat.h"
#include "hydro/drag.h"

enum { DT_AR1 = 0, DT_AR2, DT_AR3, DT_AR4, DT_PL, DT_COUNT };

#define NB DRAG_BODIES
typedef struct {
    real cd, fig, D, L, A, y, V;
    uint8_t scd, sfig, sD, sL, sA, sy, sV;
} body_in;

/* datos compartidos entre los tipos (ultimo valor) */
static struct {
    real rho, nu, V, cd, fig, D, L, A, Lr, W, vol, h, rh4, nw, Aw, cdf, Df,
         alpha, cdw, clmax, nb;
    uint8_t srho, snu, sV, scd, sfig, sD, sL, sA, sLr, sW, svol, sh, srh4,
            snw, sAw, scdf, sDf, salpha, scdw, sclmax, snb;
    uint8_t fluid, vunit, lift, kase, faces, regime, init;
    body_in b[NB];
} di;

static const char *const fluid_names[3] = { "Aire (Ajustes)", "Agua", "Manual" };
static const char *const vu_names[3] = { "m/s", "km/h", "nudos" };
static const char *const lift_names[2] = { "Arrastre FD", "Sustentac. FL" };
static const char *const kase_names[2] = { "Placa plana", "Esfera Stokes" };
static const char *const face_names[2] = { "Una", "Dos" };
static const char *const reg_names[4] = { "Auto", "Laminar", "Turbulento", "Mixto" };

#define FN(lab, un, v, fl) { lab, un, &di.v, 0, &di.s##v, fl, 0, 0, 0, 0 }
#define FC(lab, v, names, n) { lab, 0, 0, &di.v, 0, FF_CHOICE, names, n, 0, 0 }
#define F_FLUID FC("Fluido", fluid, fluid_names, 3), \
    FN("rho", "kg/m3", rho, FF_POS), FN("nu", "m2/s", nu, FF_POS)
#define F_V FN("Velocidad V", 0, V, FF_POS), FC("Unidad de V", vunit, vu_names, 3)
#define F_SHAPE FN("CD (F1: catalogo)", 0, cd, FF_POS), \
    { "Figura 1-17 (opc)", 0, &di.fig, 0, &di.sfig, FF_INT | FF_OPT, 0, 0, 1, CAT_N }, \
    FN("Dim. D (o h)", "m", D, FF_POS | FF_OPT), FN("Dim. L o b (opc)", "m", L, FF_POS | FF_OPT), \
    FN("Area A (opc)", "m2", A, FF_POS | FF_OPT), FN("Long. Re (opc)", "m", Lr, FF_POS | FF_OPT)

static form_field f_ar1[] = { FC("Calcular", lift, lift_names, 2), F_FLUID, F_V, F_SHAPE };
static form_field f_ar2[] = { F_FLUID, FN("Peso W", "N", W, FF_POS),
    FN("Volumen (empuje)", "m3", vol, FF_POS | FF_OPT), F_SHAPE };
static form_field f_ar4[] = { FN("Peso W", "N", W, FF_POS), F_V,
    FN("Altitud h", "m", h, FF_NONNEG | FF_OPT), FN("rho (o altitud)", "kg/m3", rh4, FF_POS | FF_OPT),
    { "Numero de alas", 0, &di.nw, 0, &di.snw, FF_INT, 0, 0, 1, 4 },
    FN("Area de un ala", "m2", Aw, FF_POS), FN("CD fuselaje", 0, cdf, FF_NONNEG),
    FN("D fuselaje", "m", Df, FF_NONNEG),
    FN("Lectura: alfa(opc)", "grad", alpha, FF_ANY | FF_OPT),
    FN("Lectura: CD alas", 0, cdw, FF_POS | FF_OPT), FN("CLmax (opc)", 0, clmax, FF_POS | FF_OPT) };
static form_field f_pl[] = { FC("Caso", kase, kase_names, 2), F_FLUID, F_V,
    FN("L placa o D esfera", "m", D, FF_POS), FN("Ancho w (placa)", "m", L, FF_POS | FF_OPT),
    FC("Caras mojadas", faces, face_names, 2), FC("Regimen (placa)", regime, reg_names, 4) };

static const char *const titles[DT_COUNT] = {
    "FUERZA DE ARRASTRE (AR-1)", "VELOCIDAD TERMINAL (AR-2)",
    "ESTRUCTURA: CUERPOS (AR-3)", "VUELO NIVELADO (AR-4)",
    "PLACA PLANA Y STOKES"
};

extern form_field ff_shared[];
extern char flab_shared[][18];
static uint8_t tipo, last_fluid = 0xFF, last_fig;
static form_t *fm_now;
static hydro_cfg C;

/* Arma el formulario de la estructura (como Sistemas): datos comunes y
 * 7 campos por cuerpo */
static uint8_t build_ar3(void)
{
    static const char *const sub[7] = { "CD", "Figura 1-17", "D (o h)", "L o b",
                                        "A (opc)", "y cota", "V (opc)" };
    static const char *const unit[7] = { 0, 0, "m", "m", "m2", "m", 0 };
    static const uint8_t fl[7] = { FF_POS, FF_INT | FF_OPT, FF_POS | FF_OPT,
        FF_POS | FF_OPT, FF_POS | FF_OPT, FF_ANY, FF_POS | FF_OPT };
    static const form_field head[] = {
        { "Numero de cuerpos", 0, &di.nb, 0, &di.snb, FF_INT, 0, 0, 1, NB }, F_FLUID, F_V };
    uint8_t n = sizeof head / sizeof head[0], i, j;
    form_field *f;
    memcpy(ff_shared, head, sizeof head);
    for (i = 0; i < (uint8_t)di.nb; i++) {
        body_in *b = &di.b[i];
        real *v[7] = { &b->cd, &b->fig, &b->D, &b->L, &b->A, &b->y, &b->V };
        uint8_t *s[7] = { &b->scd, &b->sfig, &b->sD, &b->sL, &b->sA, &b->sy, &b->sV };
        for (j = 0; j < 7; j++) {
            char *l = flab_shared[i * 7 + j];
            f = &ff_shared[n++];
            memset(f, 0, sizeof *f);
            l[0] = (char)('1' + i);
            l[1] = ' ';
            strcpy(l + 2, sub[j]);
            f->label = l;
            f->unit = unit[j];
            f->val = v[j];
            f->set = s[j];
            f->flags = fl[j];
            f->lo = 1;
            f->hi = CAT_N;
        }
    }
    return n;
}

static void set_form(form_t *fm)
{
    static form_field *const fs[DT_COUNT] = { f_ar1, f_ar2, 0, f_ar4, f_pl };
    static const uint8_t ns[DT_COUNT] = { sizeof f_ar1 / sizeof f_ar1[0],
        sizeof f_ar2 / sizeof f_ar2[0], 0, sizeof f_ar4 / sizeof f_ar4[0],
        sizeof f_pl / sizeof f_pl[0] };
    if (tipo == DT_AR3) {
        fm->f = ff_shared;
        fm->n = build_ar3();
    } else {
        fm->f = fs[tipo];
        fm->n = ns[tipo];
    }
    if (fm->cur >= fm->n)
        fm->cur = 0;
}

/* Fluido elegido -> rho y nu; figura escrita -> su C_D; numero de
 * cuerpos -> rehacer el formulario */
static void on_commit(void)
{
    static real nb0;
    uint8_t i;
    if (di.fluid != last_fluid && di.fluid < 2) {
        di.rho = di.fluid ? g_set.h.gamma / g_set.h.g : g_set.rho_air;
        di.nu = di.fluid ? g_set.h.nu : g_set.nu_air;
        di.srho = di.snu = 1;
    }
    last_fluid = di.fluid;
    if (di.sfig && (uint8_t)di.fig != last_fig) {
        last_fig = (uint8_t)di.fig;
        di.cd = dragcat_cd((uint8_t)(di.fig - 1));
        di.scd = 1;
    }
    for (i = 0; i < NB; i++)
        if (di.b[i].sfig && !di.b[i].scd) {
            di.b[i].cd = dragcat_cd((uint8_t)(di.b[i].fig - 1));
            di.b[i].scd = 1;
        }
    if (tipo == DT_AR3 && fm_now && di.nb != nb0) {
        nb0 = di.nb;
        set_form(fm_now);
    }
}

/* ------------------------------------------------------------------ */
/* Calculo                                                             */
/* ------------------------------------------------------------------ */
static real vms(real v)
{
    return di.vunit == 0 ? v : di.vunit == 1 ? v / 3.6 : v * g_set.knot / 3.6;
}

/* area de referencia de una figura: A tecleada o formula con D y L */
static const char *area_of(uint8_t sfig, real fig, uint8_t sA, real A, uint8_t sD,
                           real D, uint8_t sL, real L, real *out)
{
    uint8_t ar;
    if (sA) {
        *out = A;
        return 0;
    }
    if (!sfig)
        return "Falta el area A (o la figura)";
    ar = drag_shapes[(uint8_t)fig - 1].area;
    if (!sD || ((ar == AR_LD || ar == AR_BH) && !sL))
        return "Faltan las dimensiones (o A)";
    *out = dragcat_area(ar, D, L);
    return 0;
}

static uint8_t kind_of(uint8_t sfig, real fig)
{
    return sfig ? drag_shapes[(uint8_t)fig - 1].kind : DK_GENERIC;
}

static void flag_warn(unsigned int w)
{
    MSETF(G_DRELOW, w & DW_RE_LOW);
    MSETF(G_DCRIS, w & DW_CRISIS);
    MSETF(G_DRE1, w & DW_STOKES);
}

static drag_struct_res SR;
static drag_body BD[NB];

static void bodies_hook(void)
{
    char b[UI_COLS + 1];
    uint8_t i;
    for (i = 0; i < (uint8_t)di.nb; i++) {
        memo_line(mfmt(b, sizeof b, "%d: CD=%w A=%w m2 y=%w m", i + 1,
                       (double)BD[i].Cd, (double)BD[i].A, (double)BD[i].y), C_FG);
        memo_line(mfmt(b, sizeof b, "   F%d = CD q A = %w kN  Re=%w", i + 1,
                       (double)(SR.F[i] / 1000), (double)SR.Re[i]), C_OK);
        if (SR.w[i] & DW_CRISIS)
            memo_line("   ! posible crisis de arrastre", C_WARN);
    }
}

static const char *compute(void)
{
    real v, A = 0, cd, Lr, rho = di.rho;
    const char *e;
    unsigned int w = 0;
    uint8_t i, k;
    int err = 0;

    memo_reset();
    C = g_set.h;
    memo_cfg = &C;
    memo_hook = 0;
    v = vms(di.V);
    memo_V[V_VIN] = di.V;
    memo_V[V_VEL] = v;
    memo_V[V_RHO] = rho;
    memo_V[V_NU] = di.nu;
    memo_V[V_MU] = rho * di.nu;
    memo_V[V_G] = C.g;
    MSETF(G_DVCONV, di.vunit != 0);
    if (tipo == DT_AR1 || tipo == DT_AR2) {
        if ((e = area_of(di.sfig, di.fig, di.sA, di.A, di.sD, di.D, di.sL, di.L, &A)))
            return e;
        cd = di.cd;
        Lr = di.sLr ? di.Lr : di.sD ? di.D : R_SQRT(A);
        k = kind_of(di.sfig, di.fig);
        memo_V[V_CDV] = cd;
        memo_V[V_AREF] = A;
        memo_V[V_DIM1] = di.D;
        memo_V[V_DIM2] = di.L;
        memo_V[V_LREF] = Lr;
        MSETF(G_DFIG, di.sfig);
        MSETF(G_DACALC, !di.sA);
        memo_txt = di.sfig ? area_txt[drag_shapes[(uint8_t)di.fig - 1].area] : "";
        memo_V[V_KST] = di.sfig ? drag_shapes[(uint8_t)di.fig - 1].stokes : 0;
        if (tipo == DT_AR1) {
            memo_V[V_QDYN] = drag_q(rho, v);
            memo_V[V_FD] = drag_force(rho, cd, A, v);
            memo_V[V_RE] = drag_re(v, Lr, di.nu);
            w = drag_re_warn(memo_V[V_RE], k);
            MSETF(G_DLIFT, di.lift);
            if ((w & DW_STOKES) && memo_V[V_KST] > 0 && !di.lift) {
                memo_V[V_CDV] = memo_V[V_KST] / memo_V[V_RE];
                memo_V[V_FD] = drag_force(rho, memo_V[V_CDV], A, v);
                MSETF(G_DSTK, 1);
            }
        } else {
            drag_term_res t;
            uint8_t useb = di.svol && (di.fluid == 1 || g_set.buoy || di.fluid == 2);
            if (di.fluid == 1 && !di.svol)
                return "Agua: falta el volumen (empuje)";
            err = drag_terminal(di.W, rho, useb ? di.vol : 0, cd, A, Lr, di.nu,
                                C.g, k, &t);
            if (err == H_ERR_FLOATS)
                return "W <= B: el cuerpo flota, no cae";
            memo_V[V_W] = di.W;
            memo_V[V_VOL] = di.vol;
            memo_V[V_BUOY] = t.B;
            memo_V[V_NET] = t.net;
            memo_V[V_VT] = t.v;
            memo_V[V_RE] = t.Re;
            w = t.warn;
            MSETF(G_DBUOY, useb);
            if ((w & DW_STOKES) && memo_V[V_KST] > 0) {
                memo_V[V_VT] = 2 * t.net * Lr / (rho * memo_V[V_KST] * di.nu * A);
                memo_V[V_RE] = drag_re(memo_V[V_VT], Lr, di.nu);
                memo_V[V_CDV] = memo_V[V_KST] / memo_V[V_RE];
                MSETF(G_DSTK, 1);
            }
            memo_V[V_VTKMH] = memo_V[V_VT] * 3.6;
        }
        flag_warn(w);
    } else if (tipo == DT_AR3) {
        memo_V[V_QDYN] = drag_q(rho, v);
        for (i = 0; i < (uint8_t)di.nb; i++) {
            body_in *b = &di.b[i];
            if (!b->sy)
                return "Falta la cota y de un cuerpo";
            if ((e = area_of(b->sfig, b->fig, b->sA, b->A, b->sD, b->D, b->sL, b->L, &A)))
                return e;
            BD[i].Cd = b->cd;
            BD[i].A = A;
            BD[i].y = b->y;
            BD[i].V = b->sV ? vms(b->V) : v;
            BD[i].Lref = b->sD ? b->D : R_SQRT(A);
            BD[i].kind = kind_of(b->sfig, b->fig);
        }
        err = drag_struct(BD, (uint8_t)di.nb, rho, di.nu, &SR);
        memo_V[V_FTOT] = SR.Ftot / 1000;
        memo_V[V_MOM] = SR.M / 1000;
        memo_V[V_YCP] = SR.ycp;
        flag_warn(SR.warn);
        memo_hook = bodies_hook;
    } else if (tipo == DT_AR4) {
        drag_plane_res pl;
        if (!di.srh4 && !di.sh)
            return "Falta la altitud h o rho";
        rho = di.srh4 ? di.rh4 : drag_rho_alt(di.h);
        MSETF(G_DALT, !di.srh4);
        memo_V[V_ALT] = di.h;
        memo_V[V_RHO] = rho;
        err = drag_plane_lift(di.W, rho, v, di.Aw, (uint8_t)di.nw, &pl);
        if (!err && di.scdw) {
            err = drag_plane_thrust(di.W, rho, v, di.cdw, di.cdf, di.Df,
                                    di.sclmax ? di.clmax : 0, &pl);
            MSETF(G_DSTEP2, 1);
            MSETF(G_DVST, di.sclmax);
            memo_V[V_AFUS] = pl.Afus;
            memo_V[V_DWING] = pl.Dw / 1000;
            memo_V[V_DFUS] = pl.Df / 1000;
            memo_V[V_THR] = pl.T / 1000;
            memo_V[V_PWR] = pl.P / 1e6;
            memo_V[V_VST] = pl.Vst;
            memo_V[V_VTKMH] = pl.Vst * 3.6;
        }
        memo_V[V_W] = di.W;
        memo_V[V_QDYN] = pl.q;
        memo_V[V_CL] = pl.CL;
        memo_V[V_ATOT] = pl.Atot;
        memo_V[V_AW] = di.Aw;
        memo_V[V_NW] = di.nw;
        memo_V[V_CDW] = di.cdw;
        memo_V[V_CDF] = di.cdf;
        memo_V[V_DF] = di.Df;
        memo_V[V_ALPHA] = di.alpha;
        memo_V[V_CLMAX] = di.clmax;
    } else {
        memo_V[V_DIM1] = di.D;
        memo_V[V_RE] = drag_re(v, di.D, di.nu);
        if (di.kase) {
            MSETF(G_PSTK, 1);
            memo_V[V_FD] = drag_stokes(rho * di.nu, v, di.D);
            memo_V[V_CDV] = 24 / memo_V[V_RE];
            MSETF(G_DRE1, memo_V[V_RE] >= 1);    /* aviso: Re >= 1 */
        } else {
            drag_plate_res p;
            if (!di.sL)
                return "Falta el ancho w de la placa";
            err = drag_plate(di.D, di.L, v, rho, di.nu, (uint8_t)(di.faces + 1),
                             di.regime, &p);
            memo_V[V_DIM2] = di.L;
            memo_V[V_CFL] = p.Cf_lam;
            memo_V[V_CFT] = p.Cf_turb;
            memo_V[V_CFM] = p.Cf_mix;
            memo_V[V_CF] = p.Cf;
            memo_V[V_APL] = p.A;
            memo_V[V_FACES] = di.faces + 1;
            memo_V[V_QDYN] = drag_q(rho, v);
            memo_V[V_FD] = p.F;
            MSETF(G_PLAM, p.regime == PL_LAM);
            MSETF(G_PTURB, p.regime == PL_TURB);
            MSETF(G_PMIX, p.regime == PL_MIX);
            MSETF(G_PLAMNA, p.warn & DW_LAM_NA);
            MSETF(G_PTURBNA, p.warn & DW_TURB_NA);
        }
    }
    return err ? hydro_err_text(err) : 0;
}

/* ------------------------------------------------------------------ */
/* Esquema de la estructura: fuerzas a su altura                       */
/* ------------------------------------------------------------------ */
static void sketch(void)
{
    static const char *const fk[5] = { "", "", "", "", "VOLVER" };
    char b[UI_COLS + 1];
    real ymax = 0, fmax = 0;
    uint8_t i, r;
    ui_key k;
    for (i = 0; i < (uint8_t)di.nb; i++) {
        if (BD[i].y > ymax) ymax = BD[i].y;
        if (SR.F[i] > fmax) fmax = SR.F[i];
    }
    if (!(ymax > 0) || !(fmax > 0))
        return;
    do {
        ui_begin("ESQUEMA DE FUERZAS", 0);
        gfxcat_rect(10, 200, 300, 3, C_GROUND);       /* suelo */
        gfxcat_rect(30, 30, 3, 170, C_GRAY);          /* eje   */
        for (i = 0; i < (uint8_t)di.nb; i++) {
            uint8_t y = (uint8_t)(200 - 165 * BD[i].y / ymax);
            gfxcat_rect(33, (uint8_t)(y - 1), (int)(150 * SR.F[i] / fmax) + 2, 3, C_LP);
            r = (uint8_t)((y - 14) / 10 + 1);
            ui_text(r, 24, mfmt(b, 16, "F%d=%w kN", i + 1, (double)(SR.F[i] / 1000)),
                    C_FG, C_BG);
        }
        ui_text(20, 0, mfmt(b, sizeof b, "M = %w kN m  ycp = %w m",
                            (double)(SR.M / 1000), (double)SR.ycp), C_TITLE, C_BG);
        ui_fbar(fk);
        ui_end();
        k = ui_getkey();
    } while (k.k == K_NONE || k.k == K_ALPHA);
}

/* ------------------------------------------------------------------ */
static void result_loop(void)
{
    static const char *fk_sum[5] = { "MEMORIA", "", "", "", "VOLVER" };
    static const char *const fk_memo[5] = { "RESUMEN", "", "", "", "VOLVER" };
    bool memo = false;
    uint8_t k;
    fk_sum[1] = tipo == DT_AR3 ? "ESQUEMA" : "";
    for (;;) {
        memo_show(PROG_X(XP_AR1_SUM + 2 * tipo + memo));
        k = view_run(titles[tipo], memo ? fk_memo : fk_sum);
        if (k == K_F1)
            memo = !memo;
        else if (k == K_F2 && tipo == DT_AR3)
            sketch();
        else if (k == K_MODE)
            scr_settings();
        else
            return;
        if (ui_quit)
            return;
    }
}

/* F1 CD: catalogo; en la estructura, para el cuerpo del cursor */
static void pick_cd(form_t *fm)
{
    int r;
    uint8_t i = 0xFF;
    if (tipo == DT_AR3) {
        if (fm->cur >= 6)
            i = (uint8_t)((fm->cur - 6) / 7);
        if (i >= (uint8_t)di.nb) {
            fm->msg = "Ubique el cursor en un cuerpo";
            fm->msg_color = C_WARN;
            return;
        }
    }
    r = scr_cat(1);
    if (r < 0)
        return;
    if (i != 0xFF) {
        di.b[i].cd = cat_sel_cd;
        di.b[i].fig = (real)(r + 1);
        di.b[i].scd = di.b[i].sfig = 1;
    } else {
        di.cd = cat_sel_cd;
        di.fig = (real)(r + 1);
        di.scd = di.sfig = 1;
        last_fig = (uint8_t)(r + 1);
    }
}

void scr_drag(uint8_t t)
{
    static uint8_t cur[DT_COUNT];
    form_t fm;
    uint8_t k;
    const char *err;
    if (t >= DT_COUNT)
        return;
    tipo = t;
    if (!di.init) {
        di.init = 1;
        di.nw = 2;
        di.nb = 2;
        di.snw = di.snb = 1;
    }
    memset(&fm, 0, sizeof fm);
    fm.title = titles[t];
    fm.cur = cur[t];
    if (t == DT_AR4 && !di.sV)
        di.vunit = 2;                    /* el examen da nudos */
    on_commit();
    set_form(&fm);
    fm.fk[0] = (t <= DT_AR3) ? "CD" : "";
    fm.fk[3] = "AJUSTES";
    fm.fk[4] = "CALC";
    fm.on_commit = on_commit;
    fm.hint = t == DT_AR4 ? "Sin CD alas: calcula el CL necesario"
                          : "Fluido Aire o Agua llena rho y nu";
    for (;;) {
        fm_now = &fm;
        k = form_run(&fm);
        fm_now = 0;
        if (k == K_QUIT || k == K_CLEAR)
            break;
        if (k == K_F1 && t <= DT_AR3) {
            pick_cd(&fm);
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
            result_loop();
            if (ui_quit)
                break;
        }
    }
    cur[t] = fm.cur;
}
