#!/usr/bin/env python
"""Genera tests/checklist.md (fuente de verdad: las filas R(...) de este archivo).

Cada fila: item de la v2.1 -> archivo de test + fragmento literal de la asercion.
Uso: python -I tools/gen_checklist.py [salida]   (por defecto tests/checklist.md)
Luego: python -I tools/check_checklist.py
"""
import os
import sys

N, P, FL, UI, C = ("test_nav.lua", "test_perdidas.lua", "test_flujos.lua", "test_ui.lua",
                   "test_core.lua")
rows = []
cur = ""


def S(sec):
    global cur
    cur = sec


def R(item, f, frag):
    rows.append((cur, item, f, frag))


S("1. Arranque, ciclo de vida y teclas (Nspire)")
R("Menu inicial PERDIDAS / FLUJOS / Salir (3 opciones)", N, "arranque: menu inicial con 3 opciones")
R("Primer cuadro con on.create (SO antiguo)", N, "arranque con on.create (SO antiguo) dibuja el primer cuadro")
R("Primer cuadro sin construction ni create", N, "arranque sin construction/create: dibuja el primer cuadro")
R("Primer cuadro solo con on.paint", N, "arranque solo con on.paint: dibuja el primer cuadro")
R("construction + create no duplican el arranque", N, "construction + create + teclas: un solo arranque")
R("Inicio 1: abre PERDIDAS", N, "PERDIDAS: menu principal")
R("Inicio 2: abre FLUJOS", N, "inicio 2: abre FLUJOS")
R("Inicio 3 Salir: avisa de guardar (ctrl+S)", N, "inicio: Salir avisa de guardar el documento")
R("Inicio: Salir marca el documento (document.markChanged)", N, "inicio: Salir marca el documento como modificado")
R("Inicio: ESC equivale a Salir", N, "inicio: ESC equivale a Salir")
R("Inicio: flechas + ENTER", N, "inicio: flechas + ENTER sobre Salir")
R("Inicio: tecla menu abre Ajustes (MODE)", N, "inicio: tecla menu abre Ajustes")
R("Teclas: flechas, enter, esc/clear, backspace, tab/backtab, charIn, EE y menos U+2212", UI, "getkey: 16 teclas leidas")
R("Teclas: clic en F1..F5 de la barra de acciones", UI, "clic F5")
R("Teclas: toolpalette (menu) con F1..F5 y Ajustes", UI, "toolpalette TRES -> F3")
R("Clic en la barra de acciones (F4) abre Ajustes", N, "clic en la barra (F4) abre Ajustes")
R("Clic en una fila de menu la elige", N, "clic en una fila del menu la elige")
R("Clic fuera de botones no hace nada", N, "clic en el titulo no hace nada")
R("Clic F5 CALC calcula", N, "clic en la barra (F5 CALC) calcula")
R("Toolpalette A: MAT,SUMA K,FLUIDO,CALC f,CALC,Ajustes", N, "toolpalette A: F1..F5 + Ajustes")
R("Toolpalette: MAT (F1)", N, "toolpalette: MAT (F1)")
R("Toolpalette: SUMA K (F2)", N, "toolpalette: SUMA K (F2)")
R("Toolpalette: FLUIDO (F3)", N, "toolpalette: FLUIDO (F3)")
R("Toolpalette: CALC f (F4)", N, "toolpalette: CALC f (F4) abre Calcular f")
R("Toolpalette: CALC (F5)", N, "toolpalette: CALC (F5)")
R("Toolpalette: Ajustes", N, "toolpalette: Ajustes")
R("Toolpalette se re-registra en cada pantalla", N, "toolpalette: Calcular f registra sus acciones")
R("Tecla menu en un formulario abre Ajustes", N, "tecla menu en un formulario abre Ajustes")
R("Resize 320x240 sin errores", N, "{ 320, 240 }")
R("Resize 480x320 sin errores", N, "{ 480, 320 }")
R("Resize en caliente conserva la pantalla", N, "resize en caliente conserva la pantalla")
R("Maqueta medida con gc:getStringHeight", N, "maqueta: una letra mas alta reduce las filas")
R("Maqueta: mensaje y etiquetas de la barra caben", N, "maqueta: las etiquetas de la barra caben en su boton")
R("Error de la corrutina se muestra en pantalla", N, "el error se muestra en pantalla")
R("ENTER reinicia tras un error", N, "ENTER reinicia la app en el menu inicial")
R("F5 (clic) reinicia tras un error", N, "F5 tambien reinicia tras un error")
R("on.save / on.restore: casos de ambos programas + ajustes", N, "on.save: casos de los dos programas y ajustes cambiados")
R("on.restore en app nueva", N, "on.restore: casos y ajustes de vuelta en una app nueva")
R("on.restore antes del primer paint", N, "on.restore antes del primer paint: arranca con datos")
R("on.save tras on.restore: ida y vuelta", N, "on.save tras on.restore: ida y vuelta igual")
R("on.restore con datos invalidos / version futura", N, "on.restore con datos invalidos no rompe")
R("Caso de PERDIDAS restaurado calcula", N, "caso de PERDIDAS restaurado calcula")
R("Caso de FLUJOS restaurado calcula", N, "caso AR-01 restaurado da v terminal")

