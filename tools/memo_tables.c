/*
 * memo_tables.c - Fuente de la memoria de calculo y de los resumenes de
 * tuberia simple, como programas de datos. NO se compila para la
 * calculadora: tools/gen_txt.c lo incluye y genera el AppVar PERDTXT.
 * Plantillas: {NOMBRE} = valor con los decimales de Ajustes, {NOMBRE!} =
 * valor corto. Los nombres validos estan en vname[].
 */
#include <stdint.h>
#include <stddef.h>
#include "../src/app.h"
#include "../src/ui/ui.h"
#include "../src/memo_defs.h"

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
    "FCW", "FSJ", "FHA", "FGO", "DSJ", "DHA", "DGO", "FSEL", "KPLUS",
    "DMM",
    "RHO", "VIN", "VEL", "QDYN", "CDV", "AREF", "DIM1", "DIM2", "LREF",
    "FD", "W", "BUOY", "NET", "VOL", "VT", "VTKMH", "MU", "KST",
    "FTOT", "MOM", "YCP",
    "ALT", "CL", "ATOT", "AW", "NW", "CDW", "CDF", "DF", "AFUS", "DWING",
    "DFUS", "THR", "PWR", "ALPHA", "CLMAX", "VST",
    "CFL", "CFT", "CFM", "CF", "APL", "FACES",
    "WCD", "WD1", "WD2", "WH", "WQ", "WQLS", "WK", "WLEV", "WH0", "WAREA",
    "WBE", "WNC", "WIT", "WT2", "WG2",
    "PRK", "PRN", "PRB", "PRH", "PRQ", "PRVM", "PRNP",
    "SQ", "SB", "SH1", "SV1", "SE1", "SQQ", "SFR1", "SDZ", "SE2", "SHS",
    "SHP", "SHC", "SVS", "SVP",
    "VD1", "VD2", "VBETA", "VA1", "VA2", "VV1", "VV2", "VDP", "VH", "VS",
    "VCV", "VQ", "VQLS", "VDPK", "VSF", "VB4",
    "JQ", "JB", "JQQ", "JY1", "JY2", "JV1", "JV2", "JFR1", "JFR2", "JE1",
    "JE2", "JDE", "JP", "JEFF",
    "EH", "EL", "ED", "EKS", "EK", "EQ", "EQLS", "EV", "ERE", "EF", "ETH",
    "EVX", "EVY", "EHM", "ER", "ET", "EIT", "ELD",
    "CH0", "D0", "HF1", "Q0LS",
};

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
    IF(G_PSEC), LN(" Metodo: secante (formula del curso)", C_GRAY), ENDIF,
    IF(G_PHW), LN(" Arranque: Hazen-Williams, C_H = {CH0!}", C_GRAY), ENDIF,
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
      IF(G_PHW),
        LN("0 (Hazen-Williams): Q_HW tal que", C_FG),
        LN(" 10.675 L Q^1.852/(C_H^1.852 D^4.87) + SumK v^2/2g = H", C_FG),
        LN(" C_H = {CH0!}: Q_HW = {Q0LS!} l/s; hf1 = hf_HW = {HF1!} m", C_GRAY),
      ENDIF,
      IF(G_COURSE),
        LN("v = -sqrt(8gD hf/L) log(ks/3.7D + 2.51 nu sqrt(L)/sqrt(2gD^3 hf))", C_FG),
        LN("hm = SumK v^2/2g;  hf(i+1) = H - hm", C_FG),
        IFN(G_PHW), LN(" hf1 = H; parar si |dhf| <= {TOL!} m", C_GRAY), ENDIF,
        IF(G_PHW), LN(" Fila 0 = Hazen-Williams; parar si |dhf| <= {TOL!} m", C_GRAY), ENDIF,
        TAB(0),
      ENDIF,
      IF(G_PSEC),
        LN("v = -sqrt(8gD hf/L) log(ks/3.7D + 2.51 nu sqrt(L)/sqrt(2gD^3 hf))", C_FG),
        LN("Secante sobre G(hf) = hf + SumK v^2/2g - H", C_FG),
        LN(" hf(1) = H - hm(0) (un paso del curso);", C_GRAY),
        LN(" luego hf+ = hf - G (hf - hf_ant)/(G - G_ant)", C_GRAY),
        IFN(G_PHW), LN(" Fila 0: hf = H. Parar si |dhf| <= 1E-5 hf", C_GRAY), ENDIF,
        IF(G_PHW), LN(" Fila 0 = Hazen-Williams. Parar si |dhf| <= 1E-5 hf", C_GRAY), ENDIF,
        TAB(TB_B_SEC),
      ENDIF,
      IF(G_BIS),
        IF(G_FB),
          IF(G_PREQ), LN(" La secante no convergio (o Re < 2000).", C_WARN), ENDIF,
          IFN(G_PREQ), LN(" La iteracion del curso no convergio.", C_WARN), ENDIF,
        ENDIF,
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
    IF(G_PSEC),
      IF(G_PHW),
        LN("0 (Hazen-Williams): D0 tal que", C_FG),
        LN(" 10.675 L Qd^1.852/(C_H^1.852 D^4.87) + SumK v^2/2g = H", C_FG),
        LN(" C_H = {CH0!}: D0 = {D0!} mm", C_GRAY),
      ENDIF,
      IFN(G_PHW),
        LN("0: D0 con f = 0.02: (0.02 L/D + SumK) v^2/2g = H", C_FG),
        LN(" D0 = {D0!} mm", C_GRAY),
      ENDIF,
      LN("Secante con F = hT - H desde D0 y 1.02 D0:", C_FG),
      LN(" D+ = D - F (D - D_ant)/(F - F_ant)", C_GRAY),
      LN(" parar si |dD| <= 1E-5 D", C_GRAY),
      TAB(TB_D_SEC),
    ENDIF,
    IFN(G_PSEC),
      IF(G_PDFB), LN(" La secante no convergio: biseccion", C_WARN), ENDIF,
      LN("(hT baja al crecer D: biseccion geometrica)", C_GRAY),
      TAB(2),
    ENDIF,
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
    IF(G_QSEC), LN(" Secante (formula del curso)", C_GRAY), ENDIF,
    IFN(G_COURSE), IFN(G_QSEC), LN(" Biseccion sobre v", C_GRAY), ENDIF, ENDIF,
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

