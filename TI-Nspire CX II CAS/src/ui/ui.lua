-- ui.lua - Capa de pantalla y teclado (port de ui.c / ui.h).
--
-- Pantalla logica: fila 0 = barra de titulo; filas 1..ui_rows() = cuerpo;
-- luego linea de mensajes y barra de acciones F1..F5 (clic o menu).
-- 40 columnas logicas (U.UI_COLS): el texto se coloca por columna (x = col*w/40),
-- y los tramos separados por 2 o mas espacios se colocan en su columna para que
-- las tablas alineen aunque la fuente sea proporcional.
-- A diferencia de la TI-84, el numero de filas del cuerpo depende de la ventana
-- (12 en la calculadora, 318x212): usar ui_rows() en vez de UI_ROWS.
--
-- Dibujo "libre" (graficas, figuras): ui_px_* con coordenadas relativas a la
-- esquina superior izquierda del CUERPO; ui_body_w()/ui_body_h() dan su tamano.
local rt = require("ui.rt")
local U = {}

U.UI_COLS = 40
for k, v in pairs(rt.K) do U[k] = v end
-- Colores (indices de la paleta): ver rt.PAL
U.C_BG, U.C_FG, U.C_TITLE, U.C_SEL, U.C_WARN, U.C_ERR, U.C_GRAY, U.C_BAR, U.C_OK,
  U.C_EDIT, U.C_LE, U.C_LP, U.C_GROUND, U.C_WATER = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
U.C_TRANSP = 254
local C_BG, C_FG, C_TITLE, C_GRAY, C_BAR = 0, 1, 2, 6, 7
local FONT = rt.FONT

-- Ajustes globales (g_set del C): los campos los llena la pantalla de Ajustes /
-- store (F3). Aqui solo se necesita .dec (decimales en pantalla).
U.g_set = { dec = 6 }
-- Estado persistente del documento: on.save devuelve esta tabla (ver main.lua).
U.state = { cfg = U.g_set, cas = {}, ver = 3 }

U.quit = false          -- ui_quit: el usuario pidio salir de la app

-- Avisa al documento de que hay datos nuevos que guardar (ctrl+S)
function U.mark_changed()
  if document and document.markChanged then document.markChanged() end
end
-- Lua no puede cerrar el documento: "salir" = guardar y volver al menu inicial
function U.ui_request_quit() U.quit = true end

function U.ui_init() U.quit = false end
function U.ui_exit() end
function U.ui_set_alpha_lock(on) end   -- en Nspire las letras llegan directas

function U.ui_rows() return rt.layout().rows end
function U.ui_body_w() return rt.layout().w end
function U.ui_body_h() local L = rt.layout(); return L.rows * L.rowh end
function U.ui_lh() return rt.layout().lh end
function U.ui_free_ram() return math.floor(collectgarbage("count") * 1024) end

-- ------------------------------------------------------------- texto
local emit = rt.emit

local function row_y(L, row)
  if row == 0 then return 1 end
  return L.y_body + (row - 1) * L.rowh
end

local function pal_ok(c) return c ~= nil and c ~= U.C_TRANSP end

-- Emite texto por tramos (2+ espacios separan tramos colocados por columna)
local function put_text(L, row, col, s, fg, bg, style)
  local y = row_y(L, row) + (row == 0 and 0 or 1)
  local n = #s
  if pal_ok(bg) and bg ~= C_BG and n > 0 then
    local ry = row == 0 and 0 or row_y(L, row)
    emit({ "fill", math.floor(col * L.cw), ry, math.ceil(n * L.cw), row == 0 and L.th or L.rowh, bg })
  end
  local i = 1
  while i <= n do
    local a = s:find("[^ ]", i)
    if not a then break end
    local sp = s:find("  ", a, true)
    local b = sp and (sp - 1) or n
    local seg = s:sub(a, b)
    emit({ "t", math.floor((col + a - 1) * L.cw), y, seg, fg, style or "r", FONT, "l" })
    i = b + 1
  end
end

function U.ui_text(row, col, s, fg, bg)
  put_text(rt.layout(), row, col, s, fg, bg, row == 0 and "b" or "r")
end

function U.ui_text_n(row, col, s, maxlen, fg, bg)
  if #s > maxlen then s = s:sub(1, maxlen) end
  if #s > U.UI_COLS then s = s:sub(1, U.UI_COLS) end
  U.ui_text(row, col, s, fg, bg)
end

