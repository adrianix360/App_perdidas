/*
 * memo_weir.c - Memorias de calculo de vertedores y orificios (v2.0).
 * Lo incluye tools/memo_tables.c (no se compila para la calculadora).
 */

#define WWARN \
    IF(G_WPART), LN("! Nivel bajo el borde superior de un", C_WARN), \
                 LN("  orificio: la formula deja de valer", C_WARN), ENDIF, \
    IF(G_WHIGH), LN("! H mayor que la altura del vertedero", C_WARN), ENDIF, \
    IF(G_WFRAN), LN(" Contracciones laterales (Francis):", C_GRAY), \
                 LN("  be = b - 0.1 n H = {WBE!} m", C_GRAY), ENDIF

/* formula del elemento con H (vertedero desde la cresta o vertice;
 * orificio al centro) */
#define WFORM \
    IF(G_WTRI), \
      LN("Q = Cd (8/15) sqrt(2g) tan(theta/2) H^(5/2)", C_FG), \
      EQ("K", "Cd (8/15) sqrt(2g) tan(theta/2)", \
         "{WCD}(8/15)sqrt(2({G}))({WT2})", V_WK, 0), \
    ENDIF, \
    IF(G_WRECT), \
      LN("Q = Cd (2/3) sqrt(2g) b H^(3/2)", C_FG), \
      EQ("K", "Cd (2/3) sqrt(2g) b", "{WCD}(2/3)sqrt(2({G}))({WBE})", V_WK, 0), \
    ENDIF, \
    IF(G_WORC), \
      EQ("A", "pi d^2/4", "pi({WD1})^2/4", V_WAREA, "m2"), \
    ENDIF, \
    IF(G_WORR), \
      EQ("A", "b a", "{WD1}({WD2})", V_WAREA, "m2"), \
    ENDIF, \
    IF(G_WORC), LN("Q = Cd A sqrt(2 g H)  (H al centro)", C_FG), \
      EQ("K", "Cd A sqrt(2g)", "{WCD}({WAREA})sqrt(2({G}))", V_WK, 0), ENDIF, \
    IF(G_WORR), LN("Q = Cd A sqrt(2 g H)  (H al centro)", C_FG), \
      EQ("K", "Cd A sqrt(2g)", "{WCD}({WAREA})sqrt(2({G}))", V_WK, 0), ENDIF

