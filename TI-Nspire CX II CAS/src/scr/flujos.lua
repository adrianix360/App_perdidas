-- flujos.lua - Menu principal del programa FLUJOS (port de flujos.c, v2.0/v2.1):
-- arrastre y sustentacion, vertedores y orificios, canales y medicion, catalogo de
-- C_D, Mis casos, ajustes, ayuda y casos del curso.
--
-- Expone flujos_main() (la carga main.lua con pcall(require, "scr.flujos")). Re-exporta
-- las funciones de Mis casos de los modulos de pantalla (drag_save/drag_load/
-- drag_preset/scr_drag_run, weir_*, chan_*) para quien las busque aqui.
-- Ajustes y Acerca de vienen de scr.screens y Mis casos de scr.cases (F3).
local U = require("ui.ui")
local W = require("ui.widgets")
local MR = require("memo_run")
local F = require("scr.flu_util")
local Sd = require("scr.scr_drag")
local Sw = require("scr.scr_weir")
local Sc = require("scr.scr_chan")
local Sk = require("scr.scr_cat")

local S = {}
local MENU_BACK, MENU_QUIT, MENU_MODE = W.MENU_BACK, W.MENU_QUIT, W.MENU_MODE

-- Submenu generico; fn recibe el indice elegido (base 0)
local function sub_menu(m, fn)
  while not U.quit do
    local r = W.menu_run(m)
    if r == MENU_BACK or r == MENU_QUIT then return end
    if r == MENU_MODE then F.scr_settings() else fn(r) end
  end
end

local function drag_item(r)
  if r == 6 then Sk.scr_cat(false) else Sd.scr_drag(r) end
end
local function weir_item(r) Sw.scr_weir(r) end
local function chan_item(r)
  if r == 3 then Sd.scr_drag(4)            -- placa plana y Stokes (EX-4)
  else Sc.scr_chan(r) end
end

local course_names = {
  "AR-01 Paracaidista (T4-2 P1)",
  "AR-02 Torre y tanque (T4-2 P4)",
  "AR-03 Cubo en agua (T4-2 P5)",
  "AR-04 Avion A-330 (2017 P2)",
  "AR-05 Esfera en flujo lento (Stokes)",
  "AR-06 Placa plana en aire",
  "VE-01 Triang. + 3 orificios (2024 P5a)",
  "VE-02 Nivel con 0.5 m3/s (2024 P5b)",
  "VE-03 Triangular, 200 l/s (2025 P4a)",
  "VE-04 Triang., 260.64 l/s (2025 P4b)",
  "VE-05 Triang. 60, 16 l/s (T4-2 P2a)",
  "VE-06 Reparto 36 l/s (T4-2 P2b)",
  "VE-07 Perfil v = 2 y^2 (T4-2 P3a)",
  "VE-08 Cota de la cresta (T4-2 P3b)",
  "EX-01 Venturi (2025 P4c)",
  "EX-02 Salto hidraulico (2017 P3)",
  "EX-03 Chorro desde un tubo (2025)",
  "VE-09 2 tanques, Qe 250 (Vert. P4a)",
  "VE-10 2 tanques, rebalse (Vert. P4c)",
  "VE-11 2 tanques, tri. Q=0 (2025 P3a)",
  "VE-12 2 tanques, tri. 50 l/s (P3b)",
  "AR-07 Balance vertical Magnus (2024)",
}
S.course_names = course_names

local course_cur = 0
local function course_cases()
  while true do
    for i = 0, #course_names - 1 do W.list_line[i] = course_names[i + 1] end
    local r, k = W.list_pick("CASOS DEL CURSO", "ENTER carga los datos y calcula", #course_names,
      course_cur, nil)
    if r < 0 or k ~= U.K_ENTER then return end
    course_cur = r
    if r == 21 then
      Sd.scr_drag_run(Sd.drag_preset(6), true)        -- AR-07 (Magnus)
    elseif r >= 17 then
      Sw.scr_weir_run(Sw.weir_preset(r - 9), true)    -- VE-09..VE-12 (tanques)
    elseif r < 6 then
      Sd.scr_drag_run(Sd.drag_preset(r), true)
    elseif r < 14 then
      Sw.scr_weir_run(Sw.weir_preset(r - 6), true)
    else
      Sc.scr_chan_run(Sc.chan_preset(r - 14), true)
    end
    if U.quit then return end
  end
