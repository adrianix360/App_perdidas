# PERDIDAS: pérdidas de energía en tuberías para la TI-84 Plus CE

App para la calculadora TI-84 Plus CE del curso IC-0605 Mecánica de Fluidos (UCR). Resuelve los problemas de pérdidas en tuberías del curso y muestra cada resultado con su **memoria de cálculo paso a paso**: datos, fórmula, sustitución, resultado, iteraciones y advertencias.

- **Tubería simple:** pérdidas dado $Q$ (A), caudal máximo (B), diámetro de diseño (D), bomba o turbina (C), válvula de control (F), calibración de $k_s$ (E) y Darcy-Weisbach contra Hazen-Williams (I).
- **Sistemas en serie y paralelo** con módulos de caudal $h = MQ^2$, hacia adelante y hacia atrás (G).
- **Gráfica** de la línea de energía y la piezométrica (H).
- **Biblioteca:** $k_s$, $C_H$, $K$ de accesorios con sumador, fluido y diámetros comerciales.
- **Casos guardados** y **casos del curso** para cargar y estudiar.

Versión 1.0. Autor del encargo: Adrián Castro Ramírez.

---

## 1. Requisitos

| Qué | Detalle |
|---|---|
| Calculadora | TI-84 Plus CE con sistema operativo **5.8.4.0058**. **No actualices el sistema operativo**: la 5.8.5 cerró el jailbreak que usa esta app. |
| Jailbreak | **arTIfiCE v2.1** (cubre las versiones 5.5 a 5.8.4). Viene en `instalacion/arTIfiCE_v2.1.8xp`. |
| PC | Windows con **TI Connect CE 6.1** o posterior. La 6.0.4 no funciona en Windows 11 con la integridad de memoria activa: el controlador USB queda bloqueado (Code 39). |
| Memoria libre | unos **75 KB de RAM** al ejecutar y unos **90 KB de memoria de archivo** para los archivos. |

## 2. Archivos

| Archivo en el PC | Nombre en la calculadora | Qué es | Dónde va |
|---|---|---|---|
| `bin/PERDIDAS.8xp` | `PERDIDAS` | lanzador del programa (585 bytes) | RAM o archivo |
| `bin/PERDIDAS.8xp.0.8xv` | `PERDIDA0` | primera parte del programa | archivo |
| `bin/PERDIDAS.8xp.1.8xv` | `PERDIDA1` | segunda parte del programa | archivo |
| `bin/PERDTXT.8xv` | `PERDTXT` | textos de la memoria de cálculo y de la ayuda | archivo |
| `instalacion/clibs.8xg` | `GRAPHX`, `FILEIOC`, `LibLoad`… | librerías del CE Toolchain v15.0 | archivo |
| `instalacion/arTIfiCE_v2.1.8xp` | `A` | jailbreak para lanzar programas nativos | RAM (luego se puede archivar) |

El programa pasa de 64 KB, el límite de un programa normal. Por eso el CE Toolchain lo divide en un lanzador y dos AppVars. Los cuatro primeros archivos tienen que estar en la calculadora.

La app crea dos AppVars propios: `PERDCFG` (tus ajustes) y `PERDCAS` (tus casos guardados y tu lista propia de diámetros). Se archivan al salir de la app.

## 3. Instalación paso a paso

1. Conecta la calculadora encendida al PC con el cable USB y abre **TI Connect CE**.
2. Si Windows no la reconoce (en TI Connect CE no aparece «TI-84 Plus CE»), instala TI Connect CE 6.1 desde la página de Texas Instruments, desconecta y vuelve a conectar.
3. En **Explorador de calculadoras**, pulsa **Acciones › Añadir archivos desde el ordenador** y envía, de una vez:
   - `instalacion/clibs.8xg` (al archivo; si ya tienes librerías, deja marcado «Sustituya»).
   - `bin/PERDIDA0` y `bin/PERDIDA1` (los `.8xv`) y `bin/PERDTXT.8xv` (al archivo).
   - `bin/PERDIDAS.8xp` (a la RAM o al archivo).
   - `instalacion/arTIfiCE_v2.1.8xp` a la **RAM** (se llama `A` en la calculadora).
