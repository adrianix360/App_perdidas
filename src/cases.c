/*
 * cases.c - Casos guardados y lista propia de diametros en el AppVar
 * PERDCAS. Durante la sesion se escribe en RAM; al salir de la app se
 * archiva (asi sobrevive a un reinicio de la RAM y no se archiva con
 * graphx activo). Todo lo leido se valida y se acota: un archivo danado
 * nunca debe provocar un indice fuera de rango.
 *
 * v2.0: casos de todos los tipos (tuberia, Calcular f, arrastre,
 * vertedores y canales), compartido por PERDIDAS y FLUJOS. Cada programa
 * lista todos, pero solo abre los suyos.
 *   Formato 2: "PCS" 2 blob(2) ncust(1) cust[15] n(1)
 *              n x { nombre[9] tipo(1) largo(2) datos[largo] } suma(1)
 *   Formato 1 (v1.0, se lee y se convierte):
 *              "PCS" 1 tam_inputs(2) ncust(1) cust[15] n(1)
 *              n x { nombre[9] tipo(1) pipe_inputs } suma(1)
 */
#include <fileioc.h>
#include <string.h>
#include "app.h"
#include "pipe.h"
#include "data/data.h"
#include "ui/ui.h"
#include "ui/widgets.h"
#include "ui/numfmt.h"

#define CASES_VER 2

#if !defined(PROG_FLUJOS) || defined(CASES_ALL)
#define HAS_PERD 1
#endif
#if defined(PROG_FLUJOS) || defined(CASES_ALL)
#define HAS_FLUJ 1
#endif

typedef struct {
    char name[CASE_NAME + 1];
    uint8_t tipo;                   /* KT_*                 */
    uint16_t len;
    uint8_t data[CASE_BLOB];
} saved_case;

static saved_case cs[CASES_MAX];
static uint8_t ncs;
bool cases_dirty = false;

