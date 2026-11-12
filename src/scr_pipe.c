/*
 * scr_pipe.c - Tuberia simple: tipos A, B, C, D, E, F e I.
 * Cada tipo: formulario -> calculo con el motor -> resumen y memoria de
 * calculo paso a paso (DATOS, CALCULOS, ITERACIONES, RESULTADOS,
 * OBSERVACIONES). Los datos se comparten entre tipos (ultimo valor).
 * Unidades en pantalla: Q l/s, D mm, ks mm, L m, H m; motor en SI.
 */
#include <string.h>
#include "app.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "ui/numfmt.h"
#include "ui/memo.h"
#include "data/data.h"

/* ------------------------------------------------------------------ */
/* Datos compartidos (unidades de pantalla)                            */
/* ------------------------------------------------------------------ */
static struct {
    real Q, H, D, L, ks, K, nu, f, CH, eta, Hs, zb, Hp;
    real z1, z2, p1, p2;
    uint8_t sQ, sH, sD, sL, sks, sK, snu, sf, sCH, seta, sHs, szb, sHp;
    uint8_t sz1, sz2, sp1, sp2;
    uint8_t mach, dset, valve, modeI;
} in;

static const char *const mach_names[2] = { "Bomba", "Turbina" };
static const char *const yesno[2] = { "No", "Si" };
static const char *const modeI_names[2] = { "hf dado Q", "Q dado H" };

/* Resultados del ultimo calculo */
static hydro_cfg C;
static hydro_pipe P;
static hydro_log LG;
static union {
    hydro_state st;
    hydro_qmax_res q;
    hydro_machine_res m;
    hydro_design_res d;
    hydro_calib_res k;
    hydro_valve_res v;
} R;
static struct {          /* extras de algunos tipos */
    real ph, hw, err, Qhw;
    hydro_state st2;     /* D: valvula con D comercial */
    hydro_valve_res val;
    uint8_t has_val;
} X;
static real dlist[24];
static uint8_t dlist_n;
static uint8_t tipo;

static const char *const titles[PT_COUNT] = {
    "PERDIDAS DADO Q  (A)", "CAUDAL MAXIMO  (B)", "DIAMETRO DE DISENO (D)",
    "BOMBA O TURBINA  (C)", "VALVULA DE CONTROL (F)", "CALIBRAR RUGOSIDAD (E)",
    "DARCY-W. vs HAZEN-W. (I)"
};

/* ------------------------------------------------------------------ */
/* Campos                                                              */
/* ------------------------------------------------------------------ */
#define FLD(lab, un, v, s, fl) { lab, un, &in.v, 0, &in.s, fl, 0, 0, 0, 0 }
#define F_Q   FLD("Caudal Q", "l/s", Q, sQ, FF_POS)
#define F_D   FLD("Diametro D", "mm", D, sD, FF_POS)
#define F_L   FLD("Longitud L", "m", L, sL, FF_POS)
#define F_KS  FLD("Rugosidad ks", "mm", ks, sks, FF_NONNEG)
#define F_K   FLD("Suma K", 0, K, sK, FF_NONNEG)
#define F_NU  FLD("Viscosidad nu", "m2/s", nu, snu, FF_POS)
#define F_F   FLD("f dado (opc.)", 0, f, sf, FF_POS | FF_OPT)
#define F_MET { "Metodo de f", 0, 0, &g_set.h.method, 0, FF_CHOICE, method_names, FM_COUNT, 0, 0 }

static form_field f_A[] = { F_Q, F_D, F_L, F_KS, F_K, F_NU, F_F,
    FLD("H sobre punto(opc)", "m", Hp, sHp, FF_ANY | FF_OPT), F_MET };
static form_field f_B[] = { FLD("Carga H", "m", H, sH, FF_ANY), F_D, F_L,
    F_KS, F_K, F_NU, F_F, F_MET };
static form_field f_C[] = {
    { "Equipo", 0, 0, &in.mach, 0, FF_CHOICE, mach_names, 2, 0, 0 },
    F_Q, F_D, F_L, F_KS, F_K, F_NU,
    FLD("Desnivel Hs/Ha", "m", Hs, sHs, FF_ANY),
    { "Eficiencia eta", "0-1", &in.eta, 0, &in.seta, FF_RANGE, 0, 0, 0.001, 1 },
    F_F, FLD("Cota z equipo(opc)", "m", zb, szb, FF_ANY | FF_OPT), F_MET };
static form_field f_D[] = { FLD("Caudal diseno Qd", "l/s", Q, sQ, FF_POS),
    FLD("Carga H", "m", H, sH, FF_ANY), F_L, F_KS, F_K, F_NU,
    { "Lista diametros", 0, 0, &in.dset, 0, FF_CHOICE, diam_set_names, DIAM_SETS, 0, 0 },
    { "Valvula control", 0, 0, &in.valve, 0, FF_CHOICE, yesno, 2, 0, 0 },
    F_MET };
static form_field f_F[] = { F_Q, F_D, F_L, F_KS, F_K, F_NU,
    FLD("Carga H", "m", H, sH, FF_ANY), F_F, F_MET };
static form_field f_E[] = {
    FLD("Cota z1", "m", z1, sz1, FF_ANY), FLD("Cota z2", "m", z2, sz2, FF_ANY),
    FLD("Presion p1/gamma", "m", p1, sp1, FF_ANY),
    FLD("Presion p2/gamma", "m", p2, sp2, FF_ANY),
    F_L, F_D, F_Q, F_K, F_NU };
static form_field f_I[] = {
    { "Calcular", 0, 0, &in.modeI, 0, FF_CHOICE, modeI_names, 2, 0, 0 },
    FLD("Q (modo hf)", "l/s", Q, sQ, FF_POS | FF_OPT),
    FLD("H (modo Q)", "m", H, sH, FF_POS | FF_OPT),
    F_D, F_L, F_KS, FLD("Suma K (solo DW)", 0, K, sK, FF_NONNEG), F_NU,
    { "C_H Hazen-W.", 0, &in.CH, 0, &in.sCH, FF_RANGE, 0, 0, 1, 200 },
    F_MET };

