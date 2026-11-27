# Plan de ampliación: ejercicios de exámenes IC-605 (versión Nspire 1.1)

Rama `ampliacion-examenes`. Solo se toca `TI-Nspire CX II CAS/`. Las soluciones
de referencia están en `tools/oracle_examenes.py` (Python, double); la app debe
reproducirlas con un error de 0,1 % como máximo.

## 1. Ejercicios y cobertura

Clave: **Y** la app ya lo resuelve · **A** hay que ampliar una pantalla existente · **N** hace falta una pantalla nueva.

| Examen / ejercicio | Tema | Ref. (oráculo) | Cob. | Dónde |
|---|---|---|---|---|
| Vertedores P4 a,c | 2 tanques, orificio + vertedor rect. | HA 3,1628; HB 2,2068; Qlím 288,44 l/s | N | VE-8 Tanques acoplados |
| Parcial2-2025 P3 a,b | 2 tanques, orificios + vert. rect./tri. | QE 146,6 / 4685 l/s (la hoja: 4584,7, error de suma) | N | VE-8 |
| Final-2025 P1 a,b | Diámetro de diseño, ΣK=12,8 | D 256,8 mm; Q(285,75) 262,4 l/s | Y | Tubería tipo D / B |
| Final-2025 P2 a,b | hf, válvula Kv | hf 39,52; hv 30,14; Kv 60,79 | Y | Tipo A / F |
| Final-2025 P3 a,b | Turbina 65 %, bomba 60 % | 59,1/38,4 kW; HB 121,86 m, 398,5 kW | Y | Tipo C |
| Final-2025 P4 a,b | Vertedor tri. 90°: H | 0,4569 / 0,5079 m | Y | VE-2 |
| Final-2025 P4 c | Venturi, Q→ΔP, h (S=4) | ΔP 56,2 kPa; h 1,910 m (la hoja usa Q de 200 l/s y 4γ) | Y | EX-1 (verificar el sentido Q→h) |
| Final-2025 P5 | A‖B + C, f fijo | 39,88 / 11,65 / 51,53 l/s | Y | Sistemas (f fijo) |
| Final-2025 chorro | Chorro desde tubo con fricción | Q 3,90 l/s (con v²/2g de salida) | Y | EX-3 |
| EPSON P1 a,b; P1-2024 | Cojinete: T, ω, potencia | 1,0528 N·m; 94,99 rpm; 103,35 W | N | E1 Viscosidad |
| P1-2018 P4 | Placa entre placa fija y placa móvil | F 0,648 N; y0 0,6 mm | N | E1 |
| P1-2022 P1; P1-2017 P3 | Bloque en rampa con aceite / fricción seca | 64,17; 60,98; 105,46 N | N | E1 |
| P1-2018 P3; P1-2017 P1 | Manometría en serie | 55,57 kPa; d 28,02 mm | N | E2 Manometría |
| EPSON P2 (1,2,3) | Encofrado: placas vertical, inclinada, compuesta | 165 544; 1 089 587; 293 278 N | N | E3 Superficies planas |
| P1-2022 P2 | Compuerta circular inclinada | F 146 452 N; yp 3,568 m | N | E3 |
| P1-2017 P2 plana | Compuerta 45°, reacción | 0,6036 γl²w; RA 0,3607 γl²w | N | E3 (momento respecto a la bisagra) |
| P1-2018 P2 | Compuerta en L, incógnita H | H 2,0902 m | N | E3 (modo compuerta en L) |
| EPSON P3 b; P1-2022 P3; P1-2017 P2 curva | Cuarto de círculo | F 875 738 N; 53 828 N 41,96°; 59 523 N 47,75° | N | E4 Superficies curvas |
| EPSON P3 a | Semicilindro con pernos | 3721,1 N/perno | N | E4 |
| EPSON P4 a,b | Cilindro hueco flotante | GM −0,0224 (inestable); con H=3e calado 0,957 > H: se hunde | N | E5 Flotación |
| P1-2018 P1 | Prisma triangular, S 0,7 / 0,3 | h 0,502 (vértice abajo) / 0,0980 (vértice arriba) | N | E5 |
| P1-2022 P4 | Barcaza rect. + quilla triangular | ρ 800; GM 0,2475 | N | E5 |
| P1-2017 P4 | Cubo plano / girado 45° | GM −0,0833 / +0,2357 (la hoja usa otras I) | N | E5 |
| EPSON P5 b | Recipientes en polea | ay 1,962; P 2354,4 Pa | N | E6 Equilibrio relativo |
| P1-2018 P5; P1-2022 P5 | Aceleración horizontal | Pmax 146,93 kPa; PB 2652, PC 12 581 Pa; a 6,54 | N | E6 |
| EPSON P5 a; P2-2024 P4 a; Varios parabólico | Perfil de velocidades | Q 5,333; 1,3333; 0,12566; α 2, β 4/3; Re 662 032 | N | D1 Perfiles |
| P2-2024 P4 b,c | Vertedor tri. + tirante alterno | H 0,9758; h1 0,16226; v 4,109 | Y | VE-2 / VE-7 |
| Varios Ej1 | Manguera y boquilla | Q 2,4e-4; 2,122 / 12,223 m/s | N | D2 Continuidad y Bernoulli |
| P2-2025 P1 | Aire, reducción, manómetro de agua | ΔP 134,09 Pa; h 13,68 mm | N/Y | D2 (o EX-1 con S = ρw/ρa) |
| P2-2024 P2 | Descarga libre, presiones A–D | 16,50 l/s; 58 424; −436; −15 151; 34 880 Pa | N | D2 (puntos) |
| P2-2024 P3 | Codo reductor 45°, anclajes | p2 −16 372 Pa; Rx 468,3; Ry 42,25 N; R 470,2 | N | D3 Cantidad de movimiento |
| P2-2025 P5 | Flyboard (chorros que sostienen un peso) | V2 11,82; Q 0,04642; P0 120,8 kPa; HB 13,62; 6,45 kW | N | D3 |
| P2-2025 P4 | Potencia de arrastre de autos | 11,20/10,89 kW; 4,725/4,594 kW | A | AR-1 + potencia P = FD·V |
| P2-2024 P5 | Pelota de tenis, Magnus | ωD/2V 0,4705; W 0,5886; FB 0,00176; FL 0,300 N (CL 0,12) | A | AR-5 Balance vertical |
| P2-2024 P1; P2-2025 P2 | Tanque con Qe y Qs(t) | y(90) 3,803 m, v 3,252; t 2460,6 s (la hoja: 2480,5) | N | D4 Tanques no permanentes |
| Varios Ej2; tanque 3 m; tanque 5 m | Vaciado por orificio o tubo | 18,70 s; 110,7 y 78,27 l/s; 885,1 s; con Qe=0,1 no se vacía (equilibrio 1,632 m) | N | D4 |

