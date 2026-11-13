/*
 * data.h - Datos de la biblioteca: diametros comerciales, materiales,
 * accesorios, conjuntos de K del curso y propiedades del agua.
 */
#ifndef DATA_H
#define DATA_H

#include "../hydro/hydro.h"

/* ---- diametros comerciales (diams.c) ---- */
#define DIAM_SETS 5          /* listas fijas                         */
#define DIAM_CUSTOM DIAM_SETS /* indice de la lista propia            */
#define DIAM_CHOICES (DIAM_SETS + 1)
#define DIAM_CUSTOM_MAX 15

typedef struct {
    const char *name;
    unsigned char n;
    const real *mm;
} diam_set;

extern const diam_set diam_sets[DIAM_SETS];
extern const char *const diam_set_names[DIAM_CHOICES];
extern real diam_custom[DIAM_CUSTOM_MAX];   /* mm; 0 = vacio (en PERDCAS) */

/* ---- materiales (lib.c) ---- */
#define MATERIALS 24
typedef struct {
    const char *name;
    real ks_mm;      /* < 0: no aplica */
    real ch;         /* 0: no aplica   */
} material;
extern const material materials[MATERIALS];

/* ---- accesorios ---- */
#define FITTINGS 30
typedef struct {
    const char *name;
    real K;
} fitting;
extern const fitting fittings[FITTINGS];

typedef struct {
    const char *name;
    unsigned int qty;
    real K;
} preset_item;
#define K_PRESETS 6
typedef struct {
    const char *name;
    unsigned char n;
    const preset_item *items;
} k_preset;
extern const k_preset k_presets[K_PRESETS];

/* ---- agua ---- */
#define WATERS 12
typedef struct {
    const char *name;
    real T;          /* C; 0 = valor del curso sin temperatura */
    real rho;        /* kg/m3; 0 = no aplica */
    real nu;         /* m2/s */
    real pv;         /* Pa; 0 = no aplica */
} water;
extern const water waters[WATERS];

/* ---- casos del curso (examples.c) ---- */
#define EX_NONE ((real)-1e30)      /* campo vacio */
#define EXAMPLES 21
typedef struct {
    const char *name;
    unsigned char tipo;            /* PT_*; PT_COUNT = sistema       */
    const real *vals;              /* en el orden del formulario     */
    unsigned char n;               /* n valores; sistema: su indice  */
} example;
extern const example examples[EXAMPLES];

#endif
