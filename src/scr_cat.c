/*
 * scr_cat.c - v2.0: catalogo de coeficientes de arrastre (Biblioteca y
 * selector desde los formularios). Lista con miniaturas 3D, detalle con
 * la ilustracion grande, comparar hasta 3 figuras, ranking por C_D,
 * valor propio (EDITAR) y C_D por parametro (L/D, b/h, angulo).
 * Escrito para ocupar poco: cada byte de codigo es RAM en la calculadora.
 */
#include <string.h>
#include "app.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "ui/numfmt.h"
#include "ui/memo.h"
#include "ui/gfxcat.h"
#include "data/dragcat.h"
#include "hydro/drag.h"

/* resultado de USAR (para los formularios de arrastre) */
real cat_sel_cd;
real cat_sel_param;          /* parametro de la tabla (0: no hubo) */

static uint8_t mk[3], nmk;   /* figuras marcadas para comparar */
static bool gfx_ok;
static const char *msg;
static char b[UI_COLS + 1];
static uint8_t R, COL;       /* fila y columna de la siguiente linea */

#define ROWY(r) ((uint8_t)(14 + ((r) - 1) * 10))
#define S(i) (&drag_shapes[i])

static void L(const char *s, uint8_t c)
{
    ui_text(R++, COL, s, c, C_BG);
}

static bool marked(uint8_t i)
{
    return (nmk > 0 && mk[0] == i) || (nmk > 1 && mk[1] == i) ||
           (nmk > 2 && mk[2] == i);
}

static void toggle_mark(uint8_t i)
{
    uint8_t k;
    for (k = 0; k < nmk; k++)
        if (mk[k] == i) {
            for (; k + 1 < nmk; k++)
                mk[k] = mk[k + 1];
            nmk--;
            return;
        }
    if (nmk >= 3)
        msg = "Maximo 3 figuras para comparar";
    else
        mk[nmk++] = i;
}

/* pie comun: mensaje pendiente o aviso de PERDGFX, teclas y espera */
static ui_key finish(const char *const fk[5], const char *hint)
{
    ui_key k;
    if (msg)
        ui_msg(msg, C_WARN);
    else if (!gfx_ok)
        ui_msg("Falta PERDGFX: sin ilustraciones", C_WARN);
    else if (hint)
        ui_msg(hint, C_GRAY);
    msg = 0;
    ui_fbar(fk);
    ui_end();
    k = ui_getkey();
    if (k.k == K_MODE)
        scr_settings();
    return k;
}

/* ------------------------------------------------------------------ */
static void compare(void)
{
    static const char *const fk[5] = { "LIMPIAR", "", "", "", "VOLVER" };
    uint8_t k;
    real mx = 0, cd[3];
    ui_key key;
    do {
        ui_begin("COMPARAR FIGURAS", 0);
        for (k = 0; k < nmk; k++)
            if ((cd[k] = dragcat_cd(mk[k])) > mx)
                mx = cd[k];
        R = 13;
        COL = 0;
        for (k = 0; k < nmk; k++) {
            int x = 4 + k * 106;
            uint8_t col = (uint8_t)(k * 13 + 1);
            gfxcat_draw(mk[k], true, x, ROWY(1), 1);
            ui_text_n(9, col, S(mk[k])->name, 12, C_FG, C_BG);
            ui_text(10, col, mfmt(b, sizeof b, "CD %w", (double)cd[k]), C_TITLE, C_BG);
            gfxcat_rect(x, ROWY(11), (int)(96 * cd[k] / mx), 8, C_LE);
            if (k)
                L(mfmt(b, sizeof b, "Fig %d / fig 1: %w veces el arrastre", k + 1,
                       (double)(cd[k] / cd[0])), C_FG);
        }
        R = 16;
        L("(igual A, V y rho: F prop. a CD)", C_GRAY);
        key = finish(fk, 0);
        if (key.k == K_F1)
            nmk = 0;
    } while (key.k == K_MODE || key.k == K_NONE || key.k == K_ALPHA);
}

