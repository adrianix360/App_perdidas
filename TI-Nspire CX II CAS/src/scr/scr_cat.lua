-- scr_cat.lua - Catalogo de coeficientes de arrastre (port de scr_cat.c).
-- Lista con miniaturas, detalle con la ilustracion grande, comparar hasta 3
-- figuras, ranking por C_D, valor propio (EDITAR) y C_D por parametro (L/D, b/h,
-- angulo). Se adapta al cuerpo de 318x156 px de la Nspire: la lista muestra
-- ui_rows()/2 figuras por pagina (6), el ranking se desplaza y el detalle pone
-- la ilustracion (escala 1) a la izquierda, los datos al centro y la tabla a la
-- derecha. PGUP/PGDN (tab/backtab) cambian de pagina.
--
-- API: M.scr_cat(use) -> indice de figura 0..16 (USAR) o -1; el C_D elegido queda
-- en M.cat_sel_cd y el parametro de la tabla en M.cat_sel_param (0: no hubo).
local U = require("ui.ui")
local W = require("ui.widgets")
local M = require("ui.memo")
local G = require("ui.gfxcat")
local dc = require("data.dragcat")
local Dr = require("core.drag")
local H = require("core.hydro")
local F = require("scr.flu_util")

local S = {}
S.cat_sel_cd = 0
S.cat_sel_param = 0

local CAT_N = dc.CAT_N
local K_NONE, K_UP, K_DOWN, K_LEFT, K_RIGHT, K_ENTER, K_CLEAR, K_F1, K_F2, K_F3, K_F4,
  K_F5, K_MODE, K_QUIT, K_ALPHA, K_PGUP, K_PGDN, K_CLICK = U.K_NONE, U.K_UP, U.K_DOWN,
  U.K_LEFT, U.K_RIGHT, U.K_ENTER, U.K_CLEAR, U.K_F1, U.K_F2, U.K_F3, U.K_F4, U.K_F5,
  U.K_MODE, U.K_QUIT, U.K_ALPHA, U.K_PGUP, U.K_PGDN, U.K_CLICK
local C_BG, C_FG, C_TITLE, C_SEL, C_WARN, C_GRAY, C_OK, C_LE, C_ERR =
  U.C_BG, U.C_FG, U.C_TITLE, U.C_SEL, U.C_WARN, U.C_GRAY, U.C_OK, U.C_LE, U.C_ERR
local mfmt, fmt_w = M.mfmt, M.fmt_w
local floor = math.floor

local mk, nmk = {}, 0       -- figuras marcadas para comparar (codigos 0..16)
local gfx_ok = false
local msg = nil
local cur = 0               -- figura del cursor (0..16)
local p_last = 10           -- ultimo parametro de tabla

local function shape(i) return dc.drag_shapes[i + 1] end
local function cd_of(i) return dc.dragcat_cd(i) end
local function rowh() return floor(U.ui_body_h() / U.ui_rows()) end

local function marked(i)
  for k = 1, nmk do if mk[k] == i then return true end end
  return false
end

local function toggle_mark(i)
  for k = 1, nmk do
    if mk[k] == i then
      table.remove(mk, k)
      nmk = nmk - 1
      return
    end
  end
  if nmk >= 3 then
    msg = "Maximo 3 figuras para comparar"
  else
    nmk = nmk + 1
    mk[nmk] = i
  end
end

-- Pie comun: mensaje pendiente o aviso de PERDGFX, teclas y espera
local function finish(fk, hint)
  if msg then U.ui_msg(msg, C_WARN)
  elseif not gfx_ok then U.ui_msg("Falta PERDGFX: sin ilustraciones", C_WARN)
  elseif hint then U.ui_msg(hint, C_GRAY) end
  msg = nil
  U.ui_fbar(fk)
  U.ui_end()
  local k = U.ui_getkey()
  if k.k == K_MODE then F.scr_settings() end
  return k
end

local function again(kk) return kk == K_MODE or kk == K_NONE or kk == K_ALPHA or kk == K_CLICK end