S("2. Widgets y utilidades (menu, formulario, visor, lista, texto, alerta)")
R("menu_run: scroll, ENTER, digitos, ESC, tab", UI, "menu: tab = pagina abajo")
R("form_run: FF_POS / FF_NONNEG / FF_INT / FF_RANGE / FF_OPT / FF_CHOICE / FF_INFO", UI, "form: FF_RANGE")
R("form_run: expresiones (12.8, coma, e minuscula)", UI, "form: expresion = 12.8")
R("form_run: scroll, backtab/tab", UI, "form: tab = ultimo")
R("view_run: paginas, flechas, F5", UI, "view: tab = pagina abajo")
R("list_pick: ENTER, F1, ESC, vacia", UI, "lista: F1 devuelve el indice actual")
R("text_input: mayusculas, 8 caracteres, ESC", UI, "text_input: maxlen 8")
R("ui_alert: ENTER true, ESC false", UI, "alert: ESC false")
R("expr: gramatica y errores", C, "5. EXPR y NUMFMT")
R("numfmt: formato de numeros", C, "5. EXPR y NUMFMT")
R("Datos (diams, lib, examples, dragcat) consistentes", C, "6. DATOS")

S("3. PERDIDAS - Menu principal (9 opciones)")
R("1 Tuberia simple abre y ESC vuelve", N, "PERDIDAS opcion ")
R("2 Sistemas (serie / paralelo)", P, '"sistemas"')
R("3 Calcular f (solo f)", P, '"calcular f"')
R("4 Flujos externos (FLUJOS) abre FLUJOS", N, "PERDIDAS 4 Flujos externos abre FLUJOS")
R("4 Flujos externos: vuelve a PERDIDAS", N, "FLUJOS desde PERDIDAS: vuelve a PERDIDAS")
R("5 Biblioteca", P, '"biblioteca"')
R("6 Mis casos", P, "mis casos vacio")
R("7 Ajustes", P, '"ajustes"')
R("8 Ayuda / Acerca de", P, '"ayuda"')
R("9 Salir (guardar)", N, "PERDIDAS 9 Salir: guarda y avisa")
R("ESC en el principal pide confirmacion", P, "ESC en el principal pide confirmacion")
R("ESC en el principal: confirmar sale", P, "confirmar salida")
R("ESC en el principal: rechazar", P, "rechazar confirmacion")
R("Tecla menu / F4 abren Ajustes desde el menu", P, "tuberia: menu abre Ajustes")

S("4. PERDIDAS - Tuberia simple (8 entradas: tipos A B D C F E I + f)")
for t, frag in [("A Perdidas dado el caudal", "A tecleado: hT = 19,76 m"),
                ("B Caudal maximo / comprobacion", "B P-03 tecleado: Q = 318,8 l/s"),
                ("D Diametro de diseno", "D P-17 con valvula: 256,8 / 285,75 / 262,38"),
                ("C Bomba o turbina: carga y P", "C P-11: HB = 45,6 m, Pb = 28,9 kW"),
                ("F Valvula de control", "F valvula: Kv = 60,7"),
                ("E Calibrar rugosidad", "E calibracion tecleada"),
                ("I Darcy-W. vs Hazen-Williams (modo hf)", "I modo hf"),
                ("I Darcy-W. vs Hazen-Williams (modo Q)", "I modo Q"),
                ("8 f: factor de friccion", "calcular f tecleado: resultado")]:
    R(t, P, frag)
R("Cada entrada del submenu abre y ESC vuelve", N, "tuberia entrada ")
R("Cada tipo: ESC vuelve al submenu", P, ": ESC vuelve al menu")
R("A: v, hm y p/gamma del resultado", P, "A tecleado: v = 2,29 m/s")
R("A: memoria con los 4 metodos de f", P, "memoria A metodo ")
R("A: memoria laminar (64/Re)", P, "memoria A laminar")
R("B: iteracion del curso", P, "B P-03: iteracion del curso")
R("B: tabla de iteraciones en la memoria", P, "B P-03: memoria con tabla de iteraciones")
R("B: secante / arranque con C_H", P, "B secante con C_H de arranque")
R("B: memoria de la secante", P, "B secante: memoria")
R("C: cota piezometrica", P, "C P-11: cota piezometrica 935,6")
R("C: memoria", P, "C: memoria")
R("D: Kv de la valvula", P, "D P-18: Kv = 60,7")
R("D: memoria", P, "D: memoria")
R("D: grafica LE/LP", P, "D: grafica")
R("D con lista propia de diametros", P, "D con lista propia: resultado")
R("D con lista propia: la memoria la nombra", P, "D con lista propia: la memoria nombra la lista")
R("D con lista propia vacia: aviso", P, "D con lista propia vacia avisa")
R("E: memoria", P, "E: memoria")
R("I: memoria", P, "I: memoria")
R("Validacion: calcular sin datos", P, "A: calcular sin datos avisa")
R("Validacion: D = 0", P, "A: D = 0 rechazado")
R("Validacion: expresion mal formada (3+)", P, "A: 3+ rechazado")
R("Validacion: division entre cero", P, "A: 1/0 rechazado")
R("Validacion: ks negativa", P, "A: ks < 0 rechazado")
R("F1 MAT (material)", P, "biblioteca: material elegido")
R("F2 SUMA K", P, "sumador: PVC 200 mm da Suma K = 6.7")
R("F3 FLUIDO", P, "fluido: aviso")
R("F4 CALC f con cursor en 'f dado'", N, "A: F4 CALC f con el cursor en 'f dado' abre Calcular f")
R("F4 AJUSTES en D", N, ": F4 = AJUSTES")
R("F4 AJUSTES en E", N, ": F4 = AJUSTES")
R("F4 AJUSTES en I", N, ": F4 = AJUSTES")
R("F5 CALC", P, "A: calcular sin datos avisa")
R("Resultado F1 MEMORIA", P, ': memoria sin plantillas"')
R("Resultado F2 GRAFICO (A B C D F)", P, ": grafica LE/LP")
R("Resultado F2 GRAFICO no aplica a E/I", P, ": grafico no aplica a E/I")
R("Resultado F3 GUARDAR", P, "guardar: pide nombre")
R("Resultado F5 VOLVER", P, ": se vuelve al menu inicial")
R("Calcular f desde A: USAR f devuelve f", N, "Calcular f: USAR f copia f al formulario A")
R("Calcular f desde A: el campo recibe f", N, "Calcular f: A recibe f = 0.0264")

