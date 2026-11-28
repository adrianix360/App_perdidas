-- scr_tanks.lua - Problema de los tres tanques (2 a 4 tanques unidos en un nudo
-- comun, con o sin caudal Q_T que sale del nudo). Metodo del curso: se supone
-- la carga del nudo Z_J, se calcula Q en cada tramo (tipo B o Q = sqrt(H/M) si
-- f es dato), se hace el balance dQ y se corrige Z_J con dZ = 2 dQ / sum(Q/H).
-- API: TS.scr_tanks(), TS.tanks_example(idx 0..1), TS.ti (datos), TS.reset_cursors()
local U = require("ui.ui")
local W = require("ui.widgets")
local H = require("core.hydro")
local TK = require("core.tanks")
local M = require("ui.memo")

local TS = {}
local g_set = U.g_set
local NT = TK.TK_MAX
local FF_ANY, FF_POS, FF_NONNEG, FF_CHOICE, FF_INT, FF_OPT =
  W.FF_ANY, W.FF_POS, W.FF_NONNEG, W.FF_CHOICE, W.FF_INT, W.FF_OPT
local K_ENTER, K_CLEAR, K_QUIT, K_MODE = U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE
local K_F1, K_F2, K_F4, K_F5 = U.K_F1, U.K_F2, U.K_F4, U.K_F5
local C_FG, C_GRAY, C_TITLE, C_WARN, C_ERR, C_OK =
  U.C_FG, U.C_GRAY, U.C_TITLE, U.C_WARN, U.C_ERR, U.C_OK
local mfmt, memo_sec, memo_line, memo_eq, fmt_w =
  M.mfmt, M.memo_sec, M.memo_line, M.memo_eq, M.fmt_w

local function settings() require("scr.screens").scr_settings() end
local function b(x) return x ~= nil and x ~= 0 and x ~= false end
local abs_ = math.abs

local function new_tank()
  return { Z = 0, L = 0, D = 0, f = 0, ks = 0, K = 0,
           sZ = 0, sL = 0, sD = 0, sf = 0, sks = 0, sK = 1 }
end
local function new_ti()
  local ti = { n = 3, QT = 0, ZJ0 = 0, zn = 0, nu = 0,
               sn = 1, sQT = 0, sZJ0 = 0, szn = 0, snu = 0, p = {} }
  for i = 1, NT do ti.p[i] = new_tank() end
  return ti
end
local ti = new_ti()
TS.ti = ti

local TC = {}           -- configuracion usada en el calculo
local R = {}            -- resultado de TK.tanks_solve
local TT = {}           -- datos pasados al motor
local method_names = { "Colebrook-White", "Swamee-Jain", "Haaland", "Goudar-Sonnad" }

local fm_now
local last_n = 3
local function n_changed()
  if b(ti.sn) and ti.n ~= last_n and fm_now then
    last_n = ti.n
    fm_now.restart = 1
  end
end

local function build_form()
  local sub = { "Z tanque", "L", "D", "f dado(opc)", "ks (si no f)", "Suma K" }
  local unit = { "m", "m", "mm", false, "mm", false }
  local keys = { "Z", "L", "D", "f", "ks", "K" }
  local skeys = { "sZ", "sL", "sD", "sf", "sks", "sK" }
  local fl = { FF_ANY, FF_POS, FF_POS, FF_POS + FF_OPT, FF_NONNEG + FF_OPT, FF_NONNEG }
  local ff = {}
  local n = b(ti.sn) and ti.n or 3
  ff[#ff + 1] = { label = "Numero de tanques", t = ti, k = "n", setk = "sn", flags = FF_INT,
                  lo = 2, hi = NT }
  ff[#ff + 1] = { label = "Q_T sale del nudo", unit = "l/s", t = ti, k = "QT", setk = "sQT",
                  flags = FF_ANY + FF_OPT }
  ff[#ff + 1] = { label = "Z_J inicial (opc)", unit = "m", t = ti, k = "ZJ0", setk = "sZJ0",
                  flags = FF_ANY + FF_OPT }
  ff[#ff + 1] = { label = "Cota del nudo (opc)", unit = "m", t = ti, k = "zn", setk = "szn",
                  flags = FF_ANY + FF_OPT }
  ff[#ff + 1] = { label = "Viscosidad nu", unit = "m2/s", t = ti, k = "nu", setk = "snu",
                  flags = FF_POS }
  ff[#ff + 1] = { label = "Metodo de f", t = g_set.h, chk = "method", flags = FF_CHOICE,
                  choices = method_names, nchoices = 4 }
  for i = 1, n do
    local p = ti.p[i]
    for j = 1, 6 do
      ff[#ff + 1] = { label = i .. " " .. sub[j], unit = unit[j] or nil, t = p, k = keys[j],
                      setk = skeys[j], flags = fl[j] }
    end
  end
  return ff
