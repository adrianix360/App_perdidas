-- widgets.lua - Menus, formularios, visor de lineas, listas y entrada de texto
-- (port de widgets.c / widgets.h). Mismos nombres y semantica que el C.
--
-- Convenciones del port (para portar pantallas casi linea a linea):
--  * Indices que son ESTADO o RESULTADO (cur, top, ch, retorno de menu_run y
--    list_pick, list_line[]) son 0-based como en C; los arreglos que se escriben
--    como literales Lua (m.items, fm.f, choices, fk) son 1-based y el widget
--    hace arr[idx+1].
--  * Puntero a variable (real *val, uint8_t *ch, uint8_t *set) -> referencia por
--    tabla + nombre de campo:  t = tabla, k = clave del valor, chk = clave del
--    indice de opcion (FF_CHOICE), setk = clave del "tiene valor" (0/1/nil).
--    Alternativa: funciones get()/put(v) (valor), cget()/cput(i) (opcion),
--    hget()/hput(b) (tiene valor).
--  * Los menus/formularios son tablas: menu {title=, items={...}, n=, cur=0};
--    form {title=, page=, f={...}, n=, cur=0, top=0, fk={5 etiquetas}, hint=,
--    msg=, msg_color=, on_commit=fn, restart=0|1}.
--  * Las teclas son tablas {k=K_*, c=}: ui_getkey() las devuelve; form_run,
--    view_run devuelven el codigo numerico K_*; list_pick devuelve (indice, K_*).
--  * Rutinas bloqueantes: NO llamarlas dentro de pcall.
local U = require("ui.ui")
local nf = require("ui.numfmt")
local expr = require("ui.expr")
local W = {}

for k, v in pairs(U) do
  if k:match("^K_") or k:match("^C_") then W[k] = v end
end
W.MENU_BACK, W.MENU_QUIT, W.MENU_MODE = -1, -2, -3
W.FF_ANY, W.FF_POS, W.FF_NONNEG, W.FF_CHOICE, W.FF_INT, W.FF_OPT, W.FF_INFO, W.FF_RANGE =
  0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40
W.DEC_MAX = 9
W.VIEW_MAX = 160
W.LIST_MAX = 40
W.APP_NAME = "PERDIDAS"       -- main/flujos lo cambian segun el programa

local K_NONE, K_UP, K_DOWN, K_LEFT, K_RIGHT, K_ENTER, K_CLEAR, K_DEL = U.K_NONE, U.K_UP,
  U.K_DOWN, U.K_LEFT, U.K_RIGHT, U.K_ENTER, U.K_CLEAR, U.K_DEL
local K_F1, K_F5, K_MODE, K_QUIT, K_CHAR, K_ALPHA, K_PGUP, K_PGDN, K_CLICK =
  U.K_F1, U.K_F5, U.K_MODE, U.K_QUIT, U.K_CHAR, U.K_ALPHA, U.K_PGUP, U.K_PGDN, U.K_CLICK
local C_BG, C_FG, C_TITLE, C_SEL, C_ERR, C_GRAY, C_EDIT =
  U.C_BG, U.C_FG, U.C_TITLE, U.C_SEL, U.C_ERR, U.C_GRAY, U.C_EDIT
local FF = { POS = 1, NONNEG = 2, CHOICE = 4, INT = 8, OPT = 16, INFO = 32, RANGE = 64 }

local function hasf(flags, f) return math.floor((flags or 0) / f) % 2 == 1 end
W.hasf = hasf

local function is_fk(k) return k >= K_F1 and k <= K_F5 end

local function expr_eval(s)
  local e, v = expr.expr_eval(s)
  return e, v
end

-- ===================================================================== Menu
local MENU_FK = { "", "", "", "AJUSTES", "ELEGIR" }

