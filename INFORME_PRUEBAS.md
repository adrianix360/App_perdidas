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

## Fase 5: sistemas en serie y paralelo, y gráfica de LE y LP (12 de noviembre de 2026)

### Qué se construyó

- `src/scr_net.c`, tipo **G**: hasta 8 tubos, cada uno con su número de **tramo**. Los tubos del mismo tramo van en paralelo y los tramos en serie, en orden creciente. Con esto se escriben todos los sistemas del curso: S-01 `Serie[A, Paralelo[B, C, D]]` es A en el tramo 1 y B, C, D en el tramo 2. Hay dos modos: **hacia adelante** (dada $H$) y **hacia atrás** (dado $Q$ en un tubo, se obtiene $H$ y la presión). $f$ puede ser dato o calcularse con Colebrook-White a partir de $k_s$ (iteración externa).
- Resumen con $Q$, $H$, $M$ y, por tubo, $M$, $Q$, $h$ y $v$, más las comprobaciones $\sum Q$ en los nudos y $\sum h$ en las rutas. La memoria de cálculo tiene la estructura de los manuscritos: datos, módulos $M = \frac{8}{\pi^2 g}\left(\frac{fL}{D^5} + \frac{\sum K}{D^4}\right)$ con la parte de fricción y la local, reducción de cada paralelo $\left(\sum 1/\sqrt{M_i}\right)^{-2}$ y de la serie, $Q = \sqrt{H/M}$ (o el recorrido hacia atrás), reparto $h = MQ^2$ y $Q_i = \sqrt{h/M_i}$, resultados y observaciones.
- `src/ui/graph.c`, tipo **H**: esquema de la **línea de energía** (azul) y la **piezométrica** (rojo) con tanques, saltos por pérdidas locales, bomba (salto hacia arriba), turbina o válvula (salto hacia abajo) y la cota de energía en los extremos. Está en los sistemas (la ruta pasa por el tubo de mayor caudal de cada tramo, marcado «+») y en los tipos A, B, C, D y F (F2 GRÁFICO).

### Tamaño: programa grande repartido en AppVars

Con la fase 5 el programa pasa de 64 KiB (código, datos y constantes ≈ 70 KB). CEdev v15 lo resuelve solo: produce un **lanzador** `PERDIDAS.8xp` de 585 bytes y dos AppVars, `PERDIDA0` (65 308 bytes) y `PERDIDA1` (6 977 bytes), que el lanzador copia a la RAM al arrancar. Se comprobó en CEmu con el ROM 5.8.4 que **el lanzador funciona desde el menú de arTIfiCE v2.1**, y que también funciona archivado tras un reinicio de la RAM. A cambio, se necesitan unos 72 KB de RAM libre al ejecutar. Antes se intentó reducir el código; la gráfica reescrita con enteros salió 2,4 KB más grande, así que se volvió a la versión original.

| Sección | Bytes |
|---|---|
| `.text` | 58 032 |
| `.rodata` | 11 344 |
| `.data` | 2 147 |
| `.bss` | 15 794 |

### Pruebas

| Prueba | Resultado |
|---|---|
| Interfaz simulada en el PC: S-01 a S-05 tecleados en el formulario (S-04 hacia atrás), memoria (reducción, reparto, recorrido hacia atrás), $f$ automático, tubo conocido inexistente, cambio del número de tubos de 1 a 8, gráficas de S-01 (2 tramos, la LE termina en el tanque 2) y de los tipos B, C y F (datos de la gráfica finitos y coherentes) | **92 de 92 pasan** |
| Estrés: 1 000 006 teclas, 947 672 pantallas, ahora también por Sistemas | sin cierres |
| CEmu (`tools/cemu_net.py`, 14 capturas revisadas): S-01 $Q = 70{,}602$ l/s y $M = 4012{,}33$; S-02 $Q = 51{,}533$ l/s, $Q_A = 39{,}881$, $Q_B = 11{,}651$; S-03 $Q = 23{,}762$ l/s, $Q_3 = 18{,}053$, $Q_2 = 5{,}709$; S-04 $H = 12{,}666$ m $= 124{,}25$ kPa, $Q_1 = 67{,}317$ l/s; S-05 $Q = 167{,}531$ l/s, $Q_B = 41{,}548$, $Q_C = 125{,}982$; gráficas de S-01, S-03, S-05 y de la bomba de P-20 ($H_B = 121{,}86$ m hasta el tanque a 76 m) | **S-01 a S-05 correctos en CEmu** |
| Regresión de CEmu (26 pantallas), casos dorados en el eZ80 y prueba de reinicio con el lanzador | 26 de 26; 191 + 7 (r), 0 fallan; el caso sobrevive |

