-- scr_dyn.lua - DINAMICA DE FLUIDOS (ampliacion de examenes IC-605), D1..D4.
--   D1 Perfiles de velocidad (canal rectangular u(y), tuberia circular u(r))
--   D2 Continuidad y Bernoulli (continuidad, descarga libre de un tanque,
--      tramo 1-2 con manometro diferencial)
--   D3 Cantidad de movimiento (codo o reduccion, chorros que sostienen un peso)
--   D4 Tanques no permanentes (Qe(t), Qs(t,y) o Torricelli; RK4)
-- Mismo patron que scr_chan/scr_weir: tabla de estado por tipo, W.form_run,
-- resumen y MEMORIA DE CALCULO escrita en Lua con ui/memo.lua (no usa PERDTXT).
--
-- KINDS (identificador de cada pantalla/caso; los datos son una tabla plana de
-- numeros y cadenas; las expresiones del usuario se guardan como TEXTO):
--   "D1c" perfil en canal rectangular   "D1t" perfil en tuberia circular
--   "D2a" continuidad                   "D2b" descarga libre desde un tanque
--   "D2c" tramo 1-2 con manometro       "D3a" codo o reduccion
--   "D3b" chorros que sostienen un peso "D4"  tanque no permanente
-- Textos de expresion: ex (u(y) o u(r)), qs (Qs(t,y)), qe (Qe(t)).
--
-- API: scr_dyn_menu()                     submenu DINAMICA DE FLUIDOS
--      scr_dyn(kind) / scr_dyn_run(kind, autocalc)
--      case_get(kind) -> tabla plana      case_set(kind, t) -> bool
--      case_run(kind)                     abre la pantalla y calcula
--      examples (lista {name=, kind=}), example_load(i) -> kind,
--      example_run(i)
--      kt[kind] = KT_* (lo rellena quien registre los tipos en cases.lua; si no
--      esta, GUARDAR avisa que no esta disponible)
local U = require("ui.ui")
local W = require("ui.widgets")
local M = require("ui.memo")
local nf = require("ui.numfmt")
local H = require("core.hydro")
local Dy = require("core.dyn")
local F = require("scr.flu_util")

local S = {}
S.kt = {}

local FF_POS, FF_NONNEG, FF_CHOICE, FF_RANGE, FF_OPT, FF_INT =
  W.FF_POS, W.FF_NONNEG, W.FF_CHOICE, W.FF_RANGE, W.FF_OPT, W.FF_INT
local K_F1, K_F3, K_F4, K_F5, K_ENTER, K_CLEAR, K_QUIT, K_MODE =
  U.K_F1, U.K_F3, U.K_F4, U.K_F5, U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE
local C_ERR, C_WARN, C_FG, C_GRAY, C_OK, C_TITLE, C_EDIT, C_BG =
  U.C_ERR, U.C_WARN, U.C_FG, U.C_GRAY, U.C_OK, U.C_TITLE, U.C_EDIT, U.C_BG
local mfm, memo_line, memo_eq, memo_data, memo_sec, memo_begin, memo_res =
  M.mfmt, M.memo_line, M.memo_eq, M.memo_data, M.memo_sec, M.memo_begin, M.memo_res
local PI = math.pi

local function nz(x) return x ~= nil and x ~= 0 and x ~= false end
local function dec() return U.g_set.dec or 6 end
local function fv(x) return nf.fmt_real(x, dec()) end
-- mfmt con %p = real entre parentesis si es negativo (para sustituciones)
local function mf(fmt, ...)
  local args = { ... }
  local n = 0
  local f2 = fmt:gsub("%%(.?)", function(c)
    if c == "%" then return "%%" end
    n = n + 1
    if c == "p" then
      local x = args[n]
      args[n] = (x < 0) and ("(" .. fv(x) .. ")") or fv(x)
      return "%s"
    end
    return "%" .. c
  end)
  return mfm(f2, unpack(args, 1, n))
end
local function add(s, c) W.view_add(s, c or C_FG) end
local function val(label, v, unit) W.view_add_val(label, v, unit) end

-- ============================================================ definiciones
-- Cada kind: valores numericos (con bandera s<k>), elecciones, textos
local DEF = {
  D1c = { title = "D1 PERFIL EN CANAL",
    vals = { "b", "h", "umax", "n", "nu" }, ch = { "pf", "lc" }, tx = { "ex" } },
  D1t = { title = "D1 PERFIL EN TUBERIA",
    vals = { "D", "umax", "m", "k", "nu" }, ch = { "pf", "lc" }, tx = { "ex" } },
  D2a = { title = "D2a CONTINUIDAD",
    vals = { "Q", "vol", "time", "rho", "D1", "D2", "D3", "D4" }, ch = { "md", "fl" }, tx = {} },
  D2b = { title = "D2b DESCARGA DE UN TANQUE",
    vals = { "rho", "z0", "zs", "d", "D", "zA", "DA", "zB", "DB", "zC", "DC",
      "zD", "DD", "zE", "DE", "zF", "DF" }, ch = { "fl" }, tx = {} },
  D2c = { title = "D2c BERNOULLI 1 A 2",
    vals = { "rho", "p1", "D1", "z1", "Q", "V1", "D2", "z2", "hL", "S" },
    ch = { "fl", "md" }, tx = {} },
  D3a = { title = "D3a CODO O REDUCCION",
    vals = { "rho", "D1", "D2", "th", "Q", "V1", "p1", "dz", "hL", "p2" },
    ch = { "fl", "md" }, tx = {} },
  D3b = { title = "D3b CHORROS Y PESO",
    vals = { "rho", "N", "d", "al", "D", "mass", "H", "eta" }, ch = {}, tx = {} },
  D4 = { title = "D4 TANQUE NO PERMANENTE",
    vals = { "A", "Dt", "y0", "zs", "Cd", "dout", "tf", "yt", "tmax" },
    ch = { "tk", "so", "ob" }, tx = { "qs", "qe" } },
}
local KINDS = { "D1c", "D1t", "D2a", "D2b", "D2c", "D3a", "D3b", "D4" }
S.kinds = KINDS

local st = {}          -- estado por kind
local RES = {}         -- ultimo resultado por kind
S.res = RES

local function SC(t, k, x) t[k] = x; t["s" .. k] = 1 end

local function defaults(kind, t)
  local d = DEF[kind]
  for k in pairs(t) do t[k] = nil end
  for _, k in ipairs(d.vals) do t[k] = 0; t["s" .. k] = 0 end
  for _, k in ipairs(d.ch) do t[k] = 0 end
  for _, k in ipairs(d.tx) do t[k] = "" end
  t.init = 1
  local g = F.gset()
  if kind == "D1c" then
    t.ex = "2*y^2"
    SC(t, "nu", g.h.nu or 1e-6); SC(t, "umax", 2); SC(t, "n", 2)
  elseif kind == "D1t" then
    t.ex = "2*(1-r^2/0.04)"
    SC(t, "nu", g.h.nu or 1e-6); SC(t, "umax", 2); SC(t, "m", 2); SC(t, "k", 1)
  elseif kind == "D2b" then
    SC(t, "z0", 0); SC(t, "zs", 0)
  elseif kind == "D2c" then
    SC(t, "z1", 0); SC(t, "z2", 0)
  elseif kind == "D3a" then
    SC(t, "dz", 0); SC(t, "p1", 0)
  elseif kind == "D3b" then
    SC(t, "rho", 1000); SC(t, "N", 2); SC(t, "al", 0)
  elseif kind == "D4" then
    t.qs = "0.1"; t.qe = "0"
    SC(t, "zs", 0); SC(t, "Cd", 1)
  end
end

local function get(kind)
  local t = st[kind]
  if not t then t = {}; st[kind] = t; defaults(kind, t) end
  return t
end
for _, k in ipairs(KINDS) do get(k) end

-- ============================================================== utilidades
-- Fluido: 0 agua (gamma/g de Ajustes), 1 aire (rho_air), 2 otro
local fl_names = { "Agua", "Aire", "Otro (rho)" }
local function fluid(t, C)
  if t.fl == 1 then return F.gset().rho_air, "aire"
  elseif t.fl == 2 then
    if not nz(t.srho) then return nil, "Falta rho del fluido" end
    return t.rho, "fluido"
  end
  return C.gamma / C.g, "agua"
end

local function FN(t, lab, un, k, fl, lo, hi)
  return { label = lab, unit = un, t = t, k = k, setk = "s" .. k, flags = fl, lo = lo, hi = hi }
