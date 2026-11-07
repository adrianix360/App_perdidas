/*
 * Prueba de los casos dorados DENTRO de la calculadora emulada (eZ80,
 * float de 32 bits). La tabla completa sale por la consola de CEmu
 * (Docks > Console); en pantalla queda el resumen.
 */
#include <ti/screen.h>
#include <ti/getcsc.h>
#include <stdio.h>
#include <debug.h>

#define OUT dbg_printf
#define GOLDEN_NO_MAIN
#include "../../../golden.c"
#include "../../../../src/hydro/hydro.c"

int main(void)
{
    char buf[32];
    int p, r, f, m;

    os_ClrHome();
    os_PutStrFull("Casos dorados...");
    golden_run(0);
    golden_counts(&p, &r, &f, &m);
    os_ClrHome();
    os_PutStrFull("CASOS DORADOS eZ80");
    os_NewLine();
    sprintf(buf, "Pasan:   %d", p);
    os_PutStrFull(buf);
    os_NewLine();
    sprintf(buf, "Redondeo:%d", r);
    os_PutStrFull(buf);
    os_NewLine();
    sprintf(buf, "Fallan:  %d", f + m);
    os_PutStrFull(buf);
    os_NewLine();
    os_PutStrFull(f + m ? "RESULTADO: FALLA" : "RESULTADO: OK");
    while (!os_GetCSC());
    os_ClrHome();
    return 0;
}
