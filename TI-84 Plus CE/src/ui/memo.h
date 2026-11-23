/*
 * memo.h - Memoria de calculo paso a paso (sec. 7.6 de la memoria tecnica):
 * Datos, Calculos (formula, sustitucion, resultado), Iteraciones,
 * Resultados y Observaciones. Escribe en el visor de lineas (widgets.h).
 * Formulas en ASCII lineal: pi, nu, gamma, eta, SumK, sqrt, ^2, log.
 */
#ifndef MEMO_H
#define MEMO_H

#include <stddef.h>
#include "../hydro/hydro.h"

void memo_begin(const char *title);
void memo_sec(const char *s);                 /* encabezado de seccion  */
void memo_line(const char *s, unsigned char color);   /* corta a 40 col */
void memo_data(const char *label, real v, const char *unit);
/* lhs = formula / = sustitucion / = resultado unidad */
void memo_eq(const char *lhs, const char *formula, const char *subst,
             real res, const char *unit);
/* Resultado destacado */
void memo_res(const char *label, real v, const char *unit);
/* Tabla de iteraciones: hasta 5 columnas; mult[k] multiplica la columna k
 * (por ejemplo 1000 para mostrar mm o l/s). La columna 0 es el numero. */
void memo_table(const char *const head[], unsigned char ncol,
                const hydro_log *lg, const real mult[]);
/* Advertencias del motor */
void memo_warn(unsigned int warn, const hydro_cfg *c);

/* Formato con %v (real con los decimales de Ajustes), %w (real corto, 5
 * cifras), %s (texto) y %d (entero). Devuelve buf. */
char *mfmt(char *buf, size_t n, const char *fmt, ...);
/* Real en a lo sumo `width` caracteres */
char *fmt_w(real x, unsigned char width, char *buf);

#endif