end
S.course_cases = course_cases

local help_topic = { [0] = 8, 9, 10, 6 }      -- PROG_HELP(i)
local function help_item(r)
  local fk = { "", "", "", "", "VOLVER" }
  if r < 4 then
    if not MR.help_topic(help_topic[r]) then
      U.ui_alert("Ayuda", "Falta PERDTXT o es de", "otra version", U.C_ERR)
    else
      W.view_run("AYUDA", fk)
    end
  elseif r == 4 then
    course_cases()
  else
    F.scr_about()
  end
end

local items = {
  "Arrastre y sustentacion",
  "Vertedores y orificios",
  "Canales y medicion",
  "Coeficientes de arrastre (CD)",
  "Mis casos",
  "Ajustes",
  "Ayuda / Acerca de",
  "Salir",
}
local ar_items = {
  "Fuerza de arrastre FD o FL  (AR-1)",
  "Velocidad terminal          (AR-2)",
  "Estructura: varios cuerpos  (AR-3)",
  "Vuelo nivelado (avion)      (AR-4)",
  "Placa plana y flujo lento (Stokes)",
  "Balance vertical (Magnus)  (AR-5)",
  "Catalogo de coeficientes CD",
}
local ve_items = {
  "Vertedero u orificio (VE-1,2,5)",
  "Estructura compuesta      (VE-4)",
  "Perfil de velocidades     (VE-6)",
  "Aguas abajo: energia      (VE-7)",
  "Tanques acoplados         (VE-8)",
}
local ch_items = {
  "Venturi y manometro       (EX-1)",
  "Salto hidraulico          (EX-2)",
  "Chorro desde un tubo      (EX-3)",
  "Placa plana y Stokes      (EX-4)",
}
local help_items = {
  "Arrastre y sustentacion",
  "Vertedores y orificios",
  "Canales y medicion",
  "Erratas del material",
  "Casos del curso (cargar)",
  "Acerca de",
}
local m = { title = "FLUJOS EXTERNOS Y MEDICION", items = items, n = 8, cur = 0 }
local mar = { title = "ARRASTRE Y SUSTENTACION", items = ar_items, n = 7, cur = 0 }
local mh = { title = "AYUDA", items = help_items, n = 6, cur = 0 }
local mve = { title = "VERTEDORES Y ORIFICIOS", items = ve_items, n = 5, cur = 0 }
local mch = { title = "CANALES Y MEDICION", items = ch_items, n = 4, cur = 0 }

function S.flujos_main()
  while not U.quit do
    local r = W.menu_run(m)
    if r == MENU_QUIT then return end
    if r == MENU_BACK then
      if U.ui_alert("Salir", "Desea salir de FLUJOS?", nil, U.C_TITLE) then
        return
      end
    elseif r == MENU_MODE or r == 5 then F.scr_settings()
    elseif r == 0 then sub_menu(mar, drag_item)
    elseif r == 1 then sub_menu(mve, weir_item)
    elseif r == 2 then sub_menu(mch, chan_item)
    elseif r == 3 then Sk.scr_cat(false)
    elseif r == 4 then F.scr_cases()
    elseif r == 6 then sub_menu(mh, help_item)
    elseif r == 7 then return end
  end
end

-- Re-exportaciones para Mis casos (mismos nombres que el C)
S.drag_save, S.drag_load, S.drag_preset, S.scr_drag, S.scr_drag_run =
  Sd.drag_save, Sd.drag_load, Sd.drag_preset, Sd.scr_drag, Sd.scr_drag_run
S.weir_save, S.weir_load, S.weir_preset, S.scr_weir, S.scr_weir_run =
  Sw.weir_save, Sw.weir_load, Sw.weir_preset, Sw.scr_weir, Sw.scr_weir_run
S.chan_save, S.chan_load, S.chan_preset, S.scr_chan, S.scr_chan_run =
  Sc.chan_save, Sc.chan_load, Sc.chan_preset, Sc.scr_chan, Sc.scr_chan_run
S.scr_cat = Sk.scr_cat

return S