S("5. PERDIDAS - Sistemas serie/paralelo (G) y grafica (H)")
R("Formulario del sistema, 2 tubos en serie", P, "red: 2 tubos en serie tecleados")
R("Hacia adelante (dado H)", P, "S-01: Q total de la pantalla = motor")
R("Hacia atras (dado el Q de un tubo)", P, "S-04: hacia atras da H necesaria")
R("Comprobacion de nudos y rutas", P, ": comprobacion de nudos y rutas")
R("Memoria (modulos de caudal)", P, ": memoria")
R("Secciones CAUDAL Y CARGA / REPARTO", P, "S-04: secciones de la memoria")
R("Grafica LE/LP del sistema (H)", P, ": grafica")
R("F1 CALC f exige cursor en f dado", P, "red: CALC f exige cursor en f dado")
R("Aviso: tubo sin f ni ks", P, "red: aviso sin f ni ks")
R("Aviso: falta el tubo conocido", P, "red: hacia atras sin tubo conocido avisa")
R("Aviso: falta la carga H", P, "red: sin carga H avisa")
R("Motor de red", P, "S-01 motor")
R("Grafica LE/LP (graph_run)", UI, "graph: dibuja")
R("Grafica sin tanque 2 / 0 tramos", UI, "graph: 0 tramos")

S("6. PERDIDAS - Calcular f (solo f)")
R("Modo Re y ks/D: resultado", P, "calcular f tecleado: resultado")
R("Tabla de los 4 metodos", P, "calcular f: tabla de los 4 metodos")
R("Motor f(20000, 1e-4) = 0.0264", P, "motor f(20000,1e-4) = 0,0264")
R("Memoria con tabla de iteraciones de Colebrook", P, "calcular f: memoria con iteraciones")
R("F2 MODO pasa a Datos tuberia", P, "calcular f: F2 pasa al modo datos de tuberia")
R("F1 MAT solo en modo datos", P, "calcular f: MAT solo en modo 2")
R("F3 FLUIDO solo en modo datos", P, "calcular f: FLUIDO solo en modo 2")
R("Metodo de f: Colebrook-White", P, '"calcular f: metodo "')
R("Metodo de f: Swamee-Jain", P, '"calcular f: metodo "')
R("Metodo de f: Haaland", P, '"calcular f: metodo "')
R("Metodo de f: Goudar-Sonnad", P, '"calcular f: metodo "')
R("F2 USAR f devuelve f al formulario", N, "Calcular f desde A: el resultado ofrece USAR f")

S("7. PERDIDAS - Biblioteca")
R("1 Materiales (lista)", P, "biblioteca: materiales")
R("1 Material elegido: ks y C_H a los formularios", P, "material: ks = 0.15 y C_H = 130 en los formularios")
R("2 Accesorios y sumador", P, '"sumador"')
R("Sumador: AGREGAR", P, "sumador: AGREGAR abre la lista de accesorios")
R("Sumador: accesorio agregado", P, "sumador: accesorio agregado")
R("Sumador: OTRO", P, "sumador: OTRO agrega linea libre")
R("Sumador: QUITAR", P, "sumador: PVC 200 mm da Suma K")
R("Sumador: CONJUNT. (conjuntos del curso)", P, "sumador: conjuntos del curso")
R("Sumador: USAR", P, "sumador: aviso de uso")
R("3 Fluido por defecto", P, "biblioteca: fluido")
R("Fluido: agua 20 C a Ajustes", P, "fluido agua 20 C: nu, gamma y pv a Ajustes")
R("Fluido: aire por defecto", P, "fluido aire en Ajustes")
R("Fluido: nu del curso", P, "fluido de curso: solo nu")
R("4 Diametros comerciales", P, '"diametros"')
R("Lista propia de diametros (15 campos)", P, "lista propia: formulario")
R("Lista propia guardada y marca cambios", P, "lista propia: marca cambios")
R("Lista propia persiste en el documento", P, "persistencia: lista propia de diametros")
R("Cada entrada de Biblioteca abre y vuelve", N, "biblioteca entrada ")
mats = ["PVC y CPVC", "PEAD", "Vidrio", "Asbesto cemento", "Fibra vidrio", "Acero comercial",
        "Concreto centrifug.", "H. fundido asfalt.", "Hierro fundido", "Hierro galvanizado",
        "Arcilla vitrificada", "Hierro ductil", "Concreto", "Acero liso (C_H)",
        "Acero soldado (C_H)", "Acero bridas (C_H)", "Concreto liso (C_H)", "Concreto rug. (C_H)",
        "Cobre/laton (C)", "Acero inox. (C)", "Hule alisado (C)", "Hierro forjado (C)",
        "Hierro fundido (C)", "Duela de madera (C)"]
