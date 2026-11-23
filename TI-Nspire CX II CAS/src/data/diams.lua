--[[
diams.lua - Listas de diametros comerciales (internos, mm). Seccion 8.6 de la
memoria tecnica. Puerto de src/data/diams.c.

Convencion: listas de base 1; el codigo de lista guardado en los casos
(pin.dset) conserva el numero del C (0..5): la lista es diam_sets[dset + 1].

API PUBLICA
  diams.DIAM_SETS (5 listas fijas), diams.DIAM_CUSTOM (= 5, codigo de la lista
    propia), diams.DIAM_CHOICES (6), diams.DIAM_CUSTOM_MAX (15)
  diams.diam_sets[i] = {name, n, mm = {d1, d2, ...}}   (i = codigo + 1)
  diams.diam_set_names[i]   (6 nombres; el ultimo es "Lista propia")
  diams.diam_custom[i]      (i = 1..15, mm; 0 = vacio; se guarda con los casos)
]]

local diams = {}

diams.DIAM_SETS = 5
diams.DIAM_CUSTOM = 5
diams.DIAM_CHOICES = 6
diams.DIAM_CUSTOM_MAX = 15

local d_pvc25 = { 53.21, 64.45, 78.44, 100.84, 148.46, 193.28,
                  240.95, 285.75, 358.64 }
local d_nom24 = { 200, 250, 300, 350, 400, 450, 500 }
local d_prac3 = { 150, 200, 250, 300, 350, 400 }
local d_prac2 = { 50, 75, 100, 150, 300 }
local d_gen = { 50, 75, 100, 150, 200, 250, 300, 350, 400, 450,
                500, 600, 700, 800, 900, 1000, 1200, 1500 }

diams.diam_sets = {
    { name = "PVC examen 2025", n = 9, mm = d_pvc25 },
    { name = "Nominal 2024 200-500", n = 7, mm = d_nom24 },
    { name = "Pract.3/Ej.5 150-400", n = 6, mm = d_prac3 },
    { name = "Practica 2 50-300", n = 5, mm = d_prac2 },
    { name = "General 50-1500", n = 18, mm = d_gen },
}

diams.diam_set_names = {
    "PVC examen 2025", "Nominal 2024 200-500", "Pract.3/Ej.5 150-400",
    "Practica 2 50-300", "General 50-1500", "Lista propia",
}

diams.diam_custom = {}
for i = 1, diams.DIAM_CUSTOM_MAX do diams.diam_custom[i] = 0 end

return diams
