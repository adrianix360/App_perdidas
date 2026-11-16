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
#include "../src/data/data.h"
#include "../src/pipe.h"

extern char scr[UI_ROWS + 2][UI_COLS + 1];
extern char scr_msg[];
extern char last_title[], alert_title[], alert_l1[], watch_title[];
extern int watch_hits;
extern long n_frames, n_alerts, n_keys;
extern int trace;
extern int graph_calls, graph_n, graph_bad, graph_tank2;
extern real graph_E0, graph_Eend, graph_Elast;

static void K(uint8_t k);
static void T(const char *s);
static void TE(const char *s);

/* Sistema: n tubos; cada tubo {tramo, L, D, f} con K; modo 0 adelante
 * (H) o 1 atras (tubo k, Q). Deja el resultado en pantalla. */
static void net_case(int np, int mode, const char *H, const char *kp, const char *Qk,
                     const char *const p[][5])
{
    int i;
    char b[8];
    T("2"); K(K_PGUP);
    snprintf(b, sizeof b, "%d", np);
    TE(b);                       /* numero de tubos: el formulario se rehace */
    {
        static int cur_mode = 0;     /* el formulario recuerda el modo */
        if (mode != cur_mode) { K(K_RIGHT); cur_mode = mode; }
    }
    K(K_DOWN);
    if (mode) { K(K_DOWN); TE(kp); TE(Qk); } else { TE(H); K(K_DOWN); K(K_DOWN); }
    TE("1E-6");                  /* nu */
    K(K_DOWN);                   /* energia del tanque 1: vacia */
    K(K_DOWN);                   /* metodo */
    for (i = 0; i < np; i++) {
        TE(p[i][0]); TE(p[i][1]); TE(p[i][2]);
        if (p[i][3][0]) TE(p[i][3]); else K(K_DOWN);
        K(K_DOWN);               /* ks vacio (f dado) */
        TE(p[i][4]);             /* el ENTER del ultimo campo calcula */
    }
}
void mock_script(const ui_key *k, int n);
void mock_fuzz(unsigned long seed, long n);
int mock_script_left(void);

static ui_key S[1024];
static int sn, fails, checks;

static void K(uint8_t k) { S[sn].k = k; S[sn].c = 0; sn++; }
static void T(const char *s) { while (*s) { S[sn].k = K_CHAR; S[sn].c = *s++; sn++; } }
static void TE(const char *s) { T(s); K(K_ENTER); }

extern int gfx_bad;
static int gfx_bad_now(void) { return gfx_bad; }

static void run(void)
{
    mock_script(S, sn);
    ui_quit = false;
    scr_main();
    sn = 0;
}

