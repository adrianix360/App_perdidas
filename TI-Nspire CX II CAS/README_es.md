# PERDIDAS y FLUJOS en la TI-Nspire CX II CAS

Dos programas, reunidos en un solo documento para la calculadora TI-Nspire CX II CAS, del curso IC-0605 Mecánica de Fluidos (UCR). Resuelven los ejercicios del curso y muestran cada resultado con su **memoria de cálculo paso a paso**: datos, fórmula, sustitución, resultado, iteraciones y advertencias.

**PERDIDAS** (pérdidas de energía en tuberías):

- **Tubería simple:** pérdidas dado $Q$ (A), caudal máximo (B), diámetro de diseño (D), bomba o turbina (C), válvula de control (F), calibración de $k_s$ (E) y Darcy-Weisbach contra Hazen-Williams (I).
- **Sistemas en serie y paralelo** con módulos de caudal $h = MQ^2$, hacia adelante y hacia atrás (G), y **gráfica** de la línea de energía y la piezométrica (H).
- **Tres tanques:** 2 a 4 tanques unidos en un nudo, con o sin caudal $Q_T$ que sale del nudo; se ajusta la carga del nudo $Z_J$ con $\Delta Z = 2\,\Delta Q / \sum(|Q|/|H|)$, como en la solución a mano.
- **Calcular f:** solo el factor de fricción, con los 4 métodos comparados y la tabla de iteraciones de Colebrook-White.
- **Bomba en la línea** (A, B, D y G): $(z_1 - z_2) + H_B = h_f + h_m$, con $H_B$ dato o $H_B = \eta P/(\gamma Q)$; con la potencia como dato, $Q$ se halla por bisección.
- **Mi programa original** (Tuberías $h_f + h_L$): cálculo de $Q$ y de $D$ (con bomba opcional), $H$ de bomba, $H$ de turbina y pérdidas totales, más 11 cálculos individuales ($V$, $Q$, $Re$, $e/D$, $f$, $h_f$, $h_L$, $K$, $V^2/2g$ y potencias). Cada paso con 3 decimales, memoria de la primera iteración, tabla de iteraciones y vista fila por fila.
- **Redondeo a mano** (Ajustes): con «Sí (3 dec.)» cada paso de tuberías se redondea a 3 decimales ($|x| < 1$ en científica: 1.116E-2) y todo se muestra así.
- **Biblioteca:** $k_s$, $C_H$, $K$ de accesorios con sumador, fluido (agua y aire) y diámetros comerciales.

**FLUJOS** (flujos externos y medición):

- **Arrastre y sustentación:** fuerza $F_D$ o $F_L$, velocidad terminal con empuje, estructura con varios cuerpos (momento en la base), vuelo nivelado, y placa plana y Stokes.
- **Catálogo de coeficientes de arrastre:** 17 figuras con **ilustración 3D**, tablas por $L/D$, $b/h$ o ángulo, comparar y ranking.
- **Vertedores y orificios:** elemento simple ($H \leftrightarrow Q$ y cota de la cresta), estructura compuesta (nivel ↔ caudal, reparto), perfil de velocidades y energía aguas abajo.
- **Canales y medición:** Venturi con manómetro, salto hidráulico y chorro desde un tubo.

**ESTÁTICA Y DINÁMICA** (v1.1, menú principal › *Estática y dinámica*; ejercicios de los exámenes IC-605):

- **Estática de fluidos:** E1 viscosidad (placa entre paredes, eje y cojinete con par y potencia, bloque en rampa con aceite o fricción seca), E2 manometría en serie, E3 superficies planas (placas vertical, inclinada y compuesta; compuerta circular; compuerta en L con incógnita $H$; reacción en la bisagra), E4 superficies curvas (cuarto de círculo y semicilindro con pernos), E5 flotación y estabilidad ($GM$, cilindro hueco, prisma, barcaza, cubo) y E6 equilibrio relativo (aceleración horizontal y vertical, recipientes en polea).
- **Dinámica de fluidos:** D1 perfiles de velocidad ($Q$, $\alpha$, $\beta$, Simpson sobre $u(y)$ o $u(r)$), D2 continuidad, descarga libre y Bernoulli con presiones en puntos, D3 cantidad de movimiento (codo reductor con anclajes y chorros que sostienen un peso, con la potencia de la bomba) y D4 tanques no permanentes ($Q_e$ y $Q_s(t)$ como expresiones, integración RK4, tiempo de vaciado y nivel de equilibrio).
- **VE-8 Tanques acoplados** (Vertedores y orificios): dos tanques unidos por un orificio sumergido, cada uno con hasta 4 salidas libres (vertedor triangular o rectangular, orificio circular o rectangular) y pared opcional. Se resuelve con $Q_e$ dado, con el caudal de un elemento (incluso 0), o con el nivel de un tanque (p. ej. el borde de rebalse).
- **AR-1** agrega la potencia $P = F_D V$ (W, kW y hp); **AR-5 Balance vertical (Magnus)** da $\omega D/2V$ para leer $C_L$ de la gráfica y concluye si la pelota sube o cae; **EX-1** acepta un fluido distinto del agua (aire).

Los dos programas tienen **Mis casos** (compartidos), **casos del curso** para cargar y estudiar, ayuda y ajustes comunes.

Versión 1.2 Nspire (basada en la v2.1 de la TI-84; la 1.1 agrega estática y dinámica de fluidos, VE-8, AR-5 y la potencia de arrastre; la 1.2 agrega los tres tanques y las Modificaciones JV: bomba en la línea, «Mi programa original» y el redondeo a 3 decimales). Autor del encargo: Adrián Castro Ramírez.

