/*
 * PERDIDAS - Perdidas de energia en tuberias para la TI-84 Plus CE
 * IC-0605 Mecanica de Fluidos, UCR. Programa nativo (CE C Toolchain).
 * En OS 5.5 a 5.8.4 requiere arTIfiCE v2.1 para ejecutarse.
 */
#include <ti/screen.h>
#include "app.h"
#include "ui/ui.h"

int main(void)
{
    uint8_t st = settings_load();

    ui_init();
    if (st == 2) {
        ui_begin(APP_NAME, 0);
        ui_end();
        ui_alert("Ajustes", "Archivo de ajustes danado:",
                 "se usan valores por defecto", C_WARN);
        g_set_dirty = true;
    }
    scr_main();
    ui_exit();

    /* Se guarda despues de cerrar graphx: archivar puede mostrar el
     * mensaje de reorganizacion de memoria del sistema operativo. */
    if (g_set_dirty)
        settings_save();
    os_ClrHome();
    return 0;
}
