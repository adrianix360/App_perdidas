/*
 * app.h - Estado global de la app PERDIDAS
 */
#ifndef APP_H
#define APP_H

#include <stdint.h>
#include <stdbool.h>
#include "hydro/hydro.h"

#define APP_NAME    "PERDIDAS"
#define APP_VERSION "1.0"
#define CFG_APPVAR  "PERDCFG"
#define TX_APPVAR   "PERDTXT"
#define CASES_APPVAR "PERDCAS"
#define DEC_MAX     9

typedef struct {
    hydro_cfg h;          /* metodo de f, g, gamma, nu, tolerancias...  */
    uint8_t dec;          /* decimales en pantalla (6 por defecto)      */
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

/* scr_lib.c: biblioteca */
bool lib_pick_material(void);
bool lib_sumador(void);
bool lib_pick_fluid(uint8_t to_settings);
void lib_diams(void);
void scr_library(void);

#endif
