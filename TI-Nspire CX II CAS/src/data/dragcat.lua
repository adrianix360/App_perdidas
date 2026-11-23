--[[
dragcat.lua - Catalogo de coeficientes de arrastre (v2.0, prompt sec. 4.3).
Puerto de src/data/dragcat.h/.c. Valores de partida de las tablas habituales
(Cengel y Cimbala tablas 11-1 y 11-2; White; Fox/Munson), Re > 1e4 y area
frontal salvo nota. Valores sin verificar contra el libro del curso (prompt v2,
sec. 4.3): cada fila dice su fuente. El usuario puede poner un valor propio
(Ajustes: cd_user).

Convencion: listas de base 1. El indice de figura `i` que se guarda en los casos
y que reciben las funciones es el codigo del C (0..CAT_N-1): la figura es
drag_shapes[i + 1]; cd_user[i] tambien se indexa con el codigo (base 0).

API PUBLICA
  Constantes: CAT_N (17); AR_CIRC AR_SQ AR_LD AR_BH AR_SQ2 AR_COUNT;
    TB_NONE TBC_LD_PERP TBC_LD_AX TBC_BH TBC_CONE
  drag_shapes[i+1] = {name, orient, cd, area (AR_*), kind (DK_*), tab (TBC_*|TB_NONE),
                      stokes (0: no hay), src, note (lineas separadas por '|')}
  area_txt[a+1]  (a = AR_*)
  dragcat_table(tab) -> {param, n, x, y, inf} o nil   (x, y listas base 1)
  dragcat.cd_user    tabla {[i] = Cd propio} editable por la interfaz (0/nil = catalogo)
  dragcat_cd(i) -> Cd vigente (propio si lo hay)
  dragcat_param(i, p, warn) -> cd, x0, y0, x1, y1, warn   (interpola en la tabla de la figura)
  dragcat_area(area, a, b) -> area de referencia
]]

local H = require("core.hydro")
local Dr = require("core.drag")

local dc = {}

local DK_GENERIC, DK_SPHERE, DK_LONGCYL = Dr.DK_GENERIC, Dr.DK_SPHERE, Dr.DK_LONGCYL

dc.CAT_N = 17
local CAT_N = 17

-- area de referencia
dc.AR_CIRC, dc.AR_SQ, dc.AR_LD, dc.AR_BH, dc.AR_SQ2, dc.AR_COUNT = 0, 1, 2, 3, 4, 5
local AR_CIRC, AR_SQ, AR_LD, AR_BH, AR_SQ2 = 0, 1, 2, 3, 4
-- tablas por parametro
dc.TB_NONE, dc.TBC_LD_PERP, dc.TBC_LD_AX, dc.TBC_BH, dc.TBC_CONE = 0, 1, 2, 3, 4
local TB_NONE, TBC_LD_PERP, TBC_LD_AX, TBC_BH, TBC_CONE = 0, 1, 2, 3, 4

dc.area_txt = {
    "pi D^2/4", "D^2", "L D", "b h", "sqrt(2) D^2"
}