static form_field *const forms[PT_COUNT] = { f_A, f_B, f_D, f_C, f_F, f_E, f_I };
static const uint8_t nforms[PT_COUNT] = {
    sizeof f_A / sizeof f_A[0], sizeof f_B / sizeof f_B[0],
    sizeof f_D / sizeof f_D[0], sizeof f_C / sizeof f_C[0],
    sizeof f_F / sizeof f_F[0], sizeof f_E / sizeof f_E[0],
    sizeof f_I / sizeof f_I[0] };

/* ------------------------------------------------------------------ */
/* Memoria de calculo y resumen como "programas" de datos              */
/* ------------------------------------------------------------------ */
/* Los textos usan plantillas: {NOMBRE} se sustituye por el valor con los
 * decimales de Ajustes y {NOMBRE!} por un valor corto (7 caracteres).
 * Asi cada formula es solo datos y el programa cabe en 64 KiB. */

enum {
    V_Q, V_QLS, V_QD, V_D, V_L, V_KS, V_K, V_NU, V_G, V_GAM,
    V_A, V_V, V_RE, V_KSD, V_A37, V_F, V_INVSF, V_HV2G, V_HF, V_HM, V_HT,
    V_LD, V_HMHF, V_FIT, V_TOL, V_ITER, V_H,
    V_HS, V_ETA, V_HMACH, V_PN, V_PB, V_PNKW, V_PBKW, V_PBHP, V_ZB, V_COTA,
    V_HP, V_PH, V_PKPA, V_HV, V_KV,
    V_DEX, V_DCOM, V_VP, V_HFCQ, V_VCQ,
    V_EXV, V_EXRE, V_EXF, V_EXHF, V_EXHM, V_EXHT,
    V_Z1, V_Z2, V_P1, V_P2, V_HTOT, V_SF, V_KSMM,
    V_CH, V_HW, V_ERR, V_QHW, V_QHWLS,
    V_VALHT, V_VALHV, V_VALKV, V_VALV,
    V_COUNT
};

static const char *const vname[V_COUNT] = {
    "Q", "QLS", "QD", "D", "L", "KS", "K", "NU", "G", "GAM",
    "A", "V", "RE", "KSD", "A37", "F", "INVSF", "HV2G", "HF", "HM", "HT",
    "LD", "HMHF", "FIT", "TOL", "ITER", "H",
    "HS", "ETA", "HMACH", "PN", "PB", "PNKW", "PBKW", "PBHP", "ZB", "COTA",
    "HP", "PH", "PKPA", "HV", "KV",
    "DEX", "DCOM", "VP", "HFCQ", "VCQ",
    "EXV", "EXRE", "EXF", "EXHF", "EXHM", "EXHT",
    "Z1", "Z2", "P1", "P2", "HTOT", "SF", "KSMM",
    "CH", "HW", "ERR", "QHW", "QHWLS",
    "VALHT", "VALHV", "VALKV", "VALV",
};

static real V[V_COUNT];
static uint32_t FL;           /* banderas para las condiciones */
static unsigned int W;        /* advertencias a mostrar        */

enum {
    G_FIX, G_LAM, G_TRANS, G_CW, G_SJ, G_HA, G_GO, G_HP, G_PUMP, G_ZB,
    G_COURSE, G_BIS, G_DIRECT, G_FB, G_VP, G_VAL, G_MODEQ, G_KPOS,
    G_WITHQ, G_HASD
};

enum { M_END = 0, M_SEC, M_DATA, M_EQ, M_RES, M_LINE, M_IF, M_IFN, M_ENDIF,
       M_CALL, M_TABLE, M_WARN, M_DLIST, M_SEP };

typedef struct {
    uint8_t op, id;
    const char *a, *b, *c, *u;
} mstep;

#define SEC(t)            { M_SEC, 0, t, 0, 0, 0 }
#define DAT(l, i, u)      { M_DATA, i, l, 0, 0, u }
#define EQ(l, f, s, i, u) { M_EQ, i, l, f, s, u }
#define RES(l, i, u)      { M_RES, i, l, 0, 0, u }
#define LN(t, col)        { M_LINE, col, t, 0, 0, 0 }
#define IF(g)             { M_IF, g, 0, 0, 0, 0 }
#define IFN(g)            { M_IFN, g, 0, 0, 0, 0 }
#define ENDIF             { M_ENDIF, 0, 0, 0, 0, 0 }
#define CALL(n)           { M_CALL, n, 0, 0, 0, 0 }
#define TAB(k)            { M_TABLE, k, 0, 0, 0, 0 }
#define WARNS             { M_WARN, 0, 0, 0, 0, 0 }
#define DLIST             { M_DLIST, 0, 0, 0, 0, 0 }
#define SEP               { M_SEP, 0, 0, 0, 0, 0 }
#define STOP              { M_END, 0, 0, 0, 0, 0 }

/* ---- subprogramas ---- */
enum { S_DATA, S_CALC, S_OBS, S_STATE, S_COUNT };

static const mstep p_data[] = {
    SEC("DATOS"),
    IF(G_WITHQ), DAT("Q", V_Q, "m3/s"), ENDIF,
    IF(G_HASD), DAT("D", V_D, "m"), ENDIF,
    DAT("L", V_L, "m"),
    IF(G_FIX), DAT("f (dato)", V_F, 0), ENDIF,
    IFN(G_FIX), DAT("ks", V_KS, "m"), DAT("nu", V_NU, "m2/s"), ENDIF,
    DAT("Suma K", V_K, 0),
    DAT("g", V_G, "m/s2"),
    IFN(G_FIX), LN(" Metodo de f: {METHOD}", C_GRAY), ENDIF,
    STOP
};