4. En la calculadora pulsa `prgm`, elige **A** y `enter`. Si pregunta, elige TI-Basic. Se abre el menú «arTIfiCE SHELL 2.1».
5. Elige **PERDIDAS** y pulsa `enter`. Debe aparecer el **MENÚ PRINCIPAL**.
6. **Recomendado:** archiva `A` y `PERDIDAS` para que sobrevivan a un reinicio de la RAM. Para cada uno: `2nd` `+` (MEM) › `5:Archive` › `prgm` › elige el programa › `enter`. Se comprobó en el emulador que, archivados, siguen funcionando después de un reinicio.

Para salir de la app: `2nd` `mode` (QUIT), o `clear` en el menú principal y luego `enter`. Vuelves al menú de arTIfiCE; `mode` lo cierra.

**Después de un reinicio de la RAM:** si `A` no estaba archivado, vuelve a enviarlo (paso 3). Lo demás está en el archivo y no se pierde.

## 4. Uso

### Teclas

| Tecla | Acción |
|---|---|
| `enter` | acepta y pasa al campo siguiente; en el último campo, calcula |
| `clear` | borra lo escrito; si no hay nada, vuelve atrás |
| `del` | borra un carácter; en un campo opcional, lo vacía |
| flechas | se mueven; `▶` edita el valor actual; `◀ ▶` cambian las opciones `< >` |
| `2nd` `▲` / `▼` | primer o último campo, o una página arriba o abajo |
| `(-)` | signo |
| `2nd` `,` | `E` (×10^), por ejemplo `1.007E-6` |
| `y=` `window` `zoom` `trace` `graph` | F1 a F5 (barra inferior) |
| `mode` | Ajustes, desde cualquier pantalla |
| `2nd` `mode` | salir de la app |

Los campos aceptan cuentas: `0.5+1.0+4*1.10+10*0.30+3*0.3+3.0` da 12,8.

**Unidades:** $Q$ en l/s, $D$ y $k_s$ en mm, $L$, $H$ y cotas en m, presiones en m.c.a. (metros de columna de agua).

### Menú principal

1. **Tubería simple.** Siete tipos, cada uno con su formulario.
   - En el formulario: F1 **MAT** (material: $k_s$ y $C_H$), F2 **SUMA K** (sumador de accesorios), F3 **FLUIDO** ($\nu$), F4 **AJUSTES** y F5 **CALC**.
   - En el resultado: F1 **MEMORIA** (cálculo paso a paso; `◀ ▶` cambian de página), F2 **GRÁFICO** (LE y LP), F3 **GUARDAR** y F5 **VOLVER**.
   - A: pérdidas dado $Q$; opcionalmente la presión en el punto final.
   - B: caudal máximo. Usa la iteración del curso (diapositivas 10 y 11) y, si no converge, bisección. La memoria dice cuál usó.
   - D: diámetro exacto, el comercial de una lista y el caudal con el comercial. Puede incluir la válvula de control y $v_p$.
   - C: bomba ($H_B = H_s + h_T$) o turbina ($H_T = H_a - h_T$), con potencias neta y bruta en kW y Hp. La bruta es siempre la mayor.
   - F: válvula de control, $K_v = 2g\,h_v/v^2$.
   - E: calibración, con $f$ y $k_s$ a partir de la caída medida.
   - I: Darcy-Weisbach contra Hazen-Williams, en pérdidas o en caudal.
2. **Sistemas (serie / paralelo).**
   - Hasta 8 tubos A a H; a cada uno se le da un **número de tramo**. Los tubos con el mismo número van en **paralelo** y los tramos van en **serie**, en orden. Ejemplo del examen 2024 P3: A en el tramo 1; B, C y D en el tramo 2.
   - Dos modos: **Adelante**, si se conoce $H$, y **Atrás**, si se conoce el $Q$ de un tubo; en ese caso se obtiene $H$ y la presión.
   - Cada tubo usa $f$ dado o $k_s$, con $f$ calculado por Colebrook-White.
3. **Biblioteca.**
   - Materiales: tabla del curso y Cengel, marcada «(C)».
   - Accesorios y sumador: 30 accesorios y los conjuntos de $K$ de los ejercicios.
   - Fluido por defecto: cambia $\nu$, $\gamma = \rho g$ y la presión de vapor en Ajustes.
   - Diámetros comerciales: listas del curso y tu **lista propia**.
4. **Mis casos.** Hasta 20 casos guardados: `enter` carga y recalcula, F3 borra. Los sistemas no se guardan.
5. **Ajustes.**
   - Método de $f$ (Colebrook-White por defecto, Swamee-Jain, Haaland o Goudar-Sonnad).
   - $g$, $\gamma$, $\nu$, decimales (6 por defecto), tolerancia, presión de vapor, límites de los avisos y número de Reynolds laminar y turbulento.
   - Se guardan al salir.
