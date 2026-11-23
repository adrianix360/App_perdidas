-- memo_run.lua - Interprete de los programas de PERDTXT (memoria de calculo,
-- resumenes y ayuda) y constantes de memo_defs.h (port de memo_run.c).
--
-- Cada pantalla llena MR.V[V_*] (0-based: MR.V[MR.V_Q] = x), marca banderas con
-- MR.msetf(MR.G_*, cond), apunta MR.cfg a la configuracion (tabla hydro_cfg,
-- campo .method = 0..3) y, si hay tabla de iteraciones, MR.log; luego llama
-- MR.memo_show(prog). Todas las constantes (V_*, G_*, M_*, S_*, XP_*, TB_*, PT_*,
-- KT_*, TX_*, HELP_COUNT, ...) estan como campos de este modulo, mas
-- PROG_SUM(t), PROG_MEMO(t), PROG_HELP(i), PROG_X(i) y PROG_COUNT.
--
-- Estructuras (convenciones Lua):
--   MR.log / MR.lg: {n=filas, total=iteraciones, r={ {c1..c5}, ... }}, filas y
--     columnas 1-based; la columna 1 es el numero de iteracion.
--   MR.dlist: lista 1-based de diametros (m); MR.dlist_n su largo.
--   MR.method_names: nombres de metodo (1-based, indice = cfg.method + 1).
--   MR.listname(): texto de {LISTNAME} (nombre del juego de diametros).
--   MR.hook(): llamada por M_TABLE TB_HOOK. MR.txt: texto de {TXT}.
local U = require("ui.ui")
local W = require("ui.widgets")
local nf = require("ui.numfmt")
local M = require("ui.memo")

local MR = {}
local defs = require("gen.memo_defs")
for k, v in pairs(defs) do MR[k] = v end
local D = MR

local S_COUNT, PT_COUNT, HELP_COUNT, XP_COUNT = D.S_COUNT, D.PT_COUNT, D.HELP_COUNT, D.XP_COUNT
function MR.PROG_SUM(t) return S_COUNT + t end
function MR.PROG_MEMO(t) return S_COUNT + PT_COUNT + t end
function MR.PROG_HELP(i) return S_COUNT + 2 * PT_COUNT + i end
function MR.PROG_X(i) return S_COUNT + 2 * PT_COUNT + HELP_COUNT + i end
MR.PROG_COUNT = S_COUNT + 2 * PT_COUNT + HELP_COUNT + XP_COUNT
local PROG_COUNT = MR.PROG_COUNT

MR.V = {}
MR.FL = {}                -- banderas G_* activas: FL[g] = true
MR.W = 0                  -- mascara de advertencias de M_WARN
MR.cfg = nil
MR.log = nil
MR.lg = { n = 0, total = 0, r = {} }
MR.dlist, MR.dlist_n = nil, 0
MR.hook = nil
MR.txt = nil
MR.method_names = { "Colebrook-White", "Swamee-Jain", "Haaland", "Goudar-Sonnad" }
MR.listname = function() return "?" end

function MR.msetf(g, cond) if cond then MR.FL[g] = true end end

-- Limpia V, FL y W
function MR.memo_reset()
  MR.V = {}
  MR.FL = {}
  MR.W = 0
end

local TX, TXN
local byte, find, sub = string.byte, string.find, string.sub

-- Abre PERDTXT; false si falta o es de otra version
function MR.memo_tx_open()
  TX = nil
  local ok, d = pcall(require, "gen.perdtxt")
  if not ok or type(d) ~= "string" then return false end
  TXN = #d
  if TXN < 5 + 2 * PROG_COUNT or sub(d, 1, 3) ~= "PTX" or byte(d, 4) ~= D.TX_VERSION or
      byte(d, 5) ~= PROG_COUNT then
    return false
  end
  TX = d
  return true
end

local function rd16(p) return byte(TX, p + 1) + byte(TX, p + 2) * 256 end

-- texto en el desplazamiento o (0-based), o nil
local scache = {}
local function txs(o)
  if o == D.TX_NONE or o >= TXN then return nil end
  local s = scache[o]
  if s then return s end
  local z = find(TX, "\0", o + 1, true) or (TXN + 1)
  s = sub(TX, o + 1, z - 1)
  scache[o] = s
  return s
end

