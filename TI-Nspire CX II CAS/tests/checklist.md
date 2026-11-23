# Checklist del port Nspire (v2.1 completa)

Cada fila es una opcion, tecla, ayuda, ajuste, caso o elemento de biblioteca de la v2.1 y la
prueba Nspire que la cubre (archivo de `tests/` y fragmento literal del texto de la asercion).
`python -I tools/check_checklist.py` comprueba que cada fragmento existe en su archivo y que no
queda ninguna fila `SIN COBERTURA`. Se regenera con `python -I tools/gen_checklist.py`.


## 1. Arranque, ciclo de vida y teclas (Nspire)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 1 | Menu inicial PERDIDAS / FLUJOS / Salir (3 opciones) | tests/test_nav.lua | `arranque: menu inicial con 3 opciones` |
| 2 | Primer cuadro con on.create (SO antiguo) | tests/test_nav.lua | `arranque con on.create (SO antiguo) dibuja el primer cuadro` |
| 3 | Primer cuadro sin construction ni create | tests/test_nav.lua | `arranque sin construction/create: dibuja el primer cuadro` |
| 4 | Primer cuadro solo con on.paint | tests/test_nav.lua | `arranque solo con on.paint: dibuja el primer cuadro` |
| 5 | construction + create no duplican el arranque | tests/test_nav.lua | `construction + create + teclas: un solo arranque` |
| 6 | Inicio 1: abre PERDIDAS | tests/test_nav.lua | `PERDIDAS: menu principal` |
| 7 | Inicio 2: abre FLUJOS | tests/test_nav.lua | `inicio 2: abre FLUJOS` |
| 8 | Inicio 3 Salir: avisa de guardar (ctrl+S) | tests/test_nav.lua | `inicio: Salir avisa de guardar el documento` |
| 9 | Inicio: Salir marca el documento (document.markChanged) | tests/test_nav.lua | `inicio: Salir marca el documento como modificado` |
| 10 | Inicio: ESC equivale a Salir | tests/test_nav.lua | `inicio: ESC equivale a Salir` |
| 11 | Inicio: flechas + ENTER | tests/test_nav.lua | `inicio: flechas + ENTER sobre Salir` |
| 12 | Inicio: tecla menu abre Ajustes (MODE) | tests/test_nav.lua | `inicio: tecla menu abre Ajustes` |
| 13 | Teclas: flechas, enter, esc/clear, backspace, tab/backtab, charIn, EE y menos U+2212 | tests/test_ui.lua | `getkey: 16 teclas leidas` |
| 14 | Teclas: clic en F1..F5 de la barra de acciones | tests/test_ui.lua | `clic F5` |
| 15 | Teclas: toolpalette (menu) con F1..F5 y Ajustes | tests/test_ui.lua | `toolpalette TRES -> F3` |
| 16 | Clic en la barra de acciones (F4) abre Ajustes | tests/test_nav.lua | `clic en la barra (F4) abre Ajustes` |
| 17 | Clic en una fila de menu la elige | tests/test_nav.lua | `clic en una fila del menu la elige` |
| 18 | Clic fuera de botones no hace nada | tests/test_nav.lua | `clic en el titulo no hace nada` |
| 19 | Clic F5 CALC calcula | tests/test_nav.lua | `clic en la barra (F5 CALC) calcula` |
| 20 | Toolpalette A: MAT,SUMA K,FLUIDO,CALC f,CALC,Ajustes | tests/test_nav.lua | `toolpalette A: F1..F5 + Ajustes` |
| 21 | Toolpalette: MAT (F1) | tests/test_nav.lua | `toolpalette: MAT (F1)` |
| 22 | Toolpalette: SUMA K (F2) | tests/test_nav.lua | `toolpalette: SUMA K (F2)` |
| 23 | Toolpalette: FLUIDO (F3) | tests/test_nav.lua | `toolpalette: FLUIDO (F3)` |
| 24 | Toolpalette: CALC f (F4) | tests/test_nav.lua | `toolpalette: CALC f (F4) abre Calcular f` |
| 25 | Toolpalette: CALC (F5) | tests/test_nav.lua | `toolpalette: CALC (F5)` |
| 26 | Toolpalette: Ajustes | tests/test_nav.lua | `toolpalette: Ajustes` |
| 27 | Toolpalette se re-registra en cada pantalla | tests/test_nav.lua | `toolpalette: Calcular f registra sus acciones` |
| 28 | Tecla menu en un formulario abre Ajustes | tests/test_nav.lua | `tecla menu en un formulario abre Ajustes` |
| 29 | Resize 320x240 sin errores | tests/test_nav.lua | `{ 320, 240 }` |
| 30 | Resize 480x320 sin errores | tests/test_nav.lua | `{ 480, 320 }` |
| 31 | Resize en caliente conserva la pantalla | tests/test_nav.lua | `resize en caliente conserva la pantalla` |
| 32 | Maqueta medida con gc:getStringHeight | tests/test_nav.lua | `maqueta: una letra mas alta reduce las filas` |
| 33 | Maqueta: mensaje y etiquetas de la barra caben | tests/test_nav.lua | `maqueta: las etiquetas de la barra caben en su boton` |
| 34 | Error de la corrutina se muestra en pantalla | tests/test_nav.lua | `el error se muestra en pantalla` |
| 35 | ENTER reinicia tras un error | tests/test_nav.lua | `ENTER reinicia la app en el menu inicial` |
| 36 | F5 (clic) reinicia tras un error | tests/test_nav.lua | `F5 tambien reinicia tras un error` |
| 37 | on.save / on.restore: casos de ambos programas + ajustes | tests/test_nav.lua | `on.save: casos de los dos programas y ajustes cambiados` |
| 38 | on.restore en app nueva | tests/test_nav.lua | `on.restore: casos y ajustes de vuelta en una app nueva` |
| 39 | on.restore antes del primer paint | tests/test_nav.lua | `on.restore antes del primer paint: arranca con datos` |
| 40 | on.save tras on.restore: ida y vuelta | tests/test_nav.lua | `on.save tras on.restore: ida y vuelta igual` |
| 41 | on.restore con datos invalidos / version futura | tests/test_nav.lua | `on.restore con datos invalidos no rompe` |
| 42 | Caso de PERDIDAS restaurado calcula | tests/test_nav.lua | `caso de PERDIDAS restaurado calcula` |
| 43 | Caso de FLUJOS restaurado calcula | tests/test_nav.lua | `caso AR-01 restaurado da v terminal` |

## 2. Widgets y utilidades (menu, formulario, visor, lista, texto, alerta)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 44 | menu_run: scroll, ENTER, digitos, ESC, tab | tests/test_ui.lua | `menu: tab = pagina abajo` |
| 45 | form_run: FF_POS / FF_NONNEG / FF_INT / FF_RANGE / FF_OPT / FF_CHOICE / FF_INFO | tests/test_ui.lua | `form: FF_RANGE` |
| 46 | form_run: expresiones (12.8, coma, e minuscula) | tests/test_ui.lua | `form: expresion = 12.8` |
| 47 | form_run: scroll, backtab/tab | tests/test_ui.lua | `form: tab = ultimo` |
| 48 | view_run: paginas, flechas, F5 | tests/test_ui.lua | `view: tab = pagina abajo` |
| 49 | list_pick: ENTER, F1, ESC, vacia | tests/test_ui.lua | `lista: F1 devuelve el indice actual` |
| 50 | text_input: mayusculas, 8 caracteres, ESC | tests/test_ui.lua | `text_input: maxlen 8` |
| 51 | ui_alert: ENTER true, ESC false | tests/test_ui.lua | `alert: ESC false` |
| 52 | expr: gramatica y errores | tests/test_core.lua | `5. EXPR y NUMFMT` |
| 53 | numfmt: formato de numeros | tests/test_core.lua | `5. EXPR y NUMFMT` |
| 54 | Datos (diams, lib, examples, dragcat) consistentes | tests/test_core.lua | `6. DATOS` |

