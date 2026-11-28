-- scr_net.lua - Sistemas en serie y paralelo (tipo G) con el metodo de los modulos
-- de caudal, hacia adelante (H dada) o hacia atras (Q conocido en un tubo), y
-- grafica de LE y LP (tipo H). Port de scr_net.c.
--
-- Hasta 8 tubos; cada uno con su numero de tramo. Los tubos del mismo tramo van
-- en paralelo y los tramos en serie, en orden creciente.
-- API: N.scr_net(), N.scr_net_example(idx 0..4), N.ni (datos del formulario)
local U = require("ui.ui")
local W = require("ui.widgets")
local nf = require("ui.numfmt")
local H = require("core.hydro")
local M = require("ui.memo")
local GR = require("ui.graph")

local N = {}
local g_set = U.g_set
local NP = 8
local FF_ANY, FF_POS, FF_NONNEG, FF_CHOICE, FF_INT, FF_OPT =
  W.FF_ANY, W.FF_POS, W.FF_NONNEG, W.FF_CHOICE, W.FF_INT, W.FF_OPT
local K_ENTER, K_CLEAR, K_QUIT, K_MODE = U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE
local K_F1, K_F2, K_F4, K_F5 = U.K_F1, U.K_F2, U.K_F4, U.K_F5
local C_FG, C_GRAY, C_TITLE, C_WARN, C_ERR = U.C_FG, U.C_GRAY, U.C_TITLE, U.C_WARN, U.C_ERR
local mfmt, memo_sec, memo_line, memo_eq, memo_res, fmt_w =
  M.mfmt, M.memo_sec, M.memo_line, M.memo_eq, M.memo_res, M.fmt_w

local function settings() require("scr.screens").scr_settings() end
local function b(x) return x ~= nil and x ~= 0 and x ~= false end

local function new_pipe(tr)
  return { tr = tr or 0, L = 0, D = 0, f = 0, ks = 0, K = 0,
           str = tr and 1 or 0, sL = 0, sD = 0, sf = 0, sks = 0, sK = tr and 1 or 0 }
end
local function new_ni()
  local ni = { np = 1, H = 0, kp = 1, Qk = 0, nu = 0, z1 = 0,
               snp = 1, sH = 0, skp = 0, sQk = 0, snu = 0, sz1 = 0, mode = 0, p = {},
               bom = 0, bdato = 0, bP = 0, bEta = 0, bHB = 0, sbP = 0, sbEta = 0, sbHB = 0 }
  for i = 1, NP do ni.p[i] = new_pipe(i == 1 and 1 or nil) end
  return ni
end
local ni = new_ni()
N.ni = ni

local NET, NC = H.new_net(), {}
local nt = 0
local tr_node, tr_of, pnode = {}, {}, {}     -- 1..; tr_of = tramo 1..nt de cada tubo
local Htot = 0
local pname = "ABCDEFGH"
local function PN(i) return pname:sub(i, i) end

local mode_names = { "Adelante (H dada)", "Atras (Q en tubo)" }
local yesno = { "No", "Si" }
local bdato_names = { "Potencia P", "Carga HB" }
local HB, H0, BLOG = 0, 0, H.new_log()     -- bomba en la linea (Modificaciones JV)
local function bomb() return b(ni.bom) end
local method_names = { "Colebrook-White", "Swamee-Jain", "Haaland", "Goudar-Sonnad" }

-- si cambia el numero de tubos, el formulario se rehace al instante
local fm_now
local last_np = 1
local function np_changed()
  if b(ni.snp) and ni.np ~= last_np and fm_now then
    last_np = ni.np
    fm_now.restart = 1
  end
end