function W.menu_run(m)
  local n = m.n or #m.items
  if (m.cur or 0) >= n then m.cur = 0 end
  m.cur = m.cur or 0
  local top = 0
  while true do
    if U.quit then return W.MENU_QUIT end
    local vis = U.ui_rows()
    if m.cur < top then top = m.cur end
    if m.cur >= top + vis then top = m.cur - vis + 1 end
    U.ui_begin(m.title, W.APP_NAME)
    for i = top, math.min(n, top + vis) - 1 do
      local sel = (i == m.cur)
      local row = i - top + 1
      if sel then U.ui_row_fill(row, C_SEL) end
      local bg = sel and C_SEL or C_BG
      U.ui_text(row, 1, i < 9 and tostring(i + 1) or "*", C_GRAY, bg)
      U.ui_text(row, 4, m.items[i + 1], C_FG, bg)
    end
    if n > vis then
      if top > 0 then U.ui_text(1, 39, "^", C_GRAY, C_BG) end
      if top + vis < n then U.ui_text(vis, 39, "v", C_GRAY, C_BG) end
    end
    U.ui_msg("Flechas o 1-9; ENTER elige; ESC vuelve", C_GRAY)
    U.ui_fbar(MENU_FK)
    U.ui_end()

    local k = U.ui_getkey()
    local kk = k.k
    if kk == K_QUIT then return W.MENU_QUIT
    elseif kk == K_CLEAR then return W.MENU_BACK
    elseif kk == K_MODE or kk == U.K_F4 then return W.MENU_MODE
    elseif kk == K_UP then m.cur = m.cur > 0 and m.cur - 1 or n - 1
    elseif kk == K_DOWN then m.cur = (m.cur + 1 < n) and m.cur + 1 or 0
    elseif kk == K_PGUP then m.cur = math.max(0, m.cur - vis)
    elseif kk == K_PGDN then m.cur = math.min(n - 1, m.cur + vis)
    elseif kk == K_ENTER or kk == K_F5 or kk == K_RIGHT then return m.cur
    elseif kk == K_CLICK then
      local i = top + k.row - 1
      if i >= 0 and i < n then m.cur = i; return i end
    elseif kk == K_CHAR then
      local d = tonumber(k.c)
      if d and d >= 1 and d <= 9 and d <= n and k.c:match("^%d$") then
        m.cur = d - 1
        return m.cur
      end
    end
  end
end

-- ================================================================ Formulario
local function f_get(f)
  if f.get then return f.get() end
  return f.t[f.k]
end
local function f_put(f, v)
  if f.put then f.put(v) else f.t[f.k] = v end
end
local function f_cget(f)
  if f.cget then return f.cget() end
  return f.t[f.chk]
end
local function f_cput(f, i)
  if f.cput then f.cput(i) else f.t[f.chk] = i end
end
local function field_has(f)
  if f.hget then return f.hget() end
  if f.setk then
    local v = f.t[f.setk]
    return v ~= nil and v ~= 0 and v ~= false
  end
  return true
end
local function field_set_has(f, b)
  if f.hput then f.hput(b) elseif f.setk then f.t[f.setk] = b and 1 or 0 end
end
local function can_clear(f) return f.hput ~= nil or f.setk ~= nil end

function W.form_value_text(f)
  if hasf(f.flags, FF.CHOICE) then
    return f.choices[f_cget(f) + 1] or "?"
  elseif not field_has(f) then
    return "--"
  end
  return nf.fmt_real(f_get(f), U.g_set.dec or 6)
end

-- Valida un valor para el campo; devuelve mensaje o nil
local function field_err(f, v)
  local fl = f.flags
  if hasf(fl, FF.POS) and not (v > 0) then return "Debe ser mayor que 0" end
  if hasf(fl, FF.NONNEG) and not (v >= 0) then return "No puede ser negativo" end
  if (hasf(fl, FF.INT) or hasf(fl, FF.RANGE)) and not (v >= f.lo and v <= f.hi) then
    return "Fuera del rango permitido"
  end
  if hasf(fl, FF.INT) and v ~= math.floor(v) then return "Debe ser un numero entero" end
  return nil
end

local function form_draw(fm, editing, ebuf)
  local vis = U.ui_rows()
  local n = fm.n or #fm.f
  U.ui_begin(fm.title, fm.page)
  if fm.cur < fm.top then fm.top = fm.cur end
  if fm.cur >= fm.top + vis then fm.top = fm.cur - vis + 1 end
  for i = fm.top, math.min(n, fm.top + vis) - 1 do
    local f = fm.f[i + 1]
    local sel = (i == fm.cur)
    local bg = sel and C_SEL or C_BG
    local row = i - fm.top + 1
    if sel then U.ui_row_fill(row, C_SEL) end
    local lab = f.label
    if #lab > 22 then lab = lab:sub(1, 22) end
    U.ui_text(row, 1, lab, hasf(f.flags, FF.INFO) and C_GRAY or C_FG, bg)
    if sel and editing then
      local s = ebuf
      if #s > 13 then s = s:sub(#s - 12) end
      U.ui_text(row, 19, string.rep(" ", 13), C_FG, C_EDIT)
      U.ui_text(row, 19, s .. "_", C_FG, C_EDIT)
    else
      local txt = W.form_value_text(f)
      if hasf(f.flags, FF.CHOICE) then
        U.ui_text(row, 19, "<", C_GRAY, bg)
        U.ui_text_n(row, 20, txt, 18, C_FG, bg)
        U.ui_text_r(row, 40, ">", C_GRAY, bg)
      else
        U.ui_text_r(row, 31, txt, field_has(f) and C_FG or C_GRAY, bg)
      end
    end
    if f.unit and not hasf(f.flags, FF.CHOICE) then
      U.ui_text_n(row, 32, f.unit, 7, C_GRAY, bg)
    end
  end
  if n > vis then
    local L_top = fm.top > 0
    if L_top then U.ui_text(1, 39, "^", C_GRAY, C_BG) end
    if fm.top + vis < n then U.ui_text(vis, 39, "v", C_GRAY, C_BG) end
  end
  if fm.msg then U.ui_msg(fm.msg, fm.msg_color or C_GRAY)
  elseif editing then U.ui_msg("ENTER acepta; DEL borra; E = exponente", C_GRAY)
  else U.ui_msg(fm.hint or "Escriba un valor o expresion", C_GRAY) end
  U.ui_fbar(fm.fk)
  U.ui_end()