Errores corregidos en esta fase: rótulo «-9,5E-7» en vez de 0 al final de la gráfica (ruido de `float`); la leyenda LE/LP quedaba tapada por la línea de mensajes; un mensaje de 41 caracteres se montaba sobre sí mismo.

Limitaciones conocidas: los sistemas no se guardan en Mis casos (solo la tubería simple); no hay ramales con tubos en serie dentro de un paralelo (ningún ejercicio del curso los usa); la gráfica es un esquema sin el perfil del terreno.

## Fase 6: pulido, ayuda, README e instalación (12 de noviembre de 2026)

### Qué se construyó

- **Ayuda por temas** (Ayuda en el menú principal): uso y teclas, tipos de problema, fórmulas, potencia bruta y neta, $\sum K$ y fuentes de los datos, advertencias y erratas del material. Los textos van en `PERDTXT` (25 programas, 13 043 bytes), así que no ocupan RAM del programa.
- **Casos del curso:** 21 ejercicios de los PDF (P-01, P-02, P-03, P-05, P-07, P-09, P-10, P-11, P-12, P-15, P-17 a P-21, P-25 y S-01 a S-05). Se cargan en su formulario y se resuelven con un `enter`; luego se puede ver la memoria y la gráfica.
- **Acerca de**, con la versión y la RAM libre, y **aviso de RAM baja** al abrir la app (menos de 3 000 bytes).
- `README_es.md`: requisitos, archivos, instalación paso a paso con arTIfiCE v2.1 para la 5.8.4.0058, cómo archivar para sobrevivir a un reinicio, uso de cada pantalla, desinstalación, tabla de fallas y cómo compilar y probar.
- Versión 1.0. La versión final está instalada en la calculadora de Adrián (12 de noviembre de 2026): `PERDIDAS` (lanzador en RAM), `PERDIDA0`, `PERDIDA1` y `PERDTXT` en el archivo; quedan 151 kB de RAM libre.

### Pruebas

| Prueba | Resultado |
|---|---|
| Interfaz simulada en el PC: los 7 temas de ayuda (sin plantillas rotas ni líneas de más de 40 columnas), los 21 casos del curso cargados y calculados uno por uno, P-17 desde Casos del curso (285,75 mm y 262,38 l/s) y S-04 hacia atrás (12,67 m) | **96 de 96 pasan** |
| Estrés: 1 000 000 de teclas, 952 074 pantallas | sin cierres ni cuelgues |
| CEmu (`tools/cemu_net.py --fase6`, 11 capturas): menú de ayuda, temas Uso y teclas y Fórmulas, Casos del curso, P-17 y S-04 cargados y resueltos, Acerca de (64 KB de RAM libre con la app abierta) | pasa |
| Regresión de 26 pantallas en CEmu y casos dorados en el eZ80 | 26 de 26; 191 + 7 (r), 0 fallan |

### Memoria final

| Parte | Tamaño |
|---|---|
| `PERDIDAS.8xp` (lanzador) | 585 bytes |
| `PERDIDA0` + `PERDIDA1` (programa) | 65 308 + 9 699 bytes |
| `PERDTXT` (textos) | 13 119 bytes (`.8xv`) |
| `.text` / `.rodata` / `.data` / `.bss` | 59 140 / 13 084 / 2 155 / 15 795 bytes |

---

## Resumen final

### Qué se probó y cómo

| Capa | Qué | Resultado |
|---|---|---|
| 1. Motor en el PC | 198 comprobaciones de la sección 9 (P-01 a P-25 sin P-23, S-01 a S-05, R-01 a R-05), en `float` y `double` | 191 dentro del 0,1 %, 7 dentro del redondeo del valor impreso, **0 fallan** |
| 1. Motor en el PC | 750 casos aleatorios contra el oráculo en Python ($f$, $h_f$, $Q_{\max}$ y $D$; incluye laminar y transición) | **0 fallan**; peor error $6{,}8\times10^{-6}$ |
| 1. Interfaz en el PC | pantalla y teclado simulados con detección de comportamiento indefinido: 96 comprobaciones y 1 millón de teclas aleatorias | **96 de 96**, sin cierres |
| 2. CEmu (ROM de Adrián, 5.8.4.0058 + arTIfiCE) | los 198 chequeos dentro del eZ80; un caso del curso por tipo; S-01 a S-05; gráficas; ayuda; casos del curso; caso guardado tras «RAM Cleared»; regresión de 26 pantallas | **todo pasa**; diferencia con el PC $\le 2\times10^{-5}$ |
| 3. Plataforma | programa grande en lanzador + AppVars probado con arTIfiCE; AppVars dañados, truncados y ausentes; RAM libre con la app abierta | pasa |
| 4. Calculadora real | H0 (fase 0) y prueba de la fase 3 hechas por Adrián | pasa |
| 4. Calculadora real | **prueba final de la fase 6** | **pendiente de verificar por Adrián** |

