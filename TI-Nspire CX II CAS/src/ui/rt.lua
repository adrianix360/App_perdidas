-- rt.lua - Runtime de la app: corrutina + lista de dibujo + traduccion de teclas.
--
-- La logica corre en UNA corrutina con estilo bloqueante (como el C): rt.getkey()
-- hace coroutine.yield(); cada evento on.* traduce a un codigo K_* y reanuda la
-- corrutina. El dibujo se graba en una lista de operaciones (rt.build) que
-- ui_end() publica como rt.frame; on.paint(gc) solo reproduce rt.frame.
--
-- IMPORTANTE (Lua 5.1): NO envolver con pcall/xpcall codigo que llame a getkey
-- (no se puede hacer yield a traves de pcall). pcall(require, ...) si es seguro.
local rt = {}

-- Teclas logicas (mismos valores que el enum de ui.h; K_CLICK es nuevo)
rt.K = {
  K_NONE = 0, K_UP = 1, K_DOWN = 2, K_LEFT = 3, K_RIGHT = 4, K_ENTER = 5,
  K_CLEAR = 6, K_DEL = 7, K_F1 = 8, K_F2 = 9, K_F3 = 10, K_F4 = 11, K_F5 = 12,
  K_MODE = 13, K_QUIT = 14, K_CHAR = 15, K_ALPHA = 16, K_INS = 17,
  K_PGUP = 18, K_PGDN = 19, K_CLICK = 20,
}
local K = rt.K

-- Paleta (indices C_* de ui.h) -> RGB
rt.PAL = {
  [0] = { 255, 255, 255 }, { 0, 0, 0 }, { 0, 51, 102 }, { 170, 205, 255 },
  { 190, 90, 0 }, { 200, 0, 0 }, { 110, 110, 110 }, { 215, 215, 215 },
  { 0, 120, 0 }, { 255, 240, 170 }, { 0, 70, 200 }, { 210, 0, 0 },
  { 150, 120, 90 }, { 120, 180, 255 },
}
local PAL = rt.PAL

-- Maqueta: TODAS las alturas salen de la altura real del texto (gc:getStringHeight)
-- medida en el gc de la calculadora; nada depende de constantes de pixeles.
rt.FONT = 9
local LH_FALLBACK = 12
local lh_cache            -- altura de linea medida (px) de sansserif FONT

local function measure_gc(g)
  local ok, h = pcall(function()
    g:setFont("sansserif", "r", rt.FONT)
    return g:getStringHeight("Ag")
  end)
  if ok and type(h) == "number" and h >= 6 and h <= 40 then return math.floor(h + 0.5) end
  return nil
end

local function line_height()
  if lh_cache then return lh_cache end
  local g
  if platform and platform.gc then
    local ok, v = pcall(platform.gc)
    if ok then g = v end
  end
  lh_cache = (g and measure_gc(g)) or LH_FALLBACK
  return lh_cache
end

function rt.layout()
  local w, h = platform.window:width(), platform.window:height()
  local lh = line_height()
  local TH, MH, AH = lh + 4, lh + 3, lh + 7
  local rowh = lh + 1
  local avail = h - TH - MH - AH - 2
  local rows = math.floor(avail / rowh)
  if rows < 3 then rows = 3 end
  rowh = math.floor(avail / rows)
  return {
    w = w, h = h, cw = w / 40, th = TH, mh = MH, ah = AH, rowh = rowh, rows = rows, lh = lh,
    y_body = TH + 1, y_bar = h - AH, y_msg = h - AH - MH,
  }
end

-- Recalcula la maqueta con el gc de on.paint (la medida real manda). true si cambio.
function rt.remeasure(gc)
  local lh = measure_gc(gc)
  if lh and lh ~= lh_cache then lh_cache = lh; return true end
  return false
end

-- ---------------------------------------------------------------- dibujo
rt.frame = {}      -- ultimo cuadro publicado
rt.build = nil     -- cuadro en construccion
rt.fkeys = {}      -- etiquetas F1..F5 del cuadro publicado
rt.fatal = nil     -- mensaje de error de la corrutina
rt.finished = false

