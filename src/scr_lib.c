/*
 * scr_lib.c - Biblioteca: materiales (ks, C_H), accesorios y sumador de K,
 * fluido (temperatura, nu, gamma, presion de vapor) y diametros
 * comerciales (listas del curso y lista propia).
 */
#include <string.h>
#include "app.h"
#include "pipe.h"
#include "data/data.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "ui/numfmt.h"

static void pad_to(char *s, size_t col)
{
    size_t n = strlen(s);
    while (n < col)
        s[n++] = ' ';
    s[n] = 0;
}

/* ------------------------------------------------------------------ */
/* Materiales                                                          */
/* ------------------------------------------------------------------ */
bool lib_pick_material(void)
{
    static const char *const fk[5] = { "", "", "", "", "USAR" };
    static uint8_t cur;
    char num[NUMFMT_LEN];
    uint8_t i, k;
    int r;
    for (i = 0; i < MATERIALS; i++) {
        char *l = list_line[i];
        strcpy(l, materials[i].name);
        pad_to(l, 20);
        if (materials[i].ks_mm >= 0) {
            fmt_real(materials[i].ks_mm, 4, num);
            strcat(l, num);
        } else {
            strcat(l, "  --");
        }
        pad_to(l, 31);
        if (materials[i].ch > 0) {
            strcat(l, "CH ");
            strcat(l, fmt_int((long)materials[i].ch, num));
        }
    }
    r = list_pick("MATERIALES  ks (mm)  C_H", "(C) = Cengel; los demas, tabla del curso",
                  MATERIALS, cur, fk, &k);
    if (r < 0 || (k != K_ENTER && k != K_F5))
        return false;
    cur = (uint8_t)r;
    if (materials[r].ks_mm >= 0) {
        pin.ks = materials[r].ks_mm;
        pin.sks = 1;
    }
    if (materials[r].ch > 0) {
        pin.CH = materials[r].ch;
        pin.sCH = 1;
    }
    return true;
}

/* ------------------------------------------------------------------ */
/* Sumador de accesorios                                               */
/* ------------------------------------------------------------------ */
#define SUM_MAX 10
static struct {
    char name[20];
    real qty, K;
    uint8_t sq, sk;
} sl[SUM_MAX];
static uint8_t sn;
static real stotal;

static void sum_total(void)
{
    uint8_t i;
    stotal = 0;
    for (i = 0; i < sn; i++)
        stotal += sl[i].qty * sl[i].K;
}

static void add_line(const char *name, real qty, real K)
{
    if (sn >= SUM_MAX)
        return;
    strncpy(sl[sn].name, name, sizeof sl[sn].name - 1);
    sl[sn].name[sizeof sl[sn].name - 1] = 0;
    sl[sn].qty = qty;
    sl[sn].K = K;
    sl[sn].sq = sl[sn].sk = 1;
    sn++;
}

static int pick_fitting(void)
{
    static uint8_t cur;
    char num[NUMFMT_LEN];
    uint8_t i, k;
    int r;
    for (i = 0; i < FITTINGS; i++) {
        strcpy(list_line[i], fittings[i].name);
        pad_to(list_line[i], 24);
        strcat(list_line[i], "K = ");
        strcat(list_line[i], fmt_real(fittings[i].K, 3, num));
    }
    r = list_pick("ACCESORIOS  (K)", "(C) = Cengel; K editable despues",
                  FITTINGS, cur, 0, &k);
    if (r >= 0 && k == K_ENTER) {
        cur = (uint8_t)r;
        return r;
    }
    return -1;
}

static int pick_preset(void)
{
    uint8_t i, k;
    int r;
    char num[NUMFMT_LEN];
    for (i = 0; i < K_PRESETS; i++) {
        real t = 0;
        uint8_t j;
        for (j = 0; j < k_presets[i].n; j++)
            t += k_presets[i].items[j].qty * k_presets[i].items[j].K;
        strcpy(list_line[i], k_presets[i].name);
        pad_to(list_line[i], 24);
        strcat(list_line[i], "SumK ");
        strcat(list_line[i], fmt_real(t, 3, num));
    }
    r = list_pick("CONJUNTOS DEL CURSO", "Reemplaza la lista actual", K_PRESETS, 0, 0, &k);
    return (r >= 0 && k == K_ENTER) ? r : -1;
}

