--[[
lib.lua - Datos de la biblioteca (memoria tecnica, sec. 8). Puerto de
src/data/lib.c. Cada dato dice de donde sale: (curso) Perdidas-01.pdf,
(C) Cengel, (std) tabla estandar de agua a presion atmosferica (no viene de
los PDF del curso).

Convencion: listas de base 1 (el indice del C + 1). Los codigos guardados en
casos (material, accesorio, agua) conservan el numero del C; el elemento es
lib.materials[codigo + 1], etc.

API PUBLICA
  lib.MATERIALS, lib.FITTINGS, lib.K_PRESETS, lib.WATERS (cantidades)
  lib.materials[i] = {name, ks_mm (< 0: no aplica), ch (0: no aplica)}
  lib.fittings[i]  = {name, K}
  lib.k_presets[i] = {name, n, items = { {name, qty, K}, ... }}
  lib.waters[i]    = {name, T (C; 0 = valor del curso), rho (kg/m3; 0 = no aplica;
                      < 10 = aire), nu (m2/s), pv (Pa; 0 = no aplica)}
]]

local lib = {}

lib.MATERIALS = 24
lib.FITTINGS = 30
lib.K_PRESETS = 6
lib.WATERS = 15

-- 8.1 rugosidad ks (mm) y 8.2 coeficiente C_H; -1 / 0 = no disponible
lib.materials = {
  { name = "PVC y CPVC", ks_mm = 0.0015, ch = 150 },
  { name = "PEAD (polietileno)", ks_mm = 0.007, ch = 150 },
  { name = "Vidrio", ks_mm = 0.0003, ch = 0 },
  { name = "Asbesto cemento", ks_mm = 0.03, ch = 140 },
  { name = "Fibra vidrio (GRP)", ks_mm = 0.03, ch = 150 },
  { name = "Acero comercial", ks_mm = 0.045, ch = 0 },
  { name = "Concreto centrifug.", ks_mm = 0.12, ch = 0 },
  { name = "H. fundido asfalt.", ks_mm = 0.12, ch = 0 },
  { name = "Hierro fundido", ks_mm = 0.15, ch = 130 },
  { name = "Hierro galvanizado", ks_mm = 0.15, ch = 120 },
  { name = "Arcilla vitrificada", ks_mm = 0.15, ch = 100 },
  { name = "Hierro ductil", ks_mm = 0.25, ch = 140 },
  { name = "Concreto", ks_mm = 0.30, ch = 0 },
  { name = "Acero liso (C_H)", ks_mm = -1, ch = 130 },
  { name = "Acero soldado (C_H)", ks_mm = -1, ch = 120 },
  { name = "Acero bridas (C_H)", ks_mm = -1, ch = 110 },
  { name = "Concreto liso (C_H)", ks_mm = -1, ch = 140 },
  { name = "Concreto rug. (C_H)", ks_mm = -1, ch = 120 },
  { name = "Cobre/laton (C)", ks_mm = 0.0015, ch = 0 },
  { name = "Acero inox. (C)", ks_mm = 0.002, ch = 0 },
  { name = "Hule alisado (C)", ks_mm = 0.01, ch = 0 },
  { name = "Hierro forjado (C)", ks_mm = 0.046, ch = 0 },
  { name = "Hierro fundido (C)", ks_mm = 0.26, ch = 0 },
  { name = "Duela de madera (C)", ks_mm = 0.5, ch = 0 },
}

-- 8.3 coeficientes K de accesorios
lib.fittings = {
  { name = "Entrada borde recto", K = 0.5 },
  { name = "Entrada redondeada", K = 0.2 },
  { name = "Entrada saliente", K = 0.8 },
  { name = "Entrada muy redond.", K = 0.04 },
  { name = "Salida a tanque", K = 1.0 },
  { name = "Codo 90 embridado", K = 0.3 },
  { name = "Codo 90 roscado", K = 0.9 },
  { name = "Codo 90 esquina", K = 1.1 },
  { name = "Codo 90 esq. alabes", K = 0.2 },
  { name = "Codo 45 roscado", K = 0.4 },
  { name = "Retorno 180 embrid.", K = 0.2 },
  { name = "Retorno 180 roscado", K = 1.5 },
  { name = "Te deriv. embridada", K = 1.0 },
  { name = "Te deriv. roscada", K = 2.0 },
  { name = "Te linea embridada", K = 0.2 },
  { name = "Te linea roscada", K = 0.9 },
  { name = "Union roscada", K = 0.08 },
  { name = "V. globo abierta (C)", K = 10 },
  { name = "V. angulo abierta", K = 5 },
  { name = "V. bola abierta", K = 0.05 },
  { name = "V. charnela", K = 2 },
  { name = "V. compuerta (C)", K = 0.2 },
  { name = "V. compuerta 1/4 c.", K = 0.3 },
  { name = "V. compuerta 1/2 c.", K = 2.1 },
  { name = "V. compuerta 3/4 c.", K = 17 },
  { name = "V. check (curso)", K = 0.8 },
  { name = "V. compuerta (curso)", K = 0.15 },
  { name = "V. mariposa (curso)", K = 0.2 },
  { name = "V. globo (curso)", K = 4.0 },
  { name = "V. esferica (curso)", K = 0.2 },
}