### Qué NO se pudo probar automáticamente

- La lectura de la pantalla real de la calculadora (colores, nitidez, velocidad percibida). Lo cubre la prueba manual de Adrián.
- `ti_SetArchiveStatus` cuando la memoria de archivo está casi llena (no se forzó esa condición en el emulador).
- La función secundaria de posición máxima de la bomba por cavitación (memoria 6.10): **no implementada**. La memoria pedía consultarla antes, y la presión de vapor ya es editable en Ajustes para cuando se haga.

### Problemas conocidos y limitaciones

1. Los sistemas en serie y paralelo no se guardan en Mis casos (sí la tubería simple). Se pueden recuperar desde Casos del curso o tecleando.
2. No hay ramales con tubos en serie dentro de un paralelo. Ningún ejercicio del curso los usa.
3. La gráfica es un esquema sin el perfil del terreno; no marca la presión negativa contra un terreno real (memoria 6.8, nivel «deseable»).
4. Los símbolos se escriben en ASCII (`nu`, `gamma`, `SumK`), sin fuente propia, como se acordó con Adrián.
5. La app ocupa 4 archivos (lanzador, 2 AppVars y `PERDTXT`) y necesita unos 75 KB de RAM libre al ejecutar.
6. arTIfiCE v2.1 se pierde con un reinicio de la RAM si no está archivado (recomendación en el README).

---

# Versión 2.0: sustentación y arrastre, vertedores y orificios, «Calcular f»

## v2.0, fase 0: entorno, respaldo y decisiones (15 de noviembre de 2026)

**Entorno.** CEdev v15.0 (`C:\CEdev`), gcc 16.2.0 (WinLibs), Python, CEmu con el ROM 5.8.4 y TI Connect CE 6.1.0.712: todo presente, no se instaló nada. La calculadora (OS 5.8.4) está conectada por USB.

**Respaldo.** Etiqueta Git `v1.0-estable` (commit `c05f4bf`). Desde la calculadora se descargaron `PERDCAS` (170 B, 1 caso guardado, formato versión 1) y `PERDCFG` (55 B) a `respaldo_calc/2026-11-15/`.

**Regresión de la v1.0 (antes de tocar el código).**

| Prueba | Resultado |
|---|---|
| `tools/run_pc_tests.sh` (dorados `float` y `double`, aleatorios, interfaz simulada) | 191 pasan, 7 pasan por redondeo, 0 fallan; 96 de 96 comprobaciones de interfaz |
| `tools/cemu_golden.py` (eZ80) | 191 pasan, 7 (r), 0 fallan; mayor diferencia eZ80 frente a PC 1,99e-5 |
| `tools/cemu_ui.py --check` | 26 de 26 pantallas iguales |

**Decisiones de Adrián (dudas de la sección 11 del prompt).**

| Duda | Respuesta |
|---|---|
| Paracaídas (AR-01) | $C_D=1{,}3$ por defecto; 1,42 (copa) en el catálogo |
| Cubo en agua (AR-03) | Área de referencia por defecto $A=\sqrt2\,D^2$ (proyectada); $D^2$ elegible. El caso del curso usa $\sqrt2D^2$ ($v_t=1{,}329$ m/s) |
| Torre y tanque (AR-02) | Tabla de $Re>10^4$ (cilindro interpolado $L/D=15$, esfera 0,5) con aviso de crisis de arrastre |
| Tarea 4-2 P2b | $Q=36$ l/s; cresta del rectangular a la altura $H$ de la parte a sobre el vértice; $C_d=0{,}6$ |
| Venturi | Convención física $\Delta p=(S-1)\gamma h$ por defecto; la del examen 2025 queda como ajuste. Se usa el caudal que se teclee y la memoria advierte la diferencia con el caudal de diseño |
| Chorro | $\sum K=0$ por defecto (como la solución); «+1 por energía cinética de salida» opcional |
| Menú | Submenú «Flujos externos y medición» (arrastre, vertedores, canales); el principal queda con 9 entradas, todas con tecla 1 a 9 |
| Material faltante | No hay foto de las tablas de $C_D$, ni enunciado del chorro, ni solución del examen 2017: el catálogo usa los valores del prompt, cada uno con su fuente |

