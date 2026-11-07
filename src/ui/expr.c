/*
 * expr.c - Evaluador recursivo descendente con prioridad de operadores.
 *   expr   := term { (+|-) term }
 *   term   := unary { (*|/) unary | '(' ... implicito }
 *   unary  := (+|-) unary | power
 *   power  := primary [ ^ unary ]          (asociativo a la derecha)
 *   primary:= numero | ( expr )
 * Profundidad limitada para no agotar la pila del eZ80 (unos 4 KiB).
 */
#include "expr.h"

#define EXPR_MAX_DEPTH 12

typedef struct {
    const char *p;
    int err;
    unsigned char depth;
} ps_t;

static real p_expr(ps_t *s);

static void skip(ps_t *s)
{
    while (*s->p == ' ')
        s->p++;
}

static int finite_r(real x)
{
    return x == x && x - x == 0;   /* no NaN y no infinito */
}

static real p_number(ps_t *s)
{
    real v = 0, scale;
    int digits = 0, e = 0, es = 1, edig = 0;

    while (*s->p >= '0' && *s->p <= '9') {
        v = v * 10 + (real)(*s->p - '0');
        s->p++;
        digits++;
    }
    if (*s->p == '.') {
        s->p++;
        scale = 1;
        while (*s->p >= '0' && *s->p <= '9') {
            scale /= 10;
            v += scale * (real)(*s->p - '0');
            s->p++;
            digits++;
        }
    }
    if (!digits) {
        s->err = EXPR_SYNTAX;
        return 0;
    }
    if (*s->p == 'E' || *s->p == 'e') {
        s->p++;
        if (*s->p == '-') {
            es = -1;
            s->p++;
        } else if (*s->p == '+') {
            s->p++;
        }
        while (*s->p >= '0' && *s->p <= '9') {
            if (e < 100)
                e = e * 10 + (*s->p - '0');
            s->p++;
            edig++;
        }
        if (!edig) {
            s->err = EXPR_SYNTAX;
            return 0;
        }
        while (e-- > 0)
            v = (es > 0) ? v * 10 : v / 10;
    }
    return v;
}

static real p_unary(ps_t *s);

static real p_primary(ps_t *s)
{
    real v;
    skip(s);
    if (*s->p == '(') {
        if (++s->depth > EXPR_MAX_DEPTH) {
            s->err = EXPR_DEPTH;
            return 0;
        }
        s->p++;
        v = p_expr(s);
        if (s->err)
            return 0;
        skip(s);
        if (*s->p != ')') {
            s->err = EXPR_SYNTAX;
            return 0;
        }
        s->p++;
        s->depth--;
        return v;
    }
    return p_number(s);
}

static real p_power(ps_t *s)
{
    real b = p_primary(s), x;
    if (s->err)
        return 0;
    skip(s);
    if (*s->p == '^') {
        if (++s->depth > EXPR_MAX_DEPTH) {
            s->err = EXPR_DEPTH;
            return 0;
        }
        s->p++;
        x = p_unary(s);
        s->depth--;
        if (s->err)
            return 0;
        if (b == 0 && x < 0) {
            s->err = EXPR_DIV0;
            return 0;
        }
        b = R_POW(b, x);
    }
    return b;
}

static real p_unary(ps_t *s)
{
    real v;
    skip(s);
    if (*s->p == '-' || *s->p == '+') {
        int neg = (*s->p == '-');
        if (++s->depth > EXPR_MAX_DEPTH) {
            s->err = EXPR_DEPTH;
            return 0;
        }
        s->p++;
        v = p_unary(s);
        s->depth--;
        return neg ? -v : v;
    }
    return p_power(s);
}

static real p_term(ps_t *s)
{
    real v = p_unary(s), r;
    char op;
    while (!s->err) {
        skip(s);
        op = *s->p;
        if (op == '*' || op == '/') {
            s->p++;
        } else if (op == '(') {
            op = '*';            /* multiplicacion implicita */
        } else {
            break;
        }
        r = p_unary(s);
        if (s->err)
            return 0;
        if (op == '/') {
            if (r == 0) {
                s->err = EXPR_DIV0;
                return 0;
            }
            v /= r;
        } else {
            v *= r;
        }
    }
    return v;
}

static real p_expr(ps_t *s)
{
    real v = p_term(s), r;
    char op;
    while (!s->err) {
        skip(s);
        op = *s->p;
        if (op != '+' && op != '-')
            break;
        s->p++;
        r = p_term(s);
        if (s->err)
            return 0;
        v = (op == '+') ? v + r : v - r;
    }
    return v;
}

int expr_eval(const char *str, real *out)
{
    ps_t s;
    real v;
    s.p = str;
    s.err = EXPR_OK;
    s.depth = 0;
    skip(&s);
    if (!*s.p)
        return EXPR_EMPTY;
    v = p_expr(&s);
    if (s.err)
        return s.err;
    skip(&s);
    if (*s.p)
        return EXPR_SYNTAX;
    if (!finite_r(v))
        return EXPR_RANGE;
    *out = v;
    return EXPR_OK;
}

const char *expr_err_text(int e)
{
    static const char *const t[EXPR_COUNT] = {
        "OK", "Campo vacio", "Error de sintaxis", "Division entre cero",
        "Resultado fuera de rango", "Demasiados parentesis"
    };
    return (e >= 0 && e < EXPR_COUNT) ? t[e] : "Error";
}
