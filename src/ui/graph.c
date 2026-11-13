/*
 * graph.c - Ver graph.h. Dibuja directo con graphx (solo calculadora).
 */
#include <graphx.h>
#include <string.h>
#include "graph.h"
#include "ui.h"
#include "numfmt.h"
#include "memo.h"
#include "../app.h"

#define GX0 34
#define GX1 286
#define GY0 26
#define GY1 200

static real ymin, ymax;

static int ypix(real e)
{
    real t = (e - ymin) / (ymax - ymin);
    return GY1 - (int)(t * (GY1 - GY0));
}

static void lab(real v, int x, int y, uint8_t col)
{
    char b[NUMFMT_LEN];
    real span = ymax - ymin;
    if (v < span * (real)1e-5 && v > -span * (real)1e-5)
        v = 0;                         /* ruido de float: es 0 */
    fmt_w(v, 7, b);
    gfx_SetTextFGColor(col);
    gfx_SetTextBGColor(C_BG);
    if (x > 320 - 8 * (int)strlen(b))
        x = 320 - 8 * (int)strlen(b);
    if (x < 0)
        x = 0;
    if (y < GY0 - 12)
        y = GY0 - 12;
    if (y > GY1 + 2)
        y = GY1 + 2;
    gfx_PrintStringXY(b, x, y);
}

void graph_run(const char *title, real E0, const gseg *s, uint8_t n,
               real Eend, uint8_t tank2)
{
    static const char *const fk[5] = { "", "", "", "", "VOLVER" };
    int xs[GSEG_MAX + 1];
    real Ltot = 0, E, w, minw;
    uint8_t i;
    ui_key k;

    if (n > GSEG_MAX)
        n = GSEG_MAX;
    /* rango vertical: energia y piezometrica en todos los quiebres */
    ymin = ymax = E0;
    E = E0;
    for (i = 0; i < n; i++) {
        E += s[i].jump;
        if (E > ymax) ymax = E;
        E -= s[i].hloc;
        if (E - s[i].vh < ymin) ymin = E - s[i].vh;
        E -= s[i].hfr;
        if (E - s[i].vh < ymin) ymin = E - s[i].vh;
        if (E > ymax) ymax = E;
        Ltot += s[i].L;
    }
    if (tank2) {
        if (Eend < ymin) ymin = Eend;
        if (Eend > ymax) ymax = Eend;
    }
    if (!(ymax > ymin)) {
        ymax += 1;
        ymin -= 1;
    }
    w = (ymax - ymin) * (real)0.08;
    ymax += w;
    ymin -= w;
    /* anchos: proporcionales a L con un minimo de 1/(4n) del total */
    minw = Ltot / (real)(4 * (n ? n : 1));
    Ltot = 0;
    for (i = 0; i < n; i++)
        Ltot += s[i].L > minw ? s[i].L : minw;
    xs[0] = GX0;
    w = 0;
    for (i = 0; i < n; i++) {
        w += s[i].L > minw ? s[i].L : minw;
        xs[i + 1] = GX0 + (int)((GX1 - GX0) * (w / Ltot));
    }

    for (;;) {
        ui_begin(title, 0);
        /* tanques */
        gfx_SetColor(C_WATER);
        gfx_FillRectangle(2, ypix(E0), GX0 - 4, GY1 - ypix(E0) + 1);
        gfx_SetColor(C_GRAY);
        gfx_Rectangle(2, GY0, GX0 - 4, GY1 - GY0 + 1);
        if (tank2) {
            gfx_SetColor(C_WATER);
            gfx_FillRectangle(GX1 + 2, ypix(Eend), 320 - GX1 - 4, GY1 - ypix(Eend) + 1);
            gfx_SetColor(C_GRAY);
            gfx_Rectangle(GX1 + 2, GY0, 320 - GX1 - 4, GY1 - GY0 + 1);
        }
        /* tubo (eje) y divisiones de tramos */
        gfx_SetColor(C_GRAY);
        gfx_HorizLine(GX0, GY1, GX1 - GX0);
        for (i = 0; i <= n; i++)
            gfx_VertLine(xs[i], GY1 - 3, 7);
        /* LE y LP */
        E = E0;
        for (i = 0; i < n; i++) {
            int x0 = xs[i], x1 = xs[i + 1];
            real Ea = E + s[i].jump, Eb = Ea - s[i].hloc, Ec = Eb - s[i].hfr;
            gfx_SetColor(C_LE);
            gfx_Line(x0, ypix(E), x0, ypix(Eb));        /* salto y local */
            gfx_Line(x0, ypix(Eb), x1, ypix(Ec));       /* friccion      */
            gfx_SetColor(C_LP);
            gfx_Line(x0, ypix(Eb - s[i].vh), x1, ypix(Ec - s[i].vh));
            if (i > 0)
                gfx_Line(x0, ypix(E - s[i - 1].vh), x0, ypix(Eb - s[i].vh));
            gfx_SetTextFGColor(C_FG);
            gfx_SetTextBGColor(C_BG);
            gfx_PrintStringXY(s[i].name, (x0 + x1) / 2 - 4, GY1 + 4);
            if (s[i].jump != 0)
                lab(Ea, x0 + 2, ypix(Ea) - 10, C_LE);
            E = Ec;
        }
        /* salida al tanque: la LP sube a la LE (v = 0) */
        if (n) {
            gfx_SetColor(C_LP);
            gfx_Line(GX1, ypix(E - s[n - 1].vh), GX1, ypix(tank2 ? Eend : E));
        }
        lab(E0, 2, ypix(E0) - 11, C_LE);
        lab(E, GX1 - 56, ypix(E) - 11, C_LE);
        /* leyenda */
        gfx_SetTextFGColor(C_LE);
        gfx_SetTextBGColor(C_BG);
        gfx_PrintStringXY("LE", 216, 14);
        gfx_SetTextFGColor(C_LP);
        gfx_PrintStringXY("LP", 240, 14);
        ui_msg("Esquema sin escala; cotas de energia, m", C_GRAY);
        ui_fbar(fk);
        ui_end();
        k = ui_getkey();
        if (k.k == K_CLEAR || k.k == K_F5 || k.k == K_QUIT || k.k == K_ENTER)
            return;
    }
}
