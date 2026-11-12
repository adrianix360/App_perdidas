/*
 * diams.c - Listas de diametros comerciales (internos, mm). Seccion 8.6 de
 * la memoria tecnica. La edicion de listas propias llega en la fase 4.
 */
#include "data.h"

static const real d_pvc25[] = { 53.21, 64.45, 78.44, 100.84, 148.46, 193.28,
                                240.95, 285.75, 358.64 };
static const real d_nom24[] = { 200, 250, 300, 350, 400, 450, 500 };
static const real d_prac3[] = { 150, 200, 250, 300, 350, 400 };
static const real d_prac2[] = { 50, 75, 100, 150, 300 };
static const real d_gen[] = { 50, 75, 100, 150, 200, 250, 300, 350, 400, 450,
                              500, 600, 700, 800, 900, 1000, 1200, 1500 };

const diam_set diam_sets[DIAM_SETS] = {
    { "PVC examen 2025", 9, d_pvc25 },
    { "Nominal 2024 200-500", 7, d_nom24 },
    { "Pract.3/Ej.5 150-400", 6, d_prac3 },
    { "Practica 2 50-300", 5, d_prac2 },
    { "General 50-1500", 18, d_gen },
};

const char *const diam_set_names[DIAM_SETS] = {
    "PVC examen 2025", "Nominal 2024 200-500", "Pract.3/Ej.5 150-400",
    "Practica 2 50-300", "General 50-1500",
};