## 3. PERDIDAS - Menu principal (9 opciones)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 55 | 1 Tuberia simple abre y ESC vuelve | tests/test_nav.lua | `PERDIDAS opcion ` |
| 56 | 2 Sistemas (serie / paralelo) | tests/test_perdidas.lua | `"sistemas"` |
| 57 | 3 Calcular f (solo f) | tests/test_perdidas.lua | `"calcular f"` |
| 58 | 4 Flujos externos (FLUJOS) abre FLUJOS | tests/test_nav.lua | `PERDIDAS 4 Flujos externos abre FLUJOS` |
| 59 | 4 Flujos externos: vuelve a PERDIDAS | tests/test_nav.lua | `FLUJOS desde PERDIDAS: vuelve a PERDIDAS` |
| 60 | 5 Biblioteca | tests/test_perdidas.lua | `"biblioteca"` |
| 61 | 6 Mis casos | tests/test_perdidas.lua | `mis casos vacio` |
| 62 | 7 Ajustes | tests/test_perdidas.lua | `"ajustes"` |
| 63 | 8 Ayuda / Acerca de | tests/test_perdidas.lua | `"ayuda"` |
| 64 | 9 Salir (guardar) | tests/test_nav.lua | `PERDIDAS 9 Salir: guarda y avisa` |
| 65 | ESC en el principal pide confirmacion | tests/test_perdidas.lua | `ESC en el principal pide confirmacion` |
| 66 | ESC en el principal: confirmar sale | tests/test_perdidas.lua | `confirmar salida` |
| 67 | ESC en el principal: rechazar | tests/test_perdidas.lua | `rechazar confirmacion` |
| 68 | Tecla menu / F4 abren Ajustes desde el menu | tests/test_perdidas.lua | `tuberia: menu abre Ajustes` |

## 4. PERDIDAS - Tuberia simple (8 entradas: tipos A B D C F E I + f)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 69 | A Perdidas dado el caudal | tests/test_perdidas.lua | `A tecleado: hT = 19,76 m` |
| 70 | B Caudal maximo / comprobacion | tests/test_perdidas.lua | `B P-03 tecleado: Q = 318,8 l/s` |
| 71 | D Diametro de diseno | tests/test_perdidas.lua | `D P-17 con valvula: 256,8 / 285,75 / 262,38` |
| 72 | C Bomba o turbina: carga y P | tests/test_perdidas.lua | `C P-11: HB = 45,6 m, Pb = 28,9 kW` |
| 73 | F Valvula de control | tests/test_perdidas.lua | `F valvula: Kv = 60,7` |
| 74 | E Calibrar rugosidad | tests/test_perdidas.lua | `E calibracion tecleada` |
| 75 | I Darcy-W. vs Hazen-Williams (modo hf) | tests/test_perdidas.lua | `I modo hf` |
| 76 | I Darcy-W. vs Hazen-Williams (modo Q) | tests/test_perdidas.lua | `I modo Q` |
| 77 | 8 f: factor de friccion | tests/test_perdidas.lua | `calcular f tecleado: resultado` |
| 78 | Cada entrada del submenu abre y ESC vuelve | tests/test_nav.lua | `tuberia entrada ` |
| 79 | Cada tipo: ESC vuelve al submenu | tests/test_perdidas.lua | `: ESC vuelve al menu` |
| 80 | A: v, hm y p/gamma del resultado | tests/test_perdidas.lua | `A tecleado: v = 2,29 m/s` |
| 81 | A: memoria con los 4 metodos de f | tests/test_perdidas.lua | `memoria A metodo ` |
| 82 | A: memoria laminar (64/Re) | tests/test_perdidas.lua | `memoria A laminar` |
| 83 | B: iteracion del curso | tests/test_perdidas.lua | `B P-03: iteracion del curso` |
| 84 | B: tabla de iteraciones en la memoria | tests/test_perdidas.lua | `B P-03: memoria con tabla de iteraciones` |
| 85 | B: secante / arranque con C_H | tests/test_perdidas.lua | `B secante con C_H de arranque` |
| 86 | B: memoria de la secante | tests/test_perdidas.lua | `B secante: memoria` |
| 87 | C: cota piezometrica | tests/test_perdidas.lua | `C P-11: cota piezometrica 935,6` |
| 88 | C: memoria | tests/test_perdidas.lua | `C: memoria` |
| 89 | D: Kv de la valvula | tests/test_perdidas.lua | `D P-18: Kv = 60,7` |
| 90 | D: memoria | tests/test_perdidas.lua | `D: memoria` |
| 91 | D: grafica LE/LP | tests/test_perdidas.lua | `D: grafica` |
| 92 | D con lista propia de diametros | tests/test_perdidas.lua | `D con lista propia: resultado` |
| 93 | D con lista propia: la memoria la nombra | tests/test_perdidas.lua | `D con lista propia: la memoria nombra la lista` |
| 94 | D con lista propia vacia: aviso | tests/test_perdidas.lua | `D con lista propia vacia avisa` |
| 95 | E: memoria | tests/test_perdidas.lua | `E: memoria` |
| 96 | I: memoria | tests/test_perdidas.lua | `I: memoria` |
| 97 | Validacion: calcular sin datos | tests/test_perdidas.lua | `A: calcular sin datos avisa` |
| 98 | Validacion: D = 0 | tests/test_perdidas.lua | `A: D = 0 rechazado` |
| 99 | Validacion: expresion mal formada (3+) | tests/test_perdidas.lua | `A: 3+ rechazado` |
| 100 | Validacion: division entre cero | tests/test_perdidas.lua | `A: 1/0 rechazado` |
| 101 | Validacion: ks negativa | tests/test_perdidas.lua | `A: ks < 0 rechazado` |
| 102 | F1 MAT (material) | tests/test_perdidas.lua | `biblioteca: material elegido` |
| 103 | F2 SUMA K | tests/test_perdidas.lua | `sumador: PVC 200 mm da Suma K = 6.7` |
| 104 | F3 FLUIDO | tests/test_perdidas.lua | `fluido: aviso` |
| 105 | F4 CALC f con cursor en 'f dado' | tests/test_nav.lua | `A: F4 CALC f con el cursor en 'f dado' abre Calcular f` |
| 106 | F4 AJUSTES en D | tests/test_nav.lua | `: F4 = AJUSTES` |
| 107 | F4 AJUSTES en E | tests/test_nav.lua | `: F4 = AJUSTES` |
| 108 | F4 AJUSTES en I | tests/test_nav.lua | `: F4 = AJUSTES` |
| 109 | F5 CALC | tests/test_perdidas.lua | `A: calcular sin datos avisa` |
| 110 | Resultado F1 MEMORIA | tests/test_perdidas.lua | `: memoria sin plantillas"` |
| 111 | Resultado F2 GRAFICO (A B C D F) | tests/test_perdidas.lua | `: grafica LE/LP` |
| 112 | Resultado F2 GRAFICO no aplica a E/I | tests/test_perdidas.lua | `: grafico no aplica a E/I` |
| 113 | Resultado F3 GUARDAR | tests/test_perdidas.lua | `guardar: pide nombre` |
| 114 | Resultado F5 VOLVER | tests/test_perdidas.lua | `: se vuelve al menu inicial` |
| 115 | Calcular f desde A: USAR f devuelve f | tests/test_nav.lua | `Calcular f: USAR f copia f al formulario A` |
| 116 | Calcular f desde A: el campo recibe f | tests/test_nav.lua | `Calcular f: A recibe f = 0.0264` |

