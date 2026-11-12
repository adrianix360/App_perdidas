/*
 * mock_ui.c - Implementacion de ui.h y fileioc para el PC: la pantalla es
 * una matriz de texto y el teclado lee de un guion o de un generador
 * aleatorio. Permite probar la navegacion y los formularios sin CEmu.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "../../src/ui/ui.h"
#include "fileioc.h"

bool ui_quit = false;
char scr[UI_ROWS + 2][UI_COLS + 1];
char scr_msg[UI_COLS * 2];
char scr_fk[5][16];
char last_title[64];
char watch_title[64];
int watch_hits;
char alert_title[64], alert_l1[64];
long n_frames, n_alerts, n_keys;

/* fuente de teclas */
static const ui_key *script;
static int script_n, script_i;
static unsigned long rng = 1;
static long fuzz_left;
int trace;

void mock_script(const ui_key *k, int n) { script = k; script_n = n; script_i = 0; fuzz_left = 0; }
void mock_fuzz(unsigned long seed, long n) { rng = seed; fuzz_left = n; script_n = 0; script_i = 0; }
int mock_script_left(void) { return script_n - script_i; }

void ui_init(void) { ui_quit = false; }
void ui_exit(void) {}

static void put(uint8_t row, uint8_t col, const char *s)
{
    size_t i;
    if (row > UI_ROWS + 1) { printf("FALLA: fila %d fuera de pantalla\n", row); exit(3); }
    for (i = 0; s[i]; i++) {
        if (col + i >= UI_COLS) { printf("FALLA: texto sale de la pantalla: fila %d col %d \"%s\"\n", row, col, s); exit(3); }
        scr[row][col + i] = s[i];
    }
}

void ui_begin(const char *title, const char *right)
{
    int r;
    for (r = 0; r < UI_ROWS + 2; r++) { memset(scr[r], ' ', UI_COLS); scr[r][UI_COLS] = 0; }
    scr_msg[0] = 0;
    memset(scr_fk, 0, sizeof scr_fk);
    strncpy(last_title, title, 63);
    if (!strcmp(title, watch_title)) watch_hits++;
    put(0, 1, title);
    if (right) { size_t n = strlen(right); put(0, (uint8_t)(n > 39 ? 0 : 39 - n), right); }
}
void ui_text(uint8_t row, uint8_t col, const char *s, uint8_t fg, uint8_t bg) { (void)fg; (void)bg; put(row, col, s); }
void ui_text_n(uint8_t row, uint8_t col, const char *s, uint8_t maxlen, uint8_t fg, uint8_t bg)
{
    char b[UI_COLS + 1]; size_t n = strlen(s); (void)fg; (void)bg;
    if (n > maxlen) n = maxlen;
    if (n > UI_COLS) n = UI_COLS;
    memcpy(b, s, n); b[n] = 0; put(row, col, b);
}
void ui_text_r(uint8_t row, uint8_t col_end, const char *s, uint8_t fg, uint8_t bg)
{
    uint8_t n = (uint8_t)strlen(s);
    uint8_t col = (n > col_end) ? 0 : (uint8_t)(col_end - n);
    ui_text_n(row, col, s, col_end - col, fg, bg);
}
void ui_row_fill(uint8_t row, uint8_t color) { (void)row; (void)color; }
void ui_msg(const char *s, uint8_t color) { (void)color; if (s) { if (strlen(s) > UI_COLS) { printf("FALLA: mensaje largo \"%s\"\n", s); exit(3); } strcpy(scr_msg, s); } }
void ui_fbar(const char *const f[5])
{
    int i;
    for (i = 0; i < 5; i++) {
        scr_fk[i][0] = 0;
        if (f && f[i]) {
            if (strlen(f[i]) > 7) { printf("FALLA: etiqueta F%d larga \"%s\"\n", i + 1, f[i]); exit(3); }
            strcpy(scr_fk[i], f[i]);
        }
    }
}
void ui_end(void)
{
    int r;
    n_frames++;
    if (trace) {
        printf("+----------------------------------------+\n");
        for (r = 0; r <= UI_ROWS; r++) printf("|%s|\n", scr[r]);
        printf("|%-40s|\n[%s][%s][%s][%s][%s]\n", scr_msg, scr_fk[0], scr_fk[1], scr_fk[2], scr_fk[3], scr_fk[4]);
    }
}

static ui_key next_key(void)
{
    ui_key k = { K_QUIT, 0 };
    static const char chars[] = "0123456789.-+*/()^E";
    n_keys++;
    if (script_i < script_n)
        return script[script_i++];
    if (fuzz_left > 0) {
        unsigned v;
        fuzz_left--;
        rng = rng * 1103515245UL + 12345UL;
        v = (unsigned)(rng >> 8) % 40;
        if (v < 19) { k.k = K_CHAR; k.c = chars[v]; }
        else { k.k = (uint8_t)(1 + (v - 19) % (K_PGDN)); if (k.k == K_CHAR) k.k = K_ENTER; k.c = 0; }
        /* QUIT es raro (1 de cada ~40): asi se recorre mucho antes de salir */
        return k;
    }
    return k;   /* sin mas teclas: salir */
}

