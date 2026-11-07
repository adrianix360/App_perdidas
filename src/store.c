/*
 * store.c - Ajustes en el AppVar archivado PERDCFG.
 * Formato: "PRD" + version + tamano + app_settings + suma de control.
 * Si el AppVar no existe, esta danado o trae valores absurdos, se usan
 * los valores por defecto (el programa nunca confia en lo que lee).
 */
#include <fileioc.h>
#include <string.h>
#include "app.h"

#define CFG_VER 1

app_settings g_set;
bool g_set_dirty = false;

void settings_default(app_settings *s)
{
    hydro_cfg_default(&s->h);
    s->dec = 6;
}

static uint8_t checksum(const uint8_t *p, size_t n)
{
    uint8_t c = 0x5A;
    while (n--)
        c = (uint8_t)((c << 1 | c >> 7) ^ *p++);
    return c;
}

static bool in(real x, real lo, real hi)
{
    return x >= lo && x <= hi;   /* falso con NaN */
}

bool settings_valid(const app_settings *s)
{
    const hydro_cfg *h = &s->h;
    return in(h->g, 1, 20) && in(h->gamma, 1000, 20000) &&
           in(h->nu, 1e-8, 1e-3) && in(h->tol, 1e-9, 1) &&
           in(h->re_lam, 100, 10000) && in(h->re_turb, h->re_lam, 100000) &&
           in(h->ld_limit, 1, 1e6) && in(h->v_min, 0, 100) &&
           in(h->v_max, h->v_min, 100) && in(h->pv, 0, 101325) &&
           in(h->hm_ratio, 0, 100) && h->method < FM_COUNT &&
           h->max_iter >= 10 && s->dec <= DEC_MAX;
}

uint8_t settings_load(void)
{
    uint8_t f, hdr[5], ck;
    app_settings tmp;

    settings_default(&g_set);
    f = ti_Open(CFG_APPVAR, "r");
    if (!f)
        return 1;
    if (ti_Read(hdr, 5, 1, f) != 1 || memcmp(hdr, "PRD", 3) ||
        hdr[3] != CFG_VER || hdr[4] != (uint8_t)sizeof(app_settings) ||
        ti_Read(&tmp, sizeof tmp, 1, f) != 1 || ti_Read(&ck, 1, 1, f) != 1 ||
        ck != checksum((const uint8_t *)&tmp, sizeof tmp) ||
        !settings_valid(&tmp)) {
        ti_Close(f);
        return 2;
    }
    ti_Close(f);
    g_set = tmp;
    return 0;
}

bool settings_save(void)
{
    uint8_t f, hdr[5] = { 'P', 'R', 'D', CFG_VER, (uint8_t)sizeof(app_settings) };
    uint8_t ck = checksum((const uint8_t *)&g_set, sizeof g_set);
    bool ok;

    f = ti_Open(CFG_APPVAR, "w");
    if (!f)
        return false;
    ok = ti_Write(hdr, 5, 1, f) == 1 &&
         ti_Write(&g_set, sizeof g_set, 1, f) == 1 &&
         ti_Write(&ck, 1, 1, f) == 1;
    if (ok)
        ti_SetArchiveStatus(true, f);   /* sobrevive a un reinicio de RAM */
    ti_Close(f);
    if (ok)
        g_set_dirty = false;
    return ok;
}