end

-- ------------------------------------------------------------------
-- Calculo
-- ------------------------------------------------------------------
local function compute()
  local n = math.floor(ti.n)
  TC = {}
  for k, v in pairs(g_set.h) do TC[k] = v end
  TC.nu = ti.nu
  TT = { n = n, Z = {}, pipe = {}, QT = b(ti.sQT) and ti.QT / 1000 or 0,
         ZJ0 = b(ti.sZJ0) and ti.ZJ0 or nil }
  for i = 1, n do
    local p = ti.p[i]
    if not b(p.sZ) then return "Falta el nivel Z del tanque " .. i end
    if not b(p.sf) and not b(p.sks) then return "Tramo " .. i .. ": falta f o ks" end
    TT.Z[i] = p.Z
    TT.pipe[i] = H.new_pipe(p.D / 1000, p.L, b(p.sks) and p.ks / 1000 or 0, p.K,
      b(p.sf) and p.f or 0)
  end
  R = {}
  local e = TK.tanks_solve(TT, TC, R)
  if e ~= 0 then return H.hydro_err_text(e) end
  return nil
end

-- ------------------------------------------------------------------
-- Resumen y memoria
-- ------------------------------------------------------------------
local function dir_txt(i, Q)
  if Q > 0 then return "tanque " .. i .. " -> nudo" end
  if Q < 0 then return "nudo -> tanque " .. i end
  return "sin flujo"
end

local function f_of(i)
  local st = R.st[i]
  return st and st.f or 0
end

local function result_lines()
  for i = 1, TT.n do
    local Q = R.Q[i]
    local st = R.st[i]
    W.view_add(mfmt(" Q%d = %s l/s  %s", i, fmt_w(1000 * Q, 8), dir_txt(i, Q)), C_FG)
    if st then
      W.view_add(mfmt("   H %s m  v %s m/s  f %s", fmt_w(R.h[i], 7), fmt_w(st.v, 6),
        fmt_w(st.f, 7)), C_GRAY)
    end
  end
end

local function summary()
  W.view_clear()
  W.view_add("RESULTADO  Tres tanques", C_TITLE)
  W.view_add_sep()
  W.view_add_val("Z_J nudo", R.ZJ, "m")
  if b(ti.szn) then W.view_add_val("p/gamma nudo", R.ZJ - ti.zn, "m") end
  W.view_add_val("Q_T sale nudo", 1000 * TT.QT, "l/s")
  W.view_add_val("Iteraciones", R.it, nil)
  W.view_add_sep()
  result_lines()
  W.view_add_sep()
  W.view_add(mfmt(" Balance: sum Q - Q_T = %s l/s", fmt_w(1000 * R.dQ, 8)), C_GRAY)
  W.view_add(" Q > 0 entra al nudo; Q < 0 sale", C_GRAY)
end

