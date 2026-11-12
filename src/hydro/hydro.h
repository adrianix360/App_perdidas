/*
 * hydro.h - Motor hidraulico de la app PERDIDAS (TI-84 Plus CE)
 *
 * C puro, sin dependencias de la calculadora. Compila con gcc en el PC
 * (pruebas) y con ez80-clang (CE Toolchain). Todo en SI dentro del motor:
 * m, s, m^3/s, Pa, W. Las conversiones de unidades van en la interfaz.
 *
 * Tipo numerico: `real`. En la calculadora es float de 32 bits (alli
 * double == float). En el PC se puede compilar como float (por defecto)
 * o como double (-DHYDRO_USE_DOUBLE) para comparar.
 */
#ifndef HYDRO_H
#define HYDRO_H

#include <math.h>

#ifdef HYDRO_USE_DOUBLE
typedef double real;
#define R_LOG10 log10
#define R_LOG   log
#define R_SQRT  sqrt
#define R_POW   pow
#define R_FABS  fabs
#define HYDRO_EPS_REL 1e-12      /* convergencia relativa de iteraciones */
#define HYDRO_BIS_REL 1e-12      /* ancho relativo final de biseccion    */
#else
typedef float real;
#define R_LOG10 log10f
#define R_LOG   logf
#define R_SQRT  sqrtf
#define R_POW   powf
#define R_FABS  fabsf
#define HYDRO_EPS_REL 4e-7f
#define HYDRO_BIS_REL 1e-6f
#endif

#define HYDRO_PI ((real)3.14159265358979)

/* ------------------------------------------------------------------ */
/* Metodos para el factor de friccion                                  */
/* ------------------------------------------------------------------ */
enum {
    FM_CW = 0,      /* Colebrook-White (implicita, metodo del curso)   */
    FM_SJ,          /* Swamee-Jain                                     */
    FM_HAALAND,     /* Haaland                                         */
    FM_GOUDAR,      /* Goudar-Sonnad (forma de la memoria)             */
    FM_COUNT
};

/* Regimen de flujo */
enum { REG_LAMINAR = 0, REG_TRANSITION, REG_TURBULENT };

/* Solucionador usado en el caudal maximo */
enum { SOLV_DIRECT = 0, SOLV_COURSE, SOLV_BISECTION };

/* ------------------------------------------------------------------ */
/* Codigos de error (0 = correcto)                                     */
/* ------------------------------------------------------------------ */
enum {
    H_OK = 0,
    H_ERR_D,          /* D debe ser > 0                                */
    H_ERR_L,          /* L debe ser > 0                                */
    H_ERR_Q,          /* Q debe ser > 0                                */
    H_ERR_NU,         /* nu debe ser > 0                               */
    H_ERR_KS,         /* ks debe ser >= 0                              */
    H_ERR_K,          /* Suma K debe ser >= 0                          */
    H_ERR_NOFLOW,     /* H <= 0: no hay flujo por gravedad             */
    H_ERR_ETA,        /* eficiencia fuera de (0, 1]                    */
    H_ERR_NOCONV,     /* no convergio                                  */
    H_ERR_NOROOT,     /* no hay solucion en el rango buscado           */
    H_ERR_KS_NEG,     /* calibracion: ks calculado negativo            */
    H_ERR_HV_NEG,     /* valvula: carga insuficiente, hace falta bomba */
    H_ERR_HT_NEG,     /* turbina: carga neta <= 0                      */
    H_ERR_HF_NEG,     /* calibracion: hf <= 0                          */
    H_ERR_LIST,       /* ningun diametro comercial alcanza             */
    H_ERR_NET,        /* red mal definida                              */
    H_ERR_CH,         /* C_H debe ser > 0                              */
    H_ERR_COUNT
};

/* ------------------------------------------------------------------ */
/* Advertencias (mascara de bits)                                      */
/* ------------------------------------------------------------------ */
#define W_LAMINAR      0x0001u  /* Re < 2000: f = 64/Re                */
#define W_TRANSITION   0x0002u  /* 2000 <= Re <= 4000: indicativo      */
#define W_KSD_RANGE    0x0004u  /* ks/D > 0,05                         */
#define W_V_HIGH       0x0008u  /* v > vmax                            */
#define W_V_LOW        0x0010u  /* v < vmin                            */
#define W_HM_HIGH      0x0020u  /* hm > 0,3 hf: revisar vp             */
#define W_P_NEG        0x0040u  /* presion manometrica negativa        */
#define W_FALLBACK     0x0080u  /* iteracion del curso fallo: biseccion*/
#define W_LOCAL_SMALL  0x0100u  /* L/D > 4000: locales despreciables   */
#define W_SJ_RANGE     0x0200u  /* fuera del rango de Swamee-Jain      */
#define W_CAVIT        0x0400u  /* p/gamma < -10,3 m: imposible        */
#define W_KS_NEG       0x0800u  /* calibracion: ks negativo            */

