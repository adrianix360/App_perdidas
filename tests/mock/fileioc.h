/* Simulacion de fileioc para las pruebas del PC: un unico AppVar en memoria */
#ifndef MOCK_FILEIOC_H
#define MOCK_FILEIOC_H
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
uint8_t ti_Open(const char *name, const char *mode);
int ti_Close(uint8_t h);
size_t ti_Write(const void *d, size_t size, size_t count, uint8_t h);
size_t ti_Read(void *d, size_t size, size_t count, uint8_t h);
int ti_SetArchiveStatus(bool archive, uint8_t h);
/* control de la simulacion */
extern uint8_t mock_file[256];
extern size_t mock_file_len;
extern int mock_file_exists, mock_file_archived;
#endif