for i, nm in enumerate(mats):
    R("Material %d de 24: %s (ks y C_H)" % (i + 1, nm), P, '"material " .. m.name .. ": ks"')
for i in range(30):
    R("Accesorio %d de 30 (lista de accesorios)" % (i + 1), P, "sumador: los 30 accesorios")
for i, nm in enumerate(["PVC 200 mm (pag. 51)", "Examen 2025 P1", "Examen 2019 P4", "Examen 2017 P4",
                        "Examen 2018 P1a", "Examen 2018 P1b"]):
    R("Conjunto del curso %d: %s" % (i + 1, nm), N, '"conjunto " .. pr.name .. ": Suma K')
wat = ["Agua 5 C", "Agua 10 C", "Agua 15 C", "Agua 20 C", "Agua 25 C", "Agua 30 C", "Agua 40 C",
       "Curso 2025 T4", "Curso 2017-2019", "Curso 2024 P1", "Curso ej. 4", "Curso hojas",
       "Aire (curso)", "Aire 15 C", "Aire 20 C"]
for i, nm in enumerate(wat):
    R("Fluido %d de 15: %s" % (i + 1, nm), N, '"fluido " .. w.name .. ": valores a Ajustes"')
for i, nm in enumerate(["PVC examen 2025", "Nominal 2024 200-500", "Pract.3/Ej.5 150-400",
                        "Practica 2 50-300", "General 50-1500"]):
    R("Lista de diametros %d: %s" % (i + 1, nm), P, '"diametros: lista "')

S("8. PERDIDAS - Mis casos (compartidos)")
R("Lista vacia", P, "mis casos vacio")
R("Guardar: pide nombre", P, "guardar: pide nombre")
R("Guardar: marca cambios", P, "guardar: marca cambios")
R("Guardar: nombre repetido pide confirmar", P, "guardar: nombre repetido pide confirmar")
R("Guardar: nombre vacio no se acepta", P, "guardar: nombre vacio no se acepta")
R("Guardar: maximo 8 caracteres", P, "nombre: maximo 8 caracteres")
R("Guardar: limite de 20 casos", P, "guardar: limite de 20 casos")
R("Lista: nombres, tipo y contador (Casos: n de 20)", P, "Mis casos: lista")
R("ENTER carga y calcula (A)", P, "Mis casos: ENTER carga y calcula (A)")
R("Cargar cada tipo de caso", P, "Mis casos: carga el caso ")
R("F3 BORRAR pide confirmacion", P, "borrar: pide confirmacion")
R("BORRAR: ESC cancela", P, "borrar: ESC cancela")
R("BORRAR elimina el caso", P, "borrar: elimina el caso")
R("Caso de FLUJOS marcado con >", P, "Mis casos: caso de FLUJOS marcado con >")
R("Caso de FLUJOS: se abre en FLUJOS", P, "Mis casos: un caso de FLUJOS se abre en FLUJOS")
R("on.save / on.restore de los casos", P, "on.restore: casos de vuelta")
R("Casos invalidos descartados", P, "on.restore: casos invalidos descartados")
R("Caso restaurado se carga y calcula", P, "caso restaurado se carga y calcula")

