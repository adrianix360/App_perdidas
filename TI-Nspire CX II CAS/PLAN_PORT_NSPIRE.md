# Plan de trabajo: PERDIDAS y FLUJOS en la TI-Nspire CX II CAS

Autor del plan: Claude Opus 5.5 (2026-11-23). Implementación: agentes Claude Sonnet.
Origen: app TI-84 Plus CE v2.1 en `C:\dev\ti84` (solo lectura, NO modificar).
Destino: `C:\dev\nspire` (unión a `Fluidos\App_Nspire_Perdidas`, repo git propio).

## 0. Regla de oro

**Ninguna función se elimina.** Todo menú, opción, tipo de problema, memoria de cálculo,
tabla, gráfica, caso del curso, ayuda, ajuste, biblioteca y "Mis casos" de la v2.1 debe
existir en la versión Nspire con el mismo resultado numérico. Lo que dependa del hardware
TI-84 se **adapta** (sección 3), nunca se borra. Ante la duda, portar 1:1.

## 1. Decisiones de arquitectura

| Tema | Decisión | Motivo |
|---|---|---|
| Lenguaje | **Lua 5.1** (Nspire Lua, `platform.apiLevel = '2.4'`) | Sin jailbreak, corre en cualquier OS de la CX II; Ndless está cerrado en OS recientes |
| Empaque | **Un solo documento** `PerdidasFlujos.tns` con menú inicial PERDIDAS / FLUJOS | Elegido por Adrián; en Nspire no hay límite de 64 KB; comparten Mis casos y ajustes |
| Fuentes | Módulos en `src/**.lua`; `tools/build.py` los concatena en `build/app.lua` con un `require` propio (tabla `package.preload` simulada) y llama a `C:\dev\tools\luna\luna.exe` | Luna acepta un solo .lua |
| Flujo de control | **Corrutina**: la lógica de la app corre en una corrutina con el mismo estilo bloqueante del C (`menu_run`, `form_run`, `ui_getkey`). `ui_getkey()` hace `coroutine.yield()`; los eventos `on.*` reanudan la corrutina con la tecla traducida. El dibujo se graba en una lista de operaciones que `on.paint(gc)` reproduce | Permite portar las pantallas casi línea a línea, con menos errores |
| Números | `double` de Lua | Equivale a la compilación `HYDRO_USE_DOUBLE` ya probada |
| Textos de memoria (PERDTXT) | Compilar `tools/gen_txt.c` del repo TI-84 en el PC, convertir `PERDTXT.bin` a un literal Lua (`src/gen/perdtxt.lua`) y portar el intérprete `memo_run.c` leyendo bytes con `string.byte` | Reutiliza el contenido exacto, sin reescribir 35 KB de textos |
| Ilustraciones (PERDGFX) | Igual: `PERDGFX.bin` (o salida de `gen_gfx.py`) a literal Lua (`src/gen/perdgfx.lua`); portar `gfxcat.c` (RLE 4 bits + paleta RGB1555 a `gc:setColorRGB` + `fillRect` por tramos) | Mismas 17 figuras y miniaturas |
| Persistencia | `on.save()` devuelve una tabla `{cfg=..., cas=..., ver=3}`; `on.restore(t)` la carga; tras cada cambio `document.markChanged()`. Casos guardados **por nombre de campo** (no volcados binarios), con versión | Mecanismo estándar de Nspire Lua; se guarda con el documento |
| Pantalla | Sin tamaño fijo: usar `platform.window:width()/height()` (318x212 en la calculadora). Fuente `sansserif` tamaño 9 (proporcional); columnas lógicas de 40 caracteres dibujadas por celdas o con `getStringWidth` | La Nspire no tiene fuente monoespaciada |
| Texto | ASCII como en la v2.1 | No cambiar contenido |

### Estructura de carpetas