-- Alineado a la derecha en la columna col_end (en pixeles, no por celdas)
function U.ui_text_r(row, col_end, s, fg, bg)
  local L = rt.layout()
  local y = row_y(L, row) + (row == 0 and 0 or 1)
  local xe = math.floor(col_end * L.cw)
  if pal_ok(bg) and bg ~= C_BG then
    local ry = row == 0 and 0 or row_y(L, row)
    local wcell = math.ceil(#s * L.cw)
    emit({ "fill", xe - wcell, ry, wcell, row == 0 and L.th or L.rowh, bg })
  end
  emit({ "t", xe, y, s, fg, row == 0 and "b" or "r", FONT, "r" })
end

function U.ui_row_fill(row, color)
  local L = rt.layout()
  if row == 0 then emit({ "fill", 0, 0, L.w, L.th, color })
  else emit({ "fill", 0, row_y(L, row), L.w, L.rowh, color }) end
end

function U.ui_begin(title, right)
  local L = rt.layout()
  rt.begin_frame()
  emit({ "fill", 0, 0, L.w, L.h, C_BG })
  emit({ "fill", 0, 0, L.w, L.th, C_TITLE })
  put_text(L, 0, 1, title or "", C_BG, C_TITLE, "b")
  if right then U.ui_text_r(0, 39, right, C_BG, C_TITLE) end
end

function U.ui_msg(s, color)
  local L = rt.layout()
  emit({ "fill", 0, L.y_msg, L.w, L.mh, C_BG })
  emit({ "line", 0, L.y_msg, L.w, L.y_msg, C_GRAY })
  if s and s ~= "" then
    emit({ "t", 2, L.y_msg + 1, s, color or C_GRAY, "r", FONT, "l", L.w - 4 })
  end
end

-- f: tabla de 5 etiquetas (1..5)
function U.ui_fbar(f)
  local L = rt.layout()
  emit({ "fill", 0, L.y_bar, L.w, L.ah, C_BAR })
  local cwid = L.w / 5
  local labels = {}
  for i = 1, 5 do
    local x = math.floor((i - 1) * cwid)
    emit({ "rect", x + 1, L.y_bar, math.floor(cwid) - 2, L.ah - 1, C_GRAY })
    local lab = f and f[i] or ""
    labels[i] = lab
    if lab ~= "" then
      emit({ "t", math.floor(x + cwid / 2), L.y_bar + math.floor((L.ah - L.lh) / 2), lab, C_FG, "r", FONT, "c",
             math.floor(cwid) - 4 })
    end
  end
  rt.set_fkeys(labels)
end

function U.ui_end() rt.publish() end

-- ------------------------------------------------------- dibujo libre
function U.ui_px_fill(x, y, w, h, color)
  if w <= 0 or h <= 0 then return end
  emit({ "fill", x, rt.layout().y_body + y, w, h, color })
end
function U.ui_px_rect(x, y, w, h, color)
  emit({ "rect", x, rt.layout().y_body + y, w, h, color })
end
function U.ui_px_line(x1, y1, x2, y2, color)
  local yb = rt.layout().y_body
  emit({ "line", x1, yb + y1, x2, yb + y2, color })
end
-- align: "l" (def.), "c" o "r" respecto a x
function U.ui_px_text(x, y, s, color, align)
  emit({ "t", x, rt.layout().y_body + y, s, color, "r", FONT, align or "l" })
end

-- ------------------------------------------------------------- teclado
-- Devuelve {k=K_*, c=caracter si K_CHAR, row= si K_CLICK}
function U.ui_getkey()
  local k = rt.getkey()
  if not k then return { k = U.K_NONE } end
  if k.k == U.K_QUIT then U.quit = true end
  return k
end

-- Cuadro de mensaje sobre el cuadro actual; true con ENTER
function U.ui_alert(title, l1, l2, color)
  local base = rt.frame
  for _ = 1, 1000000 do
    local L = rt.layout()
    local f = {}
    for i = 1, #base do f[i] = base[i] end
    rt.build = f
    local lh = L.lh
    local bw, bh = L.w - 36, 4 * lh + 24
    local bx, by = 18, math.floor((L.h - bh) / 2)
    emit({ "fill", bx - 1, by - 1, bw + 2, bh + 2, C_FG })
    emit({ "fill", bx, by, bw, bh, C_BG })
    emit({ "fill", bx, by, bw, lh + 3, color or U.C_ERR })
    emit({ "t", bx + 6, by + 1, title or "", C_BG, "b", FONT, "l", bw - 12 })
    if l1 then emit({ "t", bx + 6, by + lh + 8, l1, C_FG, "r", FONT, "l", bw - 12 }) end
    if l2 then emit({ "t", bx + 6, by + 2 * lh + 10, l2, C_FG, "r", FONT, "l", bw - 12 }) end
    emit({ "t", bx + 6, by + 3 * lh + 16, "[ENTER] aceptar   [ESC] volver", C_GRAY, "r", FONT, "l", bw - 12 })
    rt.publish()
    local k = U.ui_getkey()
    if k.k == U.K_ENTER then rt.frame = base; return true end
    if k.k == U.K_CLEAR or k.k == U.K_QUIT then rt.frame = base; return false end
  end
end

return U