## 2. Arquitectura

* Menú principal: nueva entrada **"Estatica y dinamica"** (índice 4; las siguientes se corren) que abre `scr/fluidos.lua`
  con dos submenús: ESTATICA (E1–E6) y DINAMICA (D1–D4), más Casos del curso.
* Motores nuevos, puros y sin UI (convención: `err` primero, SI, salidas en tablas):
  * `core/statics.lua`: viscosidad, manometría, superficies planas y curvas, flotación y equilibrio relativo.
  * `core/dyn.lua`: perfiles (Simpson sobre una ley de potencia o una expresión), continuidad, Bernoulli, cantidad de movimiento e integración de tanques (RK4 y bisección).
  * `core/weir.lua` gana `weir_tanks(...)`, una red de 2 tanques construida con los elementos de `weir_q`. La incógnita es el nivel aguas abajo H2; se resuelve por bisección y explícitamente hacia aguas arriba.
* Pantallas nuevas:
  * `scr/scr_stat.lua` (E1–E6) y `scr/scr_dyn.lua` (D1–D4), con el mismo patrón que `scr_chan.lua`/`scr_weir.lua`: tabla de estado, `W.form_run`, `compute()`, resumen y memoria.
  * VE-8 en `scr_weir.lua`; AR-5 y la potencia de AR-1 en `scr_drag.lua`.
* **Memoria de cálculo**: las memorias nuevas se escriben en Lua con la API de `ui/memo.lua`
  (`memo_begin/sec/data/eq/res/line/warn/table`). No se toca el PERDTXT generado desde el C de TI-84.
  Cada paso es una ecuación con la fórmula, la sustitución numérica y el resultado con su unidad.
  Si hay iteraciones (bisección o RK4), se muestra una tabla. Mismo aspecto y formato numérico (Ajustes) que las memorias actuales.
* Casos: tipos guardables nuevos registrados con `C.register`, sin romper los casos guardados (`store` ver=3 debe seguir leyendo).
  Se agregan casos precargados del curso con los datos de cada examen (p. ej. "EX18-P4").
* Expresiones de usuario, por ejemplo Qs(t) y v(y): se reutiliza `ui/expr.lua`.

## 3. Reparto (Sonnet implementa; los archivos no se pisan)

1. **S1 Estática**: `core/statics.lua`, `scr/scr_stat.lua` y `tests/test_statics.lua`.
2. **S2 Dinámica**: `core/dyn.lua`, `scr/scr_dyn.lua` y `tests/test_dyn.lua`.
3. **S3 Integración y ampliaciones**: VE-8 (`core/weir.lua`, `scr_weir.lua`), AR-1/AR-5 (`core/drag.lua`, `scr_drag.lua`),
   `scr/fluidos.lua`, el menú de `screens.lua`, `cases.lua`, `store.lua`, los casos del curso, `README_es.md`, la versión 1.1 y
   `tests/test_examenes.lua` (casos Y del oráculo con los motores existentes).

## 4. Verificación

`tools/run_tests.sh` (Lua 5.1) con todas las suites en verde, y `tests/test_examenes.lua` con cada valor de la tabla dentro del 0,1 %.
Después, `build.py` genera `instalacion/PerdidasFlujos.tns` (requiere Luna).