/* v2.0: el programa FLUJOS (mismo codigo, otro menu principal) */
static void runf(void)
{
    mock_script(S, sn);
    ui_quit = false;
    flujos_main();
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

/* algun renglon de la ultima pantalla contiene el texto */
static int scr_has(const char *t)
{
    int r;
    for (r = 0; r < UI_ROWS + 2; r++)
        if (strstr(scr[r], t))
            return 1;
    return 0;
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

/* sin plantillas sin resolver (para la ayuda, que no tiene OBSERVACIONES) */
static int memo_ok_noobs(void)
{
    uint8_t i;
    for (i = 0; i < view_n; i++)
        if (strchr(view_line[i], '?') || strchr(view_line[i], '{') ||
            strlen(view_line[i]) > UI_COLS)
            return 0;
    return 1;
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
    T("5"); K(K_CLEAR); T("6"); K(K_CLEAR); T("7"); K(K_CLEAR); T("8"); K(K_CLEAR);
    K(K_CLEAR);
    T("2"); K(K_CLEAR);
    T("3"); K(K_CLEAR);                  /* v2.0: Calcular f */
    T("5"); T("1"); K(K_CLEAR); T("2"); K(K_CLEAR); T("3"); K(K_CLEAR);
    T("4"); K(K_CLEAR); K(K_CLEAR);
    T("6"); K(K_CLEAR);
    T("8"); T("1"); { int i; for (i = 0; i < 40; i++) K(K_DOWN); } K(K_RIGHT); K(K_LEFT); K(K_F5);
    T("9"); K(K_F5); K(K_CLEAR);
    K(K_DOWN); K(K_DOWN); K(K_UP); K(K_UP);   /* menu con flechas */
    T("9");
    run();
    check(n_alerts - a0 == 0, "ningun aviso de modulo pendiente");
    check(!ui_quit && mock_script_left() == 0, "sale por la opcion Salir sin teclas de sobra");

    /* v2.0: la entrada 4 avisa que los flujos externos estan en FLUJOS */
    T("4");
    run();
    check(!strcmp(alert_title, "Flujos externos") && !strcmp(alert_l1, "Abra el programa FLUJOS"),
          "PERDIDAS 4: aviso de abrir FLUJOS");

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

    /* 5c. Fase 4: biblioteca y casos guardados */
    {
        mock_var *cv;
        int i;
        char nm[4];
        /* material desde el formulario A (F1): PEAD */
        T("1"); T("1"); K(K_PGUP); K(K_F1); K(K_DOWN); K(K_ENTER);
        run();
        check(scr_has("0.007") && !strcmp(last_title, "PERDIDAS DADO Q  (A)"), "MAT: PEAD pone ks = 0,007 mm");
        /* sumador con el conjunto del examen 2025 (12,8) */
        T("1"); T("1"); K(K_F2); K(K_F2); K(K_DOWN); K(K_ENTER); K(K_F5);
        run();
        check(scr_has("12.8") && !strcmp(last_title, "PERDIDAS DADO Q  (A)"), "SUMA K: conjunto 2025 = 12,8");
        /* sumador: agregar entrada (0,5) con cantidad 3 = 1,5 */
        T("1"); T("1"); K(K_F2); K(K_F2); K(K_DOWN); K(K_DOWN); K(K_DOWN); K(K_ENTER);
        K(K_F1); K(K_ENTER);   /* reemplaza por 2017 P4 (2,8) y agrega entrada 0,5 */
        run();
        check(scr_has("3.3"), "SUMA K: 2017 P4 + entrada = 3,3 en vivo");
        T("1"); T("1"); K(K_F2); K(K_F3); K(K_F5);
        run();
        check(scr_has("3.3") || scr_has("2.8") || scr_has("1"), "SUMA K: quitar linea no se cae");
        /* fluido para el formulario: agua 20 C */
        T("1"); T("1"); K(K_F3); K(K_DOWN); K(K_DOWN); K(K_DOWN); K(K_ENTER);
        run();
        check(scr_has("1.004E-6"), "FLUIDO: agua 20 C da nu = 1,004E-6");
        /* fluido por defecto desde la biblioteca: 5 C */
        T("5"); T("3"); K(K_PGUP); K(K_ENTER); K(K_ENTER);
        run();
        check(g_set.h.nu > 1.51e-6 && g_set.h.nu < 1.53e-6 && g_set.h.gamma > 9809 &&
              g_set.h.gamma < 9811 && g_set.h.pv > 871 && g_set.h.pv < 873,
              "FLUIDO por defecto: nu, gamma y pv a 5 C");
        settings_default(&g_set);
        /* lista propia de diametros: 250, 300, 350 */
        T("5"); T("4"); K(K_UP); K(K_ENTER); TE("250"); TE("300"); TE("350"); K(K_F5);
        run();
        cv = mock_find("PERDCAS", 0);
        check(diam_custom[0] == 250 && diam_custom[1] == 300 && diam_custom[2] == 350 &&
              cv && cv->exists, "lista propia guardada en PERDCAS");
        /* diseno P-17 con la lista propia: comercial 300 mm */
        T("1"); T("3"); K(K_PGUP); TE("200"); TE("76"); TE("1900"); TE("0.0015"); TE("12.8");
        TE("1E-6"); K(K_LEFT); K(K_F5);
        run();
        check(starts(view_value("D comercial"), "300 "), "D con lista propia: comercial 300 mm");
        /* guardar ese caso como P17 */
        T("1"); T("3"); K(K_F5); K(K_F3); T("P17"); K(K_ENTER); K(K_ENTER);
        run();
        check(cases_count() == 1 && !strcmp(alert_title, "Caso guardado"), "guardar caso P17");
        /* guardar el B actual como PRUEBA */
        T("1"); T("2"); K(K_F5); K(K_F3); T("PRUEBA"); K(K_ENTER); K(K_ENTER);
        run();
        check(cases_count() == 2, "guardar caso PRUEBA");
        /* cambiar datos y cargar P17: vuelve a 300 mm y Qd 200 */
        T("1"); T("3"); K(K_PGUP); TE("999");
        run();
        T("6"); K(K_ENTER);
        run();
        check(starts(view_value("D comercial"), "300 ") && has_line("Diametro de diseno"),
              "cargar P17 recalcula el resultado");
        /* nombre repetido: reemplaza sin crecer */
        T("1"); T("3"); K(K_F5); K(K_F3); T("P17"); K(K_ENTER); K(K_ENTER); K(K_ENTER);
        run();
        check(cases_count() == 2, "nombre repetido reemplaza el caso");
        /* "reinicio": archivar y volver a leer del AppVar */
        check(cases_archive() && cv->archived, "casos archivados al salir");
        check(cases_load() == 0 && cases_count() == 2 && diam_custom[1] == 300,
              "casos y lista propia se recuperan del AppVar");
        /* borrar PRUEBA (segundo de la lista) */
        T("6"); K(K_DOWN); K(K_F3); K(K_ENTER);
        run();
        check(cases_count() == 1, "borrar caso");
        /* lista llena */
        T("1"); T("2"); K(K_F5);
        for (i = 0; i < 19; i++) {
            nm[0] = 'C'; nm[1] = (char)('A' + i); nm[2] = 0;
            K(K_F3); T(nm); K(K_ENTER); K(K_ENTER);
        }
        K(K_F3); T("OTRO"); K(K_ENTER); K(K_ENTER);
        run();
        check(cases_count() == 20 && !strcmp(alert_l1, "Lista llena (20 casos)."), "lista llena a los 20 casos");
        /* nombre vacio no se guarda; CLEAR cancela */
        T("1"); T("2"); K(K_F5); K(K_F3); K(K_ENTER); K(K_CLEAR);
        run();
        check(cases_count() == 20, "nombre vacio o CLEAR no guardan");
        /* AppVar danado */
        cv->data[20] ^= 0x5A;
        check(cases_load() == 2 && cases_count() == 0, "PERDCAS danado: lista vacia, sin cierre");
        cv->len = 5;
        check(cases_load() == 2, "PERDCAS truncado: lista vacia");
        cv->exists = 0;
        check(cases_load() == 1, "sin PERDCAS: lista vacia");
        memset(diam_custom, 0, sizeof diam_custom);
    }

    /* 5d. Fase 5: sistemas serie/paralelo (S-01 a S-05) y graficas */
    {
        static const char *const s01[][5] = {
            { "1", "100", "150", "0.020", "0" }, { "2", "100", "100", "0.015", "5" },
            { "2", "100", "100", "0.015", "5" }, { "2", "100", "100", "0.015", "5" } };
        static const char *const s02[][5] = {
            { "1", "500", "150", "0.014", "0" }, { "1", "600", "100", "0.018", "0" },
            { "2", "700", "200", "0.015", "5" } };
        static const char *const s03[][5] = {
            { "1", "100", "100", "0.025", "0" }, { "2", "100", "100", "0.025", "0" },
            { "2", "100", "200", "0.020", "30" }, { "3", "100", "100", "0.025", "0" } };
        static const char *const s04[][5] = {
            { "1", "400", "200", "0.02", "0" }, { "2", "180", "100", "0.025", "0" },
            { "2", "50", "100", "0.025", "0" }, { "2", "400", "200", "0.02", "0" } };
        static const char *const s05[][5] = {
            { "1", "700", "300", "0.014", "5" }, { "2", "600", "150", "0.020", "0" },
            { "2", "500", "200", "0.011", "0" }, { "3", "600", "250", "0.028", "3" } };
        int g0;

        net_case(4, 0, "20", 0, 0, s01);
        run();
        check(starts(view_value("Q total"), "70.6") && starts(view_value("M total"), "4012.3") &&
              has_line("M = 2176.1") && has_line("Q 23.53"), "S-01: Q = 70,60; M = 4012,33; QB = 23,53");
        T("2"); K(K_F5); K(K_F1);
        run();
        check(memo_ok() && has_line("REDUCCION") && has_line("Q_B = sqrt(h/M)"), "S-01: memoria");
        g0 = graph_calls;
        T("2"); K(K_F5); K(K_F2);
        run();
        check(graph_calls == g0 + 1 && !graph_bad && graph_n == 2 && graph_tank2 &&
              graph_Elast - graph_Eend < 1e-3 && graph_Elast - graph_Eend > -1e-3,
              "S-01: grafica con 2 tramos que cierra en el tanque 2");

        net_case(3, 0, "20", 0, 0, s02);
        run();
        check(starts(view_value("Q total"), "51.5") && has_line("Q 39.8") && has_line("Q 11.65"),
              "S-02: Q = 51,53; QA = 39,88; QB = 11,65");
        net_case(4, 0, "24", 0, 0, s03);
        run();
        check(starts(view_value("Q total"), "23.7") && has_line("Q 18.05") && has_line("Q 5.708"),
              "S-03: Q = 23,76; Q3 = 18,05; Q2 = 5,71");
        net_case(4, 1, 0, "4", "40", s04);
        run();
        check(starts(view_value("H necesaria"), "12.6") && starts(view_value("H en kPa"), "124.2") &&
              starts(view_value("Q total"), "67.3"), "S-04 hacia atras: H = 12,67 m = 124,2 kPa");
        T("2"); K(K_F5); K(K_F1);
        run();
        check(memo_ok() && has_line("sube por el arbol"), "S-04: memoria hacia atras");
        net_case(4, 0, "75", 0, 0, s05);
        run();
        check(starts(view_value("Q total"), "167.5") && has_line("Q 41.54") && has_line("Q 125.98"),
              "S-05: Q = 167,53; QB = 41,55; QC = 125,98");
        /* f automatico: tubo con ks en vez de f */
        T("2"); K(K_PGUP); { int i; for (i = 0; i < 8 + 3; i++) K(K_DOWN); } K(K_DEL); K(K_DOWN);
        TE("0.0015"); K(K_F5); K(K_F1);
        run();
        check(memo_ok() && has_line("f auto"), "sistema con f automatico (ks)");
        /* errores: tubo inexistente y falta de datos */
        T("2"); K(K_PGUP); K(K_DOWN); K(K_RIGHT); K(K_DOWN); K(K_DOWN); TE("8"); K(K_F5);
        run();
        check(!strcmp(scr_msg, "Ese tubo no existe"), "tubo conocido inexistente: aviso");
        /* reducir a 1 tubo y volver a 8 sin cierres */
        T("2"); K(K_PGUP); TE("1"); K(K_PGUP); TE("8"); K(K_F5);
        run();
        check(!strcmp(last_title, "SISTEMA SERIE/PARALELO (G)"), "cambiar el numero de tubos (1 y 8)");
        /* grafica de tuberia simple: B (P-03 quedo en el formulario) y C */
        g0 = graph_calls;
        T("1"); T("2"); K(K_F5); K(K_F2);
        run();
        check(graph_calls == g0 + 1 && !graph_bad && graph_Elast > -1e-3 && graph_Elast < 1e-3,
              "grafica B: la LE llega a 0 (H - hT = 0)");
        T("1"); T("4"); K(K_F5); K(K_F2);
        run();
        check(!graph_bad && graph_n >= 1, "grafica C sin datos invalidos");
        T("1"); T("5"); K(K_F5); K(K_F2);
        run();
        check(!graph_bad && graph_n == 2, "grafica F con la valvula al final");
    }

    /* 5e. Fase 6: ayuda por temas y casos del curso */
    {
        int i, ok = 1;
        char t[2] = { 0, 0 };
        for (i = 0; i < 7; i++) {
            t[0] = (char)('1' + i);
            T("8"); T(t);
            run();
            if (view_n < 8 || !memo_ok_noobs()) {
                ok = 0;
                printf("  tema %d: %d lineas\n", i + 1, view_n);
            }
        }
        check(ok, "7 temas de ayuda desde PERDTXT, sin plantillas rotas");
        ok = 1;
        for (i = 0; i < EXAMPLES; i++) {
            int j;
            T("8"); T("9");
            K(K_PGUP); K(K_PGUP);   /* primer caso */
            for (j = 0; j < i; j++) K(K_DOWN);
            K(K_ENTER);
            run();
            if (strncmp(view_line[0], "RESULTADO", 9)) {
                ok = 0;
                printf("  caso %s: sin resultado (\"%s\" / \"%s\")\n", examples[i].name,
                       view_line[0], scr_msg);
            }
        }
        check(ok, "los 21 casos del curso cargan y calculan");
        T("8"); T("9"); K(K_PGUP); K(K_PGUP); for (i = 0; i < 10; i++) K(K_DOWN); K(K_ENTER);
        run();
        check(starts(view_value("D comercial"), "285.75") && starts(view_value("Qmax con D com."), "262.38"),
              "caso del curso P-17 da 285,75 mm y 262,38 l/s");
        T("8"); T("9"); K(K_PGUP); K(K_PGUP); for (i = 0; i < 19; i++) K(K_DOWN); K(K_ENTER);
        run();
        check(starts(view_value("H necesaria"), "12.66"), "caso del curso S-04 (hacia atras) da 12,67 m");
        settings_default(&g_set);
    }

    /* 5f. v2.0: Calcular f (prompt v2, sec. 8.5) */
    {
        char num[24];
        settings_default(&g_set);
        /* F-01, modo Re y ks/D */
        T("3"); K(K_PGUP); K(K_DOWN); TE("20000"); TE("1E-4"); K(K_F5);
        run();
        check(has_line("> f (Colebrook-White) = 0.026101") && has_line("0.026064") &&
              has_line("0.025907") && has_line("0.026054"), "F-01: f CW y tabla de 4 metodos");
        T("3"); K(K_F5); K(K_F1);
        run();
        check(has_line("ITERACIONES (COLEBROOK-WHITE)") && has_line("f_i") &&
              has_line("RESULTADO") && memo_ok_noobs(), "F-01: memoria con tabla de iteraciones de CW");
        /* F-02 */
        T("3"); K(K_PGUP); K(K_DOWN); TE("200000"); TE("1.5E-4"); K(K_F5);
        run();
        check(has_line("= 0.016763") && has_line("0.016773"), "F-02: f CW 0,016763 y SJ 0,016773");
        /* F-04, ks/D desde ks y D en mm */
        T("3"); K(K_PGUP); K(K_DOWN); TE("455180"); K(K_DEL); K(K_DOWN); TE("0.0015"); TE("200"); K(K_F5);
        run();
        check(has_line("= 0.013487"), "F-04: ks/D desde ks y D (mm)");
        /* F-03, modo datos de tuberia */
        T("3"); K(K_F2); K(K_DOWN); TE("200"); K(K_DOWN); TE("285.75"); TE("0.0015"); TE("1E-6"); K(K_F5);
        run();
        check(has_line("= 0.011989") && has_line("0.011958") && starts(view_value("v"), "3.11"),
              "F-03: modo tuberia, v, Re y f");
        T("3"); K(K_F5); K(K_F1);
        run();
        check(has_line("pi D^2/4") && has_line("v D/nu") && memo_ok_noobs(), "F-03: memoria con A, v y Re");
        /* F-05a laminar */
        T("3"); K(K_PGUP); K(K_DOWN); TE("0.02"); K(K_DOWN); TE("20"); TE("0"); TE("1E-6"); K(K_F5);
        run();
        check(has_line("laminar") && has_line("= 0.050265"), "F-05a: laminar f = 64/Re");
        /* F-05b transicion (vuelve al modo 1) */
        T("3"); K(K_F2); K(K_DOWN); TE("3000"); TE("1E-4"); K(K_F5);
        run();
        check(has_line("transicion"), "F-05b: aviso de transicion");
        /* F-05c Re = 0: mensaje, sin cerrar */
        T("3"); K(K_PGUP); K(K_DOWN); TE("0");
        run();
        check(starts(scr_msg, "Debe ser mayor que 0"), "F-05c: Re = 0 rechazado");
        /* USAR f hacia el tipo A (F4 CALC f) */
        pin.sf = 0;
        T("1"); T("1"); K(K_F4); K(K_PGUP); K(K_DOWN); TE("20000"); K(K_F5); K(K_F2); K(K_ENTER);
        run();
        fmt_real(pin.f, g_set.dec, num);
        check(pin.sf && !strcmp(num, "0.026101") && scr_has("0.026101"),
              "USAR f copia el valor mostrado al tipo A");
        /* USAR f hacia el campo f del tubo A de un sistema (F1 CALC f) */
        T("2"); K(K_PGUP); { int i; for (i = 0; i < 11; i++) K(K_DOWN); }
        K(K_F1); K(K_F5); K(K_F2); K(K_ENTER);
        run();
        check(scr_has("0.026101") && !strcmp(alert_title, "USAR f"), "USAR f llega al f dado del sistema");
        T("2"); K(K_PGUP); K(K_F1);
        run();
        check(starts(scr_msg, "Ubique el cursor"), "CALC f fuera de un campo f: aviso");
        pin.sf = 0;
        settings_default(&g_set);
    }

    /* 5g. v2.0 fase 2: catalogo de CD, aire y PERDCFG 1.0 -> 2.0 */
    {
        extern int gfx_draws, gfx_bad, gfx_missing;
        extern real cat_sel_cd;
        int d0;
        settings_default(&g_set);
        d0 = gfx_draws;
        T("4");
        runf();
        check(scr_has("COEFICIENTES DE ARRASTRE") && scr_has("Esfera lisa") &&
              gfx_draws - d0 >= 10 && !gfx_bad, "catalogo: lista con 10 miniaturas por pagina");
        T("4"); K(K_PGUP); K(K_PGUP); K(K_ENTER);
        runf();
        check(scr_has("CD = 0.5") && scr_has("pi D^2/4") && !gfx_bad, "detalle de la esfera");
        /* cilindro finito: tabla L/D, L/D = 15 interpola 0,9167 */
        T("4"); K(K_PGUP); K(K_PGUP); K(K_ENTER); { int i; for (i = 0; i < 10; i++) K(K_DOWN); }
        K(K_F4); TE("15");
        runf();
        check(starts(alert_l1, "CD = 0.91667") && strstr(alert_l1, "interpolado") != 0,
              "TABLA: L/D = 15 interpola 0.9167 (vecinos 10 y 40)");
        T("4"); K(K_PGUP); K(K_PGUP); K(K_ENTER); { int i; for (i = 0; i < 10; i++) K(K_DOWN); }
        K(K_F4); TE("1000");
        runf();
        check(starts(alert_l1, "CD = 1.2"), "TABLA: L/D >= 1000 usa el valor infinito 1.2");
        /* EDITAR y restaurar */
        T("4"); K(K_PGUP); K(K_PGUP); K(K_ENTER); K(K_F3); TE("0.47");
        runf();
        check(g_set.cd_user[0] > 0.469 && g_set.cd_user[0] < 0.471 && g_set_dirty,
              "EDITAR guarda un CD propio (esfera 0.47)");
        T("4"); K(K_PGUP); K(K_PGUP); K(K_ENTER);
        runf();
        check(scr_has("(catal. 0.5)"), "el detalle muestra el valor del catalogo");
        T("4"); K(K_PGUP); K(K_PGUP); K(K_ENTER); K(K_F3); K(K_F1);
        runf();
        check(g_set.cd_user[0] == 0, "F1 CATALOGO restaura el valor");
        /* comparar y ranking */
        T("4"); K(K_PGUP); K(K_PGUP); K(K_F2); K(K_DOWN); K(K_DOWN); K(K_F2); K(K_F3);
        runf();
        check(scr_has("COMPARAR FIGURAS") && scr_has("Fig 2 / fig 1: 2.34") && !gfx_bad,
              "COMPARAR: hemisferio plano 2.34 veces la esfera");
        T("4"); K(K_F1); K(K_F4);
        runf();
        check(scr_has("13 Cuerpo aerodinamico") && scr_has("16 Barra cuadrada"),
              "RANKING de menor a mayor CD");
        /* USAR desde un formulario */
        mock_script(S, 0);
        K(K_PGUP); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); K(K_DOWN); K(K_ENTER); K(K_F1);
        mock_script(S, sn);
        ui_quit = false;
        check(scr_cat(1) == 4 && cat_sel_cd > 1.29 && cat_sel_cd < 1.31,
              "USAR devuelve el paracaidas con CD 1.3");
        sn = 0;
        /* sin PERDGFX: aviso y sin cierre */
        gfx_missing = 1;
        T("4"); K(K_PGUP); K(K_PGUP); K(K_ENTER);
        runf();
        check(!strcmp(scr_msg, "Falta PERDGFX: sin ilustraciones"), "sin PERDGFX: aviso, sin cierre");
        gfx_missing = 0;
        /* aire por defecto desde la biblioteca */
        T("5"); T("3"); K(K_PGDN); K(K_UP); K(K_ENTER); K(K_ENTER);
        run();
        check(g_set.rho_air > 1.2249 && g_set.rho_air < 1.2251 && g_set.nu_air > 1.459e-5 &&
              g_set.h.gamma > 9809, "fluido: aire 15 C va a rho y nu del aire, gamma intacto");
        /* PERDCFG en formato 1.0: se conservan los ajustes */
        {
            app_settings_v1 v1;
            uint8_t c = 0x5A, *p = (uint8_t *)&v1;
            size_t i;
            settings_default(&g_set);
            v1.h = g_set.h;
            v1.dec = 4;
            v1.h.method = FM_SJ;
            mock_file[0] = 'P'; mock_file[1] = 'R'; mock_file[2] = 'D';
            mock_file[3] = 1; mock_file[4] = (uint8_t)sizeof v1;
            memcpy(mock_file + 5, &v1, sizeof v1);
            for (i = 0; i < sizeof v1; i++)
                c = (uint8_t)((c << 1 | c >> 7) ^ p[i]);
            mock_file[5 + sizeof v1] = c;
            mock_file_len = 6 + sizeof v1;
            mock_file_exists = 1;
            g_set_dirty = false;
            check(settings_load() == 0 && g_set.dec == 4 && g_set.h.method == FM_SJ &&
                  g_set.rho_air > 1.19 && g_set.cd_weir > 0.59 && g_set_dirty,
                  "PERDCFG 1.0 migra: dec y metodo se conservan, lo nuevo por defecto");
            check(settings_save() && settings_load() == 0 && g_set.dec == 4 &&
                  mock_file[3] == 2, "se guarda y relee en formato 2.0");
        }
        settings_default(&g_set);
    }

    /* 5h. v2.0 fase 3: arrastre y sustentacion (AR-01 a AR-06) */
    {
        settings_default(&g_set);
        /* AR-01 paracaidista: aire, W = 950, figura 5 (CD 1.3), D = 8 */
        T("1"); T("2"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN);
        TE("950"); K(K_DOWN); K(K_DOWN); TE("5"); TE("8"); K(K_F5);
        runf();
        check(has_line("> v terminal = 4.9224") && has_line("2625"), "AR-01: v terminal 4.922 m/s");
        T("1"); T("2"); K(K_F5); K(K_F1);
        runf();
        check(has_line("sqrt[2(W-B)/(rho CD A)]") && has_line("A = pi D^2/4") && memo_ok_noobs(),
              "AR-01: memoria con la formula y el area de la figura");
        /* AR-03b cubo de arista en agua: A = sqrt(2) D^2 */
        T("1"); T("2"); K(K_PGUP); K(K_RIGHT); K(K_DOWN); K(K_DOWN); K(K_DOWN);
        TE("19.8"); TE("0.001"); K(K_DOWN); TE("10"); TE("0.1"); K(K_F5);
        runf();
        check(has_line("> v terminal = 1.3289") && starts(view_value("B"), "9.81"), "AR-03b: cubo de arista 1.329 m/s con empuje");
        /* AR-03a: A = D^2 tecleada */
        T("1"); T("2"); K(K_PGDN); K(K_UP); TE("0.01"); K(K_F5);
        runf();
        check(has_line("> v terminal = 1.5803"), "AR-03a: A = D^2 da 1.580 m/s");
        T("1"); T("2"); K(K_PGDN); K(K_UP); K(K_DEL); K(K_F5);
        runf();
        /* AR-02a torre y tanque: aire, 100 km/h */
        T("1"); T("3"); K(K_PGUP); K(K_DOWN); K(K_LEFT); K(K_DOWN); K(K_DOWN); K(K_DOWN);
        TE("100"); K(K_RIGHT); K(K_DOWN);
        TE("0.9+5/30*0.1"); TE("11"); TE("2"); TE("30"); K(K_DOWN); TE("15"); K(K_DOWN);
        TE("0.5"); TE("1"); TE("12"); K(K_DOWN); K(K_DOWN); TE("36"); K(K_F5);
        runf();
        check(has_line("> M en la base = 1324.4") && has_line("> ycp = M/F = 25.64") &&
              has_line("crisis"), "AR-02a: M = 1324 kN m, ycp 25.65 m y aviso de crisis");
        T("1"); T("3"); K(K_F5); K(K_F1);
        runf();
        check(has_line("F1 = CD q A = 25.46") && has_line("F2 = CD q A = 26.17") && memo_ok_noobs(),
              "AR-02a: memoria con un renglon por cuerpo");
        T("1"); T("3"); K(K_F5); K(K_F2);
        runf();
        check(!gfx_bad_now(), "AR-02a: esquema de fuerzas dentro de la pantalla");
        /* AR-04 avion: paso 1 (CL) y paso 2 (lectura CD = 0.0088) */
        T("1"); T("4"); K(K_PGUP); TE("3.9E6"); TE("480"); K(K_RIGHT); K(K_DOWN);
        TE("10675"); K(K_DOWN); TE("2"); TE("180.8"); TE("1"); TE("5.28"); K(K_F5);
        runf();
        check(has_line("> CL necesario = 0.8831") && has_line("Lea alfa y CD"), "AR-04 paso 1: CL = 0.8831");
        T("1"); T("4"); K(K_PGDN); K(K_UP); TE("0.0088"); K(K_F5);
        runf();
        check(has_line("> Empuje T = 306.2") && has_line("D fuselaje      = 267.4"),
              "AR-04 paso 2: T = 306.27 kN, D fus 267.41 kN");
        /* AR-06 placa plana en aire: turbulento y mixto */
        T("1"); T("5"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); K(K_DOWN);
        TE("10"); K(K_LEFT); K(K_LEFT); K(K_DOWN); TE("2"); TE("1"); K(K_DOWN); K(K_RIGHT); K(K_RIGHT);
        K(K_F5);
        runf();
        check(has_line("> FD = 0.5289") && has_line("Re > 5E5: Cf laminar no aplica"),
              "AR-06: FD turbulento 0.529 N y aviso laminar");
        T("1"); T("5"); K(K_PGDN); K(K_RIGHT); K(K_F5);
        runf();
        check(has_line("> FD = 0.3721"), "AR-06: FD mixto 0.372 N");
        /* AR-05 Stokes: esfera de 1 mm a 1 mm/s en agua */
        T("1"); T("5"); K(K_PGUP); K(K_RIGHT); K(K_DOWN); K(K_RIGHT); K(K_DOWN); K(K_DOWN);
        K(K_DOWN); TE("0.001"); K(K_DOWN); TE("0.001"); K(K_F5);
        runf();
        check(has_line("> FD = 9.42") && has_line("E-9") && has_line("Stokes valido"),
              "AR-05: Stokes FD = 9.425E-9 N");
        /* errores: cuerpo que flota */
        T("1"); T("2"); K(K_PGUP); K(K_RIGHT); K(K_DOWN); K(K_DOWN); K(K_DOWN);
        TE("5"); TE("0.001"); K(K_F5);
        runf();
        check(starts(scr_msg, "W <= B"), "W < B: mensaje, sin cerrar");
        settings_default(&g_set);
    }

    /* 5i. v2.0 fase 4: vertedores y orificios (VE-01 a VE-08) en FLUJOS */
    {
        settings_default(&g_set);
        /* VE-03: triangular 90, Q = 200 l/s -> H */
        T("2"); T("1"); K(K_PGUP); K(K_DOWN); K(K_RIGHT); K(K_DOWN); K(K_DOWN);
        TE("90"); K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("200"); K(K_F5);
        runf();
        check(has_line("> H = 0.45689"), "VE-03: H = 0.4569 m");
        T("2"); T("1"); K(K_F5); K(K_F1);
        runf();
        check(has_line("(Q/K)^(2/5)") && has_line("tan(theta/2)") && memo_ok_noobs(),
              "VE-03: memoria con la formula inversa");
        /* VE-05: triangular 60, Q = 16 l/s */
        T("2"); T("1"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("60");
        K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("16"); K(K_F5);
        runf();
        check(has_line("> H = 0.2072"), "VE-05: H = 0.2072 m");
        /* VE-01: triangular 90 en 1.4 m + 3 orificios de 0.2 m en 0.1 m, h = 2 */
        T("2"); T("2"); K(K_PGUP); K(K_DOWN); K(K_DOWN); TE("2"); K(K_DOWN); K(K_DOWN);
        K(K_DOWN); K(K_DOWN); TE("90"); K(K_DOWN); TE("1.4"); K(K_DOWN);
        K(K_RIGHT); K(K_RIGHT); K(K_DOWN); TE("3"); TE("0.2"); K(K_DOWN); TE("0.1"); K(K_F5);
        runf();
        check(has_line("> Q total = 0.7405"), "VE-01: Q total = 0.7405 m3/s");
        T("2"); T("2"); K(K_F5); K(K_F1);
        runf();
        check(has_line("1 Triangular x1") && has_line("2 Orificio circ. x3") && memo_ok_noobs(),
              "VE-01: memoria con un renglon por elemento");
        T("2"); T("2"); K(K_F5); K(K_F2);
        runf();
        check(!gfx_bad_now(), "VE-01: esquema dentro de la pantalla");
        /* VE-02: Q = 500 l/s -> nivel */
        T("2"); T("2"); K(K_PGUP); K(K_DOWN); K(K_RIGHT); K(K_DOWN); K(K_DOWN); TE("500"); K(K_F5);
        runf();
        check(has_line("> Nivel h = 1.8287"), "VE-02: h = 1.829 m");
        /* VE-06: triangular 60 en 0 + rectangular 1.3 m en 0.2072, Q = 36 l/s */
        T("2"); T("2"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("36"); K(K_DOWN);
        K(K_DOWN); K(K_DOWN); TE("60"); K(K_DOWN); TE("0"); K(K_DOWN);
        K(K_LEFT); K(K_DOWN); TE("1"); TE("1.3"); K(K_DOWN); TE("0.20724"); K(K_F5);
        runf();
        check(has_line("> Nivel h = 0.2391") && has_line("Q=0.02288"),
              "VE-06: h = 0.2391 m, Q tri 22.88 l/s");
        /* VE-08: Q = 4/3 m3/s, nivel aguas arriba 1 m -> h0 */
        T("2"); T("1"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("90");
        K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("4/3"); K(K_RIGHT); K(K_DOWN); TE("1"); K(K_F5);
        runf();
        check(has_line("> H = 0.97583") && has_line("> h0 = h - H = 0.0241"),
              "VE-08: H = 0.9758 m y h0 = 0.0242 m");
        /* VE-07: perfil v = 2 y^2, b = 2, h = 1 */
        T("2"); T("3"); K(K_PGUP); K(K_DOWN); TE("2"); TE("1"); TE("2"); TE("2"); K(K_F5);
        runf();
        check(has_line("> Q = 1.33333"), "VE-07: Q = 1.3333 m3/s");
        T("2"); T("3"); K(K_PGUP); K(K_RIGHT); K(K_DOWN); K(K_DOWN); K(K_DOWN);
        TE("0"); TE("0"); TE("0.25"); TE("0.125"); TE("0.5"); TE("0.5"); TE("0.75"); TE("1.125");
        TE("1"); TE("2"); K(K_F5);
        runf();
        check(has_line("> Q = 1.33333"), "VE-07: Q por puntos (Simpson) = 1.3333");
        T("2"); T("3"); K(K_F5); K(K_F1);
        runf();
        check(has_line("Simpson"), "VE-07: la memoria dice Simpson");
        /* aguas abajo: Q = 4/3, b = 2, h1 = 1; tirantes alternos */
        T("2"); T("4"); K(K_PGUP); K(K_RIGHT); K(K_DOWN); TE("4/3"); K(K_DOWN); TE("2"); TE("1"); K(K_F5);
        runf();
        check(has_line("> v1 = 0.66666") && has_line("> h2 supercrit. = 0.1622"),
              "VE-10: v1 = 0.667 m/s y h2 supercritico 0.1623 m");
        /* orificio con carga parcial */
        T("2"); T("1"); K(K_PGUP); K(K_RIGHT); K(K_RIGHT); K(K_DOWN); K(K_LEFT); K(K_DOWN);
        K(K_DOWN); TE("0.4"); K(K_DOWN); K(K_DOWN); TE("0.1"); K(K_F5);
        runf();
        check(has_line("borde superior"), "orificio con H < d/2: aviso de carga parcial");
        settings_default(&g_set);
    }

    /* 5j. v2.0 fase 5: canales y medicion (EX-01 a EX-03) en FLUJOS */
    {
        settings_default(&g_set);
        /* EX-01a: Venturi 285.75 mm, D2/D1 = 0.6, Q = 200 l/s, S = 4 */
        T("3"); T("1"); K(K_PGUP); TE("285.75"); K(K_DOWN); TE("0.6"); TE("200");
        K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("4"); K(K_F5);
        runf();
        check(has_line("> dp = p1 - p2 = 3266") && has_line("> h manometro = 1.1097"),
              "EX-01a: dp = 32 660 Pa y h = 1.110 m (S - 1)");
        T("3"); T("1"); K(K_PGDN); K(K_RIGHT); K(K_F5);
        runf();
        check(has_line("> h manometro = 0.8323") && has_line("examen"),
              "EX-01a: h = 0.8323 m con la convencion del examen");
        T("3"); T("1"); K(K_F5); K(K_F1);
        runf();
        check(has_line("gamma (v2^2 - v1^2)/(2g)") && has_line("dp/(S gamma)") && memo_ok_noobs(),
              "EX-01: memoria con Bernoulli y el manometro");
        /* EX-01b: Q = 260.64 l/s */
        T("3"); T("1"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("260.64"); K(K_F5);
        runf();
        check(has_line("> dp = p1 - p2 = 5546") && has_line("> h manometro = 1.4135"),
              "EX-01b: dp = 55 468 Pa, h = 1.414 m (S)");
        /* EX-02: salto, Q = 12, b = 2, y1 = 0.4 */
        T("3"); T("2"); K(K_PGUP); TE("12"); TE("2"); K(K_DOWN); TE("0.4");
        runf();
        check(has_line("> y2 = 4.0881") && has_line("> dE = E1 - E2 = 7.669") &&
              has_line("> P disipada = 902.9"), "EX-02: y2 = 4.088 m, dE = 7.670 m, P = 902.9 kW");
        T("3"); T("2"); K(K_F5); K(K_F1);
        runf();
        check(has_line("sqrt(1 + 8 Fr1^2)") && memo_ok_noobs(), "EX-02: memoria con cantidad de movimiento");
        T("3"); T("2"); K(K_PGDN); TE("2");
        runf();
        check(starts(scr_msg, "Fr1 <= 1"), "EX-02: Fr1 <= 1, sin salto: mensaje");
        T("3"); T("2"); K(K_PGDN); K(K_UP); K(K_RIGHT); K(K_DOWN); TE("4.0881958");
        runf();
        check(has_line("> y1 = 0.4 m") || has_line("> y1 = 0.3999"), "EX-02: dado y2 vuelve y1 = 0.4 m");
        /* EX-03a: chorro, H = 7.5, L = 5, D = 30 mm, ks = 0.045 mm, SumK = 0 */
        T("3"); T("3"); K(K_PGUP); TE("7.5"); TE("5"); TE("30"); TE("0.045"); TE("1.007E-6");
        K(K_F5);
        runf();
        check(has_line("> Q = 4.3906") && has_line("> h max = 0.4916") && has_line("> Alcance R = 3.40"),
              "EX-03a: Q = 4.391 l/s, h max = 0.4916 m, R = 3.406 m");
        T("3"); T("3"); K(K_PGDN); K(K_UP); K(K_RIGHT); K(K_F5);
        runf();
        check(has_line("> Q = 3.89") && has_line("> h max = 0.387"), "EX-03b: con salida Q = 3.899 l/s");
        T("3"); T("3"); K(K_F5); K(K_F1);
        runf();
        check(has_line("Caudal maximo (tuberia tipo B)") && memo_ok_noobs(), "EX-03: memoria con el tipo B");
        /* EX-4 desde el menu de canales */
        T("3"); T("4");
        runf();
        check(scr_has("PLACA PLANA Y STOKES"), "Canales 4: placa plana y Stokes");
        settings_default(&g_set);
    }

    /* 5k. v2.0 fase 6: Mis casos de todos los tipos y PERDCAS 1.0 -> 2.0 */
    {
        mock_var *cv = mock_find("PERDCAS", 1);
        uint8_t *d = cv->data, ck = 0x3C;
        size_t k = 0, j;
        real cust[DIAM_CUSTOM_MAX];
        pipe_inputs p1;
        settings_default(&g_set);
        /* PERDCAS 1.0 con un caso tipo D (P-17) */
        memset(cust, 0, sizeof cust);
        memset(&p1, 0, sizeof p1);
        p1.Q = 200; p1.sQ = 1; p1.H = 76; p1.sH = 1; p1.L = 1900; p1.sL = 1;
        p1.ks = 0.0015; p1.sks = 1; p1.K = 12.8; p1.sK = 1; p1.nu = 1e-6; p1.snu = 1;
        cust[0] = 250;
        d[k++] = 'P'; d[k++] = 'C'; d[k++] = 'S'; d[k++] = 1;
        d[k++] = (uint8_t)(sizeof p1 & 0xFF); d[k++] = (uint8_t)(sizeof p1 >> 8);
        d[k++] = DIAM_CUSTOM_MAX;
        memcpy(d + k, cust, sizeof cust); k += sizeof cust;
        d[k++] = 1;
        memcpy(d + k, "P17\0\0\0\0\0\0", 9); k += 9;
        d[k++] = PT_D;
        memcpy(d + k, &p1, sizeof p1); k += sizeof p1;
        for (j = 0; j < k; j++)
            ck = (uint8_t)((ck << 1 | ck >> 7) ^ d[j]);
        d[k++] = ck;
        cv->len = k;
        cv->exists = 1;
        check(cases_load() == 0 && cases_count() == 1 && diam_custom[0] == 250 && cv->data[3] == 2,
              "PERDCAS 1.0 se lee y pasa al formato 2.0");
        check(cases_load() == 0 && cases_count() == 1, "PERDCAS 2.0 se vuelve a leer");
        T("6"); K(K_ENTER);
        run();
        check(has_line("Diametro de diseno"), "el caso 1.0 (tipo D) carga y calcula");
        /* AR-2: calcular, guardar como PARA, cambiar datos y cargar: el
         * resultado cargado debe ser el mismo que el guardado */
        {
            char vt[48] = "";
            uint8_t q;
            T("1"); T("2"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN);
            TE("950"); K(K_DOWN); K(K_DOWN); TE("5"); TE("8"); K(K_F5); K(K_F3); T("PARA");
            K(K_ENTER); K(K_ENTER);
            runf();
            for (q = 0; q < view_n; q++)
                if (!strncmp(view_line[q], "> v terminal", 12)) {
                    strcpy(vt, view_line[q]);
                    break;
                }
            check(cases_count() == 2 && !strcmp(alert_title, "Caso guardado") && vt[0],
                  "AR-2 guardado en Mis casos");
            T("1"); T("2"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("100"); K(K_F5);
            runf();
            T("5"); K(K_PGUP); K(K_DOWN); K(K_ENTER);
            runf();
            check(vt[0] && has_line(vt), "AR-2 cargado desde Mis casos da el mismo resultado");
        }
        /* VE-4 y EX-2 */
        T("2"); T("2"); K(K_F5); K(K_F3); T("VE01"); K(K_ENTER); K(K_ENTER);
        runf();
        T("3"); T("2"); K(K_F5); K(K_F3); T("SALTO"); K(K_ENTER); K(K_ENTER);
        runf();
        check(cases_count() == 4, "VE y EX guardados");
        T("5"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_ENTER);
        runf();
        check(has_line("Q total"), "caso de vertedores carga y calcula");
        T("5"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); K(K_ENTER);
        runf();
        check(has_line("> y2 = 4.088") || has_line("> y1 = 0.4"), "caso del salto carga y calcula");
        /* Calcular f: guardar el calculo vigente y cargarlo */
        {
            char fl[48] = "";
            uint8_t q;
            T("3"); K(K_F5); K(K_F3); T("F01"); K(K_ENTER); K(K_ENTER);
            run();
            for (q = 0; q < view_n; q++)
                if (!strncmp(view_line[q], "> f (", 5)) {
                    strcpy(fl, view_line[q]);
                    break;
                }
            T("6"); K(K_PGDN); K(K_ENTER);
            run();
            check(cases_count() == 5 && fl[0] && has_line(fl),
                  "caso de Calcular f guardado y cargado con el mismo f");
        }
        /* reinicio: archivar y releer */
        check(cases_archive() && cases_load() == 0 && cases_count() == 5,
              "los 5 casos de tipos distintos se recuperan del AppVar");
        cv->data[cv->len / 2] ^= 0x33;
        check(cases_load() == 2 && cases_count() == 0, "PERDCAS 2.0 danado: lista vacia, sin cierre");
        cv->exists = 0;
        cases_load();
        settings_default(&g_set);
    }

    /* 5l. v2.0 fase 6: casos del curso y ayuda nueva */
    {
        static const char *const want[17] = {
            "> v terminal = 4.9224", "> M en la base = 1324.4", "> v terminal = 1.3289",
            "> CL necesario = 0.8831", "> FD = 9.42", "> FD = 0.5289",
            "> Q total = 0.7405", "> Nivel h = 1.8287", "> H = 0.45689", "> H = 0.5079",
            "> H = 0.2072", "> Nivel h = 0.2391", "> Q = 1.33333", "> h0 = h - H = 0.0241",
            "> dp = p1 - p2 = 3266", "> y2 = 4.0881", "> Q = 4.3906"
        };
        static const char *const fwant[5] = {
            "= 0.026101", "= 0.016763", "= 0.011989", "= 0.013487", "= 0.050265"
        };
        int i, j, ok = 1;
        settings_default(&g_set);
        for (i = 0; i < 17; i++) {
            T("7"); T("5"); K(K_PGUP); K(K_PGUP);
            for (j = 0; j < i; j++) K(K_DOWN);
            K(K_ENTER);
            runf();
            if (!has_line(want[i])) {
                ok = 0;
                printf("  caso del curso FLUJOS %d: falta [%s] (%s)\n", i + 1, want[i], scr_msg);
            }
        }
        check(ok, "los 17 casos del curso de FLUJOS cargan y dan su valor (AR, VE, EX)");
        ok = 1;
        for (i = 0; i < 5; i++) {
            T("8"); T("9"); K(K_PGDN);
            for (j = 0; j < 4 - i; j++) K(K_UP);
            K(K_ENTER);
            run();
            if (!has_line(fwant[i])) {
                ok = 0;
                printf("  caso F-0%d: falta [%s]\n", i + 1, fwant[i]);
            }
        }
        check(ok, "los casos F-01 a F-05 de PERDIDAS dan su f");
        T("8"); T("8");
        run();
        check(view_n > 10 && memo_ok_noobs() && has_line("Swamee-Jain"), "PERDIDAS: ayuda Factor de friccion f");
        ok = 1;
        for (i = 0; i < 4; i++) {
            char t[2] = { (char)('1' + i), 0 };
            T("7"); T(t);
            runf();
            if (view_n < 8 || !memo_ok_noobs())
                ok = 0;
        }
        check(ok, "FLUJOS: ayuda de arrastre, vertedores, canales y erratas");
        T("7"); T("4");
        runf();
        check(has_line("2025 P4c"), "erratas de la v2.0 en la ayuda");
        settings_default(&g_set);
    }

    /* 6. Ajustes: decimales, validaciones y archivo */
    T("7"); K(K_PGUP); K(K_DOWN); K(K_DOWN); K(K_DOWN); K(K_DOWN); TE("3"); K(K_F5);
    run();
    check(g_set.dec == 3 && g_set_dirty, "decimales = 3 y ajustes por guardar");
    T("7"); K(K_PGUP); K(K_DOWN); TE("50");
    run();
    check(!strcmp(scr_msg, "Fuera del rango permitido"), "g = 50 rechazado");
    T("7"); K(K_PGUP); { int i; for (i = 0; i < 8; i++) K(K_DOWN); } TE("0.1"); K(K_F5);
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
    T("7"); K(K_PGUP); K(K_F1); K(K_ENTER); K(K_F5);
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
                if (seed & 1) scr_main(); else flujos_main();
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
