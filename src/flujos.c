/*
 * flujos.c - v2.0: menu principal del programa FLUJOS (arrastre y
 * sustentacion, vertedores y orificios, canales y medicion). Se compila
 * desde flujos/makefile con -DPROG_FLUJOS; comparte el codigo y los
 * AppVars PERDTXT, PERDCFG y PERDCAS con PERDIDAS.
 */
#include "app.h"
#include "ui/ui.h"
#include <string.h>
#include "ui/widgets.h"

/* submenu generico; fn recibe el indice elegido */
static void sub_menu(menu_t *m, void (*fn)(uint8_t))
{
    int r;
    while (!ui_quit) {
        r = menu_run(m);
        if (r == MENU_BACK || r == MENU_QUIT)
            return;
        if (r == MENU_MODE)
            scr_settings();
        else
            fn((uint8_t)r);
    }
}

static void drag_item(uint8_t r)
{
    if (r == 5)
        scr_cat(0);
    else
        scr_drag(r);
}

static void weir_item(uint8_t r)
{
    scr_weir(r);
}

static void chan_item(uint8_t r)
{
    if (r == 3)
        scr_drag(4);              /* placa plana y Stokes (EX-4) */
    else
        scr_chan(r);
}

static void course_cases(void)
{
    static const char *const names[17] = {
        "AR-01 Paracaidista (T4-2 P1)",
        "AR-02 Torre y tanque (T4-2 P4)",
        "AR-03 Cubo en agua (T4-2 P5)",
        "AR-04 Avion A-330 (2017 P2)",
        "AR-05 Esfera en flujo lento (Stokes)",
        "AR-06 Placa plana en aire",
        "VE-01 Triang. + 3 orificios (2024 P5a)",
        "VE-02 Nivel con 0.5 m3/s (2024 P5b)",
        "VE-03 Triangular, 200 l/s (2025 P4a)",
        "VE-04 Triang., 260.64 l/s (2025 P4b)",
        "VE-05 Triang. 60, 16 l/s (T4-2 P2a)",
        "VE-06 Reparto 36 l/s (T4-2 P2b)",
        "VE-07 Perfil v = 2 y^2 (T4-2 P3a)",
        "VE-08 Cota de la cresta (T4-2 P3b)",
        "EX-01 Venturi (2025 P4c)",
        "EX-02 Salto hidraulico (2017 P3)",
        "EX-03 Chorro desde un tubo (2025)",
    };
    static uint8_t cur;
    uint8_t i, k, t;
    int r;
    for (;;) {
        for (i = 0; i < 17; i++)
            strcpy(list_line[i], names[i]);
        r = list_pick("CASOS DEL CURSO", "ENTER carga los datos y calcula", 17,
                      cur, 0, &k);
        if (r < 0 || k != K_ENTER)
            return;
        cur = (uint8_t)r;
        if (r < 6) {
            t = drag_preset((uint8_t)r);
            scr_drag_run(t, 1);
        } else if (r < 14) {
            t = weir_preset((uint8_t)(r - 6));
            scr_weir_run(t, 1);
        } else {
            t = chan_preset((uint8_t)(r - 14));
            scr_chan_run(t, 1);
        }
        if (ui_quit)
            return;
    }
}

static void help_item(uint8_t r)
{
    static const char *const fk[5] = { "", "", "", "", "VOLVER" };
    static const uint8_t topic[4] = { 8, 9, 10, 6 };   /* PROG_HELP(i) */
    if (r < 4) {
        if (!help_topic(topic[r]))
            ui_alert("Ayuda", "Falta PERDTXT o es de", "otra version", C_ERR);
        else
            view_run("AYUDA", fk);
    } else if (r == 4) {
        course_cases();
    } else {
        scr_about();
    }
}

void flujos_main(void)
{
    static const char *const items[] = {
        "Arrastre y sustentacion",
        "Vertedores y orificios",
        "Canales y medicion",
        "Coeficientes de arrastre (CD)",
        "Mis casos",
        "Ajustes",
        "Ayuda / Acerca de",
        "Salir",
    };
    static const char *const ar_items[] = {
        "Fuerza de arrastre FD o FL  (AR-1)",
        "Velocidad terminal          (AR-2)",
        "Estructura: varios cuerpos  (AR-3)",
        "Vuelo nivelado (avion)      (AR-4)",
        "Placa plana y flujo lento (Stokes)",
        "Catalogo de coeficientes CD",
    };
    static const char *const ve_items[] = {
        "Vertedero u orificio (VE-1,2,5)",
        "Estructura compuesta      (VE-4)",
        "Perfil de velocidades     (VE-6)",
        "Aguas abajo: energia      (VE-7)",
    };
    static const char *const ch_items[] = {
        "Venturi y manometro       (EX-1)",
        "Salto hidraulico          (EX-2)",
        "Chorro desde un tubo      (EX-3)",
        "Placa plana y Stokes      (EX-4)",
    };
    static const char *const help_items[] = {
        "Arrastre y sustentacion",
        "Vertedores y orificios",
        "Canales y medicion",
        "Erratas del material",
        "Casos del curso (cargar)",
        "Acerca de",
    };
    static menu_t m = { "FLUJOS EXTERNOS Y MEDICION", items, 8, 0 };
    static menu_t mar = { "ARRASTRE Y SUSTENTACION", ar_items, 6, 0 };
    static menu_t mh = { "AYUDA", help_items, 6, 0 };
    static menu_t mve = { "VERTEDORES Y ORIFICIOS", ve_items, 4, 0 };
    static menu_t mch = { "CANALES Y MEDICION", ch_items, 4, 0 };
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
        case 5: scr_settings(); break;
        case 0: sub_menu(&mar, drag_item); break;
        case 1: sub_menu(&mve, weir_item); break;
        case 2: sub_menu(&mch, chan_item); break;
        case 3: scr_cat(0); break;
        case 4: scr_cases(); break;
        case 6: sub_menu(&mh, help_item); break;
        case 7: return;
        default: break;
        }
    }
}