## v2.0, fase 1: motor nuevo (15 de noviembre de 2026)

**Construido.** Tres módulos en C puro, separados de `hydro.c`: `src/hydro/drag.c` (arrastre, velocidad terminal con empuje, estructura con varios cuerpos, vuelo nivelado con $\rho(h)$, Stokes, placa plana, interpolación de tablas de $C_D$ y avisos por $Re$), `src/hydro/weir.c` (vertedero triangular y rectangular con Francis opcional, orificio circular y rectangular, estructura compuesta $Q(h)$ y $h(Q)$ por bisección, perfil de velocidades $v=k\,y^n$ y por puntos con Simpson o trapecios, sección aguas abajo) y `src/hydro/chan.c` (Venturi con las dos convenciones del manómetro, salto hidráulico desde $y_1$ o desde $y_2$, chorro). En `hydro.c`, `hydro_fric_all` da los 4 métodos de $f$ con su diferencia respecto a Colebrook-White, la marca de fuera de rango y la tabla de iteraciones de CW; la iteración de CW se movió a una función `cw_iter` que también usa `hydro_friction` (los resultados de la v1.0 no cambian). Tres códigos de error nuevos, al final de la lista: `H_ERR_ARG` (18), `H_ERR_FLOATS` (19) y `H_ERR_NOJUMP` (20).

**Pruebas.**

| Prueba | Resultado |
|---|---|
| Casos dorados en el PC (`float` y `double`), con los nuevos AR-01 a AR-07, VE-01 a VE-09, EX-01 a EX-03 y F-01 a F-05 | 302 pasan, 8 por redondeo, 0 fallan (eran 191 + 7) |
| Casos dorados dentro del eZ80 (CEmu) | 302 pasan, 8 por redondeo, 0 fallan; mayor diferencia eZ80 frente a PC 1,99e-5 |
| Aleatorios v2.0: 625 casos contra el oráculo independiente `tools/oracle2.py` | 0 fallas en `float` (peor 2,2e-5, salto hidráulico) y en `double` (peor 3,1e-11) |
| Aleatorios v1.0, interfaz simulada (96) e interfaz pura (53) | sin cambios, 0 fallas |

**Diferencias con el prompt.**

- **Haaland:** el motor de la v1.0 usa $1/\sqrt f=-1{,}8\log_{10}[\dots]$ («según el material del curso», `HAALAND_COEF`); el prompt tabula F-01 a F-04 con 1,81. Se respetó el código: los casos dorados de Haaland usan 1,8 (F-01: 0,025907 en vez de 0,025621). Si el curso usa 1,81, se cambia una constante.
- **Valor inicial de Colebrook-White:** el motor parte de $f_1=0{,}0001$ (diapositiva 25 de la presentación), no de 0,001. El resultado final no cambia; la tabla de iteraciones de la memoria lo mostrará así.
- **VE-08:** $h_0=0{,}02417$ m frente a 0,0242 del prompt (redondeo de una resta; pasa por redondeo).
- **EX-01a:** $\Delta p=32\,660$ Pa con los diámetros exactos; el prompt (32 667) y la solución (32 668) usan $v_1$ y $v_2$ redondeados. Diferencia 0,02 %.
- `tools/cemu_golden.py` ahora envía también los AppVars `TGOLDEN0/1`, porque el programa de prueba pasó de 64 KiB.

**Tamaño.** `PERDIDAS` sin pantallas nuevas: `PERDIDA1` pasa de 9 699 a 10 229 B (la tabla de 4 métodos y los textos de error). Los módulos `drag`, `weir` y `chan` todavía no se enlazan con ninguna pantalla.

## v2.0, fase 1b: «Calcular f» (15 de noviembre de 2026)

**Construido.**

