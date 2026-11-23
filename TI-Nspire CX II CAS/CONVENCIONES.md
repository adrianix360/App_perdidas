# Convenciones del port (resumen de F1 y F2, para F3-F5)

## Núcleo (F1)
- Nombres idénticos al C en la tabla del módulo: `H = require("core.hydro")`, `H.hydro_pipe_state`, `require("core.weir").weir_level`, `require("ui.expr").expr_eval`, `require("ui.numfmt").fmt_real`. Cada módulo lista su API en la cabecera.
- Retorno: código de error primero (0 = OK), luego salidas por puntero: `weir_level -> err, h, Qi, warn, iters`; `hydro_net_solve_back -> err, H`; `expr_eval -> err, valor`.
- Structs de salida: pasar `{}` y la función la rellena (subtablas `r.st`, `r.qmax` se crean solas).
- Listas Lua base 1 (nodos de red, `idx_com` nil si no hay, cuerpos, elementos de vertedero). Arreglos por enum usan el código C: `t.f[FM_CW]` claves 0..3.
- Códigos guardados (`dset`, `tipo`, `tab`, figura) conservan el número C; acceso `lista[codigo+1]`. `dragcat_cd(i)` y `cd_user[i]` usan código base 0.
- Avisos: `H.warn_has(w, flag)`, `H.warn_set(w, flag)` (sin operadores de bits en Lua 5.1).
- Helpers: `new_cfg`, `new_pipe`, `new_log`, `new_net`; registro de iteraciones `lg.r[i] = {a,b,c,d,e}`. `hydro_net_add_group(n, type, kids, nk)` con `kids` base 1.
- Datos: `src/data/{diams,lib,examples,dragcat}.lua` (examples trae PT_A..PT_COUNT).

## UI (F2)
- Módulos: `ui.rt` (corrutina), `ui.ui` (U), `ui.widgets` (W), `ui.memo`, `ui.texts`, `ui.graph`, `ui.gfxcat`, `memo_run` (MR), `gen.perdtxt`, `gen.perdgfx`, `gen.memo_defs`.
- U: `ui_begin/text/text_n/text_r/row_fill/msg/fbar/end`, `ui_getkey`, `ui_alert`, `ui_rows()` (12 filas de cuerpo en 318x212), `ui_body_w/h`, `ui_px_fill/rect/line/text` (coordenadas relativas al cuerpo), `U.g_set` (ajustes, `.dec`), `U.state` (cfg, cas, ver), `U.mark_changed`, `U.ui_request_quit`, constantes `K_*`, `C_*`.
- W: `menu_run`, `form_run`, `form_check`, `form_value_text`, `view_clear/add/add_val/add_sep/run`, `list_pick -> (idx, key)`, `text_input -> (ok, texto)`, `todo_alert`, `FF_*`, `MENU_*`, `W.APP_NAME`.
- Índices de estado y retornos 0-based como en C (`cur`, `top`, `ch`, retorno de `menu_run`/`list_pick`, `list_line[0..n-1]`); literales (`m.items`, `fm.f`, `choices`, `fk`) 1-based.
- Campo de formulario: `{label, unit, t=tabla, k=clave, chk=clave opción, setk=clave "tiene valor", flags, choices, nchoices, lo, hi}`; también `get/put`, `cget/cput`, `hget/hput`.
- memo_run: `MR.V[MR.V_Q]=x` (0-based), `MR.msetf(MR.G_*, cond)`, `MR.cfg`, `MR.log`, `MR.dlist`, `MR.method_names`, `MR.listname()`, `MR.hook`, `MR.txt`; constantes `V_*`, `G_*`, `PROG_*` en MR.
- **Nunca** llamar `ui_getkey` (ni nada que lo llame) dentro de `pcall`: Lua 5.1 no puede hacer yield a través de pcall.
- Pantallas con dibujo absoluto 320x240 se adaptan a `ui_rows()` y `ui_px_*`.
- Teclas: flechas; enter/return = ENTER; esc/clear = CLEAR; backspace/delete = DEL; tab = PGDN; backtab = PGUP; menu = toolpalette con F1..F5 + Ajustes (K_MODE); clic en barra = F1..F5; clic en cuerpo = K_CLICK con `row`.
- `main.lua` carga `scr.screens` (`scr_main`) y `scr.flujos` (`flujos_main`) con `pcall(require, ...)`.

## Persistencia (F3)
- `scr.cases` guarda cada caso como `{nombre, tipo=KT_*, datos=<copia profunda de la tabla de entradas de la pantalla>}`: solo números, cadenas, booleanos y subtablas. El módulo no conoce la forma de los datos de cada tipo. Máx. 20 casos, nombre de 8 caracteres, como en la v2.1.
- `scr.store` guarda los ajustes en `U.state.cfg` con validación de rangos y `ver`.