end

local function set_msg(fm, m, color)
  fm.msg = m
  fm.msg_color = color
end

local function commit(fm, ebuf)
  local f = fm.f[fm.cur + 1]
  local e, v = expr_eval(ebuf)
  if e == expr.EXPR_EMPTY and hasf(f.flags, FF.OPT) then
    if can_clear(f) then field_set_has(f, false) end
    return true
  end
  if e ~= expr.EXPR_OK then
    set_msg(fm, expr.expr_err_text(e), U.C_ERR)
    return false
  end
  local err = field_err(f, v)
  if err then set_msg(fm, err, U.C_ERR); return false end
  f_put(f, v)
  if can_clear(f) then field_set_has(f, true) end
  if fm.on_commit then fm.on_commit() end
  return true
end

-- Revisa que los campos obligatorios tengan valor valido
function W.form_check(fm)
  local n = fm.n or #fm.f
  for i = 0, n - 1 do
    local f = fm.f[i + 1]
    if not (hasf(f.flags, FF.CHOICE) or hasf(f.flags, FF.INFO)) then
      if not field_has(f) then
        if not hasf(f.flags, FF.OPT) then
          fm.cur = i
          set_msg(fm, "Falta este dato", U.C_ERR)
          return false
        end
      else
        local err = field_err(f, f_get(f))
        if err then
          fm.cur = i
          set_msg(fm, err, U.C_ERR)
          return false
        end
      end
    end
  end
  return true
end

local function move(fm, d)
  local n = fm.n or #fm.f
  local tries = n
  repeat
    if d > 0 then fm.cur = (fm.cur + 1 < n) and fm.cur + 1 or 0
    else fm.cur = fm.cur > 0 and fm.cur - 1 or n - 1 end
    tries = tries - 1
  until not hasf(fm.f[fm.cur + 1].flags, FF.INFO) or tries <= 0
end

local EBUF_LEN = 64
local EDIT_CHARS = "^[%d%.%+%-%*/%(%)%^Ee,]$"