-- ------------------------------------------------------------------ comparar
local function compare()
  local fk = { "LIMPIAR", "", "", "", "VOLVER" }
  while true do
    if U.quit then return end
    local rh = rowh()
    U.ui_begin("COMPARAR FIGURAS", nil)
    local mx, cd = 0, {}
    for k = 1, nmk do
      cd[k] = cd_of(mk[k])
      if cd[k] > mx then mx = cd[k] end
    end
    for k = 1, nmk do
      local x = 4 + (k - 1) * 106
      local col = (k - 1) * 13 + 1
      G.gfxcat_draw(mk[k], true, x, 1, 1)
      U.ui_text_n(8, col, shape(mk[k]).name, 12, C_FG, C_BG)
      U.ui_text(9, col, mfmt("CD %w", cd[k]), C_TITLE, C_BG)
      G.gfxcat_rect(x, 9 * rh + 3, floor(96 * cd[k] / mx), 8, C_LE)
      if k > 1 then
        U.ui_text(9 + k, 0, mfmt("Fig %d / fig 1: %w veces el arrastre", k, cd[k] / cd[1]),
          C_FG, C_BG)
      end
    end
    local key = finish(fk, "(igual A, V y rho: F prop. a CD)")
    if key.k == K_F1 then nmk = 0; mk = {} end
    if not again(key.k) then return end
  end
end

-- ------------------------------------------------------------------- ranking
local function ranking()
  local fk = { "", "", "", "", "VOLVER" }
  local ord = {}
  for i = 1, CAT_N do ord[i] = i - 1 end
  for i = 2, CAT_N do                  -- insercion estable: 17 elementos
    local j = i
    while j > 1 and cd_of(ord[j]) < cd_of(ord[j - 1]) do
      ord[j], ord[j - 1] = ord[j - 1], ord[j]
      j = j - 1
    end
  end
  local top = 0
  while true do
    if U.quit then return end
    local vis = U.ui_rows()
    local rh = rowh()
    local last = math.min(top + vis, CAT_N)
    U.ui_begin("RANKING DE CD (menor a mayor)", (top + 1) .. "-" .. last .. "/" .. CAT_N)
    for i = 0, vis - 1 do
      local n = top + i + 1
      if n > CAT_N then break end
      local f = ord[n]
      local cd = cd_of(f)
      G.gfxcat_rect(264, i * rh + 3, floor(52 * cd / 2.2) + 1, 7, C_LE)
      U.ui_text(i + 1, 0, (f + 1) .. " " .. shape(f).name, C_FG, C_BG)
      U.ui_text_r(i + 1, 32, fmt_w(cd, 4), C_TITLE, C_BG)
    end
    local key = finish(fk, CAT_N > vis and "Flechas o PGUP/PGDN: desplazar" or nil)
    local kk = key.k
    if kk == K_UP then if top > 0 then top = top - 1 end
    elseif kk == K_DOWN then if top + vis < CAT_N then top = top + 1 end
    elseif kk == K_PGUP or kk == K_LEFT then top = (top > vis) and top - vis or 0
    elseif kk == K_PGDN or kk == K_RIGHT then
      top = math.min(top + vis, math.max(0, CAT_N - vis))
    elseif not again(kk) then return end
  end
end

-- ------------------------------------------------------- un campo (EDITAR/TABLA)
-- Formulario de un solo campo. Devuelve 2 si se pulso F1, 1 si se acepto con
-- valor, 0 si no; y el valor.
local function one_field(title, lab, val, flags, hint, f1)
  local box = { v = val, s = 1 }
  local fm = {
    title = title,
    f = { { label = lab, t = box, k = "v", setk = "s", flags = flags, lo = 0.001, hi = 10 } },
    n = 1, cur = 0, top = 0,
    fk = { f1 or "", "", "", "", "LISTO" },
    hint = hint,
  }
  local k = W.form_run(fm)
  if k == K_F1 then return 2, box.v end
  if (k == K_F5 or k == K_ENTER) and box.s ~= 0 then return 1, box.v end
  return 0, box.v
