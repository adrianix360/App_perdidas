/*
 * screens.c - Menus y pantallas de la app (fase 2: esqueleto completo de
 * navegacion, Ajustes, Ayuda y el tipo A como ejemplo del patron de
 * formulario -> resultado).
 */
#include <string.h>
#include "app.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "ui/numfmt.h"
#include "ui/texts.h"

const char *const method_names[FM_COUNT] = {
    "Colebrook-White", "Swamee-Jain", "Haaland", "Goudar-Sonnad"
};

/* ================================================================== */
/* Ajustes (MODE desde cualquier pantalla)                             */
/* ================================================================== */
void scr_settings(void)
{
    static uint8_t cur;
    app_settings old = g_set;
    real dec = g_set.dec;
    form_field f[] = {
        { "Metodo de f", 0, 0, &g_set.h.method, 0, FF_CHOICE, method_names, FM_COUNT, 0, 0 },
        { "g", "m/s2", &g_set.h.g, 0, 0, FF_RANGE, 0, 0, 1, 20 },
        { "gamma", "N/m3", &g_set.h.gamma, 0, 0, FF_RANGE, 0, 0, 1000, 20000 },
        { "nu", "m2/s", &g_set.h.nu, 0, 0, FF_RANGE, 0, 0, 1e-8, 1e-3 },
        { "Decimales", 0, &dec, 0, 0, FF_INT, 0, 0, 0, DEC_MAX },
        { "Tolerancia iter.", "m", &g_set.h.tol, 0, 0, FF_RANGE, 0, 0, 1e-9, 1 },
        { "Presion de vapor", "Pa", &g_set.h.pv, 0, 0, FF_RANGE, 0, 0, 0, 101325 },
        { "v minima aviso", "m/s", &g_set.h.v_min, 0, 0, FF_RANGE, 0, 0, 0, 100 },
        { "v maxima aviso", "m/s", &g_set.h.v_max, 0, 0, FF_RANGE, 0, 0, 0, 100 },
        { "L/D despreciable", 0, &g_set.h.ld_limit, 0, 0, FF_RANGE, 0, 0, 1, 1e6 },
        { "Aviso hm/hf", 0, &g_set.h.hm_ratio, 0, 0, FF_RANGE, 0, 0, 0, 100 },
        { "Re laminar <", 0, &g_set.h.re_lam, 0, 0, FF_RANGE, 0, 0, 100, 10000 },
        { "Re turbulento >", 0, &g_set.h.re_turb, 0, 0, FF_RANGE, 0, 0, 100, 100000 },
    };
    form_t fm;
    uint8_t k;

    memset(&fm, 0, sizeof fm);
    fm.title = "AJUSTES";
    fm.f = f;
    fm.n = sizeof f / sizeof f[0];
    fm.cur = cur;
    fm.fk[0] = "DEFECTO";
    fm.fk[4] = "LISTO";
    fm.hint = "Cambios se guardan al salir de la app";
    for (;;) {
        k = form_run(&fm);
        g_set.dec = (uint8_t)dec;
        if (k == K_QUIT)
            break;
        if (k == K_F1) {
            if (ui_alert("Ajustes", "Restaurar los valores", "por defecto?",
                         C_WARN)) {
                settings_default(&g_set);
                dec = g_set.dec;
            }
            continue;
        }
        if (k == K_F5 || k == K_CLEAR || k == K_MODE || k == K_ENTER) {
            if (!settings_valid(&g_set)) {
                fm.msg = "Revise: Re turb > Re lam, vmax > vmin";
                fm.msg_color = C_ERR;
                continue;
            }
            break;
        }
    }
    cur = fm.cur;
    if (!settings_valid(&g_set))
        g_set = old;
    if (memcmp(&old, &g_set, sizeof old))
        g_set_dirty = true;
}

