/*
 * lib.c - Datos de la biblioteca (memoria tecnica, sec. 8). Cada dato dice
 * de donde sale: (curso) Perdidas-01.pdf, (C) Cengel, (std) tabla estandar
 * de agua a presion atmosferica (no viene de los PDF del curso).
 */
#include "data.h"

/* 8.1 rugosidad ks (mm) y 8.2 coeficiente C_H; -1 / 0 = no disponible */
const material materials[MATERIALS] = {
    { "PVC y CPVC",          0.0015, 150 },
    { "PEAD (polietileno)",  0.007,  150 },
    { "Vidrio",              0.0003, 0 },
    { "Asbesto cemento",     0.03,   140 },
    { "Fibra vidrio (GRP)",  0.03,   150 },
    { "Acero comercial",     0.045,  0 },
    { "Concreto centrifug.", 0.12,   0 },
    { "H. fundido asfalt.",  0.12,   0 },
    { "Hierro fundido",      0.15,   130 },
    { "Hierro galvanizado",  0.15,   120 },
    { "Arcilla vitrificada", 0.15,   100 },
    { "Hierro ductil",       0.25,   140 },
    { "Concreto",            0.30,   0 },
    { "Acero liso (C_H)",    -1,     130 },
    { "Acero soldado (C_H)", -1,     120 },
    { "Acero bridas (C_H)",  -1,     110 },
    { "Concreto liso (C_H)", -1,     140 },
    { "Concreto rug. (C_H)", -1,     120 },
    { "Cobre/laton (C)",     0.0015, 0 },
    { "Acero inox. (C)",     0.002,  0 },
    { "Hule alisado (C)",    0.01,   0 },
    { "Hierro forjado (C)",  0.046,  0 },
    { "Hierro fundido (C)",  0.26,   0 },
    { "Duela de madera (C)", 0.5,    0 },
};

/* 8.3 coeficientes K de accesorios */
const fitting fittings[FITTINGS] = {
    { "Entrada borde recto",  0.5 },
    { "Entrada redondeada",   0.2 },
    { "Entrada saliente",     0.8 },
    { "Entrada muy redond.",  0.04 },
    { "Salida a tanque",      1.0 },
    { "Codo 90 embridado",    0.3 },
    { "Codo 90 roscado",      0.9 },
    { "Codo 90 esquina",      1.1 },
    { "Codo 90 esq. alabes",  0.2 },
    { "Codo 45 roscado",      0.4 },
    { "Retorno 180 embrid.",  0.2 },
    { "Retorno 180 roscado",  1.5 },
    { "Te deriv. embridada",  1.0 },
    { "Te deriv. roscada",    2.0 },
    { "Te linea embridada",   0.2 },
    { "Te linea roscada",     0.9 },
    { "Union roscada",        0.08 },
    { "V. globo abierta (C)", 10 },
    { "V. angulo abierta",    5 },
    { "V. bola abierta",      0.05 },
    { "V. charnela",          2 },
    { "V. compuerta (C)",     0.2 },
    { "V. compuerta 1/4 c.",  0.3 },
    { "V. compuerta 1/2 c.",  2.1 },
    { "V. compuerta 3/4 c.",  17 },
    { "V. check (curso)",     0.8 },
    { "V. compuerta (curso)", 0.15 },
    { "V. mariposa (curso)",  0.2 },
    { "V. globo (curso)",     4.0 },
    { "V. esferica (curso)",  0.2 },
};

/* 8.4 conjuntos de K de los ejercicios del curso */
static const preset_item pr_pvc[] = {
    { "Entrada borde recto", 1, 0.5 }, { "V. compuerta", 3, 0.15 },
    { "Uniones", 167, 0.01 }, { "Codo 45", 12, 0.18 }, { "Codo 90", 6, 0.32 } };
static const preset_item pr_2025[] = {
    { "Entrada", 1, 0.5 }, { "Salida", 1, 1.0 }, { "Codo 90", 4, 1.10 },
    { "Codo 45", 10, 0.30 }, { "V. compuerta", 3, 0.3 }, { "V. de boya", 1, 3.0 } };
static const preset_item pr_2019[] = {
    { "Filtro", 1, 8.0 }, { "Codo 90", 4, 0.5 }, { "Valvula D", 1, 1.0 },
    { "Te", 1, 0.7 }, { "Cruz", 1, 0.7 }, { "Fluviometro", 1, 6.0 },
    { "Valvula L", 1, 3.0 } };
static const preset_item pr_2017[] = {
    { "Codo 90", 3, 0.2 }, { "Codo 45", 2, 0.1 }, { "Retencion c/rejilla", 1, 2.0 } };
static const preset_item pr_2018a[] = {
    { "Entrada", 1, 0.8 }, { "V. mariposa 30 grad", 1, 10 } };
static const preset_item pr_2018b[] = {
    { "Entrada borde recto", 1, 0.5 }, { "V. mariposa abierta", 1, 0.2 } };

const k_preset k_presets[K_PRESETS] = {
    { "PVC 200 mm (pag. 51)", 5, pr_pvc },
    { "Examen 2025 P1", 6, pr_2025 },
    { "Examen 2019 P4", 7, pr_2019 },
    { "Examen 2017 P4", 3, pr_2017 },
    { "Examen 2018 P1a", 2, pr_2018a },
    { "Examen 2018 P1b", 2, pr_2018b },
};

/* 8.5 agua a presion atmosferica (std) y viscosidades usadas en el curso */
const water waters[WATERS] = {
    { "Agua  5 C (std)",  5, 1000.0, 1.519e-6, 872 },
    { "Agua 10 C (std)", 10, 999.7, 1.307e-6, 1228 },
    { "Agua 15 C (std)", 15, 999.1, 1.139e-6, 1706 },
    { "Agua 20 C (std)", 20, 998.2, 1.004e-6, 2339 },
    { "Agua 25 C (std)", 25, 997.0, 0.893e-6, 3169 },
    { "Agua 30 C (std)", 30, 995.7, 0.801e-6, 4246 },
    { "Agua 40 C (std)", 40, 992.2, 0.658e-6, 7384 },
    { "Curso: 2025, T4",  0, 0, 1.0e-6, 0 },
    { "Curso: 2017-2019", 0, 0, 1.007e-6, 0 },
    { "Curso: 2024 P1",   0, 0, 1.02e-6, 0 },
    { "Curso: ej. 4",     0, 0, 1.14e-6, 0 },
    { "Curso: hojas",     0, 0, 1.17e-6, 0 },
};
