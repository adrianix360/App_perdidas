/*
 * memo_defs.h - Definiciones compartidas entre la app (interprete) y el
 * generador del AppVar PERDTXT (tools/gen_txt.c): ids de valores, banderas,
 * operaciones y orden de los programas de la memoria de calculo.
 *
 * Formato de PERDTXT (little endian):
 *   "PTX" + version(1) + n(1) + n x uint16 desplazamiento de cada programa
 *   paso: op(1) id(1) a(2) b(2) c(2) u(2); 0xFFFF = sin texto
 *   textos terminados en 0; en plantillas, 0x01 (id+1) = valor completo,
 *   0x02 (id+1) = valor corto (7 caracteres). El +1 evita el byte 0.
 */
#ifndef MEMO_DEFS_H
#define MEMO_DEFS_H

#define TX_VERSION 2
#define TX_NONE 0xFFFFu
#define TX_FULL 0x01
#define TX_SHORT 0x02
#define TX_STEP 10

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
    /* v2.0: Calcular f */
    V_FCW, V_FSJ, V_FHA, V_FGO, V_DSJ, V_DHA, V_DGO, V_FSEL, V_KPLUS,
    V_DMM,
    /* v2.0: arrastre y sustentacion */
    V_RHO, V_VIN, V_VEL, V_QDYN, V_CDV, V_AREF, V_DIM1, V_DIM2, V_LREF,
    V_FD, V_W, V_BUOY, V_NET, V_VOL, V_VT, V_VTKMH, V_MU, V_KST,
    V_FTOT, V_MOM, V_YCP,
    V_ALT, V_CL, V_ATOT, V_AW, V_NW, V_CDW, V_CDF, V_DF, V_AFUS, V_DWING,
    V_DFUS, V_THR, V_PWR, V_ALPHA, V_CLMAX, V_VST,
    V_CFL, V_CFT, V_CFM, V_CF, V_APL, V_FACES,
    /* v2.0: vertedores y orificios */
    V_WCD, V_WD1, V_WD2, V_WH, V_WQ, V_WQLS, V_WK, V_WLEV, V_WH0, V_WAREA,
    V_WBE, V_WNC, V_WIT, V_WT2, V_WG2,
    V_PRK, V_PRN, V_PRB, V_PRH, V_PRQ, V_PRVM, V_PRNP,
    V_SQ, V_SB, V_SH1, V_SV1, V_SE1, V_SQQ, V_SFR1, V_SDZ, V_SE2, V_SHS,
    V_SHP, V_SHC, V_SVS, V_SVP,
    V_COUNT
};


/* valores especiales de texto (no numericos) */
enum { V_METHOD = V_COUNT, V_LISTNAME, V_TXT };