/* ------------------------------------------------------------------ */
/* Configuracion (Ajustes)                                             */
/* ------------------------------------------------------------------ */
typedef struct {
    real g;          /* m/s^2, 9,81                                    */
    real gamma;      /* N/m^3, 9810                                    */
    real nu;         /* m^2/s, 1,0e-6                                  */
    real tol;        /* m, tolerancia absoluta de la iteracion, 1e-5   */
    real re_lam;     /* 2000                                           */
    real re_turb;    /* 4000                                           */
    real ld_limit;   /* 4000 (aviso de locales despreciables)          */
    real v_min;      /* 0,3 m/s                                        */
    real v_max;      /* 5 m/s                                          */
    real pv;         /* presion de vapor, Pa (2339 a 20 C)             */
    real hm_ratio;   /* 0,3                                            */
    unsigned char method;   /* FM_*                                    */
    unsigned char max_iter; /* tope de la iteracion del curso, 200     */
} hydro_cfg;

void hydro_cfg_default(hydro_cfg *c);

/* ------------------------------------------------------------------ */
/* Tuberia                                                             */
/* ------------------------------------------------------------------ */
typedef struct {
    real D;        /* diametro interno, m                              */
    real L;        /* longitud, m                                      */
    real ks;       /* rugosidad absoluta, m                            */
    real sumK;     /* suma de coeficientes de perdidas locales         */
    real f_fixed;  /* > 0: f dado (no se calcula)                      */
} hydro_pipe;

/* Estado completo de un tubo con un caudal dado (tipo A) */
typedef struct {
    real Q, A, v, Re, ksD, f, hf, hm, hT, hv2g, LD;
    unsigned char regime;
    unsigned char f_iters;
    unsigned int warn;
} hydro_state;

/* Registro de iteraciones para la memoria de calculo. Si total > n, las
 * filas 0..n/2-1 son las primeras y n/2..n-1 las ultimas iteraciones. */
#define HYDRO_LOG_MAX  32
#define HYDRO_LOG_COLS 5
typedef struct {
    unsigned char n;        /* filas guardadas                         */
    int total;              /* iteraciones totales (puede ser > n)     */
    real r[HYDRO_LOG_MAX][HYDRO_LOG_COLS];
} hydro_log;

void hydro_log_clear(hydro_log *lg);

/* ------------------------------------------------------------------ */
/* Funciones base                                                      */
/* ------------------------------------------------------------------ */
real hydro_area(real D);

/* Factor de friccion. Re > 0. Devuelve H_OK o error. */
typedef struct {
    real f;
    unsigned char regime;
    unsigned char iters;     /* iteraciones de Colebrook-White          */
} hydro_fric;
int hydro_friction(real Re, real ksD, unsigned char method,
                   const hydro_cfg *c, hydro_fric *out);

/* Validacion de una tuberia */
int hydro_check_pipe(const hydro_pipe *p, const hydro_cfg *c);

/* Tipo A: perdidas dado el caudal */
int hydro_pipe_state(const hydro_pipe *p, real Q, const hydro_cfg *c,
                     hydro_state *s);

/* Tipo B: caudal maximo con carga disponible H */
typedef struct {
    hydro_state st;
    unsigned char solver;     /* SOLV_*                                 */
    unsigned char course_ok;  /* la iteracion del curso convergio        */
    int iters;
} hydro_qmax_res;
int hydro_qmax(const hydro_pipe *p, real H, const hydro_cfg *c,
               hydro_qmax_res *r, hydro_log *lg);

/* Tipo C: bomba (Hs = carga estatica a vencer: (z2+p2/g)-(z1+p1/g)) */
typedef struct {
    hydro_state st;
    real Hm;      /* H_B o H_T                                         */
    real Pn, Pb;  /* potencia neta y bruta, W                          */
} hydro_machine_res;
int hydro_pump(const hydro_pipe *p, real Q, real Hs, real eta,
               const hydro_cfg *c, hydro_machine_res *r);
