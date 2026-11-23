/*
 * dragcat.c - Ver dragcat.h. Valores sin verificar contra el libro del
 * curso (prompt v2, sec. 4.3): cada fila dice su fuente.
 */
#include "dragcat.h"
#include "../hydro/drag.h"

const char *const area_txt[AR_COUNT] = {
    "pi D^2/4", "D^2", "L D", "b h", "sqrt(2) D^2"
};

const drag_shape drag_shapes[CAT_N] = {
    { "Esfera lisa", "cualquier orientacion", 0.5, AR_CIRC, DK_SPHERE,
      TB_NONE, 24, "Cengel 11-2",
      "White 0.47. Crisis de arrastre: CD 0.2|si Re > 2E5 (Cengel turbulento)" },
    { "Hemisferio convexo", "domo hacia el flujo", 0.4, AR_CIRC, DK_GENERIC,
      TB_NONE, 0, "Cengel 11-2", "White 0.42" },
    { "Hemisferio plano", "cara plana hacia el flujo", 1.17, AR_CIRC,
      DK_GENERIC, TB_NONE, 0, "Cengel 11-2", "White 1.15" },
    { "Copa hemisferica hueca", "abierta hacia el flujo", 1.42, AR_CIRC,
      DK_GENERIC, TB_NONE, 0, "Fox/Munson",
      "Abierta hacia atras: CD 0.38" },
    { "Paracaidas", "abierto, D del dosel", 1.3, AR_CIRC, DK_GENERIC,
      TB_NONE, 0, "Cengel 11-2",
      "Copa hueca 1.42 (figura 4). La Tarea|4-2 P1 no da CD: el curso usa 1.3" },
    { "Disco delgado", "normal al flujo", 1.1, AR_CIRC, DK_GENERIC, TB_NONE,
      20.4, "Cengel 11-2",
      "White 1.17. Stokes: 20.4/Re normal,|13.6/Re paralelo al flujo" },
    { "Cono, punta al flujo", "angulo total 30 grados", 0.5, AR_CIRC,
      DK_GENERIC, TBC_CONE, 0, "Cengel 11-2",
      "Tabla por angulo total (White);|escriba el angulo en grados" },
    { "Cono, base al flujo", "base plana hacia el flujo", 1.15, AR_CIRC,
      DK_GENERIC, TB_NONE, 0, "White", "" },
    { "Cubo, cara al flujo", "una cara normal al flujo", 1.05, AR_SQ,
      DK_GENERIC, TB_NONE, 0, "Cengel 11-2", "White 1.07" },
    { "Cubo, arista al flujo", "girado 45 grados", 0.80, AR_SQ2, DK_GENERIC,
      TB_NONE, 0, "Cengel 11-2",
      "White 0.81. Area proyectada sqrt(2)D^2;|las tablas usan D^2 (escriba A)" },
    { "Cilindro finito perpend.", "eje normal al flujo", 0.9, AR_LD,
      DK_LONGCYL, TBC_LD_PERP, 0, "Cengel 11-2",
      "Tabla por L/D; L/D >= 1000: infinito|(1.2). Valor inicial: L/D = 10" },
    { "Cilindro, cara al flujo", "eje paralelo al flujo", 0.9, AR_CIRC,
      DK_GENERIC, TBC_LD_AX, 0, "Cengel 11-2", "Tabla por L/D" },
    { "Cuerpo aerodinamico", "forma de gota, punta atras", 0.04, AR_CIRC,
      DK_GENERIC, TB_NONE, 0, "Cengel 11-2", "" },
    { "Placa rectangular", "normal al flujo", 1.18, AR_BH, DK_GENERIC,
      TBC_BH, 0, "Fox/Munson",
      "Tabla por b/h; b/h >= 1000: 1.98.|Valor inicial: b/h = 1" },
    { "Cilindro largo (2D)", "eje normal, por metro", 1.2, AR_LD,
      DK_LONGCYL, TB_NONE, 0, "Cengel 11-1",
      "Re > 5E5 (turbulento): CD 0.3,|crisis de arrastre" },
    { "Barra cuadrada larga (2D)", "cara al flujo, esquinas vivas", 2.2,
      AR_LD, DK_GENERIC, TB_NONE, 0, "Cengel 11-1", "" },
    { "Placa plana larga (2D)", "normal al flujo, por metro", 1.9, AR_LD,
      DK_GENERIC, TB_NONE, 0, "Cengel 11-1", "Fox/Munson 1.98" },
};

static const real ldp_x[5] = { 1, 2, 5, 10, 40 };
static const real ldp_y[5] = { 0.6, 0.7, 0.8, 0.9, 1.0 };
static const real lda_x[5] = { 0.5, 1, 2, 4, 8 };
static const real lda_y[5] = { 1.1, 0.9, 0.9, 0.9, 1.0 };
static const real bh_x[4] = { 1, 5, 10, 20 };
static const real bh_y[4] = { 1.18, 1.2, 1.3, 1.5 };
static const real cone_x[7] = { 10, 20, 30, 40, 60, 75, 90 };
static const real cone_y[7] = { 0.30, 0.40, 0.55, 0.65, 0.80, 1.05, 1.15 };

static const drag_table tables[4] = {
    { "L/D", 5, ldp_x, ldp_y, 1.2 },
    { "L/D", 5, lda_x, lda_y, 0 },
    { "b/h", 4, bh_x, bh_y, 1.98 },
    { "angulo", 7, cone_x, cone_y, 0 },
};

const drag_table *dragcat_table(uint8_t tab)
{
    return (tab >= TBC_LD_PERP && tab <= TBC_CONE) ? &tables[tab - 1] : 0;
}

real dragcat_cd(uint8_t i)
{
    if (i >= CAT_N)
        return 0;
    return g_set.cd_user[i] > 0 ? g_set.cd_user[i] : drag_shapes[i].cd;
}

real dragcat_param(uint8_t i, real p, real *x0, real *y0, real *x1, real *y1,
                   unsigned int *warn)
{
    const drag_table *t = dragcat_table(i < CAT_N ? drag_shapes[i].tab : 0);
    unsigned char k;
    real v;
    if (!t)
        return dragcat_cd(i);
    if (t->inf > 0 && p >= 1000) {
        *x0 = *x1 = p;
        *y0 = *y1 = t->inf;
        return t->inf;
    }
    v = drag_interp(t->x, t->y, t->n, p, &k, warn);
    *x0 = t->x[k];
    *y0 = t->y[k];
    *x1 = t->x[k + 1];
    *y1 = t->y[k + 1];
    return v;
}

real dragcat_area(uint8_t area, real a, real b)
{
    switch (area) {
    case AR_CIRC: return hydro_area(a);
    case AR_SQ: return a * a;
    case AR_SQ2: return (real)1.41421356 * a * a;
    default: return a * b;
    }
}
