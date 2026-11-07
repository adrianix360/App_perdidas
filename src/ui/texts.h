/*
 * texts.h - Textos de advertencias (C puro, se prueba en el PC)
 */
#ifndef TEXTS_H
#define TEXTS_H

#include "../hydro/hydro.h"

/* Escribe hasta `max` advertencias (una por linea de 40 columnas) para la
 * mascara `warn`. Devuelve cuantas escribio. */
unsigned char warn_texts(unsigned int warn, const hydro_cfg *c,
                         unsigned char dec, char (*out)[41],
                         unsigned char max);

#endif
