/*
 * memo_run.h - Interprete de los programas de PERDTXT (memoria de calculo,
 * resumenes y ayuda), compartido por todas las pantallas (v2.0: antes
 * vivia dentro de scr_pipe.c).
 *
 * Cada pantalla llena memo_V[] y memo_FL (banderas G_*), apunta memo_cfg
 * a la configuracion usada y, si hay tabla de iteraciones, memo_log; luego
 * llama memo_show(prog).
 */
#ifndef MEMO_RUN_H
#define MEMO_RUN_H

#include <stdint.h>
#include <stdbool.h>
#include "hydro/hydro.h"
#include "memo_defs.h"

extern real memo_V[V_COUNT];
extern uint32_t memo_FL;
extern unsigned int memo_W;          /* advertencias de M_WARN           */
extern const hydro_cfg *memo_cfg;    /* metodo ({METHOD}) y avisos       */
extern const hydro_log *memo_log;    /* tablas de iteraciones            */
extern hydro_log memo_lg;            /* registro comun de las pantallas  */
extern const real *memo_dlist;       /* lista de diametros (m), M_DLIST  */
extern uint8_t memo_dlist_n;

#define MSETF(g, cond) do { if (cond) memo_FL |= (uint32_t)1 << (g); } while (0)

/* Limpia memo_V, memo_FL y memo_W */
void memo_reset(void);

/* Abre PERDTXT; false si falta o es de otra version */
bool memo_tx_open(void);

/* Ejecuta el programa prog en el visor (sin view_clear) */
void memo_run_prog(uint8_t prog);

/* view_clear + programa; si falta PERDTXT, deja un aviso en el visor */
void memo_show(uint8_t prog);

#endif
