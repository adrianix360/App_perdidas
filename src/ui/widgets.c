/*
 * widgets.c - Ver widgets.h
 */
#include <string.h>
#include "widgets.h"
#include "expr.h"
#include "numfmt.h"
#include "../app.h"

/* ================================================================== */
/* Menu                                                                */
/* ================================================================== */
int menu_run(menu_t *m)
{
    static const char *const fk[5] = { "", "", "", "AJUSTES", "ELEGIR" };
    ui_key k;
    uint8_t i;
    char line[UI_COLS + 1];

    if (m->cur >= m->n)
        m->cur = 0;
    for (;;) {
        if (ui_quit)
            return MENU_QUIT;
        ui_begin(m->title, APP_NAME);
        for (i = 0; i < m->n && i < UI_ROWS - 2; i++) {
            bool sel = (i == m->cur);
            line[0] = ' ';
            line[1] = (char)('1' + i);
            line[2] = ' ';
            strncpy(line + 3, m->items[i], UI_COLS - 4);
            line[UI_COLS - 1] = 0;
            if (sel)
                ui_row_fill(i + 2, C_SEL);
            ui_text(i + 2, 1, line, C_FG, sel ? C_SEL : C_BG);
        }
        ui_msg("Flechas o 1-9; ENTER elige; CLEAR vuelve", C_GRAY);
        ui_fbar(fk);
        ui_end();

        k = ui_getkey();
        switch (k.k) {
        case K_QUIT: return MENU_QUIT;
        case K_CLEAR: return MENU_BACK;
        case K_MODE:
        case K_F4: return MENU_MODE;
        case K_UP: m->cur = m->cur ? m->cur - 1 : m->n - 1; break;
        case K_DOWN: m->cur = (m->cur + 1 < m->n) ? m->cur + 1 : 0; break;
        case K_ENTER:
        case K_F5:
        case K_RIGHT: return m->cur;
        case K_CHAR:
            if (k.c >= '1' && k.c <= '9' && (uint8_t)(k.c - '1') < m->n) {
                m->cur = (uint8_t)(k.c - '1');
                return m->cur;
            }
            break;
        default: break;
        }
    }
}

/* ================================================================== */
/* Formulario                                                          */
/* ================================================================== */
#define VIS_ROWS (UI_ROWS - 2)   /* filas visibles para campos */
#define COL_VAL_END 31
#define COL_UNIT 32

static bool field_has(const form_field *f)
{
    return !f->set || *f->set;
}

void form_value_text(const form_field *f, char *buf)
{
    if (f->flags & FF_CHOICE) {
        strncpy(buf, f->choices[*f->ch], NUMFMT_LEN - 1);
        buf[NUMFMT_LEN - 1] = 0;
    } else if (!field_has(f)) {
        strcpy(buf, "--");
    } else {
        fmt_real(*f->val, g_set.dec, buf);
    }
}

/* Valida un valor para el campo; devuelve mensaje o NULL */
static const char *field_err(const form_field *f, real v)
{
    if ((f->flags & FF_POS) && !(v > 0))
        return "Debe ser mayor que 0";
    if ((f->flags & FF_NONNEG) && !(v >= 0))
        return "No puede ser negativo";
    if ((f->flags & (FF_INT | FF_RANGE)) && !(v >= f->lo && v <= f->hi))
        return "Fuera del rango permitido";
    if ((f->flags & FF_INT) && v != (real)(long)v)
        return "Debe ser un numero entero";
    return 0;
}

static void form_draw(form_t *fm, bool editing, const char *ebuf)
{
    uint8_t i, row;
    char buf[NUMFMT_LEN + 2], lab[UI_COLS + 1];
    ui_begin(fm->title, fm->page);
    if (fm->cur < fm->top)
        fm->top = fm->cur;
    if (fm->cur >= fm->top + VIS_ROWS)
        fm->top = fm->cur - VIS_ROWS + 1;
    for (i = fm->top; i < fm->n && i < fm->top + VIS_ROWS; i++) {
        const form_field *f = &fm->f[i];
        bool sel = (i == fm->cur);
        uint8_t bg = sel ? C_SEL : C_BG;
        size_t n;
        row = (uint8_t)(i - fm->top + 1);
        if (sel)
            ui_row_fill(row, C_SEL);
        /* etiqueta con puntos hasta la columna del valor */
        memset(lab, '.', 19);
        lab[0] = ' ';
        n = strlen(f->label);
        if (n > 17)
            n = 17;
        memcpy(lab + 1, f->label, n);
        lab[n + 1] = ' ';
        lab[19] = 0;
        ui_text(row, 0, lab, (f->flags & FF_INFO) ? C_GRAY : C_FG, bg);
        if (sel && editing) {
            size_t L = strlen(ebuf);
            const char *s = ebuf;
            if (L > 11)
                s = ebuf + L - 11;   /* muestra el final de lo escrito */
            ui_text(row, 19, "             ", C_FG, C_EDIT);
            ui_text(row, 19, s, C_FG, C_EDIT);
            ui_text(row, (uint8_t)(19 + strlen(s)), "_", C_FG, C_EDIT);
        } else {
            form_value_text(f, buf);
            if (f->flags & FF_CHOICE) {
                ui_text(row, 19, "<", C_GRAY, bg);
                ui_text_n(row, 20, buf, 18, C_FG, bg);
                ui_text(row, 39, ">", C_GRAY, bg);
            } else {
                ui_text_r(row, COL_VAL_END, buf,
                          field_has(f) ? C_FG : C_GRAY, bg);
            }
        }
        if (f->unit && !(f->flags & FF_CHOICE))
            ui_text_n(row, COL_UNIT, f->unit, 8, C_GRAY, bg);
    }
    if (fm->n > VIS_ROWS) {
        if (fm->top > 0)
            ui_text(1, 39, "^", C_GRAY, C_BG);
        if (fm->top + VIS_ROWS < fm->n)
            ui_text(VIS_ROWS, 39, "v", C_GRAY, C_BG);
    }
    if (fm->msg)
        ui_msg(fm->msg, fm->msg_color);
    else if (editing)
        ui_msg("ENTER acepta; DEL borra; 2nd , = E", C_GRAY);
    else
        ui_msg(fm->hint ? fm->hint : "Escriba un valor o expresion", C_GRAY);
    ui_fbar(fm->fk);
    ui_end();
}

