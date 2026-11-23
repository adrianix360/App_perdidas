/*
 * gfxcat.c - Ver gfxcat.h. Formato en tools/gen_gfx.py.
 */
#include <graphx.h>
#include <fileioc.h>
#include "gfxcat.h"
#include "../app.h"

static const uint8_t *G;
static uint16_t GN;

bool gfxcat_open(void)
{
    uint8_t h = ti_Open(GFX_APPVAR, "r"), i;
    G = 0;
    if (!h)
        return false;
    G = (const uint8_t *)ti_GetDataPtr(h);
    GN = (uint16_t)ti_GetSize(h);
    ti_Close(h);
    if (GN < 9 + 32 + 4 * CAT_N || G[0] != 'P' || G[1] != 'G' || G[2] != 'X' ||
        G[3] != 1 || G[4] != CAT_N || G[5] != GFX_W || G[6] != GFX_H ||
        G[7] != GFX_TW || G[8] != GFX_TH) {
        G = 0;
        return false;
    }
    for (i = 1; i < 16; i++)
        gfx_palette[GFX_PAL0 + i] = (uint16_t)(G[9 + 2 * i] | G[10 + 2 * i] << 8);
    return true;
}

void gfxcat_draw(uint8_t i, bool big, int x, uint8_t y, uint8_t s)
{
    uint16_t o, n, px = 0, w, h;
    uint8_t b, sym, run, r;
    const uint8_t *p;
    if (!G || i >= CAT_N)
        return;
    p = G + 9 + 32 + 2 * (i + (big ? 0 : CAT_N));
    o = (uint16_t)(p[0] | p[1] << 8);
    w = big ? GFX_W : GFX_TW;
    h = big ? GFX_H : GFX_TH;
    n = (uint16_t)(w * h);
    while (px < n && o < GN) {
        b = G[o++];
        sym = b & 15;
        run = (uint8_t)((b >> 4) + 1);
        while (run) {
            uint16_t col = px % w, row = px / w;
            r = run;
            if (col + r > w)
                r = (uint8_t)(w - col);
            if (sym) {
                gfx_SetColor((uint8_t)(GFX_PAL0 + sym));
                gfx_FillRectangle_NoClip(x + col * s, (uint8_t)(y + row * s),
                                         r * s, s);
            }
            px += r;
            run -= r;
            if (px >= n)
                break;
        }
    }
}

void gfxcat_rect(int x, uint8_t y, int w, uint8_t h, uint8_t color)
{
    if (w <= 0)
        return;
    gfx_SetColor(color);
    gfx_FillRectangle_NoClip(x, y, w, h);
}