/* ---- elemento simple ---- */
static const mstep x_ve1_sum[] = {
    LN(" {TXT}", C_GRAY),
    IFN(G_WINV), DAT("H", V_WH, "m"), ENDIF,
    IF(G_WINV), RES("H", V_WH, "m"), ENDIF,
    IFN(G_WINV), RES("Q", V_WQ, "m3/s"), RES("Q", V_WQLS, "l/s"), ENDIF,
    IF(G_WINV), DAT("Q", V_WQ, "m3/s"), ENDIF,
    IF(G_WH0), RES("h0 = h - H", V_WH0, "m"), ENDIF,
    SEP, WWARN,
    STOP
};
static const mstep x_ve1_memo[] = {
    SEC("DATOS"),
    LN(" Elemento: {TXT}", C_FG),
    DAT("Cd", V_WCD, 0),
    IF(G_WTRI), DAT("theta", V_WD1, "grad"), ENDIF,
    IF(G_WRECT), DAT("b", V_WD1, "m"), DAT("contracciones", V_WNC, 0), ENDIF,
    IF(G_WORC), DAT("d", V_WD1, "m"), ENDIF,
    IF(G_WORR), DAT("b", V_WD1, "m"), DAT("a", V_WD2, "m"), ENDIF,
    IFN(G_WINV), DAT("H", V_WH, "m"), ENDIF,
    IF(G_WINV), DAT("Q", V_WQ, "m3/s"), ENDIF,
    IF(G_WH0), DAT("nivel arriba h", V_WLEV, "m"), ENDIF,
    SEC("CALCULOS"),
    WFORM,
    IFN(G_WINV),
      IF(G_WTRI), EQ("Q", "K H^(5/2)", "{WK}({WH})^2.5", V_WQ, "m3/s"), ENDIF,
      IF(G_WRECT), EQ("Q", "K H^(3/2)", "{WK}({WH})^1.5", V_WQ, "m3/s"), ENDIF,
      IF(G_WORC), EQ("Q", "K H^(1/2)", "{WK}({WH})^0.5", V_WQ, "m3/s"), ENDIF,
      IF(G_WORR), EQ("Q", "K H^(1/2)", "{WK}({WH})^0.5", V_WQ, "m3/s"), ENDIF,
    ENDIF,
    IF(G_WINV),
      IF(G_WTRI), EQ("H", "(Q/K)^(2/5)", "({WQ}/{WK})^0.4", V_WH, "m"), ENDIF,
      IF(G_WRECT),
        IFN(G_WFRAN), EQ("H", "(Q/K)^(2/3)", "({WQ}/{WK})^(2/3)", V_WH, "m"), ENDIF,
        IF(G_WFRAN), LN(" Con Francis K depende de H:", C_GRAY),
                     LN(" biseccion: {WIT!} vueltas", C_GRAY),
                     RES("H", V_WH, "m"), ENDIF,
      ENDIF,
      IF(G_WORC), EQ("H", "(Q/K)^2", "({WQ}/{WK})^2", V_WH, "m"), ENDIF,
      IF(G_WORR), EQ("H", "(Q/K)^2", "({WQ}/{WK})^2", V_WH, "m"), ENDIF,
      IF(G_WH0), EQ("h0", "h - H", "{WLEV} - {WH}", V_WH0, "m"), ENDIF,
    ENDIF,
    SEC("RESULTADO"),
    RES("H", V_WH, "m"),
    RES("Q", V_WQ, "m3/s"), RES("Q", V_WQLS, "l/s"),
    IF(G_WH0), RES("Cota de la cresta h0", V_WH0, "m"), ENDIF,
    SEC("OBSERVACIONES"), WWARN,
    LN(" Cd editable (Ajustes: Cd vertedores)", C_GRAY),
    STOP
};

/* ---- estructura compuesta ---- */
static const mstep x_ve4_sum[] = {
    IFN(G_WINV), DAT("Nivel h", V_WLEV, "m"), ENDIF,
    IF(G_WINV), RES("Nivel h", V_WLEV, "m"), ENDIF,
    TAB(TB_HOOK),
    RES("Q total", V_WQ, "m3/s"), RES("Q total", V_WQLS, "l/s"),
    SEP, WWARN,
    STOP
};
static const mstep x_ve4_memo[] = {
    SEC("DATOS"),
    IFN(G_WINV), DAT("Nivel h", V_WLEV, "m"), ENDIF,
    IF(G_WINV), DAT("Q total", V_WQ, "m3/s"), ENDIF,
    SEC("CALCULOS"),
    LN("Q(h) = suma Qi(h - zi); Qi = 0 si h <= zi", C_FG),
    LN(" Vertedero: Cd (8/15) sqrt(2g) tan(t/2) H^2.5", C_GRAY),
    LN("   o Cd (2/3) sqrt(2g) b H^1.5", C_GRAY),
    LN(" Orificio: Cd A sqrt(2 g H), H al centro", C_GRAY),
    IF(G_WINV), LN(" Nivel por biseccion (Q(h) crece con h):", C_FG),
                LN("  {WIT!} vueltas", C_GRAY), ENDIF,
    TAB(TB_HOOK),
    EQ("Q", "suma Qi", 0, V_WQ, "m3/s"),
    SEC("RESULTADO"),
    RES("Nivel h", V_WLEV, "m"),
    RES("Q total", V_WQ, "m3/s"), RES("Q total", V_WQLS, "l/s"),
    SEC("OBSERVACIONES"), WWARN,
    IF(G_WDRY), LN(" Algun elemento no recibe agua (Q = 0)", C_GRAY), ENDIF,
    STOP
};

