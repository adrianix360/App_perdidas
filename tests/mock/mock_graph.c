/* mock_graph.c - graph_run para el PC: valida y guarda lo que recibe */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../../src/ui/graph.h"

int graph_calls, graph_n, graph_bad, graph_tank2;
real graph_E0, graph_Eend, graph_Elast;

static int fin(real x) { return x == x && x - x == 0; }

void graph_run(const char *title, real E0, const gseg *s, uint8_t n,
               real Eend, uint8_t tank2)
{
    uint8_t i;
    real E = E0;
    (void)title;
    graph_calls++;
    graph_n = n;
    graph_E0 = E0;
    graph_Eend = Eend;
    graph_tank2 = tank2;
    if (n == 0 || n > GSEG_MAX || !fin(E0) || (tank2 && !fin(Eend)))
        graph_bad++;
    for (i = 0; i < n && i < GSEG_MAX; i++) {
        if (!fin(s[i].L) || s[i].L < 0 || !fin(s[i].hloc) || !fin(s[i].hfr) ||
            !fin(s[i].vh) || !fin(s[i].jump) || s[i].vh < 0)
            graph_bad++;
        E += s[i].jump - s[i].hloc - s[i].hfr;
    }
    graph_Elast = E;
}
