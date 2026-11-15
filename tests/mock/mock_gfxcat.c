/* mock_gfxcat.c - ilustraciones del catalogo en el PC: valida coordenadas */
#include <stdio.h>
#include <stdlib.h>
#include "../../src/ui/gfxcat.h"
#include "../../src/app.h"

int gfx_draws, gfx_bad, gfx_missing;

bool gfxcat_open(void)
{
    return !gfx_missing;
}

void gfxcat_draw(uint8_t i, bool big, int x, uint8_t y, uint8_t s)
{
    int w = (big ? GFX_W : GFX_TW) * s, h = (big ? GFX_H : GFX_TH) * s;
    gfx_draws++;
    if (i >= CAT_N || x < 0 || x + w > 320 || y < 12 || y + h > 214 ||
        (s != 1 && s != 2))
        gfx_bad++;
}

void gfxcat_rect(int x, uint8_t y, int w, uint8_t h, uint8_t color)
{
    (void)color;
    if (x < 0 || x + w > 320 || y < 12 || y + h > 214)
        gfx_bad++;
}