S("9. Ajustes (los 19 campos)")
R("Formulario de Ajustes", P, "ajustes: formulario")
R("Metodo de f (4 metodos)", N, "Ajustes: metodo, g, gamma, nu")
R("g", N, "Ajustes: metodo, g, gamma, nu")
R("gamma", N, "Ajustes: metodo, g, gamma, nu")
R("nu", N, "Ajustes: metodo, g, gamma, nu")
R("Decimales", N, "Ajustes: decimales, tolerancia, presion de vapor")
R("Tolerancia iter.", N, "Ajustes: decimales, tolerancia, presion de vapor")
R("Presion de vapor", N, "Ajustes: decimales, tolerancia, presion de vapor")
R("v minima aviso", N, "Ajustes: v minima, v maxima, L/D despreciable, hm/hf")
R("v maxima aviso", N, "Ajustes: v minima, v maxima, L/D despreciable, hm/hf")
R("L/D despreciable", N, "Ajustes: v minima, v maxima, L/D despreciable, hm/hf")
R("Aviso hm/hf", N, "Ajustes: v minima, v maxima, L/D despreciable, hm/hf")
R("Re laminar <", N, "Ajustes: Re laminar, Re turbulento")
R("Re turbulento >", N, "Ajustes: Re laminar, Re turbulento")
R("rho del aire", N, "Ajustes: rho y nu del aire, empuje con aire")
R("nu del aire", N, "Ajustes: rho y nu del aire, empuje con aire")
R("Empuje con aire", N, "Ajustes: rho y nu del aire, empuje con aire")
R("Cd vertedores", N, "Ajustes: Cd vertedores, km/h por nudo, manometro")
R("km/h por nudo", N, "Ajustes: Cd vertedores, km/h por nudo, manometro")
R("Manometro (convencion)", N, "Ajustes: Cd vertedores, km/h por nudo, manometro")
R("F5 LISTO guarda g y decimales", P, "ajustes: g y decimales guardados")
R("Rango invalido (g = 50)", P, "ajustes: g = 50 fuera de rango")
R("Re lam > Re turb avisa", P, "ajustes: Re lam > Re turb avisa")
R("Valor valido sale", P, "ajustes: valor valido sale")
R("F1 DEFECTO pide confirmacion", P, "ajustes: DEFECTO pide confirmacion")
R("DEFECTO restaura valores", P, "ajustes: valores por defecto")
R("Ajustes persisten en on.save/on.restore", P, "ajustes: on.restore devuelve metodo y decimales")
R("Ajustes: los 19 persisten en on.save", N, "on.save conserva los 19 ajustes")
R("Ajustes: validador de rangos (store)", P, "store: g = 0 invalido")
R("Ajustes: version futura ignorada", P, "restore: version futura ignorada")
R("Cd propio del catalogo persiste", P, "restore: Cd propio")
R("Ajustes desde FLUJOS (MODE y opcion 6)", FL, "Ajustes (6) y MODE abren la pantalla de ajustes")

S("10. Ayuda y Acerca de (PERDIDAS)")
for i, nm in enumerate(["Uso y teclas", "Tipos de problema", "Formulas", "Potencia bruta y neta",
                        "Suma K y fuentes de datos", "Advertencias", "Erratas del material",
                        "Factor de friccion f"]):
    R("Tema %d: %s" % (i + 1, nm), P, '"ayuda tema "')
R("Casos del curso (cargar)", P, "ayuda: casos del curso")
R("Acerca de (version y memoria Lua)", P, "ayuda: acerca de")
R("Cada entrada de Ayuda abre y ESC vuelve", N, "ayuda entrada ")
R("Todos los temas de ayuda (11) abren", UI, '"help_topic "')
R("PERDTXT valido y 55 programas de memoria", UI, "PROG_COUNT")
R("Todas las memorias corren sin error y <= 40 columnas", UI, "todos los programas corrieron")

S("11. Casos del curso de PERDIDAS (23 ejercicios + F-01..F-05)")
exn = ["P-02 PVC 200 mm, p (A)", "P-01 DW vs HW, PVC (I)", "P-03 Pres. ejemplo 1 (B)",
       "P-05 Pres. practica 1 (B)", "P-07 Examen 2018 P1a (B)", "P-09 Tarea 4 P3a (B)",
       "P-10 Tarea 4 P3b (I)", "P-11 Pres. ejemplo 4 (C)", "P-12 Examen 2024 P2 (C)",
       "P-15 Pres. ejemplo 5 (D)", "P-17 Examen 2025 P1 (D)", "P-18 Examen 2025 P2 (F)",
       "P-19 Examen 2025 P3a (C)", "P-20 Examen 2025 P3b (C)", "P-21 Examen 2024 P1 (D)",
       "P-25 Pres. ejemplo 6 (E)", "P-26 Ejercicio 2, HW (D)", "P-27 Ejercicio 2, HW (B)",
       "S-01 Examen 2024 P3 (G)", "S-02 Examen 2025 P5 (G)", "S-03 Examen 2018 P3 (G)",
       "S-04 Examen 2017 P5 (G)", "S-05 Tarea 4 P4 (G)",
       "F-01 f: Re 20000, ks/D 1E-4 (ej. 3a)", "F-02 f: Re 2E5, ks/D 1.5E-4 (ej. 3b)",
       "F-03 f: 200 l/s, 285.75 mm (2025 P2)", "F-04 f: Re 455180, PVC 200 mm",
       "F-05 f: laminar, 20 mm, 0.02 l/s"]
for nm in exn:
    R("Caso " + nm + ": resultado", P, ": resultado contiene '")
    R("Caso " + nm + ": memoria sin plantillas", P, ": memoria sin plantillas")
R("Lista de casos del curso", P, "ayuda: casos del curso")

