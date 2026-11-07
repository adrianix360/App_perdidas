/* Mide el tamano del motor en el eZ80: llama a todas sus funciones. */
#include <ti/screen.h>
#include <ti/getcsc.h>
#include "../../../../src/hydro/hydro.c"

static volatile real sink;

int main(void)
{
    hydro_cfg c;
    hydro_pipe p = { 0.2f, 1000.0f, 1.5e-6f, 6.7f, 0.0f };
    hydro_state s;
    hydro_qmax_res q;
    hydro_design_res d;
    hydro_calib_res k;
    hydro_valve_res v;
    hydro_machine_res m;
    hydro_fric fr;
    static hydro_log lg;
    static hydro_net n;
    static const real list[] = { 0.15f, 0.2f, 0.25f };
    unsigned char kids[2];
    real H;
    int a, b;

    hydro_cfg_default(&c);
    hydro_friction(1e5f, 1e-4f, FM_GOUDAR, &c, &fr);
    hydro_pipe_state(&p, 0.072f, &c, &s);
    hydro_qmax(&p, 20.0f, &c, &q, &lg);
    hydro_design(&p, 0.05f, 10.0f, list, 3, &c, &d, &lg);
    hydro_calibrate(0.274f, 405.0f, 0.172f, 3.5f, 65.0f, -48.0f, &c, &k);
    hydro_valve(&p, 0.05f, 50.0f, &c, &v);
    hydro_pump(&p, 0.05f, 20.0f, 0.7f, &c, &m);
    hydro_turbine(&p, 0.05f, 50.0f, 0.7f, &c, &m);
    sink = hydro_hw_hf(0.05f, 0.2f, 100.0f, 150.0f) + hydro_hw_q(5.0f, 0.2f, 100.0f, 150.0f);
    sink = hydro_pressure_head(10.0f, 0.0f, 2.0f, 3.0f, &c, 0) + hydro_vp(8.0f, 6.0f, 2.0f, &c);
    sink = hydro_head_from_power(1000.0f, 0.7f, 0.01f, &c);
    hydro_net_init(&n);
    a = hydro_net_add_pipe(&n, 100.0f, 0.1f, 0.02f, 0.0f, 0.0f);
    b = hydro_net_add_pipe(&n, 100.0f, 0.1f, 0.0f, 1e-5f, 1.0f);
    kids[0] = a; kids[1] = b;
    hydro_net_add_group(&n, NODE_PARALLEL, kids, 2);
    hydro_net_solve(&n, 10.0f, &c);
    hydro_net_solve_back(&n, 0, 0.01f, &c, &H);
    os_ClrHome();
    os_PutStrFull(hydro_err_text(H_ERR_D));
    os_PutStrFull(hydro_method_name(FM_SJ));
    while (!os_GetCSC());
    return 0;
}