## 5. PERDIDAS - Sistemas serie/paralelo (G) y grafica (H)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 117 | Formulario del sistema, 2 tubos en serie | tests/test_perdidas.lua | `red: 2 tubos en serie tecleados` |
| 118 | Hacia adelante (dado H) | tests/test_perdidas.lua | `S-01: Q total de la pantalla = motor` |
| 119 | Hacia atras (dado el Q de un tubo) | tests/test_perdidas.lua | `S-04: hacia atras da H necesaria` |
| 120 | Comprobacion de nudos y rutas | tests/test_perdidas.lua | `: comprobacion de nudos y rutas` |
| 121 | Memoria (modulos de caudal) | tests/test_perdidas.lua | `: memoria` |
| 122 | Secciones CAUDAL Y CARGA / REPARTO | tests/test_perdidas.lua | `S-04: secciones de la memoria` |
| 123 | Grafica LE/LP del sistema (H) | tests/test_perdidas.lua | `: grafica` |
| 124 | F1 CALC f exige cursor en f dado | tests/test_perdidas.lua | `red: CALC f exige cursor en f dado` |
| 125 | Aviso: tubo sin f ni ks | tests/test_perdidas.lua | `red: aviso sin f ni ks` |
| 126 | Aviso: falta el tubo conocido | tests/test_perdidas.lua | `red: hacia atras sin tubo conocido avisa` |
| 127 | Aviso: falta la carga H | tests/test_perdidas.lua | `red: sin carga H avisa` |
| 128 | Motor de red | tests/test_perdidas.lua | `S-01 motor` |
| 129 | Grafica LE/LP (graph_run) | tests/test_ui.lua | `graph: dibuja` |
| 130 | Grafica sin tanque 2 / 0 tramos | tests/test_ui.lua | `graph: 0 tramos` |

## 6. PERDIDAS - Calcular f (solo f)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 131 | Modo Re y ks/D: resultado | tests/test_perdidas.lua | `calcular f tecleado: resultado` |
| 132 | Tabla de los 4 metodos | tests/test_perdidas.lua | `calcular f: tabla de los 4 metodos` |
| 133 | Motor f(20000, 1e-4) = 0.0264 | tests/test_perdidas.lua | `motor f(20000,1e-4) = 0,0264` |
| 134 | Memoria con tabla de iteraciones de Colebrook | tests/test_perdidas.lua | `calcular f: memoria con iteraciones` |
| 135 | F2 MODO pasa a Datos tuberia | tests/test_perdidas.lua | `calcular f: F2 pasa al modo datos de tuberia` |
| 136 | F1 MAT solo en modo datos | tests/test_perdidas.lua | `calcular f: MAT solo en modo 2` |
| 137 | F3 FLUIDO solo en modo datos | tests/test_perdidas.lua | `calcular f: FLUIDO solo en modo 2` |
| 138 | Metodo de f: Colebrook-White | tests/test_perdidas.lua | `"calcular f: metodo "` |
| 139 | Metodo de f: Swamee-Jain | tests/test_perdidas.lua | `"calcular f: metodo "` |
| 140 | Metodo de f: Haaland | tests/test_perdidas.lua | `"calcular f: metodo "` |
| 141 | Metodo de f: Goudar-Sonnad | tests/test_perdidas.lua | `"calcular f: metodo "` |
| 142 | F2 USAR f devuelve f al formulario | tests/test_nav.lua | `Calcular f desde A: el resultado ofrece USAR f` |