static const mstep p_calc[] = {
    EQ("A", "pi D^2/4", "pi({D})^2/4", V_A, "m2"),
    EQ("v", "Q/A", "{Q}/{A}", V_V, "m/s"),
    EQ("Re", "v D/nu", "{V}({D})/{NU}", V_RE, 0),
    IF(G_FIX), EQ("f", 0, 0, V_F, "(dato)"), ENDIF,
    IFN(G_FIX),
      IF(G_LAM), EQ("f", "64/Re", "64/{RE}", V_F, "(laminar)"), ENDIF,
      IFN(G_LAM),
        EQ("ks/D", 0, "{KS}/{D}", V_KSD, 0),
        IF(G_SJ),
          EQ("f", "0.25/[log(ks/3.7D + 5.74/Re^0.9)]^2",
             "0.25/[log({A37} + 5.74/{RE}^0.9)]^2", V_F, "(Swamee-Jain)"),
        ENDIF,
        IF(G_HA),
          EQ("1/sqrt(f)", "-1.8 log[(ks/3.7D)^1.11 + 6.9/Re]",
             "-1.8 log[({A37})^1.11 + 6.9/{RE}]", V_INVSF, 0),
          RES("f (Haaland)", V_F, 0),
        ENDIF,
        IF(G_GO),
          LN("1/sqrt(f) = 0.8686 ln(0.4587 Re/(C-0.31)^(C/(C+1)))", C_FG),
          LN("C = 0.124 Re ks/D + ln(0.4587 Re)", C_FG),
          RES("f (Goudar-Sonnad)", V_F, 0),
        ENDIF,
        IF(G_CW),
          LN("1/sqrt(f) = -2 log(ks/3.7D + 2.51/(Re sqrt(f)))", C_FG),
          LN("      = -2 log({A37} + 2.51/({RE} sqrt(f)))", C_GRAY),
          LN(" Sustitucion sucesiva desde f1 = 0.0001: {FIT!} iteraciones", C_GRAY),
          RES("f (Colebrook-White)", V_F, 0),
        ENDIF,
        IF(G_TRANS), LN(" Re en transicion: f indicativo", C_WARN), ENDIF,
      ENDIF,
    ENDIF,
    EQ("v^2/2g", 0, "({V})^2/(2({G}))", V_HV2G, "m"),
    EQ("hf", "f (L/D) v^2/2g", "{F}({L}/{D})({HV2G})", V_HF, "m"),
    EQ("hm", "SumK v^2/2g", "{K}({HV2G})", V_HM, "m"),
    EQ("hT", "hf + hm", "{HF} + {HM}", V_HT, "m"),
    STOP
};

static const mstep p_obs[] = {
    SEC("OBSERVACIONES"),
    IF(G_KPOS), LN(" L/D = {LD!}; hm/hf = {HMHF!} %", C_GRAY), ENDIF,
    WARNS,
    STOP
};

static const mstep p_state[] = {
    DAT("Q", V_QLS, "l/s"),
    DAT("v", V_V, "m/s"),
    DAT("Re", V_RE, 0),
    IF(G_FIX), DAT("f (dato)", V_F, 0), ENDIF,
    IFN(G_FIX), DAT("f", V_F, 0), ENDIF,
    DAT("hf", V_HF, "m"),
    DAT("hm", V_HM, "m"),
    DAT("hT = hf + hm", V_HT, "m"),
    STOP
};

static const mstep *const subs[S_COUNT] = { p_data, p_calc, p_obs, p_state };

/* ---- A ---- */
static const mstep sA[] = {
    LN("RESULTADO  Perdidas dado Q", C_TITLE), SEP,
    CALL(S_STATE),
    DAT("v^2/2g", V_HV2G, "m"),
    IF(G_HP), DAT("p/gamma punto", V_PH, "m"), DAT("p punto", V_PKPA, "kPa"), ENDIF,
    SEP, WARNS, STOP
};
static const mstep mA[] = {
    LN("MEMORIA  Perdidas dado Q (A)", C_TITLE), SEP,
    CALL(S_DATA),
    IF(G_HP), DAT("H sobre punto", V_HP, "m"), ENDIF,
    SEC("CALCULOS"), CALL(S_CALC),
    IF(G_HP), EQ("p/gamma", "H - v^2/2g - hT", "{HP} - {HV2G} - {HT}", V_PH, "m"), ENDIF,
    SEC("RESULTADOS"),
    RES("hf", V_HF, "m"), RES("hm", V_HM, "m"), RES("hT", V_HT, "m"),
    IF(G_HP), RES("p", V_PKPA, "kPa"), ENDIF,
    CALL(S_OBS), STOP
};

/* ---- B ---- */
static const mstep sB[] = {
    LN("RESULTADO  Caudal maximo", C_TITLE), SEP,
    CALL(S_STATE),
    IF(G_COURSE), LN(" Metodo: iteracion del curso", C_GRAY), ENDIF,
    IF(G_DIRECT), LN(" Metodo: directo (f dado)", C_GRAY), ENDIF,
    IF(G_BIS), LN(" Metodo: biseccion sobre v", C_GRAY), ENDIF,
    SEP, WARNS, STOP
};
static const mstep mB[] = {
    LN("MEMORIA  Caudal maximo (B)", C_TITLE), SEP,
    CALL(S_DATA), DAT("H", V_H, "m"),
    IF(G_DIRECT),
      SEC("CALCULOS"),
      EQ("v", "sqrt(2gH/(f L/D + SumK))", "sqrt(2({G})({H})/({F}({L}/{D})+{K}))",
         V_V, "m/s"),
    ENDIF,
    IFN(G_DIRECT),
      SEC("ITERACIONES"),
      IF(G_COURSE),
        LN("v = -sqrt(8gD hf/L) log(ks/3.7D + 2.51 nu sqrt(L)/sqrt(2gD^3 hf))", C_FG),
        LN("hm = SumK v^2/2g;  hf(i+1) = H - hm", C_FG),
        LN(" hf1 = H; parar si |dhf| <= {TOL!} m", C_GRAY),
        TAB(0),
      ENDIF,
      IF(G_BIS),
        IF(G_FB), LN(" La iteracion del curso no convergio.", C_WARN), ENDIF,
        LN("Biseccion: (f L/D + SumK) v^2/2g = H", C_FG),
        TAB(1),
      ENDIF,
      LN(" {ITER!} iteraciones", C_GRAY),
      SEC("CALCULOS CON v FINAL"),
    ENDIF,
    EQ("Q", "v A", "{V}({A})", V_Q, "m3/s"),
    CALL(S_CALC),
    SEC("RESULTADOS"),
    RES("Q", V_QLS, "l/s"), RES("v", V_V, "m/s"),
    LN(" Comprobacion: hf + hm = {HT} m (H = {H})", C_GRAY),
    CALL(S_OBS), STOP
};