end

local function edit_cd(i)
  local v = cd_of(i)
  local r, nv = one_field("EDITAR CD", "CD propio", v, W.FF_RANGE, shape(i).name, "DEFECTO")
  if r == 2 then v = 0           -- F1: vuelve el del catalogo
  elseif r == 0 then return
  else v = nv end
  F.sync_cd_user()
  dc.cd_user[i] = (v == shape(i).cd) and 0 or v
  U.mark_changed()
end

-- Pide el parametro de la tabla y deja el C_D en cat_sel_cd
local function ask_param(i)
  local t = dc.dragcat_table(shape(i).tab)
  if not t then return false end
  local r, p = one_field("CD POR TABLA", t.param, p_last, W.FF_POS,
    t.inf > 0 and "1000 o mas = infinito" or shape(i).name, nil)
  if r ~= 1 then return false end
  p_last = p
  local cd, x0, y0, x1, y1, w = dc.dragcat_param(i, p, 0)
  S.cat_sel_cd = cd
  S.cat_sel_param = p
  local isclamp = H.warn_has(w, Dr.DW_CLAMP)
  local isinterp = H.warn_has(w, Dr.DW_INTERP)
  local l1 = mfmt("CD = %w %s", cd, isclamp and "(fuera: extremo)" or isinterp and "(interpolado)" or "")
  local l2 = mfmt("%s %w: %w   %w: %w", t.param, x0 or 0, y0 or 0, x1 or 0, y1 or 0)
  U.ui_alert("CD POR TABLA", l1, l2, isclamp and C_WARN or C_OK)
  return true
end

-- ------------------------------------------------------------------- detalle
-- Devuelve true si se uso la figura (USAR)
local function detail(use)
  while true do
    if U.quit then return false end
    local i = cur
    local d = shape(i)
    local t = dc.dragcat_table(d.tab)
    local rh = rowh()
    local fk = { use and "USAR" or "", "COMPAR.", "EDITAR", t and "TABLA" or "", "VOLVER" }
    U.ui_begin(d.name, nil)
    G.gfxcat_draw(i, true, 2, 1, 1)
    local R = 1
    local X = 13                                   -- columna de los datos
    local function L(s, c, col) U.ui_text(R, col or X, s, c, C_BG); R = R + 1 end
    L(mfmt("CD = %w", cd_of(i)), C_TITLE)
    if F.gset().cd_user and F.gset().cd_user[i] and F.gset().cd_user[i] > 0 then
      L(mfmt("(catal. %w)", d.cd), C_WARN)
    end
    U.ui_text(R, X, "Area:", C_GRAY, C_BG); U.ui_text(R, X + 8, dc.area_txt[d.area + 1], C_FG, C_BG)
    R = R + 1
    U.ui_text(R, X, "Validez:", C_GRAY, C_BG); U.ui_text(R, X + 8, "Re > 1E4", C_FG, C_BG)
    R = R + 1
    if d.stokes > 0 then L(mfmt("Re<1: %w/Re", d.stokes), C_FG) end
    U.ui_text(R, X, "Fuente:", C_GRAY, C_BG); U.ui_text(R, X + 8, d.src, C_FG, C_BG)
    R = R + 1
    if t then                                       -- tabla en la columna derecha
      local T = 1
      U.ui_text(T, 29, t.param, C_GRAY, C_BG); U.ui_text(T, 35, "CD", C_GRAY, C_BG); T = T + 1
      for k = 1, t.n do
        U.ui_text(T, 29, mfmt("%w", t.x[k]), C_FG, C_BG)
        U.ui_text(T, 35, mfmt("%w", t.y[k]), C_FG, C_BG)
        T = T + 1
      end
      if t.inf > 0 then
        U.ui_text(T, 29, "inf", C_FG, C_BG)
        U.ui_text(T, 35, mfmt("%w", t.inf), C_FG, C_BG)
      end
    end
    if marked(i) then U.ui_text(8, 0, "* marcada para comparar", C_OK, C_BG) end
    U.ui_text(10, 0, d.orient, C_GRAY, C_BG)
    local r = 11
    for line in (d.note .. "|"):gmatch("([^|]*)|") do      -- '|' separa lineas
      if line ~= "" and r <= 12 then
        U.ui_text_n(r, 0, line, U.UI_COLS, C_FG, C_BG)
        r = r + 1
      end
    end
    local key = finish(fk, nil)
    local kk = key.k
    if kk == K_F1 then
      if use then
        S.cat_sel_cd = cd_of(i)
        S.cat_sel_param = 0
        if not t or ask_param(i) then return true end
      end
    elseif kk == K_F2 then
      if not marked(i) then toggle_mark(i) end
      if nmk >= 2 then compare()
      elseif not msg then msg = "Marcada; elija otra figura (F2)" end
    elseif kk == K_F3 then edit_cd(i)
    elseif kk == K_F4 then if t then ask_param(i) end
    elseif kk == K_UP or kk == K_PGUP then if i > 0 then cur = i - 1 end
    elseif kk == K_DOWN or kk == K_PGDN then if i + 1 < CAT_N then cur = i + 1 end
    elseif kk == K_QUIT or kk == K_CLEAR or kk == K_F5 then return false end
  end