/* ================================================================== */
/* AYUDA: un programa de lineas por tema (sec. 7.9 de la memoria)      */
/* ================================================================== */
#define TX(t) LN(t, C_FG)
#define TG(t) LN(t, C_GRAY)

static const mstep h_keys[] = {
    LN("USO Y TECLAS", C_TITLE), SEP,
    TX(" ENTER   acepta y pasa al siguiente"),
    TX(" CLEAR   borra lo escrito / vuelve"),
    TX(" DEL     borra un caracter; vacia un"),
    TX("         campo opcional"),
    TX(" Flechas mueven; derecha edita el valor"),
    TX("         actual; izq./der. cambian las"),
    TX("         opciones < >"),
    TX(" 2nd + flechas: primer / ultimo campo"),
    TX(" (-)     signo;  2nd ,  = E (x10^)"),
    TX(" Y= ventana zoom trace graph = F1..F5"),
    TX(" MODE    Ajustes desde cualquier lado"),
    TX(" 2nd MODE (QUIT)  salir de la app"),
    SEC("CAMPOS"),
    TX(" Aceptan cuentas: 0.5+4*1.1+3*0.3"),
    TX(" y potencias: 1.5*10^-6 o 1.5E-6"),
    TX(" Unidades: Q l/s, D mm, ks mm, L m,"),
    TX(" H y cotas m, presiones en m.c.a."),
    TX(" Los datos se conservan entre tipos."),
    SEC("RESULTADOS"),
    TX(" F1 MEMORIA: calculo paso a paso"),
    TX(" F2 GRAFICO: lineas de energia (LE) y"),
    TX("    piezometrica (LP)"),
    TX(" F3 GUARDAR: guarda el caso (8 letras)"),
    STOP
};