/* nombre corto de cada tipo para la lista (<= 28 caracteres) */
static const char *const tipo_txt[KT_COUNT] = {
    "(A) Perdidas dado Q", "(B) Caudal maximo", "(D) Diametro",
    "(C) Bomba/turbina", "(F) Valvula", "(E) Calibracion", "(I) DW vs HW",
    "f: factor de friccion",
    "AR-1 Fuerza FD/FL", "AR-2 Velocidad terminal", "AR-3 Estructura",
    "AR-4 Vuelo nivelado", "Placa plana / Stokes",
    "VE Elemento simple", "VE-4 Compuesta", "VE-6 Perfil v(y)",
    "VE-7 Aguas abajo",
    "EX-1 Venturi", "EX-2 Salto hidraulico", "EX-3 Chorro"
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
void pin_sanitize(pipe_inputs *p)
{
    uint8_t *f[] = { &p->sQ, &p->sH, &p->sD, &p->sL, &p->sks, &p->sK, &p->snu,
                     &p->sf, &p->sCH, &p->seta, &p->sHs, &p->szb, &p->sHp,
                     &p->sz1, &p->sz2, &p->sp1, &p->sp2, &p->valve, &p->modeI,
                     &p->mach, &p->sCH0, &p->itm };
    uint8_t i;
    for (i = 0; i < sizeof f / sizeof f[0]; i++)
        *f[i] = clamp01(*f[i]);
    if (p->dset >= DIAM_CHOICES)
        p->dset = 0;
}

/* ------------------------------------------------------------------ */
/* Datos de cada tipo: guardar, cargar y abrir                          */
/* ------------------------------------------------------------------ */
static bool own(uint8_t t)
{
#if defined(CASES_ALL)
    (void)t;
    return true;
#elif defined(PROG_FLUJOS)
    return t >= KT_DRAG;
#else
    return t < KT_DRAG;
#endif
}

static uint16_t mod_save(uint8_t t, uint8_t *b)
{
#ifdef HAS_PERD
    if (t < KT_FRIC) {
        memcpy(b, &pin, sizeof pin);
        return sizeof pin;
    }
    if (t == KT_FRIC)
        return fric_save(b);
#endif
#ifdef HAS_FLUJ
    if (t < KT_WEIR)
        return drag_save(b);
    if (t < KT_CHAN)
        return weir_save(b);
    return chan_save(b);
#else
    (void)b;
    return 0;
#endif
}

static bool mod_load(uint8_t t, const uint8_t *b, uint16_t n)
{
#ifdef HAS_PERD
    if (t < KT_FRIC) {
        /* v2.1: un caso de la v2.0 es mas corto; lo nuevo queda en 0 */
        if (n < PIN_V20_SIZE || n > sizeof pin)
            return false;
        memset(&pin, 0, sizeof pin);
        memcpy(&pin, b, n);
        pin_sanitize(&pin);
        return true;
    }
    if (t == KT_FRIC)
        return fric_load(b, n);
#endif
#ifdef HAS_FLUJ
    if (t < KT_WEIR)
        return drag_load(b, n);
    if (t < KT_CHAN)
        return weir_load(b, n);
    return chan_load(b, n);
#else
    (void)b;
    (void)n;
    return false;
#endif
}

static void mod_run(uint8_t t)
{
#ifdef HAS_PERD
    if (t < KT_FRIC) {
        scr_pipe_run(t, 1);
        return;
    }
    if (t == KT_FRIC) {
        scr_fric_run(0, 0, 1);
        return;
    }
#endif
#ifdef HAS_FLUJ
    if (t < KT_WEIR)
        scr_drag_run((uint8_t)(t - KT_DRAG), 1);
    else if (t < KT_CHAN)
        scr_weir_run((uint8_t)(t - KT_WEIR), 1);
    else
        scr_chan_run((uint8_t)(t - KT_CHAN), 1);
#endif
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

/* ------------------------------------------------------------------ */
/* Archivo                                                             */
/* ------------------------------------------------------------------ */
uint8_t cases_load(void)
{
    uint8_t f, hdr[7], nc, ck, c = 0x3C, i, nm[CASE_NAME + 2];
    uint16_t blob;
    real cust[DIAM_CUSTOM_MAX];

    ncs = 0;
    memset(diam_custom, 0, sizeof diam_custom);
    f = ti_Open(CASES_APPVAR, "r");
    if (!f)
        return 1;
    if (ti_Read(hdr, 7, 1, f) != 1 || memcmp(hdr, "PCS", 3) ||
        (hdr[3] != 1 && hdr[3] != CASES_VER) || hdr[6] > DIAM_CUSTOM_MAX ||
        ti_Read(cust, sizeof cust, 1, f) != 1 || ti_Read(&nc, 1, 1, f) != 1 ||
        nc > CASES_MAX)
        goto bad;
    blob = (uint16_t)(hdr[4] | hdr[5] << 8);
    c = sum8(c, hdr, 7);
    c = sum8(c, cust, sizeof cust);
    c = sum8(c, &nc, 1);
    for (i = 0; i < nc; i++) {
        saved_case *s = &cs[i];
        if (ti_Read(nm, CASE_NAME + 2, 1, f) != 1)
            goto bad;
        c = sum8(c, nm, CASE_NAME + 2);
        memcpy(s->name, nm, CASE_NAME + 1);
        s->name[CASE_NAME] = 0;
        s->tipo = nm[CASE_NAME + 1];
        if (hdr[3] == 1) {                 /* v1.0: siempre pipe_inputs */
            if (blob != sizeof(pipe_inputs) || s->tipo >= PT_COUNT)
                goto bad;
            s->len = blob;
        } else {
            if (ti_Read(&s->len, 2, 1, f) != 1)
                goto bad;
            c = sum8(c, &s->len, 2);
        }
        if (s->len > CASE_BLOB || s->tipo >= KT_COUNT || !name_ok(s->name) ||
            (s->len && ti_Read(s->data, s->len, 1, f) != 1))
            goto bad;
        c = sum8(c, s->data, s->len);
    }
    if (ti_Read(&ck, 1, 1, f) != 1 || c != ck)
        goto bad;
    for (i = 0; i < DIAM_CUSTOM_MAX; i++)
        diam_custom[i] = (cust[i] > 0 && cust[i] < 1e5) ? cust[i] : 0;
    ncs = nc;
    ti_Close(f);
    if (hdr[3] == 1)
        cases_write();                    /* pasa al formato 2 */
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
    uint8_t f, hdr[7], ck = 0x3C, i;
    bool ok;
    hdr[0] = 'P'; hdr[1] = 'C'; hdr[2] = 'S'; hdr[3] = CASES_VER;
    hdr[4] = (uint8_t)(CASE_BLOB & 0xFF);
    hdr[5] = (uint8_t)(CASE_BLOB >> 8);
    hdr[6] = DIAM_CUSTOM_MAX;
    ck = sum8(ck, hdr, 7);
    ck = sum8(ck, diam_custom, sizeof diam_custom);
    ck = sum8(ck, &ncs, 1);
    f = ti_Open(CASES_APPVAR, "w");
    if (!f)
        return false;
    ok = ti_Write(hdr, 7, 1, f) == 1 &&
         ti_Write(diam_custom, sizeof diam_custom, 1, f) == 1 &&
         ti_Write(&ncs, 1, 1, f) == 1;
    for (i = 0; ok && i < ncs; i++) {
        saved_case *s = &cs[i];
        ck = sum8(ck, s->name, CASE_NAME + 1);
        ck = sum8(ck, &s->tipo, 1);
        ck = sum8(ck, &s->len, 2);
        ck = sum8(ck, s->data, s->len);
        ok = ti_Write(s->name, CASE_NAME + 1, 1, f) == 1 &&
             ti_Write(&s->tipo, 1, 1, f) == 1 &&
             ti_Write(&s->len, 2, 1, f) == 1 &&
             (!s->len || ti_Write(s->data, s->len, 1, f) == 1);
    }
    ok = ok && ti_Write(&ck, 1, 1, f) == 1;
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
    static uint8_t tmp[CASE_BLOB + 64];
    char name[CASE_NAME + 1] = "";
    char l2[UI_COLS + 1], num[8];
    uint16_t n;
    int i;
    n = mod_save(tipo, tmp);
    if (!n || n > CASE_BLOB) {
        ui_alert("Guardar", "Este tipo no se puede", "guardar (datos grandes)", C_ERR);
        return;
    }
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
    cs[i].len = n;
    memcpy(cs[i].data, tmp, n);
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
            n = strlen(cs[i].name);
            memcpy(list_line[i] + 1, cs[i].name, n);
            n = strlen(tipo_txt[cs[i].tipo]);
            memcpy(list_line[i] + 11, tipo_txt[cs[i].tipo], n > 28 ? 28 : n);
            if (!own(cs[i].tipo))
                list_line[i][0] = '>';      /* es del otro programa */
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
            if (!own(cs[r].tipo)) {
                ui_alert("Mis casos", "Este caso se abre en",
                         cs[r].tipo >= KT_DRAG ? "el programa FLUJOS" : "el programa PERDIDAS",
                         C_TITLE);
                continue;
            }
            if (!mod_load(cs[r].tipo, cs[r].data, cs[r].len)) {
                ui_alert("Mis casos", "Caso de otra version:", "no se puede cargar", C_ERR);
                continue;
            }
            mod_run(cs[r].tipo);
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
