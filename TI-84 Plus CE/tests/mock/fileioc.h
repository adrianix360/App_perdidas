/* Simulacion de fileioc para las pruebas del PC: varios AppVars en memoria */
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
void *ti_GetDataPtr(uint8_t h);
uint16_t ti_GetSize(uint8_t h);
int ti_Delete(const char *name);
/* control de la simulacion: el AppVar de ajustes (PERDCFG) */
extern uint8_t mock_file[256];
extern size_t mock_file_len;
extern int mock_file_exists, mock_file_archived;
/* AppVars genericos */
#define MOCK_FILES 4
typedef struct {
    char name[9];
    uint8_t data[49152];
    size_t len;
    int exists, archived;
} mock_var;
extern mock_var mock_vars[MOCK_FILES];
mock_var *mock_find(const char *name, int create);
int mock_load_file(const char *name, const char *path);
#endif