## Ejercicios de examen cubiertos (v1.1)

Cada fila se comprueba contra `tools/oracle_examenes.py` (tolerancia 0,2 %): `tests/test_examenes.lua` para los resueltos con los motores existentes, VE-8, AR-1 y AR-5; `tests/test_statics.lua` y `tests/test_dyn.lua` para las pantallas nuevas.

| Examen / ejercicio | Dónde |
|---|---|
| Vertedores P4 a,c; Parcial 2-2025 P3 a,b | VE-8 (casos del curso VE-09 a VE-12) |
| Final-2025 P1 a,b; P2; P3 a,b; P5; chorro | PERDIDAS (D, B, F, C), sistemas y EX-3 |
| Final-2025 P4 a,b; Parcial 2-2024 P4 b,c | VE-2 y VE-7 |
| Final-2025 P4 c; Parcial 2-2025 P1 | EX-1 (con $S-1$; con aire) |
| Parcial 2-2025 P4 (potencia de arrastre) | AR-1 |
| Parcial 2-2024 P5 (Magnus) | AR-5 (caso del curso AR-07) |
| EPSON P1; P1-2024; P1-2018 P4; P1-2022 P1; P1-2017 P3 | E1 viscosidad |
| P1-2018 P3; P1-2017 P1 | E2 manometría |
| EPSON P2; P1-2022 P2; P1-2017 P2 plana; P1-2018 P2 | E3 superficies planas |
| EPSON P3; P1-2022 P3; P1-2017 P2 curva | E4 superficies curvas |
| EPSON P4; P1-2018 P1; P1-2022 P4; P1-2017 P4 | E5 flotación |
| EPSON P5 b; P1-2018 P5; P1-2022 P5 | E6 equilibrio relativo |
| EPSON P5 a; Parcial 2-2024 P4 a; perfil parabólico | D1 perfiles |
| Varios Ej1; Parcial 2-2024 P2 | D2 continuidad y Bernoulli |
| Parcial 2-2024 P3; Parcial 2-2025 P5 (flyboard) | D3 cantidad de movimiento |
| Parcial 2-2024 P1; Parcial 2-2025 P2; Varios Ej2, tanques de 3 m y 5 m | D4 tanques no permanentes |

---

## 1. Requisitos

| Qué | Detalle |
|---|---|
| Calculadora | **TI-Nspire CX II** o **CX II CAS**, con cualquier sistema operativo 5.x o 6.x. **No necesita jailbreak.** |
| Lenguaje | Lua (API de scripting de los documentos `.tns`). |
| PC (para instalar) | Chrome con **TI-Nspire CX II Connect** (https://nspireconnect.ti.com), o el programa **TI-Nspire CX Student Software** / **Teacher Software**. |

## 2. Archivo

Un solo archivo: `instalacion/PerdidasFlujos.tns`. Contiene los dos programas (PERDIDAS y FLUJOS, con *Estática y dinámica* en el menú de PERDIDAS), las memorias de cálculo, la ayuda y las ilustraciones del catálogo.

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
   - $\rho$ y $\nu$ del aire, empuje con aire, $C_d$ de vertedores (0,6), km/h por nudo (1,85), convención del manómetro y **Redondeo a mano** (No / Sí, 3 decimales en cada paso).
8. **Ayuda:** siete temas de tuberías, «Factor de fricción f», **Casos del curso** (21 ejercicios de tuberías más F-01 a F-05) y, en la entrada 10 (`▲` desde la primera), «Acerca de» con la memoria Lua en uso.
10. **Tres tanques (nudo)** (`▲` `▲` desde la primera opción). Por tanque: nivel $Z$, $L$, $D$, «f dado» (opcional) o $k_s$, y $\sum K$. Además $Q_T$ (sale del nudo; 0 si no hay), $Z_J$ inicial (opcional; si falta, el promedio de los $Z$) y la cota del nudo (opcional, da $p/\gamma$). F2 **EJEMPLO** carga la tarea ($k_s$, $Q_T$ = 60 l/s) o el de la pizarra ($f$ dado). $Q > 0$ va del tanque al nudo. La memoria muestra las tres primeras iteraciones como a mano ($H_i$, $Q_i$, $\Delta Q$, $\Delta Z$, nuevo $Z_J$), la tabla de todas y la última; si el paso de Newton sale del intervalo usa bisección.
11. **Mi programa original** (`▲` desde Salir). Cálculo de $Q$, cálculo de $D$, $H$ bomba, $H$ turbina, pérdidas totales y *Cálculos individuales*. «Vel. salida» suma (o no) $V_s^2/2g$ a la salida libre. En el resultado: F1 **MEMORIA** (primera iteración paso a paso), F2 **TABLA** de iteraciones (si no cabe, cada fila ocupa dos líneas) y F3 **FILAS** (elegir una fila y verla completa). Usa $g$ = 9,81 y $\gamma$ = 9810 como el programa original.
12. **Salir.**

En los tipos A, B y D y en Sistemas, los últimos campos del formulario son la **bomba en la línea**: «Bomba en la línea» Sí, «Dato de la bomba» (potencia $P$ y eficiencia, o carga $H_B$). En B y D el cálculo sigue con $H = (z_1 - z_2) + H_B$; la memoria empieza con la sección BOMBA.

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

Compila y corre las 9 suites (`test_core`, `test_ui`, `test_perdidas`, `test_flujos`, `test_nav`, `test_smoke`, `test_examenes`, `test_statics`, `test_dyn`) y la comprobación de la lista de verificación (`tools/check_checklist.py`). Usa Lua 5.1.5 y Luna en `C:\dev\tools`. `python -I tools/gen_checklist.py` regenera `tests/checklist.md`.

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