static const mstep h_types[] = {
    LN("TIPOS DE PROBLEMA", C_TITLE), SEP,
    TX("A Perdidas dado Q: v, Re, f, hf, hm."),
    TG("  Opcional: p/gamma en el punto final."),
    TX("B Caudal maximo dada la carga H."),
    TG("  Iteracion del curso; si no converge,"),
    TG("  biseccion sobre v (la memoria avisa)."),
    TG("  Opcional: secante y arranque desde"),
    TG("  Hazen-Williams (campo C_H arranque)."),
    TX("C Bomba o turbina: HB o HT y potencias"),
    TG("  Hs = z2 - z1 (bomba); Ha = z1 - z2"),
    TG("  (turbina); suma p/gamma si hay tanques"),
    TG("  presurizados."),
    TX("D Diametro exacto (biseccion o secante)"),
    TG("  y comercial (menor >= exacto); Qmax"),
    TG("  con el comercial; valvula opcional."),
    TG("  C_H arranque: secante desde Hazen-W."),
    TX("F Valvula: hv = H - hT; Kv = 2g hv/v^2."),
    TX("E Calibrar: f y ks con la caida medida."),
    TX("I Darcy-W. contra Hazen-Williams."),
    TX("G Sistemas: tubos por tramos (mismo"),
    TG("  tramo = paralelo; tramos en serie)."),
    TG("  Adelante: dada H. Atras: dado Q en un"),
    TG("  tubo se obtiene H y la presion."),
    STOP
};

static const mstep h_form[] = {
    LN("FORMULAS", C_TITLE), SEP,
    TX("A = pi D^2/4;  v = Q/A;  Re = v D/nu"),
    TX("hf = f (L/D) v^2/2g  (Darcy-Weisbach)"),
    TX("hm = SumK v^2/2g;  hT = hf + hm"),
    SEC("FACTOR DE FRICCION"),
    TX("Re < 2000: f = 64/Re (laminar)"),
    TX("2000-4000: transicion (indicativo)"),
    TX("CW: 1/sqrt f = -2 log(ks/3.7D +"),
    TX("    2.51/(Re sqrt f))"),
    TX("SJ: f = 0.25/[log(ks/3.7D +"),
    TX("    5.74/Re^0.9)]^2"),
    TX("Haaland: 1/sqrt f = -1.8 log["),
    TX("    (ks/3.7D)^1.11 + 6.9/Re]"),
    SEC("HAZEN-WILLIAMS"),
    TX("hf = 10.675 L Q^1.852/(C^1.852 D^4.87)"),
    TG(" sin perdidas locales; agua fria"),
    SEC("MODULOS (sistemas)"),
    TX("M = 8/(pi^2 g)(f L/D^5 + SumK/D^4)"),
    TX("h = M Q^2; serie: M = suma de Mi"),
    TX("paralelo: M = (suma 1/sqrt Mi)^-2"),
    SEC("OTRAS"),
    TX("vp = sqrt(2g(H - hf)/SumK)"),
    TX("ks = 3.7D(10^(-1/(2 sqrt f)) -"),
    TX("     2.51/(Re sqrt f))"),
    TX("Expansion: K = (1 - A1/A2)^2 (con v1)"),
    STOP
};

static const mstep h_power[] = {
    LN("POTENCIA BRUTA Y NETA", C_TITLE), SEP,
    TX("La bruta es la mayor y la neta la"),
    TX("menor (convencion de los examenes):"),
    SEC("BOMBA"),
    TX(" Pn = gamma Q HB  (la recibe el agua)"),
    TX(" Pb = Pn/eta      (la consume)"),
    SEC("TURBINA"),
    TX(" Pb = gamma Q HT  (la entrega el agua)"),
    TX(" Pn = eta Pb      (la que se genera)"),
    SEP,
    TG(" 1 Hp = 745.7 W; gamma = 9810 N/m3"),
    TG(" por defecto (editable en Ajustes)."),
    STOP
};

