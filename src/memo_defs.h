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

#define TX_VERSION 1
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
    V_COUNT
};


/* valores especiales de texto (no numericos) */
enum { V_METHOD = V_COUNT, V_LISTNAME };

enum {
    G_FIX, G_LAM, G_TRANS, G_CW, G_SJ, G_HA, G_GO, G_HP, G_PUMP, G_ZB,
    G_COURSE, G_BIS, G_DIRECT, G_FB, G_VP, G_VAL, G_MODEQ, G_KPOS,
    G_WITHQ, G_HASD
};

enum { M_END = 0, M_SEC, M_DATA, M_EQ, M_RES, M_LINE, M_IF, M_IFN, M_ENDIF,
       M_CALL, M_TABLE, M_WARN, M_DLIST, M_SEP };

/* programas: subprogramas, luego resumenes y memorias de cada tipo (en el
 * orden PT_* de app.h) */
enum { S_DATA, S_CALC, S_OBS, S_STATE, S_COUNT };
#define PROG_SUM(t)  (S_COUNT + (t))
#define PROG_MEMO(t) (S_COUNT + PT_COUNT + (t))
#define HELP_COUNT   7
#define PROG_HELP(i) (S_COUNT + 2 * PT_COUNT + (i))
#define PROG_COUNT   (S_COUNT + 2 * PT_COUNT + HELP_COUNT)

#endif