6. **Ayuda.** Siete temas (teclas, tipos, fórmulas, potencia, fuentes de los datos, advertencias, erratas del material), los **Casos del curso** (21 ejercicios de los PDF que se cargan y resuelven con un `enter`) y «Acerca de», que muestra la RAM libre.

### Advertencias que puede mostrar

Régimen laminar ($Re < 2000$, $f = 64/Re$); transición ($2000 \le Re \le 4000$, resultado indicativo); $k_s/D > 0{,}05$; fuera del rango de Swamee-Jain; velocidad alta o baja (criterio general, editable); $h_m > 0{,}3\,h_f$; $L/D > 4000$ (locales despreciables, pero se suman igual); presión manométrica negativa o imposible; la iteración del curso no convergió; $k_s$ negativo en la calibración.

## 5. Desinstalar

En la calculadora: `2nd` `+` (MEM) › `2:Mem Management/Delete`.

1. Borra `PERDIDAS` en **Prgm**.
2. Borra `PERDIDA0`, `PERDIDA1`, `PERDTXT`, `PERDCFG` y `PERDCAS` en **AppVars**.

Borrar `PERDCAS` elimina tus casos guardados. Las librerías (`GRAPHX`, `FILEIOC`, `LibLoad`, etc.) bórralas solo si ningún otro programa las usa. También puedes borrarlo todo desde TI Connect CE: selecciona los archivos y usa la papelera.

## 6. Si algo falla

| Síntoma | Qué hacer |
|---|---|
| `ERROR: INVALID` al ejecutar `PERDIDAS` desde `prgm` | El sistema 5.8.4 bloquea los programas nativos: lánzalo desde el menú de arTIfiCE (`prgm` › `A`). |
| Al pulsar `A` no aparece el menú de arTIfiCE | Vuelve a enviar `arTIfiCE_v2.1.8xp` a la **RAM**. Si se reinició la RAM y no estaba archivado, se perdió. |
| `Need LibLoad` o un mensaje sobre librerías | Envía `instalacion/clibs.8xg`. |
| Error al lanzar, o falta `PERDIDA0` o `PERDIDA1` | Envía los dos `.8xv` del programa; tienen que estar los cuatro archivos. |
| La memoria de cálculo dice «Falta el archivo PERDTXT» | Envía `bin/PERDTXT.8xv`. |
| «Poca RAM libre» al abrir, o la app no arranca | Archiva o borra programas y variables grandes. Hacen falta unos 75 KB de RAM libre. |
| «Archivo de ajustes dañado» o «Archivo de casos dañado» | La app empieza con valores por defecto o con la lista vacía y sigue funcionando. Si se repite, borra `PERDCFG` o `PERDCAS`. |
| TI Connect CE no ve la calculadora (Code 39 en el Administrador de dispositivos) | Instala TI Connect CE 6.1 o posterior. No hace falta desactivar ninguna protección de Windows. |
| «Calculadora ocupada» en TI Connect CE | Sal de la app y de arTIfiCE hasta la pantalla principal y repite. |
| Un resultado no coincide con un PDF | Revisa Ayuda › Erratas del material y el método de $f$ en Ajustes: los exámenes de 2024 y 2025 diseñan con Swamee-Jain. |

## 7. Para compilar y probar (en el PC de Adrián)

El código está en `src/`: `hydro/` es el motor en C puro, `ui/` la interfaz y `data/` las tablas. Se compila desde la unión sin espacios `C:\dev\ti84`, porque la carpeta de OneDrive tiene espacios.

```bash
sh tools/build_all.sh
```

Genera `bin/PERDTXT.8xv` y el programa con CEdev v15.0.

```bash
sh tools/run_pc_tests.sh
```

Corre las pruebas del PC: casos dorados en `float` y `double`, 750 casos aleatorios contra el oráculo de Python e interfaz simulada con prueba de estrés.

```bash
python -I tools/cemu_golden.py
```

Corre los casos dorados dentro del eZ80 emulado. Necesita el ROM en `C:\dev\tools\CEmu\ti84ce.rom`.

```bash
python -I tools/cemu_ui.py --check
```

Corre la regresión de 26 pantallas en CEmu.

Los resultados de todas las pruebas están en `INFORME_PRUEBAS.md`.
