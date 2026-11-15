/*
 * scr_weir.c - v2.0: vertedores y orificios (prompt v2, sec. 4.5).
 *   0 Elemento simple: vertedero triangular o rectangular, orificio
 *     circular o rectangular; dado H -> Q o dado Q -> H (VE-1, VE-2) y,
 *     con el nivel aguas arriba, la cota de la cresta h0 = h - H (VE-5)
 *   1 Estructura compuesta: hasta 8 elementos a distintas cotas, con
 *     "cantidad x"; nivel -> Q por elemento y total, o Q -> nivel (VE-4)
 *   2 Perfil de velocidades: v = k y^n o tabla de puntos (VE-6)
 *   3 Aguas abajo: v, E, Fr y tirantes alternos por Bernoulli (VE-7)
 * Cotas desde una misma referencia: z es el vertice (triangular), la
 * cresta (rectangular) o el CENTRO del orificio. Motor: hydro/weir.c.
 */
#include <string.h>
#include "app.h"
#include "memo_run.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "ui/numfmt.h"
#include "ui/memo.h"
#include "ui/gfxcat.h"
#include "hydro/weir.h"

enum { WT_SIMPLE = 0, WT_COMP, WT_PROF, WT_DOWN, WT_COUNT };
#define NE WEIR_MAX
#define NP 9

typedef struct {
    real n, d1, d2, z, cd;
    uint8_t sn, sd1, sd2, sz, scd;
    uint8_t type;
} el_in;

static struct {
    real cd, d1, d2, H, Q, hup, nc, ne, h, b, ph, k, pn, np, sQ_, sb, h1, dz;
    uint8_t scd, sd1, sd2, sH, sQ, shup, snc, sne, sh, sb_, sph, sk, spn, snp,
            ssQ, ssb, sh1, sdz;
    uint8_t etype, mode, qunit, cmode, pmode, smode, init;
    el_in e[NE];
    real y[NP], v[NP];
    uint8_t sy[NP], sv[NP];
} wi;

static const char *const et_names[WE_COUNT] = {
    "Triangular", "Rectangular", "Orificio circ.", "Orificio rect."
};
static const char *const md_names[2] = { "Dado H -> Q", "Dado Q -> H" };
static const char *const cm_names[2] = { "Nivel h -> Q", "Q -> nivel h" };
static const char *const qu_names[2] = { "l/s", "m3/s" };
static const char *const pm_names[2] = { "v = k y^n", "Tabla (y, v)" };
static const char *const sm_names[2] = { "Solo seccion 1", "h2 por Bernoulli" };
static const char *const d1_lab[WE_COUNT] = {
    "Angulo theta", "Ancho b", "Diametro d", "Ancho b"
};
static const char *const d1_unit[WE_COUNT] = { "grad", "m", "m", "m" };

#define FN(lab, un, v, fl) { lab, un, &wi.v, 0, &wi.s##v, fl, 0, 0, 0, 0 }
#define FC(lab, v, names, n) { lab, 0, 0, &wi.v, 0, FF_CHOICE, names, n, 0, 0 }

