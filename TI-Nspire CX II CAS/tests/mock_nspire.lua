-- Simulacion minima de la API Lua de la TI-Nspire CX II para pruebas sin cabeza.
-- Uso (desde la raiz del repo):  local mock = dofile("tests/mock_nspire.lua")
--   local env = mock.load_app("build/app.lua")
--   mock.key("enter"); mock.key("a"); mock.click(10, 20)
--   local ops = mock.paint(); mock.has_text("..."); mock.dump_ops("build/x.json")
local mock = {}

mock.W, mock.H = 318, 212

-- ---------------------------------------------------------------- metricas
-- Aproximacion de sansserif: ancho medio ~6 px y alto ~12 px a tam 9 (CX II).
local function clampsize(s)
  s = tonumber(s) or 11
  if s < 7 then s = 7 elseif s > 24 then s = 24 end
  return s
end
local function str_w(s, style, size)
  local k = (2 / 3) * size
  if style == "b" or style == "bi" then k = k * 1.08 end
  -- los caracteres multibyte UTF-8 cuentan como uno
  local n = 0
  for _ in tostring(s):gmatch("[^\128-\191]") do n = n + 1 end
  return math.ceil(n * k)
end
local function str_h(size) return math.ceil(size * 4 / 3) end
mock.string_width, mock.string_height = str_w, str_h

-- ------------------------------------------------------------------ gc
-- Validaciones estrictas (la calculadora real es menos permisiva que Lua puro)
local FAMILIES = { sansserif = true, serif = true, monospace = true }
local STYLES = { r = true, b = true, i = true, bi = true }
local SIZES = { [7] = true, [9] = true, [10] = true, [11] = true, [12] = true, [16] = true, [24] = true }
mock.strict = true
local function int_arg(fn, name, v)
  if not mock.strict then return end
  if type(v) ~= "number" or v ~= math.floor(v) or v ~= v then
    error(fn .. ": '" .. name .. "' debe ser un entero (recibio " .. tostring(v) .. ")", 3)
  end