-- Expande los codigos de valor de una plantilla
local function tpl(t)
  if not t then return nil end
  if not find(t, "[\1\2]") then return t end
  local out = {}
  local i, n = 1, #t
  local dec = U.g_set.dec or 6
  while i <= n do
    local code = byte(t, i)
    if code ~= D.TX_FULL and code ~= D.TX_SHORT then
      local j = find(t, "[\1\2]", i) or (n + 1)
      out[#out + 1] = sub(t, i, j - 1)
      i = j
    else
      if i + 1 > n then break end
      local id = byte(t, i + 1) - 1          -- el generador guarda id + 1
      i = i + 2
      local s
      if id == D.V_METHOD then
        local c = MR.cfg
        local m = (c and c.method and c.method < 4) and c.method or 0
        s = MR.method_names[m + 1]
      elseif id == D.V_TXT then
        s = MR.txt or ""
      elseif id == D.V_LISTNAME then
        s = MR.listname()
      elseif id < D.V_COUNT then
        local v = MR.V[id] or 0
        if code == D.TX_SHORT then s = M.fmt_w(v, 7) else s = nf.fmt_real(v, dec) end
      else
        s = "?"
      end
      out[#out + 1] = s
    end
  end
  return table.concat(out)
end

local hB_course = { "i", "hf", "v", "hm", "hf+1" }
local hB_bis = { "i", "v min", "v max", "v", "hT-H" }
local hD = { "i", "D min", "D max", "D mm", "hT-H" }
local hCW = { "i", "f_i" }
local m_one = { 1, 1, 1, 1, 1 }
local m_D = { 1, 1000, 1000, 1000, 1 }
local hB_sec = { "i", "hf", "v", "hm", "G" }
local hD_sec = { "i", "D mm", "v", "hT", "hT-H" }
local m_Ds = { 1, 1000, 1, 1, 1 }
local hW_bis = { "i", "h min", "h max", "h", "Q(h)-Q" }

local function run_prog(prog, depth)
  if not TX or prog >= PROG_COUNT then return end
  local o = rd16(5 + 2 * prog)
  local skip = 0
  local V = MR.V
  while o + D.TX_STEP <= TXN do
    local op, id = byte(TX, o + 1), byte(TX, o + 2)
    local a, b, c, u = rd16(o + 2), rd16(o + 4), rd16(o + 6), rd16(o + 8)
    o = o + D.TX_STEP
    if op == D.M_END then break end
    if skip > 0 then                       -- dentro de un IF falso
      if op == D.M_IF or op == D.M_IFN then skip = skip + 1
      elseif op == D.M_ENDIF then skip = skip - 1 end
    else
      if op == D.M_SEC then M.memo_sec(txs(a) or "")
      elseif op == D.M_SEP then W.view_add_sep()
      elseif op == D.M_DATA then W.view_add_val(txs(a) or "", V[id] or 0, txs(u))
      elseif op == D.M_RES then M.memo_res(txs(a) or "", V[id] or 0, txs(u))
      elseif op == D.M_EQ then
        M.memo_eq(txs(a) or "", txs(b), tpl(txs(c)), V[id] or 0, txs(u))
      elseif op == D.M_LINE then M.memo_line(tpl(txs(a)) or "", id)
      elseif op == D.M_IF then
        if not MR.FL[id] then skip = 1 end
      elseif op == D.M_IFN then
        if MR.FL[id] then skip = 1 end
      elseif op == D.M_CALL then
        if depth < 3 then run_prog(id, depth + 1) end
      elseif op == D.M_TABLE then
        if id == D.TB_HOOK then
          if MR.hook then MR.hook() end
        elseif MR.log then
          local lg = MR.log
          if id == D.TB_B_COURSE then M.memo_table(hB_course, 5, lg, m_one)
          elseif id == D.TB_B_BIS then M.memo_table(hB_bis, 5, lg, m_one)
          elseif id == D.TB_D then M.memo_table(hD, 5, lg, m_D)
          elseif id == D.TB_B_SEC then M.memo_table(hB_sec, 5, lg, m_one)
          elseif id == D.TB_D_SEC then M.memo_table(hD_sec, 5, lg, m_Ds)
          elseif id == D.TB_W_BIS then M.memo_table(hW_bis, 5, lg, m_one)
          else M.memo_table(hCW, 2, lg, m_one) end
        end
      elseif op == D.M_WARN then
        if MR.cfg then M.memo_warn(MR.W, MR.cfg) end
      elseif op == D.M_DLIST then
        local tb = " "
        for i = 1, MR.dlist_n do
          if #tb > 30 then
            M.memo_line(tb, U.C_GRAY)
            tb = " "
          end
          tb = tb .. M.fmt_w(MR.dlist[i] * 1000, 7) .. " "
        end
        M.memo_line(tb, U.C_GRAY)
      end
    end
  end
end

-- Ejecuta el programa prog en el visor (sin view_clear)
function MR.memo_run_prog(prog)
  if not TX then MR.memo_tx_open() end
  run_prog(prog, 0)
end

-- view_clear + programa; si falta PERDTXT, deja un aviso en el visor
function MR.memo_show(prog)
  W.view_clear()
  if not MR.memo_tx_open() then
    W.view_add("Falta el modulo de textos PERDTXT", U.C_ERR)
    W.view_add("(src/gen/perdtxt.lua) o es de otra", U.C_ERR)
    W.view_add("version. Regenere con", U.C_ERR)
    W.view_add("tools/gen_assets.py y reconstruya.", U.C_ERR)
    return
  end
  run_prog(prog, 0)
end

-- Ayuda: dibuja el tema i (programa de PERDTXT) en el visor
function MR.help_topic(i)
  W.view_clear()
  if not MR.memo_tx_open() then return false end
  MR.memo_run_prog(MR.PROG_HELP(i))
  return true
end

return MR
