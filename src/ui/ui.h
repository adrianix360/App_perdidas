/*
 * ui.h - Capa de pantalla y teclado de la app PERDIDAS (solo calculadora).
 *
 * Pantalla de 320x240 con fuente monoespaciada de 8 px:
 *   fila 0          barra de titulo (y = 0..11)
 *   filas 1..UI_ROWS cuerpo (10 px por fila, y = 14..213)
 *   linea de mensajes (y = 215)
 *   barra de teclas F1..F5 (y = 227..239): Y= ventana zoom trace graph
 * 40 columnas de 8 px.
 */
#ifndef UI_H
#define UI_H

#include <stdint.h>
#include <stdbool.h>

#define UI_COLS 40
#define UI_ROWS 20

/* Colores (indices de la paleta propia) */
enum {
    C_BG = 0, C_FG, C_TITLE, C_SEL, C_WARN, C_ERR, C_GRAY, C_BAR, C_OK,
    C_EDIT, C_LE, C_LP, C_GROUND, C_WATER, C_TRANSP = 254
};

/* Teclas logicas */
enum {
    K_NONE = 0, K_UP, K_DOWN, K_LEFT, K_RIGHT, K_ENTER, K_CLEAR, K_DEL,
    K_F1, K_F2, K_F3, K_F4, K_F5, K_MODE, K_QUIT, K_CHAR, K_ALPHA, K_INS,
    K_PGUP, K_PGDN
};

typedef struct {
    uint8_t k;      /* K_*                         */
    char c;         /* caracter si k == K_CHAR     */
} ui_key;

extern bool ui_quit;          /* 2nd + QUIT: salir de la app */

void ui_init(void);
void ui_exit(void);

/* Dibujo de una pantalla completa (doble bufer) */
void ui_begin(const char *title, const char *right);
void ui_text(uint8_t row, uint8_t col, const char *s, uint8_t fg, uint8_t bg);
void ui_text_n(uint8_t row, uint8_t col, const char *s, uint8_t maxlen,
               uint8_t fg, uint8_t bg);
void ui_text_r(uint8_t row, uint8_t col_end, const char *s, uint8_t fg,
               uint8_t bg);          /* alineado a la derecha        */
void ui_row_fill(uint8_t row, uint8_t color);
void ui_msg(const char *s, uint8_t color);
void ui_fbar(const char *const f[5]);
void ui_end(void);

/* Teclado: espera una tecla y la traduce (2nd + MODE = QUIT,
 * 2nd + , = E, 2nd + arriba/abajo = pagina) */
ui_key ui_getkey(void);

/* Cuadro de mensaje que espera ENTER o CLEAR. Devuelve true con ENTER. */
bool ui_alert(const char *title, const char *line1, const char *line2,
              uint8_t color);

/* RAM libre aproximada (bytes) para avisos de memoria */
unsigned int ui_free_ram(void);

#endif