end
local function FC(t, lab, k, names)
  return { label = lab, t = t, chk = k, flags = FF_CHOICE, choices = names, nchoices = #names }
end
-- Campo de expresion: se muestra como una "eleccion" cuyo texto es la expresion;
-- F1 (EDITAR) abre el editor de texto.
local function short(s)
  if #s > 18 then return s:sub(1, 16) .. ".." end
  return s
end
local function FX(t, lab, k, vars, hint)
  local f = { label = lab, t = t, chk = "_x", flags = FF_CHOICE, nchoices = 1,
    choices = { short(t[k]) }, cget = function() return 0 end, cput = function() end,
    expr = k, vars = vars, hint = hint }
  return f
end

-- Editor de texto libre (expresiones). -> true, texto | false
local function edit_expr(title, label, vars, buf)
  local fk = { "", "", "", "", "LISTO" }
  local msg
  local orig = buf
  while true do
    if U.quit then return false end
    U.ui_begin(title, nil)
    U.ui_text(1, 1, label, C_FG, C_BG)
    for r = 3, 5 do U.ui_row_fill(r, C_EDIT) end
    local shown = buf .. "_"
    for r = 0, 2 do
      local piece = shown:sub(r * 38 + 1, r * 38 + 38)
      if piece ~= "" then U.ui_text(3 + r, 1, piece, C_FG, C_EDIT) end
    end
    U.ui_text(7, 1, "Variables: " .. table.concat(vars, ", ") .. "   constante: pi", C_GRAY, C_BG)
    U.ui_text(8, 1, "sin cos tan asin acos atan sqrt exp", C_GRAY, C_BG)
    U.ui_text(9, 1, "ln log abs   + - * / ^ ( )   2y = 2*y", C_GRAY, C_BG)
    U.ui_text(10, 1, "ENTER acepta; DEL borra; ESC cancela", C_GRAY, C_BG)
    U.ui_msg(msg, C_ERR)
    U.ui_fbar(fk)
    U.ui_end()
    local k = U.ui_getkey()
    local kk = k.k
    if kk == U.K_CHAR then
      local c = k.c
      if c:match("^[%w%.%+%-%*/%^%(%)%s,]$") and #buf < 100 then
        if c == "," then c = "." end
        buf = buf .. c
        msg = nil
      end
    elseif kk == U.K_DEL or kk == U.K_LEFT then
      if #buf > 0 then buf = buf:sub(1, #buf - 1) end
    elseif kk == K_ENTER or kk == K_F5 then
      local e, _, m = Dy.dyn_compile(buf, vars)
      if e == 0 then return true, buf end
      msg = m or "Expresion invalida"
    elseif kk == K_CLEAR or kk == K_QUIT then
      return false, orig
    end
  end
end

local function compile(txt, vars, name)
  local e, fn, m = Dy.dyn_compile(txt, vars)
  if e ~= 0 then return nil, name .. ": " .. (m or "expresion invalida") end
  return fn
end

-- ==================================================== utilidades de memoria
local function pad(s, n) return s .. string.rep(" ", n - #s) end
local function padl(s, n) return string.rep(" ", n - #s) .. s end

local function sec_fluid(name, rho, g)
  memo_data("rho (" .. name .. ")", rho, "kg/m3")
  memo_eq("gamma", "rho g", mf("%v * %v", rho, g), rho * g, "N/m3")
end

-- ======================================================================= D1
local lc_ch = { "h tirante", "Rh = A/P" }
local lc_pipe = { "D diametro", "r0 radio" }
local pf_ch = { "Ley de potencia", "Expresion libre" }

local function form_D1c(t)
  return {
    FN(t, "Ancho b", "m", "b", FF_POS),
    FN(t, "Tirante h", "m", "h", FF_POS),
    FC(t, "Perfil", "pf", pf_ch),
    FN(t, "umax (ley)", "m/s", "umax", FF_POS + FF_OPT),
    FN(t, "Exponente n", nil, "n", FF_POS + FF_OPT),
    FX(t, "u(y) =", "ex", { "y" }),
    FN(t, "Viscosidad nu", "m2/s", "nu", FF_POS),
    FC(t, "Lc para Re", "lc", lc_ch),
  }
end
local function form_D1t(t)
  return {
    FN(t, "Diametro D", "mm", "D", FF_POS),
    FC(t, "Perfil", "pf", pf_ch),
    FN(t, "umax (ley)", "m/s", "umax", FF_POS + FF_OPT),
    FN(t, "Exponente m", nil, "m", FF_POS + FF_OPT),
    FN(t, "Exponente k", nil, "k", FF_POS + FF_OPT),
    FX(t, "u(r) =", "ex", { "r" }),
    FN(t, "Viscosidad nu", "m2/s", "nu", FF_POS),
    FC(t, "Lc para Re", "lc", lc_pipe),
  }
end

local function compute_D1(kind, t)
  local pipe = (kind == "D1t")
  local p = { nu = t.nu, n = 400 }
  local i = {}
  local uf, ptxt
  if t.pf == 0 then
    if not nz(t.sumax) then return "Falta umax" end
    if pipe then
      if not nz(t.sm) or not nz(t.sk) then return "Faltan m y k" end
    elseif not nz(t.sn) then
      return "Falta el exponente n"
    end
  else
    local fn, e = compile(t.ex, { pipe and "r" or "y" }, "u")
    if not fn then return e end
    uf = fn
    ptxt = "u = " .. t.ex
  end
  if pipe then
    i.D = t.D / 1000
    i.r0 = i.D / 2
    if t.pf == 0 then
      uf = Dy.dyn_power_pipe(t.umax, t.m, t.k, i.r0)
      p.power = { umax = t.umax, m = t.m, k = t.k }
      ptxt = mf("u = umax (1-(r/r0)^%v)^%v", t.m, t.k)
    end
    p.r0, p.u = i.r0, uf
    i.Lc = (t.lc == 0) and i.D or i.r0
    i.lcname = (t.lc == 0) and "D" or "r0"
  else
    i.b, i.h = t.b, t.h
    if t.pf == 0 then
      uf = Dy.dyn_power_channel(t.umax, t.n, t.h)
      p.power = { umax = t.umax, n = t.n }
      ptxt = mf("u = umax (y/h)^%v", t.n)
    end
    p.b, p.h, p.u = t.b, t.h, uf
    if t.lc == 0 then i.Lc, i.lcname = t.h, "h"
    else i.Lc, i.lcname = t.b * t.h / (t.b + 2 * t.h), "Rh" end
  end
  p.Lc = i.Lc
  i.nu, i.ptxt, i.pipe = t.nu, ptxt, pipe
  i.umax_in = (t.pf == 0) and t.umax or nil
  i.n, i.m, i.k, i.power = t.n, t.m, t.k, (t.pf == 0)
  local o = {}
  local e
  if pipe then e = Dy.dyn_profile_pipe(p, o) else e = Dy.dyn_profile_channel(p, o) end
  if e ~= 0 then
    if e == 4 then return "Q <= 0: el perfil no da caudal" end
    return Dy.dyn_err_text(e)
  end
  RES[kind] = { inp = i, o = o, kind = kind }
  return nil
end

local function sum_D1(res)
  local i, o = res.inp, res.o
  memo_begin(DEF[res.kind].title)
  add(i.ptxt)
  val("Caudal Q", o.Q, "m3/s")
  val("Caudal Q", o.Q * 1000, "l/s")
  val("V media", o.V, "m/s")
  val("u maxima", o.umax, "m/s")
  val("V / umax", o.Vumax, "")
  val("alfa (Coriolis)", o.alfa, "")
  val("beta (Bouss.)", o.beta, "")
  if o.Re then val("Re = V Lc/nu", o.Re, "") end
  add(mf("Lc = %s = %v m", i.lcname, i.Lc), C_GRAY)
end

local function memo_D1(res)
  local i, o = res.inp, res.o
  local pipe = i.pipe
  memo_begin(pipe and "MEMORIA - PERFIL EN TUBERIA" or "MEMORIA - PERFIL EN CANAL")
  memo_sec("DATOS")
  if pipe then
    memo_data("D", i.D, "m")
    memo_eq("r0", "D/2", mf("%v / 2", i.D), i.r0, "m")
  else
    memo_data("b ancho", i.b, "m")
    memo_data("h tirante", i.h, "m")
  end
  memo_line(i.ptxt)
  memo_data("nu", i.nu, "m2/s")
  memo_data("Lc = " .. i.lcname, i.Lc, "m")
  memo_sec("AREA")
  if pipe then memo_eq("A", "pi r0^2", mf("pi * %v^2", i.r0), o.A, "m2")
  else memo_eq("A", "b h", mf("%v * %v", i.b, i.h), o.A, "m2") end
  local P = o.power
  if o.exact then
    memo_sec("INTEGRALES (FORMULAS EXACTAS)")
    if pipe then
      memo_line("Ij = 2 pi r0^2 umax^j B(2/m, jk+1) / m")
      memo_line(mf("B = Beta; m = %v, k = %v", P.m, P.k), C_GRAY)
      memo_eq("Q", "I1", mf("2 pi %v^2 %v B(%v,%v)/%v", i.r0, P.umax, 2 / P.m, P.k + 1, P.m), o.Q, "m3/s")
      memo_eq("I2", "Q umax B(2/m,2k+1)/B(2/m,k+1)", nil, o.I2, "m5/s2")
      memo_eq("I3", "Q umax^2 B(2/m,3k+1)/B(2/m,k+1)", nil, o.I3, "m6/s3")
    else
      memo_line("Ij = umax^j b h / (n j + 1)")
      memo_eq("Q", "umax b h / (n + 1)", mf("%v * %v * %v / (%v + 1)", P.umax, i.b, i.h, P.n), o.Q, "m3/s")
      memo_eq("I2", "umax^2 b h / (2n + 1)", mf("%v^2 * %v * %v / (2*%v + 1)", P.umax, i.b, i.h, P.n), o.I2, "m5/s2")
      memo_eq("I3", "umax^3 b h / (3n + 1)", mf("%v^3 * %v * %v / (3*%v + 1)", P.umax, i.b, i.h, P.n), o.I3, "m6/s3")
    end
  else
    memo_sec("INTEGRACION NUMERICA (SIMPSON)")
    memo_line(mf("Perfil libre: Simpson con n = %d.", o.n), C_WARN)
    if pipe then
      memo_eq("Q", "INT(0..r0) u 2 pi r dr", "Simpson", o.Q, "m3/s")
      memo_eq("I2", "INT(0..r0) u^2 2 pi r dr", "Simpson", o.I2, "m5/s2")
      memo_eq("I3", "INT(0..r0) u^3 2 pi r dr", "Simpson", o.I3, "m6/s3")
    else
      memo_eq("Q", "b INT(0..h) u dy", "Simpson", o.Q, "m3/s")
      memo_eq("I2", "b INT(0..h) u^2 dy", "Simpson", o.I2, "m5/s2")
      memo_eq("I3", "b INT(0..h) u^3 dy", "Simpson", o.I3, "m6/s3")
    end
  end
  memo_sec("VELOCIDAD MEDIA Y COEFICIENTES")
  memo_eq("V", "Q / A", mf("%v / %v", o.Q, o.A), o.V, "m/s")
  if o.exact and not pipe then
    memo_eq("V", "umax / (n + 1)", mf("%v / (%v + 1)", P.umax, P.n), o.V, "m/s")
    memo_eq("alfa", "(n+1)^3 / (3n+1)", mf("(%v+1)^3 / (3*%v+1)", P.n, P.n), (P.n + 1) ^ 3 / (3 * P.n + 1), "")
    memo_eq("beta", "(n+1)^2 / (2n+1)", mf("(%v+1)^2 / (2*%v+1)", P.n, P.n), (P.n + 1) ^ 2 / (2 * P.n + 1), "")
  elseif o.exact and pipe and P.m == 2 and P.k == 1 then
    memo_line("Parabolico: V=umax/2, alfa=2, beta=4/3", C_GRAY)
  end
  memo_eq("alfa", "I3 / (A V^3)", mf("%v / (%v * %v^3)", o.I3, o.A, o.V), o.alfa, "")
  memo_eq("beta", "I2 / (A V^2)", mf("%v / (%v * %v^2)", o.I2, o.A, o.V), o.beta, "")
  memo_eq("V/umax", nil, mf("%v / %v", o.V, o.umax), o.Vumax, "")
  if o.Re then
    memo_sec("NUMERO DE REYNOLDS")
    memo_eq("Re", "V Lc / nu", mf("%v * %v / %v", o.V, i.Lc, i.nu), o.Re, "")
  end
  memo_sec("PERFIL (" .. (pipe and "r" or "y") .. ", u)")
  for j = 1, #o.prof.y do
    memo_line("  " .. pad(M.fmt_w(o.prof.y[j], 10), 12) .. M.fmt_w(o.prof.u[j], 12))
  end
  memo_sec("RESULTADOS")
  memo_res("Q", o.Q, "m3/s")
  memo_res("Q", o.Q * 1000, "l/s")
  memo_res("V", o.V, "m/s")
  memo_res("alfa", o.alfa, "")
  memo_res("beta", o.beta, "")
  if o.Re then memo_res("Re", o.Re, "") end
end

-- ======================================================================= D2
local md_q = { "Caudal Q", "Volumen y tiempo" }
local md_qv = { "Caudal Q", "Velocidad V1" }

local function form_D2a(t)
  return {
    FC(t, "Dato", "md", md_q),
    FN(t, "Caudal Q", "l/s", "Q", FF_POS + FF_OPT),
    FN(t, "Volumen", "l", "vol", FF_POS + FF_OPT),
    FN(t, "Tiempo", "s", "time", FF_POS + FF_OPT),
    FC(t, "Fluido", "fl", fl_names),
    FN(t, "rho (Otro)", "kg/m3", "rho", FF_POS + FF_OPT),
    FN(t, "Diametro D1", "mm", "D1", FF_POS + FF_OPT),
    FN(t, "Diametro D2", "mm", "D2", FF_POS + FF_OPT),
    FN(t, "Diametro D3", "mm", "D3", FF_POS + FF_OPT),
    FN(t, "Diametro D4", "mm", "D4", FF_POS + FF_OPT),
  }
end

local function compute_D2a(kind, t, C)
  local rho, nm = fluid(t, C)
  if not rho then return nm end
  local p = { rho = rho, D = {} }
  if t.md == 0 then
    if not nz(t.sQ) then return "Falta el caudal Q" end
    p.Q = t.Q / 1000
  else
    if not nz(t.svol) or not nz(t.stime) then return "Faltan volumen y tiempo" end
    p.vol, p.time = t.vol / 1000, t.time
  end
  local any = false
  for j = 1, 4 do
    if nz(t["sD" .. j]) then p.D[j] = t["D" .. j] / 1000; any = true end
  end
  if not any then return "Indique al menos un diametro" end
  local o = {}
  local e = Dy.dyn_continuity(p, o)
  if e ~= 0 then return Dy.dyn_err_text(e) end
  RES[kind] = { inp = { p = p, fname = nm, md = t.md, vol = p.vol, time = p.time }, o = o, kind = kind }
  return nil
end

local function sum_D2a(res)
  local o = res.o
  memo_begin(DEF.D2a.title)
  val("Caudal Q", o.Q, "m3/s")
  val("Caudal Q", o.Q * 1000, "l/s")
  val("Flujo masico", o.mdot, "kg/s")
  for j = 1, 4 do
    if o.V[j] then val("V en D" .. j, o.V[j], "m/s") end
  end
end

local function memo_D2a(res)
  local i, o = res.inp, res.o
  memo_begin("MEMORIA - CONTINUIDAD")
  memo_sec("DATOS")
  memo_line("Fluido: " .. i.fname)
  memo_data("rho", i.p.rho, "kg/m3")
  if i.md == 1 then
    memo_data("Volumen", i.vol * 1000, "l")
    memo_data("Tiempo", i.time, "s")
  end
  for j = 1, 4 do
    if i.p.D[j] then memo_data("D" .. j, i.p.D[j] * 1000, "mm") end
  end
  memo_sec("CAUDAL Y FLUJO MASICO")
  if i.md == 1 then
    memo_eq("Q", "Vol / t", mf("%v / %v", i.vol, i.time), o.Q, "m3/s")
  else
    memo_data("Q", o.Q, "m3/s")
  end
  memo_eq("m punto", "rho Q", mf("%v * %v", i.p.rho, o.Q), o.mdot, "kg/s")
  memo_sec("CONTINUIDAD  V = Q / A")
  for j = 1, 4 do
    if i.p.D[j] then
      memo_eq("A" .. j, "pi D^2 / 4", mf("pi * %v^2 / 4", i.p.D[j]), o.A[j], "m2")
      memo_eq("V" .. j, "Q / A" .. j, mf("%v / %v", o.Q, o.A[j]), o.V[j], "m/s")
    end
  end
  memo_sec("RESULTADOS")
  memo_res("Q", o.Q * 1000, "l/s")
  memo_res("m punto", o.mdot, "kg/s")
  for j = 1, 4 do
    if o.V[j] then memo_res("V" .. j, o.V[j], "m/s") end
  end
end

-- ---- D2b descarga
local PTN = "ABCDEF"
local function form_D2b(t)
  local f = {
    FC(t, "Fluido", "fl", fl_names),
    FN(t, "rho (Otro)", "kg/m3", "rho", FF_POS + FF_OPT),
    FN(t, "Nivel libre z0", "m", "z0", 0),
    FN(t, "Salida zs", "m", "zs", 0),
    FN(t, "Boquilla d", "mm", "d", FF_POS),
    FN(t, "Conducto D", "mm", "D", FF_POS),
  }
  for j = 1, 6 do
    local c = PTN:sub(j, j)
    f[#f + 1] = FN(t, "Punto " .. c .. ": z", "m", "z" .. c, FF_OPT)
    f[#f + 1] = FN(t, "Punto " .. c .. ": D", "mm", "D" .. c, FF_POS + FF_OPT)
  end
  return f
end

local function compute_D2b(kind, t, C)
  local rho, nm = fluid(t, C)
  if not rho then return nm end
  local p = { g = C.g, rho = rho, z0 = t.z0, zs = t.zs, d = t.d / 1000, D = t.D / 1000, pts = {} }
  local names = {}
  for j = 1, 6 do
    local c = PTN:sub(j, j)
    if nz(t["sz" .. c]) then
      p.pts[#p.pts + 1] = { z = t["z" .. c], D = nz(t["sD" .. c]) and t["D" .. c] / 1000 or nil }
      names[#names + 1] = c
    end
  end
  local o = {}
  local e = Dy.dyn_discharge(p, o)
  if e == 4 then return "z0 debe estar sobre zs" end
  if e ~= 0 then return Dy.dyn_err_text(e) end
  RES[kind] = { inp = { p = p, fname = nm, names = names }, o = o, kind = kind }
  return nil
end

local function sum_D2b(res)
  local o, i = res.o, res.inp
  memo_begin(DEF.D2b.title)
  val("V salida", o.Vs, "m/s")
  val("Caudal Q", o.Q * 1000, "l/s")
  val("Flujo masico", o.mdot, "kg/s")
  for j, q in ipairs(o.pts) do
    add(mf("%s: p = %w Pa = %w m", i.names[j], q.p, q.hp))
  end
  for _, w in ipairs(o.warn) do add(w, C_WARN) end
end

local function memo_D2b(res)
  local i, o = res.inp, res.o
  local p = i.p
  memo_begin("MEMORIA - DESCARGA DE UN TANQUE")
  memo_sec("DATOS")
  sec_fluid(i.fname, p.rho, p.g)
  memo_data("g", p.g, "m/s2")
  memo_data("z0 nivel libre", p.z0, "m")
  memo_data("zs salida", p.zs, "m")
  memo_data("d boquilla", p.d * 1000, "mm")
  memo_data("D conducto", p.D * 1000, "mm")
  memo_sec("BERNOULLI: SUPERFICIE - SALIDA")
  memo_line("z0 = zs + Vs^2/2g (p = 0 en ambos)")
  memo_eq("Vs", "sqrt(2 g (z0 - zs))", mf("sqrt(2 * %v * %v)", p.g, o.H), o.Vs, "m/s")
  memo_eq("As", "pi d^2 / 4", mf("pi * %v^2 / 4", p.d), o.As, "m2")
  memo_eq("Q", "Vs As", mf("%v * %v", o.Vs, o.As), o.Q, "m3/s")
  memo_res("Q", o.Q * 1000, "l/s")
  memo_eq("m punto", "rho Q", mf("%v * %v", p.rho, o.Q), o.mdot, "kg/s")
  memo_sec("PRESION EN CADA PUNTO")
  memo_line("p = rho g (z0 - z - V^2/2g)")
  for j, q in ipairs(o.pts) do
    memo_line("Punto " .. i.names[j] .. ": z = " .. fv(q.z) .. " m, D = " .. fv(q.D * 1000) .. " mm", C_TITLE)
    memo_eq("V", "Q / A", mf("%v / %v", o.Q, Dy.dyn_area(q.D)), q.V, "m/s")
    memo_eq("V^2/2g", nil, mf("%v^2 / (2 * %v)", q.V, p.g), q.hv, "m")
    memo_eq("p", nil, mf("%v * %v * (%v - %p - %v)", p.rho, p.g, p.z0, q.z, q.hv), q.p, "Pa")
    memo_line(mf("  = %v m de columna del fluido", q.hp), C_GRAY)
  end
  memo_sec("AVISOS")
  if #o.warn == 0 then add(" Sin advertencias", C_OK) end
  for _, w in ipairs(o.warn) do add(w, C_WARN) end
end

-- ---- D2c Bernoulli 1-2
local function form_D2c(t)
  return {
    FC(t, "Fluido", "fl", fl_names),
    FN(t, "rho (Otro)", "kg/m3", "rho", FF_POS + FF_OPT),
    FN(t, "p1 manometrica", "kPa", "p1", FF_OPT),
    FN(t, "Diametro D1", "mm", "D1", FF_POS),
    FN(t, "Cota z1", "m", "z1", 0),
    FC(t, "Dato", "md", md_qv),
    FN(t, "Caudal Q", "l/s", "Q", FF_POS + FF_OPT),
    FN(t, "Velocidad V1", "m/s", "V1", FF_POS + FF_OPT),
    FN(t, "Diametro D2", "mm", "D2", FF_POS),
    FN(t, "Cota z2", "m", "z2", 0),
    FN(t, "Perdida hL", "m", "hL", FF_NONNEG + FF_OPT),
    FN(t, "S manometro", nil, "S", FF_POS + FF_OPT),
  }
end

local function compute_D2c(kind, t, C)
  local rho, nm = fluid(t, C)
  if not rho then return nm end
  local p = { g = C.g, rho = rho, D1 = t.D1 / 1000, D2 = t.D2 / 1000, z1 = t.z1, z2 = t.z2,
    p1 = nz(t.sp1) and t.p1 * 1000 or 0, hL = nz(t.shL) and t.hL or 0 }
  if t.md == 0 then
    if not nz(t.sQ) then return "Falta el caudal Q" end
    p.Q = t.Q / 1000
  else
    if not nz(t.sV1) then return "Falta la velocidad V1" end
    p.V1 = t.V1
  end
  local rw = C.gamma / C.g
  if nz(t.sS) then p.rhom = t.S * rw end
  local o = {}
  local e = Dy.dyn_bernoulli(p, o)
  if e ~= 0 then
    if p.rhom and e == 1 and not (p.rhom > rho) then return "El manometro debe ser mas denso" end
    return Dy.dyn_err_text(e)
  end
  RES[kind] = { inp = { p = p, fname = nm, S = t.S, rw = rw, p1given = nz(t.sp1) }, o = o, kind = kind }
  return nil
end

local function sum_D2c(res)
  local o, p = res.o, res.inp.p
  memo_begin(DEF.D2c.title)
  val("Caudal Q", o.Q * 1000, "l/s")
  val("V1", o.V1, "m/s")
  val("V2", o.V2, "m/s")
  val("p1", o.p1, "Pa")
  val("p2", o.p2, "Pa")
  val("p1 - p2", o.dp, "Pa")
  if o.hmano then
    val("h manometro", o.hmano, "m")
    val("h manometro", o.hmano * 1000, "mm")
  end
  if not res.inp.p1given then add("p1 = 0 (manometrica) por defecto", C_GRAY) end
end

local function memo_D2c(res)
  local i, o = res.inp, res.o
  local p = i.p
  memo_begin("MEMORIA - BERNOULLI 1 A 2")
  memo_sec("DATOS")
  sec_fluid(i.fname, p.rho, p.g)
  memo_data("p1", p.p1, "Pa")
  memo_data("D1", p.D1 * 1000, "mm")
  memo_data("D2", p.D2 * 1000, "mm")
  memo_data("z1", p.z1, "m")
  memo_data("z2", p.z2, "m")
  memo_data("hL perdida", p.hL, "m")
  memo_sec("CONTINUIDAD")
  memo_eq("A1", "pi D1^2 / 4", mf("pi * %v^2 / 4", p.D1), o.A1, "m2")
  memo_eq("A2", "pi D2^2 / 4", mf("pi * %v^2 / 4", p.D2), o.A2, "m2")
  if p.Q then memo_data("Q", o.Q, "m3/s")
  else memo_eq("Q", "V1 A1", mf("%v * %v", p.V1, o.A1), o.Q, "m3/s") end
  memo_eq("V1", "Q / A1", mf("%v / %v", o.Q, o.A1), o.V1, "m/s")
  memo_eq("V2", "Q / A2", mf("%v / %v", o.Q, o.A2), o.V2, "m/s")
  memo_sec("BERNOULLI 1-2")
  memo_line("p1/g' + V1^2/2g + z1 = p2/g' + V2^2/2g + z2 + hL")
  memo_line("(g' = rho g)  p2 = p1 + rho (V1^2-V2^2)/2")
  memo_line("        + rho g (z1 - z2 - hL)")
  memo_eq("p2", nil, mf("%p + %v*(%v^2-%v^2)/2 + %v*%v*(%p-%p-%v)",
    p.p1, p.rho, o.V1, o.V2, p.rho, p.g, p.z1, p.z2, p.hL), o.p2, "Pa")
  memo_eq("p1 - p2", nil, mf("%v - %p", p.p1, o.p2), o.dp, "Pa")
  memo_eq("H1", "p1/g' + V1^2/2g + z1", nil, o.h1, "m")
  memo_eq("H2", "p2/g' + V2^2/2g + z2", nil, o.h2, "m")
  if o.hmano then
    memo_sec("MANOMETRO DIFERENCIAL")
    memo_eq("rho m", "S rho agua", mf("%v * %v", i.S, i.rw), p.rhom, "kg/m3")
    memo_eq("dpiez", "(p1+g'z1) - (p2+g'z2)", nil, o.dpiez, "Pa")
    memo_eq("h", "dpiez / ((rho m - rho) g)",
      mf("%v / ((%v - %v) * %v)", o.dpiez, p.rhom, p.rho, p.g), o.hmano, "m")
  end
  memo_sec("RESULTADOS")
  memo_res("V2", o.V2, "m/s")
  memo_res("p2", o.p2, "Pa")
  memo_res("p1 - p2", o.dp, "Pa")
  if o.hmano then memo_res("h", o.hmano * 1000, "mm") end
  if not i.p1given then add("p1 = 0 (manometrica) por defecto", C_GRAY) end
end

-- ======================================================================= D3
local function form_D3a(t)
  return {
    FC(t, "Fluido", "fl", fl_names),
    FN(t, "rho (Otro)", "kg/m3", "rho", FF_POS + FF_OPT),
    FN(t, "Diametro D1", "mm", "D1", FF_POS),
    FN(t, "Diametro D2", "mm", "D2", FF_POS),
    FN(t, "Angulo theta", "grad", "th", FF_RANGE, 0, 180),
    FC(t, "Dato", "md", md_qv),
    FN(t, "Caudal Q", "l/s", "Q", FF_POS + FF_OPT),
    FN(t, "Velocidad V1", "m/s", "V1", FF_POS + FF_OPT),
    FN(t, "p1 manometrica", "kPa", "p1", 0),
    FN(t, "dz = z2 - z1", "m", "dz", 0),
    FN(t, "Perdida hL", "m", "hL", FF_NONNEG + FF_OPT),
    FN(t, "p2 dada (opc)", "kPa", "p2", FF_OPT),
  }
end

local function compute_D3a(kind, t, C)
  local rho, nm = fluid(t, C)
  if not rho then return nm end
  local p = { g = C.g, rho = rho, D1 = t.D1 / 1000, D2 = t.D2 / 1000, theta = t.th,
    p1 = t.p1 * 1000, dz = t.dz, hL = nz(t.shL) and t.hL or 0 }
  if t.md == 0 then
    if not nz(t.sQ) then return "Falta el caudal Q" end
    p.Q = t.Q / 1000
  else
    if not nz(t.sV1) then return "Falta la velocidad V1" end
    p.V1 = t.V1
  end
  if nz(t.sp2) then p.p2 = t.p2 * 1000 end
  local o = {}
  local e = Dy.dyn_elbow(p, o)
  if e ~= 0 then return Dy.dyn_err_text(e) end
  RES[kind] = { inp = { p = p, fname = nm }, o = o, kind = kind }
  return nil
end

local function sum_D3a(res)
  local o = res.o
  memo_begin(DEF.D3a.title)
  val("Caudal Q", o.Q * 1000, "l/s")
  val("V1", o.V1, "m/s")
  val("V2", o.V2, "m/s")
  val("p2", o.p2, "Pa")
  add("Fuerza del fluido sobre el codo:", C_GRAY)
  val("Rx", o.Rx, "N")
  val("Ry", o.Ry, "N")
  val("|R|", o.R, "N")
  val("Angulo de R", o.ang, "grad")
  add("Anclajes: Ax = -Rx, Ay = -Ry", C_GRAY)
end

local function memo_D3a(res)
  local i, o = res.inp, res.o
  local p = i.p
  memo_begin("MEMORIA - CODO O REDUCCION")
  memo_sec("DATOS")
  sec_fluid(i.fname, p.rho, p.g)
  memo_data("D1", p.D1 * 1000, "mm")
  memo_data("D2", p.D2 * 1000, "mm")
  memo_data("theta", p.theta, "grad")
  memo_data("p1", p.p1, "Pa")
  memo_data("dz = z2 - z1", p.dz or 0, "m")
  memo_sec("CONVENCION DE SIGNOS")
  memo_line("x = sentido de la velocidad de entrada;")
  memo_line("y a 90 grados antihorario. theta = giro")
  memo_line("de la salida respecto a la entrada.")
  memo_line("(Rx, Ry) = fuerza del FLUIDO sobre")
  memo_line("el codo. Anclajes: (Ax, Ay) = -(Rx, Ry).")
  memo_line("Se desprecia el peso del fluido/codo.")
  memo_sec("CONTINUIDAD")
  memo_eq("A1", "pi D1^2 / 4", mf("pi * %v^2 / 4", p.D1), o.A1, "m2")
  memo_eq("A2", "pi D2^2 / 4", mf("pi * %v^2 / 4", p.D2), o.A2, "m2")
  if p.Q then memo_data("Q", o.Q, "m3/s")
  else memo_eq("Q", "V1 A1", mf("%v * %v", p.V1, o.A1), o.Q, "m3/s") end
  memo_eq("V1", "Q / A1", mf("%v / %v", o.Q, o.A1), o.V1, "m/s")
  memo_eq("V2", "Q / A2", mf("%v / %v", o.Q, o.A2), o.V2, "m/s")
  memo_sec("PRESION p2")
  if o.p2_given then
    memo_data("p2 (dato)", o.p2, "Pa")
  else
    memo_line("Bernoulli: p2 = p1 + rho (V1^2-V2^2)/2")
    memo_line("            - rho g (dz + hL)")
    memo_eq("p2", nil, mf("%p + %v*(%v^2-%v^2)/2 - %v*%v*(%p+%v)",
      p.p1, p.rho, o.V1, o.V2, p.rho, p.g, p.dz or 0, p.hL or 0), o.p2, "Pa")
  end
  memo_sec("CANTIDAD DE MOVIMIENTO")
  memo_eq("F1", "p1 A1", mf("%p * %v", o.p1, o.A1), o.F1, "N")
  memo_eq("F2", "p2 A2", mf("%p * %v", o.p2, o.A2), o.F2, "N")
  memo_eq("M1", "rho Q V1", mf("%v * %v", o.mdot, o.V1), o.M1x, "N")
  memo_eq("M2", "rho Q V2", mf("%v * %v", o.mdot, o.V2), o.mdot * o.V2, "N")
  memo_line("Fluido en x: Rfx + F1 - F2 cos(th)")
  memo_line("            = M2 cos(th) - M1")
  memo_line("Fluido en y: Rfy - F2 sin(th)")
  memo_line("            = M2 sin(th)")
  memo_line("Fuerza sobre el codo = -Rf:")
  memo_eq("Rx", "F1 - F2 cos(th) - M2 cos(th) + M1",
    mf("%v - %p*%v - %v*%v + %v", o.F1, o.F2, math.cos(o.th), o.mdot * o.V2, math.cos(o.th), o.M1x), o.Rx, "N")
  memo_eq("Ry", "-F2 sin(th) - M2 sin(th)",
    mf("-%p*%v - %v*%v", o.F2, math.sin(o.th), o.mdot * o.V2, math.sin(o.th)), o.Ry, "N")
  memo_eq("|R|", "sqrt(Rx^2 + Ry^2)", mf("sqrt(%v^2 + %p^2)", o.Rx, o.Ry), o.R, "N")
  memo_eq("ang", "atan2(Ry, Rx)", nil, o.ang, "grad")
  memo_sec("RESULTADOS")
  memo_res("p2", o.p2, "Pa")
  memo_res("Rx (fluido-codo)", o.Rx, "N")
  memo_res("Ry (fluido-codo)", o.Ry, "N")
  memo_res("|R|", o.R, "N")
  memo_res("Ax anclaje", o.Ax, "N")
  memo_res("Ay anclaje", o.Ay, "N")
end

-- ---- D3b chorros
local function form_D3b(t)
  return {
    FN(t, "Densidad rho", "kg/m3", "rho", FF_POS),
    FN(t, "N de chorros", nil, "N", FF_INT, 1, 8),
    FN(t, "Diametro d chorro", "mm", "d", FF_POS),
    FN(t, "Angulo vertical", "grad", "al", FF_RANGE, 0, 89),
    FN(t, "Manguera D", "mm", "D", FF_POS),
    FN(t, "Masa sostenida", "kg", "mass", FF_POS),
    FN(t, "Altura H", "m", "H", FF_NONNEG),
    FN(t, "Eficiencia eta", nil, "eta", FF_RANGE + FF_OPT, 0.01, 1),
  }
end

local function compute_D3b(kind, t, C)
  local p = { g = C.g, rho = t.rho, N = t.N, d = t.d / 1000, alpha = t.al, D = t.D / 1000,
    mass = t.mass, H = t.H, eta = nz(t.seta) and t.eta or nil }
  local o = {}
  local e = Dy.dyn_jets(p, o)
  if e ~= 0 then return Dy.dyn_err_text(e) end
  RES[kind] = { inp = { p = p }, o = o, kind = kind }
  return nil
end

local function sum_D3b(res)
  local o = res.o
  memo_begin(DEF.D3b.title)
  val("V chorros", o.V2, "m/s")
  val("V manguera", o.V1, "m/s")
  val("Caudal Q", o.Q, "m3/s")
  val("p ent. colector", o.p1, "Pa")
  val("p sal. bomba", o.p0, "Pa")
  val("HB carga bomba", o.HB, "m")
  val("Potencia hidr.", o.Pot / 1000, "kW")
  if o.Pshaft then val("Potencia al eje", o.Pshaft / 1000, "kW") end
end

local function memo_D3b(res)
  local i, o = res.inp, res.o
  local p = i.p
  memo_begin("MEMORIA - CHORROS Y PESO")
  memo_sec("DATOS")
  sec_fluid("fluido", p.rho, p.g)
  memo_data("N chorros", p.N, "")
  memo_data("d chorro", p.d * 1000, "mm")
  memo_data("alfa (vertical)", p.alpha, "grad")
  memo_data("D manguera", p.D * 1000, "mm")
  memo_data("masa", p.mass, "kg")
  memo_data("H sobre el agua", p.H, "m")
  memo_sec("AREAS Y PESO")
  memo_eq("A1", "pi D^2 / 4", mf("pi * %v^2 / 4", p.D), o.A1, "m2")
  memo_eq("A2", "pi d^2 / 4", mf("pi * %v^2 / 4", p.d), o.A2, "m2")
  memo_eq("W", "m g", mf("%v * %v", p.mass, p.g), o.W, "N")
  memo_sec("ECUACIONES (SECCION 1 A LOS CHORROS)")
  memo_line("Continuidad: V1 A1 = N V2 A2")
  memo_eq("k", "N A2 / A1", mf("%v * %v / %v", p.N, o.A2, o.A1), o.k, "")
  memo_line("(V1 = k V2)")
  memo_line("Bernoulli: p1 = rho (V2^2 - V1^2)/2")
  memo_line("Cant. mov. vertical (peso W sostenido):")
  memo_line("p1 A1 + rho A1 V1^2 + N rho A2 V2^2 cos(a) = W")
  memo_line("=> V2^2 rho [A1 (1+k^2)/2 + N A2 cos(a)] = W")
  memo_eq("coef", "rho [A1 (1+k^2)/2 + N A2 cos a]",
    mf("%v*[%v*(1+%v^2)/2 + %v*%v*%v]", p.rho, o.A1, o.k, p.N, o.A2, o.ca), o.coef, "")
  memo_eq("V2", "sqrt(W / coef)", mf("sqrt(%v / %v)", o.W, o.coef), o.V2, "m/s")
  memo_eq("V1", "k V2", mf("%v * %v", o.k, o.V2), o.V1, "m/s")
  memo_eq("Q", "N A2 V2", mf("%v * %v * %v", p.N, o.A2, o.V2), o.Q, "m3/s")
  memo_eq("p1", "rho (V2^2 - V1^2)/2", mf("%v*(%v^2-%v^2)/2", p.rho, o.V2, o.V1), o.p1, "Pa")
  memo_sec("BOMBA")
  memo_eq("p0", "p1 + rho g H", mf("%v + %v*%v*%v", o.p1, p.rho, p.g, p.H), o.p0, "Pa")
  memo_eq("HB", "p0/g' + V1^2/2g", mf("%v/(%v*%v) + %v^2/(2*%v)", o.p0, p.rho, p.g, o.V1, p.g), o.HB, "m")
  memo_eq("P", "g' Q HB", mf("%v*%v*%v*%v", p.rho, p.g, o.Q, o.HB), o.Pot, "W")
  if o.Pshaft then
    memo_eq("P eje", "P / eta", mf("%v / %v", o.Pot, p.eta), o.Pshaft, "W")
  end
  memo_sec("RESULTADOS")
  memo_res("V chorros", o.V2, "m/s")
  memo_res("V manguera", o.V1, "m/s")
  memo_res("Q", o.Q, "m3/s")
  memo_res("p entrada colector", o.p1 / 1000, "kPa")
  memo_res("p salida bomba", o.p0 / 1000, "kPa")
  memo_res("HB", o.HB, "m")
  memo_res("Potencia", o.Pot / 1000, "kW")
  if o.Pshaft then memo_res("Potencia al eje", o.Pshaft / 1000, "kW") end
end

-- ======================================================================= D4
local tk_ch = { "Area A", "Diametro D" }
local so_ch = { "Expresion Qs", "Torricelli" }
local ob_ch = { "Nivel en t", "Tiempo a nivel" }

local function form_D4(t)
  return {
    FC(t, "Tanque", "tk", tk_ch),
    FN(t, "Area A", "m2", "A", FF_POS + FF_OPT),
    FN(t, "Diametro D", "m", "Dt", FF_POS + FF_OPT),
    FN(t, "Nivel inicial y0", "m", "y0", 0),
    FN(t, "Cota salida zs", "m", "zs", 0),
    FC(t, "Salida", "so", so_ch),
    FX(t, "Qs(t,y) =", "qs", { "t", "y" }),
    FN(t, "Cd (Torricelli)", nil, "Cd", FF_POS + FF_OPT),
    FN(t, "D tubo/orificio", "mm", "dout", FF_POS + FF_OPT),
    FX(t, "Qe(t) =", "qe", { "t" }),
    FC(t, "Objetivo", "ob", ob_ch),
    FN(t, "Tiempo t", "s", "tf", FF_POS + FF_OPT),
    FN(t, "Nivel objetivo", "m", "yt", FF_OPT),
    FN(t, "t maximo", "s", "tmax", FF_POS + FF_OPT),
  }
end

local function compute_D4(kind, t, C)
  local i = { g = C.g }
  if t.tk == 0 then
    if not nz(t.sA) then return "Falta el area A" end
    i.A = t.A
  else
    if not nz(t.sDt) then return "Falta el diametro D" end
    i.A = PI * t.Dt * t.Dt / 4
    i.Dt = t.Dt
  end
  local p = { A = i.A, y0 = t.y0, zs = t.zs, g = C.g }
  local qef, e1 = compile(t.qe, { "t" }, "Qe")
  if not qef then return e1 end
  p.qe = qef
  i.qe_txt = t.qe
  if t.so == 0 then
    local qsf, e2 = compile(t.qs, { "t", "y" }, "Qs")
    if not qsf then return e2 end
    p.qs = qsf
    i.qs_txt = t.qs
    if nz(t.sdout) then p.at = PI * t.dout * t.dout / 4e6; i.dout = t.dout / 1000 end
  else
    if not nz(t.sCd) or not nz(t.sdout) then return "Faltan Cd y el diametro de salida" end
    i.Cd, i.dout = t.Cd, t.dout / 1000
    i.a = PI * i.dout * i.dout / 4
    p.Cd, p.a = i.Cd, i.a
  end
  if t.ob == 0 then
    if not nz(t.stf) then return "Falta el tiempo t" end
    p.tf = t.tf
  else
    if not nz(t.syt) then return "Falta el nivel objetivo" end
    p.ytarget = t.yt
    if nz(t.stmax) then p.tmax = t.tmax end
  end
  i.p, i.ob, i.so = p, t.ob, t.so
  local o = {}
  local e = Dy.dyn_tank(p, o)
  if e ~= 0 then return Dy.dyn_err_text(e) end
  RES[kind] = { inp = i, o = o, kind = kind }
  return nil
end

local function d4_warn(res, fn)
  local o, i = res.o, res.inp
  if o.status == "equilibrium" and i.ob == 1 then
    fn("El nivel " .. fv(i.p.ytarget) .. " m NO se alcanza.", C_WARN)
    fn("El nivel tiende al equilibrio y = " .. fv(o.y_end) .. " m", C_WARN)
  elseif o.status == "tmax" then
    fn("No se alcanzo el nivel antes de tmax.", C_WARN)
  elseif o.status == "equilibrium" then
    fn("Nivel en equilibrio (dy/dt = 0).", C_WARN)
  end
end

local function sum_D4(res)
  local o, i = res.o, res.inp
  memo_begin(DEF.D4.title)
  d4_warn(res, add)
  if i.ob == 0 then
    val("Nivel y(t)", o.y_end, "m")
    val("en t =", o.t_end, "s")
  elseif o.reached then
    val("Tiempo", o.t_end, "s")
    val("al nivel", o.y_end, "m")
  else
    val("t llegado", o.t_end, "s")
    val("nivel alcanzado", o.y_end, "m")
  end
  val("Qs final", o.Qs_end * 1000, "l/s")
  if o.v_end then val("V en el tubo", o.v_end, "m/s") end
  val("Qs inicial", o.Qs0 * 1000, "l/s")
  if o.v0 then val("V inicial", o.v0, "m/s") end
  if o.dvdt0 then val("dV/dt inicial", o.dvdt0, "m/s2") end
  if o.y_eq then val("Nivel equilibrio", o.y_eq, "m") end
end

local function memo_D4(res)
  local o, i = res.o, res.inp
  local p = i.p
  memo_begin("MEMORIA - TANQUE NO PERMANENTE")
  memo_sec("DATOS")
  memo_data("A tanque", i.A, "m2")
  memo_data("y0", p.y0, "m")
  memo_data("zs salida", p.zs or 0, "m")
  memo_line("Qe(t) = " .. i.qe_txt)
  if i.so == 0 then
    memo_line("Qs(t,y) = " .. i.qs_txt)
    if i.dout then memo_data("D tubo", i.dout * 1000, "mm") end
  else
    memo_data("Cd", i.Cd, "")
    memo_data("D salida", i.dout * 1000, "mm")
  end
  memo_sec("ECUACION DE CONTINUIDAD")
  memo_line("A dy/dt = Qe(t) - Qs(t,y)")
  if i.so ~= 0 then
    memo_eq("a", "pi d^2 / 4", mf("pi * %v^2 / 4", i.dout), i.a, "m2")
    memo_line("Qs = Cd a sqrt(2 g (y - zs))")
  end
  memo_sec("METODO NUMERICO")
  memo_line("Runge-Kutta 4 con paso automatico")
  memo_line("(doble paso, tolerancia 1E-9 m).")
  memo_line(mf("Pasos de integracion: %d", o.steps))
  if i.ob == 1 then
    memo_line("Tiempo a un nivel: biseccion del paso")
    memo_line("que cruza el nivel objetivo.")
  end
  memo_sec("CONDICION INICIAL")
  memo_eq("Qs(0)", nil, mf("Qs(0, %v)", p.y0), o.Qs0, "m3/s")
  memo_eq("dy/dt(0)", "(Qe - Qs)/A", mf("(%v - %v)/%v", o.Qe0, o.Qs0, i.A), o.dydt0, "m/s")
  if o.v0 then memo_eq("V0", "Qs / a", nil, o.v0, "m/s") end
  if o.dvdt0 then
    memo_eq("dV/dt(0)", "(g/V) dy/dt", mf("(%v/%v) * %p", i.g, o.v0, o.dydt0), o.dvdt0, "m/s2")
  end
  memo_sec("TABLA DE LA INTEGRACION")
  local S2 = o.samples
  local m = math.min(10, S2.n)
  local lg = { n = m, total = m, r = {} }
  for j = 1, m do
    local idx = (m == 1) and 1 or math.floor((j - 1) * (S2.n - 1) / (m - 1) + 1.5)
    lg.r[j] = { idx, S2.t[idx], S2.y[idx], S2.qs[idx] }
  end
  M.memo_table({ "#", "t [s]", "y [m]", "Qs[l/s]" }, 4, lg, { 1, 1, 1, 1000 })
  memo_sec("RESULTADOS")
  d4_warn(res, function(s, c) memo_line(s, c) end)
  if i.ob == 0 then
    memo_res("y(t)", o.y_end, "m")
    memo_res("t", o.t_end, "s")
  elseif o.reached then
    memo_res("t", o.t_end, "s")
    memo_res("y", o.y_end, "m")
  else
    memo_res("t llegado", o.t_end, "s")
    memo_res("y alcanzado", o.y_end, "m")
  end
  memo_res("Qs", o.Qs_end * 1000, "l/s")
  if o.v_end then memo_res("V tubo", o.v_end, "m/s") end
  if o.y_eq then
    memo_eq("y eq", "zs + (Qe/(Cd a))^2/2g", mf("%v + (%v/(%v*%v))^2/(2*%v)",
      p.zs or 0, o.Qe_end, i.Cd, i.a, i.g), o.y_eq, "m")
  end
end

-- ============================================================ tabla de kinds
local K = {
  D1c = { form = form_D1c, compute = function(t) return compute_D1("D1c", t) end,
    sum = sum_D1, memo = memo_D1 },
  D1t = { form = form_D1t, compute = function(t) return compute_D1("D1t", t) end,
    sum = sum_D1, memo = memo_D1 },
  D2a = { form = form_D2a, compute = function(t, C) return compute_D2a("D2a", t, C) end,
    sum = sum_D2a, memo = memo_D2a },
  D2b = { form = form_D2b, compute = function(t, C) return compute_D2b("D2b", t, C) end,
    sum = sum_D2b, memo = memo_D2b },
  D2c = { form = form_D2c, compute = function(t, C) return compute_D2c("D2c", t, C) end,
    sum = sum_D2c, memo = memo_D2c },
  D3a = { form = form_D3a, compute = function(t, C) return compute_D3a("D3a", t, C) end,
    sum = sum_D3a, memo = memo_D3a },
  D3b = { form = form_D3b, compute = function(t, C) return compute_D3b("D3b", t, C) end,
    sum = sum_D3b, memo = memo_D3b },
  D4 = { form = form_D4, compute = function(t, C) return compute_D4("D4", t, C) end,
    sum = sum_D4, memo = memo_D4 },
}

-- ================================================================ pantallas
local function save_case(kind)
  local kt = S.kt[kind]
  if kt then F.case_save_ui(kt)
  else U.ui_alert("Guardar", "Disponible al registrar los", "tipos de caso de DINAMICA", C_WARN) end
end

local function result_loop(kind)
  local k = K[kind]
  local fk_sum = { "MEMORIA", "", "GUARDAR", "", "VOLVER" }
  local fk_memo = { "RESUMEN", "", "", "", "VOLVER" }
  local memo = false
  while true do
    local res = RES[kind]
    if memo then k.memo(res) else k.sum(res) end
    local key = W.view_run(DEF[kind].title, memo and fk_memo or fk_sum)
    if key == K_F1 then memo = not memo
    elseif key == K_F3 and not memo then save_case(kind)
    elseif key == K_MODE then F.scr_settings()
    else return end
    if U.quit then return end
  end
end

local cur_of = {}

function S.scr_dyn_run(kind, autocalc)
  local k = K[kind]
  if not k then return end
  local t = get(kind)
  local fm = { title = DEF[kind].title, f = k.form(t), cur = cur_of[kind] or 0, top = 0 }
  fm.n = #fm.f
  if fm.cur >= fm.n then fm.cur = 0 end
  local has_expr = false
  for _, f in ipairs(fm.f) do if f.expr then has_expr = true end end
  fm.fk = { has_expr and "EDITAR" or "", "", "", "AJUSTES", "CALC" }
  while true do
    local key
    if autocalc then
      autocalc = false
      key = K_F5
    else
      local cf = fm.f[fm.cur + 1]
      fm.hint = (cf and cf.expr) and ("F1 edita: " .. t[cf.expr]) or "Escriba un valor o una expresion"
      key = W.form_run(fm)
    end
    if key == K_QUIT or key == K_CLEAR then break end
    if key == K_F4 or key == K_MODE then
      F.scr_settings()
    elseif key == K_F1 then
      local cf = fm.f[fm.cur + 1]
      if cf and cf.expr then
        local ok, txt = edit_expr("EDITAR EXPRESION", cf.label, cf.vars, t[cf.expr])
        if U.quit then break end
        if ok then t[cf.expr] = txt; cf.choices[1] = short(txt) end
      end
    elseif key == K_F5 or key == K_ENTER then
      if W.form_check(fm) then
        local err = k.compute(t, F.cfg_copy())
        if err then
          fm.msg = err
          fm.msg_color = C_ERR
        else
          result_loop(kind)
          if U.quit then break end
        end
      end
    end
  end
  cur_of[kind] = fm.cur
end

function S.scr_dyn(kind) S.scr_dyn_run(kind, false) end

-- ------------------------------------------------------------- Mis casos
function S.case_get(kind)
  if not K[kind] then return nil end
  local out = {}
  for k, v in pairs(get(kind)) do
    if type(v) == "number" or type(v) == "string" then out[k] = v end
  end
  return out
end

function S.case_set(kind, tt)
  if not K[kind] or type(tt) ~= "table" then return false end
  local t = get(kind)
  defaults(kind, t)
  for k, v in pairs(tt) do
    if type(v) == "number" or type(v) == "string" then t[k] = v end
  end
  for _, k in ipairs(DEF[kind].ch) do
    if type(t[k]) ~= "number" or t[k] < 0 or t[k] ~= math.floor(t[k]) then t[k] = 0 end
  end
  for _, k in ipairs(DEF[kind].tx) do
    if type(t[k]) ~= "string" then t[k] = "" end
  end
  t.init = 1
  return true
end

function S.case_run(kind)
  if not K[kind] then return end
  S.scr_dyn_run(kind, true)
end

-- ------------------------------------------------- Ejemplos de examen
local function ex_set(kind, vals, chs, txts)
  local t = get(kind)
  defaults(kind, t)
  for k, v in pairs(vals or {}) do SC(t, k, v) end
  for k, v in pairs(chs or {}) do t[k] = v end
  for k, v in pairs(txts or {}) do t[k] = v end
  return kind
end

S.examples = {
  { name = "EPSON P5a: u = (y/d)^0.5, canal", kind = "D1c", load = function()
    return ex_set("D1c", { b = 8, h = 1, umax = 1, n = 0.5, nu = 1.007e-6 }, { pf = 0, lc = 0 }) end },
  { name = "P2-2024 P4a: u = 2y^2, b = 2", kind = "D1c", load = function()
    return ex_set("D1c", { b = 2, h = 1, nu = 1e-6 }, { pf = 0, lc = 0 }, { ex = "2*y^2" }) end },
  { name = "Varios: perfil parabolico", kind = "D1t", load = function()
    return ex_set("D1t", { D = 400, nu = 1e-6, umax = 2, m = 2, k = 1 }, { pf = 0, lc = 0 }) end },
  { name = "Varios Ej1: manguera, boquilla", kind = "D2a", load = function()
    return ex_set("D2a", { vol = 12, time = 50, D1 = 12, D2 = 5 }, { md = 1, fl = 0 }) end },
  { name = "P2-2025 P1: aire, reduccion", kind = "D2c", load = function()
    return ex_set("D2c", { D1 = 220, D2 = 100, Q = 120, z1 = 0, z2 = 0, S = 1 }, { fl = 1, md = 0 }) end },
  { name = "P2-2024 P2: descarga A-D", kind = "D2b", load = function()
    return ex_set("D2b", { z0 = 6, zs = 2.4, d = 50, D = 150, zA = 0, zB = 6, zC = 7.5, zD = 2.4 },
      { fl = 0 }) end },
  { name = "P2-2024 P3: codo 45, anclajes", kind = "D3a", load = function()
    return ex_set("D3a", { D1 = 200, D2 = 150, th = 45, V1 = 2.5, p1 = 10, dz = 2 },
      { fl = 0, md = 1 }) end },
  { name = "P2-2025 P5: flyboard", kind = "D3b", load = function()
    return ex_set("D3b", { rho = 1040, N = 2, d = 50, al = 10, D = 100, mass = 130, H = 6.5 }) end },
  { name = "P2-2024 P1: y(90 s), Qs(t)", kind = "D4", load = function()
    return ex_set("D4", { A = 4, y0 = 5, zs = 0, dout = 150, tf = 90 }, { tk = 0, so = 0, ob = 0 },
      { qs = "0.1*(1+sin(t/(8*pi)))", qe = "0.1" }) end },
  { name = "P2-2025 P2: tiempo de vaciado", kind = "D4", load = function()
    return ex_set("D4", { Dt = 12, y0 = 6.5, zs = 0, yt = 0 }, { tk = 1, so = 0, ob = 1 },
      { qs = "0.4*cos(t/18000)", qe = "0.1" }) end },
  { name = "Varios Ej2: orificio 150 mm", kind = "D4", load = function()
    return ex_set("D4", { Dt = 1.5, y0 = 2, zs = 0, Cd = 1, dout = 150, yt = 1 },
      { tk = 1, so = 1, ob = 1 }, { qe = "0" }) end },
  { name = "Tanque 3 m: vaciado", kind = "D4", load = function()
    return ex_set("D4", { A = 20, y0 = 3, zs = 0, Cd = 1, dout = 150, yt = 0 },
      { tk = 0, so = 1, ob = 1 }, { qe = "0" }) end },
  { name = "Tanque 5 m: Qe = 0.1 (equilibrio)", kind = "D4", load = function()
    return ex_set("D4", { A = 36, y0 = 5, zs = 0, Cd = 1, dout = 150, yt = 0.5 },
      { tk = 0, so = 1, ob = 1 }, { qe = "0.1" }) end },
}

function S.example_load(i)
  local e = S.examples[i]
  if not e then return nil end
  return e.load()
end

function S.example_run(i)
  local kind = S.example_load(i)
  if kind then S.scr_dyn_run(kind, true) end
end

-- --------------------------------------------------------------- menus
local function sub_menu(m, fn)
  while not U.quit do
    local r = W.menu_run(m)
    if r == W.MENU_BACK or r == W.MENU_QUIT then return end
    if r == W.MENU_MODE then F.scr_settings() else fn(r) end
  end
end

local m_d1 = { title = "D1 PERFILES DE VELOCIDAD", cur = 0,
  items = { "Canal rectangular   u(y)", "Tuberia circular   u(r)" } }
local m_d2 = { title = "D2 CONTINUIDAD Y BERNOULLI", cur = 0,
  items = { "a) Continuidad (Q, V, m punto)", "b) Descarga libre de un tanque",
    "c) Tramo 1-2 y manometro" } }
local m_d3 = { title = "D3 CANTIDAD DE MOVIMIENTO", cur = 0,
  items = { "a) Codo o reduccion (anclajes)", "b) Chorros que sostienen un peso" } }
local m_main = { title = "DINAMICA DE FLUIDOS", cur = 0,
  items = { "D1 Perfiles de velocidad", "D2 Continuidad y Bernoulli",
    "D3 Cantidad de movimiento", "D4 Tanques no permanentes", "Ejemplos de examen" } }
local ex_cur = 0

local function examples_menu()
  while not U.quit do
    for j, e in ipairs(S.examples) do W.list_line[j - 1] = e.name end
    local r, k = W.list_pick("EJEMPLOS DE EXAMEN", "ENTER carga los datos y calcula",
      #S.examples, ex_cur, nil)
    if r < 0 or k ~= K_ENTER then return end
    ex_cur = r
    S.example_run(r + 1)
  end
end

function S.scr_dyn_menu()
  sub_menu(m_main, function(r)
    if r == 0 then
      sub_menu(m_d1, function(j) S.scr_dyn(j == 0 and "D1c" or "D1t") end)
    elseif r == 1 then
      sub_menu(m_d2, function(j) S.scr_dyn(({ "D2a", "D2b", "D2c" })[j + 1]) end)
    elseif r == 2 then
      sub_menu(m_d3, function(j) S.scr_dyn(j == 0 and "D3a" or "D3b") end)
    elseif r == 3 then
      S.scr_dyn("D4")
    else
      examples_menu()
    end
  end)
end

return S
