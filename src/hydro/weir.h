/*
 * weir.h - Vertedores y orificios (v2.0). C puro, todo en SI.
 * Cotas medidas desde un mismo nivel de referencia: z es el vertice
 * (triangular), la cresta (rectangular) o el CENTRO del orificio.
 */
#ifndef WEIR_H
#define WEIR_H

#include "hydro.h"

enum { WE_TRI = 0, WE_RECT, WE_ORC, WE_ORR, WE_COUNT };

/* Avisos */
#define VW_PARTIAL  0x01u   /* nivel bajo el borde superior de un orificio */
#define VW_DRY      0x02u   /* algun elemento no recibe agua (aporta 0)     */
#define VW_HIGH     0x04u   /* H mayor que la altura del vertedero          */
#define VW_FRANCIS  0x08u   /* se aplicaron contracciones laterales         */
#define VW_BE_NEG   0x10u   /* ancho efectivo <= 0 (Francis)                */

typedef struct {
    unsigned char type;   /* WE_*                                        */
    unsigned char count;  /* cantidad de elementos iguales (>= 1)        */
    unsigned char ncon;   /* contracciones laterales (rectangular, 0..2) */
    real Cd;
    real z;               /* cota del vertice, cresta o centro           */
    real a;               /* tri: angulo (grados); rect: b; orc: d;
                             orr: ancho b                                */
    real b;               /* orr: alto; rect/tri: altura del vertedero
                             (0 = sin limite)                            */
} weir_el;

#define WEIR_MAX 8

/* Caudal de un elemento (ya multiplicado por count) con el nivel h.
 * *H recibe la carga (h - z; 0 si no hay agua). */
real weir_q(const weir_el *e, real h, real g, real *H, unsigned int *warn);

/* Revisa los datos de un elemento: H_OK o H_ERR_ARG */
int weir_check(const weir_el *e);

/* Caudal total con el nivel h; Qi[i] por elemento (puede ser NULL) */
int weir_total(const weir_el *e, unsigned char n, real h, real g,
               real *Q, real *Qi, unsigned int *warn);

/* Nivel h que da el caudal total Q. Un solo vertedero sin Francis se
 * resuelve con la formula cerrada; si no, biseccion (la funcion es
 * monotona creciente). iters = vueltas de la biseccion (0 si cerrada). */
int weir_level(const weir_el *e, unsigned char n, real Q, real g,
               real *h, real *Qi, unsigned int *warn, int *iters);

/* VE-6: perfil de velocidades v = k y^n en un canal de ancho b y
 * tirante h: Q = b k h^(n+1) / (n+1) */
int weir_profile_pow(real k, real n, real b, real h, real *Q, real *vm);
/* VE-6: tabla de puntos (y, v) con y creciente. Simpson si los puntos
 * estan igualmente espaciados y son impares; si no, trapecios.
 * *simpson = 1 si se uso Simpson. */
int weir_profile_pts(const real *y, const real *v, unsigned char n, real b,
                     real *Q, real *vm, unsigned char *simpson);

/* VE-7: v = Q/(b h), E = h + v^2/2g */
int weir_section(real Q, real b, real h, real g, real *v, real *E);
/* VE-7: tirantes alternos con la energia especifica E y q = Q/b:
 * E = h + q^2/(2 g h^2). hc = (q^2/g)^(1/3), Emin = 1,5 hc.
 * Devuelve H_ERR_NOROOT si E < Emin (no hay flujo con esa energia). */
int weir_alt_depths(real q, real E, real g, real *hsub, real *hsup, real *hc);

#endif
