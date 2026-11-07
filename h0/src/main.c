/* Hito H0: Hola mundo para TI-84 Plus CE (OS 5.8.4.0058) */
#include <ti/screen.h>
#include <ti/getcsc.h>

int main(void)
{
    os_ClrHome();
    os_PutStrFull("Hola mundo H0");
    os_NewLine();
    os_PutStrFull("CEdev v15.0 OK");
    while (!os_GetCSC());
    os_ClrHome();
    return 0;
}