/* ---- C ---- */
static const mstep sC[] = {
    IF(G_PUMP), LN("RESULTADO  Bomba", C_TITLE), ENDIF,
    IFN(G_PUMP), LN("RESULTADO  Turbina", C_TITLE), ENDIF,
    SEP, CALL(S_STATE),
    IF(G_PUMP),
      DAT("HB", V_HMACH, "m"), DAT("Pn (agua)", V_PNKW, "kW"),
      DAT("Pb (consume)", V_PBKW, "kW"),
    ENDIF,
    IFN(G_PUMP),
      DAT("HT", V_HMACH, "m"), DAT("Pn (genera)", V_PNKW, "kW"),
      DAT("Pb (agua)", V_PBKW, "kW"),
    ENDIF,
    DAT("Pb", V_PBHP, "Hp"),
    IF(G_ZB), DAT("Cota piezometr.", V_COTA, "m"), ENDIF,
    SEP, WARNS, STOP
};
static const mstep mC[] = {
    IF(G_PUMP), LN("MEMORIA  Bomba (C)", C_TITLE), ENDIF,
    IFN(G_PUMP), LN("MEMORIA  Turbina (C)", C_TITLE), ENDIF,
    SEP, CALL(S_DATA),
    IF(G_PUMP), DAT("Hs (estatica)", V_HS, "m"), ENDIF,
    IFN(G_PUMP), DAT("Ha (disponible)", V_HS, "m"), ENDIF,
    DAT("eta", V_ETA, 0), DAT("gamma", V_GAM, "N/m3"),
    SEC("CALCULOS"), CALL(S_CALC),
    IF(G_PUMP),
      EQ("HB", "Hs + hT", "{HS} + {HT}", V_HMACH, "m"),
      EQ("Pn", "gamma Q HB", "{GAM}({Q})({HMACH})", V_PN, "W"),
      EQ("Pb", "Pn/eta", "{PN}/{ETA}", V_PB, "W"),
    ENDIF,
    IFN(G_PUMP),
      EQ("HT", "Ha - hT", "{HS} - {HT}", V_HMACH, "m"),
      EQ("Pb", "gamma Q HT", "{GAM}({Q})({HMACH})", V_PB, "W"),
      EQ("Pn", "eta Pb", "{ETA}({PB})", V_PN, "W"),
    ENDIF,
    SEC("RESULTADOS"),
    IF(G_PUMP), RES("HB", V_HMACH, "m"), ENDIF,
    IFN(G_PUMP), RES("HT", V_HMACH, "m"), ENDIF,
    RES("Pn (neta)", V_PNKW, "kW"), RES("Pb (bruta)", V_PBKW, "kW"),
    RES("Pb", V_PBHP, "Hp"),
    IF(G_ZB),
      IF(G_PUMP), EQ("Cota piez.", "z + HB", "{ZB} + {HMACH}", V_COTA, "m"), ENDIF,
      IFN(G_PUMP), EQ("Cota piez.", "z - HT", "{ZB} - {HMACH}", V_COTA, "m"), ENDIF,
    ENDIF,
    LN(" Bruta = la mayor; neta = la menor (1 Hp = 745.7 W)", C_GRAY),
    CALL(S_OBS), STOP
};

/* ---- D ---- */
static const mstep sD[] = {
    LN("RESULTADO  Diametro de diseno", C_TITLE), SEP,
    DAT("D exacto", V_DEX, "mm"), DAT("D comercial", V_DCOM, "mm"),
    DAT("Qmax con D com.", V_QLS, "l/s"), DAT("v (Qmax)", V_V, "m/s"),
    DAT("hf (Qmax)", V_HF, "m"), DAT("hm (Qmax)", V_HM, "m"),
    DAT("hm/hf", V_HMHF, "%"),
    IF(G_VP), DAT("vp", V_VP, "m/s"), ENDIF,
    IF(G_VAL), DAT("hv valvula (Qd)", V_VALHV, "m"), DAT("Kv valvula", V_VALKV, 0), ENDIF,
    SEP, WARNS, STOP
};
static const mstep mD[] = {
    LN("MEMORIA  Diametro de diseno (D)", C_TITLE), SEP,
    CALL(S_DATA), DAT("Qd", V_QD, "m3/s"), DAT("H", V_H, "m"),
    SEC("DIAMETRO EXACTO"),
    LN("Se busca D tal que hT(Qd, D) = H", C_FG),
    LN("(hT baja al crecer D: biseccion geometrica)", C_GRAY),
    TAB(2),
    LN(" {ITER!} iteraciones", C_GRAY),
    RES("D exacto", V_DEX, "mm"),
    LN(" Con D exacto: v = {EXV!}, Re = {EXRE!}, f = {EXF!}", C_GRAY),
    LN(" hf = {EXHF!}, hm = {EXHM!}, hT = {EXHT!} m", C_GRAY),
    SEC("DIAMETRO COMERCIAL"),
    LN(" Lista: {LISTNAME} (mm)", C_GRAY), DLIST,
    LN(" Menor diametro >= D exacto:", C_FG),
    RES("D comercial", V_DCOM, "mm"),
    SEC("CAUDAL CON D COMERCIAL (tipo B)"),
    IF(G_COURSE), LN(" Iteracion del curso", C_GRAY), ENDIF,
    IFN(G_COURSE), LN(" Biseccion sobre v", C_GRAY), ENDIF,
    CALL(S_CALC),
    RES("Qmax", V_QLS, "l/s"),
    LN(" hm/hf = {HMHF!} %", C_GRAY),
    IF(G_VP),
      EQ("vp", "sqrt(2g(H - hf)/SumK)", "sqrt(2({G})({H} - {HFCQ})/{K})", V_VP, "m/s"),
      LN(" v con Qd = {VCQ!} m/s debe ser <= vp", C_WARN),
    ENDIF,
    IF(G_VAL),
      SEC("VALVULA DE CONTROL (Qd, D comercial)"),
      EQ("hT", 0, 0, V_VALHT, "m"),
      EQ("hv", "H - hT", "{H} - {VALHT}", V_VALHV, "m"),
      EQ("Kv", "2g hv/v^2", "2({G})({VALHV})/({VALV})^2", V_VALKV, 0),
    ENDIF,
    CALL(S_OBS), STOP
};

