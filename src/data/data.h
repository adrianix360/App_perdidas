/*
 * data.h - Datos de la biblioteca (fase 3: diametros comerciales)
 */
#ifndef DATA_H
#define DATA_H

#include "../hydro/hydro.h"

#define DIAM_SETS 5

typedef struct {
    const char *name;
    unsigned char n;
    const real *mm;
} diam_set;

extern const diam_set diam_sets[DIAM_SETS];
extern const char *const diam_set_names[DIAM_SETS];

#endif