static form_field f_simple[] = {
    FC("Elemento", etype, et_names, WE_COUNT),
    FC("Calcular", mode, md_names, 2),
    FN("Cd", 0, cd, FF_POS),
    { "Angulo theta", "grad", &wi.d1, 0, &wi.sd1, FF_POS, 0, 0, 0, 0 },
    FN("Alto a (orif.rect)", "m", d2, FF_POS | FF_OPT),
    { "Contracciones 0-2", 0, &wi.nc, 0, &wi.snc, FF_INT | FF_OPT, 0, 0, 0, 2 },
    FN("Carga H (o Q)", "m", H, FF_POS | FF_OPT),
    FN("Caudal Q (o H)", 0, Q, FF_POS | FF_OPT),
    FC("Unidad de Q", qunit, qu_names, 2),
    FN("Nivel arriba(opc)", "m", hup, FF_ANY | FF_OPT),
};
static form_field f_prof_pow[] = {
    FC("Perfil", pmode, pm_names, 2),
    { "Ancho b", "m", &wi.b, 0, &wi.sb_, FF_POS, 0, 0, 0, 0 },
    { "Tirante h", "m", &wi.ph, 0, &wi.sph, FF_POS, 0, 0, 0, 0 },
    FN("k (v = k y^n)", 0, k, FF_POS),
    { "n (v = k y^n)", 0, &wi.pn, 0, &wi.spn, FF_NONNEG, 0, 0, 0, 0 },
};
static form_field f_down[] = {
    FC("Calcular", smode, sm_names, 2),
    { "Caudal Q", 0, &wi.sQ_, 0, &wi.ssQ, FF_POS, 0, 0, 0, 0 },
    FC("Unidad de Q", qunit, qu_names, 2),
    { "Ancho b", "m", &wi.sb, 0, &wi.ssb, FF_POS, 0, 0, 0, 0 },
    FN("Tirante h1", "m", h1, FF_POS),
    FN("Escalon dz (opc)", "m", dz, FF_ANY | FF_OPT),
};

static const char *const titles[WT_COUNT] = {
    "VERTEDERO U ORIFICIO", "ESTRUCTURA COMPUESTA (VE-4)",
    "PERFIL DE VELOCIDADES (VE-6)", "AGUAS ABAJO: ENERGIA (VE-7)"
};

extern form_field ff_shared[];
extern char flab_shared[][18];
static uint8_t tipo;
static form_t *fm_now;
static hydro_cfg C;

static void put_field(form_field *f, const char *lab, const char *unit, real *v,
                      uint8_t *s, uint8_t fl)
{
    memset(f, 0, sizeof *f);
    f->label = lab;
    f->unit = unit;
    f->val = v;
    f->set = s;
    f->flags = fl;
    f->lo = 1;
    f->hi = 20;
}

/* estructura: 4 comunes + 6 por elemento (tipo, cantidad, dim 1, dim 2,
 * cota z, Cd) */
static uint8_t build_comp(void)
{
    static const char *const sub[6] = { "Tipo", "Cantidad", "theta/b/d",
                                        "a (orif.rect)", "Cota z", "Cd (opc)" };
    static const char *const unit[6] = { 0, 0, 0, "m", "m", 0 };
    static const uint8_t fl[6] = { FF_CHOICE, FF_INT, FF_POS, FF_POS | FF_OPT,
                                   FF_ANY, FF_POS | FF_OPT };
    static const form_field head[] = {
        { "Numero elementos", 0, &wi.ne, 0, &wi.sne, FF_INT, 0, 0, 1, NE },
        FC("Calcular", cmode, cm_names, 2),
        FN("Nivel h (o Q)", "m", h, FF_ANY | FF_OPT),
        FN("Q total (o h)", 0, Q, FF_POS | FF_OPT),
        FC("Unidad de Q", qunit, qu_names, 2),
    };
    uint8_t n = sizeof head / sizeof head[0], i, j;
    form_field *f;
    memcpy(ff_shared, head, sizeof head);
    ff_shared[3].unit = qu_names[wi.qunit];
    for (i = 0; i < (uint8_t)wi.ne; i++) {
        el_in *e = &wi.e[i];
        real *v[6] = { 0, &e->n, &e->d1, &e->d2, &e->z, &e->cd };
        uint8_t *s[6] = { 0, &e->sn, &e->sd1, &e->sd2, &e->sz, &e->scd };
        for (j = 0; j < 6; j++) {
            char *l = flab_shared[i * 6 + j];
            l[0] = (char)('1' + i);
            l[1] = ' ';
            strcpy(l + 2, sub[j]);
            f = &ff_shared[n++];
            put_field(f, l, unit[j], v[j], s[j], fl[j]);
            if (j == 0) {
                f->ch = &e->type;
                f->choices = et_names;
                f->nchoices = WE_COUNT;
            }
        }
    }
    return n;
}