static void ranking(void)
{
    static const char *const fk[5] = { "", "", "", "", "VOLVER" };
    uint8_t ord[CAT_N], i, j, t;
    real cd;
    ui_key key;
    for (i = 0; i < CAT_N; i++)
        ord[i] = i;
    for (i = 1; i < CAT_N; i++)          /* insercion: 17 elementos */
        for (j = i; j > 0 && dragcat_cd(ord[j]) < dragcat_cd(ord[j - 1]); j--) {
            t = ord[j];
            ord[j] = ord[j - 1];
            ord[j - 1] = t;
        }
    do {
        ui_begin("RANKING DE CD (menor a mayor)", 0);
        R = 1;
        COL = 0;
        for (i = 0; i < CAT_N; i++) {
            cd = dragcat_cd(ord[i]);
            gfxcat_rect(264, (uint8_t)(ROWY(R) + 1), (int)(52 * cd / 2.2) + 1, 7, C_LE);
            L(mfmt(b, 33, "%d %s                          ", ord[i] + 1,
                   S(ord[i])->name), C_FG);
            ui_text_r((uint8_t)(R - 1), 32, fmt_w(cd, 4, b), C_TITLE, C_BG);
        }
        key = finish(fk, 0);
    } while (key.k == K_MODE || key.k == K_NONE || key.k == K_ALPHA);
}

/* ------------------------------------------------------------------ */
/* Formulario de un solo campo. true si se acepto con valor */
static uint8_t one_field(const char *title, const char *lab, real *v,
                         uint8_t flags, const char *hint, const char *f1)
{
    static form_field f;
    static form_t fm;
    uint8_t set = 1, k;
    memset(&f, 0, sizeof f);
    f.label = lab;
    f.val = v;
    f.set = &set;
    f.flags = flags;
    f.lo = 0.001;
    f.hi = 10;
    memset(&fm, 0, sizeof fm);
    fm.title = title;
    fm.f = &f;
    fm.n = 1;
    fm.fk[0] = f1;
    fm.fk[4] = "LISTO";
    fm.hint = hint;
    k = form_run(&fm);
    return (k == K_F1) ? 2 : ((k == K_F5 || k == K_ENTER) && set);
}

static void edit_cd(uint8_t i)
{
    real v = dragcat_cd(i);
    uint8_t r = one_field("EDITAR CD", "CD propio", &v, FF_RANGE, S(i)->name,
                          "DEFECTO");
    if (r == 2)
        v = 0;                       /* F1: vuelve el del catalogo */
    else if (!r)
        return;
    g_set.cd_user[i] = (v == S(i)->cd) ? 0 : v;
    g_set_dirty = true;
}

/* Pide el parametro de la tabla y deja el C_D en cat_sel_cd */
static bool ask_param(uint8_t i)
{
    const drag_table *t = dragcat_table(S(i)->tab);
    static real p = 10;
    unsigned int w = 0;
    real x0, y0, x1, y1;
    char l1[UI_COLS + 1];
    if (!t || one_field("CD POR TABLA", t->param, &p, FF_POS,
                        t->inf > 0 ? "1000 o mas = infinito" : S(i)->name, 0) != 1)
        return false;
    cat_sel_cd = dragcat_param(i, p, &x0, &y0, &x1, &y1, &w);
    cat_sel_param = p;
    mfmt(l1, sizeof l1, "CD = %w %s", (double)cat_sel_cd,
         (w & DW_CLAMP) ? "(fuera: extremo)" : (w & DW_INTERP) ? "(interpolado)" : "");
    mfmt(b, sizeof b, "%s %w: %w   %w: %w", t->param, (double)x0, (double)y0,
         (double)x1, (double)y1);
    ui_alert("CD POR TABLA", l1, b, (w & DW_CLAMP) ? C_WARN : C_OK);
    return true;
}