-- Detalle de una iteracion como en la solucion a mano
local function memo_iter(k)
  local w = R.rows[k]
  local n = TT.n
  memo_sec(mfmt("ITERACION %d:  Z_J = %w m", k, w.ZJ))
  for i = 1, n do
    memo_line(mfmt("H%d = %w - %w = %w m", i, TT.Z[i], w.ZJ, w.h[i]), C_FG)
    local lhs = (TT.pipe[i].f_fixed > 0 and w.Q[i] ~= 0) and " Q%d = sqrt(|H|/M) = " or " Q%d = "
    memo_line(mfmt(lhs .. "%w l/s  %s", i, 1000 * w.Q[i], dir_txt(i, w.Q[i])), C_OK)
  end
  local s = fmt_w(1000 * w.Q[1], 7)
  for i = 2, n do
    local q = 1000 * w.Q[i]
    s = s .. (q < 0 and " - " or " + ") .. fmt_w(abs_(q), 7)
  end
  if TT.QT ~= 0 then
    s = s .. (TT.QT < 0 and " + " or " - ") .. fmt_w(abs_(1000 * TT.QT), 7)
  end
  memo_line("dQ = sum Q - Q_T", C_FG)
  memo_line("   = " .. s, C_GRAY)
  memo_line(mfmt("   = %w l/s", 1000 * w.dQ), C_OK)
  local qh = {}
  for i = 1, n do
    if w.h[i] ~= 0 then
      qh[#qh + 1] = fmt_w(1000 * abs_(w.Q[i]), 7) .. "/" .. fmt_w(abs_(w.h[i]), 7)
    end
  end
  if w.bis then
    memo_line(" Newton sale del intervalo: se usa", C_WARN)
    memo_line(" el punto medio (biseccion)", C_WARN)
    memo_eq("dZ", nil, nil, w.dZ, "m")
  else
    memo_eq("dZ", "2 dQ / sum(|Q|/|H|)",
      mfmt("2(%s)/(%s)", fmt_w(1000 * w.dQ, 8), table.concat(qh, " + ")), w.dZ, "m")
  end
  if k < R.it then
    memo_line(mfmt("Z_J = %w %s %w = %w m", w.ZJ, w.dZ < 0 and "-" or "+", abs_(w.dZ),
      w.ZJ + w.dZ), C_OK)
  else
    memo_line(" |dZ| <= tolerancia: converge", C_OK)
  end
end

local function memo()
  local n = TT.n
  W.view_clear()
  W.view_add("MEMORIA  Tres tanques", C_TITLE)
  W.view_add_sep()
  memo_sec("DATOS")
  for i = 1, n do
    local p = ti.p[i]
    memo_line(mfmt(" %d: Z = %v m, L = %v m, D = %v m", i, p.Z, p.L, p.D / 1000), C_FG)
    if b(p.sf) then
      memo_line(mfmt("    f = %v (dato), SumK = %v", p.f, p.K), C_GRAY)
      local pp = TT.pipe[i]
      local Mi = H.hydro_module_coef(TC) * (pp.f_fixed * pp.L / pp.D + pp.sumK) /
        (pp.D * pp.D * pp.D * pp.D)
      memo_line(mfmt("    M = 8/(pi^2 g D^4)(fL/D+SumK) = %s", fmt_w(Mi, 9)), C_GRAY)
    else
      memo_line(mfmt("    ks = %v m, SumK = %v", p.ks / 1000, p.K), C_GRAY)
    end
  end
  memo_line(mfmt(" Q_T (sale del nudo) = %v l/s", 1000 * TT.QT), C_FG)
  memo_line(mfmt(" nu = %v m2/s; f: %s", TC.nu, method_names[(TC.method or 0) + 1]), C_GRAY)
  memo_sec("METODO")
  memo_line(" Se supone Z_J (carga del nudo). En cada tramo H = Z_tanque - Z_J y con |H| se "
    .. "halla Q como en el tipo B (si f es dato, Q = sqrt(|H|/M)). Signo de Q = signo "
    .. "de H: Q > 0 va del tanque al nudo.", C_GRAY)
  memo_line(" dQ = sum Q - Q_T;  dZ = 2 dQ / sum(|Q|/|H|);  Z_J = Z_J + dZ", C_FG)
  if not b(ti.sZJ0) then
    memo_line(mfmt(" Z_J inicial = promedio de los Z = %v m", R.rows[1].ZJ), C_GRAY)
  end
  -- primeras tres iteraciones en detalle, luego tabla y la ultima
  local nd = math.min(3, R.it)
  for k = 1, nd do memo_iter(k) end
  if R.it > nd then
    memo_sec("TABLA DE ITERACIONES")
    W.view_add("it    Z_J m     dQ l/s     dZ m", C_TITLE)
    for k = 1, R.it do
      local w = R.rows[k]
      local line = string.format("%2d %9s %10s %9s%s", k, fmt_w(w.ZJ, 9), fmt_w(1000 * w.dQ, 10),
        fmt_w(w.dZ, 9), w.bis and " b" or "")
      W.view_add(line, C_FG)
    end
    memo_iter(R.it)
  end
  memo_sec("RESULTADOS")
  W.view_add(mfmt(" Z_J = %v m", R.ZJ), C_OK)
  if b(ti.szn) then
    memo_eq("p/gamma", "Z_J - cota", mfmt("%v - %v", R.ZJ, ti.zn), R.ZJ - ti.zn, "m")
  end
  result_lines()
  memo_sec("COMPROBACION")
  memo_line(mfmt(" sum Q - Q_T = %s l/s", fmt_w(1000 * R.dQ, 9)), C_GRAY)
  for i = 1, n do
    local st = R.st[i]
    if st then
      memo_line(mfmt(" %d: (fL/D+SumK) v^2/2g = %s m", i, fmt_w(st.hT, 8)), C_GRAY)
    end
  end
end

-- Ejemplos: 0 = tarea (Colebrook, Q_T = 60 l/s), 1 = pizarra (f dado)
-- {Z, L, D mm, f, ks mm, K} por tanque
local exs = {
  [0] = { n = 3, QT = 60, ZJ0 = 110, zn = 110,
          p = { { 120, 200, 250, 0, 0.0015, 4 }, { 140, 300, 200, 0, 0.0015, 4 },
                { 100, 100, 100, 0, 0.0015, 4 } } },
  { n = 3, QT = 0, zn = 40,
    p = { { 100, 400, 200, 0.012, 0, 3.5 }, { 50, 350, 180, 0.011, 0, 3.0 },
          { 20, 480, 150, 0.011, 0, 2.5 } } },
}
TS.EXAMPLES = 2
local ex_next = 0

local tanks_run

function TS.tanks_load_example(idx)
  local e = exs[idx]
  if not e then return end
  for i = 1, NT do ti.p[i] = new_tank() end
  ti.n, ti.sn = e.n, 1
  ti.QT, ti.sQT = e.QT, 1
  ti.ZJ0, ti.sZJ0 = e.ZJ0 or 0, e.ZJ0 and 1 or 0
  ti.zn, ti.szn = e.zn or 0, e.zn and 1 or 0
  ti.nu, ti.snu = 1e-6, 1
  for i = 1, e.n do
    local p, v = ti.p[i], e.p[i]
    p.Z, p.L, p.D, p.f, p.ks, p.K = v[1], v[2], v[3], v[4], v[5], v[6]
    p.sZ, p.sL, p.sD, p.sK = 1, 1, 1, 1
    p.sf = v[4] > 0 and 1 or 0
    p.sks = v[4] > 0 and 0 or 1
  end
  last_n = ti.n
end

function TS.tanks_example(idx)
  TS.tanks_load_example(idx)
  tanks_run(true)
end

function TS.scr_tanks() tanks_run(false) end

local cur = 0
function TS.reset_cursors() cur = 0; ex_next = 0 end

local function results()
  local m = false
  local fk_sum = { "MEMORIA", "", "", "", "VOLVER" }
  local fk_memo = { "RESUMEN", "", "", "", "VOLVER" }
  while true do
    if m then memo() else summary() end
    local kk = W.view_run("TRES TANQUES", m and fk_memo or fk_sum)
    if kk == K_F1 then m = not m
    elseif kk == K_MODE then settings()
    else return end
    if U.quit then return end
  end
end

tanks_run = function(autocalc)
  if not b(ti.snu) then ti.nu = g_set.h.nu; ti.snu = 1 end
  last_n = b(ti.sn) and ti.n or 3
  local fm = { title = "TRES TANQUES (NUDO)",
               fk = { "CALC f", "EJEMPLO", "", "AJUSTES", "CALC" },
               hint = "Q>0 del tanque al nudo; Q_T sale" }
  while true do
    local ff = build_form()
    fm.f = ff
    fm.n = #ff
    fm.cur = cur < #ff and cur or 0
    fm.on_commit = n_changed
    fm_now = fm
    local k
    if autocalc then
      autocalc = false
      k = K_F5
    else
      k = W.form_run(fm)
    end
    fm_now = nil
    cur = fm.cur
    if k == K_QUIT or k == K_CLEAR then return end
    if k == K_F4 or k == K_MODE then
      settings()
    elseif k == K_F2 then
      TS.tanks_load_example(ex_next)
      fm.msg = ex_next == 0 and "Ejemplo: tarea (ks, Q_T = 60 l/s)"
        or "Ejemplo: pizarra (f dado, Q_T = 0)"
      fm.msg_color = C_OK
      ex_next = (ex_next + 1) % TS.EXAMPLES
    elseif k == K_F1 then
      local f = ff[cur + 1]
      local isf = false
      for i = 1, NT do if f and f.t == ti.p[i] and f.k == "f" then isf = true end end
      if isf then
        require("scr.scr_fric").scr_fric(f.t, "f", "sf")
      else
        fm.msg = "Ubique el cursor en un campo f dado"
        fm.msg_color = C_WARN
      end
      if U.quit then return end
    elseif k == K_F5 or k == K_ENTER then
      if W.form_check(fm) then
        local err = compute()
        if err then
          fm.msg = err
          fm.msg_color = C_ERR
        else
          results()
          if U.quit then return end
        end
      end
    end
  end
end

return TS
