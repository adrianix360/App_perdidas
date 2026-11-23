# PERDIDAS y FLUJOS: mecánica de fluidos en la TI-84 Plus CE

Dos programas para la calculadora TI-84 Plus CE del curso IC-0605 Mecánica de Fluidos (UCR). Resuelven los ejercicios del curso y muestran cada resultado con su **memoria de cálculo paso a paso**: datos, fórmula, sustitución, resultado, iteraciones y advertencias.

**PERDIDAS** (pérdidas de energía en tuberías):

- **Tubería simple:** pérdidas dado $Q$ (A), caudal máximo (B), diámetro de diseño (D), bomba o turbina (C), válvula de control (F), calibración de $k_s$ (E) y Darcy-Weisbach contra Hazen-Williams (I).
- **Sistemas en serie y paralelo** con módulos de caudal $h = MQ^2$, hacia adelante y hacia atrás (G), y **gráfica** de la línea de energía y la piezométrica (H).
- **Calcular f:** solo el factor de fricción, con los 4 métodos comparados y la tabla de iteraciones de Colebrook-White.
- **Biblioteca:** $k_s$, $C_H$, $K$ de accesorios con sumador, fluido (agua y aire) y diámetros comerciales.

**FLUJOS** (flujos externos y medición):

- **Arrastre y sustentación:** fuerza $F_D$ o $F_L$, velocidad terminal con empuje, estructura con varios cuerpos (momento en la base), vuelo nivelado, y placa plana y Stokes.
- **Catálogo de coeficientes de arrastre:** 17 figuras con **ilustración 3D**, tablas por $L/D$, $b/h$ o ángulo, comparar y ranking.
- **Vertedores y orificios:** elemento simple ($H \leftrightarrow Q$ y cota de la cresta), estructura compuesta (nivel ↔ caudal, reparto), perfil de velocidades y energía aguas abajo.
- **Canales y medición:** Venturi con manómetro, salto hidráulico y chorro desde un tubo.

Los dos programas tienen **Mis casos** (compartidos), **casos del curso** para cargar y estudiar, ayuda y ajustes comunes.

Versión 2.0. Autor del encargo: Adrián Castro Ramírez.

---

## 1. Requisitos

| Qué | Detalle |
|---|---|
| Calculadora | TI-84 Plus CE con sistema operativo **5.8.4.0058**. **No actualices el sistema operativo**: la 5.8.5 cerró el jailbreak que usan estos programas. |
| Jailbreak | **arTIfiCE v2.1** (cubre las versiones 5.5 a 5.8.4). Viene en `instalacion/arTIfiCE_v2.1.8xp`. |
| PC | Windows con **TI Connect CE 6.1** o posterior. La 6.0.4 no funciona en Windows 11 con la integridad de memoria activa: el controlador USB queda bloqueado (Code 39). |
| Memoria de archivo | unos **220 KB** para todos los archivos. |
| RAM | Al abrir un programa se copia a la RAM: hacen falta unos **85 KB** libres antes de abrirlo. Con la app abierta quedan unos **56 KB** libres en PERDIDAS y unos **53 KB** en FLUJOS (medido en el emulador con la calculadora de Adrián). |

## 2. Archivos

Todos están en la carpeta `instalacion/` (copias de `bin/`):

| Archivo en el PC | Nombre en la calculadora | Qué es | Dónde va |
|---|---|---|---|
| `PERDIDAS.8xp` | `PERDIDAS` | lanzador de PERDIDAS (585 bytes) | RAM o archivo |
| `PERDIDAS.8xp.0.8xv`, `PERDIDAS.8xp.1.8xv` | `PERDIDA0`, `PERDIDA1` | código de PERDIDAS | archivo |
| `FLUJOS.8xp` | `FLUJOS` | lanzador de FLUJOS (591 bytes) | RAM o archivo |
| `FLUJOS.8xp.0.8xv`, `FLUJOS.8xp.1.8xv` | `FLUJOS0`, `FLUJOS1` | código de FLUJOS | archivo |
| `PERDTXT.8xv` | `PERDTXT` | memorias de cálculo y ayuda de los dos programas | archivo |
| `PERDGFX.8xv` | `PERDGFX` | ilustraciones 3D del catálogo de $C_D$ (FLUJOS) | archivo |
| `clibs.8xg` | `GRAPHX`, `FILEIOC`, `LibLoad`… | librerías del CE Toolchain v15.0 | archivo |
| `arTIfiCE_v2.1.8xp` | `A` | jailbreak para lanzar programas nativos | RAM (luego se puede archivar) |