enum {
    G_FIX, G_LAM, G_TRANS, G_CW, G_SJ, G_HA, G_GO, G_HP, G_PUMP, G_ZB,
    G_COURSE, G_BIS, G_DIRECT, G_FB, G_VP, G_VAL, G_MODEQ, G_KPOS,
    G_WITHQ, G_HASD,
    /* v2.0: banderas libres por modulo (cada pantalla llena FL de cero) */
    G_X0, G_X1, G_X2, G_X3, G_X4, G_X5, G_X6, G_X7, G_X8, G_X9, G_X10,
    G_X11
};
/* Calcular f */
#define G_FMODE2  G_X0   /* datos de tuberia (modo 2)          */
#define G_FHASV   G_X1   /* se dio v en lugar de Q             */
#define G_FKSDIN  G_X2   /* ks/D calculado desde ks y D (modo 1)*/
#define G_ZSMOOTH G_X3   /* zona hidraulicamente lisa          */
#define G_ZTRANS  G_X4   /* zona de transicion                 */
#define G_ZROUGH  G_X5   /* zona rugosa                        */
#define G_OCW     G_X6   /* fuera de rango: Colebrook-White    */
#define G_OSJ     G_X7   /* fuera de rango: Swamee-Jain        */
#define G_OHA     G_X8   /* fuera de rango: Haaland            */
#define G_OGO     G_X9   /* fuera de rango: Goudar-Sonnad      */
/* Arrastre y sustentacion */
#define G_DLIFT   G_X0   /* AR-1: sustentacion (C_L)           */
#define G_DFIG    G_X1   /* C_D de una figura del catalogo     */
#define G_DACALC  G_X2   /* area calculada con la formula      */
#define G_DBUOY   G_X3   /* con empuje                         */
#define G_DSTK    G_X4   /* se uso la formula de Stokes        */
#define G_DRELOW  G_X5   /* Re < 1E4: fuera de la tabla        */
#define G_DCRIS   G_X6   /* posible crisis de arrastre         */
#define G_DRE1    G_X7   /* Re < 1                             */
#define G_DSTEP2  G_X8   /* AR-4: con la lectura de la grafica */
#define G_DALT    G_X9   /* AR-4: rho por altitud              */
#define G_DVST    G_X10  /* AR-4: con C_Lmax                   */
#define G_DVCONV  G_X11  /* V dada en km/h o nudos             */
/* Placa plana y Stokes */
#define G_PSTK    G_X0   /* caso Stokes (esfera)               */
#define G_PLAM    G_X1
#define G_PTURB   G_X2
#define G_PMIX    G_X3
#define G_PLAMNA  G_X4   /* Re > 5E5: laminar no aplica        */
#define G_PTURBNA G_X5   /* Re > 1E7                           */
/* Vertedores y orificios */
#define G_WTRI    G_X0
#define G_WRECT   G_X1
#define G_WORC    G_X2
#define G_WORR    G_X3
#define G_WINV    G_X4   /* dado Q: hallar H o el nivel        */
#define G_WH0     G_X5   /* cota de la cresta h0 = h - H       */
#define G_WFRAN   G_X6   /* contracciones laterales (Francis)  */
#define G_WPART   G_X7   /* orificio con carga parcial         */
#define G_WHIGH   G_X8   /* H mayor que la altura del vertedero*/
#define G_WDRY    G_X9   /* un elemento no recibe agua         */
#define G_WPTS    G_X10  /* perfil por puntos                  */
#define G_WSIMP   G_X11  /* Simpson (si no, trapecios)         */
#define G_SBER    G_X10  /* aguas abajo: tirante por Bernoulli */
#define G_SNOE    G_X11  /* E < Emin: no hay tirante            */

enum { M_END = 0, M_SEC, M_DATA, M_EQ, M_RES, M_LINE, M_IF, M_IFN, M_ENDIF,
       M_CALL, M_TABLE, M_WARN, M_DLIST, M_SEP };

/* programas: subprogramas, luego resumenes y memorias de cada tipo (en el
 * orden PT_* de app.h) */
enum { S_DATA, S_CALC, S_OBS, S_STATE, S_COUNT };
#define PROG_SUM(t)  (S_COUNT + (t))
#define PROG_MEMO(t) (S_COUNT + PT_COUNT + (t))
#define HELP_COUNT   7
#define PROG_HELP(i) (S_COUNT + 2 * PT_COUNT + (i))
/* v2.0: programas de los modulos nuevos, despues de la ayuda */
enum { XP_FRIC_SUM, XP_FRIC_MEMO,
       XP_AR1_SUM, XP_AR1_MEMO, XP_AR2_SUM, XP_AR2_MEMO, XP_AR3_SUM,
       XP_AR3_MEMO, XP_AR4_SUM, XP_AR4_MEMO, XP_PL_SUM, XP_PL_MEMO,
       XP_VE1_SUM, XP_VE1_MEMO, XP_VE4_SUM, XP_VE4_MEMO, XP_VE6_SUM,
       XP_VE6_MEMO, XP_VE7_SUM, XP_VE7_MEMO,
       XP_COUNT };
#define PROG_X(i)    (S_COUNT + 2 * PT_COUNT + HELP_COUNT + (i))
#define PROG_COUNT   (S_COUNT + 2 * PT_COUNT + HELP_COUNT + XP_COUNT)
/* tablas de iteraciones (M_TABLE id) */
enum { TB_B_COURSE = 0, TB_B_BIS, TB_D, TB_CW,
       TB_HOOK,          /* lo dibuja la pantalla (memo_hook) */
       TB_COUNT };

#endif