-- 8.4 conjuntos de K de los ejercicios del curso
local pr_pvc = {
    { name = "Entrada borde recto", qty = 1, K = 0.5 },
    { name = "V. compuerta", qty = 3, K = 0.15 },
    { name = "Uniones", qty = 167, K = 0.01 },
    { name = "Codo 45", qty = 12, K = 0.18 },
    { name = "Codo 90", qty = 6, K = 0.32 },
}
local pr_2025 = {
    { name = "Entrada", qty = 1, K = 0.5 },
    { name = "Salida", qty = 1, K = 1.0 },
    { name = "Codo 90", qty = 4, K = 1.10 },
    { name = "Codo 45", qty = 10, K = 0.30 },
    { name = "V. compuerta", qty = 3, K = 0.3 },
    { name = "V. de boya", qty = 1, K = 3.0 },
}
local pr_2019 = {
    { name = "Filtro", qty = 1, K = 8.0 },
    { name = "Codo 90", qty = 4, K = 0.5 },
    { name = "Valvula D", qty = 1, K = 1.0 },
    { name = "Te", qty = 1, K = 0.7 },
    { name = "Cruz", qty = 1, K = 0.7 },
    { name = "Fluviometro", qty = 1, K = 6.0 },
    { name = "Valvula L", qty = 1, K = 3.0 },
}
local pr_2017 = {
    { name = "Codo 90", qty = 3, K = 0.2 },
    { name = "Codo 45", qty = 2, K = 0.1 },
    { name = "Retencion c/rejilla", qty = 1, K = 2.0 },
}
local pr_2018a = {
    { name = "Entrada", qty = 1, K = 0.8 },
    { name = "V. mariposa 30 grad", qty = 1, K = 10 },
}
local pr_2018b = {
    { name = "Entrada borde recto", qty = 1, K = 0.5 },
    { name = "V. mariposa abierta", qty = 1, K = 0.2 },
}

lib.k_presets = {
  { name = "PVC 200 mm (pag. 51)", n = 5, items = pr_pvc },
  { name = "Examen 2025 P1", n = 6, items = pr_2025 },
  { name = "Examen 2019 P4", n = 7, items = pr_2019 },
  { name = "Examen 2017 P4", n = 3, items = pr_2017 },
  { name = "Examen 2018 P1a", n = 2, items = pr_2018a },
  { name = "Examen 2018 P1b", n = 2, items = pr_2018b },
}

-- 8.5 agua a presion atmosferica (std) y viscosidades usadas en el curso
-- v2.0: aire (rho < 10 lo distingue del agua)
lib.waters = {
  { name = "Agua  5 C (std)", T = 5, rho = 1000.0, nu = 1.519e-6, pv = 872 },
  { name = "Agua 10 C (std)", T = 10, rho = 999.7, nu = 1.307e-6, pv = 1228 },
  { name = "Agua 15 C (std)", T = 15, rho = 999.1, nu = 1.139e-6, pv = 1706 },
  { name = "Agua 20 C (std)", T = 20, rho = 998.2, nu = 1.004e-6, pv = 2339 },
  { name = "Agua 25 C (std)", T = 25, rho = 997.0, nu = 0.893e-6, pv = 3169 },
  { name = "Agua 30 C (std)", T = 30, rho = 995.7, nu = 0.801e-6, pv = 4246 },
  { name = "Agua 40 C (std)", T = 40, rho = 992.2, nu = 0.658e-6, pv = 7384 },
  { name = "Curso: 2025, T4", T = 0, rho = 0, nu = 1.0e-6, pv = 0 },
  { name = "Curso: 2017-2019", T = 0, rho = 0, nu = 1.007e-6, pv = 0 },
  { name = "Curso: 2024 P1", T = 0, rho = 0, nu = 1.02e-6, pv = 0 },
  { name = "Curso: ej. 4", T = 0, rho = 0, nu = 1.14e-6, pv = 0 },
  { name = "Curso: hojas", T = 0, rho = 0, nu = 1.17e-6, pv = 0 },
  { name = "Aire (curso)", T = 0, rho = 1.2, nu = 1.5e-5, pv = 0 },
  { name = "Aire 15 C (std)", T = 15, rho = 1.225, nu = 1.46e-5, pv = 0 },
  { name = "Aire 20 C (std)", T = 20, rho = 1.204, nu = 1.516e-5, pv = 0 },
}

return lib