- Pantalla `src/scr_fric.c`, entrada 3 del menú principal y 8.ª del menú «Tubería simple». Dos modos que se alternan con F2 MODO: «Re y ks/D» (el campo $k_s/D$ acepta el valor directo, o bien $k_s$ y $D$ en mm) y «Datos tubería» ($Q$ o $v$, $D$, $k_s$, $\nu$, con los selectores MAT y FLUIDO). Los datos del modo 2 se comparten con la tubería simple.
- Resultado: régimen, zona del turbulento por $k^+=(k_s/D)\,Re\sqrt{f/8}$ (lisa < 5, transición 5 a 70, rugosa > 70), $f$ con el método de Ajustes, $1/\sqrt f$ y la tabla de los 4 métodos con la diferencia porcentual respecto a CW y la marca de fuera de rango.
- Memoria de cálculo en `PERDTXT` (programas `XP_FRIC_SUM` y `XP_FRIC_MEMO`): datos, cálculos con la fórmula del método elegido, tabla de iteraciones de Colebrook-White (columnas $i$ y $f_i$), resultado, comparación y avisos.
- `[USAR f]` copia el $f$ al campo «f dado» del formulario que abrió la pantalla. En los tipos A, B, C y F la tecla F4 pasó de AJUSTES a **CALC f** (MODE sigue abriendo los Ajustes); en Sistemas, F1 **CALC f** actúa sobre el campo «f dado» donde esté el cursor.
- Menú principal de 9 entradas (todas con tecla 1 a 9): Tubería simple, Sistemas, Calcular f, Flujos externos y medición (submenú; sus 3 módulos avisan «Disponible en la fase 3, 4 o 5»), Biblioteca, Mis casos, Ajustes, Ayuda, Salir.
- El intérprete de la memoria de cálculo salió de `scr_pipe.c` a `src/memo_run.c`, para que lo usen todos los módulos nuevos. `TX_VERSION` sube a 2: **la app nueva necesita el `PERDTXT` nuevo** (con uno viejo muestra el aviso, sin cerrarse). Versión 2.0 en «Acerca de».

**Pruebas.**

| Prueba | Resultado |
|---|---|
| Interfaz simulada (`test_nav`), con 12 comprobaciones nuevas: F-01 a F-05, memoria con tabla de CW, modo tubería, laminar, transición, $Re=0$ rechazado, USAR f hacia el tipo A y hacia un sistema, aviso fuera de un campo f | 108 de 108; estrés de 1 000 005 teclas sin cierres |
| Casos dorados PC y eZ80, aleatorios v1.0 y v2.0 | sin cambios, 0 fallas |
| CEmu (`cemu_ui.py`): 34 pantallas | Las 12 pantallas de la v1.0 que cambiaron se revisaron una por una: el menú principal, el de tubería, la tecla F4 de los formularios A, B, C y F, y las que guardan en el segundo búfer la pantalla anterior. Se agregaron 8 pantallas nuevas (formulario, F-01, memoria en 3 páginas, F-03, submenú de flujos y «Acerca de»). Línea base nueva: 34 de 34 iguales |

| Caso | Pantalla en CEmu | Esperado |
|---|---|---|
| F-01 | CW 0,026101; SJ 0,026064 (−0,1451 %); Haaland 0,025907; GS 0,026054; converge en 9 iteraciones | 0,026101 (sol. 0,0261015) |
| F-03 (modo tubería) | $v=3{,}118658$; $Re=891\,156$; CW 0,011989; SJ 0,011958 (−0,2637 %) | 0,011989; SJ 0,011958 |

**Tamaños y RAM.** `PERDIDA1` 15 305 B (antes 9 699), `PERDTXT` 15 626 B (antes 13 119). El motor de arrastre, vertedores y canales ya va dentro del programa. **RAM libre con la app abierta: 58 942 B** (v1.0: unos 64 KB; mínimo pedido: 30 KB). Quedan unos 29 KB de margen para las fases 2 a 6: las pantallas nuevas tendrán que ser compactas y los textos ir a `PERDTXT`.

**Pendiente de esta pantalla.** `[GUARDAR]` en «Mis casos» queda para la fase 6, junto con el formato nuevo de `PERDCAS` y su migración.

## v2.0, fase 2: catálogo de $C_D$, aire e ilustraciones 3D (15 de noviembre de 2026)

**Construido.**

