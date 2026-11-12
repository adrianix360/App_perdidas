/*
 * cases.c - Casos guardados y lista propia de diametros en el AppVar
 * PERDCAS. Durante la sesion se escribe en RAM; al salir de la app se
 * archiva (asi sobrevive a un reinicio de la RAM y no se archiva con
 * graphx activo). Todo lo leido se valida y se acota: un archivo danado
 * nunca debe provocar un indice fuera de rango.
 *
 * Formato: "PCS" ver(1) tam_inputs(2) ncust(1) cust[15] n(1)
 *          n x { nombre[9] tipo(1) pipe_inputs } suma(1)
 */
#include <fileioc.h>
#include <string.h>
#include "app.h"
#include "pipe.h"
#include "data/data.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "ui/numfmt.h"

#define CASES_VER 1

typedef struct {
    char name[CASE_NAME + 1];
    uint8_t tipo;
    pipe_inputs in;
} saved_case;

static saved_case cs[CASES_MAX];
static uint8_t ncs;
bool cases_dirty = false;

static const char *const tipo_txt[PT_COUNT] = {
    "(A) Perdidas dado Q", "(B) Caudal maximo", "(D) Diametro",
    "(C) Bomba/turbina", "(F) Valvula", "(E) Calibracion", "(I) DW vs HW"
};

static uint8_t sum8(uint8_t c, const void *p, size_t n)
{
    const uint8_t *b = (const uint8_t *)p;
    while (n--)
        c = (uint8_t)((c << 1 | c >> 7) ^ *b++);
    return c;
}

static uint8_t clamp01(uint8_t v)
{
    return v ? 1 : 0;
}

/* acota todo lo que se usa como indice o bandera */
static void sanitize(pipe_inputs *p)
{
    uint8_t *f[] = { &p->sQ, &p->sH, &p->sD, &p->sL, &p->sks, &p->sK, &p->snu,
                     &p->sf, &p->sCH, &p->seta, &p->sHs, &p->szb, &p->sHp,
                     &p->sz1, &p->sz2, &p->sp1, &p->sp2, &p->valve, &p->modeI,
                     &p->mach };
    uint8_t i;
    for (i = 0; i < sizeof f / sizeof f[0]; i++)
        *f[i] = clamp01(*f[i]);
    if (p->dset >= DIAM_CHOICES)
        p->dset = 0;
}

static bool name_ok(const char *n)
{
    uint8_t i;
    if (!n[0])
        return false;
    for (i = 0; i < CASE_NAME && n[i]; i++)
        if (!((n[i] >= 'A' && n[i] <= 'Z') || (n[i] >= '0' && n[i] <= '9')))
            return false;
    return n[i] == 0;
}

uint8_t cases_load(void)
{
    uint8_t f, hdr[7], nc, ck, c = 0x3C, i;
    real cust[DIAM_CUSTOM_MAX];

    ncs = 0;
    memset(diam_custom, 0, sizeof diam_custom);
    f = ti_Open(CASES_APPVAR, "r");
    if (!f)
        return 1;
    if (ti_Read(hdr, 6, 1, f) != 1 || memcmp(hdr, "PCS", 3) || hdr[3] != CASES_VER ||
        (hdr[4] | hdr[5] << 8) != sizeof(pipe_inputs) ||
        ti_Read(&hdr[6], 1, 1, f) != 1 || hdr[6] > DIAM_CUSTOM_MAX ||
        ti_Read(cust, sizeof cust, 1, f) != 1 || ti_Read(&nc, 1, 1, f) != 1 ||
        nc > CASES_MAX || (nc && ti_Read(cs, sizeof cs[0], nc, f) != nc) ||
        ti_Read(&ck, 1, 1, f) != 1)
        goto bad;
    c = sum8(c, hdr, 7);
    c = sum8(c, cust, sizeof cust);
    c = sum8(c, &nc, 1);
    c = sum8(c, cs, sizeof cs[0] * nc);
    if (c != ck)
        goto bad;
    for (i = 0; i < nc; i++) {
        cs[i].name[CASE_NAME] = 0;
        if (!name_ok(cs[i].name) || cs[i].tipo >= PT_COUNT)
            goto bad;
        sanitize(&cs[i].in);
    }
    for (i = 0; i < DIAM_CUSTOM_MAX; i++)
        diam_custom[i] = (cust[i] > 0 && cust[i] < 1e5) ? cust[i] : 0;
    ncs = nc;
    ti_Close(f);
    return 0;
bad:
    ti_Close(f);
    ncs = 0;
    memset(diam_custom, 0, sizeof diam_custom);
    return 2;
}

