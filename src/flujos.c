/*
 * flujos.c - v2.0: menu principal del programa FLUJOS (arrastre y
 * sustentacion, vertedores y orificios, canales y medicion). Se compila
 * desde flujos/makefile con -DPROG_FLUJOS; comparte el codigo y los
 * AppVars PERDTXT, PERDCFG y PERDCAS con PERDIDAS.
 */
#include "app.h"
#include "ui/ui.h"
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

static void help_item(uint8_t r)
{
    (void)r;
    scr_about();
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
    static const char *const help_items[] = { "Acerca de" };
    static menu_t m = { "FLUJOS EXTERNOS Y MEDICION", items, 8, 0 };
    static menu_t mar = { "ARRASTRE Y SUSTENTACION", ar_items, 6, 0 };
    static menu_t mh = { "AYUDA", help_items, 1, 0 };
    static menu_t mve = { "VERTEDORES Y ORIFICIOS", ve_items, 4, 0 };
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
        case 2: todo_alert(items[2], 5); break;
        case 3: scr_cat(0); break;
        case 4: todo_alert(items[4], 6); break;
        case 6: sub_menu(&mh, help_item); break;
        case 7: return;
        default: break;
        }
    }
}
