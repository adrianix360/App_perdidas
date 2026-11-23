/*
 * memo_drag.c - Memorias de calculo de arrastre y sustentacion (v2.0).
 * Lo incluye tools/memo_tables.c (no se compila para la calculadora).
 */

/* datos del fluido y de la velocidad */
#define DFL \
    DAT("rho", V_RHO, "kg/m3"), DAT("nu", V_NU, "m2/s"), \
    IF(G_DVCONV), LN(" V dada = {VIN} (km/h o nudos)", C_GRAY), ENDIF, \
    DAT("V", V_VEL, "m/s")

/* coeficiente y area de referencia */
#define DSHP \
    IF(G_DFIG), LN(" Figura del catalogo de CD", C_GRAY), ENDIF, \
    DAT("CD", V_CDV, 0), \
    IF(G_DACALC), LN(" A = {TXT}  (D = {DIM1!}, L/b = {DIM2!})", C_FG), ENDIF, \
    DAT("A", V_AREF, "m2"), \
    DAT("L para Re", V_LREF, "m")

#define DWARN \
    IF(G_DSTK), LN("! Re < 1: se uso Stokes (CD = k/Re)", C_WARN), ENDIF, \
    IF(G_DRE1), IFN(G_DSTK), LN("! Re < 1: flujo lento (Stokes)", C_WARN), ENDIF, ENDIF, \
    IF(G_DRELOW), IFN(G_DRE1), LN("! Re < 1E4: fuera del rango de la tabla", C_WARN), ENDIF, ENDIF, \
    IF(G_DCRIS), LN("! Posible crisis de arrastre: el CD", C_WARN), \
                 LN("  puede ser mucho menor; revise", C_WARN), ENDIF, \
    IFN(G_DRELOW), IFN(G_DCRIS), LN(" Re > 1E4: CD de la tabla valido", C_OK), ENDIF, ENDIF

/* ---- AR-1 ---- */
static const mstep x_ar1_sum[] = {
    DAT("q = 0.5 rho V^2", V_QDYN, "Pa"),
    DAT("Re", V_RE, 0),
    IFN(G_DLIFT), RES("FD", V_FD, "N"), ENDIF,
    IF(G_DLIFT), RES("FL", V_FD, "N"), ENDIF,
    SEP, DWARN,
    STOP
};
static const mstep x_ar1_memo[] = {
    SEC("DATOS"), DFL, DSHP,
    IF(G_DLIFT), LN(" (CL en lugar de CD; A = area en planta)", C_GRAY), ENDIF,
    SEC("CALCULOS"),
    EQ("q", "0.5 rho V^2", "0.5({RHO})({VEL})^2", V_QDYN, "Pa"),
    EQ("Re", "V L/nu", "{VEL}({LREF})/{NU}", V_RE, 0),
    IF(G_DSTK), EQ("CD", "k/Re (Stokes)", "{KST}/{RE}", V_CDV, 0), ENDIF,
    IFN(G_DLIFT), EQ("FD", "CD q A", "{CDV}({QDYN})({AREF})", V_FD, "N"), ENDIF,
    IF(G_DLIFT), EQ("FL", "CL q A", "{CDV}({QDYN})({AREF})", V_FD, "N"), ENDIF,
    SEC("RESULTADO"),
    IFN(G_DLIFT), RES("FD", V_FD, "N"), ENDIF,
    IF(G_DLIFT), RES("FL", V_FD, "N"), ENDIF,
    SEC("OBSERVACIONES"), DWARN,
    STOP
};

/* ---- AR-2 ---- */
static const mstep x_ar2_sum[] = {
    DAT("W", V_W, "N"),
    IF(G_DBUOY), DAT("B", V_BUOY, "N"), DAT("W - B", V_NET, "N"), ENDIF,
    RES("v terminal", V_VT, "m/s"),
    RES("v terminal", V_VTKMH, "km/h"),
    DAT("Re", V_RE, 0),
    SEP, DWARN,
    STOP
};
static const mstep x_ar2_memo[] = {
    SEC("DATOS"),
    DAT("rho", V_RHO, "kg/m3"), DAT("nu", V_NU, "m2/s"),
    DAT("W", V_W, "N"),
    IF(G_DBUOY), DAT("Volumen", V_VOL, "m3"), ENDIF,
    DSHP,
    SEC("CALCULOS"),
    IF(G_DBUOY),
      EQ("B", "rho g Vol", "{RHO}({G})({VOL})", V_BUOY, "N"),
      EQ("W - B", 0, "{W} - {BUOY}", V_NET, "N"),
    ENDIF,
    IFN(G_DBUOY), LN(" Empuje despreciable (aire): W - B = W", C_GRAY), ENDIF,
    LN(" Equilibrio: W - B = FD = 0.5 rho CD A v^2", C_FG),
    IFN(G_DSTK),
      EQ("v", "sqrt[2(W-B)/(rho CD A)]",
         "sqrt[2({NET})/({RHO}({CDV})({AREF}))]", V_VT, "m/s"),
    ENDIF,
    IF(G_DSTK),
      LN(" Re < 1: FD = 0.5 rho (k nu/(v L)) A v^2", C_FG),
      EQ("v", "2(W-B) L/(rho k nu A)",
         "2({NET})({LREF})/({RHO}({KST})({NU})({AREF}))", V_VT, "m/s"),
    ENDIF,
    EQ("Re", "v L/nu", "{VT}({LREF})/{NU}", V_RE, 0),
    SEC("RESULTADO"),
    RES("v terminal", V_VT, "m/s"),
    RES("v terminal", V_VTKMH, "km/h"),
    SEC("OBSERVACIONES"), DWARN,
    STOP
};

