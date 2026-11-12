/*
 * scr_net.c - Sistemas en serie y paralelo (tipo G) con el metodo de los
 * modulos de caudal, hacia adelante (H dada) o hacia atras (Q conocido en
 * un tubo), y grafica de LE y LP (tipo H).
 *
 * Entrada: hasta 8 tubos; cada uno con su numero de tramo. Los tubos del
 * mismo tramo van en paralelo y los tramos en serie, en orden creciente.
 * Ejemplo examen 2024 P3: A tramo 1; B, C y D tramo 2.
 */
#include <string.h>
#include "app.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "ui/numfmt.h"
#include "ui/memo.h"
#include "ui/graph.h"

#define NP 8

typedef struct {
    real tr, L, D, f, ks, K;
    uint8_t str, sL, sD, sf, sks, sK;
} npipe;

static struct {
    real np, H, kp, Qk, nu, z1;
    uint8_t snp, sH, skp, sQk, snu, sz1;
    uint8_t mode;              /* 0 hacia adelante, 1 hacia atras */
    npipe p[NP];
} ni = { 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, { { 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 } } };

static hydro_net NET;
static hydro_cfg NC;
static uint8_t nt;              /* numero de tramos                    */
static uint8_t tr_node[NP];     /* nodo de cada tramo                  */
static uint8_t tr_of[NP];       /* tramo (0..nt-1) de cada tubo        */
static uint8_t pnode[NP];       /* nodo de cada tubo                   */
static real Htot;
static const char pname[NP + 1] = "ABCDEFGH";

static const char *const mode_names[2] = { "Adelante (H dada)", "Atras (Q en tubo)" };

/* ------------------------------------------------------------------ */
/* Formulario dinamico                                                 */
/* ------------------------------------------------------------------ */
static form_field ff[8 + 6 * NP];
static form_t *fm_now;

/* si cambia el numero de tubos, el formulario se rehace al instante */
static void np_changed(void)
{
    static real last = 1;
    if (ni.snp && ni.np != last && fm_now) {
        last = ni.np;
        fm_now->restart = 1;
    }
}
static char flab[6 * NP][18];

static uint8_t build_form(void)
{
    static const char *const sub[6] = { "tramo", "L", "D", "f dado(opc)", "ks (si no f)", "Suma K" };
    static const char *const unit[6] = { 0, "m", "mm", 0, "mm", 0 };
    uint8_t n = 0, i, j, np = (uint8_t)(ni.snp ? ni.np : 1);
    form_field *f;
    memset(ff, 0, sizeof ff);
#define ADD(l, u, v, s, fl, LO_, HI_) do { f = &ff[n++]; f->label = l; f->unit = u; \
    f->val = v; f->set = s; f->flags = fl; f->lo = LO_; f->hi = HI_; } while (0)
    ADD("Numero de tubos", 0, &ni.np, &ni.snp, FF_INT, 1, NP);
    f = &ff[n++];
    f->label = "Calcular";
    f->ch = &ni.mode;
    f->flags = FF_CHOICE;
    f->choices = mode_names;
    f->nchoices = 2;
    ADD("Carga H (adelante)", "m", &ni.H, &ni.sH, FF_POS | FF_OPT, 0, 0);
    ADD("Tubo conocido 1-8", 0, &ni.kp, &ni.skp, FF_INT | FF_OPT, 1, NP);
    ADD("Q en ese tubo", "l/s", &ni.Qk, &ni.sQk, FF_POS | FF_OPT, 0, 0);
    ADD("Viscosidad nu", "m2/s", &ni.nu, &ni.snu, FF_POS, 0, 0);
    ADD("Energia tanque 1", "m", &ni.z1, &ni.sz1, FF_ANY | FF_OPT, 0, 0);
    f = &ff[n++];
    f->label = "Metodo de f";
    f->ch = &g_set.h.method;
    f->flags = FF_CHOICE;
    f->choices = method_names;
    f->nchoices = FM_COUNT;
    for (i = 0; i < np; i++) {
        npipe *p = &ni.p[i];
        real *v[6] = { &p->tr, &p->L, &p->D, &p->f, &p->ks, &p->K };
        uint8_t *s[6] = { &p->str, &p->sL, &p->sD, &p->sf, &p->sks, &p->sK };
        uint8_t fl[6] = { FF_INT, FF_POS, FF_POS, FF_POS | FF_OPT, FF_NONNEG | FF_OPT, FF_NONNEG };
        for (j = 0; j < 6; j++) {
            char *l = flab[i * 6 + j];
            l[0] = pname[i];
            l[1] = ' ';
            strcpy(l + 2, sub[j]);
            ADD(l, unit[j], v[j], s[j], fl[j], j == 0 ? 1 : 0, j == 0 ? NP : 0);
        }
    }