S("12. FLUJOS - Menu principal y submenus")
R("Titulo y 8 opciones", FL, "menu principal: ")
R("1 Arrastre y sustentacion (6 entradas)", FL, "submenu ")
R("2 Vertedores y orificios (4 entradas)", FL, "submenu ")
R("3 Canales y medicion (4 entradas)", FL, "submenu ")
R("4 Coeficientes de arrastre (CD)", FL, "catalogo: lista")
R("5 Mis casos", FL, "Mis casos: lista")
R("6 Ajustes", FL, "Ajustes (6) y MODE abren la pantalla de ajustes")
R("7 Ayuda / Acerca de (6 entradas)", FL, "submenu ")
R("8 Salir", FL, "Salir (8) termina flujos_main")
R("ESC pide confirmacion", FL, "ESC: pregunta si desea salir")
R("ESC cancela la salida", FL, "ESC cancela la salida")
R("ENTER confirma la salida", FL, "ENTER confirma la salida")
R("Cada opcion de FLUJOS abre y ESC vuelve", N, "FLUJOS opcion ")
R("Cada entrada de los submenus abre y ESC vuelve", N, " entrada ")
R("Entrada AR-1 Fuerza FD/FL", FL, "AR-1: resultado FD")
R("Entrada AR-2 Velocidad terminal", FL, "AR-01: v terminal 4.922 m/s")
R("Entrada AR-3 Estructura: varios cuerpos", FL, "AR-3: formulario")
R("Entrada AR-4 Vuelo nivelado", FL, "AR-04 paso 1: CL = 0.8831")
R("Entrada Placa plana y Stokes", FL, "Canales 4: placa plana y Stokes")
R("Entrada Catalogo de coeficientes CD", FL, "catalogo: lista")
R("Entrada VE-1,2,5 Vertedero u orificio", FL, "VE-03: H = 0.4569 m")
R("Entrada VE-4 Estructura compuesta", FL, "VE-01: Q total = 0.7405 m3/s")
R("Entrada VE-6 Perfil de velocidades", FL, "VE-07: Q = 1.3333 m3/s")
R("Entrada VE-7 Aguas abajo: energia", FL, "VE-7: memoria")
R("Entrada EX-1 Venturi y manometro", FL, "EX-1: D2 >= D1 avisa")
R("Entrada EX-2 Salto hidraulico", FL, "EX-02: memoria con cantidad de movimiento")
R("Entrada EX-3 Chorro desde un tubo", FL, "EX-03: memoria con el tipo B")
R("Entrada EX-4 Placa plana y Stokes", FL, "Canales 4: placa plana y Stokes")
R("Ayuda: arrastre, vertedores, canales, erratas", FL, "FLUJOS: ayuda de arrastre, vertedores, canales y erratas")
R("Ayuda: erratas de la v2.0", FL, "erratas de la v2.0 en la ayuda")
R("Ayuda: Casos del curso (cargar)", FL, "lista de casos: primer nombre")
R("Ayuda: Acerca de", FL, "Ayuda 6: Acerca de")

S("13. FLUJOS - Arrastre y sustentacion (AR-1..AR-4, Stokes)")
R("AR-1: resultado FD", FL, "AR-1: resultado FD")
R("AR-1: modo sustentacion FL", FL, "AR-1: modo sustentacion")
R("AR-1: sin figura ni area avisa", FL, "AR-1: sin figura ni area avisa")
R("AR-1: memoria", FL, "AR-1: memoria")
R("AR-2: v terminal en aire (AR-01)", FL, "AR-01: v terminal 4.922 m/s")
R("AR-2: memoria", FL, "A = pi D^2/4")
R("AR-2: agua con empuje (AR-03a)", FL, "AR-03a: A = D^2 da 1.580 m/s")
R("AR-2: guardar y recargar", FL, "AR-2 cargado desde Mis casos da el mismo resultado")
R("AR-2: W <= B no flota (aviso)", FL, "W < B: mensaje, sin cerrar")
R("AR-3: formulario de estructura", FL, "AR-3: formulario")
R("AR-3: momento en la base y ycp (AR-02)", FL, "ycp = M/F")
R("AR-3: F1 CD fuera de un cuerpo avisa", FL, "AR-3: F1 CD fuera de un cuerpo avisa")
R("AR-3: 3 cuerpos agregan campos", FL, "AR-3: 3 cuerpos agregan campos")
R("AR-3: F2 ESQUEMA de fuerzas", FL, "esquema: una tecla vuelve al resultado")
R("AR-3: resize", FL, "resize en AR-3 sin errores")
R("AR-4: CL necesario (paso 1)", FL, "AR-04 paso 1: CL = 0.8831")
R("AR-4: empuje y D fuselaje (paso 2)", FL, "Empuje T = 306.2")
R("AR-4: memoria", FL, "AR-04: memoria sin plantillas")
R("Placa plana: Cf turbulento (AR-06)", FL, "AR-06: FD turbulento 0.529 N y aviso laminar")
R("Placa plana: mixto", FL, "AR-06: FD mixto 0.372 N")
R("Esfera Stokes: FD = 9.425E-9 N y 'Stokes valido' (Re = 1)", FL, "AR-05: Stokes FD = 9.425E-9 N")
R("Avisos Re < 1e4 / crisis / Stokes (limite Re = 1 con tolerancia)", C, "aviso Stokes")
R("Fluido Agua llena rho y nu", N, "AR-1: Fluido Agua llena rho y nu")
R("Fluido Manual", N, "AR-1: Fluido Manual")
R("Fluido Aire (Ajustes)", N, "AR-1: Fluido Aire (Ajustes) llena rho y nu del aire")
R("Velocidad en m/s", N, "AR-1: V = 20 m/s da FD = 23.56 N")
R("Velocidad en km/h", N, "AR-1: V = 72 km/h equivale a 20 m/s")
R("Velocidad en nudos (km/h por nudo de Ajustes)", N, "AR-1: V en nudos")
R("Unidades de V: ciclo m/s, km/h, nudos", N, "AR-1: unidad nudos")
R("Regimen de placa: turbulento y mixto", FL, "AR-06: FD mixto 0.372 N")
R("Placa plana: Caras mojadas 1 vs 2 (duplica FD)", FL, "AR-06: 2 caras mojadas duplican FD mixto (0.744 N)")
R("F1 CD abre el selector de figura", FL, "AR-2: F1 CD abre el selector")
R("Selector: vuelve al formulario", FL, "selector: vuelve al formulario")