/* ---- AR-3 ---- */
static const mstep x_ar3_sum[] = {
    DAT("q = 0.5 rho V^2", V_QDYN, "Pa"),
    RES("F total", V_FTOT, "kN"),
    RES("M en la base", V_MOM, "kN m"),
    RES("ycp = M/F", V_YCP, "m"),
    SEP, DWARN,
    STOP
};
static const mstep x_ar3_memo[] = {
    SEC("DATOS"), DFL,
    SEC("CALCULOS"),
    EQ("q", "0.5 rho V^2", "0.5({RHO})({VEL})^2", V_QDYN, "Pa"),
    LN("Cuerpos: Fi = CDi q Ai (Vi propia si se dio)", C_FG),
    TAB(TB_HOOK),
    EQ("F", "suma Fi", 0, V_FTOT, "kN"),
    EQ("M", "suma Fi yi", 0, V_MOM, "kN m"),
    EQ("ycp", "M/F", "{MOM}/{FTOT}", V_YCP, "m"),
    SEC("RESULTADO"),
    RES("F total", V_FTOT, "kN"),
    RES("M en la base", V_MOM, "kN m"),
    RES("ycp", V_YCP, "m"),
    SEC("OBSERVACIONES"), DWARN,
    STOP
};

/* ---- AR-4 ---- */
static const mstep x_ar4_sum[] = {
    DAT("rho", V_RHO, "kg/m3"),
    DAT("q", V_QDYN, "Pa"),
    RES("CL necesario", V_CL, 0),
    IFN(G_DSTEP2),
      LN("> Lea alfa y CD en la grafica con", C_WARN),
      LN("  CL = {CL!}; escribalos y CALC", C_WARN),
    ENDIF,
    IF(G_DSTEP2),
      DAT("D alas", V_DWING, "kN"),
      DAT("D fuselaje", V_DFUS, "kN"),
      RES("Empuje T", V_THR, "kN"),
      RES("Potencia P", V_PWR, "MW"),
      IF(G_DVST), RES("V perdida", V_VST, "m/s"), ENDIF,
    ENDIF,
    STOP
};
static const mstep x_ar4_memo[] = {
    SEC("DATOS"),
    DAT("W", V_W, "N"),
    IF(G_DVCONV), LN(" V dada = {VIN} (km/h o nudos)", C_GRAY), ENDIF,
    DAT("V", V_VEL, "m/s"),
    IF(G_DALT), DAT("h", V_ALT, "m"), ENDIF,
    IFN(G_DALT), DAT("rho", V_RHO, "kg/m3"), ENDIF,
    DAT("n alas", V_NW, 0),
    DAT("A de un ala", V_AW, "m2"),
    DAT("CD fuselaje", V_CDF, 0),
    DAT("D fuselaje", V_DF, "m"),
    SEC("CALCULOS"),
    IF(G_DALT),
      EQ("rho", "1.3(1 - 2.26E-5 h)^4.256",
         "1.3(1 - 2.26E-5({ALT}))^4.256", V_RHO, "kg/m3"),
    ENDIF,
    EQ("q", "0.5 rho V^2", "0.5({RHO})({VEL})^2", V_QDYN, "Pa"),
    EQ("A", "n A ala", "{NW}({AW})", V_ATOT, "m2"),
    LN(" Vuelo nivelado: L = W", C_FG),
    EQ("CL", "W/(q A)", "{W}/({QDYN}({ATOT}))", V_CL, 0),
    IFN(G_DSTEP2),
      LN("> Lea alfa y CD en la grafica con", C_WARN),
      LN("  CL = {CL!}; escribalos y CALC", C_WARN),
    ENDIF,
    IF(G_DSTEP2),
      LN(" Grafica: alfa = {ALPHA!} grad, CD = {CDW!}", C_GRAY),
      EQ("D alas", "CD q A", "{CDW}({QDYN})({ATOT})/1000", V_DWING, "kN"),
      EQ("Af", "pi D^2/4", "pi({DF})^2/4", V_AFUS, "m2"),
      EQ("D fus", "CDf q Af", "{CDF}({QDYN})({AFUS})/1000", V_DFUS, "kN"),
      EQ("T", "D alas + D fus", "{DWING} + {DFUS}", V_THR, "kN"),
      EQ("P", "T V", "{THR}({VEL})/1000", V_PWR, "MW"),
      IF(G_DVST),
        EQ("V perd", "sqrt[2W/(rho CLmax A)]",
           "sqrt[2({W})/({RHO}({CLMAX})({ATOT}))]", V_VST, "m/s"),
      ENDIF,
    ENDIF,
    SEC("RESULTADO"),
    RES("CL necesario", V_CL, 0),
    IF(G_DSTEP2),
      RES("Empuje T", V_THR, "kN"),
      RES("Potencia P", V_PWR, "MW"),
      IF(G_DVST), RES("V perdida", V_VST, "m/s"), RES("V perdida", V_VTKMH, "km/h"), ENDIF,
    ENDIF,
    SEC("OBSERVACIONES"),
    LN(" alfa y CD se leen en la grafica del", C_GRAY),
    LN(" perfil (entrada manual)", C_GRAY),
    STOP
};