static const mstep h_lib[] = {
    LN("SUMA K Y BIBLIOTECA", C_TITLE), SEP,
    TX("SumK suma los K de todos los"),
    TX("accesorios del tubo: cantidad x K."),
    TG("Se escribe a mano (acepta cuentas) o"),
    TG("con F2 SUMA K en el formulario."),
    TX("Notacion: hm = hL = hl; K = KL = km."),
    SEC("FUENTES DE LOS DATOS"),
    TX(" ks y C_H: tabla del curso"),
    TG("   (Perdidas-01.pdf, pags. 12 y 30)"),
    TX(" (C): Cengel; los K del curso pueden"),
    TX("   diferir del fabricante: editables"),
    TX(" Conjuntos de K: los ejercicios"),
    TG("   (PVC 200 mm, examenes 2017-2025)"),
    TX(" (std): agua a presion atmosferica,"),
    TG("   tabla estandar (no de los PDF)"),
    TX(" nu del curso: 1E-6, 1.007E-6,"),
    TX("   1.02E-6, 1.14E-6 y 1.17E-6"),
    STOP
};

static const mstep h_warn[] = {
    LN("ADVERTENCIAS", C_TITLE), SEP,
    TX("! Re < 2000: laminar, f = 64/Re"),
    TX("! Re en transicion: resultado indicativo"),
    TX("! ks/D > 0.05: fuera de Colebrook-White"),
    TX("! Fuera del rango de Swamee-Jain"),
    TX("! v > 5 o v < 0.3 m/s (editable)"),
    TG("   criterio general, no del curso"),
    TX("! hm > 30% hf: perdidas locales altas"),
    TG("   en el diseno se muestra vp"),
    TX("! L/D > 4000: locales despreciables"),
    TG("   igual se suman (ajuste del curso)"),
    TX("! Presion manometrica negativa"),
    TX("! p/gamma < -10.3 m: imposible"),
    TX("! Iteracion del curso no convergio:"),
    TX("   se resolvio por biseccion"),
    TX("! ks negativo: datos inconsistentes"),
    STOP
};

static const mstep h_err[] = {
    LN("ERRATAS DEL MATERIAL", C_TITLE), SEP,
    TX("Perdidas-01 p.34: usa D^4.87 aunque"),
    TX("  escribe 4.57 (19.32 m sale con 4.87)"),
    TX("PVC 200 mm: el enunciado dice 32 l/s;"),
    TX("  la solucion usa 72 l/s"),
    TX("Presentacion ej. 1: H = 43.5 m (hoja)"),
    TX("Presentacion ej. 2: ks = 2.0E-6 m"),
    TX("Presentacion ej. 4: L = 970 m (hoja) y"),
    TX("  gamma = 9801 (agua a 15 C)"),
    TX("2018 P1a: Q = 5.69 l/s, no 56.9;"),
    TX("  el manuscrito usa L = 2.06 m"),
    TX("2024 P3: QB = 23.53 l/s, no 20.53"),
    TX("2025 P1: con 285.75 mm, Q = 262.4"),
    TX("  l/s (la solucion uso 285.00 mm)"),
    TX("2024 y 2025: D exacto con Swamee-Jain"),
    TG("  (CW difiere 0.04 %: ver Ajustes)"),
    LN("v2.0 (flujos externos y medicion):", C_TITLE),
    TX("2017 P2: sin solucion; alfa y CD se"),
    TX("  leen de la grafica (entrada manual)"),
    TX("T4-2 P1: no da CD; paracaidas 1.3"),
    TG("  (copa hueca 1.42 en el catalogo)"),
    TX("T4-2 P4: Re sobre la crisis de"),
    TX("  arrastre; se usa la tabla Re > 1E4"),
    TX("T4-2 P5: cubo de arista, A = sqrt(2)D^2"),
    TG("  (las tablas usan D^2: 1.580 m/s)"),
    TX("T4-2 P2b: Q = 16 + 20 = 36 l/s y cresta"),
    TX("  a la H de la parte a; Cd 0.6"),
    TX("2025 P4c: la solucion uso Q de diseno"),
    TX("  (200 l/s) y dp = S gamma h"),
    TX("2025 chorro: Suma K = 0, sin energia"),
    TX("  de salida (con ella, 3.899 l/s)"),
    STOP
};