/* perfil por puntos: comunes + (y, v) por punto */
static uint8_t build_pts(void)
{
    static const form_field head[] = {
        FC("Perfil", pmode, pm_names, 2),
        { "Ancho b", "m", &wi.b, 0, &wi.sb_, FF_POS, 0, 0, 0, 0 },
        { "Numero de puntos", 0, &wi.np, 0, &wi.snp, FF_INT, 0, 0, 2, NP },
    };
    uint8_t n = sizeof head / sizeof head[0], i;
    memcpy(ff_shared, head, sizeof head);
    for (i = 0; i < (uint8_t)wi.np; i++) {
        char *l = flab_shared[2 * i];
        strcpy(l, "1 y (desde fondo)");
        l[0] = (char)('1' + i);
        put_field(&ff_shared[n++], l, "m", &wi.y[i], &wi.sy[i], FF_NONNEG);
        l = flab_shared[2 * i + 1];
        strcpy(l, "1 v");
        l[0] = (char)('1' + i);
        put_field(&ff_shared[n++], l, "m/s", &wi.v[i], &wi.sv[i], FF_NONNEG);
    }
    return n;
}

static void set_form(form_t *fm)
{
    switch (tipo) {
    case WT_SIMPLE:
        fm->f = f_simple;
        fm->n = sizeof f_simple / sizeof f_simple[0];
        break;
    case WT_COMP:
        fm->f = ff_shared;
        fm->n = build_comp();
        break;
    case WT_PROF:
        if (wi.pmode) {
            fm->f = ff_shared;
            fm->n = build_pts();
        } else {
            fm->f = f_prof_pow;
            fm->n = sizeof f_prof_pow / sizeof f_prof_pow[0];
        }
        break;
    default:
        fm->f = f_down;
        fm->n = sizeof f_down / sizeof f_down[0];
        break;
    }
    if (fm->cur >= fm->n)
        fm->cur = 0;
}

/* etiqueta de la dimension segun el elemento; rehacer formularios con
 * numero variable de campos */
static void on_commit(void)
{
    static real ne0, np0;
    static uint8_t pm0;
    f_simple[3].label = d1_lab[wi.etype];
    f_simple[3].unit = d1_unit[wi.etype];
    f_simple[7].unit = f_down[1].unit = qu_names[wi.qunit];
    if (tipo == WT_COMP && fm_now)
        ff_shared[3].unit = qu_names[wi.qunit];
    if (fm_now && ((tipo == WT_COMP && wi.ne != ne0) ||
                   (tipo == WT_PROF && (wi.pmode != pm0 || wi.np != np0)))) {
        ne0 = wi.ne;
        np0 = wi.np;
        pm0 = wi.pmode;
        set_form(fm_now);
    }
}

/* ------------------------------------------------------------------ */
static weir_el EL[NE];
static real QI[NE], HI[NE];

static real qsi(real q)              /* caudal de pantalla -> m3/s */
{
    return wi.qunit ? q : q / 1000;
}

static void flag_w(unsigned int w)
{
    MSETF(G_WFRAN, w & VW_FRANCIS);
    MSETF(G_WPART, w & VW_PARTIAL);
    MSETF(G_WHIGH, w & VW_HIGH);
    MSETF(G_WDRY, w & VW_DRY);
}

/* coeficiente de Q = K H^p (con Francis: ancho efectivo b - 0,1 n H) */
static real coefK(const weir_el *e, real H)
{
    real s = R_SQRT(2 * C.g) * e->Cd;
    switch (e->type) {
    case WE_TRI: return s * (8.0 / 15.0) * R_TAN(e->a * (real)0.00872664626);
    case WE_RECT: return s * (2.0 / 3.0) * (e->a - 0.1 * e->ncon * H);
    case WE_ORC: return s * hydro_area(e->a);
    default: return s * e->a * e->b;
    }
}

