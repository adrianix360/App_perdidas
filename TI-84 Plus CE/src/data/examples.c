/*
 * examples.c - Casos del curso para cargar desde la Ayuda (memoria 7.9).
 * Los valores van en el orden de los campos del formulario de cada tipo;
 * EX_NONE deja el campo vacio. Datos de la seccion 9 de la memoria
 * tecnica, con las correcciones de los PDF (INFORME_PRUEBAS.md).
 */
#include "data.h"
#include "../app.h"

#define N EX_NONE

/* A: Q, D, L, ks, SumK, nu, f, H sobre punto, metodo */
static const real e_p02[] = { 72, 200, 1000, 0.0015, 6.7, 1.007e-6, N, 53, FM_SJ };
/* I: modo, Q, H, D, L, ks, SumK, nu, C_H, metodo */
static const real e_p01[] = { 0, 72, N, 200, 1000, 0.0015, 0, 1.007e-6, 150, FM_SJ };
static const real e_p10[] = { 1, N, 100, 300, 4500, 0.045, 5, 1e-6, 130, FM_CW };
/* B: H, D, L, ks, SumK, nu, f, metodo, C_H arranque, iteracion */
static const real e_p03[] = { 43.5, 293, 700, 0.0015, 11.5, 1e-6, N, FM_CW, N, 0 };
static const real e_p05[] = { 80, 1050, 23778, 0.046, 7, 1e-6, N, FM_CW, N, 0 };
static const real e_p07[] = { 5, 50, 2.06, 0.045, 10.8, 1.007e-6, N, FM_CW, N, 0 };
static const real e_p09[] = { 100, 300, 4500, 0.045, 5, 1e-6, N, FM_CW, N, 0 };
static const real e_p27[] = { 8, 400, 500, 0.0015, 5, 1e-6, N, FM_CW, 150, 1 };
/* C: equipo, Q, D, L, ks, SumK, nu, Hs, eta, f, cota, metodo */
static const real e_p11[] = { 0, 42, 150, 970, 0.0015, 9.4, 1.14e-6, 16, 0.65, N, N, FM_CW };
static const real e_p12[] = { 0, 75, 200, 1000, 0, 0, 1e-6, 102, 0.85, 0.014, N, FM_CW };
static const real e_p19[] = { 1, 200, 285.75, 1900, 0.0015, 12.8, 1e-6, 76, 0.65, N, N, FM_CW };
static const real e_p20[] = { 0, 200, 285.75, 1900, 0.0015, 12.8, 1e-6, 76, 0.60, N, 1015, FM_CW };
/* D: Qd, H, L, ks, SumK, nu, lista, valvula, metodo, C_H arranque,
 * iteracion */
static const real e_p15[] = { 200, 8, 450, 0.25, 2.5, 1.17e-6, 2, 0, FM_CW, N, 0 };
static const real e_p17[] = { 200, 76, 1900, 0.0015, 12.8, 1e-6, 0, 1, FM_CW, N, 0 };
static const real e_p21[] = { 400, 8, 600, 0.0015, 5, 1.02e-6, 1, 0, FM_CW, N, 0 };
static const real e_p26[] = { 305, 8, 500, 0.0015, 5, 1e-6, 1, 0, FM_CW, 150, 1 };
/* F: Q, D, L, ks, SumK, nu, H, f, metodo */
static const real e_p18[] = { 200, 285.75, 1900, 0.0015, 12.8, 1e-6, 76, N, FM_CW };
/* E: z1, z2, p1, p2, L, D, Q, SumK, nu */
static const real e_p25[] = { 1135, 1070, 36, 84, 405, 274, 172, 3.5, 1.17e-6 };

#define EX(n, t, v) { n, t, v, sizeof v / sizeof v[0] }
const example examples[EXAMPLES] = {
    EX("P-02 PVC 200 mm, p (A)",      PT_A, e_p02),
    EX("P-01 DW vs HW, PVC (I)",      PT_I, e_p01),
    EX("P-03 Pres. ejemplo 1 (B)",    PT_B, e_p03),
    EX("P-05 Pres. practica 1 (B)",   PT_B, e_p05),
    EX("P-07 Examen 2018 P1a (B)",    PT_B, e_p07),
    EX("P-09 Tarea 4 P3a (B)",        PT_B, e_p09),
    EX("P-10 Tarea 4 P3b (I)",        PT_I, e_p10),
    EX("P-11 Pres. ejemplo 4 (C)",    PT_C, e_p11),
    EX("P-12 Examen 2024 P2 (C)",     PT_C, e_p12),
    EX("P-15 Pres. ejemplo 5 (D)",    PT_D, e_p15),
    EX("P-17 Examen 2025 P1 (D)",     PT_D, e_p17),
    EX("P-18 Examen 2025 P2 (F)",     PT_F, e_p18),
    EX("P-19 Examen 2025 P3a (C)",    PT_C, e_p19),
    EX("P-20 Examen 2025 P3b (C)",    PT_C, e_p20),
    EX("P-21 Examen 2024 P1 (D)",     PT_D, e_p21),
    EX("P-25 Pres. ejemplo 6 (E)",    PT_E, e_p25),
    EX("P-26 Ejercicio 2, HW (D)",    PT_D, e_p26),
    EX("P-27 Ejercicio 2, HW (B)",    PT_B, e_p27),
    { "S-01 Examen 2024 P3 (G)", PT_COUNT, 0, 0 },
    { "S-02 Examen 2025 P5 (G)", PT_COUNT, 0, 1 },
    { "S-03 Examen 2018 P3 (G)", PT_COUNT, 0, 2 },
    { "S-04 Examen 2017 P5 (G)", PT_COUNT, 0, 3 },
    { "S-05 Tarea 4 P4 (G)",     PT_COUNT, 0, 4 },
};
