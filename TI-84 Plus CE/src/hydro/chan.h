/*
 * chan.h - Canales y medicion (v2.0): Venturi con manometro, salto
 * hidraulico en canal rectangular y chorro. C puro, todo en SI.
 */
#ifndef CHAN_H
#define CHAN_H

#include "hydro.h"

/* Convencion del manometro diferencial */
enum { MANO_PHYS = 0,   /* dp = (S - 1) gamma h  (fisico)            */
       MANO_EXAM };     /* dp = S gamma h        (solucion 2025)      */

typedef struct {
    real A1, A2, v1, v2, beta, dp, h;   /* h = 0 si S <= 0              */
} chan_venturi_res;
/* D1, D2 (m), Q (m3/s), Cv (1 ideal), S del liquido del manometro
 * (0 = sin manometro). dp = rho/2 (Q/(Cv A2))^2 (1 - beta^4). */
int chan_venturi(real D1, real D2, real Q, real Cv, real S,
                 unsigned char conv, const hydro_cfg *c,
                 chan_venturi_res *r);

typedef struct {
    real q, y1, y2, v1, v2, Fr1, Fr2, E1, E2, dE, P, eff;
} chan_jump_res;
/* Dado y1 (from_y2 = 0) o dado y2 (from_y2 = 1): el otro tirante */
int chan_jump(real Q, real b, real y, unsigned char from_y2,
              const hydro_cfg *c, chan_jump_res *r);

typedef struct {
    real vx, vy, hmax, R, t;
} chan_jet_res;
/* Chorro con velocidad v y angulo theta (grados) sobre la horizontal */
int chan_jet(real v, real theta, real g, chan_jet_res *r);

#endif
