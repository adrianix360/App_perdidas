/*
 * app.h - Estado global de la app PERDIDAS
 */
#ifndef APP_H
#define APP_H

#include <stdint.h>
#include <stdbool.h>
#include "hydro/hydro.h"

#ifdef PROG_FLUJOS
#define APP_NAME    "FLUJOS"     /* v2.0: segundo programa (flujos/makefile) */
#else
#define APP_NAME    "PERDIDAS"
#endif
#define APP_VERSION "2.0"
#define CFG_APPVAR  "PERDCFG"
#define TX_APPVAR   "PERDTXT"
#define CASES_APPVAR "PERDCAS"
#define DEC_MAX     9

/* Formato 1.0 de PERDCFG (se sigue leyendo y se migra) */
typedef struct {
    hydro_cfg h;
    uint8_t dec;
} app_settings_v1;

#define CAT_N 17          /* figuras del catalogo de C_D (data/dragcat.c) */

typedef struct {
    hydro_cfg h;          /* metodo de f, g, gamma, nu, tolerancias...  */
    uint8_t dec;          /* decimales en pantalla (6 por defecto)      */
    /* v2.0 */
    real rho_air;         /* kg/m3 (1,2 del curso)                      */
    real nu_air;          /* m2/s (1,5e-5)                              */
    real cd_weir;         /* C_d por defecto de vertedores y orificios  */
    real knot;            /* km/h por nudo (1,85 del examen 2017)       */
    uint8_t mano;         /* convencion del manometro: MANO_*           */
    uint8_t buoy;         /* aplicar empuje con aire en AR-2            */
    real cd_user[CAT_N];  /* C_D propio de cada figura (0 = catalogo)   */
} app_settings;

extern app_settings g_set;
extern bool g_set_dirty;  /* hay que guardar al salir                  */

/* store.c */
void settings_default(app_settings *s);
bool settings_valid(const app_settings *s);
uint8_t settings_load(void);   /* 0 ok, 1 no existia, 2 danado          */
bool settings_save(void);

/* screens.c */
void scr_main(void);
void scr_settings(void);
void scr_about(void);
extern const char *const method_names[FM_COUNT];

/* scr_pipe.c: tuberia simple. tipo: 0 A, 1 B, 2 D, 3 C, 4 F, 5 E, 6 I
 * (mismo orden que el menu) */
enum { PT_A = 0, PT_B, PT_D, PT_C, PT_F, PT_E, PT_I, PT_COUNT };
void scr_pipe(uint8_t tipo);
void pipe_load_example(uint8_t tipo, const real *v, uint8_t n);
bool help_topic(uint8_t i);

/* cases.c: casos guardados (AppVar PERDCAS) */
#define CASES_MAX 20
#define CASE_NAME 8
extern bool cases_dirty;
uint8_t cases_load(void);      /* 0 ok, 1 no existe, 2 danado */
bool cases_write(void);
bool cases_archive(void);
uint8_t cases_count(void);
void case_save_ui(uint8_t tipo);
void scr_cases(void);

/* scr_net.c: sistemas serie/paralelo */
void scr_net(void);
void scr_net_example(uint8_t idx);

/* scr_fric.c (v2.0): Calcular f. dest/dset: campo "f dado" del
 * formulario que la abrio ([USAR f]); NULL desde el menu principal */
void scr_fric(real *dest, uint8_t *dset);

/* scr_cat.c (v2.0): catalogo de C_D. use = 1: selector con [USAR];
 * devuelve la figura elegida (C_D en cat_sel_cd) o -1 */
int scr_cat(uint8_t use);
extern real cat_sel_cd, cat_sel_param;

/* flujos.c (v2.0): menu principal del programa FLUJOS */
void flujos_main(void);

/* scr_drag.c (v2.0): arrastre y sustentacion. 0 AR-1, 1 AR-2, 2 AR-3,
 * 3 AR-4, 4 placa plana y Stokes */
void scr_drag(uint8_t t);

/* scr_lib.c: biblioteca */
bool lib_pick_material(void);
bool lib_sumador(void);
bool lib_pick_fluid(uint8_t to_settings);
void lib_diams(void);
void scr_library(void);

#endif