```
src/main.lua            punto de entrada, eventos on.*, corrutina, on.save/on.restore
src/core/hydro.lua      hydro.c   (f, Colebrook, SJ, Haaland, Goudar-Sonnad, Q/D/h, bisección, secante, HW)
src/core/drag.lua       drag.c
src/core/weir.lua       weir.c
src/core/chan.lua       chan.c
src/ui/rt.lua           runtime: lista de dibujo, corrutina, traducción de teclas, invalidate
src/ui/ui.lua           ui.c (paleta, título, barra de acciones, alert)
src/ui/widgets.lua      widgets.c (menu_run, form_run, view_run, list_pick, text_input)
src/ui/memo.lua         memo.c
src/ui/expr.lua         expr.c (misma gramática y errores)
src/ui/numfmt.lua       numfmt.c
src/ui/texts.lua        texts.c
src/ui/graph.lua        graph.c
src/ui/gfxcat.lua       gfxcat.c
src/memo_run.lua        memo_run.c + memo_defs.h
src/data/*.lua          diams, lib, examples, dragcat
src/scr/*.lua           screens, flujos, cases, store, scr_pipe, scr_fric, scr_net, scr_lib, scr_cat, scr_drag, scr_weir, scr_chan
src/gen/*.lua           GENERADO (perdtxt.lua, perdgfx.lua): no editar a mano
tests/mock_nspire.lua   simulación de platform, gc, var, document, toolpalette, timer, cursor
tests/*.lua             pruebas
tools/build.py, tools/gen_assets.py, tools/run_tests.sh, tools/render_png.py
build/                  app.lua y PerdidasFlujos.tns
```

## 2. Herramientas (listas)

- `C:\dev\tools\lua51\lua.exe`, `luac.exe` (Lua 5.1.5, estático).
- `C:\dev\tools\luna\luna.exe` (Luna 2.1): `luna.exe build\app.lua build\PerdidasFlujos.tns`.
- gcc WinLibs y Python en el PATH. Ejecutar Python con `-I`.
- Comprobar sintaxis Lua 5.1: nada de `goto`, `//`, operadores de bits, `utf8`, `table.unpack` (usar `unpack`), `#` sobre tablas con huecos.
- Bibliotecas Nspire disponibles: `string`, `table`, `math`, `coroutine`; **no** hay `io`, `os`, `require`, `load` de archivos.
- Límites de Lua 5.1: 200 locales y 60 upvalues por función; evitar funciones gigantes.

## 3. Adaptaciones de hardware (TI-84 a Nspire)

| TI-84 | Nspire | Notas |
|---|---|---|
| F1..F5 (y=, window, zoom, trace, graph) | Barra de acciones dibujada abajo, clic con el touchpad (`on.mouseDown`) **y** tecla `menu`: `toolpalette` con las 5 acciones de la pantalla actual. Además atajos Ctrl+1..5 si `on.charIn` los distingue; si no, solo menú y clic | F5 sigue siendo ENTER en casi todas |
| ENTER | `on.enterKey` / `on.returnKey` | |
| CLEAR (volver / borrar entrada) | `on.escapeKey` y `on.clearKey` | |
| DEL | `on.backspaceKey` (y `on.deleteKey` si existe) | En FF_OPT vacía el campo |
| MODE (Ajustes) | Entrada "Ajustes" fija en el `toolpalette` + tecla `doc`/atajo si existe | |
| 2nd+MODE (salir) | Opción "Salir" guarda datos, marca cambios y avisa "Guarde el documento (ctrl+S)" | Lua no puede cerrar el documento |
| 2nd+arriba/abajo (PGUP/PGDN) | `on.tabKey` = página abajo, `on.backtabKey` = página arriba (y mantener flechas) | |
| 2nd+coma = E | aceptar `E`, `e` y el carácter de la tecla EE (`ᴇ`, U+1D07) como exponente | |
| (-) | aceptar `−` (U+2212) y `-` | |
| ALPHA + letra | `on.charIn` con letras directas | |
| `os_MemChk` (RAM libre) | `collectgarbage("count")` (memoria Lua en uso) | En Acerca y aviso de inicio |
| Archivar AppVars | `on.save` + `document.markChanged()` | |
| Migración PERDCFG/PERDCAS v1 | No hay archivos TI-84 en la Nspire: conservar el campo `ver` y el validador de rangos; documentar que los casos se recrean | El código de migración se conserva como validador de versiones futuras |
| Doble búfer graphx | `platform.window:invalidate()` y repintado completo en `on.paint` | |
| Paleta 16 colores RGB1555 | tabla Lua de colores RGB 8 bits equivalentes | |

