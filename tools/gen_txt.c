/*
 * gen_txt.c - Genera el contenido del AppVar PERDTXT a partir de
 * tools/memo_tables.c (formato en src/memo_defs.h). Valida en tiempo de
 * compilacion: nombres de plantilla, IF/ENDIF balanceados, CALL y TABLE.
 * Uso: gen_txt salida.bin     (luego convbin -k 8xv -n PERDTXT -r)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "memo_tables.c"

#define MAXS 2048
static const char *strs_src[MAXS];
static unsigned char *strs_enc[MAXS];
static size_t strs_len[MAXS];
static int nstrs;
static int errors;

/* codifica plantillas: {NOMBRE} -> 0x01 id, {NOMBRE!} -> 0x02 id */
static unsigned char *encode(const char *s, int tpl, size_t *len, const char *where)
{
    unsigned char *o = malloc(strlen(s) + 2);
    size_t k = 0;
    while (*s) {
        if (tpl && *s == '{') {
            char name[16];
            int j = 0, id = -1, i, sh = 0;
            s++;
            while (*s && *s != '}' && *s != '!' && j < 15)
                name[j++] = *s++;
            name[j] = 0;
            if (*s == '!') { sh = 1; s++; }
            if (*s == '}') s++;
            for (i = 0; i < V_COUNT; i++)
                if (!strcmp(name, vname[i])) id = i;
            if (!strcmp(name, "METHOD")) id = V_METHOD;
            if (!strcmp(name, "LISTNAME")) id = V_LISTNAME;
            if (!strcmp(name, "TXT")) id = V_TXT;
            if (id < 0) {
                fprintf(stderr, "ERROR: plantilla {%s} desconocida en %s\n", name, where);
                errors++;
                id = 0;
            }
            o[k++] = sh ? TX_SHORT : TX_FULL;
            o[k++] = (unsigned char)(id + 1);   /* nunca 0 (fin de texto) */
            continue;
        }
        if ((unsigned char)*s < 0x20) {
            fprintf(stderr, "ERROR: caracter de control en \"%s\"\n", where);
            errors++;
        }
        o[k++] = (unsigned char)*s++;
    }
    o[k++] = 0;
    *len = k;
    return o;
}

static int add_str(const char *s, int tpl, const char *where)
{
    size_t len;
    unsigned char *e;
    int i;
    if (!s)
        return -1;
    e = encode(s, tpl, &len, where);
    for (i = 0; i < nstrs; i++)
        if (strs_len[i] == len && !memcmp(strs_enc[i], e, len)) {
            free(e);
            return i;
        }
    strs_src[nstrs] = s;
    strs_enc[nstrs] = e;
    strs_len[nstrs] = len;
    return nstrs++;
}

static void put16(unsigned char *p, unsigned v)
{
    p[0] = (unsigned char)(v & 0xFF);
    p[1] = (unsigned char)(v >> 8);
}

int main(int argc, char **argv)
{
    const mstep *progs[PROG_COUNT];
    int nsteps[PROG_COUNT];
    int sidx[PROG_COUNT][400][4];
    static unsigned char out[65536];
    size_t pos, stroff[MAXS], steps_at[PROG_COUNT];
    int p, i, k, total = 0;
    FILE *f;

    for (i = 0; i < S_COUNT; i++)
        progs[i] = subs[i];
    for (i = 0; i < PT_COUNT; i++) {
        progs[PROG_SUM(i)] = sum_p[i];
        progs[PROG_MEMO(i)] = memo_p[i];
    }
    for (i = 0; i < HELP_COUNT; i++)
        progs[PROG_HELP(i)] = help_p[i];
    for (i = 0; i < XP_COUNT; i++)
        progs[PROG_X(i)] = x_p[i];
    for (p = 0; p < PROG_COUNT; p++) {
        int depth = 0;
        const mstep *s = progs[p];
        char where[64];
        for (i = 0;; i++) {
            if (i >= 400) { fprintf(stderr, "ERROR: programa %d sin STOP\n", p); return 1; }
            snprintf(where, sizeof where, "programa %d paso %d", p, i);
            if (s[i].op == M_IF || s[i].op == M_IFN) depth++;
            if (s[i].op == M_ENDIF && --depth < 0) {
                fprintf(stderr, "ERROR: ENDIF de mas en %s\n", where); errors++;
            }
            if (s[i].op == M_CALL && s[i].id >= S_COUNT) {
                fprintf(stderr, "ERROR: CALL invalido en %s\n", where); errors++;
            }
            if (s[i].op == M_TABLE && s[i].id >= TB_COUNT) {
                fprintf(stderr, "ERROR: TABLE invalida en %s\n", where); errors++;
            }
            if ((s[i].op == M_DATA || s[i].op == M_RES || s[i].op == M_EQ) &&
                s[i].id >= V_COUNT) {
                fprintf(stderr, "ERROR: valor invalido en %s\n", where); errors++;
            }
            sidx[p][i][0] = add_str(s[i].a, s[i].op == M_LINE, where);
            sidx[p][i][1] = add_str(s[i].b, 0, where);
            sidx[p][i][2] = add_str(s[i].c, s[i].op == M_EQ, where);
            sidx[p][i][3] = add_str(s[i].u, 0, where);
            if (s[i].op == M_END)
                break;
        }
        if (depth) { fprintf(stderr, "ERROR: IF sin ENDIF en programa %d\n", p); errors++; }
        nsteps[p] = i + 1;
        total += i + 1;
    }
    if (errors)
        return 1;
    /* cabecera, pasos y textos */
    out[0] = 'P'; out[1] = 'T'; out[2] = 'X'; out[3] = TX_VERSION; out[4] = PROG_COUNT;
    pos = 5 + 2 * PROG_COUNT;
    for (p = 0; p < PROG_COUNT; p++) {
        steps_at[p] = pos;
        put16(out + 5 + 2 * p, (unsigned)pos);
        pos += (size_t)nsteps[p] * TX_STEP;
    }
    for (i = 0; i < nstrs; i++) {
        stroff[i] = pos;
        memcpy(out + pos, strs_enc[i], strs_len[i]);
        pos += strs_len[i];
    }
    if (pos >= 0xFFFF) { fprintf(stderr, "ERROR: PERDTXT demasiado grande\n"); return 1; }
    for (p = 0; p < PROG_COUNT; p++)
        for (i = 0; i < nsteps[p]; i++) {
            unsigned char *q = out + steps_at[p] + (size_t)i * TX_STEP;
            q[0] = progs[p][i].op;
            q[1] = progs[p][i].id;
            for (k = 0; k < 4; k++)
                put16(q + 2 + 2 * k, sidx[p][i][k] < 0 ? TX_NONE
                      : (unsigned)stroff[sidx[p][i][k]]);
        }
    f = fopen(argc > 1 ? argv[1] : "PERDTXT.bin", "wb");
    if (!f) return 1;
    fwrite(out, 1, pos, f);
    fclose(f);
    printf("PERDTXT: %d programas, %d pasos, %d textos, %u bytes\n",
           PROG_COUNT, total, nstrs, (unsigned)pos);
    return 0;
}
