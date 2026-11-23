/*
 * drag.h - Arrastre y sustentacion (v2.0). C puro, todo en SI.
 * F = 1/2 rho C A V^2; velocidad terminal; estructuras con varios
 * cuerpos (fuerza y momento en la base); vuelo nivelado; Stokes; placa
 * plana; interpolacion de tablas de C_D.
 */
#ifndef DRAG_H
#define DRAG_H

#include "hydro.h"

/* Avisos de arrastre (mascara de bits) */
#define DW_RE_LOW   0x01u   /* Re < 1e4: fuera del rango de la tabla      */
#define DW_CRISIS   0x02u   /* posible crisis de arrastre                 */
#define DW_STOKES   0x04u   /* Re < 1: flujo lento (Stokes)               */
#define DW_INTERP   0x08u   /* C_D interpolado en una tabla               */
#define DW_CLAMP    0x10u   /* parametro fuera de la tabla: valor extremo */
#define DW_LAM_NA   0x20u   /* placa: Cf laminar no aplica (Re > 5e5)     */
#define DW_TURB_NA  0x40u   /* placa: Re > 1e7, fuera de 0,074/Re^0,2     */
#define DW_BUOY     0x80u   /* se considero el empuje                     */

/* Tipo de cuerpo para las reglas de aviso */
enum { DK_GENERIC = 0, DK_SPHERE, DK_LONGCYL };

real drag_q(real rho, real V);                       /* 1/2 rho V^2 */
real drag_force(real rho, real C, real A, real V);   /* 1/2 rho C A V^2 */
real drag_re(real V, real L, real nu);
/* Avisos segun Re y el tipo de cuerpo */
unsigned int drag_re_warn(real Re, unsigned char kind);

/* Interpolacion lineal en una tabla x creciente (n >= 2). Devuelve el
 * valor; *i0 = indice del vecino de abajo; marca DW_CLAMP si x queda
 * fuera (devuelve el extremo). */
real drag_interp(const real *x, const real *y, unsigned char n, real xv,
                 unsigned char *i0, unsigned int *warn);

/* AR-2: velocidad terminal. W peso (N), rho fluido, vol volumen del
 * cuerpo (0 = sin empuje), C_D, A area de referencia, Lref longitud
 * para Re, nu. */
typedef struct {
    real B, net, v, Re;
    unsigned int warn;
} drag_term_res;
int drag_terminal(real W, real rho, real vol, real Cd, real A, real Lref,
                  real nu, real g, unsigned char kind, drag_term_res *r);

/* AR-3: estructura con varios cuerpos */
#define DRAG_BODIES 6
typedef struct {
    real Cd, A, y, V, Lref;   /* y = cota del centro de presion        */
    unsigned char kind;
} drag_body;
typedef struct {
    real F[DRAG_BODIES], Re[DRAG_BODIES];
    unsigned int w[DRAG_BODIES];
    real Ftot, M, ycp;
    unsigned int warn;
} drag_struct_res;
int drag_struct(const drag_body *b, unsigned char n, real rho, real nu,
                drag_struct_res *r);

/* AR-4: vuelo nivelado */
real drag_rho_alt(real h);   /* 1,3 (1 - 2,26e-5 h)^4,256, h en m */
typedef struct {
    real q, Atot, CL;              /* paso 1                          */
    real Afus, Dw, Df, T, P;       /* paso 2 (con C_D leido)          */
    real Vst;                      /* velocidad de perdida (0: no)    */
} drag_plane_res;
/* Paso 1: q y C_L necesario. A_ala por ala, n alas */
int drag_plane_lift(real W, real rho, real V, real Aw, unsigned char nw,
                    drag_plane_res *r);
/* Paso 2: con C_D de las alas, C_D y diametro del fuselaje y C_Lmax
 * (0 = no se calcula la velocidad de perdida) */
int drag_plane_thrust(real W, real rho, real V, real CDw, real CDf,
                      real Df, real CLmax, drag_plane_res *r);

/* EX-4: Stokes (esfera) F = 3 pi mu V D */
real drag_stokes(real mu, real V, real D);
/* EX-4: placa plana. Cf laminar, turbulento y mixto segun Re_L.
 * mode: PL_AUTO (laminar si Re < 5e5, si no turbulento), PL_LAM,
 * PL_TURB, PL_MIX. */
enum { PL_AUTO = 0, PL_LAM, PL_TURB, PL_MIX };
typedef struct {
    real Re, Cf_lam, Cf_turb, Cf_mix, Cf;   /* Cf = el usado           */
    real A, F;                               /* A = L w por cara        */
    unsigned char regime;                    /* PL_LAM, PL_TURB, PL_MIX */
    unsigned int warn;
} drag_plate_res;
int drag_plate(real L, real w, real V, real rho, real nu,
               unsigned char faces, unsigned char mode, drag_plate_res *r);

#endif