- **Catálogo** (`src/data/dragcat.c`): las 17 figuras de la sección 4.3 del prompt, cada una con su orientación, $C_D$, área de referencia, tipo de cuerpo para los avisos por $Re$, fuente y nota. Tiene tablas para el cilindro finito perpendicular ($L/D$, con ∞ = 1,2), el cilindro axial ($L/D$), la placa rectangular ($b/h$, con ∞ = 1,98) y el cono (ángulo, según White). Para usar el valor «infinito» se escribe un parámetro de 1000 o más. La esfera y el disco traen su fórmula de Stokes.
- **Pantallas** (`src/scr_cat.c`), en Biblioteca › 5 «Coeficientes de arrastre (CD)»:
  - lista con miniatura 3D, número, nombre, orientación y $C_D$;
  - detalle con la ilustración ×2 y la flecha del flujo, $C_D$, área de referencia, validez, fuente, tabla y nota;
  - MARCAR y COMPAR. (hasta 3 figuras con su barra y la razón de fuerzas);
  - RANKING de menor a mayor $C_D$ con barras;
  - EDITAR ($C_D$ propio, que se guarda en `PERDCFG`; DEFECTO restaura el del catálogo);
  - TABLA (interpola el parámetro y muestra los dos vecinos);
  - USAR, que devuelve $C_D$ al formulario que la abrió (lo usarán las fases 3 a 5).
- **Ilustraciones**: `tools/gen_gfx.py` traza con rayos la función de distancia de cada figura (numpy, vista tres cuartos, supermuestreo 3×3), cuantiza a una rampa de 12 tonos gris azulado más naranja para la flecha y comprime con RLE de 4 bits en el AppVar archivado `PERDGFX`, de **15 297 B** (límite: 60 KB). La app dibuja tramo a tramo desde el archivo, sin búfer: **0 B de RAM**. Imagen grande de 96×80 (se muestra ×2) y miniatura de 32×18; paleta en las entradas 32 a 47, sin tocar los colores de la interfaz. Si falta `PERDGFX`, la app avisa y sigue funcionando. Para que los dos cubos se distingan se ven desde arriba: el de cara es un cuadrado con un lado hacia la flecha y el de arista, un rombo con la punta hacia la flecha.
- **Aire** en la lista de fluidos: curso (1,2 y 1,5E-5), 15 °C estándar (1,225 y 1,46E-5) y 20 °C (1,204 y 1,516E-5). Como fluido por defecto, el aire va a «rho del aire» y «nu del aire», sin tocar el $\gamma$ del agua.
- **Ajustes nuevos**: rho y nu del aire, empuje con aire, Cd de vertedores (0,6), km/h por nudo (1,85) y convención del manómetro.
- **`PERDCFG` 2.0**: lee el formato 1.0 conservando los ajustes de la v1.0 (decimales, método, $g$, $\gamma$, $\nu$, tolerancias…), pone lo nuevo por defecto y lo guarda en el formato nuevo al salir.
- **RAM**: el catálogo escrito a la primera ocupaba 15 KB de código. Se compactó (el formulario de Ajustes pasó a datos estáticos, las líneas se arman con `mfmt` y se comparte un solo registro de iteraciones entre pantallas): `PERDIDA1` quedó en 25 083 B.

**Pruebas.**

| Prueba | Resultado |
|---|---|
| Interfaz simulada: 14 comprobaciones nuevas (lista con 10 miniaturas sin salirse de la pantalla, detalle, TABLA L/D = 15 da 0,91667 con vecinos 10 y 40, L/D ≥ 1000 da 1,2, EDITAR y DEFECTO, COMPAR. da 2,34 veces, RANKING, USAR devuelve el paracaídas con 1,3, sin `PERDGFX`, aire por defecto, migración de `PERDCFG` 1.0 y vuelta a leer en 2.0) | 122 de 122; estrés sin cierres |
| Dorados, aleatorios v1.0 y v2.0, eZ80 | sin cambios, 0 fallas |
| CEmu: 56 pantallas (22 nuevas: dos páginas de la lista, las 17 fichas, comparar, ranking y tabla) | revisadas una por una; línea base nueva, 56 de 56 iguales. `tools/vram8png.py` ahora lee la paleta de `PERDGFX` |

**Hoja de contacto** capturada de CEmu: `tests/cemu/hoja_contacto_cemu.png`, con las 17 fichas (`tools/cemu_sheet.py`); versión del generador: `tests/cemu/hoja_contacto_cd.png`. **Pendiente de la aprobación de Adrián.**

