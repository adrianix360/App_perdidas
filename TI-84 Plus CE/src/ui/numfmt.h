/*
 * numfmt.h - Formato de numeros para la pantalla (C puro, sin printf de
 * coma flotante). Muestra hasta `dec` decimales sin pasar de 7 cifras
 * significativas (limite real de un float de 32 bits) y quita los ceros
 * finales. Notacion cientifica (6 cifras) si |x| >= 1e7 o 0 < |x| < 1e-4.
 * Ejemplos con dec = 6: 17.969841 | 455180.6 | 0.01349 | 1.5E-6
 */
#ifndef NUMFMT_H
#define NUMFMT_H

#include "../hydro/hydro.h"

#define NUMFMT_LEN 20   /* tamano minimo del bufer */

char *fmt_real(real x, unsigned char dec, char *buf);
char *fmt_int(long v, char *buf);

#endif