S("14. FLUJOS - Catalogo de CD (17 figuras)")
R("Lista con miniaturas", FL, "catalogo: miniaturas dibujadas")
R("Lista: Esfera lisa ... Placa plana larga", FL, "catalogo: lista")
R("PERDGFX valido y 17 figuras dibujadas", UI, "17 figuras dibujadas")
fig = ["Esfera lisa", "Hemisferio convexo", "Hemisferio plano", "Copa hemisferica hueca",
       "Paracaidas", "Disco delgado", "Cono punta al flujo", "Cono base al flujo",
       "Cubo cara al flujo", "Cubo arista al flujo", "Cilindro finito perpend.",
       "Cilindro cara al flujo", "Cuerpo aerodinamico", "Placa rectangular",
       "Cilindro largo (2D)", "Barra cuadrada larga (2D)", "Placa plana larga (2D)"]
for i, nm in enumerate(fig):
    R("Figura %d: %s (nombre, CD, area, fuente, orientacion)" % (i + 1, nm), FL, '": area " .. dc.area_txt')
    R("Figura %d: %s (ilustracion 3D dibujada)" % (i + 1, nm), UI, '"figura " .. i .. ": hay operaciones')
R("Detalle de la esfera (CD, area, Re<1)", FL, "detalle de la esfera")
R("Tabla por L/D", FL, "detalle: tabla por L/D")
R("Tabla por angulo", FL, "detalle: tabla por angulo (7 puntos)")
R("Tabla por b/h", FL, "detalle: tabla por b/h")
R("F4 TABLA: interpola", FL, "TABLA: L/D = 15 interpola 0.9167")
R("F4 TABLA: valor infinito L/D >= 1000", FL, "TABLA: L/D >= 1000 usa el valor infinito 1.2")
R("F3 EDITAR: CD propio", FL, "(catal. 0.5)")
R("DEFECTO restaura el CD del catalogo", FL, "F1 DEFECTO restaura el valor")
R("F2 MARCAR + F3 COMPAR.", FL, "COMPARAR: 3 figuras")
R("COMPARAR: maximo 3 figuras", FL, "COMPARAR: maximo 3 figuras")
R("COMPARAR sin marcas avisa", FL, "COMPARAR sin marcas avisa")
R("F4 RANKING de menor a mayor", FL, "RANKING de menor a mayor CD")
R("F1 USAR devuelve la figura y CD", FL, "USAR devuelve el paracaidas con CD 1.3")
R("USAR con parametro (L/D, angulo)", FL, "cat.cat_sel_param == 30")
R("ESC devuelve -1", FL, "scr_cat: ESC devuelve -1")
R("Segundo clic abre la ficha", FL, "catalogo: segundo clic abre el detalle")
R("Sin PERDGFX: aviso, sin cierre", FL, "sin PERDGFX: aviso, sin cierre")
R("Resize en el catalogo", FL, "resize en el catalogo sin errores")

S("15. FLUJOS - Vertedores y orificios")
R("Elemento simple: triangular, H -> Q (VE-03)", FL, "VE-03: H = 0.4569 m")
R("Elemento simple: memoria (Q/K)^(2/5)", FL, "(Q/K)^(2/5)")
R("Elemento simple: dado Q da H (VE-05)", FL, "VE-05: H = 0.2072 m")
R("Rectangular: aviso de Francis", FL, "vertedero rectangular: aviso de Francis")
R("Orificio circular: carga parcial (H < d/2)", FL, "orificio con H < d/2: aviso de carga parcial")
R("Orificio rectangular: falta alto a", FL, "orificio rectangular: falta el alto a")
R("Cota de la cresta (VE-08): h0", FL, "h0 = h - H = 0.0241")
R("Estructura compuesta: nivel -> Q (VE-01)", FL, "VE-01: Q total = 0.7405 m3/s")
R("Estructura compuesta: memoria con 'cantidad x'", FL, "2 Orificio circ. x3")
R("Estructura compuesta: Q -> nivel (VE-02)", FL, "VE-02: h = 1.829 m")
R("Estructura compuesta: tabla de biseccion", FL, "VE-4: la tabla de biseccion esta en la memoria")
R("Estructura compuesta: reparto (VE-06)", FL, "Q=0.02288")
R("Estructura compuesta: F2 ESQUEMA", FL, "VE-01: esquema")
R("Perfil de velocidades v = k y^n (VE-07)", FL, "VE-07: Q = 1.3333 m3/s")
R("Perfil por tabla de puntos (Simpson)", FL, "VE-07: Q por puntos (Simpson) = 1.3333")
R("Perfil: la memoria dice Simpson", FL, "VE-07: la memoria dice Simpson")
R("Perfil: y no creciente avisa", FL, "VE-07: y no creciente: mensaje")
R("Aguas abajo: v1, E, Fr y alternos", FL, "VE-7: memoria")
R("Aguas abajo: solo seccion 1", FL, "VE-7: solo seccion 1")

