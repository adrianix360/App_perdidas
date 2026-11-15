/*
 * memo_run.c - Ver memo_run.h
 */
#include <string.h>
#include <fileioc.h>
#include "app.h"
#include "pipe.h"
#include "memo_run.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "ui/numfmt.h"
#include "ui/memo.h"
#include "data/data.h"

real memo_V[V_COUNT];
uint32_t memo_FL;
unsigned int memo_W;
const hydro_cfg *memo_cfg;
const hydro_log *memo_log;
hydro_log memo_lg;
const real *memo_dlist;
uint8_t memo_dlist_n;
void (*memo_hook)(void);
const char *memo_txt;

void memo_reset(void)
{
    memset(memo_V, 0, sizeof memo_V);
    memo_FL = 0;
    memo_W = 0;
}

/* PERDTXT: programas de la memoria de calculo en un AppVar (normalmente
 * archivado; se lee en su lugar, sin copiarlo a la RAM). El puntero se
 * vuelve a pedir en cada uso, porque archivar otra variable puede mover
 * los datos de la memoria flash. */
static const uint8_t *TX;
static uint16_t TXN;

bool memo_tx_open(void)
{
    uint8_t h = ti_Open(TX_APPVAR, "r");
    TX = 0;
    if (!h)
        return false;
    TX = (const uint8_t *)ti_GetDataPtr(h);
    TXN = (uint16_t)ti_GetSize(h);
    ti_Close(h);
    if (TXN < 5 + 2 * PROG_COUNT || TX[0] != 'P' || TX[1] != 'T' ||
        TX[2] != 'X' || TX[3] != TX_VERSION || TX[4] != PROG_COUNT) {
        TX = 0;
        return false;
    }
    return true;
}

static uint16_t rd16(const uint8_t *p)
{
    return (uint16_t)(p[0] | p[1] << 8);
}

/* texto en el desplazamiento o, o NULL */
static const char *txs(uint16_t o)
{
    return (o == TX_NONE || o >= TXN) ? 0 : (const char *)(TX + o);
}

static char tb[200], tb2[200];

/* Expande los codigos de valor de una plantilla */
static const char *tpl(const char *t, char *out, size_t n)
{
    size_t k = 0;
    char num[NUMFMT_LEN];
    const char *s;
    uint8_t code, id;
    if (!t)
        return 0;
    while (*t && k + 1 < n) {
        code = (uint8_t)*t;
        if (code != TX_FULL && code != TX_SHORT) {
            out[k++] = *t++;
            continue;
        }
        if (!t[1])
            break;
        id = (uint8_t)(t[1] - 1);       /* el generador guarda id + 1 */
        t += 2;
        if (id == V_METHOD)
            s = method_names[memo_cfg && memo_cfg->method < FM_COUNT ?
                             memo_cfg->method : 0];
        else if (id == V_TXT)
            s = memo_txt ? memo_txt : "";
        else if (id == V_LISTNAME)
            s = pin.dset < DIAM_CHOICES ? diam_set_names[pin.dset] : "?";
        else if (id < V_COUNT)
            s = code == TX_SHORT ? fmt_w(memo_V[id], 7, num)
                                 : fmt_real(memo_V[id], g_set.dec, num);
        else
            s = "?";
        while (*s && k + 1 < n)
            out[k++] = *s++;
    }
    out[k] = 0;
    return out;
}

static const char *const hB_course[5] = { "i", "hf", "v", "hm", "hf+1" };
static const char *const hB_bis[5] = { "i", "v min", "v max", "v", "hT-H" };
static const char *const hD[5] = { "i", "D min", "D max", "D mm", "hT-H" };
static const char *const hCW[2] = { "i", "f_i" };
static const real m_one[5] = { 1, 1, 1, 1, 1 };
static const real m_D[5] = { 1, 1000, 1000, 1000, 1 };

static void run_prog(uint8_t prog, uint8_t depth)
{
    const uint8_t *p;
    uint16_t o;
    uint8_t skip = 0, i, op, id;
    char num[NUMFMT_LEN];
    if (!TX || prog >= PROG_COUNT)
        return;
    o = rd16(TX + 5 + 2 * prog);
    for (; o + TX_STEP <= TXN; o += TX_STEP) {
        p = TX + o;
        op = p[0];
        id = p[1];
        if (op == M_END)
            break;
        if (skip) {                       /* dentro de un IF falso */
            if (op == M_IF || op == M_IFN)
                skip++;
            else if (op == M_ENDIF)
                skip--;
            continue;
        }
        switch (op) {
        case M_SEC: memo_sec(txs(rd16(p + 2))); break;
        case M_SEP: view_add_sep(); break;
        case M_DATA: view_add_val(txs(rd16(p + 2)), memo_V[id], txs(rd16(p + 8))); break;
        case M_RES: memo_res(txs(rd16(p + 2)), memo_V[id], txs(rd16(p + 8))); break;
        case M_EQ:
            memo_eq(txs(rd16(p + 2)), txs(rd16(p + 4)),
                    tpl(txs(rd16(p + 6)), tb, sizeof tb), memo_V[id],
                    txs(rd16(p + 8)));
            break;
        case M_LINE: memo_line(tpl(txs(rd16(p + 2)), tb2, sizeof tb2), id); break;
        case M_IF:
            if (!(memo_FL & ((uint32_t)1 << id)))
                skip = 1;
            break;
        case M_IFN:
            if (memo_FL & ((uint32_t)1 << id))
                skip = 1;
            break;
        case M_CALL:
            if (depth < 3)
                run_prog(id, depth + 1);
            break;
        case M_TABLE:
            if (id == TB_HOOK) {
                if (memo_hook)
                    memo_hook();
                break;
            }
            if (!memo_log)
                break;
            if (id == TB_B_COURSE)
                memo_table(hB_course, 5, memo_log, m_one);
            else if (id == TB_B_BIS)
                memo_table(hB_bis, 5, memo_log, m_one);
            else if (id == TB_D)
                memo_table(hD, 5, memo_log, m_D);
            else
                memo_table(hCW, 2, memo_log, m_one);
            break;
        case M_WARN:
            if (memo_cfg)
                memo_warn(memo_W, memo_cfg);
            break;
        case M_DLIST:
            tb2[0] = ' ';
            tb2[1] = 0;
            for (i = 0; i < memo_dlist_n; i++) {
                if (strlen(tb2) > 30) {
                    memo_line(tb2, C_GRAY);
                    tb2[0] = ' ';
                    tb2[1] = 0;
                }
                strcat(tb2, fmt_w(memo_dlist[i] * 1000, 7, num));
                strcat(tb2, " ");
            }
            memo_line(tb2, C_GRAY);
            break;
        default: break;
        }
    }
}

void memo_run_prog(uint8_t prog)
{
    run_prog(prog, 0);
}

void memo_show(uint8_t prog)
{
    view_clear();
    if (!memo_tx_open()) {
        view_add("Falta el archivo " TX_APPVAR " (textos", C_ERR);
        view_add("de la memoria de calculo) o es de", C_ERR);
        view_add("otra version. Envie el PERDTXT nuevo", C_ERR);
        view_add("con TI Connect CE y vuelva a entrar.", C_ERR);
        return;
    }
    run_prog(prog, 0);
}