static void set_msg(form_t *fm, const char *m, uint8_t color)
{
    fm->msg = m;
    fm->msg_color = color;
}

/* Intenta guardar el texto editado en el campo actual */
static bool commit(form_t *fm, const char *ebuf)
{
    form_field *f = &fm->f[fm->cur];
    real v;
    int e = expr_eval(ebuf, &v);
    const char *err;
    if (e == EXPR_EMPTY && (f->flags & FF_OPT)) {
        if (f->set)
            *f->set = 0;
        return true;
    }
    if (e) {
        set_msg(fm, expr_err_text(e), C_ERR);
        return false;
    }
    err = field_err(f, v);
    if (err) {
        set_msg(fm, err, C_ERR);
        return false;
    }
    *f->val = v;
    if (f->set)
        *f->set = 1;
    return true;
}

bool form_check(form_t *fm)
{
    uint8_t i;
    for (i = 0; i < fm->n; i++) {
        form_field *f = &fm->f[i];
        const char *err;
        if (f->flags & (FF_CHOICE | FF_INFO))
            continue;
        if (!field_has(f)) {
            if (f->flags & FF_OPT)
                continue;
            fm->cur = i;
            set_msg(fm, "Falta este dato", C_ERR);
            return false;
        }
        err = field_err(f, *f->val);
        if (err) {
            fm->cur = i;
            set_msg(fm, err, C_ERR);
            return false;
        }
    }
    return true;
}

static void move(form_t *fm, int d)
{
    uint8_t tries = fm->n;
    do {
        if (d > 0)
            fm->cur = (fm->cur + 1 < fm->n) ? fm->cur + 1 : 0;
        else
            fm->cur = fm->cur ? fm->cur - 1 : fm->n - 1;
    } while ((fm->f[fm->cur].flags & FF_INFO) && --tries);
}

#define EBUF_LEN 64   /* la suma de K del examen 2025 ya pasa de 32 */

uint8_t form_run(form_t *fm)
{
    char ebuf[EBUF_LEN];
    uint8_t elen = 0;
    bool editing = false;
    ui_key k;

    if (fm->cur >= fm->n)
        fm->cur = 0;
    if (fm->f[fm->cur].flags & FF_INFO)
        move(fm, 1);
    for (;;) {
        if (ui_quit)
            return K_QUIT;
        ebuf[elen] = 0;
        form_draw(fm, editing, ebuf);
        fm->msg = 0;
        k = ui_getkey();
        if (k.k == K_QUIT)
            return K_QUIT;
        if (k.k == K_NONE || k.k == K_ALPHA)
            continue;   /* 2nd: redibuja el indicador */
        if (editing) {
            switch (k.k) {
            case K_CHAR:
                if (elen < sizeof ebuf - 1)
                    ebuf[elen++] = k.c;
                else
                    set_msg(fm, "Expresion demasiado larga", C_ERR);
                continue;
            case K_DEL:
            case K_LEFT:
                if (elen)
                    elen--;
                continue;
            case K_CLEAR:
                if (elen)
                    elen = 0;
                else
                    editing = false;
                continue;
            case K_ENTER: case K_UP: case K_DOWN: case K_PGUP: case K_PGDN:
            case K_F1: case K_F2: case K_F3: case K_F4: case K_F5:
            case K_MODE:
                if (!commit(fm, ebuf))
                    continue;
                editing = false;
                elen = 0;
                break;      /* sigue abajo con la tecla */
            default:
                continue;
            }
        }
        {
            form_field *f = &fm->f[fm->cur];
            switch (k.k) {
            case K_CLEAR: return K_CLEAR;
            case K_MODE: return K_MODE;
            case K_F1: case K_F2: case K_F3: case K_F4: case K_F5:
                return k.k;
            case K_UP: move(fm, -1); break;
            case K_DOWN: move(fm, 1); break;
            case K_PGUP: fm->cur = 0; if (fm->f[0].flags & FF_INFO) move(fm, 1); break;
            case K_PGDN: fm->cur = fm->n - 1; if (fm->f[fm->cur].flags & FF_INFO) move(fm, -1); break;
            case K_ENTER:
                if (fm->cur + 1 >= fm->n)
                    return K_ENTER;
                move(fm, 1);
                break;
            case K_LEFT:
            case K_RIGHT:
                if (f->flags & FF_CHOICE) {
                    if (k.k == K_RIGHT)
                        *f->ch = (uint8_t)((*f->ch + 1) % f->nchoices);
                    else
                        *f->ch = *f->ch ? (uint8_t)(*f->ch - 1)
                                        : (uint8_t)(f->nchoices - 1);
                } else if (k.k == K_RIGHT && !(f->flags & FF_INFO)) {
                    /* editar el valor actual */
                    if (field_has(f)) {
                        char t[NUMFMT_LEN];
                        fmt_real(*f->val, DEC_MAX, t);
                        strcpy(ebuf, t);
                        elen = (uint8_t)strlen(ebuf);
                    } else {
                        elen = 0;
                    }
                    editing = true;
                }
                break;
            case K_DEL:
                if ((f->flags & FF_OPT) && f->set) {
                    *f->set = 0;
                    set_msg(fm, "Campo vaciado (opcional)", C_GRAY);
                }
                break;
            case K_CHAR:
                if (f->flags & (FF_CHOICE | FF_INFO))
                    break;
                editing = true;
                elen = 0;
                ebuf[elen++] = k.c;
                break;
            default:
                break;
            }
        }
    }
}