S("16. FLUJOS - Canales y medicion")
R("Venturi: dp y h manometro fisico (EX-01a)", FL, "dp = p1 - p2 = 3266")
R("Venturi: convencion del examen (S g h)", FL, "h manometro = 0.8323")
R("Venturi: memoria", FL, "dp/(S gamma)")
R("Venturi: D2 >= D1 avisa", FL, "D2 >= D1 avisa")
R("Salto hidraulico dado y1 (EX-02)", FL, "EX-02: memoria con cantidad de movimiento")
R("Salto: Fr1 <= 1 sin salto", FL, "EX-02: Fr1 <= 1, sin salto: mensaje")
R("Salto dado y2", FL, "EX-02: dado y2 vuelve y1 = 0.4 m")
R("Salto dado y2 supercritico: Fr2", FL, "EX-02: dado y2 supercritico: mensaje Fr2")
R("Chorro desde un tubo (EX-03a)", FL, "> Alcance R = 3.40")
R("Chorro con energia de salida (EX-03b)", FL, "EX-03b: con salida Q = 3.899 l/s")
R("Chorro: memoria con el tipo B", FL, "EX-03: memoria con el tipo B")
R("Placa plana y Stokes (EX-4)", FL, "Canales 4: placa plana y Stokes")

S("17. FLUJOS - Casos del curso (17) y Mis casos")
fn = ["AR-01 Paracaidista (T4-2 P1)", "AR-02 Torre y tanque (T4-2 P4)", "AR-03 Cubo en agua (T4-2 P5)",
      "AR-04 Avion A-330 (2017 P2)", "AR-05 Esfera en flujo lento (Stokes)", "AR-06 Placa plana en aire",
      "VE-01 Triang. + 3 orificios (2024 P5a)", "VE-02 Nivel con 0.5 m3/s (2024 P5b)",
      "VE-03 Triangular, 200 l/s (2025 P4a)", "VE-04 Triang., 260.64 l/s (2025 P4b)",
      "VE-05 Triang. 60, 16 l/s (T4-2 P2a)", "VE-06 Reparto 36 l/s (T4-2 P2b)",
      "VE-07 Perfil v = 2 y^2 (T4-2 P3a)", "VE-08 Cota de la cresta (T4-2 P3b)",
      "EX-01 Venturi (2025 P4c)", "EX-02 Salto hidraulico (2017 P3)", "EX-03 Chorro desde un tubo (2025)"]
for nm in fn:
    R("Caso " + nm + ": resultado", FL, ": falta [")
    R("Caso " + nm + ": memoria sin plantillas", FL, ": memoria sin plantillas (")
R("17 casos del curso en la lista", FL, "17 casos del curso en la lista")
R("Presets AR/VE/EX a su pantalla", FL, "preset AR-01 -> AR-2")
R("Mis casos: 12 tipos distintos", FL, "Mis casos: 12 casos de tipos distintos")
R("Mis casos: cargar cada caso", FL, "carga y calcula")
R("Mis casos: on.save/on.restore", FL, "on.restore recupera los 12 casos")
R("Mis casos: copia profunda y rechazo de datos invalidos", FL, "load: rechaza datos invalidos")

S("18. Nucleo numerico (golden, aleatorios, secante)")
R("Casos dorados (todos)", C, "1. GOLDEN")
R("Aleatorios 1 (750 filas)", C, "2. ALEATORIOS")
R("Aleatorios 2 (625 filas)", C, "3. ALEATORIOS")
R("Secante y arranque HW", C, "4. SECANTE")
R("Datos consistentes", C, "6. DATOS")


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    dest = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "tests", "checklist.md")
    out = ["# Checklist del port Nspire (v2.1 completa)", "",
           "Cada fila es una opcion, tecla, ayuda, ajuste, caso o elemento de biblioteca de la v2.1 y la",
           "prueba Nspire que la cubre (archivo de `tests/` y fragmento literal del texto de la asercion).",
           "`python -I tools/check_checklist.py` comprueba que cada fragmento existe en su archivo y que no",
           "queda ninguna fila `SIN COBERTURA`. Se regenera con `python -I tools/gen_checklist.py`.", ""]
    n = 0
    cursec = None
    for sec, item, f, frag in rows:
        if sec != cursec:
            out += ["", "## " + sec, "", "| # | Item v2.1 | Prueba | Asercion |", "|---|---|---|---|"]
            cursec = sec
        n += 1
        out.append("| %d | %s | tests/%s | `%s` |" % (
            n, item.replace("|", "/"), f, frag.replace("|", "/").replace("`", "'")))
    out += ["", "Total: %d filas, 0 sin cobertura." % n, ""]
    with open(dest, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out))
    print(n, "filas ->", dest)


main()