**Tamaños y RAM.** `PERDIDA1` 25 083 B, `PERDGFX` 15 373 B (el .8xv). **RAM libre con la app abierta: 49 159 B** (fase 1b: 58 942). Para las fases 3 a 6 quedan unos 19 KB sobre el mínimo de 30 KB. Las pantallas de arrastre, vertedores y canales se harán con un motor común de formulario y memoria en `PERDTXT`.

**Valores del catálogo sin verificar con el libro** (no hay foto de las tablas): todos traen su fuente. Diferencia interna que conviene revisar: el cono de 30° vale 0,5 en Çengel, pero la tabla por ángulo de White da 0,55 a 30°.

## v2.0, fase 3: arrastre y sustentación (15 de noviembre de 2026)

**Construido.** `src/scr_drag.c`, en Flujos externos › Arrastre y sustentación:

- **AR-1**: fuerza de arrastre o de sustentación (elige $C_D$ o $C_L$).
- **AR-2**: velocidad terminal con empuje. En agua el volumen es obligatorio; en aire, según Ajustes.
- **AR-3**: estructura de hasta 6 cuerpos, cada uno con $C_D$, figura, dimensiones, área, cota $y$ y velocidad propia opcional. Da fuerza total, momento en la base, $y_{cp}$ y un ESQUEMA con las fuerzas a su altura.
- **AR-4**: vuelo nivelado en dos pasos en la misma pantalla. Sin «CD alas» calcula $\rho(h)$, $q$ y el $C_L$ necesario, y pide leer $\alpha$ y $C_D$ en la gráfica; con la lectura da el arrastre de las alas y del fuselaje, el empuje, la potencia y, si se da $C_{L,\max}$, la velocidad de pérdida.
- **Placa plana y Stokes** (el EX-4 del prompt; queda aquí porque es materia de arrastre): $C_f$ laminar, turbulento y mixto, con régimen automático o elegido; esfera de Stokes con $F=3\pi\mu VD$.
- El catálogo también se abre desde este menú.

Detalles de la entrada de datos:

- **Fluido**: «Aire (Ajustes)», «Agua» o «Manual»; las dos primeras llenan $\rho$ y $\nu$.
- **Velocidad** en m/s, km/h o nudos; el factor del nudo sale de Ajustes, y AR-4 empieza en nudos.
- **F1 CD** abre el catálogo y devuelve $C_D$ y figura; con tabla, pide el parámetro. Escribir el número de la figura también pone su $C_D$.
- **Área**: si no se teclea, se calcula con la fórmula de la figura y la memoria la muestra con la plantilla `{TXT}`.
- **Re < 1**: con una figura que tiene fórmula de Stokes (esfera o disco) se usa $C_D=k/Re$ y la memoria lo dice.
- **Avisos**: $Re<10^4$, crisis de arrastre (esfera con $Re>2\times10^5$, cilindro largo con $Re>5\times10^5$) y $Re<1$.

Memorias de cálculo en `PERDTXT` (10 programas nuevos, `tools/memo_drag.c`). En AR-3 los renglones de cada cuerpo los arma la pantalla, con un gancho del intérprete (`TB_HOOK`). La estructura reutiliza el búfer del formulario de Sistemas (`ff_shared`): 0 B de RAM extra. Cambio en el catálogo pedido por Adrián: el cubo de arista usa por defecto el área proyectada $\sqrt2\,D^2$; para usar $D^2$ se teclea $A$.

**Pruebas.**

| Prueba | Resultado |
|---|---|
| Interfaz simulada: 13 comprobaciones nuevas, cada caso tecleado: AR-01, AR-03a, AR-03b, AR-02a con memoria y esquema, AR-04 en los dos pasos, AR-06 turbulento y mixto, AR-05, y W < B rechazado | 135 de 135; estrés sin cierres. Se amplió el AppVar simulado a 32 KB, porque `PERDTXT` ya mide 21,9 KB |
| Dorados, aleatorios v1.0 y v2.0 | sin cambios, 0 fallas |
| CEmu: 69 pantallas (15 nuevas) | revisadas; línea base nueva, 69 de 69 iguales |

