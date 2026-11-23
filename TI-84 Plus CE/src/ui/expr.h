/*
 * expr.h - Evaluador de expresiones numericas de los campos (C puro).
 * Acepta: numeros (12, 0.5, .5, 1.5E-6), + - * / ^ ( ), signo unario y
 * multiplicacion implicita antes de un parentesis: 4(0.2) = 0,8.
 * Ejemplo del examen 2025: 0.5+1.0+4*1.10+10*0.30+3*0.3+3.0 = 12,8
 */
#ifndef EXPR_H
#define EXPR_H

#include "../hydro/hydro.h"

enum {
    EXPR_OK = 0,
    EXPR_EMPTY,      /* campo vacio                       */
    EXPR_SYNTAX,     /* error de sintaxis                 */
    EXPR_DIV0,       /* division entre cero               */
    EXPR_RANGE,      /* resultado no finito               */
    EXPR_DEPTH,      /* demasiados parentesis anidados    */
    EXPR_COUNT
};

int expr_eval(const char *s, real *out);
const char *expr_err_text(int e);

#endif