/* ---- F ---- */
static const mstep sF[] = {
    LN("RESULTADO  Valvula de control", C_TITLE), SEP,
    CALL(S_STATE), DAT("hv", V_HV, "m"), DAT("Kv", V_KV, 0),
    SEP, WARNS, STOP
};
static const mstep mF[] = {
    LN("MEMORIA  Valvula de control (F)", C_TITLE), SEP,
    CALL(S_DATA), DAT("H disponible", V_H, "m"),
    SEC("CALCULOS"), CALL(S_CALC),
    EQ("hv", "H - hT", "{H} - {HT}", V_HV, "m"),
    EQ("Kv", "2g hv/v^2", "2({G})({HV})/({V})^2", V_KV, 0),
    SEC("RESULTADOS"), RES("hv", V_HV, "m"), RES("Kv", V_KV, 0),
    CALL(S_OBS), STOP
};

/* ---- E ---- */
static const mstep sE[] = {
    LN("RESULTADO  Calibracion", C_TITLE), SEP,
    DAT("v", V_V, "m/s"), DAT("Re", V_RE, 0), DAT("hf + hm", V_HTOT, "m"),
    DAT("hm", V_HM, "m"), DAT("hf", V_HF, "m"), DAT("f", V_F, 0),
    DAT("ks", V_KSMM, "mm"), DAT("ks/D", V_KSD, 0),
    SEP, WARNS, STOP
};
static const mstep mE[] = {
    LN("MEMORIA  Calibracion (E)", C_TITLE), SEP,
    SEC("DATOS"),
    DAT("z1", V_Z1, "m"), DAT("z2", V_Z2, "m"),
    DAT("p1/gamma", V_P1, "m"), DAT("p2/gamma", V_P2, "m"),
    DAT("L", V_L, "m"), DAT("D", V_D, "m"), DAT("Q", V_Q, "m3/s"),
    DAT("Suma K", V_K, 0), DAT("nu", V_NU, "m2/s"),
    SEC("CALCULOS"),
    EQ("A", "pi D^2/4", "pi({D})^2/4", V_A, "m2"),
    EQ("v", "Q/A", "{Q}/{A}", V_V, "m/s"),
    EQ("hf+hm", "(z1 - z2) + (p1 - p2)/gamma", "({Z1} - {Z2}) + ({P1} - {P2})", V_HTOT, "m"),
    EQ("hm", "SumK v^2/2g", "{K}({V})^2/(2({G}))", V_HM, "m"),
    EQ("hf", "(hf + hm) - hm", "{HTOT} - {HM}", V_HF, "m"),
    EQ("f", "2g D hf/(L v^2)", "2({G})({D})({HF})/({L}({V})^2)", V_F, 0),
    EQ("Re", "v D/nu", "{V}({D})/{NU}", V_RE, 0),
    EQ("ks", "3.7D(10^(-1/(2 sqrt f)) - 2.51/(Re sqrt f))",
       "3.7({D})(10^(-1/(2({SF}))) - 2.51/({RE}({SF})))", V_KS, "m"),
    SEC("RESULTADOS"), RES("f", V_F, 0), RES("ks", V_KSMM, "mm"),
    SEC("OBSERVACIONES"), WARNS, STOP
};