#include "memo_help2.c"

static const mstep *const help_p[HELP_COUNT] = {
    h_keys, h_types, h_form, h_power, h_lib, h_warn, h_err,
    h_fric, h_drag, h_weir, h_chan
};

/* ================================================================== */
/* v2.0: Calcular f                                                    */
/* ================================================================== */
#define FTAB \
    LN("Metodo           f          dif. CW", C_TITLE), \
    LN(" Colebrook-W.  {FCW}", C_FG), \
    IF(G_OCW), LN("   ! fuera de rango: ks/D > 0.05", C_WARN), ENDIF, \
    LN(" Swamee-Jain   {FSJ}  {DSJ!} %", C_FG), \
    IF(G_OSJ), LN("   ! fuera de rango (Re 4E3-1E8,", C_WARN), \
               LN("     ks/D 1E-6 a 1E-2)", C_WARN), ENDIF, \
    LN(" Haaland       {FHA}  {DHA!} %", C_FG), \
    IF(G_OHA), LN("   ! fuera de rango (Re 4E3-1E8)", C_WARN), ENDIF, \
    LN(" Goudar-Sonnad {FGO}  {DGO!} %", C_FG), \
    IF(G_OGO), LN("   ! fuera de rango (Re < 4000)", C_WARN), ENDIF

#define FREG \
    IF(G_LAM), LN(" Re < Re lam: laminar, f = 64/Re", C_WARN), ENDIF, \
    IF(G_TRANS), LN(" Re en transicion: f de CW indicativo", C_WARN), ENDIF, \
    IFN(G_LAM), IFN(G_TRANS), LN(" Re > Re turb: turbulento", C_GRAY), ENDIF, \
      LN(" k+ = (ks/D) Re sqrt(f/8) = {KPLUS!}", C_GRAY), \
      IF(G_ZSMOOTH), LN(" Zona: hidraulicamente lisa (k+ < 5)", C_GRAY), ENDIF, \
      IF(G_ZTRANS), LN(" Zona: transicion (5 <= k+ <= 70)", C_GRAY), ENDIF, \
      IF(G_ZROUGH), LN(" Zona: rugosa, f casi no depende de Re", C_GRAY), \
                    LN("   (k+ > 70)", C_GRAY), ENDIF, \
    ENDIF

static const mstep x_fric_sum[] = {
    IF(G_FMODE2), DAT("v", V_V, "m/s"), ENDIF,
    DAT("Re", V_RE, 0),
    DAT("ks/D", V_KSD, 0),
    FREG,
    SEP,
    LN("> f ({METHOD}) = {FSEL}", C_OK),
    DAT("1/sqrt(f)", V_INVSF, 0),
    IFN(G_LAM), SEP, FTAB, ENDIF,
    STOP
};