static void comp_hook(void)
{
    char b[UI_COLS + 1];
    uint8_t i;
    for (i = 0; i < (uint8_t)wi.ne; i++) {
        memo_line(mfmt(b, sizeof b, "%d %s x%d: z=%w Cd=%w", i + 1,
                       et_names[EL[i].type], EL[i].count, (double)EL[i].z,
                       (double)EL[i].Cd), C_FG);
        if (HI[i] > 0)
            memo_line(mfmt(b, sizeof b, "   H=h-z=%w m  Q=%w m3/s", (double)HI[i],
                           (double)QI[i]), C_OK);
        else
            memo_line("   h <= z: no recibe agua, Q = 0", C_GRAY);
    }
}

static const char *compute(void)
{
    real Q = 0, h = 0, H;
    unsigned int w = 0;
    uint8_t i;
    int err = 0, it = 0;

    memo_reset();
    C = g_set.h;
    memo_cfg = &C;
    memo_hook = 0;
    memo_V[V_G] = C.g;
    if (tipo == WT_SIMPLE) {
        memset(EL, 0, sizeof EL);
        EL[0].type = wi.etype;
        EL[0].count = 1;
        EL[0].Cd = wi.cd;
        EL[0].a = wi.d1;
        EL[0].b = (wi.etype == WE_ORR) ? (wi.sd2 ? wi.d2 : 0) : 0;
        EL[0].ncon = (wi.etype == WE_RECT && wi.snc) ? (uint8_t)wi.nc : 0;
        if (wi.etype == WE_ORR && !wi.sd2)
            return "Falta el alto a del orificio";
        if (!wi.mode) {
            if (!wi.sH)
                return "Falta la carga H";
            err = weir_total(EL, 1, wi.H, C.g, &Q, QI, &w);
            H = wi.H;
        } else {
            if (!wi.sQ)
                return "Falta el caudal Q";
            Q = qsi(wi.Q);
            err = weir_level(EL, 1, Q, C.g, &H, QI, &w, &it);
            MSETF(G_WH0, wi.shup);
            memo_V[V_WLEV] = wi.hup;
            memo_V[V_WH0] = wi.hup - H;
        }
        memo_V[V_WH] = H;
        memo_V[V_WK] = coefK(&EL[0], H);
        memo_V[V_WBE] = EL[0].a - 0.1 * EL[0].ncon * H;
        memo_V[V_WNC] = EL[0].ncon;
    } else if (tipo == WT_COMP) {
        for (i = 0; i < (uint8_t)wi.ne; i++) {
            el_in *e = &wi.e[i];
            if (!e->sn || !e->sd1 || !e->sz)
                return "Faltan datos de un elemento";
            if (e->type == WE_ORR && !e->sd2)
                return "Falta el alto a de un orificio";
            EL[i].type = e->type;
            EL[i].count = (uint8_t)e->n;
            EL[i].ncon = 0;
            EL[i].Cd = e->scd ? e->cd : g_set.cd_weir;
            EL[i].z = e->z;
            EL[i].a = e->d1;
            EL[i].b = (e->type == WE_ORR) ? e->d2 : 0;
        }
        if (!wi.cmode) {
            if (!wi.sh)
                return "Falta el nivel h";
            h = wi.h;
            err = weir_total(EL, (uint8_t)wi.ne, h, C.g, &Q, QI, &w);
        } else {
            if (!wi.sQ)
                return "Falta el caudal Q";
            Q = qsi(wi.Q);
            err = weir_level(EL, (uint8_t)wi.ne, Q, C.g, &h, QI, &w, &it);
        }
        for (i = 0; i < (uint8_t)wi.ne; i++)
            HI[i] = h - EL[i].z;
        memo_V[V_WLEV] = h;
        memo_hook = comp_hook;
    } else if (tipo == WT_PROF) {
        memo_V[V_PRB] = wi.b;
        if (!wi.pmode) {
            err = weir_profile_pow(wi.k, wi.pn, wi.b, wi.ph, &Q, &memo_V[V_PRVM]);
            memo_V[V_PRK] = wi.k;
            memo_V[V_PRN] = wi.pn;
            memo_V[V_PRH] = wi.ph;
        } else {
            unsigned char simp;
            err = weir_profile_pts(wi.y, wi.v, (uint8_t)wi.np, wi.b, &Q,
                                   &memo_V[V_PRVM], &simp);
            MSETF(G_WPTS, 1);
            MSETF(G_WSIMP, simp);
            memo_V[V_PRNP] = wi.np;
            memo_V[V_PRH] = wi.y[(uint8_t)wi.np - 1] - wi.y[0];
        }
        memo_V[V_PRQ] = Q;
        memo_V[V_WQLS] = Q * 1000;
        return err ? "Datos invalidos (y debe crecer)" : 0;
    } else {
        real q, v1, E1;
        Q = qsi(wi.sQ_);
        err = weir_section(Q, wi.sb, wi.h1, C.g, &v1, &E1);
        if (err)
            return hydro_err_text(err);
        q = Q / wi.sb;
        memo_V[V_SQ] = Q;
        memo_V[V_SB] = wi.sb;
        memo_V[V_SH1] = wi.h1;
        memo_V[V_SV1] = v1;
        memo_V[V_SE1] = E1;
        memo_V[V_SQQ] = q;
        memo_V[V_SFR1] = v1 / R_SQRT(C.g * wi.h1);
        if (wi.smode) {
            memo_V[V_SDZ] = wi.sdz ? wi.dz : 0;
            memo_V[V_SE2] = E1 - memo_V[V_SDZ];
            MSETF(G_SBER, 1);
            err = weir_alt_depths(q, memo_V[V_SE2], C.g, &memo_V[V_SHS],
                                  &memo_V[V_SHP], &memo_V[V_SHC]);
            if (err) {
                MSETF(G_SNOE, 1);
                memo_V[V_SHC] = R_POW(q * q / C.g, (real)(1.0 / 3.0));
                memo_V[V_SHS] = memo_V[V_SHP] = 0;
            } else {
                memo_V[V_SVS] = q / memo_V[V_SHS];
                memo_V[V_SVP] = q / memo_V[V_SHP];
            }
            memo_V[V_WG2] = 1.5 * memo_V[V_SHC];
        }
        return 0;
    }
    if (err)
        return hydro_err_text(err);
    memo_V[V_WQ] = Q;
    memo_V[V_WQLS] = Q * 1000;
    memo_V[V_WCD] = EL[0].Cd;
    memo_V[V_WD1] = EL[0].a;
    memo_V[V_WD2] = EL[0].b;
    memo_V[V_WAREA] = EL[0].type == WE_ORC ? hydro_area(EL[0].a) : EL[0].a * EL[0].b;
    memo_V[V_WT2] = R_TAN(EL[0].a * (real)0.00872664626);
    memo_V[V_WIT] = it;
    MSETF(G_WTRI, EL[0].type == WE_TRI);
    MSETF(G_WRECT, EL[0].type == WE_RECT);
    MSETF(G_WORC, EL[0].type == WE_ORC);
    MSETF(G_WORR, EL[0].type == WE_ORR);
    MSETF(G_WINV, tipo == WT_SIMPLE ? wi.mode : wi.cmode);
    flag_w(w);
    memo_txt = et_names[EL[0].type];
    return 0;
}