#undef ADD
    return n;
}

/* ------------------------------------------------------------------ */
/* Calculo                                                             */
/* ------------------------------------------------------------------ */
static const char *compute(void)
{
    uint8_t np = (uint8_t)ni.np, i, t, k, kids[NP], nk, troot[NP];
    int idx, e;
    real tv[NP];

    NC = g_set.h;
    NC.nu = ni.nu;
    for (i = 0; i < np; i++)
        if (!ni.p[i].sf && !ni.p[i].sks)
            return "Cada tubo necesita f o ks";
    /* tramos distintos, en orden */
    nt = 0;
    for (i = 0; i < np; i++) {
        real v = ni.p[i].tr;
        for (k = 0; k < nt && tv[k] != v; k++)
            ;
        if (k == nt)
            tv[nt++] = v;
    }
    for (i = 1; i < nt; i++)          /* insercion */
        for (k = i; k > 0 && tv[k - 1] > tv[k]; k--) {
            real x = tv[k]; tv[k] = tv[k - 1]; tv[k - 1] = x;
        }
    hydro_net_init(&NET);
    for (i = 0; i < np; i++) {
        npipe *p = &ni.p[i];
        idx = hydro_net_add_pipe(&NET, p->L, p->D / 1000, p->sf ? p->f : 0,
                                 p->sks ? p->ks / 1000 : 0, p->K);
        if (idx < 0)
            return "Sistema mal definido";
        pnode[i] = (uint8_t)idx;
        for (t = 0; t < nt && tv[t] != p->tr; t++)
            ;
        tr_of[i] = t;
    }
    for (t = 0; t < nt; t++) {
        nk = 0;
        for (i = 0; i < np; i++)
            if (tr_of[i] == t)
                kids[nk++] = pnode[i];
        if (nk == 1) {
            tr_node[t] = kids[0];
        } else {
            idx = hydro_net_add_group(&NET, NODE_PARALLEL, kids, nk);
            if (idx < 0)
                return "Sistema mal definido";
            tr_node[t] = (uint8_t)idx;
        }
        troot[t] = tr_node[t];
    }
    if (nt > 1) {
        idx = hydro_net_add_group(&NET, NODE_SERIES, troot, nt);
        if (idx < 0)
            return "Sistema mal definido";
    } else {
        NET.root = tr_node[0];
    }
    if (ni.mode == 0) {
        if (!ni.sH)
            return "Falta la carga H";
        e = hydro_net_solve(&NET, ni.H, &NC);
        Htot = ni.H;
    } else {
        if (!ni.skp || !ni.sQk)
            return "Falta el tubo conocido y su Q";
        if (ni.kp > np)
            return "Ese tubo no existe";
        e = hydro_net_solve_back(&NET, pnode[(uint8_t)ni.kp - 1], ni.Qk / 1000, &NC, &Htot);
    }
    return e ? hydro_err_text(e) : 0;
}

/* ------------------------------------------------------------------ */
/* Resumen y memoria                                                   */
/* ------------------------------------------------------------------ */
static char b1[200], b2[200];

static real vel(uint8_t i)
{
    const net_node *nd = &NET.node[pnode[i]];
    return nd->Q / hydro_area(nd->pipe.D);
}

static void add_pipe_lines(void)
{
    uint8_t i, np = (uint8_t)ni.np;
    char a[NUMFMT_LEN], b[NUMFMT_LEN], c[NUMFMT_LEN];
    for (i = 0; i < np; i++) {
        const net_node *nd = &NET.node[pnode[i]];
        mfmt(b1, sizeof b1, " %s (tramo %d)  M = %s", (char[2]){ pname[i], 0 },
             tr_of[i] + 1, fmt_w(nd->M, 9, a));
        view_add(b1, C_FG);
        mfmt(b1, sizeof b1, "   Q %s l/s  h %s m  v %s", fmt_w(1000 * nd->Q, 7, a),
             fmt_w(nd->h, 7, b), fmt_w(vel(i), 6, c));
        view_add(b1, C_GRAY);
    }
}

static void summary(void)
{
    view_clear();
    view_add("RESULTADO  Sistema serie/paralelo", C_TITLE);
    view_add_sep();
    view_add_val("Q total", 1000 * NET.node[NET.root].Q, "l/s");
    view_add_val(ni.mode ? "H necesaria" : "H", Htot, "m");
    if (ni.mode)
        view_add_val("H en kPa", Htot * NC.gamma / 1000, "kPa");
    view_add_val("M total", NET.node[NET.root].M, 0);
    view_add_sep();
    add_pipe_lines();
    view_add_sep();
    mfmt(b1, sizeof b1, " Comprobacion: sum Q %s, sum h %s",
         fmt_w(NET.res_q * 1000, 7, b2), fmt_w(NET.res_h, 7, b2 + 100));
    view_add(b1, C_GRAY);
}