/* Tipo C: turbina (Ha = carga disponible: (z1+p1/g)-(z2+p2/g)) */
int hydro_turbine(const hydro_pipe *p, real Q, real Ha, real eta,
                  const hydro_cfg *c, hydro_machine_res *r);
/* Carga de bomba a partir de su potencia bruta: H = eta P / (gamma Q) */
real hydro_head_from_power(real P, real eta, real Q, const hydro_cfg *c);

/* Tipo D: diseno del diametro */
typedef struct {
    real D_exact;
    int iters;
    real D_com;               /* 0 si no hay lista o ninguno alcanza    */
    int idx_com;              /* -1 si no hay                           */
    hydro_state st_exact;     /* Qd con D exacto                        */
    hydro_state st_com_qd;    /* Qd con D comercial                     */
    hydro_qmax_res qmax;      /* caudal maximo con D comercial          */
    real vp;                  /* velocidad de perdidas (0 si no aplica) */
    unsigned int warn;
} hydro_design_res;
int hydro_design(const hydro_pipe *p, real Qd, real H,
                 const real *list, int n, const hydro_cfg *c,
                 hydro_design_res *r, hydro_log *lg);

/* Tipo E: calibracion. dz = z1 - z2; dp = p1/g - p2/g (m) */
typedef struct {
    real A, v, hm, htot, hf, f, Re, ksD, ks;
    unsigned int warn;
} hydro_calib_res;
int hydro_calibrate(real D, real L, real Q, real sumK, real dz, real dp,
                    const hydro_cfg *c, hydro_calib_res *r);

/* Tipo F: valvula de control. Ha = carga disponible */
typedef struct {
    hydro_state st;
    real hv, Kv;
} hydro_valve_res;
int hydro_valve(const hydro_pipe *p, real Q, real Ha, const hydro_cfg *c,
                hydro_valve_res *r);

/* Tipo I: Hazen-Williams */
real hydro_hw_hf(real Q, real D, real L, real CH);
real hydro_hw_q(real H, real D, real L, real CH);

/* Presion en un punto: p/gamma = head_up + HB - v^2/2g - h_loss
 * head_up = z1 + p1/gamma - zP. Devuelve p/gamma y marca avisos. */
real hydro_pressure_head(real head_up, real HB, real v, real h_loss,
                         const hydro_cfg *c, unsigned int *warn);

/* Velocidad de perdidas v_p = sqrt(2 g (H - hf) / sumK) */
real hydro_vp(real H, real hf, real sumK, const hydro_cfg *c);

/* ------------------------------------------------------------------ */
/* Tipo G: sistemas en serie y paralelo (modulo de caudal M)           */
/* ------------------------------------------------------------------ */
#define NET_MAX        16
#define NET_MAX_CHILD  6
enum { NODE_PIPE = 0, NODE_SERIES, NODE_PARALLEL };

typedef struct {
    unsigned char type;
    unsigned char nchild;
    unsigned char child[NET_MAX_CHILD];
    hydro_pipe pipe;     /* solo NODE_PIPE                              */
    real f;              /* f usado (dado o calculado)                  */
    real Mf, Mk;         /* parte de friccion y local (solo tubos)      */
    real M;              /* modulo: h = M Q^2                           */
    real Q, h;
} net_node;

typedef struct {
    unsigned char n;
    unsigned char root;
    net_node node[NET_MAX];
    int outer_iters;     /* vueltas de f automatico                     */
    real res_q;          /* max |Q - suma Qi| en paralelos              */
    real res_h;          /* max error de suma de h en rutas             */
} hydro_net;

real hydro_module_coef(const hydro_cfg *c);   /* 8 / (pi^2 g) */
void hydro_net_init(hydro_net *n);
int  hydro_net_add_pipe(hydro_net *n, real L, real D, real f, real ks,
                        real sumK);
int  hydro_net_add_group(hydro_net *n, unsigned char type,
                         const unsigned char *kids, unsigned char nk);
/* Hacia adelante: dado H, caudales y perdidas en todos los nodos */
int hydro_net_solve(hydro_net *n, real H, const hydro_cfg *c);
/* Hacia atras: dado Q en el nodo k, carga total H */
int hydro_net_solve_back(hydro_net *n, unsigned char k, real Qk,
                         const hydro_cfg *c, real *H);

/* Textos cortos (ASCII) */
const char *hydro_err_text(int err);
const char *hydro_method_name(unsigned char m);

#endif /* HYDRO_H */