/* ---- I ---- */
static const mstep sI[] = {
    LN("RESULTADO  Darcy-W. vs Hazen-W.", C_TITLE), SEP,
    IFN(G_MODEQ),
      CALL(S_STATE),
      DAT("hf Hazen-W.", V_HW, "m"), DAT("Diferencia", V_ERR, "%"),
      LN("   (HW - DW)/DW, solo friccion", C_GRAY),
    ENDIF,
    IF(G_MODEQ),
      DAT("Q Darcy-W.", V_QLS, "l/s"), DAT("Q Hazen-W.", V_QHWLS, "l/s"),
      DAT("Diferencia", V_ERR, "%"),
      LN("   (HW - DW)/DW; HW sin locales", C_GRAY),
    ENDIF,
    SEP, WARNS, STOP
};
static const mstep mI[] = {
    LN("MEMORIA  Darcy-W. vs Hazen-W. (I)", C_TITLE), SEP,
    CALL(S_DATA), DAT("C_H", V_CH, 0),
    IFN(G_MODEQ),
      SEC("DARCY-WEISBACH"), CALL(S_CALC),
      SEC("HAZEN-WILLIAMS (sin locales)"),
      EQ("hf", "10.675 L Q^1.852/(C^1.852 D^4.87)",
         "10.675({L})({Q})^1.852/(({CH})^1.852({D})^4.87)", V_HW, "m"),
      SEC("COMPARACION"),
      EQ("e", "(hf HW - hf DW)/hf DW", "({HW} - {HF})/{HF}", V_ERR, "%"),
      LN(" Hazen-W. suele sobreestimar las perdidas", C_GRAY),
    ENDIF,
    IF(G_MODEQ),
      DAT("H", V_H, "m"),
      SEC("DARCY-WEISBACH (tipo B)"),
      IF(G_COURSE), LN(" Iteracion del curso", C_GRAY), ENDIF,
      IFN(G_COURSE), LN(" Biseccion sobre v", C_GRAY), ENDIF,
      CALL(S_CALC),
      RES("Q DW", V_QLS, "l/s"),
      SEC("HAZEN-WILLIAMS (sin locales)"),
      EQ("Q", "(H C^1.852 D^4.87/(10.675 L))^(1/1.852)",
         "({H}({CH})^1.852({D})^4.87/(10.675({L})))^(1/1.852)", V_QHW, "m3/s"),
      SEC("COMPARACION"),
      EQ("e", "(Q HW - Q DW)/Q DW", "({QHW} - {Q})/{Q}", V_ERR, "%"),
    ENDIF,
    CALL(S_OBS), STOP
};

static const mstep *const sum_p[PT_COUNT] = { sA, sB, sD, sC, sF, sE, sI };
static const mstep *const memo_p[PT_COUNT] = { mA, mB, mD, mC, mF, mE, mI };

/* ---- interprete ---- */
static char tb[200], tb2[200];

/* Expande {NOMBRE} y {NOMBRE!} */
static const char *tpl(const char *t, char *out, size_t n)
{
    size_t k = 0, j;
    char name[12], num[NUMFMT_LEN];
    const char *s;
    bool shortf;
    uint8_t i;
    if (!t)
        return 0;
    while (*t && k + 1 < n) {
        if (*t != '{') {
            out[k++] = *t++;
            continue;
        }
        t++;
        j = 0;
        while (*t && *t != '}' && *t != '!' && j < sizeof name - 1)
            name[j++] = *t++;
        name[j] = 0;
        shortf = (*t == '!');
        while (*t && *t != '}')
            t++;
        if (*t)
            t++;
        s = "?";
        if (!strcmp(name, "METHOD")) {
            s = method_names[C.method];
        } else if (!strcmp(name, "LISTNAME")) {
            s = diam_set_names[in.dset];
        } else {
            for (i = 0; i < V_COUNT; i++)
                if (!strcmp(name, vname[i])) {
                    s = shortf ? fmt_w(V[i], 7, num)
                               : fmt_real(V[i], g_set.dec, num);
                    break;
                }
        }
        while (*s && k + 1 < n)
            out[k++] = *s++;
    }
    out[k] = 0;
    return out;
}

static const char *const hB_course[5] = { "i", "hf", "v", "hm", "hf+1" };
static const char *const hB_bis[5] = { "i", "v min", "v max", "v", "hT-H" };
static const char *const hD[5] = { "i", "D min", "D max", "D mm", "hT-H" };
static const real m_one[5] = { 1, 1, 1, 1, 1 };
static const real m_D[5] = { 1, 1000, 1000, 1000, 1 };

static void run_prog(const mstep *p, uint8_t depth)
{
    uint8_t skip = 0, i;
    char num[NUMFMT_LEN];
    for (; p->op != M_END; p++) {
        if (skip) {                       /* dentro de un IF falso */
            if (p->op == M_IF || p->op == M_IFN)
                skip++;
            else if (p->op == M_ENDIF)
                skip--;
            continue;
        }
        switch (p->op) {
        case M_SEC: memo_sec(p->a); break;
        case M_SEP: view_add_sep(); break;
        case M_DATA: view_add_val(p->a, V[p->id], p->u); break;
        case M_RES: memo_res(p->a, V[p->id], p->u); break;
        case M_EQ:
            memo_eq(p->a, p->b, tpl(p->c, tb, sizeof tb), V[p->id], p->u);
            break;
        case M_LINE: memo_line(tpl(p->a, tb2, sizeof tb2), p->id); break;
        case M_IF:
            if (!(FL & ((uint32_t)1 << p->id)))
                skip = 1;
            break;
        case M_IFN:
            if (FL & ((uint32_t)1 << p->id))
                skip = 1;
            break;
        case M_CALL:
            if (depth < 3)
                run_prog(subs[p->id], depth + 1);
            break;
        case M_TABLE:
            if (p->id == 0)
                memo_table(hB_course, 5, &LG, m_one);
            else if (p->id == 1)
                memo_table(hB_bis, 5, &LG, m_one);
            else
                memo_table(hD, 5, &LG, m_D);
            break;
        case M_WARN: memo_warn(W, &C); break;
        case M_DLIST:
            tb2[0] = ' ';
            tb2[1] = 0;
            for (i = 0; i < dlist_n; i++) {
                if (strlen(tb2) > 30) {
                    memo_line(tb2, C_GRAY);
                    tb2[0] = ' ';
                    tb2[1] = 0;
                }
                strcat(tb2, fmt_w(dlist[i] * 1000, 7, num));
                strcat(tb2, " ");
            }
            memo_line(tb2, C_GRAY);
            break;
        default: break;
        }
    }
}

#define SETF(g, cond) do { if (cond) FL |= (uint32_t)1 << (g); } while (0)

