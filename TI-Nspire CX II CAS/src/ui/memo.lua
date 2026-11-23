-- memo.lua - Memoria de calculo paso a paso (port de memo.c). Escribe en el
-- visor de lineas (widgets.view_*). Colores: ui.C_*.
local U = require("ui.ui")
local W = require("ui.widgets")
local nf = require("ui.numfmt")
local T = require("ui.texts")
local M = {}
local WID = U.UI_COLS
local C_FG, C_TITLE, C_GRAY, C_OK = U.C_FG, U.C_TITLE, U.C_GRAY, U.C_OK

-- Real en a lo sumo `width` caracteres
function M.fmt_w(x, width)
  local s
  for d = 6, 0, -1 do
    s = nf.fmt_real(x, d)
    if #s <= width then return s end
  end
  return s
end
local fmt_w = M.fmt_w

-- Formato con %v (real con los decimales de Ajustes), %w (real corto, 7
-- caracteres), %s (texto), %d (entero) y %% . mfmt(fmt, ...) -> string
function M.mfmt(fmt, ...)
  local args = { ... }
  local ai = 0
  return (fmt:gsub("%%(.?)", function(c)
    if c == "%" then return "%" end
    ai = ai + 1
    local a = args[ai]
    if c == "v" then return nf.fmt_real(a, U.g_set.dec or 6)
    elseif c == "w" then return fmt_w(a, 7)
    elseif c == "d" then return nf.fmt_int(a)
    elseif c == "s" then return tostring(a) end
    ai = ai - 1
    return ""
  end))
end
local mfmt = M.mfmt

function M.memo_begin(title)
  W.view_clear()
  W.view_add(title, C_TITLE)
  W.view_add_sep()
end

function M.memo_sec(s)
  if W.view_n > 2 then W.view_add("", C_FG) end
  W.view_add(s, C_TITLE)
end

-- Punto de corte: despues de un operador o espacio, sin partir "E-6"
local function cut_at(s, max)
  for i = max, math.floor(max / 2) + 1, -1 do
    local c = s:sub(i, i)
    if c == " " or c == "+" or c == "*" or c == "/" or c == "(" or
        (c == "-" and i >= 2 and s:sub(i - 1, i - 1) ~= "E" and s:sub(i - 1, i - 1) ~= "(") then
      return i
    end
  end
  return max
end

-- Corta a 40 columnas (continuacion con 6 espacios de sangria)
function M.memo_line(s, color)
  local len = #s
  local first = true
  local pos = 1
  while len > 0 do
    local room = first and WID or WID - 6
    local take
    if len <= room then take = len else take = cut_at(s:sub(pos), room) end
    local piece = s:sub(pos, pos + take - 1)
    if not first then piece = "      " .. piece end
    W.view_add(piece, color)
    pos = pos + take
    len = len - take
    while s:sub(pos, pos) == " " and len > 0 do pos = pos + 1; len = len - 1 end
    first = false
  end
end
local memo_line = M.memo_line

function M.memo_data(label, v, unit) W.view_add_val(label, v, unit) end

-- lhs = formula / = sustitucion / = resultado unidad
function M.memo_eq(lhs, formula, subst, res, unit)
  local pad = #lhs + 1
  if pad > 12 then pad = 4 end
  local sp = string.rep(" ", pad)
  local num = nf.fmt_real(res, U.g_set.dec or 6)
  if formula then memo_line(lhs .. " = " .. formula, C_FG) end
  if subst and not formula then
    memo_line(lhs .. " = " .. subst, C_FG)
  elseif subst then
    memo_line(sp .. "= " .. subst, C_GRAY)
  end
  if not formula and not subst then
    memo_line(lhs .. " = " .. num .. " " .. (unit or ""), C_OK)
  else
    memo_line(sp .. "= " .. num .. " " .. (unit or ""), C_OK)
  end
end

function M.memo_res(label, v, unit)
  memo_line("> " .. label .. " = " .. nf.fmt_real(v, U.g_set.dec or 6) .. " " .. (unit or ""), C_OK)
end

-- Tabla de iteraciones: head = nombres de columna (1-based), ncol columnas,
-- lg = {n=, total=, r={ {c0..c4}, ... }} (filas y columnas 1-based, columna 1 =
-- numero de iteracion), mult[k] (1-based) multiplica cada columna.
function M.memo_table(head, ncol, lg, mult)
  local cw = math.floor((WID - 4) / (ncol - 1))
  local line = string.rep(" ", WID)
  local function put(p, s)   -- p 0-based
    line = line:sub(1, p) .. s .. line:sub(p + #s + 1)
  end
  for k = 0, ncol - 1 do
    local p = (k == 0) and 0 or 4 + (k - 1) * cw
    put(p, head[k + 1]:sub(1, cw - 1))
  end
  W.view_add(line, C_TITLE)
  for i = 1, lg.n do
    if lg.total > lg.n and i - 1 == math.floor(lg.n / 2) then W.view_add("...", C_GRAY) end
    line = string.rep(" ", WID)
    local row = lg.r[i]
    put(0, nf.fmt_int(math.floor(row[1])))
    for k = 1, ncol - 1 do
      local num = fmt_w(row[k + 1] * mult[k + 1], cw - 1)
      put(4 + (k - 1) * cw + (cw - 1 - #num), num)
    end
    W.view_add(line, C_FG)
  end
end

-- Advertencias del motor
function M.memo_warn(warn, c)
  local w = T.warn_texts(warn, c, U.g_set.dec or 6, 10)
  if #w == 0 then
    W.view_add(" Sin advertencias", C_OK)
    return
  end
  for i = 1, #w do W.view_add(w[i], U.C_WARN) end
end

return M