/* ------------------------------------------------------------------ */
/* devuelve 1 si se uso la figura (USAR) */
static uint8_t detail(uint8_t *pi, uint8_t use)
{
    static const char *fk[5] = { "", "COMPAR.", "EDITAR", "", "VOLVER" };
    const drag_shape *d;
    const drag_table *t;
    const char *np;
    uint8_t k, i;
    ui_key key;
    for (;;) {
        i = *pi;
        d = S(i);
        t = dragcat_table(d->tab);
        fk[0] = use ? "USAR" : "";
        fk[3] = t ? "TABLA" : "";
        ui_begin(d->name, 0);
        gfxcat_draw(i, true, 2, ROWY(1), 2);
        R = 1;
        COL = 25;
        L(mfmt(b, 16, "CD = %w", (double)dragcat_cd(i)), C_TITLE);
        if (g_set.cd_user[i] > 0)
            L(mfmt(b, 16, "(catal. %w)", (double)d->cd), C_WARN);
        R++;
        L("Area de ref.:", C_GRAY);
        L(area_txt[d->area], C_FG);
        L("Validez:", C_GRAY);
        L("Re > 1E4", C_FG);
        if (d->stokes > 0)
            L(mfmt(b, 16, "Re<1: %w/Re", (double)d->stokes), C_FG);
        L("Fuente:", C_GRAY);
        L(d->src, C_FG);
        if (t) {
            L(mfmt(b, 16, "%s  CD", t->param), C_GRAY);
            for (k = 0; k < t->n && R < 17; k++)
                L(mfmt(b, 16, "%w  %w", (double)t->x[k], (double)t->y[k]), C_FG);
            if (t->inf > 0 && R < 17)
                L(mfmt(b, 16, "inf  %w", (double)t->inf), C_FG);
        }
        R = 17;
        COL = 0;
        L(d->orient, C_GRAY);
        for (np = d->note; R <= 19 && *np; ) {   /* nota: '|' separa lineas */
            for (k = 0; np[k] && np[k] != '|' && k < UI_COLS; k++)
                ;
            ui_text_n(R++, 0, np, k, C_FG, C_BG);
            np += k + (np[k] == '|');
        }
        if (marked(i))
            ui_text(20, 0, "* marcada para comparar", C_OK, C_BG);
        key = finish(fk, 0);
        switch (key.k) {
        case K_F1:
            if (!use)
                break;
            cat_sel_cd = dragcat_cd(i);
            cat_sel_param = 0;
            if (t && !ask_param(i))
                break;
            return 1;
        case K_F2:
            if (!marked(i))
                toggle_mark(i);
            if (nmk >= 2)
                compare();
            else if (!msg)
                msg = "Marcada; elija otra figura (F2)";
            break;
        case K_F3: edit_cd(i); break;
        case K_F4: if (t) ask_param(i); break;
        case K_UP: if (i) *pi = (uint8_t)(i - 1); break;
        case K_DOWN: if (i + 1 < CAT_N) *pi = (uint8_t)(i + 1); break;
        case K_QUIT: case K_CLEAR: case K_F5: return 0;
        default: break;
        }
        if (ui_quit)
            return 0;
    }
}

/* ------------------------------------------------------------------ */
#define PAGE 10

int scr_cat(uint8_t use)
{
    static const char *const fk[5] = { "", "MARCAR", "COMPAR.", "RANKING", "VOLVER" };
    static uint8_t cur;
    uint8_t top, k, i, r, bg;
    ui_key key;
    gfx_ok = gfxcat_open();
    for (;;) {
        top = (uint8_t)(cur / PAGE * PAGE);
        ui_begin(use ? "ELIJA LA FIGURA (CD)" : "COEFICIENTES DE ARRASTRE", 0);
        for (k = 0; k < PAGE && top + k < CAT_N; k++) {
            i = (uint8_t)(top + k);
            r = (uint8_t)(1 + 2 * k);
            bg = (i == cur) ? C_SEL : C_BG;
            if (i == cur) {
                ui_row_fill(r, C_SEL);
                ui_row_fill((uint8_t)(r + 1), C_SEL);
            }
            gfxcat_draw(i, false, 2, (uint8_t)(ROWY(r) + 1), 1);
            ui_text(r, 5, mfmt(b, 32, "%s%d %s", marked(i) ? "*" : " ", i + 1,
                               S(i)->name), C_FG, bg);
            ui_text_n((uint8_t)(r + 1), 9, S(i)->orient, 25, C_GRAY, bg);
            ui_text_r(r, 39, fmt_w(dragcat_cd(i), 4, b),
                      g_set.cd_user[i] > 0 ? C_WARN : C_TITLE, bg);
        }
        key = finish(fk, "ENTER: detalle con ilustracion 3D");
        switch (key.k) {
        case K_UP: cur = cur ? (uint8_t)(cur - 1) : (uint8_t)(CAT_N - 1); break;
        case K_DOWN: cur = (uint8_t)((cur + 1) % CAT_N); break;
        case K_PGUP: cur = cur >= PAGE ? (uint8_t)(cur - PAGE) : 0; break;
        case K_PGDN: cur = cur + PAGE < CAT_N ? (uint8_t)(cur + PAGE) : (uint8_t)(CAT_N - 1); break;
        case K_ENTER:
            if (detail(&cur, use))
                return cur;
            break;
        case K_F2: toggle_mark(cur); break;
        case K_F3:
            if (nmk >= 2)
                compare();
            else
                msg = "Marque 2 o 3 figuras con F2";
            break;
        case K_F4: ranking(); break;
        case K_QUIT: case K_CLEAR: case K_F5: return -1;
        default: break;
        }
        if (ui_quit)
            return -1;
    }
}
