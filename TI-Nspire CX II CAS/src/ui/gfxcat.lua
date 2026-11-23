-- gfxcat.lua - Ilustraciones del catalogo de C_D (port de gfxcat.c).
-- Los datos (PERDGFX) vienen de src/gen/perdgfx.lua (cadena binaria). Formato:
--   "PGX" ver(1) n(1) W(1) H(1) TW(1) TH(1) pal[16] x uint16 RGB1555,
--   n x uint16 desplazamiento grande, n x uint16 miniatura, datos RLE 4 bits.
-- Coordenadas: pixeles relativos a la esquina del CUERPO (ver ui.lua).
local rt = require("ui.rt")
local U = require("ui.ui")
local G = {}
G.GFX_PAL0, G.GFX_W, G.GFX_H, G.GFX_TW, G.GFX_TH, G.CAT_N = 32, 96, 80, 32, 18, 17

local data, GN
local byte = string.byte

-- Abre PERDGFX y carga su paleta; false si falta o no es valido
function G.gfxcat_open()
  data = nil
  local ok, d = pcall(require, "gen.perdgfx")
  if not ok or type(d) ~= "string" then return false end
  GN = #d
  if GN < 9 + 32 + 4 * G.CAT_N or d:sub(1, 3) ~= "PGX" or byte(d, 4) ~= 1 or
      byte(d, 5) ~= G.CAT_N or byte(d, 6) ~= G.GFX_W or byte(d, 7) ~= G.GFX_H or
      byte(d, 8) ~= G.GFX_TW or byte(d, 9) ~= G.GFX_TH then
    return false
  end
  data = d
  for i = 1, 15 do
    local v = byte(d, 10 + 2 * i) + byte(d, 11 + 2 * i) * 256
    local r = math.floor(v / 1024) % 32
    local g = math.floor(v / 32) % 32
    local b = v % 32
    rt.PAL[G.GFX_PAL0 + i] = { r * 8 + 7, g * 8 + 7, b * 8 + 7 }
  end
  return true
end

-- Dibuja la figura i (0-based; grande o miniatura) con su esquina en (x, y) y
-- escala s (1 o 2). No hace nada si el archivo no esta abierto.
function G.gfxcat_draw(i, big, x, y, s)
  if not data or i < 0 or i >= G.CAT_N then return end
  local p = 9 + 32 + 2 * (i + (big and 0 or G.CAT_N)) + 1
  local o = byte(data, p) + byte(data, p + 1) * 256
  local w = big and G.GFX_W or G.GFX_TW
  local h = big and G.GFX_H or G.GFX_TH
  local n = w * h
  local px = 0
  local fill = U.ui_px_fill
  local pal0 = G.GFX_PAL0
  while px < n and o < GN do
    local b = byte(data, o + 1)
    o = o + 1
    local sym = b % 16
    local run = math.floor(b / 16) + 1
    while run > 0 do
      local col = px % w
      local row = (px - col) / w
      local r = run
      if col + r > w then r = w - col end
      if sym ~= 0 then fill(x + col * s, y + row * s, r * s, s, pal0 + sym) end
      px = px + r
      run = run - r
      if px >= n then break end
    end
  end
end

-- Rectangulo lleno (barras de comparar y ranking)
function G.gfxcat_rect(x, y, w, h, color)
  if w <= 0 then return end
  U.ui_px_fill(x, y, w, h, color)
end

return G
