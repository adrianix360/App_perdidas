/*
 * dragcat.h - Catalogo de coeficientes de arrastre (v2.0, prompt sec. 4.3).
 * Valores de partida de las tablas habituales (Cengel y Cimbala tablas
 * 11-1 y 11-2; White; Fox/Munson), Re > 1e4 y area frontal salvo nota.
 * El usuario puede poner un valor propio (Ajustes: cd_user).
 */
#ifndef DRAGCAT_H
#define DRAGCAT_H

#include <stdint.h>
#include "../app.h"

/* area de referencia */
enum { AR_CIRC = 0,   /* pi D^2/4          */
       AR_SQ,         /* D^2               */
       AR_LD,         /* L D (2D: por L)   */
       AR_BH,         /* b h               */
       AR_COUNT };

/* tablas por parametro */
enum { TB_NONE = 0, TBC_LD_PERP, TBC_LD_AX, TBC_BH, TBC_CONE };

typedef struct {
    const char *name;       /* <= 26 caracteres (lista)               */
    const char *orient;     /* <= 34: orientacion respecto al flujo    */
    real cd;                /* valor del catalogo                      */
    uint8_t area;           /* AR_*                                    */
    uint8_t kind;           /* DK_* (drag.h): reglas de aviso por Re   */
    uint8_t tab;            /* TBC_* o TB_NONE                         */
    real stokes;            /* C_D = stokes/Re si Re < 1 (0: no hay)   */
    const char *src;        /* fuente, <= 14                           */
    const char *note;       /* <= 2 lineas de 40, separadas por '|'   */
} drag_shape;

typedef struct {
    const char *param;      /* "L/D", "b/h", "angulo"                  */
    uint8_t n;
    const real *x, *y;
    real inf;               /* valor para parametro >= 1000 (0: no)   */
} drag_table;

extern const drag_shape drag_shapes[CAT_N];
extern const char *const area_txt[AR_COUNT];
const drag_table *dragcat_table(uint8_t tab);

/* C_D vigente de la figura i (propio si lo hay) */
real dragcat_cd(uint8_t i);
/* C_D por parametro de la tabla de la figura i: interpola y deja los
 * vecinos en *x0..*y1; *warn recibe DW_INTERP / DW_CLAMP. Si el
 * parametro es >= 1000 usa el valor "infinito" de la tabla. */
real dragcat_param(uint8_t i, real p, real *x0, real *y0, real *x1, real *y1,
                   unsigned int *warn);
/* Area de referencia con las dimensiones (D o L,D o b,h) */
real dragcat_area(uint8_t area, real a, real b);

#endif
