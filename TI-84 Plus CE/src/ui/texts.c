/*
 * texts.c - Ver texts.h. Mensajes cortos en espanol (ASCII, sin tildes:
 * la fuente de graphx no tiene caracteres acentuados).
 */
#include <string.h>
#include "texts.h"
#include "numfmt.h"

static void cat2(char *d, const char *a, const char *b, const char *c)
{
    size_t n;
    strncpy(d, a, 40);
    d[40] = 0;
    n = strlen(d);
    if (b && n < 40) { strncpy(d + n, b, 40 - n); d[40] = 0; }
    n = strlen(d);
    if (c && n < 40) { strncpy(d + n, c, 40 - n); d[40] = 0; }
}

unsigned char warn_texts(unsigned int warn, const hydro_cfg *c,
                         unsigned char dec, char (*out)[41],
                         unsigned char max)
{
    unsigned char n = 0;
    char num[NUMFMT_LEN];
    (void)dec;

#define ADD(a, b, cc) do { if (n < max) cat2(out[n++], a, b, cc); } while (0)
    if (warn & W_FALLBACK)
        ADD("! Iteracion del curso no convergio:", 0, 0);
    if (warn & W_FALLBACK)
        ADD("  se resolvio por biseccion", 0, 0);
    if (warn & W_LAMINAR)
        ADD("! Re < ", fmt_real(c->re_lam, 0, num), ": laminar, f = 64/Re");
    if (warn & W_TRANSITION)
        ADD("! Re en transicion: resultado indicativo", 0, 0);
    if (warn & W_KSD_RANGE)
        ADD("! ks/D > 0.05: fuera de Colebrook-White", 0, 0);
    if (warn & W_SJ_RANGE)
        ADD("! Fuera del rango de Swamee-Jain", 0, 0);
    if (warn & W_V_HIGH)
        ADD("! v > ", fmt_real(c->v_max, 2, num), " m/s: velocidad alta");
    if (warn & W_V_LOW)
        ADD("! v < ", fmt_real(c->v_min, 2, num), " m/s: velocidad baja");
    if (warn & W_HM_HIGH)
        ADD("! hm > ", fmt_real(100 * c->hm_ratio, 0, num),
            "% hf: perdidas locales altas");
    if (warn & W_LOCAL_SMALL)
        ADD("! L/D > ", fmt_real(c->ld_limit, 0, num),
            ": locales despreciables");
    if (warn & W_P_NEG)
        ADD("! Presion manometrica negativa", 0, 0);
    if (warn & W_CAVIT)
        ADD("! p/gamma < -10.3 m: imposible", 0, 0);
    if (warn & W_KS_NEG)
        ADD("! ks negativo: datos inconsistentes", 0, 0);
#undef ADD
    return n;
}