local function build_form()
  local sub = { "tramo", "L", "D", "f dado(opc)", "ks (si no f)", "Suma K" }
  local unit = { false, "m", "mm", false, "mm", false }
  local keys = { "tr", "L", "D", "f", "ks", "K" }
  local skeys = { "str", "sL", "sD", "sf", "sks", "sK" }
  local fl = { FF_INT, FF_POS, FF_POS, FF_POS + FF_OPT, FF_NONNEG + FF_OPT, FF_NONNEG }
  local ff = {}
  local np = b(ni.snp) and ni.np or 1
  ff[#ff + 1] = { label = "Numero de tubos", t = ni, k = "np", setk = "snp", flags = FF_INT, lo = 1, hi = NP }
  ff[#ff + 1] = { label = "Calcular", t = ni, chk = "mode", flags = FF_CHOICE, choices = mode_names,
                  nchoices = 2 }
  ff[#ff + 1] = { label = "Carga H (adelante)", unit = "m", t = ni, k = "H", setk = "sH", flags = FF_POS + FF_OPT }
  ff[#ff + 1] = { label = "Tubo conocido 1-8", t = ni, k = "kp", setk = "skp", flags = FF_INT + FF_OPT, lo = 1, hi = NP }
  ff[#ff + 1] = { label = "Q en ese tubo", unit = "l/s", t = ni, k = "Qk", setk = "sQk", flags = FF_POS + FF_OPT }
  ff[#ff + 1] = { label = "Viscosidad nu", unit = "m2/s", t = ni, k = "nu", setk = "snu", flags = FF_POS }
  ff[#ff + 1] = { label = "Energia tanque 1", unit = "m", t = ni, k = "z1", setk = "sz1", flags = FF_ANY + FF_OPT }
  ff[#ff + 1] = { label = "Metodo de f", t = g_set.h, chk = "method", flags = FF_CHOICE,
                  choices = method_names, nchoices = 4 }
  for i = 1, np do
    local p = ni.p[i]
    for j = 1, 6 do
      ff[#ff + 1] = { label = PN(i) .. " " .. sub[j], unit = unit[j] or nil, t = p, k = keys[j],
                      setk = skeys[j], flags = fl[j], lo = (j == 1) and 1 or nil,
                      hi = (j == 1) and NP or nil }
    end
  end
  -- bomba en la linea: (z1 - z2) + HB = M Q^2 (al final para no mover los campos)
  ff[#ff + 1] = { label = "Bomba en la linea", t = ni, chk = "bom", flags = FF_CHOICE,
                  choices = yesno, nchoices = 2 }
  ff[#ff + 1] = { label = "Dato de la bomba", t = ni, chk = "bdato", flags = FF_CHOICE,
                  choices = bdato_names, nchoices = 2 }
  ff[#ff + 1] = { label = "Potencia bomba P", unit = "kW", t = ni, k = "bP", setk = "sbP",
                  flags = FF_POS + FF_OPT }
  ff[#ff + 1] = { label = "Eficiencia bomba", unit = "0-1", t = ni, k = "bEta", setk = "sbEta",
                  flags = W.FF_RANGE + FF_OPT, lo = 0.001, hi = 1 }
  ff[#ff + 1] = { label = "Carga HB (dato)", unit = "m", t = ni, k = "bHB", setk = "sbHB",
                  flags = FF_ANY + FF_OPT }
  return ff
end

-- ------------------------------------------------------------------
-- Calculo
-- ------------------------------------------------------------------
local function compute()
  local np = math.floor(ni.np)
  NC = {}
  for k, v in pairs(g_set.h) do NC[k] = v end
  NC.nu = ni.nu
  for i = 1, np do
    if not b(ni.p[i].sf) and not b(ni.p[i].sks) then return "Cada tubo necesita f o ks" end
  end
  -- tramos distintos, en orden
  local tv = {}
  nt = 0
  for i = 1, np do
    local v = ni.p[i].tr
    local found = false
    for k = 1, nt do if tv[k] == v then found = true; break end end
    if not found then nt = nt + 1; tv[nt] = v end
  end
  table.sort(tv)
  H.hydro_net_init(NET)
  for i = 1, np do
    local p = ni.p[i]
    local idx = H.hydro_net_add_pipe(NET, p.L, p.D / 1000, b(p.sf) and p.f or 0,
      b(p.sks) and p.ks / 1000 or 0, p.K)
    if idx < 0 then return "Sistema mal definido" end
    pnode[i] = idx
    for t = 1, nt do if tv[t] == p.tr then tr_of[i] = t; break end end
  end
  local troot = {}
  for t = 1, nt do
    local kids = {}
    for i = 1, np do
      if tr_of[i] == t then kids[#kids + 1] = pnode[i] end
    end
    if #kids == 1 then
      tr_node[t] = kids[1]
    else
      local idx = H.hydro_net_add_group(NET, H.NODE_PARALLEL, kids, #kids)
      if idx < 0 then return "Sistema mal definido" end
      tr_node[t] = idx
    end
    troot[t] = tr_node[t]
  end
  if nt > 1 then
    local idx = H.hydro_net_add_group(NET, H.NODE_SERIES, troot, nt)
    if idx < 0 then return "Sistema mal definido" end
  else
    NET.root = tr_node[1]
  end
  local e
  HB, H0 = 0, 0
  H.hydro_log_clear(BLOG)
  local pot = bomb() and ni.bdato == 0
  if bomb() then
    if pot then
      if not b(ni.sbP) then return "Falta la potencia P de la bomba" end
      if not b(ni.sbEta) then return "Falta la eficiencia de la bomba" end
    elseif not b(ni.sbHB) then
      return "Falta la carga HB de la bomba"
    end
  end
  local function HBq(Q)
    if not bomb() then return 0 end
    if pot then return H.hydro_head_from_power(ni.bP * 1000, ni.bEta, Q, NC) end
    return ni.bHB
  end
  if ni.mode == 0 then
    if not b(ni.sH) then return "Falta la carga H" end
    H0 = ni.H
    if pot then
      -- Q total tal que Q = Q_red(H + eta P/(gamma Q)); g(Q) baja con Q
      local function g(Q)
        local h = H0 + HBq(Q)
        if not (h > 0) then return -Q end
        if H.hydro_net_solve(NET, h, NC) ~= 0 then return nil end
        return NET.node[NET.root].Q - Q
      end
      local lo, hi, it = 0, 0.01, 0
      while true do
        local v = g(hi)
        if v == nil then return "Sistema mal definido" end
        if v < 0 then break end
        lo, hi, it = hi, hi * 2, it + 1
        if it > 60 then return H.hydro_err_text(H.H_ERR_NOROOT) end
      end
      for i = 1, 200 do
        local mid = 0.5 * (lo + hi)
        local v = g(mid)
        if v == nil then return "Sistema mal definido" end
        H.hydro_log_row(BLOG, i, lo, hi, mid, v)
        if v > 0 then lo = mid else hi = mid end
        if hi - lo <= 1e-12 * hi then break end
      end
      HB = HBq(0.5 * (lo + hi))
    else
      HB = HBq(1)
    end
    Htot = H0 + HB
    if not (Htot > 0) then return "H + HB debe ser > 0" end
    e = H.hydro_net_solve(NET, Htot, NC)
  else
    if not b(ni.skp) or not b(ni.sQk) then return "Falta el tubo conocido y su Q" end
    if ni.kp > np then return "Ese tubo no existe" end
    local hh
    e, hh = H.hydro_net_solve_back(NET, pnode[math.floor(ni.kp)], ni.Qk / 1000, NC)
    if e == 0 then
      Htot = hh
      HB = HBq(NET.node[NET.root].Q)
      H0 = Htot - HB
    end
  end
  if e ~= 0 then return H.hydro_err_text(e) end
  return nil
end

-- ------------------------------------------------------------------
-- Resumen y memoria
-- ------------------------------------------------------------------
local function vel(i)
  local nd = NET.node[pnode[i]]
  return nd.Q / H.hydro_area(nd.pipe.D)
end

local function add_pipe_lines()
  for i = 1, math.floor(ni.np) do
    local nd = NET.node[pnode[i]]
    W.view_add(mfmt(" %s (tramo %d)  M = %s", PN(i), tr_of[i], fmt_w(nd.M, 9)), C_FG)
    W.view_add(mfmt("   Q %s l/s  h %s m  v %s", fmt_w(1000 * nd.Q, 7), fmt_w(nd.h, 7),
      fmt_w(vel(i), 6)), C_GRAY)
  end
end

local function summary()
  local root = NET.node[NET.root]
  W.view_clear()
  W.view_add("RESULTADO  Sistema serie/paralelo", C_TITLE)
  W.view_add_sep()
  W.view_add_val("Q total", 1000 * root.Q, "l/s")
  if bomb() then
    W.view_add_val("HB bomba", HB, "m")
    W.view_add_val(ni.mode ~= 0 and "z1-z2 necesaria" or "z1 - z2", H0, "m")
    W.view_add_val("H = z1-z2+HB", Htot, "m")
    if ni.mode ~= 0 then W.view_add_val("z1-z2 en kPa", H0 * NC.gamma / 1000, "kPa") end
  else
    W.view_add_val(ni.mode ~= 0 and "H necesaria" or "H", Htot, "m")
    if ni.mode ~= 0 then W.view_add_val("H en kPa", Htot * NC.gamma / 1000, "kPa") end
  end
  W.view_add_val("M total", root.M, nil)
  W.view_add_sep()
  add_pipe_lines()
  W.view_add_sep()
  W.view_add(mfmt(" Comprobacion: sum Q %s, sum h %s", fmt_w(NET.res_q * 1000, 7),
    fmt_w(NET.res_h, 7)), C_GRAY)
end

local function memo()
  local np = math.floor(ni.np)
  local k0 = H.hydro_module_coef(NC)
  local root = NET.node[NET.root]
  W.view_clear()
  W.view_add("MEMORIA  Sistema serie/paralelo", C_TITLE)
  W.view_add_sep()
  memo_sec("DATOS")
  for i = 1, np do
    local p = ni.p[i]
    local nd = NET.node[pnode[i]]
    memo_line(mfmt(" %s: tramo %d, L = %v m, D = %v m", PN(i), tr_of[i], p.L, p.D / 1000), C_FG)
    if b(p.sf) then
      memo_line(mfmt("    f = %v (dato), SumK = %v", p.f, p.K), C_GRAY)
    else
      memo_line(mfmt("    ks = %v m, SumK = %v; f auto = %v", p.ks / 1000, p.K, nd.f), C_GRAY)
    end
  end
  if ni.mode == 0 then
    memo_line(mfmt(" H = %v m", ni.H), C_FG)
  else
    memo_line(mfmt(" Q conocido en %s = %v l/s", PN(math.floor(ni.kp)), ni.Qk), C_FG)
  end
  memo_sec("MODULOS DE CAUDAL (h = M Q^2)")
  memo_line("M = 8/(pi^2 g) (f L/D^5 + SumK/D^4)", C_FG)
  memo_eq("8/(pi^2 g)", nil, mfmt("8/(pi^2 (%v))", NC.g), k0, nil)
  for i = 1, np do
    local nd = NET.node[pnode[i]]
    local lhs = "M_" .. PN(i)
    local s = mfmt("%v(%v(%v)/(%v)^5 + %v/(%v)^4)", k0, nd.f, nd.pipe.L, nd.pipe.D,
      nd.pipe.sumK, nd.pipe.D)
    memo_eq(lhs, nil, s, nd.M, nil)
    if nd.Mk > 0 then
      memo_line(mfmt("      (friccion %s + local %w)", fmt_w(nd.Mf, 9), nd.Mk), C_GRAY)
    end
  end
  memo_sec("REDUCCION DEL SISTEMA")
  for t = 1, nt do
    local g = NET.node[tr_node[t]]
    if g.type == H.NODE_PARALLEL then
      local parts = {}
      for i = 1, np do
        if tr_of[i] == t then
          parts[#parts + 1] = "1/sqrt(" .. fmt_w(NET.node[pnode[i]].M, 9) .. ")"
        end
      end
      memo_line(mfmt("M tramo %d (paralelo)", t), C_FG)
      memo_eq("  ", nil, "(" .. table.concat(parts, " + ") .. ")^-2", g.M, nil)
    end
  end
  if nt > 1 then
    local parts = {}
    for t = 1, nt do parts[t] = fmt_w(NET.node[tr_node[t]].M, 9) end
    memo_line("M total = suma de tramos en serie", C_FG)
    memo_eq("M", nil, table.concat(parts, " + "), root.M, nil)
  end
  memo_sec("CAUDAL Y CARGA")
  if bomb() then
    memo_line(" Bomba: (z1 - z2) + HB = M Q^2", C_GRAY)
    if ni.bdato == 0 then
      memo_line(mfmt(" HB = eta P/(gamma Q); P = %v kW, eta = %v", ni.bP, ni.bEta), C_GRAY)
      if ni.mode == 0 then
        memo_line(" Q total por biseccion: Q = sqrt((z1-z2 + HB(Q))/M)", C_GRAY)
        M.memo_table({ "it", "Q min", "Q max", "Q l/s", "F l/s" }, 5, BLOG,
          { 1, 1000, 1000, 1000, 1000 })
      end
      memo_eq("HB", "eta P/(gamma Q)", mfmt("%v(%v)/(%v(%v))", ni.bEta, ni.bP * 1000,
        NC.gamma, root.Q), HB, "m")
    else
      memo_eq("HB", nil, nil, HB, "m (dato)")
    end
  end
  if ni.mode == 0 then
    if bomb() then memo_eq("H", "(z1 - z2) + HB", mfmt("%v + %v", H0, HB), Htot, "m") end
    memo_eq("Q", "sqrt(H/M)", mfmt("sqrt(%v/%v)", Htot, root.M), root.Q, "m3/s")
  else
    memo_line(" Con el Q conocido se sube por el arbol:", C_GRAY)
    memo_line(" h = M Q^2 en el tubo; en un paralelo", C_GRAY)
    memo_line(" Qi = sqrt(h/Mi); en serie h se suma.", C_GRAY)
    memo_eq("Q", nil, nil, root.Q, "m3/s")
    memo_eq("H", "M Q^2", mfmt("%v(%v)^2", root.M, root.Q), Htot, "m")
    if bomb() then
      memo_eq("z1 - z2", "H - HB", mfmt("%v - %v", Htot, HB), H0, "m")
      memo_res("p = gamma (z1 - z2)", H0 * NC.gamma / 1000, "kPa")
    else
      memo_res("p = gamma H", Htot * NC.gamma / 1000, "kPa")
    end
  end
  memo_sec("REPARTO")
  for t = 1, nt do
    local g = NET.node[tr_node[t]]
    memo_eq(mfmt("h tramo %d", t), "M Q^2", mfmt("%v(%v)^2", g.M, g.Q), g.h, "m")
    if g.type == H.NODE_PARALLEL then
      for i = 1, np do
        if tr_of[i] == t then
          local nd = NET.node[pnode[i]]
          memo_eq("Q_" .. PN(i), "sqrt(h/M)", mfmt("sqrt(%v/%v)", g.h, nd.M), nd.Q, "m3/s")
        end
      end
    end
  end
  memo_sec("RESULTADOS")
  add_pipe_lines()
  if NET.outer_iters > 1 then
    memo_line(mfmt(" f automatico: %d vueltas de Colebrook-W.", NET.outer_iters), C_GRAY)
  end
  memo_sec("OBSERVACIONES")
  memo_line(mfmt(" Nudos: |Q - sum Qi| max = %w l/s", NET.res_q * 1000), C_GRAY)
  memo_line(mfmt(" Rutas: |h - sum hi| max = %w m", NET.res_h), C_GRAY)
end

-- Grafica: la ruta pasa por el tubo de mayor caudal de cada tramo
local function graph()
  local s = {}
  local np = math.floor(ni.np)
  local E0 = b(ni.sz1) and ni.z1 or (bomb() and H0 or Htot)
  for t = 1, nt do
    if t > GR.GSEG_MAX then break end
    local g = NET.node[tr_node[t]]
    local best
    for i = 1, np do
      if tr_of[i] == t and (not best or NET.node[pnode[i]].Q > NET.node[pnode[best]].Q) then
        best = i
      end
    end
    local nd = NET.node[pnode[best]]
    local sg = { L = nd.pipe.L, jump = 0, vh = 0 }
    sg.hloc = nd.M > 0 and g.h * nd.Mk / nd.M or 0
    sg.hfr = g.h - sg.hloc
    sg.vh = vel(best) * vel(best) / (2 * NC.g)
    sg.name = PN(best) .. (g.type == H.NODE_PARALLEL and "+" or "")
    s[t] = sg
  end
  if bomb() and s[1] then s[1].jump = HB end
  GR.graph_run("SISTEMA: LE y LP", E0, s, math.min(nt, GR.GSEG_MAX),
    E0 - (bomb() and H0 or Htot), true)
end

-- Casos del curso S-01 a S-05: {tramo, L, D (mm), f, K} por tubo
local exn = {
  [0] = { { 1, 100, 150, 0.020, 0 }, { 2, 100, 100, 0.015, 5 },
          { 2, 100, 100, 0.015, 5 }, { 2, 100, 100, 0.015, 5 } },
  { { 1, 500, 150, 0.014, 0 }, { 1, 600, 100, 0.018, 0 },
    { 2, 700, 200, 0.015, 5 } },
  { { 1, 100, 100, 0.025, 0 }, { 2, 100, 100, 0.025, 0 },
    { 2, 100, 200, 0.020, 30 }, { 3, 100, 100, 0.025, 0 } },
  { { 1, 400, 200, 0.02, 0 }, { 2, 180, 100, 0.025, 0 },
    { 2, 50, 100, 0.025, 0 }, { 2, 400, 200, 0.02, 0 } },
  { { 1, 700, 300, 0.014, 5 }, { 2, 600, 150, 0.020, 0 },
    { 2, 500, 200, 0.011, 0 }, { 3, 600, 250, 0.028, 3 } },
}
local exn_np = { [0] = 4, 3, 4, 4, 4 }
local exn_H = { [0] = 20, 20, 24, 0, 75 }

local net_run

function N.scr_net_example(idx)
  if idx < 0 or idx >= 5 then return end
  for i = 1, NP do ni.p[i] = new_pipe() end
  ni.np = exn_np[idx]
  ni.snp = 1
  ni.mode = idx == 3 and 1 or 0
  ni.H = exn_H[idx]
  ni.sH = idx ~= 3 and 1 or 0
  ni.kp = 4
  ni.skp = idx == 3 and 1 or 0
  ni.Qk = 40
  ni.sQk = idx == 3 and 1 or 0
  ni.nu = 1e-6
  ni.snu = 1
  ni.sz1 = 0
  ni.bom = 0
  for i = 1, exn_np[idx] do
    local p, e = ni.p[i], exn[idx][i]
    p.tr, p.L, p.D, p.f, p.K = e[1], e[2], e[3], e[4], e[5]
    p.str, p.sL, p.sD, p.sf, p.sK, p.sks = 1, 1, 1, 1, 1, 0
  end
  net_run(true)
end

function N.scr_net() net_run(false) end

local cur = 0
function N.reset_cursors() cur = 0 end

net_run = function(autocalc)
  local fk_sum = { "MEMORIA", "GRAFICO", "", "", "VOLVER" }
  local fk_memo = { "RESUMEN", "GRAFICO", "", "", "VOLVER" }
  if not b(ni.snu) then ni.nu = g_set.h.nu; ni.snu = 1 end
  last_np = b(ni.snp) and ni.np or 1
  local fm = { title = "SISTEMA SERIE/PARALELO (G)",
               fk = { "CALC f", "", "", "AJUSTES", "CALC" },
               hint = "Mismo tramo = paralelo; tramos en serie" }
  while true do
    local ff = build_form()
    fm.f = ff
    fm.n = #ff
    fm.cur = cur < #ff and cur or 0
    fm.on_commit = np_changed
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
    elseif k == K_F1 then          -- v2.0: Calcular f hacia "f dado"
      local f = ff[cur + 1]
      local isf = false
      for i = 1, NP do if f and f.t == ni.p[i] and f.k == "f" then isf = true end end
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
          local m = false
          while true do
            if m then memo() else summary() end
            local kk = W.view_run("SISTEMA SERIE/PARALELO", m and fk_memo or fk_sum)
            if kk == K_F1 then m = not m
            elseif kk == K_F2 then graph()
            elseif kk == K_MODE then settings()
            else break end
            if U.quit then return end
          end
          if U.quit then return end
        end
      end
    end
  end
end

return N
