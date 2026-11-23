/*
 * test_ui_pure.c - Pruebas del PC para el evaluador de expresiones y el
 * formato de numeros (las partes de la interfaz que son C puro).
 */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "../src/ui/expr.h"
#include "../src/ui/numfmt.h"

static int fails, total;

static void ev(const char *s, double expect, int err_expect)
{
    real v = 0;
    int e = expr_eval(s, &v);
    int ok = (e == err_expect) &&
             (e != EXPR_OK || fabs((double)v - expect) <= 1e-6 * (fabs(expect) + 1e-30));
    total++;
    if (!ok) {
        fails++;
        printf("FALLA expr \"%s\": err %d (esp. %d) valor %.9g (esp. %.9g)\n",
               s, e, err_expect, (double)v, expect);
    }
}

static void fm(double x, int dec, const char *expect)
{
    char b[NUMFMT_LEN];
    fmt_real((real)x, (unsigned char)dec, b);
    total++;
    if (strcmp(b, expect)) {
        fails++;
        printf("FALLA fmt %.10g dec %d: \"%s\" (esp. \"%s\")\n", x, dec, b, expect);
    }
}

int main(void)
{
    /* Evaluador */
    ev("0.5+1.0+4*1.10+10*0.30+3*0.3+3.0", 12.8, EXPR_OK);  /* examen 2025 */
    ev("0.5+3*0.15+167*0.01+12*0.18+6*0.32", 6.7, EXPR_OK); /* PVC 200 mm */
    ev("8.0+1.0+0.7+1.0+0.7+6.0+1.0+3.0", 21.4, EXPR_OK);   /* 2019 P4 */
    ev("1.5E-6", 1.5e-6, EXPR_OK);
    ev("1.007E-6", 1.007e-6, EXPR_OK);
    ev("2E3", 2000, EXPR_OK);
    ev("2E+3", 2000, EXPR_OK);
    ev(".5", 0.5, EXPR_OK);
    ev("-3+5", 2, EXPR_OK);
    ev("--3", 3, EXPR_OK);
    ev("2^3^2", 512, EXPR_OK);
    ev("-2^2", -4, EXPR_OK);
    ev("4(0.2)", 0.8, EXPR_OK);
    ev("(1+2)(3+4)", 21, EXPR_OK);
    ev("10/4", 2.5, EXPR_OK);
    ev("1252-1193", 59, EXPR_OK);
    ev(" 3 * ( 2 + 1 ) ", 9, EXPR_OK);
    ev("", 0, EXPR_EMPTY);
    ev("   ", 0, EXPR_EMPTY);
    ev("3+", 0, EXPR_SYNTAX);
    ev("(3+2", 0, EXPR_SYNTAX);
    ev("3+2)", 0, EXPR_SYNTAX);
    ev("1/0", 0, EXPR_DIV0);
    ev("1/(2-2)", 0, EXPR_DIV0);
    ev("0^-1", 0, EXPR_DIV0);
    ev("1E", 0, EXPR_SYNTAX);
    ev(".", 0, EXPR_SYNTAX);
    ev("1..2", 0, EXPR_SYNTAX);
    ev("E5", 0, EXPR_SYNTAX);
    ev("((((((((((((((1))))))))))))))", 0, EXPR_DEPTH);
    ev("1E30*1E30", 1e60, sizeof(real) == 4 ? EXPR_RANGE : EXPR_OK);
    ev("--------------------1", 0, EXPR_DEPTH);

    /* Formato con 6 decimales y 7 cifras significativas */
    fm(17.969841, 6, "17.96984");
    fm(455180.6, 6, "455180.6");
    fm(0.01349, 6, "0.01349");
    fm(0.0261015, 6, "0.026102");
    fm(9.81, 6, "9.81");
    fm(9810, 6, "9810");
    fm(1.0e-6, 6, "1E-6");
    fm(1.5e-6, 6, "1.5E-6");
    fm(1.007e-6, 6, "1.007E-6");
    fm(2.5e7, 6, "2.5E7");
    fm(0, 6, "0");
    fm(-7.8, 6, "-7.8");
    fm(318.8, 1, "318.8");
    fm(2.376714, 3, "2.377");
    fm(99.99996, 4, "100");
    fm(0.5, 0, "1");
    fm(1234567, 6, "1234567");
    fm(9999999.6, 6, "1E7");
    fm(1.23456789e-5, 6, "1.23457E-5");
    fm(0.000123, 6, "0.000123");
    fm(0.00009999, 6, "9.999E-5");

    printf("%d de %d pruebas de la interfaz pura pasan (real = %s)\n",
           total - fails, total, sizeof(real) == 4 ? "float" : "double");
    return fails ? 1 : 0;
}