Cada programa pasa del tamaño cómodo para la RAM, así que el CE Toolchain lo divide en un lanzador chico y AppVars de código archivados.

Los programas crean dos AppVars propios: `PERDCFG` (tus ajustes) y `PERDCAS` (tus casos guardados y tu lista propia de diámetros). Se archivan al salir. **Al actualizar desde la v1.0 se conservan:** la v2.0 lee los formatos 1.0 y los convierte.

## 3. Instalación paso a paso

1. Conecta la calculadora encendida al PC con el cable USB y abre **TI Connect CE**.
2. Si Windows no la reconoce (en TI Connect CE no aparece «TI-84 Plus CE»), instala TI Connect CE 6.1 desde la página de Texas Instruments, desconecta y vuelve a conectar.
3. En **Explorador de calculadoras**, pulsa **Acciones › Añadir archivos desde el ordenador** (o el primer icono de la barra) y envía, de una vez, todos los archivos de `instalacion/`. Deja marcado «Sustituya el contenido existente». TI Connect CE pone solo los `.8xp` en la RAM y los `.8xv` en el archivo.
4. En la calculadora pulsa `prgm`, elige **A** y `enter`. Si pregunta, elige TI-Basic. Se abre el menú «arTIfiCE SHELL 2.1».
5. Elige **PERDIDAS** o **FLUJOS** y pulsa `enter`.
6. **Recomendado:** archiva `A`, `PERDIDAS` y `FLUJOS` para que sobrevivan a un reinicio de la RAM: `2nd` `+` (MEM) › `5:Archive` › `prgm` › elige el programa › `enter`.

**Actualizar desde la v1.0:** envía los mismos archivos con «Sustituya» marcado. No borres `PERDCFG` ni `PERDCAS`: la v2.0 los convierte la primera vez que se abre.

Para salir: `2nd` `mode` (QUIT), o `clear` en el menú principal y luego `enter`. Vuelves al menú de arTIfiCE; `mode` lo cierra.

## 4. Uso

### Teclas (las dos)

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
| `2nd` `mode` | salir del programa |

Los campos aceptan cuentas: `0.5+1.0+4*1.10+10*0.30+3*0.3+3.0` da 12,8.

En todo resultado: F1 **MEMORIA** (cálculo paso a paso; `◀ ▶` cambian de página), F3 **GUARDAR** (en Mis casos) y F5 **VOLVER**.

### PERDIDAS

**Unidades:** $Q$ en l/s, $D$ y $k_s$ en mm, $L$, $H$ y cotas en m, presiones en m.c.a.

1. **Tubería simple.** Siete tipos (A, B, D, C, F, E, I) y la entrada 8, «f: factor de fricción».
   - En el formulario: F1 **MAT** (material: $k_s$ y $C_H$), F2 **SUMA K**, F3 **FLUIDO**, F4 **CALC f** en A, B, C y F (calcula $f$ y lo devuelve al campo «f dado»; en D, E e I es AJUSTES) y F5 **CALC**.
   - En el resultado, además: F2 **GRÁFICO** (LE y LP).
   - B usa la iteración del curso y, si no converge, bisección; D da el diámetro exacto y el comercial; C da las potencias neta y bruta en kW y Hp.
2. **Sistemas (serie / paralelo).** Hasta 8 tubos; los que tienen el mismo número de tramo van en paralelo y los tramos van en serie. Modo adelante (dado $H$) o atrás (dado el $Q$ de un tubo). F1 **CALC f** calcula el $f$ del campo «f dado» donde esté el cursor.
3. **Calcular f.** F2 **MODO** alterna entre «Re y ks/D» (o $k_s$ y $D$ en mm) y «Datos tubería» ($Q$ o $v$, $D$, $k_s$, $\nu$).
   - El resultado da el régimen, la zona (lisa, transición o rugosa), $f$ con el método de Ajustes y la tabla de los 4 métodos con su diferencia respecto a Colebrook-White.
   - La memoria trae la tabla de iteraciones de Colebrook-White.
   - F2 **USAR f** devuelve $f$ al formulario que abrió la pantalla.
4. **Flujos externos (FLUJOS):** avisa que esos temas están en el programa FLUJOS.
5. **Biblioteca:** materiales, accesorios y sumador, fluido por defecto (agua o aire; el aire va a «rho y nu del aire»), diámetros comerciales y tu lista propia.
6. **Mis casos:** hasta 20 casos, compartidos con FLUJOS. `enter` carga y recalcula, F3 borra. Los casos de FLUJOS aparecen con «>» y piden abrir FLUJOS.
7. **Ajustes:**
   - método de $f$, $g$, $\gamma$, $\nu$, decimales, tolerancia, presión de vapor, límites de los avisos;
   - $\rho$ y $\nu$ del aire, empuje con aire, $C_d$ de vertedores (0,6), km/h por nudo (1,85) y convención del manómetro.