function W.form_run(fm)
  fm.n = fm.n or #fm.f
  fm.cur = fm.cur or 0
  fm.top = fm.top or 0
  fm.fk = fm.fk or { "", "", "", "", "" }
  local ebuf, editing = "", false
  if fm.cur >= fm.n then fm.cur = 0 end
  if hasf(fm.f[fm.cur + 1].flags, FF.INFO) then move(fm, 1) end
  while true do
    if U.quit then return K_QUIT end
    form_draw(fm, editing, ebuf)
    fm.msg = nil
    local k = U.ui_getkey()
    local kk = k.k
    if kk == K_QUIT then return K_QUIT end
    local proceed = true
    if kk == K_NONE or kk == K_ALPHA then
      proceed = false
    elseif kk == K_CLICK then
      local i = fm.top + k.row - 1
      if not editing and i >= 0 and i < fm.n and not hasf(fm.f[i + 1].flags, FF.INFO) then
        fm.cur = i
      end
      proceed = false
    elseif editing then
      if kk == K_CHAR then
        local c = k.c
        if c == "," then c = "." end
        if c == "e" then c = "E" end
        if c:match(EDIT_CHARS) then
          if #ebuf < EBUF_LEN - 1 then ebuf = ebuf .. c
          else set_msg(fm, "Expresion demasiado larga", U.C_ERR) end
        end
        proceed = false
      elseif kk == K_DEL or kk == K_LEFT then
        if #ebuf > 0 then ebuf = ebuf:sub(1, #ebuf - 1) end
        proceed = false
      elseif kk == K_CLEAR then
        if #ebuf > 0 then ebuf = "" else editing = false end
        proceed = false
      elseif kk == K_ENTER or kk == K_UP or kk == K_DOWN or kk == K_PGUP or kk == K_PGDN
          or is_fk(kk) or kk == K_MODE then
        if not commit(fm, ebuf) then
          proceed = false
        else
          editing = false
          ebuf = ""
          if fm.restart and fm.restart ~= 0 then
            fm.restart = 0
            if kk == K_ENTER or kk == K_DOWN then move(fm, 1) end
            return K_NONE
          end
        end
      else
        proceed = false
      end
    end
    if proceed then
      local f = fm.f[fm.cur + 1]
      if kk == K_CLEAR then return K_CLEAR
      elseif kk == K_MODE then return K_MODE
      elseif is_fk(kk) then return kk
      elseif kk == K_UP then move(fm, -1)
      elseif kk == K_DOWN then move(fm, 1)
      elseif kk == K_PGUP then
        fm.cur = 0
        if hasf(fm.f[1].flags, FF.INFO) then move(fm, 1) end
      elseif kk == K_PGDN then
        fm.cur = fm.n - 1
        if hasf(fm.f[fm.cur + 1].flags, FF.INFO) then move(fm, -1) end
      elseif kk == K_ENTER then
        if fm.cur + 1 >= fm.n then return K_ENTER end
        move(fm, 1)
      elseif kk == K_LEFT or kk == K_RIGHT then
        if hasf(f.flags, FF.CHOICE) then
          local c = f_cget(f)
          local nc = f.nchoices or #f.choices
          if kk == K_RIGHT then c = (c + 1) % nc
          else c = c > 0 and c - 1 or nc - 1 end
          f_cput(f, c)
          if fm.on_commit then fm.on_commit() end
        elseif kk == K_RIGHT and not hasf(f.flags, FF.INFO) then
          if field_has(f) then ebuf = nf.fmt_real(f_get(f), W.DEC_MAX) else ebuf = "" end
          editing = true
        end
      elseif kk == K_DEL then
        if hasf(f.flags, FF.OPT) and can_clear(f) then
          field_set_has(f, false)
          set_msg(fm, "Campo vaciado (opcional)", C_GRAY)
        end
      elseif kk == K_CHAR then
        if not (hasf(f.flags, FF.CHOICE) or hasf(f.flags, FF.INFO)) then
          local c = k.c
          if c == "," then c = "." end
          if c == "e" then c = "E" end
          if c:match(EDIT_CHARS) then
            editing = true
            ebuf = c
          end
        end
      end
    end
  end
end

-- ============================================================ Visor de lineas
W.view_line = {}       -- 1..view_n
W.view_color = {}
W.view_n = 0

function W.view_clear() W.view_n = 0 end

function W.view_add(s, color)
  if W.view_n >= W.VIEW_MAX then return end
  W.view_n = W.view_n + 1
  W.view_line[W.view_n] = s:sub(1, U.UI_COLS)
  W.view_color[W.view_n] = color
end

