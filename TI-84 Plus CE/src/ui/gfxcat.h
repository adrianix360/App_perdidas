/*
 * gfxcat.h - Ilustraciones 3D del catalogo de C_D (AppVar archivado
 * PERDGFX, generado por tools/gen_gfx.py). Se dibujan tramo a tramo desde
 * el archivo, sin bufer: no ocupan RAM.
 */
#ifndef GFXCAT_H
#define GFXCAT_H

#include <stdint.h>
#include <stdbool.h>

#define GFX_APPVAR "PERDGFX"
#define GFX_PAL0   32          /* paleta 32..47 para la rampa y acentos */
#define GFX_W 96
#define GFX_H 80
#define GFX_TW 32
#define GFX_TH 18

/* Abre PERDGFX y carga su paleta; false si falta o no es valido */
bool gfxcat_open(void);
/* Dibuja la figura i (grande o miniatura) con su esquina en (x, y) y
 * escala s (1 o 2). No hace nada si el archivo no esta abierto. */
void gfxcat_draw(uint8_t i, bool big, int x, uint8_t y, uint8_t s);
/* Rectangulo lleno (barras de comparar y ranking) */
void gfxcat_rect(int x, uint8_t y, int w, uint8_t h, uint8_t color);

#endif
