/*
 * graph.h - Grafica de la linea de energia (LE) y la linea piezometrica
 * (LP) a lo largo de una conduccion (memoria tecnica 5.11, 6.8 y 7.7).
 * Esquema sin escala horizontal exacta: cada tramo ocupa un ancho
 * proporcional a su longitud (con un minimo para que se vea).
 */
#ifndef GRAPH_H
#define GRAPH_H

#include <stdint.h>
#include "../hydro/hydro.h"

#define GSEG_MAX 10

typedef struct {
    real L;        /* longitud del tramo (m)                          */
    real jump;     /* salto al inicio: + bomba, - turbina o valvula   */
    real hloc;     /* perdida local al inicio del tramo (m)           */
    real hfr;      /* perdida por friccion a lo largo del tramo (m)   */
    real vh;       /* v^2/2g del tramo (m)                            */
    char name[4];  /* rotulo del tramo                                */
} gseg;

/* E0: energia en el tanque de salida (m). Eend: nivel del tanque de
 * llegada (m) si tank2; si no, la conduccion termina en un punto. */
void graph_run(const char *title, real E0, const gseg *s, uint8_t n,
               real Eend, uint8_t tank2);

#endif