bool lib_sumador(void)
{
    static form_field f[1 + 2 * SUM_MAX];
    static uint8_t cur;
    form_t fm;
    uint8_t i, k, n;
    int r;
    for (;;) {
        sum_total();
        f[0].label = "Suma K total";
        f[0].unit = 0;
        f[0].val = &stotal;
        f[0].ch = 0;
        f[0].set = 0;
        f[0].flags = FF_INFO;
        n = 1;
        for (i = 0; i < sn; i++) {
            form_field *a = &f[n++], *b = &f[n++];
            memset(a, 0, sizeof *a);
            memset(b, 0, sizeof *b);
            a->label = sl[i].name;
            a->unit = "uds";
            a->val = &sl[i].qty;
            a->set = &sl[i].sq;
            a->flags = FF_NONNEG;
            b->label = "   K c/u";
            b->val = &sl[i].K;
            b->set = &sl[i].sk;
            b->flags = FF_NONNEG;
        }
        memset(&fm, 0, sizeof fm);
        fm.title = "SUMADOR DE ACCESORIOS";
        fm.f = f;
        fm.n = n;
        fm.cur = cur < n ? cur : 0;
        fm.fk[0] = "AGREGAR";
        fm.fk[1] = "CONJUNT";
        fm.fk[2] = "QUITAR";
        fm.fk[3] = "OTRO";
        fm.fk[4] = "USAR";
        fm.hint = sn ? "Cantidad y K editables; F5 usa la suma"
                     : "F1 agrega accesorio; F2 conjunto curso";
        fm.on_commit = sum_total;
        k = form_run(&fm);
        cur = fm.cur;
        switch (k) {
        case K_F1:
            r = pick_fitting();
            if (r >= 0) {
                add_line(fittings[r].name, 1, fittings[r].K);
                cur = (uint8_t)(2 * sn - 1);
            }
            break;
        case K_F2:
            r = pick_preset();
            if (r >= 0) {
                sn = 0;
                for (i = 0; i < k_presets[r].n; i++)
                    add_line(k_presets[r].items[i].name,
                             (real)k_presets[r].items[i].qty, k_presets[r].items[i].K);
                cur = 0;
            }
            break;
        case K_F3:
            if (sn && fm.cur >= 1) {
                uint8_t li = (uint8_t)((fm.cur - 1) / 2);
                for (i = li; i + 1 < sn; i++)
                    sl[i] = sl[i + 1];
                sn--;
                cur = cur > 2 ? (uint8_t)(cur - 2) : 0;
            }
            break;
        case K_F4:
            add_line("Otro accesorio", 1, 0);
            cur = (uint8_t)(2 * sn);
            break;
        case K_F5:
            sum_total();
            pin.K = stotal;
            pin.sK = 1;
            return true;
        case K_MODE:
            scr_settings();
            break;
        default:              /* CLEAR, QUIT o ENTER en el ultimo campo */
            if (k == K_ENTER)
                break;
            return false;
        }
        if (ui_quit)
            return false;
    }
}

/* ------------------------------------------------------------------ */
/* Fluido                                                              */
/* ------------------------------------------------------------------ */
bool lib_pick_fluid(uint8_t to_settings)
{
    static uint8_t cur;
    char num[NUMFMT_LEN];
    uint8_t i, k;
    int r;
    for (i = 0; i < WATERS; i++) {
        strcpy(list_line[i], waters[i].name);
        pad_to(list_line[i], 18);
        strcat(list_line[i], "nu ");
        strcat(list_line[i], fmt_real(waters[i].nu, 6, num));
    }
    r = list_pick(to_settings ? "FLUIDO POR DEFECTO" : "FLUIDO",
                  "(std) tabla estandar; aire: arrastre", WATERS, cur, 0, &k);
    if (r < 0 || k != K_ENTER)
        return false;
    cur = (uint8_t)r;
    if (!to_settings) {
        pin.nu = waters[r].nu;
        pin.snu = 1;
        return true;
    }
    if (waters[r].rho > 0 && waters[r].rho < 10) {      /* v2.0: aire */
        g_set.rho_air = waters[r].rho;
        g_set.nu_air = waters[r].nu;
        g_set_dirty = true;
        ui_alert("Aire por defecto", "rho y nu del aire quedan en",
                 "Ajustes (arrastre y sustentacion)", C_OK);
        return true;
    }
    {
        app_settings t = g_set;      /* se valida antes de aplicar */
        t.h.nu = waters[r].nu;
        if (waters[r].rho > 0)
            t.h.gamma = waters[r].rho * t.h.g;
        if (waters[r].pv > 0)
            t.h.pv = waters[r].pv;
        if (!settings_valid(&t)) {
            ui_alert("Fluido por defecto", "gamma = rho g queda fuera de",
                     "rango: revise g en Ajustes", C_ERR);
            return false;
        }
        g_set = t;
    }
    g_set_dirty = true;
    pin.nu = waters[r].nu;
    pin.snu = 1;
    ui_alert("Fluido por defecto", waters[r].rho > 0 ? "nu, gamma = rho g y presion"
             : "nu del curso (gamma sin", waters[r].rho > 0 ? "de vapor quedan en Ajustes"
             : "cambio) queda en Ajustes", C_OK);
    return true;
}