end
local function new_gc(ops)
  local gc = { font = { "sansserif", "r", 11 }, color = { 0, 0, 0 } }
  local function rec(name, ...)
    if ops then
      local op = { name, ... }
      op.color = { gc.color[1], gc.color[2], gc.color[3] }
      op.font = { gc.font[1], gc.font[2], gc.font[3] }
      ops[#ops + 1] = op
    end
  end
  function gc:setFont(fam, style, size)
    if mock.strict then
      assert(FAMILIES[fam], "setFont: familia no valida '" .. tostring(fam) .. "'")
      assert(STYLES[style], "setFont: estilo no valido '" .. tostring(style) .. "'")
      assert(SIZES[size], "setFont: tamano no permitido " .. tostring(size) .. " (7,9,10,11,12,16,24)")
    end
    self.font = { fam or "sansserif", style or "r", clampsize(size) }
    rec("setFont", fam, style, size)
  end
  function gc:setColorRGB(r, g, b)
    if type(r) == "table" then r, g, b = r[1], r[2], r[3] end
    assert(r and g and b, "setColorRGB: faltan componentes")
    int_arg("setColorRGB", "r", r); int_arg("setColorRGB", "g", g); int_arg("setColorRGB", "b", b)
    if mock.strict then assert(r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255,
      "setColorRGB: componente fuera de 0..255") end
    self.color = { r, g, b }
    rec("setColorRGB", r, g, b)
  end
  function gc:setPen(thick, style) rec("setPen", thick, style) end
  function gc:getStringWidth(s) return str_w(s, self.font[2], self.font[3]) end
  function gc:getStringHeight(s) return str_h(self.font[3]) end
  function gc:drawString(s, x, y, baseline)
    if mock.strict then
      assert(type(s) == "string", "drawString: el texto debe ser string")
      int_arg("drawString", "x", x); int_arg("drawString", "y", y)
      assert(baseline == "top", "drawString: pase siempre \"top\" como 4o argumento")
    end
    rec("drawString", tostring(s), x, y, baseline)
  end
  function gc:fillRect(x, y, w, h)
    int_arg("fillRect", "x", x); int_arg("fillRect", "y", y)
    int_arg("fillRect", "w", w); int_arg("fillRect", "h", h)
    rec("fillRect", x, y, w, h)
  end
  function gc:drawRect(x, y, w, h)
    int_arg("drawRect", "x", x); int_arg("drawRect", "y", y)
    int_arg("drawRect", "w", w); int_arg("drawRect", "h", h)
    rec("drawRect", x, y, w, h)
  end
  function gc:drawLine(x1, y1, x2, y2)
    int_arg("drawLine", "x1", x1); int_arg("drawLine", "y1", y1)
    int_arg("drawLine", "x2", x2); int_arg("drawLine", "y2", y2)
    rec("drawLine", x1, y1, x2, y2)
  end
  function gc:drawPolyLine(t)
    assert(type(t) == "table", "drawPolyLine: se espera una tabla")
    rec("drawPolyLine", t)
  end
  function gc:fillPolygon(t)
    assert(type(t) == "table", "fillPolygon: se espera una tabla")
    rec("fillPolygon", t)
  end
  function gc:drawArc(x, y, w, h, a, b) rec("drawArc", x, y, w, h, a, b) end
  function gc:fillArc(x, y, w, h, a, b) rec("fillArc", x, y, w, h, a, b) end
  function gc:drawImage(img, x, y) rec("drawImage", img, x, y) end
  function gc:clipRect(mode, x, y, w, h) rec("clipRect", mode, x, y, w, h) end
  function gc:setAlpha() end
  function gc:begin() end
  function gc:finish() end
  return gc
end

-- --------------------------------------------------------------- estado
local function fresh_state()
  mock.vars = {}
  mock.timer_running, mock.timer_period = false, nil
  mock.cursor_shown = true
  mock.cursor_shape = "default"
  mock.toolpalette_menu, mock.toolpalette_enabled = nil, {}
  mock.invalidated = 0
  mock.marked_changed = 0
  mock.last_ops = {}
  mock.log = {}
end

local function make_env()
  local env = {}
  for _, k in ipairs({ "assert", "error", "ipairs", "pairs", "next", "pcall", "xpcall",
      "select", "tonumber", "tostring", "type", "unpack", "setmetatable", "getmetatable",
      "rawget", "rawset", "rawequal", "collectgarbage", "string", "table", "math",
      "coroutine" }) do
    env[k] = _G[k]
  end
  env._G = env
  env.print = function(...)
    local t = {}
    for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
    mock.log[#mock.log + 1] = table.concat(t, "\t")
  end

  env.on = {}
  local window = {}
  function window:width() return mock.W end
  function window:height() return mock.H end
  function window:invalidate() mock.invalidated = mock.invalidated + 1 end
  function window:setFocus() end
  env.platform = {
    window = window,
    gc = function() return new_gc(nil) end,
    isColorDisplay = function() return true end,
    isDeviceModeRendering = function() return true end,
    hw = function() return 7 end,
  }

  env.var = {
    store = function(name, v) mock.vars[name] = v; return true end,
    recall = function(name) return mock.vars[name] end,
  }
  env.document = { markChanged = function() mock.marked_changed = mock.marked_changed + 1 end }
  env.toolpalette = {
    register = function(menu)
      assert(type(menu) == "table" and #menu >= 1, "toolpalette.register: se espera {{titulo, items...}}")
      for _, m in ipairs(menu) do
        assert(type(m) == "table" and type(m[1]) == "string",
          "toolpalette.register: cada menu es {\"Titulo\", {\"item\", fn}, ...}")
        for i = 2, #m do
          local it = m[i]
          assert(it == "-" or (type(it) == "table" and type(it[1]) == "string" and
            (type(it[2]) == "function" or type(it[2]) == "table")),
            "toolpalette.register: item invalido en '" .. m[1] .. "'")
        end
      end
      mock.toolpalette_menu = menu
    end,
    enable = function(name, item, flag)
      mock.toolpalette_enabled[name .. "/" .. tostring(item)] = flag
    end,
  }
  env.cursor = {
    show = function() mock.cursor_shown = true end,
    hide = function() mock.cursor_shown = false end,
    set = function(shape) mock.cursor_shape = shape end,
  }
  env.timer = {
    start = function(period) mock.timer_running, mock.timer_period = true, period end,
    stop = function() mock.timer_running = false end,
    getMilliSecCounter = function() return math.floor(os.clock() * 1000) end,
  }
  local img_mt = {}
  img_mt.__index = {
    width = function(self) return self.w end,
    height = function(self) return self.h end,
  }
  env.image = {
    new = function(a, b)
      local w, h = 1, 1
      if type(a) == "number" then w, h = a, b or a end
      return setmetatable({ w = w, h = h, src = a }, img_mt)
    end,
    width = function(i) return i.w end,
    height = function(i) return i.h end,
  }
  return env
end

-- ------------------------------------------------------------------ API
-- opts.old_order = true: SO antiguo (sin on.construction): on.create / on.resize / on.paint
function mock.load_app(path, opts)
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  fresh_state()
  local env = make_env()
  local chunk, err = loadstring(src, "@" .. path)
  assert(chunk, err)
  setfenv(chunk, env)
  chunk()
  mock.env = env
  if opts and opts.old_order then
    if env.on.create then env.on.create() end
  elseif opts and opts.no_init then
    -- ni construction ni create: solo resize/paint
  else
    if env.on.construction then env.on.construction() end
  end
  if env.on.resize and not (opts and opts.no_resize) then env.on.resize(mock.W, mock.H) end
  return env
end

local KEYS = {
  up = "arrowKey", down = "arrowKey", left = "arrowKey", right = "arrowKey",
  enter = "enterKey", ["return"] = "returnKey", esc = "escapeKey", escape = "escapeKey",
  backspace = "backspaceKey", delete = "deleteKey", tab = "tabKey", backtab = "backtabKey",
  clear = "clearKey", menu = "contextMenu", context = "contextMenu", home = "homeKey",
}

-- Despacha una tecla como lo haria el OS: nombre (ver KEYS) o un caracter.
function mock.key(k)
  local on = assert(mock.env, "load_app primero").on
  local h = KEYS[k]
  if h then
    local f = on[h]
    if f then
      if h == "arrowKey" then f(k) else f() end
    end
    return h
  end
  local single = #k == 1 or k:match("^[\192-\247][\128-\191]*$")
  assert(single, "mock.key: tecla desconocida '" .. tostring(k) .. "'")
  if on.charIn then on.charIn(k) end
  return "charIn"
end

function mock.click(x, y)
  local on = assert(mock.env, "load_app primero").on
  if on.mouseDown then on.mouseDown(x, y) end
  if on.mouseUp then on.mouseUp(x, y) end
end

function mock.tick()
  local on = assert(mock.env, "load_app primero").on
  if on.timer then on.timer() end
end

function mock.paint()
  local on = assert(mock.env, "load_app primero").on
  local ops = {}
  mock.last_ops = ops
  if on.paint then on.paint(new_gc(ops)) end
  return ops
end

-- Textos dibujados en el ultimo paint: { {text,x,y,w,h,size,style,color}, ... }
function mock.screen_text(ops)
  local out = {}
  for _, op in ipairs(ops or mock.last_ops) do
    if op[1] == "drawString" then
      local f = op.font
      out[#out + 1] = {
        text = op[2], x = op[3], y = op[4], size = f[3], style = f[2], color = op.color,
        w = str_w(op[2], f[2], f[3]), h = str_h(f[3]),
      }
    end
  end
  return out
end

function mock.has_text(s, ops)
  for _, t in ipairs(mock.screen_text(ops)) do
    if t.text:find(s, 1, true) then return true, t end
  end
  return false
end

local function deep_copy(v, seen)
  local tv = type(v)
  if tv == "function" or tv == "userdata" or tv == "thread" then
    error("on.save devolvio un valor no serializable (" .. tv .. ")", 3)
  end
  if tv ~= "table" then return v end
  seen = seen or {}
  if seen[v] then error("on.save devolvio una tabla con ciclos", 3) end
  seen[v] = true
  local c = {}
  for k, x in pairs(v) do c[deep_copy(k, seen)] = deep_copy(x, seen) end
  seen[v] = nil
  return c
end

-- Llama on.save() y devuelve una copia profunda (como el documento .tns).
function mock.save()
  local on = assert(mock.env, "load_app primero").on
  assert(on.save, "la app no define on.save")
  return deep_copy(on.save())
end

function mock.restore(t)
  local on = assert(mock.env, "load_app primero").on
  assert(on.restore, "la app no define on.restore")
  on.restore(deep_copy(t))
end

-- ----------------------------------------------------------- volcado JSON
local function jstr(s)
  local r = s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
    return string.format("\\u%04x", c:byte())
  end)
  return '"' .. r .. '"'
end
local function jval(v)
  local t = type(v)
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    return string.format("%.10g", v)
  elseif t == "string" then return jstr(v)
  elseif t == "boolean" then return tostring(v)
  elseif t == "table" then
    if getmetatable(v) and v.w then return '{"image":[' .. v.w .. "," .. v.h .. "]}" end
    local p = {}
    for i = 1, #v do p[i] = jval(v[i]) end
    return "[" .. table.concat(p, ",") .. "]"
  end
  return "null"
end

-- Escribe las operaciones como JSON: {"w":318,"h":212,"ops":[["fillRect",0,0,318,212],...]}
function mock.dump_ops(file, ops)
  ops = ops or mock.last_ops
  local lines = {}
  for i, op in ipairs(ops) do
    local p = {}
    for j = 1, table.maxn(op) do p[j] = jval(op[j]) end
    lines[i] = "[" .. table.concat(p, ",") .. "]"
  end
  local fh = assert(io.open(file, "wb"))
  fh:write(string.format('{"w":%d,"h":%d,"ops":[\n%s\n]}\n', mock.W, mock.H,
    table.concat(lines, ",\n")))
  fh:close()
end

fresh_state()
return mock