| Caso | En CEmu | Esperado |
|---|---|---|
| AR-01 | $v_t=4{,}92243$ m/s (17,72 km/h), $Re=2\,625\,296$ | 4,922 |
| AR-02a | $q=462{,}963$; $F_1=25{,}463$; $F_2=26{,}180$ kN; $M=1324{,}422$ kN·m; $y_{cp}=25{,}6458$ m; aviso de crisis | 1 324; 25,65 |
| AR-03b / AR-03a | 1,32891 / 1,58035 m/s (interfaz simulada) | 1,329 / 1,580 |
| AR-04 | $\rho=0{,}40145$; $q=12\,213$; $C_L=0{,}883108$; $D_{fus}=267{,}41$ kN; $T=306{,}274$ kN; $P=75{,}5$ MW | 0,8831; 267,41; 306,27 |
| AR-05 | $F_D=9{,}42\times10^{-9}$ N (interfaz simulada) | 9,425E-9 |
| AR-06 | $Re_L=1\,333\,333$; $C_f$ 0,004408 y 0,003102; $F_D=0{,}528963$ N | 0,529 |

**RAM.** `PERDIDA1` 39 728 B, `PERDTXT` 21 933 B. **RAM libre con la app abierta: 34 505 B** (fase 2: 49 159). Quedan 4,5 KB sobre el mínimo de 30 KB, y las fases 4 y 5 no caben en ese margen: se consulta a Adrián.

**Aprendido.** `make clean` borra todo `bin/`, incluido `PERDGFX.bin` (se recupera con `git checkout` o con `tools/gen_gfx.py`). Se probó `PREFER_OS_CRT` de CEdev: ahorra solo 450 B y cambia las rutinas de punto flotante, así que se descartó.

## v2.0: separación en dos programas, PERDIDAS y FLUJOS (15 de noviembre de 2026)

**Decisión de Adrián** (después de la fase 3, con 34,5 KB libres y vertedores y canales todavía por hacer): separar la app en dos programas.

- **PERDIDAS**: tubería simple, sistemas, «Calcular f», biblioteca (materiales, accesorios, fluido con aire, diámetros), mis casos, ajustes y ayuda. La entrada 4 del menú, «Flujos externos (FLUJOS)», avisa que hay que abrir el otro programa. Así no cambió la numeración del menú.
- **FLUJOS**: arrastre y sustentación, vertedores y orificios, canales y medición, catálogo de coeficientes de arrastre, mis casos, ajustes y ayuda.
- Los dos comparten `PERDTXT` (memorias y ayuda), `PERDCFG` (ajustes) y `PERDCAS` (casos). FLUJOS usa además `PERDGFX`.

**Cómo se arma.** Es un solo código fuente (`src/`). `flujos/makefile` compila con `-DPROG_FLUJOS`, que hace que `main.c` llame a `flujos_main()` (`src/flujos.c`) en vez de `scr_main()`. El enlazado con LTO deja en cada programa solo lo que usa. `flujos/src` y `flujos/obj` son uniones (CEdev no acepta `SRCDIR=../src`). `CONVBINFLAGS = -m 32768` hace que FLUJOS sea, como PERDIDAS, un lanzador chico más AppVars de código archivados (`FLUJOS0`, `FLUJOS1`). Un `.8xp` grande en RAM ocuparía el doble al ejecutarse: con 50 KB en RAM quedaban 38,7 KB libres, y con lanzador quedan 88,8 KB. `tools/build_all.sh` compila los dos. La ayuda por temas (`help_topic`) pasó a `memo_run.c` y «Acerca de» (`scr_about`) es común a los dos.

**Pruebas.**

| Prueba | Resultado |
|---|---|
| Interfaz simulada: catálogo y arrastre recorridos desde el menú de FLUJOS (`runf`), aviso de PERDIDAS › 4 y estrés repartido entre los dos programas | 136 de 136 |
| Dorados, aleatorios v1.0 y v2.0, eZ80 | sin cambios, 0 fallas |
| CEmu (`tools/cemu_ui.py` y `tools/cemu_ui.py --flujos`) | PERDIDAS 34 de 34; FLUJOS 39 de 39 (líneas base `autotest_ui.json` y `autotest_flujos.json`) |

**Tamaños y RAM con la app abierta (CEmu).**

| Programa | Archivos | RAM libre |
|---|---|---|
| PERDIDAS | `PERDIDAS` 585 B + `PERDIDA0` 65 308 B + `PERDIDA1` 15 813 B | **58 420 B** |
| FLUJOS | `FLUJOS` 591 B + `FLUJOS0` 32 844 B + `FLUJOS1` 17 937 B | **88 758 B** |

Los dos superan con holgura los 30 KB pedidos. FLUJOS tiene más de 50 KB de margen para vertedores y canales.
