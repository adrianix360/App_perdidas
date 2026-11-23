/*
 * numfmt.c - Ver numfmt.h
 */
#include "numfmt.h"

#define SIG_MAX 7

char *fmt_int(long v, char *buf)
{
    char tmp[12];
    int n = 0, i = 0;
    unsigned long u;
    if (v < 0) {
        buf[i++] = '-';
        u = (unsigned long)(-v);
    } else {
        u = (unsigned long)v;
    }
    do {
        tmp[n++] = (char)('0' + u % 10);
        u /= 10;
    } while (u && n < 11);
    while (n)
        buf[i++] = tmp[--n];
    buf[i] = 0;
    return buf;
}

/* Escribe u con `nd` decimales implicitos y quita ceros finales */
static int put_scaled(unsigned long u, int nd, char *b)
{
    char tmp[12];
    int n = 0, i = 0, k;
    do {
        tmp[n++] = (char)('0' + u % 10);
        u /= 10;
    } while (u && n < 11);
    while (n <= nd)                 /* ceros a la izquierda: 0.00123 */
        tmp[n++] = '0';
    for (k = n - 1; k >= nd; k--)
        b[i++] = tmp[k];
    if (nd > 0) {
        int last = 0;
        while (last < nd && tmp[last] == '0')
            last++;
        if (last < nd) {
            b[i++] = '.';
            for (k = nd - 1; k >= last; k--)
                b[i++] = tmp[k];
        }
    }
    b[i] = 0;
    return i;
}

static real p10(int e)
{
    real r = 1;
    while (e > 0) { r *= 10; e--; }
    while (e < 0) { r /= 10; e++; }
    return r;
}

char *fmt_real(real x, unsigned char dec, char *buf)
{
    char *b = buf;
    real a;
    int e, nd, intd;
    unsigned long u;

    if (!(x == x) || x - x != 0) {   /* NaN o infinito */
        buf[0] = 'E'; buf[1] = 'R'; buf[2] = 'R'; buf[3] = 0;
        return buf;
    }
    if (x < 0) {
        *b++ = '-';
        x = -x;
    }
    if (x == 0) {
        b[0] = '0';
        b[1] = 0;
        return buf;
    }
    a = x;
    if (a >= 1e7 || a < 1e-4) {
sci:
        /* cientifica: m.mmmmmE+ee con hasta min(dec, 5) decimales (6 cifras:
         * la normalizacion por potencias de 10 ya gasta la 7.a en float) */
        e = 0;
        while (a >= 10) { a /= 10; e++; }
        while (a < 1) { a *= 10; e--; }
        nd = dec < SIG_MAX - 2 ? dec : SIG_MAX - 2;
        u = (unsigned long)(a * p10(nd) + 0.5);
        if (u >= (unsigned long)p10(nd + 1)) {   /* 9.9999995 -> 10.0 */
            u /= 10;
            e++;
        }
        b += put_scaled(u, nd, b);
        *b++ = 'E';
        fmt_int(e, b);
        return buf;
    }
    intd = 1;
    while (intd < SIG_MAX && a >= p10(intd))
        intd++;
    nd = SIG_MAX - intd;
    if (nd > dec)
        nd = dec;
    if (a < 1) {                     /* 0.0xyz: cuenta los ceros */
        int z = 0;
        real t = a;
        while (t < 0.1 && z < 6) { t *= 10; z++; }
        nd = SIG_MAX + z;
        if (nd > dec)
            nd = dec;
    }
    u = (unsigned long)(a * p10(nd) + 0.5);
    if (nd == 0 && u >= 10000000UL) {   /* 9999999.6 -> 1E7 */
        a = x;
        goto sci;
    }
    put_scaled(u, nd, b);
    return buf;
}