static void memo(void)
{
    uint8_t i, t, np = (uint8_t)ni.np, first;
    real k0 = hydro_module_coef(&NC);
    char a[NUMFMT_LEN];
    view_clear();
    view_add("MEMORIA  Sistema serie/paralelo", C_TITLE);
    view_add_sep();
    memo_sec("DATOS");
    for (i = 0; i < np; i++) {
        const npipe *p = &ni.p[i];
        const net_node *nd = &NET.node[pnode[i]];
        mfmt(b1, sizeof b1, " %s: tramo %d, L = %v m, D = %v m", (char[2]){ pname[i], 0 },
             tr_of[i] + 1, p->L, p->D / 1000);
        memo_line(b1, C_FG);
        if (p->sf)
            mfmt(b1, sizeof b1, "    f = %v (dato), SumK = %v", p->f, p->K);
        else
            mfmt(b1, sizeof b1, "    ks = %v m, SumK = %v; f auto = %v", p->ks / 1000,
                 p->K, nd->f);
        memo_line(b1, C_GRAY);
    }
    if (ni.mode == 0)
        memo_line(mfmt(b1, sizeof b1, " H = %v m", ni.H), C_FG);
    else
        memo_line(mfmt(b1, sizeof b1, " Q conocido en %s = %v l/s",
                       (char[2]){ pname[(uint8_t)ni.kp - 1], 0 }, ni.Qk), C_FG);
    memo_sec("MODULOS DE CAUDAL (h = M Q^2)");
    memo_line("M = 8/(pi^2 g) (f L/D^5 + SumK/D^4)", C_FG);
    memo_eq("8/(pi^2 g)", 0, mfmt(b2, sizeof b2, "8/(pi^2 (%v))", NC.g), k0, 0);
    for (i = 0; i < np; i++) {
        const net_node *nd = &NET.node[pnode[i]];
        char lhs[4] = { 'M', '_', pname[i], 0 };
        mfmt(b2, sizeof b2, "%v(%v(%v)/(%v)^5 + %v/(%v)^4)", k0, nd->f, nd->pipe.L,
             nd->pipe.D, nd->pipe.sumK, nd->pipe.D);
        memo_eq(lhs, 0, b2, nd->M, 0);
        if (nd->Mk > 0)
            memo_line(mfmt(b1, sizeof b1, "      (friccion %s + local %w)",
                           fmt_w(nd->Mf, 9, a), nd->Mk), C_GRAY);
    }
    memo_sec("REDUCCION DEL SISTEMA");
    for (t = 0; t < nt; t++) {
        const net_node *g = &NET.node[tr_node[t]];
        if (g->type != NODE_PARALLEL)
            continue;
        b2[0] = 0;
        first = 1;
        for (i = 0; i < np; i++)
            if (tr_of[i] == t) {
                if (!first)
                    strcat(b2, " + ");
                strcat(b2, "1/sqrt(");
                strcat(b2, fmt_w(NET.node[pnode[i]].M, 9, a));
                strcat(b2, ")");
                first = 0;
            }
        mfmt(b1, sizeof b1, "M tramo %d (paralelo)", t + 1);
        memo_line(b1, C_FG);
        strcpy(b1, "(");
        strcat(b1, b2);
        strcat(b1, ")^-2");
        memo_eq("  ", 0, b1, g->M, 0);
    }
    if (nt > 1) {
        b2[0] = 0;
        for (t = 0; t < nt; t++) {
            if (t)
                strcat(b2, " + ");
            strcat(b2, fmt_w(NET.node[tr_node[t]].M, 9, a));
        }
        memo_line("M total = suma de tramos en serie", C_FG);
        memo_eq("M", 0, b2, NET.node[NET.root].M, 0);
    }
    memo_sec("CAUDAL Y CARGA");
    if (ni.mode == 0) {
        memo_eq("Q", "sqrt(H/M)", mfmt(b2, sizeof b2, "sqrt(%v/%v)", ni.H,
                NET.node[NET.root].M), NET.node[NET.root].Q, "m3/s");
    } else {
        memo_line(" Con el Q conocido se sube por el arbol:", C_GRAY);
        memo_line(" h = M Q^2 en el tubo; en un paralelo", C_GRAY);
        memo_line(" Qi = sqrt(h/Mi); en serie h se suma.", C_GRAY);
        memo_eq("Q", 0, 0, NET.node[NET.root].Q, "m3/s");
        memo_eq("H", "M Q^2", mfmt(b2, sizeof b2, "%v(%v)^2", NET.node[NET.root].M,
                NET.node[NET.root].Q), Htot, "m");
        memo_res("p = gamma H", Htot * NC.gamma / 1000, "kPa");
    }
    memo_sec("REPARTO");
    for (t = 0; t < nt; t++) {
        const net_node *g = &NET.node[tr_node[t]];
        mfmt(b1, sizeof b1, "h tramo %d", t + 1);
        memo_eq(b1, "M Q^2", mfmt(b2, sizeof b2, "%v(%v)^2", g->M, g->Q), g->h, "m");
        if (g->type == NODE_PARALLEL)
            for (i = 0; i < np; i++)
                if (tr_of[i] == t) {
                    const net_node *nd = &NET.node[pnode[i]];
                    char lhs[4] = { 'Q', '_', pname[i], 0 };
                    memo_eq(lhs, "sqrt(h/M)", mfmt(b2, sizeof b2, "sqrt(%v/%v)", g->h,
                            nd->M), nd->Q, "m3/s");
                }
    }
    memo_sec("RESULTADOS");
    add_pipe_lines();
    if (NET.outer_iters > 1)
        memo_line(mfmt(b1, sizeof b1, " f automatico: %d vueltas de Colebrook-W.",
                       NET.outer_iters), C_GRAY);
    memo_sec("OBSERVACIONES");
    mfmt(b1, sizeof b1, " Nudos: |Q - sum Qi| max = %w l/s", NET.res_q * 1000);
    memo_line(b1, C_GRAY);
    mfmt(b1, sizeof b1, " Rutas: |h - sum hi| max = %w m", NET.res_h);
    memo_line(b1, C_GRAY);
}