-- "  etiqueta = valor unidad" con el formato de los ajustes
function W.view_add_val(label, v, unit)
  local num = nf.fmt_real(v, U.g_set.dec or 6)
  local line = " " .. label:sub(1, 16)
  line = line .. string.rep(" ", 17 - #line) .. "= " .. num
  if unit and #line < U.UI_COLS - 1 then line = line .. " " .. unit end
  W.view_add(line, C_FG)
end

function W.view_add_sep() W.view_add(string.rep("-", 40), C_GRAY) end

function W.view_run(title, fk)
  local top = 0
  while true do
    if U.quit then return K_QUIT end
    local vis = U.ui_rows()
    local vn = W.view_n
    U.ui_begin(title, nil)
    for i = 0, vis - 1 do
      if top + i >= vn then break end
      U.ui_text(i + 1, 0, W.view_line[top + i + 1], W.view_color[top + i + 1], C_BG)
    end
    if vn > vis then
      local pages = math.floor((vn + vis - 1) / vis)
      local pg = (top + vis >= vn) and pages or math.floor(top / vis) + 1
      U.ui_text_r(0, 39, pg .. "/" .. pages, C_BG, C_TITLE)
      U.ui_msg("Flechas: desplazar; ESC vuelve", C_GRAY)
    else
      U.ui_msg("ESC vuelve", C_GRAY)
    end
    U.ui_fbar(fk)
    U.ui_end()
    local k = U.ui_getkey()
    local kk = k.k
    if kk == K_UP then if top > 0 then top = top - 1 end
    elseif kk == K_DOWN then if top + vis < vn then top = top + 1 end
    elseif kk == K_LEFT or kk == K_PGUP then top = (top > vis) and top - vis or 0
    elseif kk == K_RIGHT or kk == K_PGDN then
      if top + vis < vn then
        top = (top + 2 * vis <= vn) and top + vis or vn - vis
      end
    elseif kk == K_CLEAR or kk == K_QUIT or kk == K_MODE or is_fk(kk) then
      return kk
    end
  end
end

-- ======================================================= Lista con desplazamiento
W.list_line = {}     -- 0-based: list_line[0 .. n-1]

function W.list_pick(title, hint, n, cur, fk)
  local top = 0
  if cur >= n then cur = 0 end
  while true do
    if U.quit then return -1, K_QUIT end
    local vis = U.ui_rows()
    if cur < top then top = cur end
    if cur >= top + vis then top = cur - vis + 1 end
    U.ui_begin(title, nil)
    for i = 0, vis - 1 do
      if top + i >= n then break end
      local sel = (top + i == cur)
      if sel then U.ui_row_fill(i + 1, C_SEL) end
      U.ui_text_n(i + 1, 0, W.list_line[top + i], U.UI_COLS, C_FG, sel and C_SEL or C_BG)
    end
    if n == 0 then U.ui_text(2, 1, "(vacio)", C_GRAY, C_BG) end
    U.ui_msg(hint or "Flechas; ENTER elige; ESC vuelve", C_GRAY)
    U.ui_fbar(fk)
    U.ui_end()
    local k = U.ui_getkey()
    local kk = k.k
    if kk == K_UP then if n > 0 then cur = cur > 0 and cur - 1 or n - 1 end
    elseif kk == K_DOWN then if n > 0 then cur = (cur + 1 < n) and cur + 1 or 0 end
    elseif kk == K_PGUP or kk == K_LEFT then cur = cur > vis and cur - vis or 0
    elseif kk == K_PGDN or kk == K_RIGHT then
      if n > 0 then cur = (cur + vis < n) and cur + vis or n - 1 end
    elseif kk == K_CLICK then
      local i = top + k.row - 1
      if i >= 0 and i < n then
        if i == cur then return cur, K_ENTER end
        cur = i
      end
    elseif kk == K_ENTER then
      if n > 0 then return cur, K_ENTER end
    elseif is_fk(kk) then
      return (n > 0) and cur or -1, kk
    elseif kk == K_CLEAR or kk == K_QUIT or kk == K_MODE then
      return -1, kk
    end
  end
end

-- ============================================================ Entrada de texto
-- Letras A-Z (las minusculas se pasan a mayuscula) y digitos directos.
-- Devuelve (true, texto) o (false, texto original).
function W.text_input(title, prompt, buf, maxlen)
  local fk = { "", "", "", "", "LISTO" }
  local orig = buf
  buf = buf or ""
  while true do
    if U.quit then return false, orig end
    U.ui_begin(title, "A-Z 0-9")
    U.ui_text(2, 1, prompt, C_FG, C_BG)
    U.ui_row_fill(4, C_EDIT)
    U.ui_text(4, 2, buf .. "_", C_FG, C_EDIT)
    U.ui_text(7, 1, "Escriba letras y numeros directamente.", C_GRAY, C_BG)
    U.ui_text(8, 1, "DEL borra; ENTER guarda; ESC cancela", C_GRAY, C_BG)
    U.ui_msg(nil, C_GRAY)
    U.ui_fbar(fk)
    U.ui_end()
    local k = U.ui_getkey()
    local kk = k.k
    if kk == K_CHAR then
      local c = k.c:upper()
      if c:match("^[A-Z0-9]$") and #buf < maxlen then buf = buf .. c end
    elseif kk == K_DEL or kk == K_LEFT then
      if #buf > 0 then buf = buf:sub(1, #buf - 1) end
    elseif kk == K_ENTER or kk == K_F5 then
      if #buf > 0 then return true, buf end
    elseif kk == K_CLEAR or kk == K_QUIT then
      return false, orig
    end
  end
end

-- Aviso de modulo pendiente
function W.todo_alert(what, fase)
  U.ui_alert("En construccion", what, "Disponible en la fase " .. tostring(fase), U.C_WARN)
end

return W