## 7. PERDIDAS - Biblioteca

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 143 | 1 Materiales (lista) | tests/test_perdidas.lua | `biblioteca: materiales` |
| 144 | 1 Material elegido: ks y C_H a los formularios | tests/test_perdidas.lua | `material: ks = 0.15 y C_H = 130 en los formularios` |
| 145 | 2 Accesorios y sumador | tests/test_perdidas.lua | `"sumador"` |
| 146 | Sumador: AGREGAR | tests/test_perdidas.lua | `sumador: AGREGAR abre la lista de accesorios` |
| 147 | Sumador: accesorio agregado | tests/test_perdidas.lua | `sumador: accesorio agregado` |
| 148 | Sumador: OTRO | tests/test_perdidas.lua | `sumador: OTRO agrega linea libre` |
| 149 | Sumador: QUITAR | tests/test_perdidas.lua | `sumador: PVC 200 mm da Suma K` |
| 150 | Sumador: CONJUNT. (conjuntos del curso) | tests/test_perdidas.lua | `sumador: conjuntos del curso` |
| 151 | Sumador: USAR | tests/test_perdidas.lua | `sumador: aviso de uso` |
| 152 | 3 Fluido por defecto | tests/test_perdidas.lua | `biblioteca: fluido` |
| 153 | Fluido: agua 20 C a Ajustes | tests/test_perdidas.lua | `fluido agua 20 C: nu, gamma y pv a Ajustes` |
| 154 | Fluido: aire por defecto | tests/test_perdidas.lua | `fluido aire en Ajustes` |
| 155 | Fluido: nu del curso | tests/test_perdidas.lua | `fluido de curso: solo nu` |
| 156 | 4 Diametros comerciales | tests/test_perdidas.lua | `"diametros"` |
| 157 | Lista propia de diametros (15 campos) | tests/test_perdidas.lua | `lista propia: formulario` |
| 158 | Lista propia guardada y marca cambios | tests/test_perdidas.lua | `lista propia: marca cambios` |
| 159 | Lista propia persiste en el documento | tests/test_perdidas.lua | `persistencia: lista propia de diametros` |
| 160 | Cada entrada de Biblioteca abre y vuelve | tests/test_nav.lua | `biblioteca entrada ` |
| 161 | Material 1 de 24: PVC y CPVC (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 162 | Material 2 de 24: PEAD (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 163 | Material 3 de 24: Vidrio (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 164 | Material 4 de 24: Asbesto cemento (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 165 | Material 5 de 24: Fibra vidrio (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 166 | Material 6 de 24: Acero comercial (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 167 | Material 7 de 24: Concreto centrifug. (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 168 | Material 8 de 24: H. fundido asfalt. (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 169 | Material 9 de 24: Hierro fundido (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 170 | Material 10 de 24: Hierro galvanizado (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 171 | Material 11 de 24: Arcilla vitrificada (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 172 | Material 12 de 24: Hierro ductil (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 173 | Material 13 de 24: Concreto (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 174 | Material 14 de 24: Acero liso (C_H) (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 175 | Material 15 de 24: Acero soldado (C_H) (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 176 | Material 16 de 24: Acero bridas (C_H) (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 177 | Material 17 de 24: Concreto liso (C_H) (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 178 | Material 18 de 24: Concreto rug. (C_H) (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 179 | Material 19 de 24: Cobre/laton (C) (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 180 | Material 20 de 24: Acero inox. (C) (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 181 | Material 21 de 24: Hule alisado (C) (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 182 | Material 22 de 24: Hierro forjado (C) (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 183 | Material 23 de 24: Hierro fundido (C) (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 184 | Material 24 de 24: Duela de madera (C) (ks y C_H) | tests/test_perdidas.lua | `"material " .. m.name .. ": ks"` |
| 185 | Accesorio 1 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 186 | Accesorio 2 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 187 | Accesorio 3 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 188 | Accesorio 4 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 189 | Accesorio 5 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 190 | Accesorio 6 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 191 | Accesorio 7 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 192 | Accesorio 8 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 193 | Accesorio 9 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 194 | Accesorio 10 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 195 | Accesorio 11 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 196 | Accesorio 12 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 197 | Accesorio 13 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 198 | Accesorio 14 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 199 | Accesorio 15 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 200 | Accesorio 16 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 201 | Accesorio 17 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 202 | Accesorio 18 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 203 | Accesorio 19 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 204 | Accesorio 20 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 205 | Accesorio 21 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 206 | Accesorio 22 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 207 | Accesorio 23 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 208 | Accesorio 24 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 209 | Accesorio 25 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 210 | Accesorio 26 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 211 | Accesorio 27 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 212 | Accesorio 28 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 213 | Accesorio 29 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 214 | Accesorio 30 de 30 (lista de accesorios) | tests/test_perdidas.lua | `sumador: los 30 accesorios` |
| 215 | Conjunto del curso 1: PVC 200 mm (pag. 51) | tests/test_nav.lua | `"conjunto " .. pr.name .. ": Suma K` |
| 216 | Conjunto del curso 2: Examen 2025 P1 | tests/test_nav.lua | `"conjunto " .. pr.name .. ": Suma K` |
| 217 | Conjunto del curso 3: Examen 2019 P4 | tests/test_nav.lua | `"conjunto " .. pr.name .. ": Suma K` |
| 218 | Conjunto del curso 4: Examen 2017 P4 | tests/test_nav.lua | `"conjunto " .. pr.name .. ": Suma K` |
| 219 | Conjunto del curso 5: Examen 2018 P1a | tests/test_nav.lua | `"conjunto " .. pr.name .. ": Suma K` |
| 220 | Conjunto del curso 6: Examen 2018 P1b | tests/test_nav.lua | `"conjunto " .. pr.name .. ": Suma K` |
| 221 | Fluido 1 de 15: Agua 5 C | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 222 | Fluido 2 de 15: Agua 10 C | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 223 | Fluido 3 de 15: Agua 15 C | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 224 | Fluido 4 de 15: Agua 20 C | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 225 | Fluido 5 de 15: Agua 25 C | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 226 | Fluido 6 de 15: Agua 30 C | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 227 | Fluido 7 de 15: Agua 40 C | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 228 | Fluido 8 de 15: Curso 2025 T4 | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 229 | Fluido 9 de 15: Curso 2017-2019 | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 230 | Fluido 10 de 15: Curso 2024 P1 | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 231 | Fluido 11 de 15: Curso ej. 4 | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 232 | Fluido 12 de 15: Curso hojas | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 233 | Fluido 13 de 15: Aire (curso) | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 234 | Fluido 14 de 15: Aire 15 C | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 235 | Fluido 15 de 15: Aire 20 C | tests/test_nav.lua | `"fluido " .. w.name .. ": valores a Ajustes"` |
| 236 | Lista de diametros 1: PVC examen 2025 | tests/test_perdidas.lua | `"diametros: lista "` |
| 237 | Lista de diametros 2: Nominal 2024 200-500 | tests/test_perdidas.lua | `"diametros: lista "` |
| 238 | Lista de diametros 3: Pract.3/Ej.5 150-400 | tests/test_perdidas.lua | `"diametros: lista "` |
| 239 | Lista de diametros 4: Practica 2 50-300 | tests/test_perdidas.lua | `"diametros: lista "` |
| 240 | Lista de diametros 5: General 50-1500 | tests/test_perdidas.lua | `"diametros: lista "` |

## 8. PERDIDAS - Mis casos (compartidos)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 241 | Lista vacia | tests/test_perdidas.lua | `mis casos vacio` |
| 242 | Guardar: pide nombre | tests/test_perdidas.lua | `guardar: pide nombre` |
| 243 | Guardar: marca cambios | tests/test_perdidas.lua | `guardar: marca cambios` |
| 244 | Guardar: nombre repetido pide confirmar | tests/test_perdidas.lua | `guardar: nombre repetido pide confirmar` |
| 245 | Guardar: nombre vacio no se acepta | tests/test_perdidas.lua | `guardar: nombre vacio no se acepta` |
| 246 | Guardar: maximo 8 caracteres | tests/test_perdidas.lua | `nombre: maximo 8 caracteres` |
| 247 | Guardar: limite de 20 casos | tests/test_perdidas.lua | `guardar: limite de 20 casos` |
| 248 | Lista: nombres, tipo y contador (Casos: n de 20) | tests/test_perdidas.lua | `Mis casos: lista` |
| 249 | ENTER carga y calcula (A) | tests/test_perdidas.lua | `Mis casos: ENTER carga y calcula (A)` |
| 250 | Cargar cada tipo de caso | tests/test_perdidas.lua | `Mis casos: carga el caso ` |
| 251 | F3 BORRAR pide confirmacion | tests/test_perdidas.lua | `borrar: pide confirmacion` |
| 252 | BORRAR: ESC cancela | tests/test_perdidas.lua | `borrar: ESC cancela` |
| 253 | BORRAR elimina el caso | tests/test_perdidas.lua | `borrar: elimina el caso` |
| 254 | Caso de FLUJOS marcado con > | tests/test_perdidas.lua | `Mis casos: caso de FLUJOS marcado con >` |
| 255 | Caso de FLUJOS: se abre en FLUJOS | tests/test_perdidas.lua | `Mis casos: un caso de FLUJOS se abre en FLUJOS` |
| 256 | on.save / on.restore de los casos | tests/test_perdidas.lua | `on.restore: casos de vuelta` |
| 257 | Casos invalidos descartados | tests/test_perdidas.lua | `on.restore: casos invalidos descartados` |
| 258 | Caso restaurado se carga y calcula | tests/test_perdidas.lua | `caso restaurado se carga y calcula` |

## 9. Ajustes (los 19 campos)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 259 | Formulario de Ajustes | tests/test_perdidas.lua | `ajustes: formulario` |
| 260 | Metodo de f (4 metodos) | tests/test_nav.lua | `Ajustes: metodo, g, gamma, nu` |
| 261 | g | tests/test_nav.lua | `Ajustes: metodo, g, gamma, nu` |
| 262 | gamma | tests/test_nav.lua | `Ajustes: metodo, g, gamma, nu` |
| 263 | nu | tests/test_nav.lua | `Ajustes: metodo, g, gamma, nu` |
| 264 | Decimales | tests/test_nav.lua | `Ajustes: decimales, tolerancia, presion de vapor` |
| 265 | Tolerancia iter. | tests/test_nav.lua | `Ajustes: decimales, tolerancia, presion de vapor` |
| 266 | Presion de vapor | tests/test_nav.lua | `Ajustes: decimales, tolerancia, presion de vapor` |
| 267 | v minima aviso | tests/test_nav.lua | `Ajustes: v minima, v maxima, L/D despreciable, hm/hf` |
| 268 | v maxima aviso | tests/test_nav.lua | `Ajustes: v minima, v maxima, L/D despreciable, hm/hf` |
| 269 | L/D despreciable | tests/test_nav.lua | `Ajustes: v minima, v maxima, L/D despreciable, hm/hf` |
| 270 | Aviso hm/hf | tests/test_nav.lua | `Ajustes: v minima, v maxima, L/D despreciable, hm/hf` |
| 271 | Re laminar < | tests/test_nav.lua | `Ajustes: Re laminar, Re turbulento` |
| 272 | Re turbulento > | tests/test_nav.lua | `Ajustes: Re laminar, Re turbulento` |
| 273 | rho del aire | tests/test_nav.lua | `Ajustes: rho y nu del aire, empuje con aire` |
| 274 | nu del aire | tests/test_nav.lua | `Ajustes: rho y nu del aire, empuje con aire` |
| 275 | Empuje con aire | tests/test_nav.lua | `Ajustes: rho y nu del aire, empuje con aire` |
| 276 | Cd vertedores | tests/test_nav.lua | `Ajustes: Cd vertedores, km/h por nudo, manometro` |
| 277 | km/h por nudo | tests/test_nav.lua | `Ajustes: Cd vertedores, km/h por nudo, manometro` |
| 278 | Manometro (convencion) | tests/test_nav.lua | `Ajustes: Cd vertedores, km/h por nudo, manometro` |
| 279 | F5 LISTO guarda g y decimales | tests/test_perdidas.lua | `ajustes: g y decimales guardados` |
| 280 | Rango invalido (g = 50) | tests/test_perdidas.lua | `ajustes: g = 50 fuera de rango` |
| 281 | Re lam > Re turb avisa | tests/test_perdidas.lua | `ajustes: Re lam > Re turb avisa` |
| 282 | Valor valido sale | tests/test_perdidas.lua | `ajustes: valor valido sale` |
| 283 | F1 DEFECTO pide confirmacion | tests/test_perdidas.lua | `ajustes: DEFECTO pide confirmacion` |
| 284 | DEFECTO restaura valores | tests/test_perdidas.lua | `ajustes: valores por defecto` |
| 285 | Ajustes persisten en on.save/on.restore | tests/test_perdidas.lua | `ajustes: on.restore devuelve metodo y decimales` |
| 286 | Ajustes: los 19 persisten en on.save | tests/test_nav.lua | `on.save conserva los 19 ajustes` |
| 287 | Ajustes: validador de rangos (store) | tests/test_perdidas.lua | `store: g = 0 invalido` |
| 288 | Ajustes: version futura ignorada | tests/test_perdidas.lua | `restore: version futura ignorada` |
| 289 | Cd propio del catalogo persiste | tests/test_perdidas.lua | `restore: Cd propio` |
| 290 | Ajustes desde FLUJOS (MODE y opcion 6) | tests/test_flujos.lua | `Ajustes (6) y MODE abren la pantalla de ajustes` |

## 10. Ayuda y Acerca de (PERDIDAS)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 291 | Tema 1: Uso y teclas | tests/test_perdidas.lua | `"ayuda tema "` |
| 292 | Tema 2: Tipos de problema | tests/test_perdidas.lua | `"ayuda tema "` |
| 293 | Tema 3: Formulas | tests/test_perdidas.lua | `"ayuda tema "` |
| 294 | Tema 4: Potencia bruta y neta | tests/test_perdidas.lua | `"ayuda tema "` |
| 295 | Tema 5: Suma K y fuentes de datos | tests/test_perdidas.lua | `"ayuda tema "` |
| 296 | Tema 6: Advertencias | tests/test_perdidas.lua | `"ayuda tema "` |
| 297 | Tema 7: Erratas del material | tests/test_perdidas.lua | `"ayuda tema "` |
| 298 | Tema 8: Factor de friccion f | tests/test_perdidas.lua | `"ayuda tema "` |
| 299 | Casos del curso (cargar) | tests/test_perdidas.lua | `ayuda: casos del curso` |
| 300 | Acerca de (version y memoria Lua) | tests/test_perdidas.lua | `ayuda: acerca de` |
| 301 | Cada entrada de Ayuda abre y ESC vuelve | tests/test_nav.lua | `ayuda entrada ` |
| 302 | Todos los temas de ayuda (11) abren | tests/test_ui.lua | `"help_topic "` |
| 303 | PERDTXT valido y 55 programas de memoria | tests/test_ui.lua | `PROG_COUNT` |
| 304 | Todas las memorias corren sin error y <= 40 columnas | tests/test_ui.lua | `todos los programas corrieron` |

## 11. Casos del curso de PERDIDAS (23 ejercicios + F-01..F-05)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 305 | Caso P-02 PVC 200 mm, p (A): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 306 | Caso P-02 PVC 200 mm, p (A): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 307 | Caso P-01 DW vs HW, PVC (I): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 308 | Caso P-01 DW vs HW, PVC (I): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 309 | Caso P-03 Pres. ejemplo 1 (B): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 310 | Caso P-03 Pres. ejemplo 1 (B): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 311 | Caso P-05 Pres. practica 1 (B): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 312 | Caso P-05 Pres. practica 1 (B): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 313 | Caso P-07 Examen 2018 P1a (B): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 314 | Caso P-07 Examen 2018 P1a (B): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 315 | Caso P-09 Tarea 4 P3a (B): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 316 | Caso P-09 Tarea 4 P3a (B): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 317 | Caso P-10 Tarea 4 P3b (I): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 318 | Caso P-10 Tarea 4 P3b (I): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 319 | Caso P-11 Pres. ejemplo 4 (C): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 320 | Caso P-11 Pres. ejemplo 4 (C): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 321 | Caso P-12 Examen 2024 P2 (C): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 322 | Caso P-12 Examen 2024 P2 (C): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 323 | Caso P-15 Pres. ejemplo 5 (D): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 324 | Caso P-15 Pres. ejemplo 5 (D): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 325 | Caso P-17 Examen 2025 P1 (D): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 326 | Caso P-17 Examen 2025 P1 (D): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 327 | Caso P-18 Examen 2025 P2 (F): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 328 | Caso P-18 Examen 2025 P2 (F): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 329 | Caso P-19 Examen 2025 P3a (C): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 330 | Caso P-19 Examen 2025 P3a (C): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 331 | Caso P-20 Examen 2025 P3b (C): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 332 | Caso P-20 Examen 2025 P3b (C): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 333 | Caso P-21 Examen 2024 P1 (D): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 334 | Caso P-21 Examen 2024 P1 (D): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 335 | Caso P-25 Pres. ejemplo 6 (E): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 336 | Caso P-25 Pres. ejemplo 6 (E): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 337 | Caso P-26 Ejercicio 2, HW (D): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 338 | Caso P-26 Ejercicio 2, HW (D): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 339 | Caso P-27 Ejercicio 2, HW (B): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 340 | Caso P-27 Ejercicio 2, HW (B): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 341 | Caso S-01 Examen 2024 P3 (G): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 342 | Caso S-01 Examen 2024 P3 (G): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 343 | Caso S-02 Examen 2025 P5 (G): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 344 | Caso S-02 Examen 2025 P5 (G): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 345 | Caso S-03 Examen 2018 P3 (G): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 346 | Caso S-03 Examen 2018 P3 (G): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 347 | Caso S-04 Examen 2017 P5 (G): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 348 | Caso S-04 Examen 2017 P5 (G): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 349 | Caso S-05 Tarea 4 P4 (G): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 350 | Caso S-05 Tarea 4 P4 (G): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 351 | Caso F-01 f: Re 20000, ks/D 1E-4 (ej. 3a): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 352 | Caso F-01 f: Re 20000, ks/D 1E-4 (ej. 3a): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 353 | Caso F-02 f: Re 2E5, ks/D 1.5E-4 (ej. 3b): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 354 | Caso F-02 f: Re 2E5, ks/D 1.5E-4 (ej. 3b): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 355 | Caso F-03 f: 200 l/s, 285.75 mm (2025 P2): resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 356 | Caso F-03 f: 200 l/s, 285.75 mm (2025 P2): memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 357 | Caso F-04 f: Re 455180, PVC 200 mm: resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 358 | Caso F-04 f: Re 455180, PVC 200 mm: memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 359 | Caso F-05 f: laminar, 20 mm, 0.02 l/s: resultado | tests/test_perdidas.lua | `: resultado contiene '` |
| 360 | Caso F-05 f: laminar, 20 mm, 0.02 l/s: memoria sin plantillas | tests/test_perdidas.lua | `: memoria sin plantillas` |
| 361 | Lista de casos del curso | tests/test_perdidas.lua | `ayuda: casos del curso` |

## 12. FLUJOS - Menu principal y submenus

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 362 | Titulo y 8 opciones | tests/test_flujos.lua | `menu principal: ` |
| 363 | 1 Arrastre y sustentacion (6 entradas) | tests/test_flujos.lua | `submenu ` |
| 364 | 2 Vertedores y orificios (4 entradas) | tests/test_flujos.lua | `submenu ` |
| 365 | 3 Canales y medicion (4 entradas) | tests/test_flujos.lua | `submenu ` |
| 366 | 4 Coeficientes de arrastre (CD) | tests/test_flujos.lua | `catalogo: lista` |
| 367 | 5 Mis casos | tests/test_flujos.lua | `Mis casos: lista` |
| 368 | 6 Ajustes | tests/test_flujos.lua | `Ajustes (6) y MODE abren la pantalla de ajustes` |
| 369 | 7 Ayuda / Acerca de (6 entradas) | tests/test_flujos.lua | `submenu ` |
| 370 | 8 Salir | tests/test_flujos.lua | `Salir (8) termina flujos_main` |
| 371 | ESC pide confirmacion | tests/test_flujos.lua | `ESC: pregunta si desea salir` |
| 372 | ESC cancela la salida | tests/test_flujos.lua | `ESC cancela la salida` |
| 373 | ENTER confirma la salida | tests/test_flujos.lua | `ENTER confirma la salida` |
| 374 | Cada opcion de FLUJOS abre y ESC vuelve | tests/test_nav.lua | `FLUJOS opcion ` |
| 375 | Cada entrada de los submenus abre y ESC vuelve | tests/test_nav.lua | ` entrada ` |
| 376 | Entrada AR-1 Fuerza FD/FL | tests/test_flujos.lua | `AR-1: resultado FD` |
| 377 | Entrada AR-2 Velocidad terminal | tests/test_flujos.lua | `AR-01: v terminal 4.922 m/s` |
| 378 | Entrada AR-3 Estructura: varios cuerpos | tests/test_flujos.lua | `AR-3: formulario` |
| 379 | Entrada AR-4 Vuelo nivelado | tests/test_flujos.lua | `AR-04 paso 1: CL = 0.8831` |
| 380 | Entrada Placa plana y Stokes | tests/test_flujos.lua | `Canales 4: placa plana y Stokes` |
| 381 | Entrada Catalogo de coeficientes CD | tests/test_flujos.lua | `catalogo: lista` |
| 382 | Entrada VE-1,2,5 Vertedero u orificio | tests/test_flujos.lua | `VE-03: H = 0.4569 m` |
| 383 | Entrada VE-4 Estructura compuesta | tests/test_flujos.lua | `VE-01: Q total = 0.7405 m3/s` |
| 384 | Entrada VE-6 Perfil de velocidades | tests/test_flujos.lua | `VE-07: Q = 1.3333 m3/s` |
| 385 | Entrada VE-7 Aguas abajo: energia | tests/test_flujos.lua | `VE-7: memoria` |
| 386 | Entrada EX-1 Venturi y manometro | tests/test_flujos.lua | `EX-1: D2 >= D1 avisa` |
| 387 | Entrada EX-2 Salto hidraulico | tests/test_flujos.lua | `EX-02: memoria con cantidad de movimiento` |
| 388 | Entrada EX-3 Chorro desde un tubo | tests/test_flujos.lua | `EX-03: memoria con el tipo B` |
| 389 | Entrada EX-4 Placa plana y Stokes | tests/test_flujos.lua | `Canales 4: placa plana y Stokes` |
| 390 | Ayuda: arrastre, vertedores, canales, erratas | tests/test_flujos.lua | `FLUJOS: ayuda de arrastre, vertedores, canales y erratas` |
| 391 | Ayuda: erratas de la v2.0 | tests/test_flujos.lua | `erratas de la v2.0 en la ayuda` |
| 392 | Ayuda: Casos del curso (cargar) | tests/test_flujos.lua | `lista de casos: primer nombre` |
| 393 | Ayuda: Acerca de | tests/test_flujos.lua | `Ayuda 6: Acerca de` |

## 13. FLUJOS - Arrastre y sustentacion (AR-1..AR-4, Stokes)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 394 | AR-1: resultado FD | tests/test_flujos.lua | `AR-1: resultado FD` |
| 395 | AR-1: modo sustentacion FL | tests/test_flujos.lua | `AR-1: modo sustentacion` |
| 396 | AR-1: sin figura ni area avisa | tests/test_flujos.lua | `AR-1: sin figura ni area avisa` |
| 397 | AR-1: memoria | tests/test_flujos.lua | `AR-1: memoria` |
| 398 | AR-2: v terminal en aire (AR-01) | tests/test_flujos.lua | `AR-01: v terminal 4.922 m/s` |
| 399 | AR-2: memoria | tests/test_flujos.lua | `A = pi D^2/4` |
| 400 | AR-2: agua con empuje (AR-03a) | tests/test_flujos.lua | `AR-03a: A = D^2 da 1.580 m/s` |
| 401 | AR-2: guardar y recargar | tests/test_flujos.lua | `AR-2 cargado desde Mis casos da el mismo resultado` |
| 402 | AR-2: W <= B no flota (aviso) | tests/test_flujos.lua | `W < B: mensaje, sin cerrar` |
| 403 | AR-3: formulario de estructura | tests/test_flujos.lua | `AR-3: formulario` |
| 404 | AR-3: momento en la base y ycp (AR-02) | tests/test_flujos.lua | `ycp = M/F` |
| 405 | AR-3: F1 CD fuera de un cuerpo avisa | tests/test_flujos.lua | `AR-3: F1 CD fuera de un cuerpo avisa` |
| 406 | AR-3: 3 cuerpos agregan campos | tests/test_flujos.lua | `AR-3: 3 cuerpos agregan campos` |
| 407 | AR-3: F2 ESQUEMA de fuerzas | tests/test_flujos.lua | `esquema: una tecla vuelve al resultado` |
| 408 | AR-3: resize | tests/test_flujos.lua | `resize en AR-3 sin errores` |
| 409 | AR-4: CL necesario (paso 1) | tests/test_flujos.lua | `AR-04 paso 1: CL = 0.8831` |
| 410 | AR-4: empuje y D fuselaje (paso 2) | tests/test_flujos.lua | `Empuje T = 306.2` |
| 411 | AR-4: memoria | tests/test_flujos.lua | `AR-04: memoria sin plantillas` |
| 412 | Placa plana: Cf turbulento (AR-06) | tests/test_flujos.lua | `AR-06: FD turbulento 0.529 N y aviso laminar` |
| 413 | Placa plana: mixto | tests/test_flujos.lua | `AR-06: FD mixto 0.372 N` |
| 414 | Esfera Stokes: FD = 9.425E-9 N y 'Stokes valido' (Re = 1) | tests/test_flujos.lua | `AR-05: Stokes FD = 9.425E-9 N` |
| 415 | Avisos Re < 1e4 / crisis / Stokes (limite Re = 1 con tolerancia) | tests/test_core.lua | `aviso Stokes` |
| 416 | Fluido Agua llena rho y nu | tests/test_nav.lua | `AR-1: Fluido Agua llena rho y nu` |
| 417 | Fluido Manual | tests/test_nav.lua | `AR-1: Fluido Manual` |
| 418 | Fluido Aire (Ajustes) | tests/test_nav.lua | `AR-1: Fluido Aire (Ajustes) llena rho y nu del aire` |
| 419 | Velocidad en m/s | tests/test_nav.lua | `AR-1: V = 20 m/s da FD = 23.56 N` |
| 420 | Velocidad en km/h | tests/test_nav.lua | `AR-1: V = 72 km/h equivale a 20 m/s` |
| 421 | Velocidad en nudos (km/h por nudo de Ajustes) | tests/test_nav.lua | `AR-1: V en nudos` |
| 422 | Unidades de V: ciclo m/s, km/h, nudos | tests/test_nav.lua | `AR-1: unidad nudos` |
| 423 | Regimen de placa: turbulento y mixto | tests/test_flujos.lua | `AR-06: FD mixto 0.372 N` |
| 424 | Placa plana: Caras mojadas 1 vs 2 (duplica FD) | tests/test_flujos.lua | `AR-06: 2 caras mojadas duplican FD mixto (0.744 N)` |
| 425 | F1 CD abre el selector de figura | tests/test_flujos.lua | `AR-2: F1 CD abre el selector` |
| 426 | Selector: vuelve al formulario | tests/test_flujos.lua | `selector: vuelve al formulario` |

## 14. FLUJOS - Catalogo de CD (17 figuras)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 427 | Lista con miniaturas | tests/test_flujos.lua | `catalogo: miniaturas dibujadas` |
| 428 | Lista: Esfera lisa ... Placa plana larga | tests/test_flujos.lua | `catalogo: lista` |
| 429 | PERDGFX valido y 17 figuras dibujadas | tests/test_ui.lua | `17 figuras dibujadas` |
| 430 | Figura 1: Esfera lisa (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 431 | Figura 1: Esfera lisa (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 432 | Figura 2: Hemisferio convexo (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 433 | Figura 2: Hemisferio convexo (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 434 | Figura 3: Hemisferio plano (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 435 | Figura 3: Hemisferio plano (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 436 | Figura 4: Copa hemisferica hueca (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 437 | Figura 4: Copa hemisferica hueca (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 438 | Figura 5: Paracaidas (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 439 | Figura 5: Paracaidas (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 440 | Figura 6: Disco delgado (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 441 | Figura 6: Disco delgado (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 442 | Figura 7: Cono punta al flujo (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 443 | Figura 7: Cono punta al flujo (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 444 | Figura 8: Cono base al flujo (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 445 | Figura 8: Cono base al flujo (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 446 | Figura 9: Cubo cara al flujo (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 447 | Figura 9: Cubo cara al flujo (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 448 | Figura 10: Cubo arista al flujo (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 449 | Figura 10: Cubo arista al flujo (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 450 | Figura 11: Cilindro finito perpend. (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 451 | Figura 11: Cilindro finito perpend. (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 452 | Figura 12: Cilindro cara al flujo (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 453 | Figura 12: Cilindro cara al flujo (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 454 | Figura 13: Cuerpo aerodinamico (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 455 | Figura 13: Cuerpo aerodinamico (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 456 | Figura 14: Placa rectangular (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 457 | Figura 14: Placa rectangular (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 458 | Figura 15: Cilindro largo (2D) (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 459 | Figura 15: Cilindro largo (2D) (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 460 | Figura 16: Barra cuadrada larga (2D) (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 461 | Figura 16: Barra cuadrada larga (2D) (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 462 | Figura 17: Placa plana larga (2D) (nombre, CD, area, fuente, orientacion) | tests/test_flujos.lua | `": area " .. dc.area_txt` |
| 463 | Figura 17: Placa plana larga (2D) (ilustracion 3D dibujada) | tests/test_ui.lua | `"figura " .. i .. ": hay operaciones` |
| 464 | Detalle de la esfera (CD, area, Re<1) | tests/test_flujos.lua | `detalle de la esfera` |
| 465 | Tabla por L/D | tests/test_flujos.lua | `detalle: tabla por L/D` |
| 466 | Tabla por angulo | tests/test_flujos.lua | `detalle: tabla por angulo (7 puntos)` |
| 467 | Tabla por b/h | tests/test_flujos.lua | `detalle: tabla por b/h` |
| 468 | F4 TABLA: interpola | tests/test_flujos.lua | `TABLA: L/D = 15 interpola 0.9167` |
| 469 | F4 TABLA: valor infinito L/D >= 1000 | tests/test_flujos.lua | `TABLA: L/D >= 1000 usa el valor infinito 1.2` |
| 470 | F3 EDITAR: CD propio | tests/test_flujos.lua | `(catal. 0.5)` |
| 471 | DEFECTO restaura el CD del catalogo | tests/test_flujos.lua | `F1 DEFECTO restaura el valor` |
| 472 | F2 MARCAR + F3 COMPAR. | tests/test_flujos.lua | `COMPARAR: 3 figuras` |
| 473 | COMPARAR: maximo 3 figuras | tests/test_flujos.lua | `COMPARAR: maximo 3 figuras` |
| 474 | COMPARAR sin marcas avisa | tests/test_flujos.lua | `COMPARAR sin marcas avisa` |
| 475 | F4 RANKING de menor a mayor | tests/test_flujos.lua | `RANKING de menor a mayor CD` |
| 476 | F1 USAR devuelve la figura y CD | tests/test_flujos.lua | `USAR devuelve el paracaidas con CD 1.3` |
| 477 | USAR con parametro (L/D, angulo) | tests/test_flujos.lua | `cat.cat_sel_param == 30` |
| 478 | ESC devuelve -1 | tests/test_flujos.lua | `scr_cat: ESC devuelve -1` |
| 479 | Segundo clic abre la ficha | tests/test_flujos.lua | `catalogo: segundo clic abre el detalle` |
| 480 | Sin PERDGFX: aviso, sin cierre | tests/test_flujos.lua | `sin PERDGFX: aviso, sin cierre` |
| 481 | Resize en el catalogo | tests/test_flujos.lua | `resize en el catalogo sin errores` |

## 15. FLUJOS - Vertedores y orificios

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 482 | Elemento simple: triangular, H -> Q (VE-03) | tests/test_flujos.lua | `VE-03: H = 0.4569 m` |
| 483 | Elemento simple: memoria (Q/K)^(2/5) | tests/test_flujos.lua | `(Q/K)^(2/5)` |
| 484 | Elemento simple: dado Q da H (VE-05) | tests/test_flujos.lua | `VE-05: H = 0.2072 m` |
| 485 | Rectangular: aviso de Francis | tests/test_flujos.lua | `vertedero rectangular: aviso de Francis` |
| 486 | Orificio circular: carga parcial (H < d/2) | tests/test_flujos.lua | `orificio con H < d/2: aviso de carga parcial` |
| 487 | Orificio rectangular: falta alto a | tests/test_flujos.lua | `orificio rectangular: falta el alto a` |
| 488 | Cota de la cresta (VE-08): h0 | tests/test_flujos.lua | `h0 = h - H = 0.0241` |
| 489 | Estructura compuesta: nivel -> Q (VE-01) | tests/test_flujos.lua | `VE-01: Q total = 0.7405 m3/s` |
| 490 | Estructura compuesta: memoria con 'cantidad x' | tests/test_flujos.lua | `2 Orificio circ. x3` |
| 491 | Estructura compuesta: Q -> nivel (VE-02) | tests/test_flujos.lua | `VE-02: h = 1.829 m` |
| 492 | Estructura compuesta: tabla de biseccion | tests/test_flujos.lua | `VE-4: la tabla de biseccion esta en la memoria` |
| 493 | Estructura compuesta: reparto (VE-06) | tests/test_flujos.lua | `Q=0.02288` |
| 494 | Estructura compuesta: F2 ESQUEMA | tests/test_flujos.lua | `VE-01: esquema` |
| 495 | Perfil de velocidades v = k y^n (VE-07) | tests/test_flujos.lua | `VE-07: Q = 1.3333 m3/s` |
| 496 | Perfil por tabla de puntos (Simpson) | tests/test_flujos.lua | `VE-07: Q por puntos (Simpson) = 1.3333` |
| 497 | Perfil: la memoria dice Simpson | tests/test_flujos.lua | `VE-07: la memoria dice Simpson` |
| 498 | Perfil: y no creciente avisa | tests/test_flujos.lua | `VE-07: y no creciente: mensaje` |
| 499 | Aguas abajo: v1, E, Fr y alternos | tests/test_flujos.lua | `VE-7: memoria` |
| 500 | Aguas abajo: solo seccion 1 | tests/test_flujos.lua | `VE-7: solo seccion 1` |

## 16. FLUJOS - Canales y medicion

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 501 | Venturi: dp y h manometro fisico (EX-01a) | tests/test_flujos.lua | `dp = p1 - p2 = 3266` |
| 502 | Venturi: convencion del examen (S g h) | tests/test_flujos.lua | `h manometro = 0.8323` |
| 503 | Venturi: memoria | tests/test_flujos.lua | `dp/(S gamma)` |
| 504 | Venturi: D2 >= D1 avisa | tests/test_flujos.lua | `D2 >= D1 avisa` |
| 505 | Salto hidraulico dado y1 (EX-02) | tests/test_flujos.lua | `EX-02: memoria con cantidad de movimiento` |
| 506 | Salto: Fr1 <= 1 sin salto | tests/test_flujos.lua | `EX-02: Fr1 <= 1, sin salto: mensaje` |
| 507 | Salto dado y2 | tests/test_flujos.lua | `EX-02: dado y2 vuelve y1 = 0.4 m` |
| 508 | Salto dado y2 supercritico: Fr2 | tests/test_flujos.lua | `EX-02: dado y2 supercritico: mensaje Fr2` |
| 509 | Chorro desde un tubo (EX-03a) | tests/test_flujos.lua | `> Alcance R = 3.40` |
| 510 | Chorro con energia de salida (EX-03b) | tests/test_flujos.lua | `EX-03b: con salida Q = 3.899 l/s` |
| 511 | Chorro: memoria con el tipo B | tests/test_flujos.lua | `EX-03: memoria con el tipo B` |
| 512 | Placa plana y Stokes (EX-4) | tests/test_flujos.lua | `Canales 4: placa plana y Stokes` |

## 17. FLUJOS - Casos del curso (17) y Mis casos

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 513 | Caso AR-01 Paracaidista (T4-2 P1): resultado | tests/test_flujos.lua | `: falta [` |
| 514 | Caso AR-01 Paracaidista (T4-2 P1): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 515 | Caso AR-02 Torre y tanque (T4-2 P4): resultado | tests/test_flujos.lua | `: falta [` |
| 516 | Caso AR-02 Torre y tanque (T4-2 P4): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 517 | Caso AR-03 Cubo en agua (T4-2 P5): resultado | tests/test_flujos.lua | `: falta [` |
| 518 | Caso AR-03 Cubo en agua (T4-2 P5): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 519 | Caso AR-04 Avion A-330 (2017 P2): resultado | tests/test_flujos.lua | `: falta [` |
| 520 | Caso AR-04 Avion A-330 (2017 P2): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 521 | Caso AR-05 Esfera en flujo lento (Stokes): resultado | tests/test_flujos.lua | `: falta [` |
| 522 | Caso AR-05 Esfera en flujo lento (Stokes): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 523 | Caso AR-06 Placa plana en aire: resultado | tests/test_flujos.lua | `: falta [` |
| 524 | Caso AR-06 Placa plana en aire: memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 525 | Caso VE-01 Triang. + 3 orificios (2024 P5a): resultado | tests/test_flujos.lua | `: falta [` |
| 526 | Caso VE-01 Triang. + 3 orificios (2024 P5a): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 527 | Caso VE-02 Nivel con 0.5 m3/s (2024 P5b): resultado | tests/test_flujos.lua | `: falta [` |
| 528 | Caso VE-02 Nivel con 0.5 m3/s (2024 P5b): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 529 | Caso VE-03 Triangular, 200 l/s (2025 P4a): resultado | tests/test_flujos.lua | `: falta [` |
| 530 | Caso VE-03 Triangular, 200 l/s (2025 P4a): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 531 | Caso VE-04 Triang., 260.64 l/s (2025 P4b): resultado | tests/test_flujos.lua | `: falta [` |
| 532 | Caso VE-04 Triang., 260.64 l/s (2025 P4b): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 533 | Caso VE-05 Triang. 60, 16 l/s (T4-2 P2a): resultado | tests/test_flujos.lua | `: falta [` |
| 534 | Caso VE-05 Triang. 60, 16 l/s (T4-2 P2a): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 535 | Caso VE-06 Reparto 36 l/s (T4-2 P2b): resultado | tests/test_flujos.lua | `: falta [` |
| 536 | Caso VE-06 Reparto 36 l/s (T4-2 P2b): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 537 | Caso VE-07 Perfil v = 2 y^2 (T4-2 P3a): resultado | tests/test_flujos.lua | `: falta [` |
| 538 | Caso VE-07 Perfil v = 2 y^2 (T4-2 P3a): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 539 | Caso VE-08 Cota de la cresta (T4-2 P3b): resultado | tests/test_flujos.lua | `: falta [` |
| 540 | Caso VE-08 Cota de la cresta (T4-2 P3b): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 541 | Caso EX-01 Venturi (2025 P4c): resultado | tests/test_flujos.lua | `: falta [` |
| 542 | Caso EX-01 Venturi (2025 P4c): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 543 | Caso EX-02 Salto hidraulico (2017 P3): resultado | tests/test_flujos.lua | `: falta [` |
| 544 | Caso EX-02 Salto hidraulico (2017 P3): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 545 | Caso EX-03 Chorro desde un tubo (2025): resultado | tests/test_flujos.lua | `: falta [` |
| 546 | Caso EX-03 Chorro desde un tubo (2025): memoria sin plantillas | tests/test_flujos.lua | `: memoria sin plantillas (` |
| 547 | 17 casos del curso en la lista | tests/test_flujos.lua | `17 casos del curso en la lista` |
| 548 | Presets AR/VE/EX a su pantalla | tests/test_flujos.lua | `preset AR-01 -> AR-2` |
| 549 | Mis casos: 12 tipos distintos | tests/test_flujos.lua | `Mis casos: 12 casos de tipos distintos` |
| 550 | Mis casos: cargar cada caso | tests/test_flujos.lua | `carga y calcula` |
| 551 | Mis casos: on.save/on.restore | tests/test_flujos.lua | `on.restore recupera los 12 casos` |
| 552 | Mis casos: copia profunda y rechazo de datos invalidos | tests/test_flujos.lua | `load: rechaza datos invalidos` |

## 18. Nucleo numerico (golden, aleatorios, secante)

| # | Item v2.1 | Prueba | Asercion |
|---|---|---|---|
| 553 | Casos dorados (todos) | tests/test_core.lua | `1. GOLDEN` |
| 554 | Aleatorios 1 (750 filas) | tests/test_core.lua | `2. ALEATORIOS` |
| 555 | Aleatorios 2 (625 filas) | tests/test_core.lua | `3. ALEATORIOS` |
| 556 | Secante y arranque HW | tests/test_core.lua | `4. SECANTE` |
| 557 | Datos consistentes | tests/test_core.lua | `6. DATOS` |

Total: 557 filas, 0 sin cobertura.
