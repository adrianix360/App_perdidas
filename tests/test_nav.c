/*
 * test_nav.c - Pruebas de la interfaz en el PC con pantalla y teclado
 * simulados (tests/mock/mock_ui.c). Recorre todos los menus, resuelve un
 * caso del curso por cada tipo de tuberia simple tecleandolo en su
 * formulario, revisa la memoria de calculo (sin plantillas sin resolver y
 * con todas sus secciones), prueba entradas invalidas, los Ajustes y su
 * AppVar (incluido danado o ausente) y hace una prueba de estres con
 * secuencias de teclas aleatorias.
 * Uso: test_nav [-t]   (-t imprime cada pantalla)
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "../src/app.h"
#include "../src/ui/ui.h"
#include "../src/ui/widgets.h"
#include "../src/ui/numfmt.h"
#include "mock/fileioc.h"

extern char scr[UI_ROWS + 2][UI_COLS + 1];
extern char scr_msg[];
extern char last_title[], alert_title[], alert_l1[], watch_title[];
extern int watch_hits;
extern long n_frames, n_alerts, n_keys;
extern int trace;
void mock_script(const ui_key *k, int n);
void mock_fuzz(unsigned long seed, long n);
int mock_script_left(void);

static ui_key S[1024];
static int sn, fails, checks;

static void K(uint8_t k) { S[sn].k = k; S[sn].c = 0; sn++; }
static void T(const char *s) { while (*s) { S[sn].k = K_CHAR; S[sn].c = *s++; sn++; } }
static void TE(const char *s) { T(s); K(K_ENTER); }

static void run(void)
{
    mock_script(S, sn);
    ui_quit = false;
    scr_main();
    sn = 0;
}

static void check(int ok, const char *what)
{
    checks++;
    if (!ok) {
        fails++;
        printf("FALLA: %s\n", what);
        printf("  titulo \"%s\" mensaje \"%s\"\n", last_title, scr_msg);
    }
}

/* Busca en el visor la linea cuya etiqueta empieza con `lab` */
static const char *view_value(const char *lab)
{
    uint8_t i;
    for (i = 0; i < view_n; i++)
        if (!strncmp(view_line[i] + 1, lab, strlen(lab)) &&
            view_line[i][17] == '=')
            return view_line[i] + 19;
    return "";
}

static int starts(const char *s, const char *p)
{
    return !strncmp(s, p, strlen(p));
}

/* alguna linea del visor contiene el texto */
static int has_line(const char *t)
{
    uint8_t i;
    for (i = 0; i < view_n; i++)
        if (strstr(view_line[i], t))
            return 1;
    return 0;
}

/* memoria completa: sin plantillas sin resolver, con OBSERVACIONES al
 * final (IF/ENDIF balanceados) y sin llenar el visor */
static int memo_ok(void)
{
    uint8_t i;
    int obs = 0;
    if (getenv("MEMO_DUMP")) {
        printf("======== %s (%d lineas)\n", view_line[0], view_n);
        for (i = 0; i < view_n; i++)
            printf("%s\n", view_line[i]);
    }
    for (i = 0; i < view_n; i++) {
        if (strchr(view_line[i], '?') || strchr(view_line[i], '{')) {
            printf("  linea con plantilla sin resolver: %s\n", view_line[i]);
            return 0;
        }
        if (!strcmp(view_line[i], "OBSERVACIONES"))
            obs = 1;
    }
    if (!obs)
        printf("  falta OBSERVACIONES (%d lineas)\n", view_n);
    if (view_n >= VIEW_MAX)
        printf("  el visor se lleno (%d lineas)\n", view_n);
    return obs && view_n < VIEW_MAX;
}