/* ------------------------------------------------------------------ */
/* Esquema de la estructura compuesta: pared, elementos y nivel        */
/* ------------------------------------------------------------------ */
static void sketch(void)
{
    static const char *const fk[5] = { "", "", "", "", "VOLVER" };
    char b[UI_COLS + 1];
    real top = memo_V[V_WLEV], zmin = 0, sc;
    uint8_t i, y0, y1, ybase = 200;
    int x;
    ui_key k;
    for (i = 0; i < (uint8_t)wi.ne; i++) {
        if (EL[i].z < zmin) zmin = EL[i].z;
        if (EL[i].z + 0.1 > top) top = EL[i].z + 0.1;
    }
    top *= 1.15;
    if (!(top - zmin > 0))
        return;
    sc = 170 / (top - zmin);
    do {
        ui_begin("ESQUEMA DE LA ESTRUCTURA", 0);
        gfxcat_rect(20, 30, 280, 171, C_GROUND);                   /* pared */
        y0 = (uint8_t)(ybase - (memo_V[V_WLEV] - zmin) * sc);
        gfxcat_rect(4, y0, 16, (uint8_t)(ybase - y0), C_WATER);    /* agua */
        for (i = 0; i < (uint8_t)wi.ne; i++) {
            x = 34 + i * 34;
            y1 = (uint8_t)(ybase - (EL[i].z - zmin) * sc);
            if (EL[i].type >= WE_ORC) {       /* orificio: cuadro centrado */
                uint8_t d = (uint8_t)(EL[i].type == WE_ORC ? EL[i].a * sc : EL[i].b * sc) + 2;
                gfxcat_rect(x, (uint8_t)(y1 - d / 2), 14, d, C_BG);
            } else {                          /* vertedero: hasta arriba */
                gfxcat_rect(x, 30, 14, (uint8_t)(y1 - 30), C_BG);
                gfxcat_rect(x, y1, 14, 2, C_FG);
            }
            ui_text((uint8_t)((y1 - 14) / 10 + 2 > 18 ? 18 : (y1 - 14) / 10 + 2),
                    (uint8_t)(x / 8), mfmt(b, 5, "%d", i + 1), C_TITLE, C_BG);
        }
        gfxcat_rect(4, y0, 296, 1, C_LE);                          /* nivel */
        ui_text(20, 0, mfmt(b, sizeof b, "h = %w m   Q = %w m3/s",
                            (double)memo_V[V_WLEV], (double)memo_V[V_WQ]),
                C_TITLE, C_BG);
        ui_fbar(fk);
        ui_end();
        k = ui_getkey();
    } while (k.k == K_NONE || k.k == K_ALPHA);
}

