/*
 * ui.c - Ver ui.h
 */
#include <graphx.h>
#include <ti/getcsc.h>
#include <ti/vars.h>
#include <string.h>
#include "ui.h"

bool ui_quit = false;
static bool second = false;
static bool alpha = false;
static bool alpha_lock = false;

void ui_set_alpha_lock(bool on)
{
    alpha_lock = on;
    alpha = false;      /* sin ALPHA de un solo uso pendiente */
}

/* Letra de cada tecla en modo ALPHA (TI-84 Plus CE) */
static char alpha_char(uint8_t k)
{
    switch (k) {
    case sk_Math: return 'A';   case sk_Apps: return 'B';
    case sk_Prgm: return 'C';   case sk_Recip: return 'D';
    case sk_Sin: return 'E';    case sk_Cos: return 'F';
    case sk_Tan: return 'G';    case sk_Power: return 'H';
    case sk_Square: return 'I'; case sk_Comma: return 'J';
    case sk_LParen: return 'K'; case sk_RParen: return 'L';
    case sk_Div: return 'M';    case sk_Log: return 'N';
    case sk_7: return 'O';      case sk_8: return 'P';
    case sk_9: return 'Q';      case sk_Mul: return 'R';
    case sk_Ln: return 'S';     case sk_4: return 'T';
    case sk_5: return 'U';      case sk_6: return 'V';
    case sk_Sub: return 'W';    case sk_Store: return 'X';
    case sk_1: return 'Y';      case sk_2: return 'Z';
    default: return 0;
    }
}


#define Y_TITLE 0
#define Y_BODY 14
#define Y_MSG 215
#define Y_BAR 227

static void set_palette(void)
{
    gfx_palette[C_BG] = gfx_RGBTo1555(255, 255, 255);
    gfx_palette[C_FG] = gfx_RGBTo1555(0, 0, 0);
    gfx_palette[C_TITLE] = gfx_RGBTo1555(0, 51, 102);
    gfx_palette[C_SEL] = gfx_RGBTo1555(170, 205, 255);
    gfx_palette[C_WARN] = gfx_RGBTo1555(190, 90, 0);
    gfx_palette[C_ERR] = gfx_RGBTo1555(200, 0, 0);
    gfx_palette[C_GRAY] = gfx_RGBTo1555(110, 110, 110);
    gfx_palette[C_BAR] = gfx_RGBTo1555(215, 215, 215);
    gfx_palette[C_OK] = gfx_RGBTo1555(0, 120, 0);
    gfx_palette[C_EDIT] = gfx_RGBTo1555(255, 240, 170);
    gfx_palette[C_LE] = gfx_RGBTo1555(0, 70, 200);
    gfx_palette[C_LP] = gfx_RGBTo1555(210, 0, 0);
    gfx_palette[C_GROUND] = gfx_RGBTo1555(150, 120, 90);
    gfx_palette[C_WATER] = gfx_RGBTo1555(120, 180, 255);
}

void ui_init(void)
{
    gfx_Begin();
    set_palette();
    gfx_SetDrawBuffer();
    gfx_SetMonospaceFont(8);
    gfx_SetTextTransparentColor(C_TRANSP);
    ui_quit = false;
    second = false;
    alpha = false;
}

void ui_exit(void)
{
    gfx_End();
}

void ui_text(uint8_t row, uint8_t col, const char *s, uint8_t fg, uint8_t bg)
{
    int y = (row == 0) ? Y_TITLE + 2 : Y_BODY + (row - 1) * 10 + 1;
    gfx_SetTextFGColor(fg);
    gfx_SetTextBGColor(bg);
    gfx_PrintStringXY(s, col * 8, y);
}

void ui_text_n(uint8_t row, uint8_t col, const char *s, uint8_t maxlen,
               uint8_t fg, uint8_t bg)
{
    char buf[UI_COLS + 1];
    uint8_t n = (uint8_t)strlen(s);
    if (n > maxlen)
        n = maxlen;
    if (n > UI_COLS)
        n = UI_COLS;
    memcpy(buf, s, n);
    buf[n] = 0;
    ui_text(row, col, buf, fg, bg);
}

void ui_text_r(uint8_t row, uint8_t col_end, const char *s, uint8_t fg,
               uint8_t bg)
{
    uint8_t n = (uint8_t)strlen(s);
    uint8_t col = (n > col_end) ? 0 : (uint8_t)(col_end - n);
    ui_text_n(row, col, s, col_end - col, fg, bg);
}

void ui_row_fill(uint8_t row, uint8_t color)
{
    gfx_SetColor(color);
    if (row == 0)
        gfx_FillRectangle(0, Y_TITLE, 320, 12);
    else
        gfx_FillRectangle(0, Y_BODY + (row - 1) * 10, 320, 10);
}

void ui_begin(const char *title, const char *right)
{
    gfx_FillScreen(C_BG);
    gfx_SetColor(C_TITLE);
    gfx_FillRectangle(0, Y_TITLE, 320, 12);
    ui_text(0, 1, title, C_BG, C_TITLE);
    if (second)
        ui_text(0, 34, "2nd", C_SEL, C_TITLE);
    if (right)
        ui_text_r(0, 39, right, C_BG, C_TITLE);
}

void ui_msg(const char *s, uint8_t color)
{
    gfx_SetColor(C_BG);
    gfx_FillRectangle(0, Y_MSG - 1, 320, 11);
    gfx_SetColor(C_GRAY);
    gfx_HorizLine(0, Y_MSG - 2, 320);
    gfx_SetTextFGColor(color);
    gfx_SetTextBGColor(C_BG);
    if (s)
        gfx_PrintStringXY(s, 0, Y_MSG);
}