/* ---- Placa plana y Stokes ---- */
#define PWARN \
    IF(G_PSTK), IF(G_DRE1), LN("! Re >= 1: Stokes no aplica", C_WARN), ENDIF, \
                IFN(G_DRE1), LN(" Re < 1: Stokes valido", C_OK), ENDIF, ENDIF, \
    IFN(G_PSTK), \
      IF(G_PLAMNA), LN("! Re > 5E5: Cf laminar no aplica", C_WARN), ENDIF, \
      IF(G_PTURBNA), LN("! Re > 1E7: fuera de 0.074/Re^0.2", C_WARN), ENDIF, \
      IF(G_PLAM), IFN(G_PLAMNA), LN(" Laminar: Re < 5E5", C_OK), ENDIF, ENDIF, \
    ENDIF

static const mstep x_pl_sum[] = {
    DAT("Re", V_RE, 0),
    IF(G_PSTK), DAT("CD = 24/Re", V_CDV, 0), ENDIF,
    IFN(G_PSTK),
      DAT("Cf laminar", V_CFL, 0), DAT("Cf turbulento", V_CFT, 0),
      DAT("Cf mixto", V_CFM, 0),
      IF(G_PLAM), LN(" Se usa: laminar", C_GRAY), ENDIF,
      IF(G_PTURB), LN(" Se usa: turbulento", C_GRAY), ENDIF,
      IF(G_PMIX), LN(" Se usa: mixto", C_GRAY), ENDIF,
    ENDIF,
    RES("FD", V_FD, "N"),
    SEP, PWARN,
    STOP
};
static const mstep x_pl_memo[] = {
    SEC("DATOS"), DFL,
    IF(G_PSTK), DAT("D esfera", V_DIM1, "m"), ENDIF,
    IFN(G_PSTK), DAT("L placa", V_DIM1, "m"), DAT("w", V_DIM2, "m"),
                 DAT("Caras", V_FACES, 0), ENDIF,
    SEC("CALCULOS"),
    EQ("Re", "V L/nu", "{VEL}({DIM1})/{NU}", V_RE, 0),
    IF(G_PSTK),
      EQ("mu", "rho nu", "{RHO}({NU})", V_MU, "Pa s"),
      EQ("FD", "3 pi mu V D", "3 pi({MU})({VEL})({DIM1})", V_FD, "N"),
      EQ("CD", "24/Re", "24/{RE}", V_CDV, 0),
    ENDIF,
    IFN(G_PSTK),
      EQ("Cf lam", "1.328/sqrt(ReL)", "1.328/sqrt({RE})", V_CFL, 0),
      EQ("Cf turb", "0.074/ReL^0.2", "0.074/{RE}^0.2", V_CFT, 0),
      EQ("Cf mixto", "0.074/ReL^0.2 - 1742/ReL", "{CFT} - 1742/{RE}", V_CFM, 0),
      IF(G_PLAM), LN(" Se usa Cf laminar", C_GRAY), ENDIF,
      IF(G_PTURB), LN(" Se usa Cf turbulento", C_GRAY), ENDIF,
      IF(G_PMIX), LN(" Se usa Cf mixto", C_GRAY), ENDIF,
      EQ("q", "0.5 rho V^2", "0.5({RHO})({VEL})^2", V_QDYN, "Pa"),
      EQ("A", "L w", "{DIM1}({DIM2})", V_APL, "m2"),
      EQ("FD", "Cf q A (caras)", "{CF}({QDYN})({APL})({FACES})", V_FD, "N"),
    ENDIF,
    SEC("RESULTADO"),
    RES("FD", V_FD, "N"),
    SEC("OBSERVACIONES"), PWARN,
    STOP
};
