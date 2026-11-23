/*
 * memo.c - Ver memo.h
 */
#include <stdarg.h>
#include <string.h>
#include "memo.h"
#include "numfmt.h"
#include "texts.h"
#include "widgets.h"
#include "../app.h"

#define W UI_COLS

char *fmt_w(real x, unsigned char width, char *buf)
{
    signed char d;
    for (d = 6; d >= 0; d--) {
        fmt_real(x, (unsigned char)d, buf);
        if (strlen(buf) <= width)
            return buf;
    }
    return buf;   /* notacion cientifica corta (fmt_real ya la usa) */
}

char *mfmt(char *buf, size_t n, const char *fmt, ...)
{
    va_list ap;
    size_t k = 0;
    char num[NUMFMT_LEN];
    const char *s;
    va_start(ap, fmt);
    while (*fmt && k + 1 < n) {
        if (*fmt != '%') {
            buf[k++] = *fmt++;
            continue;
        }
        fmt++;
        switch (*fmt) {
        case 'v': s = fmt_real((real)va_arg(ap, double), g_set.dec, num); break;
        case 'w': s = fmt_w((real)va_arg(ap, double), 7, num); break;
        case 'd': s = fmt_int(va_arg(ap, int), num); break;
        case 's': s = va_arg(ap, const char *); break;
        case '%': s = "%"; break;
        default: s = ""; break;
        }
        if (*fmt)
            fmt++;
        while (*s && k + 1 < n)
            buf[k++] = *s++;
    }
    buf[k] = 0;
    va_end(ap);
    return buf;
}

void memo_begin(const char *title)
{
    view_clear();
    view_add(title, C_TITLE);
    view_add_sep();
}

void memo_sec(const char *s)
{
    if (view_n > 2)
        view_add("", C_FG);
    view_add(s, C_TITLE);
}

/* Punto de corte: despues de un operador o espacio, sin partir "E-6" */
static size_t cut_at(const char *s, size_t max)
{
    size_t i;
    for (i = max; i > max / 2; i--) {
        char c = s[i - 1];
        if (c == ' ' || c == '+' || c == '*' || c == '/' || c == '(' ||
            (c == '-' && i >= 2 && s[i - 2] != 'E' && s[i - 2] != '('))
            return i;
    }
    return max;
}

void memo_line(const char *s, unsigned char color)
{
    char line[W + 1];
    size_t len = strlen(s), take;
    bool first = true;
    while (len > 0) {
        size_t room = first ? W : W - 6;
        if (len <= room) {
            take = len;
        } else {
            take = cut_at(s, room);
        }
        if (first) {
            memcpy(line, s, take);
            line[take] = 0;
        } else {
            memcpy(line, "      ", 6);
            memcpy(line + 6, s, take);
            line[take + 6] = 0;
        }
        view_add(line, color);
        s += take;
        len -= take;
        while (*s == ' ') {
            s++;
            len--;
        }
        first = false;
    }
}

void memo_data(const char *label, real v, const char *unit)
{
    view_add_val(label, v, unit);
}

void memo_eq(const char *lhs, const char *formula, const char *subst,
             real res, const char *unit)
{
    char b[200], num[NUMFMT_LEN];
    size_t pad = strlen(lhs) + 1;
    if (pad > 12)
        pad = 4;
    if (formula) {
        mfmt(b, sizeof b, "%s = %s", lhs, formula);
        memo_line(b, C_FG);
    }
    if (subst && !formula) {          /* sin formula literal: lhs = subst */
        mfmt(b, sizeof b, "%s = %s", lhs, subst);
        memo_line(b, C_FG);
    } else if (subst) {
        memset(b, ' ', pad);
        mfmt(b + pad, sizeof b - pad, "= %s", subst);
        memo_line(b, C_GRAY);
    }
    memset(b, ' ', pad);
    if (!formula && !subst) {
        mfmt(b, sizeof b, "%s = %s %s", lhs, fmt_real(res, g_set.dec, num),
             unit ? unit : "");
    } else {
        mfmt(b + pad, sizeof b - pad, "= %s %s",
             fmt_real(res, g_set.dec, num), unit ? unit : "");
    }
    memo_line(b, C_OK);
}

void memo_res(const char *label, real v, const char *unit)
{
    char b[64], num[NUMFMT_LEN];
    mfmt(b, sizeof b, "> %s = %s %s", label, fmt_real(v, g_set.dec, num),
         unit ? unit : "");
    memo_line(b, C_OK);
}

void memo_table(const char *const head[], unsigned char ncol,
                const hydro_log *lg, const real mult[])
{
    /* columna 0: 3 caracteres; las demas: (40 - 4) / (ncol - 1) */
    char line[W + 1], num[NUMFMT_LEN];
    unsigned char k, i, cw = (unsigned char)((W - 4) / (ncol - 1));
    size_t p;

    memset(line, ' ', W);
    line[W] = 0;
    for (k = 0; k < ncol; k++) {
        p = (k == 0) ? 0 : 4 + (k - 1) * cw;
        {
            size_t hl = strlen(head[k]);
            if (hl > (size_t)(cw - 1))
                hl = (size_t)(cw - 1);
            memcpy(line + p, head[k], hl);
        }
    }
    view_add(line, C_TITLE);
    for (i = 0; i < lg->n; i++) {
        if (lg->total > lg->n && i == lg->n / 2)
            view_add("...", C_GRAY);
        memset(line, ' ', W);
        line[W] = 0;
        fmt_int((long)lg->r[i][0], num);
        memcpy(line, num, strlen(num));
        for (k = 1; k < ncol; k++) {
            fmt_w(lg->r[i][k] * mult[k], (unsigned char)(cw - 1), num);
            p = 4 + (k - 1) * cw + (cw - 1 - strlen(num));
            memcpy(line + p, num, strlen(num));
        }
        view_add(line, C_FG);
    }
}

void memo_warn(unsigned int warn, const hydro_cfg *c)
{
    char w[10][41];
    unsigned char i, n = warn_texts(warn, c, g_set.dec, w, 10);
    if (!n) {
        view_add(" Sin advertencias", C_OK);
        return;
    }
    for (i = 0; i < n; i++)
        view_add(w[i], C_WARN);
}