/* Llena V[] y FL con el resultado del ultimo calculo */
static void fill_values(void)
{
    const hydro_state *s = 0;
    real D = P.D;
    memset(V, 0, sizeof V);
    FL = 0;
    switch (tipo) {
    case PT_A: case PT_F: s = &R.st; break;      /* v.st y st coinciden */
    case PT_C: s = &R.m.st; break;
    case PT_B: s = &R.q.st; break;
    case PT_D: s = &R.d.qmax.st; D = R.d.D_com; break;
    case PT_I: s = in.modeI ? &R.q.st : &R.st; break;
    default: break;
    }
    V[V_D] = D; V[V_L] = P.L; V[V_KS] = P.ks; V[V_K] = P.sumK;
    V[V_NU] = C.nu; V[V_G] = C.g; V[V_GAM] = C.gamma; V[V_TOL] = C.tol;
    V[V_H] = in.H; V[V_QD] = in.Q / 1000; V[V_KSMM] = P.ks * 1000;
    if (s) {
        V[V_Q] = s->Q; V[V_QLS] = s->Q * 1000; V[V_A] = s->A; V[V_V] = s->v;
        V[V_RE] = s->Re; V[V_KSD] = s->ksD; V[V_F] = s->f;
        V[V_INVSF] = 1 / R_SQRT(s->f); V[V_HV2G] = s->hv2g;
        V[V_HF] = s->hf; V[V_HM] = s->hm; V[V_HT] = s->hT; V[V_LD] = s->LD;
        V[V_HMHF] = s->hf > 0 ? 100 * s->hm / s->hf : 0;
        V[V_FIT] = s->f_iters;
        V[V_A37] = D > 0 ? P.ks / (3.7 * D) : 0;
        W = s->warn;
        SETF(G_LAM, s->regime == REG_LAMINAR);
        SETF(G_TRANS, s->regime == REG_TRANSITION);
    }
    SETF(G_FIX, P.f_fixed > 0);
    SETF(G_CW, C.method == FM_CW);
    SETF(G_SJ, C.method == FM_SJ);
    SETF(G_HA, C.method == FM_HAALAND);
    SETF(G_GO, C.method == FM_GOUDAR);
    SETF(G_KPOS, P.sumK > 0);
    SETF(G_WITHQ, tipo == PT_A || tipo == PT_C || tipo == PT_F ||
                  (tipo == PT_I && !in.modeI));
    SETF(G_HASD, tipo != PT_D);
    switch (tipo) {
    case PT_A:
        V[V_HP] = in.Hp; V[V_PH] = X.ph; V[V_PKPA] = X.ph * C.gamma / 1000;
        SETF(G_HP, in.sHp);
        break;
    case PT_B: case PT_I:
        V[V_ITER] = R.q.iters;
        SETF(G_COURSE, R.q.solver == SOLV_COURSE);
        SETF(G_BIS, R.q.solver == SOLV_BISECTION);
        SETF(G_DIRECT, R.q.solver == SOLV_DIRECT);
        SETF(G_FB, R.q.st.warn & W_FALLBACK);
        if (tipo == PT_I) {
            V[V_CH] = in.CH; V[V_HW] = X.hw; V[V_ERR] = X.err;
            V[V_QHW] = X.Qhw; V[V_QHWLS] = X.Qhw * 1000;
            SETF(G_MODEQ, in.modeI);
            if (!in.modeI)
                FL &= ~(((uint32_t)1 << G_COURSE) | ((uint32_t)1 << G_BIS));
        }
        break;
    case PT_C:
        V[V_HS] = in.Hs; V[V_ETA] = in.eta; V[V_HMACH] = R.m.Hm;
        V[V_PN] = R.m.Pn; V[V_PB] = R.m.Pb; V[V_PNKW] = R.m.Pn / 1000;
        V[V_PBKW] = R.m.Pb / 1000; V[V_PBHP] = R.m.Pb / 745.7;
        V[V_ZB] = in.zb;
        V[V_COTA] = in.zb + (in.mach == 0 ? R.m.Hm : -R.m.Hm);
        SETF(G_PUMP, in.mach == 0);
        SETF(G_ZB, in.szb);
        break;
    case PT_F:
        V[V_HV] = R.v.hv; V[V_KV] = R.v.Kv;
        break;
    case PT_D:
        V[V_ITER] = R.d.iters; V[V_DEX] = R.d.D_exact * 1000;
        V[V_DCOM] = R.d.D_com * 1000; V[V_VP] = R.d.vp;
        V[V_HFCQ] = R.d.st_com_qd.hf; V[V_VCQ] = R.d.st_com_qd.v;
        V[V_EXV] = R.d.st_exact.v; V[V_EXRE] = R.d.st_exact.Re;
        V[V_EXF] = R.d.st_exact.f; V[V_EXHF] = R.d.st_exact.hf;
        V[V_EXHM] = R.d.st_exact.hm; V[V_EXHT] = R.d.st_exact.hT;
        V[V_VALHT] = X.val.st.hT; V[V_VALHV] = X.val.hv;
        V[V_VALKV] = X.val.Kv; V[V_VALV] = X.val.st.v;
        W |= R.d.warn;
        SETF(G_COURSE, R.d.qmax.solver == SOLV_COURSE);
        SETF(G_VP, R.d.vp > 0);
        SETF(G_VAL, X.has_val);
        break;
    case PT_E:
        V[V_D] = in.D / 1000; V[V_Q] = in.Q / 1000;
        V[V_Z1] = in.z1; V[V_Z2] = in.z2; V[V_P1] = in.p1; V[V_P2] = in.p2;
        V[V_A] = R.k.A; V[V_V] = R.k.v; V[V_HTOT] = R.k.htot;
        V[V_HM] = R.k.hm; V[V_HF] = R.k.hf; V[V_F] = R.k.f; V[V_RE] = R.k.Re;
        V[V_SF] = R_SQRT(R.k.f); V[V_KS] = R.k.ks; V[V_KSMM] = R.k.ks * 1000;
        V[V_KSD] = R.k.ksD;
        W = R.k.warn;
        break;
    default:
        break;
    }
}

static void show(bool memo)
{
    fill_values();
    view_clear();
    run_prog(memo ? memo_p[tipo] : sum_p[tipo], 0);
}