dc.drag_shapes = {
    { name = "Esfera lisa", orient = "cualquier orientacion", cd = 0.5, area = AR_CIRC, kind = DK_SPHERE,
      tab = TB_NONE, stokes = 24, src = "Cengel 11-2",
      note = "White 0.47. Crisis de arrastre: CD 0.2|si Re > 2E5 (Cengel turbulento)" },
    { name = "Hemisferio convexo", orient = "domo hacia el flujo", cd = 0.4, area = AR_CIRC, kind = DK_GENERIC,
      tab = TB_NONE, stokes = 0, src = "Cengel 11-2",
      note = "White 0.42" },
    { name = "Hemisferio plano", orient = "cara plana hacia el flujo", cd = 1.17, area = AR_CIRC, kind = DK_GENERIC,
      tab = TB_NONE, stokes = 0, src = "Cengel 11-2",
      note = "White 1.15" },
    { name = "Copa hemisferica hueca", orient = "abierta hacia el flujo", cd = 1.42, area = AR_CIRC, kind = DK_GENERIC,
      tab = TB_NONE, stokes = 0, src = "Fox/Munson",
      note = "Abierta hacia atras: CD 0.38" },
    { name = "Paracaidas", orient = "abierto, D del dosel", cd = 1.3, area = AR_CIRC, kind = DK_GENERIC,
      tab = TB_NONE, stokes = 0, src = "Cengel 11-2",
      note = "Copa hueca 1.42 (figura 4). La Tarea|4-2 P1 no da CD: el curso usa 1.3" },
    { name = "Disco delgado", orient = "normal al flujo", cd = 1.1, area = AR_CIRC, kind = DK_GENERIC,
      tab = TB_NONE, stokes = 20.4, src = "Cengel 11-2",
      note = "White 1.17. Stokes: 20.4/Re normal,|13.6/Re paralelo al flujo" },
    { name = "Cono, punta al flujo", orient = "angulo total 30 grados", cd = 0.5, area = AR_CIRC, kind = DK_GENERIC,
      tab = TBC_CONE, stokes = 0, src = "Cengel 11-2",
      note = "Tabla por angulo total (White);|escriba el angulo en grados" },
    { name = "Cono, base al flujo", orient = "base plana hacia el flujo", cd = 1.15, area = AR_CIRC, kind = DK_GENERIC,
      tab = TB_NONE, stokes = 0, src = "White",
      note = "" },
    { name = "Cubo, cara al flujo", orient = "una cara normal al flujo", cd = 1.05, area = AR_SQ, kind = DK_GENERIC,
      tab = TB_NONE, stokes = 0, src = "Cengel 11-2",
      note = "White 1.07" },
    { name = "Cubo, arista al flujo", orient = "girado 45 grados", cd = 0.80, area = AR_SQ2, kind = DK_GENERIC,
      tab = TB_NONE, stokes = 0, src = "Cengel 11-2",
      note = "White 0.81. Area proyectada sqrt(2)D^2;|las tablas usan D^2 (escriba A)" },
    { name = "Cilindro finito perpend.", orient = "eje normal al flujo", cd = 0.9, area = AR_LD, kind = DK_LONGCYL,
      tab = TBC_LD_PERP, stokes = 0, src = "Cengel 11-2",
      note = "Tabla por L/D; L/D >= 1000: infinito|(1.2). Valor inicial: L/D = 10" },
    { name = "Cilindro, cara al flujo", orient = "eje paralelo al flujo", cd = 0.9, area = AR_CIRC, kind = DK_GENERIC,
      tab = TBC_LD_AX, stokes = 0, src = "Cengel 11-2",
      note = "Tabla por L/D" },
    { name = "Cuerpo aerodinamico", orient = "forma de gota, punta atras", cd = 0.04, area = AR_CIRC, kind = DK_GENERIC,
      tab = TB_NONE, stokes = 0, src = "Cengel 11-2",
      note = "" },
    { name = "Placa rectangular", orient = "normal al flujo", cd = 1.18, area = AR_BH, kind = DK_GENERIC,
      tab = TBC_BH, stokes = 0, src = "Fox/Munson",
      note = "Tabla por b/h; b/h >= 1000: 1.98.|Valor inicial: b/h = 1" },
    { name = "Cilindro largo (2D)", orient = "eje normal, por metro", cd = 1.2, area = AR_LD, kind = DK_LONGCYL,
      tab = TB_NONE, stokes = 0, src = "Cengel 11-1",
      note = "Re > 5E5 (turbulento): CD 0.3,|crisis de arrastre" },
    { name = "Barra cuadrada larga (2D)", orient = "cara al flujo, esquinas vivas", cd = 2.2, area = AR_LD, kind = DK_GENERIC,
      tab = TB_NONE, stokes = 0, src = "Cengel 11-1",
      note = "" },
    { name = "Placa plana larga (2D)", orient = "normal al flujo, por metro", cd = 1.9, area = AR_LD, kind = DK_GENERIC,
      tab = TB_NONE, stokes = 0, src = "Cengel 11-1",
      note = "Fox/Munson 1.98" },
}

local ldp_x = { 1, 2, 5, 10, 40 }
local ldp_y = { 0.6, 0.7, 0.8, 0.9, 1.0 }
local lda_x = { 0.5, 1, 2, 4, 8 }
local lda_y = { 1.1, 0.9, 0.9, 0.9, 1.0 }
local bh_x = { 1, 5, 10, 20 }
local bh_y = { 1.18, 1.2, 1.3, 1.5 }
local cone_x = { 10, 20, 30, 40, 60, 75, 90 }
local cone_y = { 0.30, 0.40, 0.55, 0.65, 0.80, 1.05, 1.15 }

local tables = {
    { param = "L/D", n = 5, x = ldp_x, y = ldp_y, inf = 1.2 },
    { param = "L/D", n = 5, x = lda_x, y = lda_y, inf = 0 },
    { param = "b/h", n = 4, x = bh_x, y = bh_y, inf = 1.98 },
    { param = "angulo", n = 7, x = cone_x, y = cone_y, inf = 0 },
}

function dc.dragcat_table(tab)
    if tab >= TBC_LD_PERP and tab <= TBC_CONE then return tables[tab] end
    return nil
end
local dragcat_table = dc.dragcat_table

-- C_D propio de cada figura (0/nil = catalogo); indice = codigo de figura
dc.cd_user = {}

function dc.dragcat_cd(i)
    if i < 0 or i >= CAT_N then return 0 end
    local u = dc.cd_user[i]
    if u and u > 0 then return u end
    return dc.drag_shapes[i + 1].cd
end

-- C_D por parametro de la tabla de la figura i: interpola y devuelve los
-- vecinos. warn recibe DW_INTERP / DW_CLAMP. Si el parametro es >= 1000 usa
-- el valor "infinito" de la tabla. -> cd, x0, y0, x1, y1, warn
function dc.dragcat_param(i, p, warn)
    local t = dragcat_table((i >= 0 and i < CAT_N) and dc.drag_shapes[i + 1].tab or 0)
    if not t then return dc.dragcat_cd(i), nil, nil, nil, nil, warn end
    if t.inf > 0 and p >= 1000 then
        return t.inf, p, t.inf, p, t.inf, warn
    end
    local v, k
    v, k, warn = Dr.drag_interp(t.x, t.y, t.n, p, warn)
    return v, t.x[k], t.y[k], t.x[k + 1], t.y[k + 1], warn
end

function dc.dragcat_area(area, a, b)
    if area == AR_CIRC then return H.hydro_area(a)
    elseif area == AR_SQ then return a * a
    elseif area == AR_SQ2 then return 1.41421356 * a * a
    end
    return a * b
end

return dc