8. **Ayuda:** siete temas de tuberías, «Factor de fricción f», **Casos del curso** (21 ejercicios de tuberías más F-01 a F-05) y, en la entrada 10 (`▲` desde la primera), «Acerca de» con la RAM libre.

### FLUJOS

**Unidades:** SI (m, N, Pa, kg/m³). La velocidad se puede dar en m/s, km/h o nudos. El caudal de los vertedores y del Venturi, en l/s o m³/s; los diámetros del Venturi y del chorro, en mm.

1. **Arrastre y sustentación.**
   - En los formularios: «Fluido» (*Aire (Ajustes)*, *Agua* o *Manual*) llena $\rho$ y $\nu$. F1 **CD** abre el catálogo y devuelve $C_D$ y la figura; escribir el número de la figura también pone su $C_D$. Si no tecleas el área $A$, se calcula con la fórmula de la figura y las dimensiones.
   - **AR-1** fuerza $F_D$ o $F_L$; **AR-2** velocidad terminal (en agua pide el volumen para el empuje); **AR-3** estructura de hasta 6 cuerpos, con su cota $y$ (F2 **ESQUEMA** dibuja las fuerzas).
   - **AR-4** vuelo nivelado, en dos pasos: sin «CD alas» da el $C_L$ necesario; lee $\alpha$ y $C_D$ en la gráfica del perfil, escríbelos y vuelve a calcular.
   - **Placa plana y Stokes.**
   - Avisos: $Re < 10^4$, posible crisis de arrastre y $Re < 1$ (se usa Stokes).
2. **Vertedores y orificios.** Las cotas se miden desde una misma referencia: el vértice, la cresta o el **centro** del orificio.
   - Elemento simple: dado $H$ da $Q$ y dado $Q$ da $H$; con el nivel aguas arriba da la cota de la cresta.
   - Estructura compuesta: hasta 8 elementos con «cantidad ×»; dado el nivel da el caudal por elemento y el total, y dado el caudal da el nivel. F2 **ESQUEMA**.
   - Perfil de velocidades: $v = k\,y^n$ o tabla de puntos (Simpson).
   - Aguas abajo: $v$, $E$, $Fr$ y los tirantes alternos.
3. **Canales y medición.**
   - Venturi y manómetro, con convención física $(S-1)\gamma h$ o la del examen 2025, $S\gamma h$.
   - Salto hidráulico, dado $y_1$ o dado $y_2$.
   - Chorro desde un tubo: caudal con la tubería tipo B y luego la trayectoria; opción de energía de salida.
   - Placa plana y Stokes.
4. **Coeficientes de arrastre (CD):** lista con miniaturas; `enter` abre la ficha con la ilustración 3D.
   - Las flechas ▲▼ pasan de figura.
   - F2 **MARCAR** y F3 **COMPAR.** comparan hasta 3 figuras; F4 **RANKING** las ordena por $C_D$.
   - En la ficha: F3 **EDITAR** (guarda un $C_D$ propio; DEFECTO restaura el del catálogo) y F4 **TABLA** ($C_D$ por parámetro, con los vecinos).
5. **Mis casos**, 6 **Ajustes**, 7 **Ayuda:** temas de arrastre, vertedores y canales, erratas del material, **Casos del curso** (AR-01 a AR-06, VE-01 a VE-08, EX-01 a EX-03) y «Acerca de».

### Advertencias que puede mostrar

- **Tuberías:** régimen laminar o de transición; $k_s/D > 0{,}05$; fuera del rango de Swamee-Jain; velocidad alta o baja; $h_m > 0{,}3\,h_f$; $L/D > 4000$; presión negativa o imposible; la iteración del curso no convergió; $k_s$ negativo.
- **Arrastre:** $Re$ fuera de la tabla, crisis de arrastre, flujo lento; el cuerpo flota ($W \le B$).
- **Vertedores:** orificio con el nivel bajo su borde superior, $H$ mayor que la altura del vertedero, elementos sin agua; $E < E_{min}$.
- **Canales:** $Fr_1 \le 1$ (no hay salto); recordatorio del caudal del Venturi.

## 5. Desinstalar

En la calculadora: `2nd` `+` (MEM) › `2:Mem Management/Delete`.