static void result_loop(void)
{
    static const char *fk_sum[5] = { "MEMORIA", "", "", "", "VOLVER" };
    static const char *const fk_memo[5] = { "RESUMEN", "", "", "", "VOLVER" };
    bool memo = false;
    uint8_t k;
    fk_sum[1] = tipo == WT_COMP ? "ESQUEMA" : "";
    for (;;) {
        memo_show(PROG_X(XP_VE1_SUM + 2 * tipo + memo));
        k = view_run(titles[tipo], memo ? fk_memo : fk_sum);
        if (k == K_F1)
            memo = !memo;
        else if (k == K_F2 && tipo == WT_COMP)
            sketch();
        else if (k == K_MODE)
            scr_settings();
        else
            return;
        if (ui_quit)
            return;
    }
}

void scr_weir(uint8_t t)
{
    static uint8_t cur[WT_COUNT];
    form_t fm;
    uint8_t k, i;
    const char *err;
    if (t >= WT_COUNT)
        return;
    tipo = t;
    if (!wi.init) {
        wi.init = 1;
        wi.cd = g_set.cd_weir;
        wi.scd = 1;
        wi.ne = 2;
        wi.np = 5;
        wi.sne = wi.snp = 1;
        for (i = 0; i < NE; i++) {
            wi.e[i].n = 1;
            wi.e[i].sn = 1;
        }
    }
    memset(&fm, 0, sizeof fm);
    fm.title = titles[t];
    fm.cur = cur[t];
    on_commit();
    set_form(&fm);
    fm.fk[3] = "AJUSTES";
    fm.fk[4] = "CALC";
    fm.on_commit = on_commit;
    fm.hint = t == WT_SIMPLE ? "Orificio: H al centro; z desde una ref."
            : t == WT_COMP ? "Cotas z: vertice, cresta o centro"
            : t == WT_PROF ? "Perfil: elija la forma con izq/der"
                           : "Bernoulli: E2 = E1 - dz";
    for (;;) {
        fm_now = &fm;
        k = form_run(&fm);
        fm_now = 0;
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
