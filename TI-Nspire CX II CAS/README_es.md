# PERDIDAS y FLUJOS en la TI-Nspire CX II CAS

Dos programas, reunidos en un solo documento para la calculadora TI-Nspire CX II CAS, del curso IC-0605 Mecánica de Fluidos (UCR). Resuelven los ejercicios del curso y muestran cada resultado con su **memoria de cálculo paso a paso**: datos, fórmula, sustitución, resultado, iteraciones y advertencias.

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

Versión 1.0 Nspire (basada en la v2.1 de la TI-84). Autor del encargo: Adrián Castro Ramírez.

---

## 1. Requisitos

| Qué | Detalle |
|---|---|
| Calculadora | **TI-Nspire CX II** o **CX II CAS**, con cualquier sistema operativo 5.x o 6.x. **No necesita jailbreak.** |
| Lenguaje | Lua (API de scripting de los documentos `.tns`). |
| PC (para instalar) | Chrome con **TI-Nspire CX II Connect** (https://nspireconnect.ti.com), o el programa **TI-Nspire CX Student Software** / **Teacher Software**. |

## 2. Archivo

Un solo archivo: `instalacion/PerdidasFlujos.tns`. Contiene los dos programas (PERDIDAS y FLUJOS), las memorias de cálculo, la ayuda y las ilustraciones del catálogo.

## 3. Instalación

**Con TI-Nspire CX II Connect (Chrome):**

1. Conecta la calculadora al PC con el cable USB y abre https://nspireconnect.ti.com en Chrome.
2. Pulsa **CONNECT TO CALCULATOR**, luego **TRANSFER FILE** › **TO CALCULATOR** y elige `PerdidasFlujos.tns`.
3. El documento queda en **Mis documentos**.

**Con TI-Nspire CX Student/Teacher Software:** abre el programa, conecta la calculadora y arrastra `PerdidasFlujos.tns` al panel de la calculadora (o usa el Explorador de documentos).

**Abrir la app:** `home` › **Mis documentos** › **PerdidasFlujos**. Aparece el menú inicial: PERDIDAS, FLUJOS o Salir.

## 4. Uso

### Teclas (TI-84 y Nspire)

| TI-84 Plus CE | TI-Nspire | Acción |
|---|---|---|
| flechas | flechas (touchpad) | se mueven; ◀ ▶ cambian las opciones `< >` |
| `enter` | `enter` | acepta y pasa al campo siguiente; en el último campo, calcula |
| `clear` | `esc` | borra lo escrito; si no hay nada, vuelve atrás |
| `del` | `del` | borra un carácter; en un campo opcional, lo vacía |
| `2nd` `▲` / `▼` | `shift`+`tab` / `tab` | página arriba / abajo (primer o último campo) |
| `y=` `window` `zoom` `trace` `graph` (F1 a F5) | tecla `menu` (acciones F1 a F5) o clic con el touchpad en la barra inferior | acciones de la pantalla |
| `mode` | tecla `menu` › **Ajustes** | Ajustes, desde cualquier pantalla |
| `2nd` `,` | tecla `EE` | `E` (×10^), por ejemplo `1.007E-6` |
| `(-)` | `(-)` | signo negativo |
| letras (`alpha`) | letras directas | nombres de casos |
| (no existe) | clic con el touchpad en una fila | elige esa fila de un menú o lista |
| `2nd` `mode` (QUIT) | `esc` en el menú inicial, o su opción Salir | salir |

Los campos aceptan cuentas: `0.5+1.0+4*1.10+10*0.30+3*0.3+3.0` da 12,8.

En todo resultado: F1 **MEMORIA** (cálculo paso a paso; ◀ ▶ cambian de página), F3 **GUARDAR** (en Mis casos) y F5 **VOLVER**.

### Guardado (importante)

**Mis casos** y **Ajustes** se guardan **dentro del documento**. Guarda con `ctrl`+`S` (o, al cerrar, responde **Sí** a guardar). **Sin esto se pierden.** La opción Salir del menú inicial marca el documento como modificado y avisa de guardar.

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
8. **Ayuda:** siete temas de tuberías, «Factor de fricción f», **Casos del curso** (21 ejercicios de tuberías más F-01 a F-05) y, en la entrada 10 (`▲` desde la primera), «Acerca de» con la memoria Lua en uso.

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

## 5. Diferencias con la TI-84

- Un solo documento contiene PERDIDAS y FLUJOS; se elige en el menú inicial.
- En PERDIDAS, **Flujos externos** abre directamente FLUJOS.
- **Salir** avisa que hay que guardar el documento (`ctrl`+`S`).
- **Acerca de** muestra la memoria Lua en uso, en lugar de la RAM libre de la TI-84.
- El catálogo de $C_D$ muestra **6 figuras por página**; el ranking se desplaza con las flechas.
- Los casos guardados en la TI-84 (`PERDCAS`) **no se importan**: hay que volver a guardarlos.
- No hacen falta jailbreak, arTIfiCE, librerías ni AppVars.

## 6. Para compilar y probar (en el PC de Adrián)

```bash
python -I tools/build.py
```

Genera `build/PerdidasFlujos.tns` (se copia a `instalacion/`). Con `--no-tns` solo arma el Lua.

```bash
bash tools/run_tests.sh
```

Compila y corre las 6 suites (`test_core`, `test_ui`, `test_perdidas`, `test_flujos`, `test_nav`, `test_smoke`) y la comprobación de la lista de verificación (`tools/check_checklist.py`). Usa Lua 5.1.5 y Luna en `C:\dev\tools`. `python -I tools/gen_checklist.py` regenera `tests/checklist.md`.

Los resultados están en `INFORME_PRUEBAS.md`.

### Estructura de carpetas

| Carpeta | Contenido |
|---|---|
| `src/core` | motor numérico: tuberías, arrastre, vertedores y canales |
| `src/ui`, `src/scr` | runtime por corrutina, widgets y pantallas de PERDIDAS y FLUJOS |
| `src/data`, `src/gen` | tablas del curso, textos y gráficos generados |
| `tests/` | suites, mock de la API Nspire, tablas doradas y `checklist.md` |
| `tools/` | `build.py`, `run_tests.sh`, generadores y comprobador |
| `instalacion/` | `PerdidasFlujos.tns` listo para enviar |
| `build/` | salida de compilación (no se versiona) |