/* ------------------------------------------------------------------ */
/* Calculo                                                             */
/* ------------------------------------------------------------------ */
static void make_pipe(void)
{
    C = g_set.h;
    C.nu = in.nu;
    P.D = in.D / 1000;
    P.L = in.L;
    P.ks = in.ks / 1000;
    P.sumK = in.sK ? in.K : 0;
    P.f_fixed = in.sf ? in.f : 0;
}

/* Devuelve 0 si todo bien, o un texto de error */
static const char *compute(void)
{
    int e = H_OK;
    uint8_t i;
    make_pipe();
    hydro_log_clear(&LG);
    memset(&X, 0, sizeof X);
    switch (tipo) {
    case PT_A:
        e = hydro_pipe_state(&P, in.Q / 1000, &C, &R.st);
        if (!e && in.sHp)
            X.ph = hydro_pressure_head(in.Hp, 0, R.st.v, R.st.hT, &C, &R.st.warn);
        break;
    case PT_B:
        e = hydro_qmax(&P, in.H, &C, &R.q, &LG);
        break;
    case PT_C:
        e = (in.mach == 0) ? hydro_pump(&P, in.Q / 1000, in.Hs, in.eta, &C, &R.m)
                           : hydro_turbine(&P, in.Q / 1000, in.Hs, in.eta, &C, &R.m);
        break;
    case PT_D:
        P.f_fixed = 0;
        dlist_n = diam_sets[in.dset].n;
        for (i = 0; i < dlist_n; i++)
            dlist[i] = diam_sets[in.dset].mm[i] / 1000;
        e = hydro_design(&P, in.Q / 1000, in.H, dlist, dlist_n, &C, &R.d, &LG);
        if (!e && in.valve) {
            P.D = R.d.D_com;
            X.has_val = 1;   /* si hv < 0 se muestra igual, con su aviso */
            hydro_valve(&P, in.Q / 1000, in.H, &C, &X.val);
        }
        break;
    case PT_F:
        e = hydro_valve(&P, in.Q / 1000, in.H, &C, &R.v);
        break;
    case PT_E:
        P.f_fixed = 0;
        e = hydro_calibrate(in.D / 1000, in.L, in.Q / 1000, P.sumK,
                            in.z1 - in.z2, in.p1 - in.p2, &C, &R.k);
        if (e == H_ERR_KS_NEG)
            e = H_OK;    /* se muestra con su advertencia */
        break;
    case PT_I:
        P.f_fixed = 0;
        if (in.modeI == 0) {
            if (!in.sQ)
                return "Falta Q (modo hf)";
            e = hydro_pipe_state(&P, in.Q / 1000, &C, &R.st);
            X.hw = hydro_hw_hf(in.Q / 1000, P.D, P.L, in.CH);
            X.err = 100 * (X.hw - R.st.hf) / R.st.hf;
        } else {
            if (!in.sH)
                return "Falta H (modo Q)";
            e = hydro_qmax(&P, in.H, &C, &R.q, &LG);
            X.Qhw = hydro_hw_q(in.H, P.D, P.L, in.CH);
            X.err = 100 * (X.Qhw - R.q.st.Q) / R.q.st.Q;
        }
        break;
    default:
        break;
    }
    if (e == H_ERR_HV_NEG || e == H_ERR_HT_NEG)
        return hydro_err_text(e);
    return e ? hydro_err_text(e) : 0;
}

/* ------------------------------------------------------------------ */
/* Bucle de resultado: resumen <-> memoria                             */
/* ------------------------------------------------------------------ */
static void result_loop(void)
{
    static const char *const fk_sum[5] = { "MEMORIA", "", "", "", "VOLVER" };
    static const char *const fk_memo[5] = { "RESUMEN", "", "", "", "VOLVER" };
    bool memo = false;
    uint8_t k;
    for (;;) {
        show(memo);
        k = view_run(titles[tipo], memo ? fk_memo : fk_sum);
        if (k == K_F1) {
            memo = !memo;
        } else if (k == K_MODE) {
            scr_settings();
        } else {
            return;
        }
    }
}

void scr_pipe(uint8_t t)
{
    static uint8_t cur[PT_COUNT];
    form_t fm;
    uint8_t k, m0;
    const char *err;

    if (t >= PT_COUNT)
        return;
    tipo = t;
    if (!in.snu) {
        in.nu = g_set.h.nu;
        in.snu = 1;
    }
    if (!in.sK) {
        in.K = 0;
        in.sK = 1;
    }
    memset(&fm, 0, sizeof fm);
    fm.title = titles[t];
    fm.f = forms[t];
    fm.n = nforms[t];
    fm.cur = cur[t];
    fm.fk[0] = "MAT";
    fm.fk[1] = "SUMA K";
    fm.fk[2] = "FLUIDO";
    fm.fk[3] = "AJUSTES";
    fm.fk[4] = "CALC";
    if (t == PT_C)
        fm.hint = "Hs = z2-z1 (bomba); Ha = z1-z2 (turb.)";
    m0 = g_set.h.method;
    for (;;) {
        k = form_run(&fm);
        if (k == K_QUIT || k == K_CLEAR)
            break;
        if (k == K_F1) { todo_alert("Biblioteca de materiales", 4); continue; }
        if (k == K_F2) { todo_alert("Sumador de accesorios", 4); continue; }
        if (k == K_F3) { todo_alert("Selector de fluido", 4); continue; }
        if (k == K_F4 || k == K_MODE) { scr_settings(); continue; }
        if (k == K_F5 || k == K_ENTER) {
            if (!form_check(&fm))
                continue;
            err = compute();
            if (err) {
                fm.msg = err;
                fm.msg_color = C_ERR;
                continue;
            }
            result_loop();
            if (ui_quit)
                break;
        }
    }
    cur[t] = fm.cur;
    if (g_set.h.method != m0)
        g_set_dirty = true;
}
