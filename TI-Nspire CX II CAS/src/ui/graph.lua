-- graph.lua - Grafica de la linea de energia (LE) y la piezometrica (LP) a lo
-- largo de una conduccion (port de graph.c). Esquema sin escala horizontal
-- exacta: cada tramo ocupa un ancho proporcional a su longitud (con minimo).
--
-- graph_run(title, E0, s, n, Eend, tank2): s = lista 1-based de tramos
-- {L=, jump=, hloc=, hfr=, vh=, name=}; E0 energia en el tanque de salida (m);
-- Eend nivel del tanque de llegada si tank2 (true/1), si no la conduccion
-- termina en un punto. Bloqueante: vuelve con ESC, ENTER o F5.
local U = require("ui.ui")
local M = require("ui.memo")
local G = {}
G.GSEG_MAX = 10

local function trunc(x) return x >= 0 and math.floor(x) or -math.floor(-x) end

function G.graph_run(title, E0, s, n, Eend, tank2)
  local fk = { "", "", "", "", "VOLVER" }
  local C_LE, C_LP, C_GRAY, C_WATER, C_FG = U.C_LE, U.C_LP, U.C_GRAY, U.C_WATER, U.C_FG
  if n > G.GSEG_MAX then n = G.GSEG_MAX end
  tank2 = tank2 and tank2 ~= 0
  -- rango vertical: energia y piezometrica en todos los quiebres
  local ymin, ymax = E0, E0
  local E, Ltot = E0, 0
  for i = 1, n do
    local sg = s[i]
    E = E + sg.jump
    if E > ymax then ymax = E end
    E = E - sg.hloc
    if E - sg.vh < ymin then ymin = E - sg.vh end
    E = E - sg.hfr
    if E - sg.vh < ymin then ymin = E - sg.vh end
    if E > ymax then ymax = E end
    Ltot = Ltot + sg.L
  end
  if tank2 then
    if Eend < ymin then ymin = Eend end
    if Eend > ymax then ymax = Eend end
  end
  if not (ymax > ymin) then ymax = ymax + 1; ymin = ymin - 1 end
  local w = (ymax - ymin) * 0.08
  ymax = ymax + w
  ymin = ymin - w
  -- anchos: proporcionales a L con un minimo de 1/(4n) del total
  local minw = Ltot / (4 * (n > 0 and n or 1))
  Ltot = 0
  for i = 1, n do Ltot = Ltot + math.max(s[i].L, minw) end

  while true do
    local BW, BH = U.ui_body_w(), U.ui_body_h()
    local GX0, GX1 = 30, BW - 30
    local LH = U.ui_lh()
    local GY0, GY1 = LH + 5, BH - (LH + 6)   -- sitio para cotas arriba y nombres abajo
    local function ypix(e)
      local t = (e - ymin) / (ymax - ymin)
      return GY1 - trunc(t * (GY1 - GY0))
    end
    local xs = { [0] = GX0 }
    local acc = 0
    for i = 1, n do
      acc = acc + math.max(s[i].L, minw)
      xs[i] = GX0 + trunc((GX1 - GX0) * (acc / Ltot))
    end
    local function lab(v, x, y, col)
      local span = ymax - ymin
      if v < span * 1e-5 and v > -span * 1e-5 then v = 0 end
      local b = M.fmt_w(v, 7)
      local wpx = #b * 7
      if x > BW - wpx then x = BW - wpx end
      if x < 0 then x = 0 end
      if y < GY0 - LH - 1 then y = GY0 - LH - 1 end
      if y > GY1 + 2 then y = GY1 + 2 end
      U.ui_px_text(x, y, b, col)
    end

    U.ui_begin(title, nil)
    -- tanques
    U.ui_px_fill(2, ypix(E0), GX0 - 4, GY1 - ypix(E0) + 1, C_WATER)
    U.ui_px_rect(2, GY0, GX0 - 4, GY1 - GY0 + 1, C_GRAY)
    if tank2 then
      U.ui_px_fill(GX1 + 2, ypix(Eend), BW - GX1 - 4, GY1 - ypix(Eend) + 1, C_WATER)
      U.ui_px_rect(GX1 + 2, GY0, BW - GX1 - 4, GY1 - GY0 + 1, C_GRAY)
    end
    -- tubo (eje) y divisiones de tramos
    U.ui_px_line(GX0, GY1, GX1, GY1, C_GRAY)
    for i = 0, n do U.ui_px_line(xs[i], GY1 - 3, xs[i], GY1 + 3, C_GRAY) end
    -- LE y LP
    E = E0
    for i = 1, n do
      local sg = s[i]
      local x0, x1 = xs[i - 1], xs[i]
      local Ea = E + sg.jump
      local Eb = Ea - sg.hloc
      local Ec = Eb - sg.hfr
      U.ui_px_line(x0, ypix(E), x0, ypix(Eb), C_LE)          -- salto y local
      U.ui_px_line(x0, ypix(Eb), x1, ypix(Ec), C_LE)         -- friccion
      U.ui_px_line(x0, ypix(Eb - sg.vh), x1, ypix(Ec - sg.vh), C_LP)
      if i > 1 then
        U.ui_px_line(x0, ypix(E - s[i - 1].vh), x0, ypix(Eb - sg.vh), C_LP)
      end
      U.ui_px_text(trunc((x0 + x1) / 2) - 4, GY1 + 5, sg.name or "", C_FG)
      if sg.jump ~= 0 then lab(Ea, x0 + 2, ypix(Ea) - LH - 1, C_LE) end
      E = Ec
    end
    -- salida al tanque: la LP sube a la LE (v = 0)
    if n > 0 then
      U.ui_px_line(GX1, ypix(E - s[n].vh), GX1, ypix(tank2 and Eend or E), C_LP)
    end
    lab(E0, 2, GY0 - LH - 1, C_LE)   -- sobre el marco del tanque, sin tocarlo
    lab(E, GX1 - 56, ypix(E) - LH - 1, C_LE)
    -- leyenda
    U.ui_px_text(BW - 104, 0, "LE", C_LE)
    U.ui_px_text(BW - 80, 0, "LP", C_LP)
    U.ui_msg("Esquema sin escala; cotas de energia, m", C_GRAY)
    U.ui_fbar(fk)
    U.ui_end()
    local k = U.ui_getkey()
    if k.k == U.K_CLEAR or k.k == U.K_F5 or k.k == U.K_QUIT or k.k == U.K_ENTER then
      return
    end
  end
end

return G
