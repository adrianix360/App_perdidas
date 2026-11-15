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
#include "data/data.h"
#include "pipe.h"

#define HELP_COUNT_UI 7   /* temas en PERDTXT (memo_defs.h: HELP_COUNT) */

const char *const method_names[FM_COUNT] = {
    "Colebrook-White", "Swamee-Jain", "Haaland", "Goudar-Sonnad"
};

/* ================================================================== */
/* Ajustes (MODE desde cualquier pantalla)                             */
/* ================================================================== */
static const char *const yesno2[2] = { "No", "Si" };
static const char *const mano_names[2] = { "(S-1) g h fisico", "S g h examen" };

void scr_settings(void)
{
    static uint8_t cur;
    static app_settings old;
    static real dec;
    static form_field f[] = {
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
        /* v2.0 */
        { "rho del aire", "kg/m3", &g_set.rho_air, 0, 0, FF_RANGE, 0, 0, 0.05, 5 },
        { "nu del aire", "m2/s", &g_set.nu_air, 0, 0, FF_RANGE, 0, 0, 1e-7, 1e-3 },
        { "Empuje con aire", 0, 0, &g_set.buoy, 0, FF_CHOICE, yesno2, 2, 0, 0 },
        { "Cd vertedores", 0, &g_set.cd_weir, 0, 0, FF_RANGE, 0, 0, 0.1, 1.5 },
        { "km/h por nudo", 0, &g_set.knot, 0, 0, FF_RANGE, 0, 0, 1, 3 },
        { "Manometro", 0, 0, &g_set.mano, 0, FF_CHOICE, mano_names, 2, 0, 0 },
    };
    form_t fm;
    uint8_t k;

    old = g_set;
    dec = g_set.dec;
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
void scr_about(void)
{
    static const char *const fk[5] = { "", "", "", "", "VOLVER" };
    char num[24];
    view_clear();
    view_add(APP_NAME " v" APP_VERSION, C_TITLE);
#ifdef PROG_FLUJOS
    view_add("Arrastre, vertedores y canales", C_FG);
#else
    view_add("Perdidas de energia en tuberias", C_FG);
#endif
    view_add("IC-0605 Mecanica de Fluidos, UCR", C_FG);
    view_add("Adrian Castro Ramirez", C_FG);
    view_add_sep();
    view_add("Programa nativo en C (CE Toolchain", C_GRAY);
    view_add("v15.0). En OS 5.5 a 5.8.4 se lanza", C_GRAY);
    view_add("con arTIfiCE v2.1. Dos programas:", C_GRAY);
    view_add("PERDIDAS (tuberias) y FLUJOS (flujos", C_GRAY);
    view_add("externos). Comparten PERDTXT, PERDCFG", C_GRAY);
    view_add("y PERDCAS; FLUJOS usa PERDGFX.", C_GRAY);
    view_add_sep();
    strcpy(num, " RAM libre: ");
    fmt_int((long)ui_free_ram(), num + strlen(num));
    strcat(num, " B");
    view_add(num, C_GRAY);
    view_run("ACERCA DE", fk);
}

static void course_cases(void)
{
    static uint8_t cur;
    uint8_t i, k;
    int r;
    for (;;) {
        for (i = 0; i < EXAMPLES; i++)
            strcpy(list_line[i], examples[i].name);
        r = list_pick("CASOS DEL CURSO", "ENTER carga los datos y calcula",
                      EXAMPLES, cur, 0, &k);
        if (r < 0 || k != K_ENTER)
            return;
        cur = (uint8_t)r;
        if (examples[r].tipo == PT_COUNT) {
            scr_net_example(examples[r].n);
        } else {
            pipe_load_example(examples[r].tipo, examples[r].vals, examples[r].n);
            scr_pipe_run(examples[r].tipo, 1);
        }
        if (ui_quit)
            return;
    }
}

static void scr_help(void)
{
    static const char *const items[] = {
        "Uso y teclas",
        "Tipos de problema",
        "Formulas",
        "Potencia bruta y neta",
        "Suma K y fuentes de datos",
        "Advertencias",
        "Erratas del material",
        "Casos del curso (cargar)",
        "Acerca de",
    };
    static const char *const fk[5] = { "", "", "", "", "VOLVER" };
    static menu_t m = { "AYUDA", items, 9, 0 };
    int r;
    while (!ui_quit) {
        r = menu_run(&m);
        if (r == MENU_BACK || r == MENU_QUIT)
            return;
        if (r == MENU_MODE) {
            scr_settings();
            continue;
        }
        if (r < HELP_COUNT_UI) {
            if (!help_topic((uint8_t)r)) {
                ui_alert("Ayuda", "Falta el archivo PERDTXT.", "Envielo con TI Connect CE", C_ERR);
                continue;
            }
            view_run("AYUDA", fk);
        } else if (r == HELP_COUNT_UI) {
            course_cases();
        } else {
            scr_about();
        }
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
        "f: factor de friccion",
    };
    static menu_t m = { "TUBERIA SIMPLE", items, 8, 0 };
    int r;
    while (!ui_quit) {
        r = menu_run(&m);
        if (r == MENU_BACK || r == MENU_QUIT)
            return;
        if (r == MENU_MODE) {
            scr_settings();
            continue;
        }
        if (r == PT_COUNT)
            scr_fric(0, 0);
        else
            scr_pipe((uint8_t)r);
    }
}

/* v2.0: arrastre, vertedores y canales viven en el programa FLUJOS */
static void ext_info(void)
{
    ui_alert("Flujos externos", "Abra el programa FLUJOS", "(arTIfiCE, igual que este)", C_TITLE);
}

void scr_main(void)
{
    static const char *const items[] = {
        "Tuberia simple",
        "Sistemas (serie / paralelo)",
        "Calcular f (solo f)",
        "Flujos externos (FLUJOS)",
        "Biblioteca",
        "Mis casos",
        "Ajustes",
        "Ayuda / Acerca de",
        "Salir",
    };
    static menu_t m = { "MENU PRINCIPAL", items, 9, 0 };
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
        case 6: scr_settings(); break;
        case 0: scr_pipe_menu(); break;
        case 1: scr_net(); break;
        case 2: scr_fric(0, 0); break;
        case 3: ext_info(); break;
        case 4: scr_library(); break;
        case 5: scr_cases(); break;
        case 7: scr_help(); break;
        case 8: return;
        default: break;
        }
    }
}
