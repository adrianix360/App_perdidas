# Informe de pruebas: PERDIDAS y FLUJOS en la TI-Nspire CX II CAS (v1.1 Nspire)

Port a Lua 5.1 de la app de la TI-84 (v2.1). Pruebas en el PC con Lua 5.1.5 y un mock estricto de la API Nspire; `bash tools/run_tests.sh` corre todo (9 suites + lista de verificación).

## Suites

| Suite | Comprobaciones | Qué cubre |
|---|---|---|
| `test_core` | 339 casos dorados, 750 + 625 aleatorios, 500 + 500 secante, 71 expr/numfmt, datos | núcleo numérico, `expr`, `numfmt`, tablas |
| `test_ui` | 223 | teclas, widgets, memoria de cálculo, figuras, gráfica |
| `test_perdidas` | 430 | pantallas de PERDIDAS, Mis casos, Ajustes, store |
| `test_flujos` | 399 | pantallas de FLUJOS, catálogo CD, casos del curso |
| `test_nav` | 424 | menú inicial, toolpalette, clics, ciclo de vida, on.save/on.restore, resize |
| `test_smoke` | humo | arranque y sandbox de la API |
| `test_examenes` | 162 | ejercicios de examen con los motores existentes, VE-8 (tanques acoplados), potencia de AR-1, AR-5 (Magnus), EX-1 con aire, Mis casos y store |
| `test_statics` | 491 | estática de fluidos E1 a E6 (motor y pantallas) |
| `test_dyn` | 291 | dinámica de fluidos D1 a D4 (motor y pantallas) |
| `check_checklist` | 557 filas | cada ítem de la v2.1 ligado a una aserción; 0 sin cobertura |

## Resultados numéricos frente al C en double

- **Dorados:** 339 filas; 328 pasan, 11 pasan por redondeo, 0 fallan, 0 difieren del C compilado en `double`.
- **Aleatorios:** oráculo 1 (f, hf, Qmax, D): 750 filas, 1000 comparaciones, 0 fallos (peor error relativo 6.98e-06 en Qmax, criterio de parada del curso; el resto menor de 4e-13). Oráculo 2 (v2.0): 625 filas, 0 fallos (peor 3.1e-11).
- **Secante:** 250 casos tipo B x 9 variantes y 250 casos tipo D x 8 variantes, 0 fallos (tipo B: 4 a 5 vueltas medias frente a 24 del método del curso).

## Decisiones de tolerancia

- **Stokes en Re = 1:** en `double` Re sale 1.0000000000000002; se compara con tolerancia 1e-9 (aviso de `drag_re_warn` y de la memoria), como el `float` de la TI-84. `test_flujos` vuelve a exigir «Stokes válido».
- **Froude = 1:** mismo criterio (1e-9) en el salto hidráulico.
- **Placa plana, 1 vs 2 caras:** AR-06 mixto da 0.3721 N con una cara y 0.7443 N con dos (F = Cf q A x caras, como `drag_plate` del C).

## Fallos del C encontrados y corregidos en el port (F4/F5)

- `drag_load`: los indicadores de «tiene valor» (trackers `s*`) de los cuerpos no se restauraban al cargar un caso.
- Rutas con resultados sin inicializar (variables de memoria que el C dejaba con basura) ahora arrancan en un valor definido.
- `form_run`: se usaba `fm.n` sin recalcularlo al cambiar el formulario (estructura con N cuerpos); ahora se actualiza en `set_form`.
- Maqueta por medida real (`gc:getStringHeight`) en lugar de alturas fijas.

## Prueba en la calculadora real (23 nov 2026, TI-Nspire CX II del usuario)

Comprobado: menú de inicio, caso A del curso, toolpalette (tecla `menu`), CALC con hT = 19.76738 m (coincide con el dorado P-02) y GRÁFICO. Salieron ajustes de maqueta que ya se corrigieron en el código (tamaños de fuente, alturas de fila, barra de acciones y cuadros de alerta).

Segunda prueba (misma fecha, maqueta nueva): FLUJOS › Coeficientes CD muestra la lista con miniaturas 3D y la figura de detalle; la línea de mensajes se ve completa y las etiquetas de la barra de acciones caben.

## Pendiente

- Uso prolongado por Adrián en clase (todas las pantallas se probaron en el simulador; en el equipo real se probaron las de arriba).