end

-- --------------------------------------------------------------------- lista
function S.scr_cat(use)
  gfx_ok = G.gfxcat_open()
  F.sync_cd_user()
  while true do
    if U.quit then return -1 end
    local PAGE = math.max(1, floor(U.ui_rows() / 2))
    local rh = rowh()
    local top = floor(cur / PAGE) * PAGE
    U.ui_begin(use and "ELIJA LA FIGURA (CD)" or "COEFICIENTES DE ARRASTRE",
      (cur + 1) .. "/" .. CAT_N)
    local cdu = F.gset().cd_user or {}
    for k = 0, PAGE - 1 do
      local i = top + k
      if i >= CAT_N then break end
      local r = 1 + 2 * k
      local bg = (i == cur) and C_SEL or C_BG
      if i == cur then
        U.ui_row_fill(r, C_SEL)
        U.ui_row_fill(r + 1, C_SEL)
      end
      G.gfxcat_draw(i, false, 2, (r - 1) * rh + floor((2 * rh - G.GFX_TH) / 2), 1)
      U.ui_text(r, 5, (marked(i) and "*" or " ") .. (i + 1) .. " " .. shape(i).name, C_FG, bg)
      U.ui_text_n(r + 1, 5, shape(i).orient, 30, C_GRAY, bg)
      U.ui_text_r(r, 39, fmt_w(cd_of(i), 4), (cdu[i] and cdu[i] > 0) and C_WARN or C_TITLE, bg)
    end
    local key = finish({ "", "MARCAR", "COMPAR.", "RANKING", "VOLVER" },
      "ENTER: detalle con ilustracion 3D")
    local kk = key.k
    if kk == K_UP then cur = cur > 0 and cur - 1 or CAT_N - 1
    elseif kk == K_DOWN then cur = (cur + 1) % CAT_N
    elseif kk == K_PGUP then cur = cur >= PAGE and cur - PAGE or 0
    elseif kk == K_PGDN then cur = (cur + PAGE < CAT_N) and cur + PAGE or CAT_N - 1
    elseif kk == K_ENTER then
      if detail(use) then return cur end
    elseif kk == K_CLICK then
      local i = top + floor((key.row - 1) / 2)
      if i >= 0 and i < CAT_N then
        if i == cur then
          if detail(use) then return cur end
        else cur = i end
      end
    elseif kk == K_F2 then toggle_mark(cur)
    elseif kk == K_F3 then
      if nmk >= 2 then compare() else msg = "Marque 2 o 3 figuras con F2" end
    elseif kk == K_F4 then ranking()
    elseif kk == K_QUIT or kk == K_CLEAR or kk == K_F5 then return -1 end
    if U.quit then return -1 end
  end
end

return S