/* ================================================================== */
/* Ayuda / Acerca de                                                   */
/* ================================================================== */
static void scr_help(void)
{
    static const char *const fk[5] = { "", "", "", "", "VOLVER" };
    char num[24];
    uint8_t k;
    view_clear();
    view_add(APP_NAME " v" APP_VERSION "  Perdidas en tuberias", C_TITLE);
    view_add("IC-0605 Mecanica de Fluidos, UCR", C_FG);
    view_add("Adrian Castro Ramirez", C_FG);
    view_add_sep();
    view_add("TECLAS", C_TITLE);
    view_add(" ENTER   acepta y pasa al siguiente", C_FG);
    view_add(" CLEAR   borra / vuelve atras", C_FG);
    view_add(" DEL     borra un caracter", C_FG);
    view_add(" Flechas mueven; der. edita el valor", C_FG);
    view_add(" (-)     signo;  2nd ,  = E (x10^)", C_FG);
    view_add(" Y= ... GRAPH  teclas F1 a F5", C_FG);
    view_add(" MODE    Ajustes desde cualquier lado", C_FG);
    view_add(" 2nd MODE (QUIT)  salir de la app", C_FG);
    view_add_sep();
    view_add("CAMPOS", C_TITLE);
    view_add(" Aceptan cuentas: 0.5+4*1.1+3*0.3", C_FG);
    view_add(" y potencias: 1.5*10^-6 o 1.5E-6", C_FG);
    view_add(" Unidades: Q l/s, D mm, ks mm, L m", C_FG);
    view_add_sep();
    view_add("CONVENCIONES DEL CURSO", C_TITLE);
    view_add(" Laminar si Re < 2000 (f = 64/Re)", C_FG);
    view_add(" Transicion 2000-4000: indicativo", C_FG);
    view_add(" Potencia bruta = la mayor; neta =", C_FG);
    view_add(" la menor (bomba y turbina)", C_FG);
    view_add_sep();
    strcpy(num, " RAM libre: ");
    fmt_int((long)ui_free_ram(), num + strlen(num));
    strcat(num, " B");
    view_add(num, C_GRAY);
    for (;;) {
        k = view_run("AYUDA / ACERCA DE", fk);
        if (k == K_MODE) {
            scr_settings();
            continue;
        }
        break;
    }
}

/* ================================================================== */
/* Menus                                                               */
/* ================================================================== */
static void scr_pipe_menu(void)
{
    static const char *const items[] = {
        "Perdidas dado el caudal      (A)",
        "Caudal maximo / comprobacion (B)",
        "Diametro de diseno           (D)",
        "Bomba o turbina: carga y P   (C)",
        "Valvula de control           (F)",
        "Calibrar rugosidad           (E)",
        "Darcy-W. vs Hazen-Williams   (I)",
    };
    static menu_t m = { "TUBERIA SIMPLE", items, 7, 0 };
    int r;
    while (!ui_quit) {
        r = menu_run(&m);
        if (r == MENU_BACK || r == MENU_QUIT)
            return;
        if (r == MENU_MODE) {
            scr_settings();
            continue;
        }
        scr_pipe((uint8_t)r);
    }
}

void scr_main(void)
{
    static const char *const items[] = {
        "Tuberia simple",
        "Sistemas (serie / paralelo)",
        "Biblioteca",
        "Mis casos",
        "Ajustes",
        "Ayuda / Acerca de",
        "Salir",
    };
    static menu_t m = { "MENU PRINCIPAL", items, 7, 0 };
    int r;
    while (!ui_quit) {
        r = menu_run(&m);
        if (r == MENU_QUIT)
            return;
        if (r == MENU_BACK) {
            if (ui_alert("Salir", "Desea salir de " APP_NAME "?", 0, C_TITLE))
                return;
            continue;
        }
        switch (r) {
        case MENU_MODE:
        case 4: scr_settings(); break;
        case 0: scr_pipe_menu(); break;
        case 1: todo_alert("Sistemas serie / paralelo", 5); break;
        case 2: scr_library(); break;
        case 3: scr_cases(); break;
        case 5: scr_help(); break;
        case 6: return;
        default: break;
        }
    }
}