/* ================================================================== */
/* Visor de lineas                                                     */
/* ================================================================== */
char view_line[VIEW_MAX][UI_COLS + 1];
uint8_t view_color[VIEW_MAX];
uint8_t view_n;

void view_clear(void)
{
    view_n = 0;
}

void view_add(const char *s, uint8_t color)
{
    if (view_n >= VIEW_MAX)
        return;
    strncpy(view_line[view_n], s, UI_COLS);
    view_line[view_n][UI_COLS] = 0;
    view_color[view_n] = color;
    view_n++;
}

void view_add_val(const char *label, real v, const char *unit)
{
    char line[UI_COLS + 1], num[NUMFMT_LEN];
    size_t n;
    fmt_real(v, g_set.dec, num);
    line[0] = ' ';
    strncpy(line + 1, label, 16);
    line[17] = 0;
    n = strlen(line);
    while (n < 17)
        line[n++] = ' ';
    line[n++] = '=';
    line[n++] = ' ';
    line[n] = 0;
    strncat(line, num, UI_COLS - n);
    if (unit) {
        n = strlen(line);
        if (n < UI_COLS - 1) {
            line[n++] = ' ';
            line[n] = 0;
            strncat(line, unit, UI_COLS - n);
        }
    }
    view_add(line, C_FG);
}

void view_add_sep(void)
{
    view_add("----------------------------------------", C_GRAY);
}

uint8_t view_run(const char *title, const char *const fk[5])
{
    uint8_t top = 0, i, vis = UI_ROWS - 1;
    char pg[12], t[6];
    ui_key k;
    for (;;) {
        if (ui_quit)
            return K_QUIT;
        ui_begin(title, 0);
        for (i = 0; i < vis && top + i < view_n; i++)
            ui_text(i + 1, 0, view_line[top + i], view_color[top + i], C_BG);
        if (view_n > vis) {
            /* la ultima pagina puede empezar antes de un multiplo de vis */
            fmt_int(top + vis >= view_n ? (view_n + vis - 1) / vis
                                        : top / vis + 1, pg);
            strcat(pg, "/");
            fmt_int((view_n + vis - 1) / vis, t);
            strcat(pg, t);
            ui_text_r(0, 39, pg, C_BG, C_TITLE);
            ui_msg("Flechas: desplazar; CLEAR vuelve", C_GRAY);
        } else {
            ui_msg("CLEAR vuelve", C_GRAY);
        }
        ui_fbar(fk);
        ui_end();
        k = ui_getkey();
        switch (k.k) {
        case K_UP: if (top) top--; break;
        case K_DOWN: if (top + vis < view_n) top++; break;
        case K_LEFT: case K_PGUP: top = (top > vis) ? top - vis : 0; break;
        case K_RIGHT: case K_PGDN:
            if (top + vis < view_n)
                top = (top + 2 * vis <= view_n) ? top + vis : view_n - vis;
            break;
        case K_CLEAR: case K_QUIT: case K_MODE:
        case K_F1: case K_F2: case K_F3: case K_F4: case K_F5:
            return k.k;
        default: break;
        }
    }
}

void todo_alert(const char *what, uint8_t fase)
{
    char l2[UI_COLS + 1] = "Disponible en la fase ";
    char n[4];
    fmt_int(fase, n);
    strcat(l2, n);
    ui_alert("En construccion", what, l2, C_WARN);
}
