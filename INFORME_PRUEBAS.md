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
