# Informe de pruebas: app de pérdidas en tuberías (TI-84 Plus CE)

## Fase 0: entorno e hito H0 (6 de noviembre de 2026)

### Entorno verificado con comandos

| Componente | Estado | Detalle |
|---|---|---|
| Python | instalado | 3.14.3 (sin `scipy`; el oráculo usará Colebrook-White propio en doble precisión) |
| Git | instalado | 2.53.0 |
| WSL | Ubuntu (WSL 2) presente | sin `gcc` ni `make`; no se usa |
| TI Connect CE | instalado | `C:\Program Files\TI Education` |
| CE C/C++ Toolchain | **instalado por Claude** | v15.0 (clang 19.1.0 para eZ80) en `C:\CEdev`; incluye `cemu-autotester.exe` |
| CEmu | **descargado por Claude** | v2.0 (`CEmu-v2.0_win64_Qt6.exe`) y nightly (`CEmu-nightly_win-x64-msvc.exe`) en `C:\dev\tools\CEmu\` |
| gcc para el PC | **instalado por Claude** | 16.2.0 (WinLibs POSIX UCRT, vía `winget`) |
| arTIfiCE | **descargado por Claude** | v2.1 (`arTIfiCE_v2.1.8xp`, 978 bytes) en `C:\dev\downloads\artifice\` |

Orígenes: CEdev de `github.com/CE-Programming/toolchain/releases/tag/v15.0`; CEmu de `github.com/CE-Programming/CEmu/releases` (v2.0 y nightly); gcc con `winget install BrechtSanders.WinLibs.POSIX.UCRT`; arTIfiCE de `github.com/YvanTT/arTIfiCE/releases/tag/v2.1` (enlace de la página oficial `yvantt.github.io/arTIfiCE`). Se agregó `C:\CEdev\bin` al PATH del usuario.

### Compilación desde ruta sin espacios

- Código real: `Fluidos\App_TI84_Perdidas\` (OneDrive). Unión de directorio: `C:\dev\ti84` hacia esa carpeta. Se compila siempre desde `C:\dev\ti84`.
- Carpeta marcada como «Mantener siempre en este dispositivo» (`attrib +P /S /D`).
- `OBJDIR` absoluto o fuera del árbol **no funciona** con el makefile de CEdev v15.0 (`ez80-link.exe: invalid argument` y `No rule to make target _../_../...`). Solución: `obj/` es una unión hacia `C:\dev\build\<proyecto>\obj`, así los temporales quedan fuera de OneDrive.

### Hito H0

| Prueba | Resultado |
|---|---|
| Compilar `h0/` con `make` desde `C:\dev\ti84\h0` | **pasa**: `bin/HOLAH0.8xp`, 580 bytes |
| Ejecutar H0 en CEmu (ROM de Adrián, OS 5.8.4) | **pasa** con arTIfiCE v2.1 dentro del emulador (12 de noviembre de 2026); sin arTIfiCE da «ERROR: INVALID» |
| Ejecutar H0 en la calculadora real (OS 5.8.4.0058 con arTIfiCE v2.1) | **pasa** (lo verificó Adrián el 6 de noviembre de 2026, lanzando `HOLAH0` desde el menú de arTIfiCE) |

### arTIfiCE y la 5.8.4.0058

- La página oficial dice que la v2.1 soporta el OS «hasta la v5.8.4» y la v3 solo la 5.8.5. Para la 5.8.4.0058 corresponde la **v2.1**.
- La página solo habla de programas en ensamblador. H0 confirmó en la calculadora real que **un programa en C de CEdev v15.0 corre en la 5.8.4.0058 con arTIfiCE v2.1**.
- Comportamiento de CEmu con el ROM 5.8.4: **bloquea los programas nativos** igual que la calculadora («ERROR: INVALID»). Para probar se envía `arTIfiCE_v2.1.8xp` al emulador, se lanza `prgmA` y desde su menú «arTIfiCE SHELL 2.1» se ejecuta el programa. Así funcionan todas las pruebas de CEmu.

### Respuestas de Adrián (tanda única, 6 de noviembre de 2026)

| # | Pregunta | Respuesta | Decisión de implementación |
|---|---|---|---|
| 1 | Modelo | TI-84 Plus CE normal | arTIfiCE v2.1 |
| 2 | $\nu$ por defecto | la propuesta | $\nu = 1{,}0\times10^{-6}$ m²/s, editable y con selector de temperatura |
| 3 | $k_s$ del PEAD (Tarea 4 P1) | irrelevante | el caso P-23 sale de la batería de pruebas |
| 4 | Método de $f$ | Colebrook-White | CW por defecto; SJ, Haaland y Goudar-Sonnad como opción |
| 5 | Pérdidas locales | calcularlas siempre | siempre se suman; aviso «despreciables» si $L/D > 4000$ |
| 6 | Fuente con símbolos | le da igual | ASCII (`nu`, `gamma`, `SumK`) en la primera versión |
| 7 | Nombre e ícono | «Perdidas», acepta el ícono | programa `PERDIDAS`; ícono 16×16 de tubo con gota |
| 8 | Funciones secundarias / presión de vapor | modificable en configuración | presión de vapor editable en Ajustes (por defecto 2339 Pa, 20 °C) |
| 9 | Decimales | 6 | 6 decimales por defecto (ajustable); notación científica para valores muy grandes o pequeños |
| 10 | Módulos futuros | no, solo pérdidas | apéndice A descartado |

## Fase 1: motor en C puro y pruebas del PC (6 de noviembre de 2026)

### Qué se construyó

- `src/hydro/hydro.h` y `hydro.c`: motor en C99 puro, sin dependencias de la calculadora. Tipo `real` = `float` (como en el eZ80) o `double` con `-DHYDRO_USE_DOUBLE`. Funciones: factor de fricción (laminar, Colebrook-White, Swamee-Jain, Haaland, Goudar-Sonnad), tipo A (pérdidas dado $Q$), B (caudal máximo: iteración del curso y respaldo por bisección sobre $v$), C (bomba y turbina, potencia neta y bruta), D (diámetro por bisección geométrica sobre $D$, diámetro comercial, $Q_{\max}$ con el comercial, $v_p$), E (calibración de $f$ y $k_s$), F (válvula de control), I (Hazen-Williams), presión en un punto y G (árbol serie-paralelo con módulos $M$, hacia adelante y hacia atrás, $f$ dado o automático).
- Todas las iteraciones tienen tope: Colebrook-White 60 vueltas, iteración del curso 200, bisecciones 200 y búsqueda del intervalo 40 duplicaciones, red con $f$ automático 50 vueltas. Ninguna división sin validar el divisor.
- `tests/golden_table.h` (tabla de 198 comprobaciones de la sección 9), `tests/golden.c` (ejecutor), `tools/oracle.py` (oráculo en Python, doble precisión, Newton para Colebrook-White y bisección de 300 pasos), `tests/random_check.c` y `tools/run_pc_tests.sh`.
- Compilación del motor en el PC con `-Wall -Wextra -Werror -Wdouble-promotion` y, en `float`, `-fsingle-precision-constant`: ninguna cuenta del motor se hace en `double` sin que el compilador avise.

### Regla de aprobación de los casos dorados

$$|x_{obt} - x_{esp}| \le \max\left(0{,}001\,|x_{esp}|,\ \text{tol}_{abs}\right) \Rightarrow \textbf{pasa}$$

con $\text{tol}_{abs} = 0{,}0001$ para $f$ y tolerancia propia del 1 % para P-08. Si no se cumple, pero la diferencia es menor que media unidad de la última cifra con que la fuente imprime el valor ($0{,}5\times10^{-d}$), el resultado es **pasa (r)**: el valor esperado solo se conoce con esa precisión (por ejemplo, $h_m = 1{,}79$ m frente a 1,7937 m). En cualquier otro caso, **falla**. La tolerancia no se cambió para ningún caso.

### Cambios a los casos de la memoria, justificados con los PDF

| Caso | Memoria | PDF | Cambio |
|---|---|---|---|
| P-06 | «converge por la iteración del curso» | el manuscrito de 2018 P1b resolvió por bisección sobre $h_f$ (6 tanteos) | se quitó la comprobación del método. La iteración del curso sí converge, pero oscilando: 116 vueltas para $10^{-5}$ m |
| P-07 y R-01 | $L = 2$ m | el manuscrito de 2018 P1a usa $L = 2{,}06$ m y llega a $v = 2{,}9$ m/s con $h_T = 5{,}001$ | se usa $L = 2{,}06$ m. Con 2 m da $Q = 5{,}699$ l/s (+0,16 %, sobre el 0,1 %); con 2,06 m da 5,693 l/s. Confirmada la errata «56,9 l/s» del manuscrito |
| P-11 | $P = 28{,}9$ kW $= 38{,}7$ Hp con $\gamma = 9810$ | la hoja (diapositiva 25) da $P = 28\,894{,}18$ W, que implica $\gamma \approx 9801$ N/m³ ($\rho = 999{,}1$ kg/m³ a 15 °C, coherente con $\nu = 1{,}14\times10^{-6}$) | la prueba usa $\gamma = 999{,}1\times9{,}81$ y los valores de la hoja con todas sus cifras. Con $\gamma = 9810$ salen 28,92 kW y 38,78 Hp (+0,09 % y +0,21 %) |
| Colebrook-White | se arranca con $f_1 = 0{,}001$ | la hoja de la diapositiva 25 arranca con $f_1 = 0{,}0001$ | el motor arranca con $0{,}0001$ (el resultado no cambia) |
| P-23 | dos variantes de $k_s$ | — | fuera de la batería por decisión de Adrián |

### Resultados de los casos dorados en el PC

`float`: **191 pasan, 7 pasan (r), 0 fallan**. `double`: el mismo resultado. La tabla de abajo es la corrida en `float` (como la calculadora).

| Caso | Magnitud | Esperado | Obtenido | Error rel. | Resultado |
|---|---|---|---|---|---|
| P-01 | v [m/s] | 2.29 | 2.291831 | +0.080 % | pasa |
| P-01 | Re | 455180 | 455179.9 | -0.000 % | pasa |
| P-01 | f SJ | 0.01343 | 0.0134277 | -0.017 % | pasa |
| P-01 | f CW | 0.01349 | 0.01348743 | -0.019 % | pasa |
| P-01 | hf SJ [m] | 17.97 | 17.97372 | +0.021 % | pasa |
| P-01 | hf CW [m] | 18.05 | 18.05367 | +0.020 % | pasa |
| P-01 | hf HW [m] | 19.32 | 19.32015 | +0.001 % | pasa |
| P-01 | error HW vs SJ [%] | 7.5 | 7.491104 | -0.119 % | pasa (r) |
| P-02 | hm [m] | 1.79 | 1.793664 | +0.205 % | pasa (r) |
| P-02 | hT SJ [m] | 19.76 | 19.76738 | +0.037 % | pasa |
| P-02 | p/gamma [m] | 32.97 | 32.96491 | -0.015 % | pasa |
| P-02 | p/gamma sin hm [m] | 34.76 | 34.75857 | -0.004 % | pasa |
| P-03 | Q [l/s] | 318.8 | 318.8204 | +0.006 % | pasa |
| P-03 | v [m/s] | 4.73 | 4.728473 | -0.032 % | pasa |
| P-03 | f | 0.01117 | 0.0111642 | -0.052 % | pasa |
| P-03 | hf [m] | 30.4 | 30.3949 | -0.017 % | pasa |
| P-03 | hm [m] | 13.1 | 13.10511 | +0.039 % | pasa |
| P-03 | metodo (1 curso) | 1 | 1 | +0.000 % | pasa |
| P-04 | Q [l/s] | 531.3 | 531.2959 | -0.001 % | pasa |
| P-04 | v [m/s] | 4.42 | 4.424794 | +0.108 % | pasa (r) |
| P-04 | f | 0.01079 | 0.0107882 | -0.017 % | pasa |
| P-04 | hf [m] | 117 | 117.0168 | +0.014 % | pasa |
| P-04 | hm [m] | 7.98 | 7.983201 | +0.040 % | pasa |
| P-05 | Q [l/s] | 2104 | 2104.088 | +0.004 % | pasa |
| P-05 | v [m/s] | 2.43 | 2.429939 | -0.003 % | pasa |
| P-05 | f | 0.01143 | 0.01142938 | -0.005 % | pasa |
| P-05 | hf [m] | 77.89 | 77.89335 | +0.004 % | pasa |
| P-05 | hm [m] | 2.11 | 2.106637 | -0.159 % | pasa (r) |
| P-06 | Q [l/s] | 15.9 | 15.89288 | -0.045 % | pasa |
| P-06 | v [m/s] | 8.09 | 8.094177 | +0.052 % | pasa |
| P-07 | Q [l/s] | 5.69 | 5.692726 | +0.048 % | pasa |
| P-07 | v [m/s] | 2.9 | 2.899282 | -0.025 % | pasa |
| P-07 | metodo (2 biseccion) | 2 | 2 | +0.000 % | pasa |
| P-08 | Q [l/s] | 131 | 131.1162 | +0.089 % | pasa |
| P-09 | Q [l/s] | 211.97 | 211.9732 | +0.002 % | pasa |
| P-09 | v [m/s] | 3 | 2.998807 | -0.040 % | pasa |
| P-09 | hf [m] | 97.71 | 97.70824 | -0.002 % | pasa |
| P-09 | hm [m] | 2.29 | 2.291754 | +0.077 % | pasa |
| R-01 | metodo (2 biseccion) | 2 | 2 | +0.000 % | pasa |
| R-01 | aviso de respaldo | 1 | 1 | +0.000 % | pasa |
| R-01 | Q [l/s] | 5.69 | 5.692726 | +0.048 % | pasa |
| P-10 | Q HW [l/s] | 195.46 | 195.4561 | -0.002 % | pasa |
| P-10 | diferencia [%] | -7.8 | -7.792057 | +0.102 % | pasa (r) |
| P-11 | v [m/s] | 2.376714 | 2.376714 | -0.000 % | pasa |
| P-11 | Re | 312725.5 | 312725.5 | -0.000 % | pasa |
| P-11 | f | 0.014458 | 0.01445797 | -0.000 % | pasa |
| P-11 | hf [m] | 26.918 | 26.91797 | -0.000 % | pasa |
| P-11 | hm [m] | 2.7063417 | 2.706341 | -0.000 % | pasa |
| P-11 | H [m] | 45.6243 | 45.62431 | +0.000 % | pasa |
| P-11 | P [kW] | 28.8942 | 28.89417 | -0.000 % | pasa |
| P-11 | P [Hp] | 38.7413 | 38.74772 | +0.017 % | pasa |
| P-12 | v [m/s] | 2.387 | 2.387324 | +0.014 % | pasa |
| P-12 | hf [m] | 20.33 | 20.33395 | +0.019 % | pasa |
| P-12 | HB [m] | 122.33 | 122.334 | +0.003 % | pasa |
| P-12 | Pn [kW] | 90 | 90.0072 | +0.008 % | pasa |
| P-12 | Pb [kW] | 105.9 | 105.8908 | -0.009 % | pasa |
| P-13 | v [m/s] | 7.958 | 7.957747 | -0.003 % | pasa |
| P-13 | Re | 316097 | 316097.2 | +0.000 % | pasa |
| P-13 | f CW | 0.02106 | 0.02106272 | +0.013 % | pasa |
| P-13 | hf [m] | 1360 | 1359.646 | -0.026 % | pasa |
| P-13 | HB [m] | 1430 | 1429.646 | -0.025 % | pasa |
| P-13 | Pn [kW] | 140.3 | 140.2482 | -0.037 % | pasa |
| P-13 | Pb [kW] | 165 | 164.9979 | -0.001 % | pasa |
| P-14 | v [m/s] | 1.415 | 1.414711 | -0.020 % | pasa |
| P-14 | Re | 212207 | 212206.6 | -0.000 % | pasa |
| P-14 | f | 0.01554 | 0.01554219 | +0.014 % | pasa |
| P-14 | hf [m] | 13.74 | 13.74043 | +0.003 % | pasa |
| P-14 | hm [m] | 0.51 | 0.5100423 | +0.008 % | pasa |
| P-14 | HB [m] | 54.25 | 54.25047 | +0.001 % | pasa |
| P-14 | Pn [kW] | 13.3 | 13.30493 | +0.037 % | pasa |
| P-14 | Pb [kW] | 22.17 | 22.17488 | +0.022 % | pasa |
| P-15 | D exacto [mm] | 329.1 | 329.1185 | +0.006 % | pasa |
| P-15 | D comercial [mm] | 350 | 350 | -0.000 % | pasa |
| P-15 | Qmax [l/s] | 234.23 | 234.2301 | +0.000 % | pasa |
| P-15 | hm/hf [%] | 10.42 | 10.42436 | +0.042 % | pasa |
| P-16a | D exacto [mm] | 385.6 | 385.5804 | -0.005 % | pasa |
| P-16a | D comercial [mm] | 400 | 400 | +0.000 % | pasa |
| P-16a | Qmax [l/s] | 329.9 | 329.9219 | +0.007 % | pasa |
| P-16b | D exacto [mm] | 375 | 374.9735 | -0.007 % | pasa |
| P-16b | D comercial [mm] | 400 | 400 | +0.000 % | pasa |
| P-16b | Qmax [l/s] | 354.8 | 354.8249 | +0.007 % | pasa |
| P-17 | D exacto CW [mm] | 256.83 | 256.8315 | +0.001 % | pasa |
| P-17 | D exacto SJ [mm] | 256.73 | 256.7299 | -0.000 % | pasa |
| P-17 | D comercial [mm] | 285.75 | 285.75 | +0.000 % | pasa |
| P-17 | Qmax 285.75 [l/s] | 262.4 | 262.3841 | -0.006 % | pasa |
| P-17 | Qmax 285.00 [l/s] | 260.64 | 260.6394 | -0.000 % | pasa |
| P-17 | v 285.00 [m/s] | 4.086 | 4.085643 | -0.009 % | pasa |
| P-17 | hf 285.00 [m] | 65.11 | 65.10989 | -0.000 % | pasa |
| P-17 | hm 285.00 [m] | 10.89 | 10.8901 | +0.001 % | pasa |
| P-18 | v [m/s] | 3.119 | 3.118657 | -0.011 % | pasa |
| P-18 | Re | 891156 | 891156.2 | +0.000 % | pasa |
| P-18 | f CW | 0.011989 | 0.01198944 | +0.004 % | pasa |
| P-18 | f SJ | 0.011958 | 0.01195783 | -0.001 % | pasa |
| P-18 | hf [m] | 39.52 | 39.5187 | -0.003 % | pasa |
| P-18 | hm [m] | 6.35 | 6.345212 | -0.075 % | pasa |
| P-18 | hT [m] | 45.87 | 45.86391 | -0.013 % | pasa |
| P-18 | hv [m] | 30.13 | 30.13609 | +0.020 % | pasa |
| P-18 | Kv | 60.8 | 60.79261 | -0.012 % | pasa |
| P-19 | HT [m] | 30.13 | 30.13609 | +0.020 % | pasa |
| P-19 | Pb [kW] | 59.1 | 59.12702 | +0.046 % | pasa |
| P-19 | Pn [kW] | 38.4 | 38.43256 | +0.085 % | pasa |
| P-20 | HB [m] | 121.87 | 121.8639 | -0.005 % | pasa |
| P-20 | Pn [kW] | 239.1 | 239.097 | -0.001 % | pasa |
| P-20 | Pb [kW] | 398.5 | 398.495 | -0.001 % | pasa |
| P-20 | cota piezometrica [m] | 1136.87 | 1136.864 | -0.001 % | pasa |
| P-21 | D exacto CW [mm] | 431.23 | 431.2257 | -0.001 % | pasa |
| P-21 | D exacto SJ [mm] | 431.08 | 431.0791 | -0.000 % | pasa |
| P-21 | D comercial [mm] | 450 | 450 | -0.000 % | pasa |
| P-21 | Qmax [l/s] | 444.4 | 444.4286 | +0.006 % | pasa |
| P-21 | hf [m] | 6.01 | 6.010041 | +0.001 % | pasa |
| P-21 | hm [m] | 1.99 | 1.989964 | -0.002 % | pasa |
| P-22 | HB [m] | 38.23 | 38.2263 | -0.010 % | pasa |
| P-22 | hT disponible [m] | 8.23 | 8.226303 | -0.045 % | pasa |
| P-22 | D exacto [mm] | 172.3 | 172.293 | -0.004 % | pasa |
| P-22 | D comercial [mm] | 200 | 200 | +0.000 % | pasa |
| P-22 | Qmax 200 [l/s] | 44.33 | 44.32172 | -0.019 % | pasa |
| P-22 | hf 200 [m] | 7.95 | 7.942254 | -0.097 % | pasa |
| P-22 | hm 200 [m] | 0.28 | 0.2840485 | +1.446 % | pasa (r) |
| P-22 | Qmax 150 [l/s] | 20.9 | 20.85522 | -0.214 % | pasa (r) |
| P-24a | f CW | 0.0261015 | 0.02610146 | -0.000 % | pasa |
| P-24b | f CW | 0.0167634 | 0.01676344 | +0.000 % | pasa |
| P-25 | hf+hm [m] | 17 | 17 | +0.000 % | pasa |
| P-25 | v [m/s] | 2.917 | 2.917007 | +0.000 % | pasa |
| P-25 | hm [m] | 1.518 | 1.517903 | -0.006 % | pasa |
| P-25 | hf [m] | 15.48 | 15.4821 | +0.014 % | pasa |
| P-25 | f | 0.024152 | 0.0241518 | -0.001 % | pasa |
| P-25 | ks [mm] | 0.591 | 0.5906766 | -0.055 % | pasa |
| P-25 | Re | 683128 | 683128.1 | +0.000 % | pasa |
| S-01 | M_A | 2176.18 | 2176.18 | +0.000 % | pasa |
| S-01 | M_B | 16525.37 | 16525.37 | -0.000 % | pasa |
| S-01 | M_B friccion | 12394.03 | 12394.03 | -0.000 % | pasa |
| S-01 | M_B local | 4131.34 | 4131.342 | +0.000 % | pasa |
| S-01 | M_BCD | 1836.15 | 1836.152 | +0.000 % | pasa |
| S-01 | M total | 4012.33 | 4012.332 | +0.000 % | pasa |
| S-01 | Q [l/s] | 70.6 | 70.60193 | +0.003 % | pasa |
| S-01 | h_A [m] | 10.85 | 10.84746 | -0.023 % | pasa |
| S-01 | h_B [m] | 9.15 | 9.152542 | +0.028 % | pasa |
| S-01 | Q_B [l/s] | 23.53 | 23.53398 | +0.017 % | pasa |
| S-02 | M_A | 7616.6 | 7616.631 | +0.000 % | pasa |
| S-02 | M_B | 89237 | 89236.99 | -0.000 % | pasa |
| S-02 | M_C | 2969.39 | 2969.402 | +0.000 % | pasa |
| S-02 | M_C friccion | 2711.19 | 2711.193 | +0.000 % | pasa |
| S-02 | M_C local | 258.2 | 258.2089 | +0.003 % | pasa |
| S-02 | M_AB | 4561.78 | 4561.793 | +0.000 % | pasa |
| S-02 | M total | 7531.17 | 7531.196 | +0.000 % | pasa |
| S-02 | Q [l/s] | 51.53 | 51.53272 | +0.005 % | pasa |
| S-02 | h_C [m] | 7.886 | 7.885606 | -0.005 % | pasa |
| S-02 | h_A [m] | 12.114 | 12.11439 | +0.003 % | pasa |
| S-02 | Q_A [l/s] | 39.88 | 39.88131 | +0.003 % | pasa |
| S-02 | Q_B [l/s] | 11.65 | 11.65141 | +0.012 % | pasa |
| S-03 | M_1 | 20656.7 | 20656.71 | +0.000 % | pasa |
| S-03 | M_3 | 2065.67 | 2065.671 | +0.000 % | pasa |
| S-03 | M_3 friccion | 516.4 | 516.4178 | +0.003 % | pasa |
| S-03 | M_3 local | 1549.3 | 1549.253 | -0.003 % | pasa |
| S-03 | M_23 | 1192.3 | 1192.337 | +0.003 % | pasa |
| S-03 | Q [l/s] | 23.76 | 23.76193 | +0.008 % | pasa |
| S-03 | h_1 [m] | 11.66 | 11.66338 | +0.029 % | pasa |
| S-03 | h_23 [m] | 0.673 | 0.6732284 | +0.034 % | pasa |
| S-03 | Q_3 [l/s] | 18.05 | 18.05305 | +0.017 % | pasa |
| S-03 | Q_2 [l/s] | 5.71 | 5.708876 | -0.020 % | pasa |
| S-04 | M_1 | 2065.67 | 2065.671 | +0.000 % | pasa |
| S-04 | M_2 | 37182.09 | 37182.08 | -0.000 % | pasa |
| S-04 | M_3 | 10328.36 | 10328.36 | -0.000 % | pasa |
| S-04 | M_234 | 729.35 | 729.3506 | +0.000 % | pasa |
| S-04 | h_4 [m] | 3.305 | 3.305074 | +0.002 % | pasa |
| S-04 | Q_2 [l/s] | 9.43 | 9.42809 | -0.020 % | pasa |
| S-04 | Q_3 [l/s] | 17.89 | 17.88854 | -0.008 % | pasa |
| S-04 | Q_1 [l/s] | 67.32 | 67.31664 | -0.005 % | pasa |
| S-04 | h_1 [m] | 9.36 | 9.36065 | +0.007 % | pasa |
| S-04 | carga total [m] | 12.67 | 12.66572 | -0.034 % | pasa |
| S-04 | p tanque A [kPa] | 124.2 | 124.2507 | +0.041 % | pasa |
| S-05 | M_A | 384.23 | 384.2318 | +0.000 % | pasa |
| S-05 | M_B | 13057.08 | 13057.08 | +0.000 % | pasa |
| S-05 | M_C | 1420.15 | 1420.149 | -0.000 % | pasa |
| S-05 | M_D | 1484.9 | 1484.904 | +0.000 % | pasa |
| S-05 | M_BC | 803.09 | 803.0905 | +0.000 % | pasa |
| S-05 | M total | 2672.22 | 2672.226 | +0.000 % | pasa |
| S-05 | Q [l/s] | 167.53 | 167.5306 | +0.000 % | pasa |
| S-05 | h_A [m] | 10.78 | 10.78404 | +0.037 % | pasa |
| S-05 | h_BC [m] | 22.54 | 22.53993 | -0.000 % | pasa |
| S-05 | h_D [m] | 41.68 | 41.67603 | -0.010 % | pasa |
| S-05 | Q_B [l/s] | 41.55 | 41.5483 | -0.004 % | pasa |
| S-05 | Q_C [l/s] | 125.98 | 125.9822 | +0.002 % | pasa |
| R-02 | aviso laminar | 1 | 1 | +0.000 % | pasa |
| R-02 | f*Re | 64 | 64 | +0.000 % | pasa |
| R-02 | hf / Hagen-Poiseuille | 1 | 1 | +0.000 % | pasa |
| R-02 | Q de vuelta [l/s] | 0.02 | 0.02 | -0.000 % | pasa |
| R-03 | aviso transicion | 1 | 1 | +0.000 % | pasa |
| R-04 | error D=0 | 1 | 1 | +0.000 % | pasa |
| R-04 | error L<0 | 2 | 2 | +0.000 % | pasa |
| R-04 | error Q=0 | 3 | 3 | +0.000 % | pasa |
| R-04 | error Qmax D=0 | 1 | 1 | +0.000 % | pasa |
| R-04 | error diseno L<0 | 2 | 2 | +0.000 % | pasa |
| R-04 | error nu=0 | 4 | 4 | +0.000 % | pasa |
| R-04 | error K<0 | 6 | 6 | +0.000 % | pasa |
| R-05 | error H<0 | 7 | 7 | +0.000 % | pasa |
| R-05 | error H=0 | 7 | 7 | +0.000 % | pasa |
| R-05 | error red H=0 | 7 | 7 | +0.000 % | pasa |

Total: 191 pasan (0,1 %), 7 pasan por redondeo (r), 0 fallan, 0 sin dato

### 750 casos aleatorios contra el oráculo de Python

Rangos: $D$ de 20 mm a 1,5 m; $L$ de 1 m a 20 km; $\nu$ de $0{,}8\times10^{-6}$ a $1{,}5\times10^{-6}$ m²/s; $k_s/D$ de $10^{-6}$ a $0{,}05$; $\sum K$ de 0 a 20; $v$ de 0,02 a 6 m/s en los casos con $Q$ dado; $H$ de 0,5 a 300 m. Semilla fija 20261106. Incluye 21 casos laminares y 16 en transición. Tolerancia 0,1 %.

real = float, tolerancia 0.1 %
| Magnitud | Casos | Fallan | Peor error rel. | Donde |
|---|---|---|---|---|
| f (dado Q) | 250 | 0 | 2.50e-07 | F-17 (Re = 29567) |
| hf (dado Q) | 250 | 0 | 6.23e-07 | F-25 (Re = 2152) |
| Qmax (dado H) | 250 | 0 | 6.81e-06 | B-23 (Re = 33717) |
| D de diseno | 250 | 0 | 3.60e-07 | D-38 (Re = 588624) |

real = double, tolerancia 0.1 %
| Magnitud | Casos | Fallan | Peor error rel. | Donde |
|---|---|---|---|---|
| f (dado Q) | 250 | 0 | 2.47e-13 | F-176 (Re = 14969) |
| hf (dado Q) | 250 | 0 | 2.44e-13 | F-134 (Re = 6365) |
| Qmax (dado H) | 250 | 0 | 6.98e-06 | B-23 (Re = 33717) |
| D de diseno | 250 | 0 | 3.08e-13 | D-113 (Re = 48328) |

El peor error en $Q_{\max}$ ($6{,}8\times10^{-6}$, también en `double`) viene del criterio de parada de la iteración del curso, $|h_f^{(i+1)} - h_f^{(i)}| \le 10^{-5}$ m, y no de la precisión de 32 bits. Ningún caso aleatorio necesitó excepción.

### Casos límite

R-01 a R-05 pasan: respaldo por bisección con aviso, laminar ($f\,Re = 64$ y $h_f$ igual a Hagen-Poiseuille con un error menor que $10^{-4}$), transición con aviso, entradas inválidas con código de error y sin cierre, y $H \le 0$ con «no hay flujo por gravedad».

### Compilación para el eZ80 (CEdev v15.0)

| Programa | Tamaño `.8xp` | Detalle |
|---|---|---|
| `tests/cemu/size_probe` (motor completo, todas las funciones) | 11 194 bytes | `.text` 10 905 bytes, `.bss` 1 493 bytes |
| `tests/cemu/golden` (`make debug`, casos dorados dentro del eZ80) | 51 679 bytes | lista para CEmu; imprime la tabla por la consola de CEmu |

**Probado en CEmu** el 12 de noviembre de 2026: ver la sección «CEmu» más abajo.

## Fase 2: esqueleto de interfaz (6 de noviembre de 2026)

### Qué se construyó

- `src/ui/ui.c`: pantalla con `graphx` (doble búfer, paleta propia, fuente monoespaciada de 8 px: 40 columnas y 20 filas de cuerpo), barra de título, línea de mensajes, barra de teclas F1 a F5 (`Y=`, `ventana`, `zoom`, `trace`, `graph`) y teclado con `os_GetCSC`: `2nd`+`MODE` sale de la app, `2nd`+`,` escribe `E` (EE), `2nd`+flechas salta de página, `MODE` abre Ajustes desde cualquier pantalla.
- `src/ui/widgets.c`: menú numerado (teclas 1 a 9 o flechas), formulario común (etiqueta, valor, unidad; campos obligatorios, opcionales, de opción y enteros; validación al aceptar, sin bloquear), visor de líneas con desplazamiento y páginas.
- `src/ui/expr.c`: evaluador de expresiones con $+\ -\ \times\ /\ \hat{}\ (\ )$, signo, notación `E` y multiplicación implícita. Acepta la suma de $K$ del examen 2025 tal como se escribe.
- `src/ui/numfmt.c`: formato de números con 6 decimales por defecto (ajustable de 0 a 9), sin pasar de 7 cifras significativas (límite del `float`), y notación científica de 6 cifras fuera de $[10^{-4},\,10^7)$.
- `src/store.c`: Ajustes en el AppVar archivado `PERDCFG`, con firma, versión, tamaño, suma de control y validación de rangos. Si falta o está dañado, se usan los valores por defecto.
- `src/screens.c`: menú principal (§7.2 de la memoria), submenús de tubería simple y biblioteca, Ajustes completos, Ayuda/Acerca de, y el tipo A como ejemplo del patrón formulario y resultado (con advertencias). Las opciones de las fases 3 a 5 muestran «En construcción: disponible en la fase N».
- `icon.png` (tubo con gota, 16×16) y `makefile` (`PERDIDAS`, en RAM como H0).

### Pruebas

| Prueba | Resultado |
|---|---|
| Evaluador y formato (`tests/test_ui_pure.c`), `float` y `double` | **53 de 53 pasan** |
| Interfaz con pantalla y teclado simulados en el PC (`tests/test_nav.c` y `tests/mock/`), compilada con detección de comportamiento indefinido y de accesos fuera de límites (`-fsanitize=undefined,bounds`, que detiene el programa al primer fallo) | **29 de 29 pasan** |
| Recorrido de todos los menús y avisos, salida por menú y por `CLEAR` con confirmación | pasa |
| P-02 resuelto desde el formulario (D en mm, $k_s$ en mm, $\sum K$ como expresión, Swamee-Jain): igual al motor y a la memoria ($h_T = 19{,}77$, $h_m = 1{,}79$, $v = 2{,}29$) | pasa |
| Entradas inválidas: dato faltante, $D = 0$, `3+`, `1/0`, $k_s < 0$, $g = 50$, $v_{max} < v_{min}$, expresión de 70 caracteres | mensaje correcto y sin cierre |
| Ajustes: guardar y archivar, volver a leer, AppVar dañado, truncado y ausente, restaurar valores por defecto | pasa |
| Estrés: 40 secuencias aleatorias, **1 000 005 teclas y 709 141 pantallas** | sin cierres ni cuelgues; los Ajustes nunca quedan inválidos |
| Compilación `make` con CEdev v15.0 | `bin/PERDIDAS.8xp`, 25 191 bytes, sin advertencias del compilador |
| Navegación en CEmu | **pasa**: ver la sección «CEmu» más abajo |

Errores encontrados y corregidos en esta fase: el búfer de edición de 32 caracteres cortaba la suma de $K$ del P-02 (34 caracteres) y daba $\sum K = 6{,}38$ en lugar de 6,7; ahora tiene 64 caracteres y avisa si se llena.

### Memoria del programa (`bin/PERDIDAS.map`)

| Sección | Bytes |
|---|---|
| `.text` (código) | 19 890 |
| `.rodata` (textos y constantes) | 4 570 |
| `.data` | 59 |
| `.bss` (RAM estática) | 3 078 |

Código y datos suman unos 24,5 KB de los 64 KiB disponibles. El programa necesita las librerías `GRAPHX` y `FILEIOC` del paquete `clibs.8xg` v15.0 en la calculadora.

## CEmu: ROM, H0, casos dorados en el eZ80 y navegación (12 de noviembre de 2026)

### Cómo se obtuvo el ROM

1. La calculadora no se comunicaba con Windows 11: la integridad de memoria (HVCI) bloqueaba el controlador `tiehdusb.sys` de TI Connect CE 6.0.4 (Code 39; eventos 3077 y 3004 de CodeIntegrity). Adrián instaló **TI Connect CE 6.1.0.712** (descargado por Claude de la página de TI, firma Authenticode de Texas Instruments verificada), que trae un controlador WinUSB. Con eso, la calculadora aparece como «TI-84 Plus CE», estado OK.
2. El asistente de CEmu no se pudo manejar desde la herramienta de control de pantalla. Por eso se extrajo el programa volcador del código de CEmu (`gui/qt/romselection.cpp`) a `C:\dev\tools\romdump\DUMP.8xp`: 298 bytes, suma de control verificada.
3. Con TI Connect CE se enviaron `DUMP` y `A` (arTIfiCE) a la RAM. Adrián ejecutó `DUMP` desde arTIfiCE y se generaron `ROMData0`, `ROMData1` y `ROMDataA` a `ROMDataL` (853 kB en la memoria de archivo).
4. `tools/build_rom.py` reproduce `RomSelection::parseROMSegments` de CEmu y armó `C:\dev\tools\CEmu\ti84ce.rom`: 4 194 304 bytes, SO de 776 298 bytes en 12 segmentos más el certificado, con la cadena «5.8.4» presente. El ROM no se guarda en el repositorio.

### Herramienta de prueba

Se usa `cemu-autotester.exe` de CEdev v15.0 (sin interfaz gráfica), con las librerías v15.0 (`AUTOTESTER_LIBS_DIR`). Con `-d`, cada captura que no coincide guarda la VRAM. `tools/vram2png.py` (16 bpp, pantalla del SO) y `tools/vram8png.py` (8 bpp con los dos búferes de `graphx`) la convierten a PNG para revisarla. Nota: este autotester solo acepta las teclas por su símbolo (`.`, `+`, `,`, `y=`), no los alias `dot`, `add`, `comma` ni `yequ`.

### Casos dorados dentro del eZ80 (`tools/cemu_golden.py`)

`TGOLDEN` (`make debug`) corre los 198 chequeos en la calculadora emulada y deja cada valor en el arreglo `golden_got`. El script lo lee de la RAM emulada y lo compara con la corrida en `float` del PC y con el valor esperado.

**Total eZ80: 191 pasan, 7 pasan (r), 0 fallan. Mayor diferencia eZ80 vs PC: 1.99e-05 (P-01 error HW vs SJ [%])**

La diferencia entre el eZ80 y el PC (ambos en `float` de 32 bits) nunca pasa de $2\times10^{-5}$ en términos relativos. Solo 3 de los 198 valores superan $10^{-6}$: los dos porcentajes de diferencia entre métodos ($2\times10^{-5}$ en P-01 y $7\times10^{-6}$ en P-10), que son restas de valores parecidos, y $h_f$ de Hazen-Williams en P-01 ($1{,}4\times10^{-6}$, por las potencias con `powf`). Los otros 195 quedan en $10^{-6}$ o menos. Las diferencias se explican por el redondeo de 32 bits y por las funciones matemáticas de cada compilador.

<details><summary>Tabla completa: esperado, PC y eZ80</summary>

| Caso | Magnitud | Esperado | PC (float) | eZ80 (CEmu) | eZ80 vs PC | Resultado eZ80 |
|---|---|---|---|---|---|---|
| P-01 | v [m/s] | 2.29 | 2.291831 | 2.291831 | 1.5e-09 | pasa |
| P-01 | Re | 455180 | 455179.9 | 455179.9 | 1.1e-09 | pasa |
| P-01 | f SJ | 0.01343 | 0.0134277 | 0.0134277 | 7.5e-10 | pasa |
| P-01 | f CW | 0.01349 | 0.01348743 | 0.01348744 | 2.1e-07 | pasa |
| P-01 | hf SJ [m] | 17.97 | 17.97372 | 17.97372 | 2.0e-09 | pasa |
| P-01 | hf CW [m] | 18.05 | 18.05367 | 18.05368 | 3.2e-07 | pasa |
| P-01 | hf HW [m] | 19.32 | 19.32015 | 19.32017 | 1.4e-06 | pasa |
| P-01 | error HW vs SJ [%] | 7.5 | 7.491104 | 7.491253 | 2.0e-05 | pasa (r) |
| P-02 | hm [m] | 1.79 | 1.793664 | 1.793664 | 9.7e-10 | pasa (r) |
| P-02 | hT SJ [m] | 19.76 | 19.76738 | 19.76738 | 2.0e-09 | pasa |
| P-02 | p/gamma [m] | 32.97 | 32.96491 | 32.96491 | 1.2e-07 | pasa |
| P-02 | p/gamma sin hm [m] | 34.76 | 34.75857 | 34.75858 | 1.1e-07 | pasa |
| P-03 | Q [l/s] | 318.8 | 318.8204 | 318.8203 | 4.4e-08 | pasa |
| P-03 | v [m/s] | 4.73 | 4.728473 | 4.728473 | 7.3e-11 | pasa |
| P-03 | f | 0.01117 | 0.0111642 | 0.0111642 | 2.5e-07 | pasa |
| P-03 | hf [m] | 30.4 | 30.3949 | 30.39489 | 2.5e-07 | pasa |
| P-03 | hm [m] | 13.1 | 13.10511 | 13.10511 | 5.7e-10 | pasa |
| P-03 | metodo (1 curso) | 1 | 1 | 1 | 0.0e+00 | pasa |
| P-04 | Q [l/s] | 531.3 | 531.2959 | 531.296 | 1.2e-07 | pasa |
| P-04 | v [m/s] | 4.42 | 4.424794 | 4.424794 | 1.1e-07 | pasa (r) |
| P-04 | f | 0.01079 | 0.0107882 | 0.0107882 | 1.7e-07 | pasa |
| P-04 | hf [m] | 117 | 117.0168 | 117.0168 | 6.8e-08 | pasa |
| P-04 | hm [m] | 7.98 | 7.983201 | 7.983202 | 1.8e-07 | pasa |
| P-05 | Q [l/s] | 2104 | 2104.088 | 2104.088 | 2.7e-08 | pasa |
| P-05 | v [m/s] | 2.43 | 2.429939 | 2.429939 | 6.6e-10 | pasa |
| P-05 | f | 0.01143 | 0.01142938 | 0.01142938 | 3.3e-09 | pasa |
| P-05 | hf [m] | 77.89 | 77.89335 | 77.89335 | 7.9e-11 | pasa |
| P-05 | hm [m] | 2.11 | 2.106637 | 2.106637 | 2.6e-10 | pasa (r) |
| P-06 | Q [l/s] | 15.9 | 15.89288 | 15.89288 | 1.5e-07 | pasa |
| P-06 | v [m/s] | 8.09 | 8.094177 | 8.094178 | 1.2e-07 | pasa |
| P-07 | Q [l/s] | 5.69 | 5.692726 | 5.692726 | 2.4e-08 | pasa |
| P-07 | v [m/s] | 2.9 | 2.899281 | 2.899282 | 6.1e-10 | pasa |
| P-07 | metodo (2 biseccion) | 2 | 2 | 2 | 0.0e+00 | pasa |
| P-08 | Q [l/s] | 131 | 131.1162 | 131.1162 | 4.8e-10 | pasa |
| P-09 | Q [l/s] | 211.97 | 211.9732 | 211.9733 | 2.2e-07 | pasa |
| P-09 | v [m/s] | 3 | 2.998807 | 2.998808 | 1.6e-07 | pasa |
| P-09 | hf [m] | 97.71 | 97.70824 | 97.70825 | 7.8e-08 | pasa |
| P-09 | hm [m] | 2.29 | 2.291754 | 2.291755 | 4.1e-07 | pasa |
| P-10 | Q HW [l/s] | 195.46 | 195.4561 | 195.4561 | 4.0e-07 | pasa |
| P-10 | diferencia [%] | -7.8 | -7.792057 | -7.792111 | 7.0e-06 | pasa (r) |
| P-11 | v [m/s] | 2.376714 | 2.376714 | 2.376714 | 1.8e-09 | pasa |
| P-11 | Re | 312725.5 | 312725.5 | 312725.5 | 8.0e-10 | pasa |
| P-11 | f | 0.014458 | 0.01445797 | 0.01445797 | 7.0e-11 | pasa |
| P-11 | hf [m] | 26.918 | 26.91797 | 26.91797 | 1.6e-09 | pasa |
| P-11 | hm [m] | 2.7063417 | 2.706341 | 2.706341 | 7.6e-11 | pasa |
| P-11 | H [m] | 45.6243 | 45.62431 | 45.62431 | 1.0e-09 | pasa |
| P-11 | P [kW] | 28.8942 | 28.89417 | 28.89417 | 2.7e-08 | pasa |
| P-11 | P [Hp] | 38.7413 | 38.74772 | 38.74771 | 2.8e-08 | pasa |
| P-12 | v [m/s] | 2.387 | 2.387324 | 2.387324 | 2.0e-09 | pasa |
| P-12 | hf [m] | 20.33 | 20.33395 | 20.33395 | 2.5e-09 | pasa |
| P-12 | HB [m] | 122.33 | 122.334 | 122.3339 | 6.4e-08 | pasa |
| P-12 | Pn [kW] | 90 | 90.0072 | 90.0072 | 1.1e-08 | pasa |
| P-12 | Pb [kW] | 105.9 | 105.8908 | 105.8908 | 2.8e-08 | pasa |
| P-13 | v [m/s] | 7.958 | 7.957747 | 7.957747 | 3.2e-10 | pasa |
| P-13 | Re | 316097 | 316097.2 | 316097.2 | 1.6e-09 | pasa |
| P-13 | f CW | 0.02106 | 0.02106272 | 0.02106272 | 9.0e-08 | pasa |
| P-13 | hf [m] | 1360 | 1359.646 | 1359.646 | 9.0e-08 | pasa |
| P-13 | HB [m] | 1430 | 1429.646 | 1429.646 | 8.5e-08 | pasa |
| P-13 | Pn [kW] | 140.3 | 140.2482 | 140.2482 | 8.0e-08 | pasa |
| P-13 | Pb [kW] | 165 | 164.9979 | 164.9979 | 1.1e-07 | pasa |
| P-14 | v [m/s] | 1.415 | 1.414711 | 1.414711 | 1.2e-09 | pasa |
| P-14 | Re | 212207 | 212206.6 | 212206.6 | 1.2e-09 | pasa |
| P-14 | f | 0.01554 | 0.01554219 | 0.01554219 | 2.1e-10 | pasa |
| P-14 | hf [m] | 13.74 | 13.74043 | 13.74043 | 2.3e-09 | pasa |
| P-14 | hm [m] | 0.51 | 0.5100423 | 0.5100423 | 3.1e-10 | pasa |
| P-14 | HB [m] | 54.25 | 54.25047 | 54.25047 | 4.1e-10 | pasa |
| P-14 | Pn [kW] | 13.3 | 13.30493 | 13.30493 | 6.0e-09 | pasa |
| P-14 | Pb [kW] | 22.17 | 22.17488 | 22.17488 | 3.7e-09 | pasa |
| P-15 | D exacto [mm] | 329.1 | 329.1185 | 329.1185 | 3.1e-08 | pasa |
| P-15 | D comercial [mm] | 350 | 350 | 350 | 1.7e-08 | pasa |
| P-15 | Qmax [l/s] | 234.23 | 234.2301 | 234.2301 | 6.6e-09 | pasa |
| P-15 | hm/hf [%] | 10.42 | 10.42436 | 10.42436 | 1.5e-08 | pasa |
| P-16a | D exacto [mm] | 385.6 | 385.5804 | 385.5804 | 2.1e-08 | pasa |
| P-16a | D comercial [mm] | 400 | 400 | 400 | 1.5e-08 | pasa |
| P-16a | Qmax [l/s] | 329.9 | 329.9219 | 329.9219 | 1.2e-08 | pasa |
| P-16b | D exacto [mm] | 375 | 374.9735 | 374.9735 | 1.3e-08 | pasa |
| P-16b | D comercial [mm] | 400 | 400 | 400 | 1.5e-08 | pasa |
| P-16b | Qmax [l/s] | 354.8 | 354.8249 | 354.8249 | 2.6e-08 | pasa |
| P-17 | D exacto CW [mm] | 256.83 | 256.8315 | 256.8315 | 5.8e-08 | pasa |
| P-17 | D exacto SJ [mm] | 256.73 | 256.7299 | 256.7299 | 7.2e-08 | pasa |
| P-17 | D comercial [mm] | 285.75 | 285.75 | 285.75 | 7.0e-09 | pasa |
| P-17 | Qmax 285.75 [l/s] | 262.4 | 262.3841 | 262.3841 | 1.4e-07 | pasa |
| P-17 | Qmax 285.00 [l/s] | 260.64 | 260.6394 | 260.6394 | 2.5e-07 | pasa |
| P-17 | v 285.00 [m/s] | 4.086 | 4.085643 | 4.085644 | 1.2e-07 | pasa |
| P-17 | hf 285.00 [m] | 65.11 | 65.10989 | 65.10991 | 2.3e-07 | pasa |
| P-17 | hm 285.00 [m] | 10.89 | 10.8901 | 10.8901 | 1.7e-07 | pasa |
| P-18 | v [m/s] | 3.119 | 3.118657 | 3.118657 | 1.2e-09 | pasa |
| P-18 | Re | 891156 | 891156.2 | 891156.2 | 5.6e-10 | pasa |
| P-18 | f CW | 0.011989 | 0.01198944 | 0.01198944 | 4.8e-10 | pasa |
| P-18 | f SJ | 0.011958 | 0.01195783 | 0.01195783 | 1.0e-09 | pasa |
| P-18 | hf [m] | 39.52 | 39.5187 | 39.5187 | 7.9e-10 | pasa |
| P-18 | hm [m] | 6.35 | 6.345212 | 6.345212 | 6.9e-11 | pasa |
| P-18 | hT [m] | 45.87 | 45.86391 | 45.86391 | 8.6e-10 | pasa |
| P-18 | hv [m] | 30.13 | 30.13609 | 30.13609 | 1.3e-09 | pasa |
| P-18 | Kv | 60.8 | 60.79261 | 60.79261 | 5.2e-10 | pasa |
| P-19 | HT [m] | 30.13 | 30.13609 | 30.13609 | 1.3e-09 | pasa |
| P-19 | Pb [kW] | 59.1 | 59.12702 | 59.12701 | 2.4e-08 | pasa |
| P-19 | Pn [kW] | 38.4 | 38.43256 | 38.43256 | 3.6e-08 | pasa |
| P-20 | HB [m] | 121.87 | 121.8639 | 121.8639 | 1.1e-09 | pasa |
| P-20 | Pn [kW] | 239.1 | 239.097 | 239.097 | 3.6e-09 | pasa |
| P-20 | Pb [kW] | 398.5 | 398.495 | 398.495 | 1.1e-08 | pasa |
| P-20 | cota piezometrica [m] | 1136.87 | 1136.864 | 1136.864 | 1.6e-08 | pasa |
| P-21 | D exacto CW [mm] | 431.23 | 431.2257 | 431.2257 | 4.8e-08 | pasa |
| P-21 | D exacto SJ [mm] | 431.08 | 431.0791 | 431.0791 | 2.7e-08 | pasa |
| P-21 | D comercial [mm] | 450 | 450 | 450 | 2.7e-08 | pasa |
| P-21 | Qmax [l/s] | 444.4 | 444.4286 | 444.4284 | 4.2e-07 | pasa |
| P-21 | hf [m] | 6.01 | 6.010041 | 6.010036 | 8.7e-07 | pasa |
| P-21 | hm [m] | 1.99 | 1.989964 | 1.989962 | 9.0e-07 | pasa |
| P-22 | HB [m] | 38.23 | 38.2263 | 38.2263 | 1.5e-11 | pasa |
| P-22 | hT disponible [m] | 8.23 | 8.226303 | 8.226303 | 7.1e-11 | pasa |
| P-22 | D exacto [mm] | 172.3 | 172.293 | 172.293 | 4.2e-08 | pasa |
| P-22 | D comercial [mm] | 200 | 200 | 200 | 1.5e-08 | pasa |
| P-22 | Qmax 200 [l/s] | 44.33 | 44.32172 | 44.32174 | 2.7e-07 | pasa |
| P-22 | hf 200 [m] | 7.95 | 7.942254 | 7.942256 | 2.4e-07 | pasa |
| P-22 | hm 200 [m] | 0.28 | 0.2840485 | 0.2840486 | 5.2e-07 | pasa (r) |
| P-22 | Qmax 150 [l/s] | 20.9 | 20.85522 | 20.85522 | 1.2e-07 | pasa (r) |
| P-24a | f CW | 0.0261015 | 0.02610146 | 0.02610147 | 7.2e-08 | pasa |
| P-24b | f CW | 0.0167634 | 0.01676344 | 0.01676344 | 1.1e-07 | pasa |
| P-25 | hf+hm [m] | 17 | 17 | 17 | 0.0e+00 | pasa |
| P-25 | v [m/s] | 2.917 | 2.917007 | 2.917007 | 1.9e-10 | pasa |
| P-25 | hm [m] | 1.518 | 1.517903 | 1.517903 | 1.2e-09 | pasa |
| P-25 | hf [m] | 15.48 | 15.4821 | 15.4821 | 1.7e-09 | pasa |
| P-25 | f | 0.024152 | 0.0241518 | 0.0241518 | 1.0e-09 | pasa |
| P-25 | ks [mm] | 0.591 | 0.5906766 | 0.590677 | 7.9e-07 | pasa |
| P-25 | Re | 683128 | 683128.1 | 683128.1 | 0.0e+00 | pasa |
| S-01 | M_A | 2176.18 | 2176.18 | 2176.18 | 1.9e-09 | pasa |
| S-01 | M_B | 16525.37 | 16525.37 | 16525.37 | 7.6e-10 | pasa |
| S-01 | M_B friccion | 12394.03 | 12394.03 | 12394.03 | 7.6e-10 | pasa |
| S-01 | M_B local | 4131.34 | 4131.342 | 4131.342 | 1.2e-09 | pasa |
| S-01 | M_BCD | 1836.15 | 1836.152 | 1836.151 | 2.7e-07 | pasa |
| S-01 | M total | 4012.33 | 4012.332 | 4012.332 | 1.2e-07 | pasa |
| S-01 | Q [l/s] | 70.6 | 70.60193 | 70.60194 | 1.6e-07 | pasa |
| S-01 | h_A [m] | 10.85 | 10.84746 | 10.84746 | 1.7e-07 | pasa |
| S-01 | h_B [m] | 9.15 | 9.152542 | 9.152542 | 4.7e-10 | pasa |
| S-01 | Q_B [l/s] | 23.53 | 23.53398 | 23.53398 | 4.2e-09 | pasa |
| S-02 | M_A | 7616.6 | 7616.631 | 7616.631 | 8.2e-11 | pasa |
| S-02 | M_B | 89237 | 89236.99 | 89236.99 | 1.4e-10 | pasa |
| S-02 | M_C | 2969.39 | 2969.402 | 2969.402 | 8.1e-08 | pasa |
| S-02 | M_C friccion | 2711.19 | 2711.193 | 2711.193 | 2.3e-10 | pasa |
| S-02 | M_C local | 258.2 | 258.2089 | 258.2089 | 6.9e-10 | pasa |
| S-02 | M_AB | 4561.78 | 4561.793 | 4561.793 | 6.5e-10 | pasa |
| S-02 | M total | 7531.17 | 7531.196 | 7531.195 | 6.5e-08 | pasa |
| S-02 | Q [l/s] | 51.53 | 51.53272 | 51.53271 | 1.5e-08 | pasa |
| S-02 | h_C [m] | 7.886 | 7.885606 | 7.885605 | 1.2e-07 | pasa |
| S-02 | h_A [m] | 12.114 | 12.11439 | 12.11439 | 1.0e-09 | pasa |
| S-02 | Q_A [l/s] | 39.88 | 39.88131 | 39.88131 | 4.8e-08 | pasa |
| S-02 | Q_B [l/s] | 11.65 | 11.65141 | 11.65141 | 2.1e-08 | pasa |
| S-03 | M_1 | 20656.7 | 20656.71 | 20656.71 | 4.5e-10 | pasa |
| S-03 | M_3 | 2065.67 | 2065.671 | 2065.671 | 1.2e-09 | pasa |
| S-03 | M_3 friccion | 516.4 | 516.4178 | 516.4178 | 6.9e-10 | pasa |
| S-03 | M_3 local | 1549.3 | 1549.253 | 1549.253 | 1.3e-09 | pasa |
| S-03 | M_23 | 1192.3 | 1192.337 | 1192.337 | 1.0e-07 | pasa |
| S-03 | Q [l/s] | 23.76 | 23.76193 | 23.76193 | 1.0e-07 | pasa |
| S-03 | h_1 [m] | 11.66 | 11.66338 | 11.66339 | 1.6e-07 | pasa |
| S-03 | h_23 [m] | 0.673 | 0.6732284 | 0.6732286 | 2.7e-07 | pasa |
| S-03 | Q_3 [l/s] | 18.05 | 18.05305 | 18.05305 | 2.1e-07 | pasa |
| S-03 | Q_2 [l/s] | 5.71 | 5.708876 | 5.708877 | 1.8e-07 | pasa |
| S-04 | M_1 | 2065.67 | 2065.671 | 2065.671 | 1.2e-09 | pasa |
| S-04 | M_2 | 37182.09 | 37182.08 | 37182.08 | 8.4e-10 | pasa |
| S-04 | M_3 | 10328.36 | 10328.36 | 10328.36 | 4.4e-09 | pasa |
| S-04 | M_234 | 729.35 | 729.3506 | 729.3506 | 8.6e-11 | pasa |
| S-04 | h_4 [m] | 3.305 | 3.305074 | 3.305074 | 5.8e-10 | pasa |
| S-04 | Q_2 [l/s] | 9.43 | 9.42809 | 9.42809 | 3.4e-08 | pasa |
| S-04 | Q_3 [l/s] | 17.89 | 17.88854 | 17.88854 | 7.0e-09 | pasa |
| S-04 | Q_1 [l/s] | 67.32 | 67.31664 | 67.31664 | 1.9e-08 | pasa |
| S-04 | h_1 [m] | 9.36 | 9.36065 | 9.36065 | 2.7e-10 | pasa |
| S-04 | carga total [m] | 12.67 | 12.66572 | 12.66572 | 5.2e-11 | pasa |
| S-04 | p tanque A [kPa] | 124.2 | 124.2507 | 124.2507 | 1.9e-08 | pasa |
| S-05 | M_A | 384.23 | 384.2318 | 384.2318 | 1.2e-09 | pasa |
| S-05 | M_B | 13057.08 | 13057.08 | 13057.08 | 1.7e-09 | pasa |
| S-05 | M_C | 1420.15 | 1420.149 | 1420.149 | 2.6e-09 | pasa |
| S-05 | M_D | 1484.9 | 1484.904 | 1484.904 | 2.3e-09 | pasa |
| S-05 | M_BC | 803.09 | 803.0905 | 803.0905 | 1.7e-10 | pasa |
| S-05 | M total | 2672.22 | 2672.226 | 2672.226 | 1.6e-09 | pasa |
| S-05 | Q [l/s] | 167.53 | 167.5306 | 167.5305 | 2.3e-08 | pasa |
| S-05 | h_A [m] | 10.78 | 10.78404 | 10.78404 | 3.4e-09 | pasa |
| S-05 | h_BC [m] | 22.54 | 22.53993 | 22.53993 | 1.3e-09 | pasa |
| S-05 | h_D [m] | 41.68 | 41.67603 | 41.67603 | 1.3e-10 | pasa |
| S-05 | Q_B [l/s] | 41.55 | 41.5483 | 41.5483 | 2.6e-08 | pasa |
| S-05 | Q_C [l/s] | 125.98 | 125.9822 | 125.9822 | 9.8e-09 | pasa |
| R-01 | metodo (2 biseccion) | 2 | 2 | 2 | 0.0e+00 | pasa |
| R-01 | aviso de respaldo | 1 | 1 | 1 | 0.0e+00 | pasa |
| R-01 | Q [l/s] | 5.69 | 5.692726 | 5.692726 | 2.4e-08 | pasa |
| R-02 | aviso laminar | 1 | 1 | 1 | 0.0e+00 | pasa |
| R-02 | f*Re | 64 | 64 | 64 | 0.0e+00 | pasa |
| R-02 | hf / Hagen-Poiseuille | 1 | 1 | 1.000001 | 5.5e-07 | pasa |
| R-02 | Q de vuelta [l/s] | 0.02 | 0.02 | 0.02 | 3.6e-09 | pasa |
| R-03 | aviso transicion | 1 | 1 | 1 | 0.0e+00 | pasa |
| R-04 | error D=0 | 1 | 1 | 1 | 0.0e+00 | pasa |
| R-04 | error L<0 | 2 | 2 | 2 | 0.0e+00 | pasa |
| R-04 | error Q=0 | 3 | 3 | 3 | 0.0e+00 | pasa |
| R-04 | error Qmax D=0 | 1 | 1 | 1 | 0.0e+00 | pasa |
| R-04 | error diseno L<0 | 2 | 2 | 2 | 0.0e+00 | pasa |
| R-04 | error nu=0 | 4 | 4 | 4 | 0.0e+00 | pasa |
| R-04 | error K<0 | 6 | 6 | 6 | 0.0e+00 | pasa |
| R-05 | error H<0 | 7 | 7 | 7 | 0.0e+00 | pasa |
| R-05 | error H=0 | 7 | 7 | 7 | 0.0e+00 | pasa |
| R-05 | error red H=0 | 7 | 7 | 7 | 0.0e+00 | pasa |

</details>

### Navegación de `PERDIDAS` en CEmu (`tools/cemu_ui.py`, `tests/cemu/autotest_ui.json`)

21 pantallas capturadas y revisadas a mano en PNG: menú principal, submenú de tubería simple, formulario vacío, «Falta este dato», $D = 0$ rechazado, P-02 escrito tecla por tecla (incluida la suma de $K$ como expresión y `1.007E-6` con `2nd` + `,`), resultado de P-02 (igual al PC: $h_T = 19{,}76738$ m, Swamee-Jain), desplazamiento, aviso de módulo pendiente, Ajustes (13 campos), regreso por `CLEAR`, Biblioteca, Ayuda con dos páginas, confirmación de salida y regreso limpio al menú de arTIfiCE.

| Prueba | Resultado |
|---|---|
| Regresión con los CRC32 guardados (`python -I tools/cemu_ui.py --check`) | **21 de 21 pantallas iguales** |
| Cierres o cuelgues durante la secuencia | ninguno |
| Error encontrado y corregido | la Ayuda mostraba «1/2» también en su última página |

**Con esto la fase 2 queda cerrada**: navegación completa sin cierres en CEmu.

## Fase 3: tubería simple con memoria de cálculo (12 de noviembre de 2026)

### Qué se construyó

- `src/scr_pipe.c`: formularios, cálculo, resumen y memoria de cálculo de los tipos **A** (pérdidas dado $Q$, con presión opcional en el punto final), **B** (caudal máximo: iteración del curso o bisección de respaldo, con la tabla de iteraciones), **C** (bomba o turbina, potencia neta y bruta en kW y Hp, cota piezométrica opcional), **D** (diámetro exacto por bisección con su tabla, diámetro comercial de una lista del curso, $Q_{\max}$ con el comercial, $v_p$ y válvula de control opcional), **E** (calibración de $f$ y $k_s$), **F** (válvula de control) e **I** (Darcy-Weisbach contra Hazen-Williams, en pérdidas o en caudal). Los datos tecleados se conservan entre tipos.
- La memoria de cálculo sigue el orden de la sección 7.6: DATOS, CÁLCULOS (fórmula literal, sustitución y resultado), ITERACIONES (primeras y últimas 16 filas si hay más de 32), RESULTADOS y OBSERVACIONES (advertencias). Las fórmulas se escriben en ASCII lineal y se cortan solas a 40 columnas.
- La memoria y los resúmenes son «programas» de datos con plantillas (`{Q}`, `{D}`…) que interpreta `run_prog`. `src/data/diams.c` trae las listas de diámetros comerciales de la sección 8.6 más una lista general.

### Pruebas

| Prueba | Resultado |
|---|---|
| Interfaz simulada en el PC (`tests/test_nav.c`): un caso del curso por tipo tecleado en su formulario (P-02 A, P-03 y P-07 B, P-11 y P-19 C, P-17 y P-18 D, P-18 F, P-25 E, P-01 y P-10 I), memoria de cálculo de cada uno, tipo A con los 4 métodos de $f$ y en régimen laminar, $v_p$ con pérdidas locales altas | **57 de 57 pasan** |
| Revisión de cada memoria: sin plantillas sin resolver, con OBSERVACIONES al final (condiciones balanceadas) y sin llenar el visor (máx. 108 de 120 líneas) | pasa |
| Estrés: 1 000 005 teclas aleatorias, 762 687 pantallas, ahora pasando por los 7 tipos | sin cierres ni cuelgues |
| Casos dorados del motor en el PC (`float` y `double`) y en el eZ80 (CEmu) | sin cambios: 191 + 7 (r), 0 fallan |
| CEmu: un caso por tipo tecleado en la calculadora emulada, con capturas revisadas (`tools/cemu_ui.py`, 26 pantallas) | valores iguales al PC salvo en la última cifra (por ejemplo, $K_v$ = 60,79253 en el eZ80 frente a 60,79262 en el PC) |
| Regresión de CEmu con los CRC guardados | **26 de 26 pantallas iguales** |

Valores leídos en las capturas de CEmu: P-02 $h_T = 19{,}76738$ m y $p = 323{,}39$ kPa; P-03 $Q = 318{,}8204$ l/s (20 iteraciones del curso); P-11 $H_B = 45{,}62432$ m y $P_b = 28{,}9202$ kW con $\gamma = 9810$; P-17 $D = 256{,}8315$ mm, comercial 285,75 mm, $Q_{\max} = 262{,}3841$ l/s y $K_v = 60{,}79$; P-18 $h_v = 30{,}136$ m; P-25 $k_s = 0{,}590677$ mm; P-10 $Q_{HW} = 195{,}4561$ l/s y $-7{,}79\,\%$.

Errores encontrados y corregidos en esta fase: el nombre de plantilla `LISTNAME` no cabía en el búfer de 8 caracteres y la memoria del tipo D decía «Lista: ?»; los pasos sin fórmula literal (`ks/D`, `v^2/2g`) salían sin su nombre; y el aviso de pérdidas locales altas hablaba de $v_p$ también en los tipos que no la calculan.

### Memoria del programa

| Sección | Bytes |
|---|---|
| `.text` | 32 808 |
| `.rodata` | 15 195 |
| `.data` | 1 872 |
| `.bss` | 6 976 |

El `.8xp` pesa 50 547 bytes de los 64 KiB que puede ocupar el programa. Comprimir no ayuda, porque solo reduce el espacio guardado y no la RAM al ejecutar. Para las fases 4 y 5 se planea llevar los textos de la memoria de cálculo y de la ayuda a un AppVar archivado, como pide la sección 1.5 de la memoria técnica. Así el programa no debería pasar el límite.

### Pendiente de la fase 3

Prueba en la calculadora real de Adrián (TI-84 Plus CE, OS 5.8.4.0058, arTIfiCE v2.1, librerías v15.0): **pasa**. Adrián siguió la lista de 8 pasos (P-02, memoria, P-03, P-17, P-25 y salida) y reportó que todo coincide y funciona bien. **Fase 3 cerrada.**

## Fase 4: biblioteca y casos guardados (12 de noviembre de 2026)

### Qué se construyó

- **AppVar `PERDTXT`**: los textos de la memoria de cálculo y de los resúmenes salieron del programa. `tools/memo_tables.c` es la fuente; `tools/gen_txt.c` la serializa (7 498 bytes, textos repetidos fusionados) y valida al compilar los nombres de plantilla, el balance IF/ENDIF y los índices. La app lee el AppVar directamente desde la memoria de archivo. Si falta, la memoria de cálculo lo avisa en pantalla y la app no se cierra. `tools/build_all.sh` genera `bin/PERDTXT.8xv` y `bin/PERDIDAS.8xp`.
- **Biblioteca** (`src/data/lib.c`, `src/scr_lib.c`): 24 materiales con $k_s$ y $C_H$ (tabla del curso más Cengel, marcados), 30 accesorios con $K$, los 6 conjuntos de $K$ de los ejercicios (§8.4; sus sumas dan 6,7, 12,8, 21,4, 2,8, 10,8 y 0,7), 12 fluidos (agua de 5 a 40 °C de tabla estándar, marcada «std», y las 5 viscosidades del curso) y diámetros comerciales con una **lista propia** editable de hasta 15 valores.
- En los formularios, **F1 MAT**, **F2 SUMA K** y **F3 FLUIDO** llenan los campos. El **sumador** lleva cantidad × $K$ por línea, ambos editables, con el total actualizado al aceptar cada valor. «Fluido por defecto» cambia $\nu$, $\gamma = \rho g$ y la presión de vapor en Ajustes, y valida antes de aplicar.
- **Mis casos** (`src/cases.c`, AppVar `PERDCAS`): F3 GUARDAR en cualquier resultado, con nombre de hasta 8 letras o números (se escribe con las teclas verdes). Hasta 20 casos; reemplaza con confirmación; los carga y recalcula; los borra con confirmación. El archivo lleva firma, versión, tamaño y suma de control, y al leerlo se acotan todos los índices. Se escribe en RAM durante la sesión y se archiva al salir de la app.

### Pruebas

| Prueba | Resultado |
|---|---|
| Interfaz simulada en el PC (`tests/test_nav.c`), con 20 comprobaciones nuevas: material, sumador con conjunto y accesorio suelto, quitar línea, fluido en el formulario y por defecto, lista propia usada en el diseño (P-17 da comercial 300 mm), guardar, nombre repetido, cargar (recalcula), borrar, lista llena (20), nombre vacío, recarga tras archivar, AppVar dañado, truncado y ausente | **78 de 78 pasan** |
| Estrés (1 000 005 teclas, 896 696 pantallas), ahora también por la biblioteca y Mis casos | sin cierres; **encontró un error real**: «Fluido por defecto» calculaba $\gamma = \rho g$ con una $g$ extrema y dejaba los Ajustes inválidos. Corregido: se valida antes de aplicar |
| Migración a `PERDTXT` verificada en CEmu: las 26 pantallas de la fase 3 salen **idénticas** byte a byte | pasa. Antes, la regresión atrapó un error: el valor con id 0 ($Q$) terminaba el texto; ahora se guarda id + 1 |
| CEmu, fase 4 (`tools/cemu_reset.py`, 20 capturas revisadas): MAT, sumador con el conjunto 2025, fluidos, nombre «PRUEBA» con las teclas de letras, guardado, Mis casos | pasa |
| **Un caso guardado sobrevive a reiniciar la RAM** (CEmu, ROM 5.8.4.0058): se guarda «PRUEBA» (P-03), se sale, se archivan `prgmA` y `prgmPERDIDAS` desde MEM, se provoca el reinicio (la pantalla muestra «RAM Cleared»), se relanza arTIfiCE desde el archivo, `PERDIDAS` arranca y Mis casos carga «PRUEBA» con $Q = 318{,}8204$ l/s | **pasa** |
| Regresión de interfaz en CEmu y casos dorados en el eZ80 | 26 de 26; 191 + 7 (r), 0 fallan |

Hallazgo útil para la instalación: con arTIfiCE y `PERDIDAS` **archivados**, ambos siguen funcionando después de un reinicio de la RAM, así que no hace falta volver a pasarlos.

### Memoria del programa

| Sección | Bytes |
|---|---|
| `.text` | 41 313 |
| `.rodata` | 9 889 |
| `.data` | 1 872 |
| `.bss` | 11 998 |

`PERDIDAS.8xp` pesa 53 754 bytes y `PERDTXT.8xv` 7 574. Para la fase 5 (sistemas y gráficos) quedan unos 10 KiB dentro del límite de 64 KiB. Si no alcanzan, el siguiente paso es llevar también los datos de la biblioteca y la ayuda al AppVar.
