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

static const char *const method_names[FM_COUNT] = {
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
/* Tipo A: perdidas dado el caudal (ejemplo del patron en la fase 2)   */
/* ================================================================== */
static struct {
    real Q, D, L, ks, K, nu, f;
    uint8_t sQ, sD, sL, sks, sK, snu, sf;
} pa = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0 };

static void result_A(const hydro_pipe *p, const hydro_state *s,
                     const hydro_cfg *c)
{
    static const char *const fk[5] = { "MEMORIA", "", "", "", "VOLVER" };
    char w[8][41];
    uint8_t i, nw;
    uint8_t k;

    view_clear();
    view_add("RESULTADO  Perdidas dado Q", C_TITLE);
    view_add_sep();
    view_add_val("Q", s->Q * 1000, "l/s");
    view_add_val("v", s->v, "m/s");
    view_add_val("Re", s->Re, 0);
    view_add_val(p->f_fixed > 0 ? "f (dado)" : "f", s->f, 0);
    if (p->f_fixed <= 0)
        view_add(s->regime == REG_LAMINAR ? "   (laminar: f = 64/Re)"
                 : (c->method == FM_CW ? "   (Colebrook-White)"
                    : method_names[c->method]), C_GRAY);
    view_add_val("v^2/2g", s->hv2g, "m");
    view_add_val("hf", s->hf, "m");
    view_add_val("hm", s->hm, "m");
    view_add_val("hT = hf + hm", s->hT, "m");
    view_add_val("L/D", s->LD, 0);
    view_add_sep();
    nw = warn_texts(s->warn, c, g_set.dec, w, 8);
    if (!nw)
        view_add(" Sin advertencias", C_OK);
    for (i = 0; i < nw; i++)
        view_add(w[i], C_WARN);
    for (;;) {
        k = view_run("TUBERIA SIMPLE  A", fk);
        if (k == K_F1) {
            todo_alert("Memoria de calculo", 3);
            continue;
        }
        if (k == K_MODE) {
            scr_settings();
            continue;
        }
        break;
    }
}

static void scr_pipe_A(void)
{
    static uint8_t cur;
    form_field f[] = {
        { "Caudal Q", "l/s", &pa.Q, 0, &pa.sQ, FF_POS, 0, 0, 0, 0 },
        { "Diametro D", "mm", &pa.D, 0, &pa.sD, FF_POS, 0, 0, 0, 0 },
        { "Longitud L", "m", &pa.L, 0, &pa.sL, FF_POS, 0, 0, 0, 0 },
        { "Rugosidad ks", "mm", &pa.ks, 0, &pa.sks, FF_NONNEG, 0, 0, 0, 0 },
        { "Suma K", 0, &pa.K, 0, &pa.sK, FF_NONNEG, 0, 0, 0, 0 },
        { "Viscosidad nu", "m2/s", &pa.nu, 0, &pa.snu, FF_POS, 0, 0, 0, 0 },
        { "f dado (opc.)", 0, &pa.f, 0, &pa.sf, FF_POS | FF_OPT, 0, 0, 0, 0 },
        { "Metodo de f", 0, 0, &g_set.h.method, 0, FF_CHOICE, method_names, FM_COUNT, 0, 0 },
    };
    form_t fm;
    uint8_t k, m0;
    hydro_cfg c;
    hydro_pipe p;
    hydro_state s;
    int e;

    if (!pa.snu) {
        pa.nu = g_set.h.nu;
        pa.snu = 1;
    }
    memset(&fm, 0, sizeof fm);
    fm.title = "PERDIDAS DADO Q  (A)";
    fm.page = "1/1";
    fm.f = f;
    fm.n = sizeof f / sizeof f[0];
    fm.cur = cur;
    fm.fk[0] = "MAT";
    fm.fk[1] = "SUMA K";
    fm.fk[2] = "FLUIDO";
    fm.fk[3] = "AJUSTES";
    fm.fk[4] = "CALC";
    m0 = g_set.h.method;
    for (;;) {
        k = form_run(&fm);
        if (k == K_QUIT || k == K_CLEAR)
            break;
        if (k == K_F1) { todo_alert("Biblioteca de materiales", 4); continue; }
        if (k == K_F2) { todo_alert("Sumador de accesorios", 4); continue; }
        if (k == K_F3) { todo_alert("Selector de fluido", 4); continue; }
        if (k == K_F4 || k == K_MODE) { scr_settings(); continue; }
        if (k == K_F5 || k == K_ENTER) {
            if (!form_check(&fm))
                continue;
            c = g_set.h;
            c.nu = pa.nu;
            p.D = pa.D / 1000;
            p.L = pa.L;
            p.ks = pa.ks / 1000;
            p.sumK = pa.K;
            p.f_fixed = pa.sf ? pa.f : 0;
            e = hydro_pipe_state(&p, pa.Q / 1000, &c, &s);
            if (e) {
                fm.msg = hydro_err_text(e);
                fm.msg_color = C_ERR;
                continue;
            }
            result_A(&p, &s, &c);
            if (ui_quit)
                break;
        }
    }
    cur = fm.cur;
    if (g_set.h.method != m0)
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
        if (r == 0)
            scr_pipe_A();
        else
            todo_alert(items[r], 3);
    }
}

static void scr_library_menu(void)
{
    static const char *const items[] = {
        "Materiales (ks, C_H)",
        "Accesorios (K) y sumador",
        "Fluido (temperatura, nu, gamma)",
        "Diametros comerciales",
    };
    static menu_t m = { "BIBLIOTECA", items, 4, 0 };
    int r;
    while (!ui_quit) {
        r = menu_run(&m);
        if (r == MENU_BACK || r == MENU_QUIT)
            return;
        if (r == MENU_MODE) {
            scr_settings();
            continue;
        }
        todo_alert(items[r], 4);
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
        case 2: scr_library_menu(); break;
        case 3: todo_alert("Mis casos (guardar y cargar)", 4); break;
        case 5: scr_help(); break;
        case 6: return;
        default: break;
        }
    }
}