ui_key ui_getkey(void)
{
    ui_key k = next_key();
    if (k.k == K_QUIT)
        ui_quit = true;
    return k;
}

bool ui_alert(const char *title, const char *l1, const char *l2, uint8_t color)
{
    ui_key k;
    (void)l2; (void)color;
    n_alerts++;
    strncpy(alert_title, title, 63);
    strncpy(alert_l1, l1 ? l1 : "", 63);
    if (strlen(title) > 34 || (l1 && strlen(l1) > 34) || (l2 && strlen(l2) > 34)) {
        printf("FALLA: texto de alerta largo: %s / %s / %s\n", title, l1 ? l1 : "", l2 ? l2 : "");
        exit(3);
    }
    for (;;) {
        k = ui_getkey();
        if (k.k == K_ENTER) return true;
        if (k.k == K_CLEAR || k.k == K_QUIT) return false;
    }
}

unsigned int ui_free_ram(void) { return 123456; }

/* ---------------- fileioc ---------------- */
/* PERDCFG usa mock_file (compatibilidad con pruebas anteriores); los demas
 * AppVars usan mock_vars. */
uint8_t mock_file[256];
size_t mock_file_len;
int mock_file_exists, mock_file_archived;
mock_var mock_vars[MOCK_FILES];

static struct { int open, cfg; mock_var *v; size_t pos; int wmode; } hd[4];

mock_var *mock_find(const char *name, int create)
{
    int i;
    for (i = 0; i < MOCK_FILES; i++)
        if (mock_vars[i].name[0] && !strcmp(mock_vars[i].name, name))
            return &mock_vars[i];
    if (!create)
        return 0;
    for (i = 0; i < MOCK_FILES; i++)
        if (!mock_vars[i].name[0]) {
            strncpy(mock_vars[i].name, name, 8);
            return &mock_vars[i];
        }
    return 0;
}

int mock_load_file(const char *name, const char *path)
{
    FILE *f = fopen(path, "rb");
    mock_var *v = mock_find(name, 1);
    if (!f || !v) return 0;
    v->len = fread(v->data, 1, sizeof v->data, f);
    v->exists = 1;
    v->archived = 1;
    fclose(f);
    return 1;
}

uint8_t ti_Open(const char *name, const char *mode)
{
    int h;
    for (h = 1; h < 4 && hd[h].open; h++) ;
    if (h >= 4) return 0;
    hd[h].pos = 0;
    hd[h].wmode = (mode[0] == 'w');
    hd[h].cfg = !strcmp(name, "PERDCFG");
    if (hd[h].cfg) {
        if (hd[h].wmode) { mock_file_exists = 1; mock_file_len = 0; mock_file_archived = 0; }
        else if (!mock_file_exists) return 0;
    } else {
        mock_var *v = mock_find(name, hd[h].wmode);
        if (!v) return 0;
        if (hd[h].wmode) { v->exists = 1; v->len = 0; v->archived = 0; }
        else if (!v->exists) return 0;
        hd[h].v = v;
    }
    hd[h].open = 1;
    return (uint8_t)h;
}
int ti_Close(uint8_t h) { if (h < 4) hd[h].open = 0; return 1; }
size_t ti_Write(const void *d, size_t size, size_t count, uint8_t h)
{
    uint8_t *buf = hd[h].cfg ? mock_file : hd[h].v->data;
    size_t cap = hd[h].cfg ? sizeof mock_file : sizeof hd[h].v->data;
    size_t *len = hd[h].cfg ? &mock_file_len : &hd[h].v->len;
    if (hd[h].pos + size * count > cap) return 0;
    memcpy(buf + hd[h].pos, d, size * count); hd[h].pos += size * count;
    if (hd[h].pos > *len) *len = hd[h].pos;
    return count;
}
size_t ti_Read(void *d, size_t size, size_t count, uint8_t h)
{
    uint8_t *buf = hd[h].cfg ? mock_file : hd[h].v->data;
    size_t len = hd[h].cfg ? mock_file_len : hd[h].v->len;
    if (hd[h].pos + size * count > len) return 0;
    memcpy(d, buf + hd[h].pos, size * count); hd[h].pos += size * count;
    return count;
}
int ti_SetArchiveStatus(bool a, uint8_t h)
{
    if (hd[h].cfg) mock_file_archived = a; else hd[h].v->archived = a;
    return 1;
}
void *ti_GetDataPtr(uint8_t h) { return hd[h].cfg ? mock_file : hd[h].v->data; }
uint16_t ti_GetSize(uint8_t h) { return (uint16_t)(hd[h].cfg ? mock_file_len : hd[h].v->len); }
int ti_Delete(const char *name)
{
    mock_var *v = mock_find(name, 0);
    if (!v || !v->exists) return 0;
    v->exists = 0; v->len = 0;
    return 1;
}
