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
| Ejecutar H0 en CEmu | **pendiente**: no hay ROM (punto de parada 1) |
| Ejecutar H0 en la calculadora real (OS 5.8.4.0058 con arTIfiCE v2.1) | **pendiente de verificar por Adrián** |

### arTIfiCE y la 5.8.4.0058

- La página oficial dice que la v2.1 soporta el OS «hasta la v5.8.4» y la v3 solo la 5.8.5. Para la 5.8.4.0058 corresponde la **v2.1**.
- La página solo habla de programas en ensamblador. Los programas del toolchain de C son programas nativos del mismo tipo, pero eso **no está probado** hasta que H0 corra en la calculadora real.
- Comportamiento de CEmu con un ROM 5.8.4: por comprobar en cuanto haya ROM (se espera que bloquee programas nativos y haya que aplicar arTIfiCE dentro del emulador).

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

**No probado todavía en CEmu**: falta el ROM (punto de parada 1).