/* Grafica: la ruta pasa por el tubo de mayor caudal de cada tramo */
static void graph(void)
{
    gseg s[GSEG_MAX];
    uint8_t t, i, np = (uint8_t)ni.np, best;
    real E0 = ni.sz1 ? ni.z1 : Htot;
    for (t = 0; t < nt && t < GSEG_MAX; t++) {
        const net_node *g = &NET.node[tr_node[t]], *nd;
        best = 0xFF;
        for (i = 0; i < np; i++)
            if (tr_of[i] == t && (best == 0xFF || NET.node[pnode[i]].Q > NET.node[pnode[best]].Q))
                best = i;
        nd = &NET.node[pnode[best]];
        memset(&s[t], 0, sizeof s[t]);
        s[t].L = nd->pipe.L;
        s[t].hloc = nd->M > 0 ? g->h * nd->Mk / nd->M : 0;
        s[t].hfr = g->h - s[t].hloc;
        s[t].vh = vel(best) * vel(best) / (2 * NC.g);
        s[t].name[0] = pname[best];
        if (g->type == NODE_PARALLEL) {
            s[t].name[1] = '+';
        }
    }
    graph_run("SISTEMA: LE y LP", E0, s, nt, E0 - Htot, 1);
}

/* ------------------------------------------------------------------ */
void scr_net(void)
{
    static const char *const fk_sum[5] = { "MEMORIA", "GRAFICO", "", "", "VOLVER" };
    static const char *const fk_memo[5] = { "RESUMEN", "GRAFICO", "", "", "VOLVER" };
    static uint8_t cur;
    form_t fm;
    uint8_t k, n;
    bool m;
    const char *err;

    if (!ni.snu) {
        ni.nu = g_set.h.nu;
        ni.snu = 1;
    }
    memset(&fm, 0, sizeof fm);
    fm.title = "SISTEMA SERIE/PARALELO (G)";
    fm.fk[3] = "AJUSTES";
    fm.fk[4] = "CALC";
    fm.hint = "Mismo tramo = paralelo; tramos en serie";
    for (;;) {
        n = build_form();
        fm.f = ff;
        fm.n = n;
        fm.cur = cur < n ? cur : 0;
        fm.on_commit = np_changed;
        fm_now = &fm;
        k = form_run(&fm);
        fm_now = 0;
        cur = fm.cur;
        if (k == K_QUIT || k == K_CLEAR)
            return;
        if (k == K_F4 || k == K_MODE) {
            scr_settings();
            continue;
        }
        if (k != K_F5 && k != K_ENTER)
            continue;
        if (!form_check(&fm))
            continue;
        err = compute();
        if (err) {
            fm.msg = err;
            fm.msg_color = C_ERR;
            continue;
        }
        m = false;
        for (;;) {
            if (m)
                memo();
            else
                summary();
            k = view_run("SISTEMA SERIE/PARALELO", m ? fk_memo : fk_sum);
            if (k == K_F1)
                m = !m;
            else if (k == K_F2)
                graph();
            else if (k == K_MODE)
                scr_settings();
            else
                break;
            if (ui_quit)
                return;
        }
        if (ui_quit)
            return;
    }
}