int main(int argc, char **argv)
{
    long a0;
    int seed;
    char exp[NUMFMT_LEN + 24], buf[NUMFMT_LEN];
    hydro_cfg c;
    hydro_pipe p;
    hydro_state s;

    trace = (argc > 1 && !strcmp(argv[1], "-t"));
    settings_default(&g_set);
    if (!mock_load_file("PERDTXT", "bin/PERDTXT.bin")) {
        printf("FALLA: no se pudo cargar bin/PERDTXT.bin (correr tools/build_all.sh)\n");
        return 1;
    }

    /* 1. Navegacion por todo el menu, con salida por "Salir" */
    a0 = n_alerts;
    T("1");
    T("1"); K(K_CLEAR); T("2"); K(K_CLEAR); T("3"); K(K_CLEAR); T("4"); K(K_CLEAR);
    T("5"); K(K_CLEAR); T("6"); K(K_CLEAR); T("7"); K(K_CLEAR);
    K(K_CLEAR);
    T("2"); K(K_ENTER);
    T("3"); T("1"); K(K_ENTER); T("2"); K(K_ENTER); T("3"); K(K_ENTER);
    T("4"); K(K_ENTER); K(K_CLEAR);
    T("4"); K(K_ENTER);
    T("6"); { int i; for (i = 0; i < 40; i++) K(K_DOWN); } K(K_RIGHT); K(K_LEFT); K(K_F5);
    K(K_DOWN); K(K_DOWN); K(K_UP); K(K_UP);   /* menu con flechas */
    T("7");
    run();
    check(n_alerts - a0 == 6, "6 avisos de modulos pendientes (fases 4 y 5)");
    check(!ui_quit && mock_script_left() == 0, "sale por la opcion Salir sin teclas de sobra");

    /* 2. CLEAR en el menu principal pide confirmacion */
    K(K_CLEAR); K(K_CLEAR); K(K_CLEAR); K(K_ENTER);
    run();
    check(!ui_quit && !strcmp(alert_title, "Salir"), "CLEAR + ENTER confirma la salida");

    /* 3. Formulario A: calcular sin datos */
    T("1"); T("1"); K(K_PGUP); K(K_F5);
    run();
    check(!strcmp(scr_msg, "Falta este dato"), "aviso de dato faltante");

    /* 4. Entradas invalidas */
    T("1"); T("1"); K(K_PGUP); K(K_DOWN); TE("0");
    run();
    check(!strcmp(scr_msg, "Debe ser mayor que 0"), "D = 0 rechazado");
    T("1"); T("1"); K(K_PGUP); TE("3+");
    run();
    check(!strcmp(scr_msg, "Error de sintaxis"), "3+ rechazado");
    T("1"); T("1"); K(K_PGUP); TE("1/0");
    run();
    check(!strcmp(scr_msg, "Division entre cero"), "1/0 rechazado");
    T("1"); T("1"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("-1");
    run();
    check(!strcmp(scr_msg, "No puede ser negativo"), "ks < 0 rechazado");
    T("1"); T("1"); K(K_PGUP); T("123"); K(K_CLEAR); K(K_CLEAR); K(K_DEL); K(K_DEL);
    run();
    check(!strcmp(last_title, "PERDIDAS DADO Q  (A)"), "CLEAR en edicion vuelve al formulario");

    /* 5. P-02 desde el formulario (Swamee-Jain), con presion en el punto */
    g_set.h.method = FM_SJ;
    T("1"); T("1"); K(K_PGUP);
    TE("72"); TE("200"); TE("1000"); TE("0.0015");
    TE("0.5+3*0.15+167*0.01+12*0.18+6*0.32");
    TE("1.007E-6");
    K(K_ENTER);            /* f dado: vacio (opcional) */
    TE("53");              /* H sobre el punto */
    K(K_F5);
    run();
    check(has_line("RESULTADO  Perdidas dado Q"), "P-02: se muestra el resultado");
    c = g_set.h;
    c.nu = (real)1.007e-6;
    c.method = FM_SJ;
    p.D = (real)0.2; p.L = 1000; p.ks = (real)0.0015e-3; p.sumK = (real)6.7; p.f_fixed = 0;
    hydro_pipe_state(&p, (real)0.072, &c, &s);
    fmt_real(s.hT, 6, buf);
    snprintf(exp, sizeof exp, "%s m", buf);
    check(!strcmp(view_value("hT = hf + hm"), exp), "P-02: hT del formulario = motor");
    check(starts(view_value("hT = hf + hm"), "19.76"), "P-02: hT = 19,76 m");
    check(starts(view_value("hm"), "1.79"), "P-02: hm = 1,79 m");
    check(starts(view_value("v "), "2.29"), "P-02: v = 2,29 m/s");
    check(starts(view_value("p/gamma punto"), "32.96"), "P-02: p/gamma = 32,97 m");
    T("1"); T("1"); K(K_F5); K(K_F1);
    run();
    check(memo_ok() && has_line("Swamee-Jain"), "P-02: memoria de calculo completa");
    check(has_line("= 0.072/0.031416"), "P-02: sustitucion v = Q/A con Q");

    /* Memoria del tipo A con los cuatro metodos de f y en laminar */
    {
        int m;
        for (m = 0; m < FM_COUNT; m++) {
            g_set.h.method = (unsigned char)m;
            T("1"); T("1"); K(K_F5); K(K_F1);
            run();
            snprintf(exp, sizeof exp, "memoria A metodo %d", m);
            check(memo_ok(), exp);
        }
        g_set.h.method = FM_CW;
        T("1"); T("1"); K(K_PGUP); TE("0.00002"); TE("20"); TE("50"); K(K_F5); K(K_F1);
        run();
        check(memo_ok() && has_line("64/Re"), "memoria A laminar");
    }

    /* 5b. Un caso del curso por tipo, tecleado en su formulario */
    g_set.h.method = FM_CW;
    /* B, P-03 */
    T("1"); T("2"); K(K_PGUP); TE("43.5"); TE("293"); TE("700"); TE("0.0015"); TE("11.5");
    TE("1E-6"); K(K_F5);
    run();
    check(starts(view_value("Q"), "318.8") && has_line("iteracion del curso"), "B P-03: Q = 318,8 l/s");
    T("1"); T("2"); K(K_F5); K(K_F1);
    run();
    check(memo_ok() && has_line("ITERACIONES"), "B P-03: memoria con tabla de iteraciones");
    /* B, P-07: la iteracion del curso diverge */
    T("1"); T("2"); K(K_PGUP); TE("5"); TE("50"); TE("2.06"); TE("0.045"); TE("10.8");
    TE("1.007E-6"); K(K_F5);
    run();
    check(starts(view_value("Q"), "5.69") && has_line("biseccion"), "B P-07: Q = 5,69 l/s por biseccion");
    T("1"); T("2"); K(K_F5); K(K_F1);
    run();
    check(memo_ok() && has_line("no convergio"), "B P-07: memoria indica el respaldo");
    /* C, P-11 con gamma = 9810 */
    T("1"); T("4"); K(K_PGUP); K(K_ENTER); TE("42"); TE("150"); TE("970"); TE("0.0015");
    TE("9.4"); TE("1.14E-6"); TE("16"); TE("0.65"); K(K_ENTER); TE("890"); K(K_F5);
    run();
    check(starts(view_value("HB"), "45.62") && starts(view_value("Pb (consume)"), "28.92"),
          "C P-11: HB = 45,62 m, Pb = 28,92 kW");
    check(starts(view_value("Cota piezometr."), "935.6"), "C P-11: cota piezometrica");
    T("1"); T("4"); K(K_F5); K(K_F1);
    run();
    check(memo_ok(), "C P-11: memoria completa");
    /* C, P-19 turbina */
    T("1"); T("4"); K(K_PGUP); K(K_RIGHT); K(K_ENTER); TE("200"); TE("285.75"); TE("1900");
    TE("0.0015"); TE("12.8"); TE("1E-6"); TE("76"); TE("0.65"); K(K_F5);
    run();
    check(starts(view_value("HT"), "30.1") && starts(view_value("Pb (agua)"), "59.1") &&
          starts(view_value("Pn (genera)"), "38.4"), "C P-19: turbina HT, Pb, Pn");
    T("1"); T("4"); K(K_F5); K(K_F1);
    run();
    check(memo_ok(), "C P-19: memoria completa");
    /* D, P-17 con valvula de control (P-18) */
    T("1"); T("3"); K(K_PGUP); TE("200"); TE("76"); TE("1900"); TE("0.0015"); TE("12.8");
    TE("1E-6"); K(K_ENTER); K(K_RIGHT); K(K_F5);
    run();
    check(starts(view_value("D exacto"), "256.8") && starts(view_value("D comercial"), "285.75") &&
          starts(view_value("Qmax con D com."), "262.38"), "D P-17: 256,8 / 285,75 / 262,4 (262,38)");
    check(starts(view_value("Kv valvula"), "60.7"), "D P-18: Kv = 60,8");
    T("1"); T("3"); K(K_F5); K(K_F1);
    run();
    check(memo_ok() && has_line("VALVULA DE CONTROL"), "D P-17: memoria completa");
    /* D con perdidas locales altas: velocidad de perdidas vp */
    T("1"); T("3"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("200"); K(K_F5); K(K_F1);
    run();
    check(memo_ok() && has_line("vp ="), "D con locales altas: vp en la memoria");
    /* F, P-18 */
    T("1"); T("5"); K(K_PGUP); TE("200"); TE("285.75"); TE("1900"); TE("0.0015"); TE("12.8");
    TE("1E-6"); TE("76"); K(K_F5);
    run();
    check(starts(view_value("hv"), "30.13") && starts(view_value("Kv"), "60.7"), "F P-18: hv y Kv");
    T("1"); T("5"); K(K_F5); K(K_F1);
    run();
    check(memo_ok(), "F P-18: memoria completa");
    /* E, P-25 */
    T("1"); T("6"); K(K_PGUP); TE("1135"); TE("1070"); TE("36"); TE("84"); TE("405"); TE("274");
    TE("172"); TE("3.5"); TE("1.17E-6");
    run();
    check(starts(view_value("ks "), "0.5906") && starts(view_value("f "), "0.02415"), "E P-25: ks = 0,591 mm");
    T("1"); T("6"); K(K_F5); K(K_F1);
    run();
    check(memo_ok(), "E P-25: memoria completa");
    /* I, P-01 con Swamee-Jain */
    g_set.h.method = FM_SJ;
    T("1"); T("7"); K(K_PGUP); K(K_ENTER); TE("72"); K(K_ENTER); TE("200"); TE("1000");
    TE("0.0015"); TE("0"); TE("1.007E-6"); TE("150"); K(K_F5);
    run();
    check(starts(view_value("hf Hazen-W."), "19.32") && starts(view_value("Diferencia"), "7.49"),
          "I P-01: HW 19,32 m, +7,5 %");
    T("1"); T("7"); K(K_F5); K(K_F1);
    run();
    check(memo_ok(), "I P-01: memoria completa");
    /* I, P-10: caudal con Darcy-W. (CW) y Hazen-W. */
    g_set.h.method = FM_CW;
    T("1"); T("7"); K(K_PGUP); K(K_RIGHT); K(K_ENTER); K(K_ENTER); TE("100"); TE("300");
    TE("4500"); TE("0.045"); TE("5"); TE("1E-6"); TE("130"); K(K_F5);
    run();
    check(starts(view_value("Q Hazen-W."), "195.4") && starts(view_value("Diferencia"), "-7.79"),
          "I P-10: Q HW 195,46 l/s, -7,8 %");
    T("1"); T("7"); K(K_F5); K(K_F1);
    run();
    check(memo_ok(), "I P-10: memoria completa");
    check(g_set.h.method == FM_CW, "metodo en ajustes");

    /* 6. Ajustes: decimales, validaciones y archivo */
    T("5"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("3"); K(K_F5);
    run();
    check(g_set.dec == 3 && g_set_dirty, "decimales = 3 y ajustes por guardar");
    T("5"); K(K_PGUP); K(K_DOWN); TE("50");
    run();
    check(!strcmp(scr_msg, "Fuera del rango permitido"), "g = 50 rechazado");
    T("5"); K(K_PGUP); { int i; for (i = 0; i < 8; i++) K(K_DOWN); } TE("0.1"); K(K_F5);
    run();
    check(starts(scr_msg, "Revise"), "v max < v min rechazado al salir");
    check(settings_valid(&g_set), "ajustes siguen validos tras QUIT");
    g_set.h.v_max = 5;
    check(settings_save() && mock_file_archived, "guardar archiva el AppVar");
    g_set.dec = 6;
    check(settings_load() == 0 && g_set.dec == 3, "los ajustes se recuperan del AppVar");
    mock_file[12] ^= 0x55;
    check(settings_load() == 2 && g_set.dec == 6, "AppVar danado: valores por defecto");
    mock_file_len = 3;
    check(settings_load() == 2, "AppVar truncado: valores por defecto");
    mock_file_exists = 0;
    check(settings_load() == 1 && g_set.dec == 6, "sin AppVar: valores por defecto");
    T("5"); K(K_PGUP); K(K_F1); K(K_ENTER); K(K_F5);
    g_set.dec = 2;
    run();
    check(g_set.dec == 6 && g_set.h.method == FM_CW, "F1 restaura los valores por defecto");

    /* 7. MODE desde un formulario abre Ajustes y vuelve */
    strcpy(watch_title, "AJUSTES");
    watch_hits = 0;
    T("1"); T("1"); K(K_PGUP); K(K_MODE);
    run();
    check(watch_hits > 0 && !strcmp(last_title, "AJUSTES"), "MODE abre Ajustes");
    /* expresion de 60 caracteres y desborde del bufer */
    T("1"); T("1"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); K(K_DOWN);
    TE("0.5+1.0+4*1.10+10*0.30+3*0.3+3.0+0.5+1.0+4*1.10+10*0.30+0");
    K(K_UP); K(K_RIGHT);
    run();
    check(!strncmp(scr_msg, "ENTER acepta", 12), "suma de K de 60 caracteres aceptada");
    T("1"); T("1"); K(K_PGUP);
    { int i; for (i = 0; i < 70; i++) T("1"); }
    run();
    check(!strcmp(scr_msg, "Expresion demasiado larga"), "aviso de expresion larga");

    /* 8. Estres: secuencias aleatorias largas */
    {
        long keys0 = n_keys, fr0 = n_frames;
        for (seed = 1; seed <= 40; seed++) {
            mock_fuzz((unsigned long)seed * 7919UL, 25000);
            while (mock_script_left() >= 0 && n_keys - keys0 < (long)seed * 25000) {
                ui_quit = false;
                scr_main();
                if (!settings_valid(&g_set)) {
                    check(0, "el estres dejo ajustes invalidos");
                    break;
                }
                if (view_n > VIEW_MAX) {
                    check(0, "visor fuera de limite");
                    break;
                }
            }
        }
        printf("Estres: %ld teclas, %ld pantallas, 40 semillas\n",
               n_keys - keys0, n_frames - fr0);
        check(1, "estres sin cierres");
    }

    printf("%d de %d comprobaciones de la interfaz pasan\n", checks - fails, checks);
    return fails ? 1 : 0;
}