void ui_fbar(const char *const f[5])
{
    uint8_t i;
    int x;
    gfx_SetColor(C_BAR);
    gfx_FillRectangle(0, Y_BAR, 320, 13);
    for (i = 0; i < 5; i++) {
        x = i * 64;
        gfx_SetColor(C_GRAY);
        gfx_Rectangle(x + 1, Y_BAR, 62, 13);
        if (f && f[i] && f[i][0]) {
            unsigned int w = gfx_GetStringWidth(f[i]);
            if (w > 60)
                w = 60;
            gfx_SetTextFGColor(C_FG);
            gfx_SetTextBGColor(C_BAR);
            gfx_PrintStringXY(f[i], x + 32 - (int)w / 2, Y_BAR + 3);
        }
    }
}

void ui_end(void)
{
    gfx_SwapDraw();
}

ui_key ui_getkey(void)
{
    ui_key r;
    uint8_t k;
    r.k = K_NONE;
    r.c = 0;
    for (;;) {
        while (!(k = os_GetCSC()))
            ;
        if (k == sk_2nd) {
            second = !second;
            alpha = false;
            /* devolver K_NONE permite redibujar el indicador 2nd */
            return r;
        }
        if (k == sk_Alpha) {
            alpha = !alpha;
            second = false;
            r.k = K_ALPHA;
            return r;
        }
        if ((alpha || alpha_lock) && !second) {
            char c = alpha_char(k);
            alpha = false;
            if (c) {
                r.k = K_CHAR;
                r.c = c;
                return r;
            }
        }
        if (second) {
            second = false;
            switch (k) {
            case sk_Mode: ui_quit = true; r.k = K_QUIT; return r;
            case sk_Comma: r.k = K_CHAR; r.c = 'E'; return r;
            case sk_Up: r.k = K_PGUP; return r;
            case sk_Down: r.k = K_PGDN; return r;
            case sk_Del: r.k = K_INS; return r;
            default: break;   /* 2nd + otra tecla: se trata como normal */
            }
        }
        switch (k) {
        case sk_Up: r.k = K_UP; return r;
        case sk_Down: r.k = K_DOWN; return r;
        case sk_Left: r.k = K_LEFT; return r;
        case sk_Right: r.k = K_RIGHT; return r;
        case sk_Enter: r.k = K_ENTER; return r;
        case sk_Clear: r.k = K_CLEAR; return r;
        case sk_Del: r.k = K_DEL; return r;
        case sk_Yequ: r.k = K_F1; return r;
        case sk_Window: r.k = K_F2; return r;
        case sk_Zoom: r.k = K_F3; return r;
        case sk_Trace: r.k = K_F4; return r;
        case sk_Graph: r.k = K_F5; return r;
        case sk_Mode: r.k = K_MODE; return r;
        case sk_0: r.c = '0'; break;
        case sk_1: r.c = '1'; break;
        case sk_2: r.c = '2'; break;
        case sk_3: r.c = '3'; break;
        case sk_4: r.c = '4'; break;
        case sk_5: r.c = '5'; break;
        case sk_6: r.c = '6'; break;
        case sk_7: r.c = '7'; break;
        case sk_8: r.c = '8'; break;
        case sk_9: r.c = '9'; break;
        case sk_DecPnt: r.c = '.'; break;
        case sk_Chs: r.c = '-'; break;
        case sk_Sub: r.c = '-'; break;
        case sk_Add: r.c = '+'; break;
        case sk_Mul: r.c = '*'; break;
        case sk_Div: r.c = '/'; break;
        case sk_LParen: r.c = '('; break;
        case sk_RParen: r.c = ')'; break;
        case sk_Power: r.c = '^'; break;
        default: break;
        }
        if (r.c) {
            r.k = K_CHAR;
            return r;
        }
        /* tecla sin uso: se ignora */
    }
}

bool ui_alert(const char *title, const char *l1, const char *l2,
              uint8_t color)
{
    ui_key k;
    /* se dibuja directo sobre la pantalla visible, encima de lo que hay */
    gfx_SetDrawScreen();
    gfx_SetColor(C_FG);
    gfx_Rectangle(18, 70, 284, 80);
    gfx_SetColor(C_BG);
    gfx_FillRectangle(19, 71, 282, 78);
    gfx_SetColor(color);
    gfx_FillRectangle(19, 71, 282, 12);
    gfx_SetTextFGColor(C_BG);
    gfx_SetTextBGColor(color);
    gfx_PrintStringXY(title, 24, 73);
    gfx_SetTextFGColor(C_FG);
    gfx_SetTextBGColor(C_BG);
    if (l1)
        gfx_PrintStringXY(l1, 24, 92);
    if (l2)
        gfx_PrintStringXY(l2, 24, 106);
    gfx_SetTextFGColor(C_GRAY);
    gfx_PrintStringXY("[ENTER] aceptar  [CLEAR] volver", 24, 132);
    gfx_SetDrawBuffer();
    for (;;) {
        k = ui_getkey();
        if (k.k == K_ENTER)
            return true;
        if (k.k == K_CLEAR || k.k == K_QUIT)
            return false;
    }
}

unsigned int ui_free_ram(void)
{
    void *p;
    return (unsigned int)os_MemChk(&p);
}