/* ------------------------------------------------------------------ */
/* Diametros comerciales                                               */
/* ------------------------------------------------------------------ */
static void edit_custom(void)
{
    static form_field f[DIAM_CUSTOM_MAX];
    static uint8_t set[DIAM_CUSTOM_MAX];
    static const char *const labels[DIAM_CUSTOM_MAX] = {
        "Diametro 1", "Diametro 2", "Diametro 3", "Diametro 4", "Diametro 5",
        "Diametro 6", "Diametro 7", "Diametro 8", "Diametro 9", "Diametro 10",
        "Diametro 11", "Diametro 12", "Diametro 13", "Diametro 14", "Diametro 15" };
    form_t fm;
    uint8_t i, k;
    for (i = 0; i < DIAM_CUSTOM_MAX; i++) {
        memset(&f[i], 0, sizeof f[i]);
        f[i].label = labels[i];
        f[i].unit = "mm";
        f[i].val = &diam_custom[i];
        set[i] = diam_custom[i] > 0;
        f[i].set = &set[i];
        f[i].flags = FF_POS | FF_OPT;
    }
    memset(&fm, 0, sizeof fm);
    fm.title = "LISTA PROPIA (mm, internos)";
    fm.f = f;
    fm.n = DIAM_CUSTOM_MAX;
    fm.fk[4] = "GUARDAR";
    fm.hint = "DEL vacia un campo; F5 guarda";
    do {
        k = form_run(&fm);
        if (k == K_MODE)
            scr_settings();
    } while (k == K_MODE && !ui_quit);
    if (k == K_F5 || k == K_ENTER || k == K_CLEAR) {
        for (i = 0; i < DIAM_CUSTOM_MAX; i++)
            if (!set[i])
                diam_custom[i] = 0;
        cases_write();
    }
}

static void show_set(uint8_t s)
{
    static const char *const fk[5] = { "", "", "", "", "VOLVER" };
    char line[UI_COLS + 1], num[NUMFMT_LEN];
    uint8_t i;
    view_clear();
    view_add(diam_set_names[s], C_TITLE);
    view_add("Diametros internos (mm):", C_GRAY);
    view_add_sep();
    line[0] = 0;
    for (i = 0; i < diam_sets[s].n; i++) {
        if (strlen(line) > 30) {
            view_add(line, C_FG);
            line[0] = 0;
        }
        strcat(line, " ");
        strcat(line, fmt_real(diam_sets[s].mm[i], 2, num));
    }
    view_add(line, C_FG);
    view_run("DIAMETROS COMERCIALES", fk);
}

void lib_diams(void)
{
    static uint8_t cur;
    uint8_t i, k;
    int r;
    for (;;) {
        for (i = 0; i < DIAM_CHOICES; i++)
            strcpy(list_line[i], diam_set_names[i]);
        r = list_pick("DIAMETROS COMERCIALES", "ENTER: ver o editar (lista propia)",
                      DIAM_CHOICES, cur, 0, &k);
        if (r < 0)
            return;
        cur = (uint8_t)r;
        if (r == DIAM_CUSTOM)
            edit_custom();
        else
            show_set((uint8_t)r);
        if (ui_quit)
            return;
    }
}

void scr_library(void)
{
    static const char *const items[] = {
        "Materiales (ks, C_H)",
        "Accesorios (K) y sumador",
        "Fluido por defecto (T, nu, gamma)",
        "Diametros comerciales",
        "Coeficientes de arrastre (CD)",
    };
    static menu_t m = { "BIBLIOTECA", items, 5, 0 };
    int r;
    while (!ui_quit) {
        r = menu_run(&m);
        if (r == MENU_BACK || r == MENU_QUIT)
            return;
        if (r == MENU_MODE) {
            scr_settings();
            continue;
        }
        switch (r) {
        case 0:
            if (lib_pick_material())
                ui_alert("Material", "ks y C_H quedan en los", "formularios de tuberia", C_OK);
            break;
        case 1:
            if (lib_sumador())
                ui_alert("Suma K", "La suma queda en el campo", "Suma K de los formularios", C_OK);
            break;
        case 2: lib_pick_fluid(1); break;
        case 3: lib_diams(); break;
        case 4: scr_cat(0); break;
        default: break;
        }
    }
}