/* ---- perfil de velocidades ---- */
static const mstep x_ve6_sum[] = {
    RES("Q", V_PRQ, "m3/s"), RES("Q", V_WQLS, "l/s"),
    DAT("v media", V_PRVM, "m/s"),
    STOP
};
static const mstep x_ve6_memo[] = {
    SEC("DATOS"),
    DAT("b", V_PRB, "m"),
    IFN(G_WPTS), DAT("h", V_PRH, "m"), DAT("k", V_PRK, 0), DAT("n", V_PRN, 0), ENDIF,
    IF(G_WPTS), DAT("puntos", V_PRNP, 0), DAT("altura medida", V_PRH, "m"), ENDIF,
    SEC("CALCULOS"),
    LN("Q = b * integral de v(y) dy de 0 a h", C_FG),
    IFN(G_WPTS),
      LN(" v = k y^n:  Q = b k h^(n+1)/(n+1)", C_FG),
      EQ("Q", 0, "{PRB}({PRK})({PRH})^({PRN}+1)/({PRN}+1)", V_PRQ, "m3/s"),
    ENDIF,
    IF(G_WPTS),
      IF(G_WSIMP), LN(" Simpson 1/3 (puntos iguales e impares)", C_FG), ENDIF,
      IFN(G_WSIMP), LN(" Trapecios (puntos no aptos para Simpson)", C_FG), ENDIF,
      RES("Q", V_PRQ, "m3/s"),
    ENDIF,
    EQ("v media", "Q/(b h)", "{PRQ}/({PRB}({PRH}))", V_PRVM, "m/s"),
    SEC("RESULTADO"),
    RES("Q", V_PRQ, "m3/s"), RES("Q", V_WQLS, "l/s"),
    RES("v media", V_PRVM, "m/s"),
    STOP
};

/* ---- aguas abajo ---- */
static const mstep x_ve7_sum[] = {
    RES("v1", V_SV1, "m/s"),
    RES("E1", V_SE1, "m"),
    DAT("Fr1", V_SFR1, 0),
    IF(G_SBER),
      IFN(G_SNOE), RES("h2 subcritico", V_SHS, "m"), RES("h2 supercrit.", V_SHP, "m"), ENDIF,
      IF(G_SNOE), LN("! E2 < Emin: no hay tirante posible", C_WARN), ENDIF,
    ENDIF,
    STOP
};
static const mstep x_ve7_memo[] = {
    SEC("DATOS"),
    DAT("Q", V_SQ, "m3/s"), DAT("b", V_SB, "m"), DAT("h1", V_SH1, "m"),
    IF(G_SBER), DAT("dz (escalon)", V_SDZ, "m"), ENDIF,
    SEC("CALCULOS"),
    EQ("v1", "Q/(b h1)", "{SQ}/({SB}({SH1}))", V_SV1, "m/s"),
    EQ("E1", "h1 + v1^2/2g", "{SH1} + ({SV1})^2/(2({G}))", V_SE1, "m"),
    EQ("Fr1", "v1/sqrt(g h1)", "{SV1}/sqrt({G}({SH1}))", V_SFR1, 0),
    IF(G_SBER),
      EQ("q", "Q/b", "{SQ}/{SB}", V_SQQ, "m2/s"),
      EQ("E2", "E1 - dz", "{SE1} - {SDZ}", V_SE2, "m"),
      EQ("hc", "(q^2/g)^(1/3)", "(({SQQ})^2/{G})^(1/3)", V_SHC, "m"),
      EQ("Emin", "1.5 hc", "1.5({SHC})", V_WG2, "m"),
      IFN(G_SNOE),
        LN(" E2 = h2 + q^2/(2 g h2^2): dos raices", C_FG),
        RES("h2 subcritico", V_SHS, "m"), DAT("v2", V_SVS, "m/s"),
        RES("h2 supercritico", V_SHP, "m"), DAT("v2", V_SVP, "m/s"),
      ENDIF,
      IF(G_SNOE), LN("! E2 < Emin: no hay tirante posible", C_WARN), ENDIF,
    ENDIF,
    SEC("RESULTADO"),
    RES("v1", V_SV1, "m/s"), RES("E1", V_SE1, "m"),
    STOP
};