static const mstep x_fric_memo[] = {
    SEC("DATOS"),
    IF(G_FMODE2),
      IFN(G_FHASV), DAT("Q", V_Q, "m3/s"), ENDIF,
      IF(G_FHASV), DAT("v", V_V, "m/s"), ENDIF,
      DAT("D", V_D, "m"),
      DAT("ks", V_KS, "m"),
      DAT("nu", V_NU, "m2/s"),
    ENDIF,
    IFN(G_FMODE2),
      DAT("Re", V_RE, 0),
      IF(G_FKSDIN), DAT("ks", V_KSMM, "mm"), DAT("D", V_DMM, "mm"), ENDIF,
      IFN(G_FKSDIN), DAT("ks/D", V_KSD, 0), ENDIF,
    ENDIF,
    LN(" Metodo de f (Ajustes): {METHOD}", C_GRAY),
    SEC("CALCULOS"),
    IF(G_FMODE2),
      EQ("A", "pi D^2/4", "pi({D})^2/4", V_A, "m2"),
      IFN(G_FHASV), EQ("v", "Q/A", "{Q}/{A}", V_V, "m/s"), ENDIF,
      EQ("Re", "v D/nu", "{V}({D})/{NU}", V_RE, 0),
      EQ("ks/D", 0, "{KS}/{D}", V_KSD, 0),
    ENDIF,
    IFN(G_FMODE2), IF(G_FKSDIN),
      EQ("ks/D", 0, "{KSMM}/{DMM}", V_KSD, 0),
    ENDIF, ENDIF,
    FREG,
    IF(G_LAM), EQ("f", "64/Re", "64/{RE}", V_FSEL, "(laminar)"), ENDIF,
    IFN(G_LAM),
      EQ("ks/3.7D", 0, "{KSD}/3.7", V_A37, 0),
      IF(G_SJ),
        EQ("f", "0.25/[log(ks/3.7D + 5.74/Re^0.9)]^2",
           "0.25/[log({A37} + 5.74/{RE}^0.9)]^2", V_FSJ, "(Swamee-Jain)"),
      ENDIF,
      IF(G_HA),
        EQ("1/sqrt(f)", "-1.8 log[(ks/3.7D)^1.11 + 6.9/Re]",
           "-1.8 log[({A37})^1.11 + 6.9/{RE}]", V_INVSF, 0),
        RES("f (Haaland)", V_FHA, 0),
      ENDIF,
      IF(G_GO),
        LN("1/sqrt(f) = 0.8686 ln(0.4587 Re/(C-0.31)^(C/(C+1)))", C_FG),
        LN("C = 0.124 Re ks/D + ln(0.4587 Re)", C_FG),
        RES("f (Goudar-Sonnad)", V_FGO, 0),
      ENDIF,
      SEC("ITERACIONES (COLEBROOK-WHITE)"),
      LN("1/sqrt(f) = -2 log(ks/3.7D + 2.51/(Re sqrt(f)))", C_FG),
      LN("      = -2 log({A37} + 2.51/({RE} sqrt(f)))", C_GRAY),
      LN(" Sustitucion sucesiva desde f1 = 0.0001", C_GRAY),
      TAB(TB_CW),
      LN(" Converge en {FIT!} iteraciones", C_GRAY),
      LN(" (|cambio de 1/sqrt f| < 4E-7 relativo)", C_GRAY),
      RES("f (Colebrook-White)", V_FCW, 0),
    ENDIF,
    SEC("RESULTADO"),
    LN("> f ({METHOD}) = {FSEL}", C_OK),
    DAT("1/sqrt(f)", V_INVSF, 0),
    SEC("COMPARACION Y AVISOS"),
    IFN(G_LAM), FTAB, ENDIF,
    IF(G_LAM), LN(" Laminar: f no depende de ks/D", C_GRAY), ENDIF,
    IF(G_TRANS), LN("! Re en transicion: resultado indicativo", C_WARN), ENDIF,
    IF(G_OCW), LN("! ks/D > 0.05: fuera de Colebrook-White", C_WARN), ENDIF,
    STOP
};

#include "memo_drag.c"
#include "memo_weir.c"
#include "memo_chan.c"

static const mstep *const x_p[XP_COUNT] = { x_fric_sum, x_fric_memo,
    x_ar1_sum, x_ar1_memo, x_ar2_sum, x_ar2_memo, x_ar3_sum, x_ar3_memo,
    x_ar4_sum, x_ar4_memo, x_pl_sum, x_pl_memo,
    x_ve1_sum, x_ve1_memo, x_ve4_sum, x_ve4_memo, x_ve6_sum, x_ve6_memo,
    x_ve7_sum, x_ve7_memo, x_ex1_sum, x_ex1_memo, x_ex2_sum, x_ex2_memo,
    x_ex3_sum, x_ex3_memo };