function rt.emit(op)
  local b = rt.build
  if not b then b = {}; rt.build = b end
  b[#b + 1] = op
end

function rt.begin_frame() rt.build = {} end

function rt.publish()
  rt.frame = rt.build or {}
  rt.build = nil
end

local function wrap(s, n)
  local out = {}
  s = tostring(s)
  for part in (s .. "\n"):gmatch("(.-)\n") do
    while #part > n do
      out[#out + 1] = part:sub(1, n)
      part = part:sub(n + 1)
    end
    out[#out + 1] = part
  end
  return out
end

local function set_font(gc, st, style, size)
  if st.style ~= style or st.size ~= size then
    gc:setFont("sansserif", style, size)
    st.style, st.size = style, size
  end
end

local function set_color(gc, st, c)
  if st.col ~= c then
    local p = PAL[c] or PAL[1]
    gc:setColorRGB(math.floor(p[1]), math.floor(p[2]), math.floor(p[3]))
    st.col = c
  end
end

-- Reproduce una lista de operaciones sobre gc
local function fl(v)
  v = math.floor((tonumber(v) or 0) + 0.5)
  if v ~= v or v > 100000 then return 0 elseif v < -100000 then return -100000 end
  return v
end

function rt.replay(gc, ops)
  local st = {}
  for i = 1, #ops do
    local op = ops[i]
    local c = op[1]
    if c == "fill" then
      -- la API real exige enteros; un rectangulo vacio no se dibuja
      local w, h = fl(op[4]), fl(op[5])
      if w > 0 and h > 0 then
        set_color(gc, st, op[6]); gc:fillRect(fl(op[2]), fl(op[3]), w, h)
      end
    elseif c == "rect" then
      local w, h = fl(op[4]), fl(op[5])
      if w > 0 and h > 0 then
        set_color(gc, st, op[6]); gc:drawRect(fl(op[2]), fl(op[3]), w, h)
      end
    elseif c == "line" then
      set_color(gc, st, op[6]); gc:drawLine(fl(op[2]), fl(op[3]), fl(op[4]), fl(op[5]))
    elseif c == "t" then
      -- {"t", x, y, s, fg, style, size, align, maxw}
      local s, align = op[4], op[8]
      set_font(gc, st, op[6], op[7])
      set_color(gc, st, op[5])
      local x = op[2]
      if align ~= "l" or op[9] then
        local w = gc:getStringWidth(s)
        if op[9] and w > op[9] and op[7] > 7 then      -- primero una fuente menor (7)
          set_font(gc, st, op[6], 7); w = gc:getStringWidth(s)
        end
        if op[9] then
          while w > op[9] and #s > 1 do
            s = s:sub(1, #s - 1); w = gc:getStringWidth(s)
          end
        end
        if align == "r" then x = x - w elseif align == "c" then x = x - math.floor(w / 2) end
      end
      gc:drawString(s, fl(x), fl(op[3]), "top")
    end
  end
end

-- ------------------------------------------------------------- corrutina
local co, main_fn

local function fkeys_changed(labels)
  local key = table.concat(labels, "|", 1, 5)
  if key == rt.fk_key then return end
  rt.fk_key = key
  rt.fkeys = labels
  if toolpalette and toolpalette.register then
    local items = {}
    for i = 1, 5 do
      local lab = labels[i]
      if lab and lab ~= "" then
        local kk = K.K_F1 + i - 1
        items[#items + 1] = { lab, function() rt.feed({ k = kk }) end }
      end
    end
    items[#items + 1] = { "Ajustes", function() rt.feed({ k = K.K_MODE }) end }
    toolpalette.register({ { "Acciones", unpack(items) } })
  end
end

-- Llamada por ui_fbar: guarda las etiquetas del cuadro y refresca la paleta
function rt.set_fkeys(labels)
  local l = {}
  for i = 1, 5 do l[i] = labels and labels[i] or "" end
  rt.pending_fk = l
end

function rt.getkey()
  if rt.pending_fk then fkeys_changed(rt.pending_fk) end
  return coroutine.yield()
end

local function invalidate()
  if platform and platform.window then platform.window:invalidate() end
end

local function resume(key)
  local ok, err = coroutine.resume(co, key)
  if not ok then
    rt.fatal = tostring(err)
    rt.build = nil
  elseif coroutine.status(co) == "dead" then
    rt.finished = true
  end
end

function rt.start(fn)
  main_fn = fn or main_fn
  rt.fatal, rt.finished, rt.build, rt.frame = nil, false, nil, {}
  rt.fk_key, rt.pending_fk = nil, nil
  co = coroutine.create(main_fn)
  resume(nil)
  invalidate()
end

function rt.running() return co ~= nil and coroutine.status(co) == "suspended" end

-- Entrega una tecla (tabla {k=, c=...}) a la corrutina
function rt.feed(key)
  if rt.fatal or rt.finished then
    if key.k == K.K_ENTER or key.k == K.K_F5 then rt.start() end
    invalidate()
    return
  end
  if co and coroutine.status(co) == "suspended" then resume(key) end
  invalidate()
end

-- ---------------------------------------------------------------- eventos
local function norm_char(ch)
  if ch == "\226\136\146" then return "-" end        -- U+2212
  if ch == "\225\180\135" then return "E" end        -- U+1D07 (tecla EE)
  if ch == "\195\151" then return "*" end            -- multiplicacion
  if ch == "\195\183" then return "/" end            -- division
  return ch
end
rt.norm_char = norm_char

local function paint_fatal(gc)
  local w, h = platform.window:width(), platform.window:height()
  gc:setColorRGB(255, 255, 255); gc:fillRect(0, 0, w, h)
  gc:setColorRGB(200, 0, 0); gc:fillRect(0, 0, w, 16)
  gc:setColorRGB(255, 255, 255); gc:setFont("sansserif", "b", 9)
  gc:drawString("Error de la app", 4, 1, "top")
  gc:setColorRGB(0, 0, 0); gc:setFont("sansserif", "r", 9)
  local lines = wrap(rt.fatal or "?", 52)
  local y = 22
  for i = 1, #lines do
    if y > h - 30 then break end
    gc:drawString(lines[i], 4, y, "top"); y = y + 13
  end
  gc:setColorRGB(110, 110, 110)
  gc:drawString("ENTER: reiniciar la app", 4, h - 16, "top")
end

local function paint_done(gc)
  local w, h = platform.window:width(), platform.window:height()
  gc:setColorRGB(255, 255, 255); gc:fillRect(0, 0, w, h)
  gc:setColorRGB(0, 0, 0); gc:setFont("sansserif", "r", 9)
  gc:drawString("La app termino.", 4, 20, "top")
  gc:drawString("ENTER: volver a empezar", 4, 36, "top")
end

function rt.paint(gc)
  if rt.remeasure(gc) and rt.running() then rt.feed({ k = K.K_NONE }) end
  if rt.fatal then return paint_fatal(gc) end
  if rt.finished then return paint_done(gc) end
  rt.replay(gc, rt.frame)
end

function rt.install(on, fn)
  main_fn = fn
  rt.app_main = fn
  local function f(k, extra)
    local t = { k = K[k] }
    if extra then for a, b in pairs(extra) do t[a] = b end end
    rt.feed(t)
  end
  -- Orden de llamadas segun el SO: construction (nuevo) o create (antiguo), resize, paint.
  -- ensure_started es idempotente y tambien se llama desde paint/resize por si el SO
  -- no llamo a ninguno de los dos.
  local function ensure_started()
    if not co then rt.start(main_fn) end
  end
  on.construction = ensure_started
  on.create = ensure_started
  on.resize = function()
    ensure_started()
    if rt.running() then rt.feed({ k = K.K_NONE }) end
  end
  on.paint = function(gc)
    ensure_started()
    rt.paint(gc)
  end
  on.arrowKey = function(a)
    f(({ up = "K_UP", down = "K_DOWN", left = "K_LEFT", right = "K_RIGHT" })[a] or "K_NONE")
  end
  on.enterKey = function() f("K_ENTER") end
  on.returnKey = function() f("K_ENTER") end
  on.escapeKey = function() f("K_CLEAR") end
  on.clearKey = function() f("K_CLEAR") end
  on.backspaceKey = function() f("K_DEL") end
  on.deleteKey = function() f("K_DEL") end
  on.tabKey = function() f("K_PGDN") end
  on.backtabKey = function() f("K_PGUP") end
  on.contextMenu = function() f("K_MODE") end
  on.charIn = function(ch)
    if not ch or ch == "" or ch:byte(1) < 32 then return end   -- ignora caracteres de control
    f("K_CHAR", { c = norm_char(ch) })
  end
  on.mouseDown = function(x, y)
    local L = rt.layout()
    if y >= L.y_bar then
      local i = math.floor(x / (L.w / 5)) + 1
      if i < 1 then i = 1 elseif i > 5 then i = 5 end
      local lab = rt.fkeys[i]
      if lab and lab ~= "" then f("K_F" .. i) end
    elseif y >= L.y_body and y < L.y_body + L.rows * L.rowh then
      f("K_CLICK", { row = math.floor((y - L.y_body) / L.rowh) + 1, x = x, y = y })
    end
  end
end

return rt
