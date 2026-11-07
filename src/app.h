/*
 * app.h - Estado global de la app PERDIDAS
 */
#ifndef APP_H
#define APP_H

#include <stdint.h>
#include <stdbool.h>
#include "hydro/hydro.h"

#define APP_NAME    "PERDIDAS"
#define APP_VERSION "0.2"
#define CFG_APPVAR  "PERDCFG"
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

#endif