## 4. Fases y agentes

Cada agente lee primero este plan y el código C de su módulo en `C:\dev\ti84`. Cada fase
termina con `tools/run_tests.sh` en verde y un commit en `C:\dev\nspire` (mensajes en
español, sin push). Archivos de cada agente: solo los de su fase.

| Fase | Agente | Entrega | Depende de |
|---|---|---|---|
| F0 | Sonnet | `tools/build.py` (concatenar + preload + luna), `tests/mock_nspire.lua`, `tools/run_tests.sh`, `tools/render_png.py` (lista de dibujo grabada a PNG con PIL), `src/main.lua` mínimo que compila a .tns | — |
| F1 | Sonnet | Núcleo numérico `src/core/*`, `expr`, `numfmt`, `src/data/*`; `tools/export_golden.py` (golden_table.h y random_cases*.csv a tablas Lua) y `tests/test_core.lua`: **todos** los casos dorados, aleatorios y de secante con las tolerancias del INFORME_PRUEBAS.md | F0 |
| F2 | Sonnet | `src/ui/rt.lua`, `ui`, `widgets`, `memo`, `texts`, `memo_run` + `tools/gen_assets.py` (PERDTXT y PERDGFX a `src/gen/`), `gfxcat`, `graph`; prueba `tests/test_ui.lua` (expr, numfmt, widgets con teclas simuladas, memo_run de todas las memorias sin errores) | F0 (paralela a F1) |
| F3 | Sonnet | Pantallas PERDIDAS: `screens`, `scr_pipe`, `scr_fric`, `scr_net`, `scr_lib`, `cases`, `store`, menú inicial PERDIDAS/FLUJOS en `main.lua` | F1, F2 |
| F4 | Sonnet | Pantallas FLUJOS: `flujos`, `scr_drag`, `scr_weir`, `scr_chan`, `scr_cat` | F1, F2 (paralela a F3; no toca `cases`/`store`) |
| F5 | Sonnet | `tests/test_nav.lua` (port de test_nav.c: recorre todos los menús y formularios, carga los casos del curso, guarda/carga/borra Mis casos, on.save/on.restore) + `tests/checklist.md`: cada opción del árbol de menús de la v2.1 marcada con la prueba que la cubre. Capturas PNG de cada pantalla principal | F3, F4 |
| F6 | Opus + Sonnet | Revisión (Haiku: recorrido de checklist; Opus: revisión de diferencias), `README_es.md` (instalación, teclas Nspire, guardado), build final, envío a la calculadora y prueba de Adrián | F5 |
| F7 | Opus | Subir a `github.com/adrianix360/App_perdidas` en la carpeta `TI-Nspire CX II CAS/` y actualizar la tabla del README raíz | F6 |

## 5. Criterios de aceptación

1. `tools/run_tests.sh` verde: casos dorados, aleatorios (0,1 %), secante, UI y navegación.
2. `checklist.md` sin huecos: cada opción del menú v2.1 existe y está probada.
3. `build/PerdidasFlujos.tns` se genera sin errores y abre en la calculadora sin errores de Lua.
4. Mis casos y Ajustes sobreviven a guardar, cerrar y reabrir el documento.
5. Memorias de cálculo idénticas en contenido a la v2.1 (mismos textos, mismos números con 5 cifras).
6. Ninguna regresión: cualquier diferencia numérica con la v2.1 se explica en `INFORME_PRUEBAS.md`.

## 6. Ahorro de tokens (para agentes)

- No volcar archivos enteros al informe final; reportar solo rutas, resultados de pruebas y problemas.
- Leer el C por secciones (`grep -n`, `sed -n`), no completo si no hace falta.
- Informe final de cada agente: máx. 25 líneas.