/* Escribe el AppVar en RAM (se archiva al salir de la app) */
bool cases_write(void)
{
    uint8_t f, hdr[7], ck = 0x3C;
    bool ok;
    hdr[0] = 'P'; hdr[1] = 'C'; hdr[2] = 'S'; hdr[3] = CASES_VER;
    hdr[4] = (uint8_t)(sizeof(pipe_inputs) & 0xFF);
    hdr[5] = (uint8_t)(sizeof(pipe_inputs) >> 8);
    hdr[6] = DIAM_CUSTOM_MAX;
    ck = sum8(ck, hdr, 7);
    ck = sum8(ck, diam_custom, sizeof diam_custom);
    ck = sum8(ck, &ncs, 1);
    ck = sum8(ck, cs, sizeof cs[0] * ncs);
    f = ti_Open(CASES_APPVAR, "w");
    if (!f)
        return false;
    ok = ti_Write(hdr, 7, 1, f) == 1 &&
         ti_Write(diam_custom, sizeof diam_custom, 1, f) == 1 &&
         ti_Write(&ncs, 1, 1, f) == 1 &&
         (!ncs || ti_Write(cs, sizeof cs[0], ncs, f) == ncs) &&
         ti_Write(&ck, 1, 1, f) == 1;
    ti_Close(f);
    cases_dirty = true;
    return ok;
}

bool cases_archive(void)
{
    uint8_t f = ti_Open(CASES_APPVAR, "r");
    if (!f)
        return false;
    ti_SetArchiveStatus(true, f);
    ti_Close(f);
    cases_dirty = false;
    return true;
}

uint8_t cases_count(void)
{
    return ncs;
}

static int find(const char *name)
{
    uint8_t i;
    for (i = 0; i < ncs; i++)
        if (!strcmp(cs[i].name, name))
            return i;
    return -1;
}

/* Guarda el caso actual (desde la pantalla de resultado) */
void case_save_ui(uint8_t tipo)
{
    char name[CASE_NAME + 1] = "";
    char l2[UI_COLS + 1], num[8];
    int i;
    if (!text_input("GUARDAR CASO", "Nombre del caso (max. 8):", name, CASE_NAME))
        return;
    i = find(name);
    if (i >= 0) {
        if (!ui_alert("Guardar", "Ya existe un caso con ese", "nombre. Reemplazarlo?", C_WARN))
            return;
    } else {
        if (ncs >= CASES_MAX) {
            ui_alert("Guardar", "Lista llena (20 casos).", "Borre uno en Mis casos.", C_ERR);
            return;
        }
        i = ncs++;
    }
    strcpy(cs[i].name, name);
    cs[i].tipo = tipo;
    cs[i].in = pin;
    if (!cases_write()) {
        ui_alert("Guardar", "No se pudo escribir el", "archivo: falta memoria RAM", C_ERR);
        return;
    }
    strcpy(l2, "Casos guardados: ");
    fmt_int(ncs, num);
    strcat(l2, num);
    strcat(l2, " de 20");
    ui_alert("Caso guardado", name, l2, C_OK);
}

void scr_cases(void)
{
    static const char *const fk[5] = { "CARGAR", "", "BORRAR", "", "VOLVER" };
    static uint8_t cur;
    char hint[UI_COLS + 1], num[8];
    uint8_t i, k;
    int r;
    for (;;) {
        for (i = 0; i < ncs; i++) {
            size_t n;
            memset(list_line[i], ' ', UI_COLS);
            list_line[i][UI_COLS] = 0;
            list_line[i][0] = ' ';
            n = strlen(cs[i].name);
            memcpy(list_line[i] + 1, cs[i].name, n);
            memcpy(list_line[i] + 11, tipo_txt[cs[i].tipo], strlen(tipo_txt[cs[i].tipo]));
        }
        strcpy(hint, "Casos: ");
        fmt_int(ncs, num);
        strcat(hint, num);
        strcat(hint, " de 20. ENTER carga");
        r = list_pick("MIS CASOS", hint, ncs, cur, fk, &k);
        if (k == K_QUIT || k == K_CLEAR || k == K_F5)
            return;
        if (k == K_MODE) {
            scr_settings();
            continue;
        }
        if (r < 0)
            continue;
        cur = (uint8_t)r;
        if (k == K_ENTER || k == K_F1) {
            pin = cs[r].in;
            sanitize(&pin);
            scr_pipe_run(cs[r].tipo, 1);
            if (ui_quit)
                return;
        } else if (k == K_F3) {
            if (ui_alert("Borrar caso", cs[r].name, "Se borra para siempre.", C_WARN)) {
                for (i = (uint8_t)r; i + 1 < ncs; i++)
                    cs[i] = cs[i + 1];
                ncs--;
                if (cur >= ncs && cur)
                    cur--;
                cases_write();
            }
        }
    }
}
