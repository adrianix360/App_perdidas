/*
 * widgets.h - Menus, formularios y visor de lineas (patron comun de todas
 * las pantallas: titulo arriba, contenido al centro, mensajes y barra de
 * teclas F1..F5 abajo).
 */
#ifndef WIDGETS_H
#define WIDGETS_H

#include <stdint.h>
#include <stdbool.h>
#include "../hydro/hydro.h"
#include "ui.h"

/* ---------------- Menu ---------------- */
enum { MENU_BACK = -1, MENU_QUIT = -2, MENU_MODE = -3 };

typedef struct {
    const char *title;
    const char *const *items;
    uint8_t n;
    uint8_t cur;
} menu_t;

/* Devuelve el indice elegido (0..n-1) o MENU_BACK / MENU_QUIT / MENU_MODE.
 * Las teclas 1..9 eligen directo. */
int menu_run(menu_t *m);

/* ---------------- Formulario ---------------- */
#define FF_ANY     0x00
#define FF_POS     0x01   /* debe ser > 0                       */
#define FF_NONNEG  0x02   /* debe ser >= 0                      */
#define FF_CHOICE  0x04   /* lista de opciones (izq/der)        */
#define FF_INT     0x08   /* entero en [lo, hi]                 */
#define FF_OPT     0x10   /* opcional: puede quedar vacio (DEL) */
#define FF_INFO    0x20   /* solo lectura                       */
#define FF_RANGE   0x40   /* debe estar en [lo, hi]             */

typedef struct {
    const char *label;
    const char *unit;
    real *val;               /* campos numericos                   */
    uint8_t *ch;             /* FF_CHOICE: indice elegido          */
    uint8_t *set;            /* 1 si tiene valor (NULL: siempre)   */
    uint8_t flags;
    const char *const *choices;
    uint8_t nchoices;
    real lo, hi;
} form_field;

typedef struct {
    const char *title;
    const char *page;        /* texto a la derecha del titulo      */
    form_field *f;
    uint8_t n;
    uint8_t cur, top;
    const char *fk[5];
    const char *hint;        /* mensaje cuando no hay otro         */
    const char *msg;         /* mensaje pendiente (una vez)        */
    uint8_t msg_color;
    void (*on_commit)(void); /* se llama tras aceptar un valor     */
} form_t;

/* Corre el formulario hasta que el usuario pulsa F1..F5, CLEAR (atras),
 * MODE (ajustes), 2nd+QUIT o ENTER en el ultimo campo. Devuelve la tecla. */
uint8_t form_run(form_t *fm);

/* Revisa que todos los campos obligatorios tengan valor valido. Si falta
 * uno, lo selecciona, deja el mensaje y devuelve false. */
bool form_check(form_t *fm);

/* Texto de un valor de campo segun los ajustes */
void form_value_text(const form_field *f, char *buf);

/* ---------------- Visor de lineas ---------------- */
#define VIEW_MAX 120
extern char view_line[VIEW_MAX][UI_COLS + 1];
extern uint8_t view_color[VIEW_MAX];
extern uint8_t view_n;

void view_clear(void);
void view_add(const char *s, uint8_t color);
/* "  etiqueta = valor unidad" con el formato de los ajustes */
void view_add_val(const char *label, real v, const char *unit);
void view_add_sep(void);

/* Muestra las lineas con desplazamiento. Devuelve la tecla que salio:
 * K_F1..K_F5, K_CLEAR, K_QUIT o K_MODE. */
uint8_t view_run(const char *title, const char *const fk[5]);

/* ---------------- Lista con desplazamiento ---------------- */
#define LIST_MAX 40
extern char list_line[LIST_MAX][UI_COLS + 1];
/* Muestra list_line[0..n-1]; devuelve el indice elegido o -1 si se sale.
 * *key recibe la tecla que termino (K_ENTER, K_F1..K_F5, K_CLEAR,
 * K_QUIT, K_MODE). */
int list_pick(const char *title, const char *hint, uint8_t n, uint8_t cur,
              const char *const fk[5], uint8_t *key);

/* ---------------- Entrada de texto (nombres) ---------------- */
/* Letras A-Z y digitos; ALPHA alterna letras/digitos. Devuelve false si
 * se cancela con CLEAR. */
bool text_input(const char *title, const char *prompt, char *buf,
                uint8_t maxlen);

/* Aviso de modulo pendiente */
void todo_alert(const char *what, uint8_t fase);

#endif
