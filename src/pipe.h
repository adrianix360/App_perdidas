/*
 * pipe.h - Datos del formulario de tuberia simple (compartidos con la
 * biblioteca y los casos guardados). Unidades de pantalla: Q l/s, D mm,
 * ks mm, L m, H m. Cada valor tiene su bandera "s..." (1 = tiene valor).
 */
#ifndef PIPE_H
#define PIPE_H

#include <stdint.h>
#include <stddef.h>
#include "hydro/hydro.h"

typedef struct {
    real Q, H, D, L, ks, K, nu, f, CH, eta, Hs, zb, Hp;
    real z1, z2, p1, p2;
    uint8_t sQ, sH, sD, sL, sks, sK, snu, sf, sCH, seta, sHs, szb, sHp;
    uint8_t sz1, sz2, sp1, sp2;
    uint8_t mach, dset, valve, modeI;
    /* v2.1 (al final: los casos guardados mas cortos se completan con
     * ceros = sin C_H de arranque, metodo de siempre) */
    uint8_t sCH0, itm;      /* C_H de arranque dado; iteracion IT_*    */
    real CH0;               /* C_H de arranque (B y D)                 */
} pipe_inputs;
#define PIN_V20_SIZE offsetof(pipe_inputs, sCH0)

extern pipe_inputs pin;
void pin_sanitize(pipe_inputs *p);   /* cases.c */

/* Abre el formulario del tipo t; si autocalc, calcula y muestra el
 * resultado al entrar (para casos cargados) */
void scr_pipe_run(uint8_t t, uint8_t autocalc);

#endif