1. Borra `PERDIDAS` y `FLUJOS` en **Prgm**.
2. Borra `PERDIDA0`, `PERDIDA1`, `FLUJOS0`, `FLUJOS1`, `PERDTXT`, `PERDGFX`, `PERDCFG` y `PERDCAS` en **AppVars**.

Borrar `PERDCAS` elimina tus casos guardados. Para quitar solo FLUJOS, borra `FLUJOS`, `FLUJOS0`, `FLUJOS1` y `PERDGFX`. Las librerías (`GRAPHX`, `FILEIOC`, `LibLoad`, etc.) bórralas solo si ningún otro programa las usa.

## 6. Si algo falla

| Síntoma | Qué hacer |
|---|---|
| `ERROR: INVALID` al ejecutar desde `prgm` | El sistema 5.8.4 bloquea los programas nativos: lánzalos desde el menú de arTIfiCE (`prgm` › `A`). |
| Al pulsar `A` no aparece el menú de arTIfiCE | Vuelve a enviar `arTIfiCE_v2.1.8xp` a la **RAM**. Si se reinició la RAM y no estaba archivado, se perdió. |
| `Need LibLoad` o un mensaje sobre librerías | Envía `clibs.8xg`. |
| Error al lanzar, o falta `PERDIDA0/1` o `FLUJOS0/1` | Envía los `.8xv` del programa; tienen que estar el lanzador y sus AppVars. |
| «Falta el archivo PERDTXT … o es de otra versión» | Envía el `PERDTXT.8xv` de la v2.0 (la v2.0 no usa el de la v1.0). |
| «Falta PERDGFX: sin ilustraciones» | Envía `PERDGFX.8xv`. Todo lo demás funciona sin él. |
| «Poca RAM libre» al abrir, o el programa no arranca | Archiva o borra programas y variables grandes: hacen falta unos 85 KB de RAM libre antes de abrirlo. |
| «Archivo de ajustes dañado» o «Archivo de casos dañado» | El programa empieza con valores por defecto o con la lista vacía y sigue funcionando. Si se repite, borra `PERDCFG` o `PERDCAS`. |
| Un caso de Mis casos dice «Este caso se abre en…» | Es del otro programa: ábrelo desde PERDIDAS o desde FLUJOS. |
| TI Connect CE no ve la calculadora (Code 39) | Instala TI Connect CE 6.1 o posterior. |
| «Calculadora ocupada» en TI Connect CE | Sal del programa y de arTIfiCE hasta la pantalla principal y repite. |
| Un resultado no coincide con un PDF | Revisa Ayuda › Erratas del material y los Ajustes (método de $f$, convención del manómetro, $C_d$, empuje con aire). |

## 7. Para compilar y probar (en el PC de Adrián)

El código está en `src/`: `hydro/` es el motor en C puro (`hydro.c` tuberías, `drag.c` arrastre, `weir.c` vertedores, `chan.c` canales), `ui/` la interfaz y `data/` las tablas. Los dos programas salen del mismo código: `makefile` compila PERDIDAS y `flujos/makefile` compila FLUJOS con `-DPROG_FLUJOS`. Se compila desde la unión sin espacios `C:\dev\ti84`, porque la carpeta de OneDrive tiene espacios. `flujos/src` y `flujos/obj` también son uniones.

```bash
sh tools/build_all.sh
```

Genera `bin/PERDTXT.8xv` y `bin/PERDGFX.8xv` y compila PERDIDAS y FLUJOS con CEdev v15.0. Las ilustraciones se regeneran con `python -I tools/gen_gfx.py`; tarda un par de minutos.

```bash
sh tools/run_pc_tests.sh
```

Corre las pruebas del PC: casos dorados en `float` y `double`, 750 + 625 casos aleatorios contra los oráculos de Python e interfaz simulada de los dos programas con prueba de estrés.

```bash
python -I tools/cemu_golden.py
```

Corre los casos dorados dentro del eZ80 emulado (recompila `TGOLDEN` solo). Necesita el ROM en `C:\dev\tools\CEmu\ti84ce.rom`.

```bash
python -I tools/cemu_ui.py --check
```

```bash
python -I tools/cemu_ui.py --flujos --check
```

```bash
python -I tools/cemu_ui.py --migr --check
```

Corren la regresión de pantallas en CEmu: PERDIDAS, FLUJOS y la migración con los archivos 1.0 reales de la calculadora (`respaldo_calc/`). Sin `--check` vuelven a capturar las pantallas. `python -I tools/cemu_sheet.py` arma la hoja de contacto del catálogo.

Los resultados de todas las pruebas están en `INFORME_PRUEBAS.md`.
