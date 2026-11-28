-- scr_orig.lua - "Mi programa original" (Tuberias hf + hL) de las Modificaciones
-- JV (Modificaciones JV/tuberias_2.lua), integrado a la app.
--   Problemas: Calculo de Q, Calculo de D, H bomba, H turbina, Perdidas totales
--   (Q, D y perdidas totales aceptan bomba en la linea: HB dada o eta P).
--   Calculos individuales: V, Q, Re, e/D, f, hf, hL, K, V^2/2g, potencias.
-- Cada paso se redondea a 3 decimales (|x| < 1 en cientifica) como a mano;
-- g = 9.81, gamma = 9810 y Colebrook con 3.71, como en el programa original.
-- Resultado: resumen (F1 MEMORIA de la primera iteracion, F2 TABLA de
-- iteraciones, F3 FILAS: una fila de la tabla por pantalla).
-- API: O.scr_orig(), O.oi (datos), O.compute(idx, ind) -> res | nil, err,
--      O.reset_cursors()
local U = require("ui.ui")
local W = require("ui.widgets")
local M = require("ui.memo")
local R3 = require("core.round3")

local O = {}
local r3, rls, rmm, fmt3 = R3.r3, R3.rls, R3.rmm, R3.fmt3
local pi, sqrt, abs, floor = math.pi, math.sqrt, math.abs, math.floor
local function log10(x) return math.log(x) / math.log(10) end
local FF_ANY, FF_POS, FF_NONNEG, FF_CHOICE, FF_OPT, FF_RANGE =
  W.FF_ANY, W.FF_POS, W.FF_NONNEG, W.FF_CHOICE, W.FF_OPT, W.FF_RANGE
local K_ENTER, K_CLEAR, K_QUIT, K_MODE = U.K_ENTER, U.K_CLEAR, U.K_QUIT, U.K_MODE
local K_F1, K_F2, K_F3, K_F5 = U.K_F1, U.K_F2, U.K_F3, U.K_F5
local C_FG, C_GRAY, C_TITLE, C_ERR, C_OK = U.C_FG, U.C_GRAY, U.C_TITLE, U.C_ERR, U.C_OK

local G0, GAM0, TOL0, NMAX0 = 9.81, 9810.0, 1e-4, 40

local function herr(m) error(m, 0) end
local function area(D) return r3(pi * D * D / 4) end
local function gamma_cfg() return (U.g_set.h and U.g_set.h.gamma) or GAM0 end

-- ------------------------------------------------------------------
-- Datos del formulario (unidades de pantalla) y helpers de campos
-- ------------------------------------------------------------------
local oi = {
  cs = 0, bom = 0, bdato = 0,
  dz = 0, D = 0, L = 0, ks = 0, nu0 = 1.02e-6, K = 0, f0 = 0.02, Q = 0, D0 = 100,
  vs = 0, eta = 1, bP = 0, bEta = 0, bHB = 0, V = 0, Re = 0, eD = 0, f = 0, hl = 0,
  HB = 0, HTu = 0,
  sdz = 0, sD = 0, sL = 0, sks = 0, snu0 = 1, sK = 1, sf0 = 1, sQ = 0, sD0 = 1,
  svs = 0, seta = 1, sbP = 0, sbEta = 0, sbHB = 0, sV = 0, sRe = 0, seD = 0, sf = 0,
  shl = 0, sHB = 0, sHTu = 0,
}
O.oi = oi
local function b(x) return x ~= nil and x ~= 0 and x ~= false end
local function val(k) return b(oi["s" .. k]) and oi[k] or nil end

local function NUMF(lab, un, k, fl, lo, hi)
  return { label = lab, unit = un, t = oi, k = k, setk = "s" .. k, flags = fl, lo = lo, hi = hi }
end
local function CHO(lab, k, names)
  return { label = lab, t = oi, chk = k, flags = FF_CHOICE, choices = names, nchoices = #names }
end
local fcs = function() return CHO("Vel. salida", "cs", { "Si (libre)", "No (tanque)" }) end
local fnu0 = function() return NUMF("nu", "m2/s", "nu0", FF_POS) end
local fK = function() return NUMF("Suma K", nil, "K", FF_NONNEG) end
local fQ = function() return NUMF("Q", "l/s", "Q", FF_POS) end
local fD = function() return NUMF("D", "mm", "D", FF_POS) end
local fL = function() return NUMF("L", "m", "L", FF_POS) end
local fks = function() return NUMF("ks", "mm", "ks", FF_NONNEG) end
local fvs = function() return NUMF("Vs (opc; Q/A)", "m/s", "vs", FF_NONNEG + FF_OPT) end
local feta = function() return NUMF("Eficiencia", "0-1", "eta", FF_RANGE, 0.001, 1) end
local function con_bomba(fl)
  fl[#fl + 1] = CHO("Bomba en la linea", "bom", { "No", "Si" })
  fl[#fl + 1] = CHO("Dato de la bomba", "bdato", { "Potencia P", "Carga HB" })
  fl[#fl + 1] = NUMF("Potencia bomba P", "kW", "bP", FF_POS + FF_OPT)
  fl[#fl + 1] = NUMF("Eficiencia bomba", "0-1", "bEta", FF_RANGE + FF_OPT, 0.001, 1)
  fl[#fl + 1] = NUMF("Carga HB (dato)", "m", "bHB", FF_ANY + FF_OPT)
  return fl
end

-- ------------------------------------------------------------------
-- Visor: memoria con 3 decimales
-- ------------------------------------------------------------------
local function vadd(s, c) W.view_add(s, c or C_FG) end
local function vsep() W.view_add_sep() end
local function msec(s) M.memo_sec(s) end
local function mline(s, c) M.memo_line(s, c or C_FG) end
local function fv(x) return fmt3(x) end
local function vval(l, v, u)
  local line = " " .. l:sub(1, 16)
  line = line .. string.rep(" ", 17 - #line) .. "= " .. fv(v)
  if u then line = line .. " " .. u end
  mline(line, C_FG)
end
local function meq(lhs, formula, subst, res, unit)
  local pad = #lhs + 1
  if pad > 12 then pad = 4 end
  local sp = string.rep(" ", pad)
  local num = fv(res) .. (unit and (" " .. unit) or "")
  if formula then mline(lhs .. " = " .. formula, C_FG) end
  if subst and not formula then mline(lhs .. " = " .. subst, C_FG)
  elseif subst then mline(sp .. "= " .. subst, C_GRAY) end
  if not formula and not subst then mline(lhs .. " = " .. num, C_OK)
  else mline(sp .. "= " .. num, C_OK) end
end
local function mres(l, v, u) mline("> " .. l .. " = " .. fv(v) .. (u and (" " .. u) or ""), C_OK) end

-- ------------------------------------------------------------------
-- Calculo (port de oc_*/oi_* de tuberias_2.lua)
-- ------------------------------------------------------------------
local function o_colebrook(Re, eD)
  if Re < 2000 then return r3(64 / Re) end
  local f, f1, fp2 = 0.02, 0.02, nil
  for _ = 1, 100 do
    f1 = r3((-2 * log10(eD / 3.71 + 2.51 / (Re * sqrt(f)))) ^ -2)
    if f1 == f or f1 == fp2 then break end
    fp2 = f
    f = f1
  end
  return f1
end
local function o_re(Q, D, nu) return r3(4 * Q / (pi * D * nu)) end
local function o_k8(Q, D) return r3(8 * Q * Q / (G0 * pi * pi * D ^ 4)) end
local function o_reg(Re)
  if Re < 2000 then return "Laminar" end
  if Re < 4000 then return "Transicional" end
  return "Turbulento"
end
local function o_tabla_f(Re, eD)
  if Re < 2000 then return r3(64 / Re), nil, { "Laminar: f = 64/Re" } end
  local rows, f0, f1 = {}, 0.05, 0.05
  local ok = false
  for i = 1, NMAX0 do
    f1 = r3((-2 * log10(eD / 3.71 + 2.51 / (Re * sqrt(f0)))) ^ -2)
    rows[#rows + 1] = { tostring(i), fmt3(f0), fmt3(f1) }
    if abs(f1 - f0) < TOL0 then ok = true; break end
    f0 = f1
  end
  return f1, { hdr = { "i", "f0", "f1" }, rows = rows }, ok and {} or { "Aviso: max. iteraciones" }
end
local function o_pot(P)
  P = r3(P)
  return { { "P", fmt3(P) .. " W" }, { "P", fmt3(r3(P / 1000)) .. " kW" },
           { "P", fmt3(r3(P / 745.7)) .. " HP" } }
end
local function cat(...)
  local r = {}
  for _, t in ipairs({ ... }) do for _, x in ipairs(t) do r[#r + 1] = x end end
  return r
end
local function pos(x, n) if x == nil or x <= 0 then herr(n .. " debe ser > 0") end end
local function need(k, n) local v = val(k); if v == nil then herr("Falta " .. n) end; return v end
local function u3(x, u) return fmt3(x) .. (u and (" " .. u) or "") end
local function R(r, t, w) return { r = r, t = t, w = w or {} } end

-- raiz positiva de a Q^3 - b Q - c = 0 (Newton desde la derecha)
local function raiz_cubica(a, bq, c)
  local x = math.max((c / a) ^ (1 / 3), sqrt(math.max(bq, 0) / a)) * 2 + 1e-9
  for _ = 1, 80 do
    local fx = a * x * x * x - bq * x - c
    local d = 3 * a * x * x - bq
    if d == 0 then break end
    local xn = x - fx / d
    if abs(xn - x) <= 1e-13 * abs(x) then x = xn; break end
    x = xn
  end
  return rls(x)
end

local function o_bomba()
  local bo = { on = b(oi.bom), pot = b(oi.bom) and oi.bdato == 0, HB = 0, bpg = 0 }
  if bo.on then
    if bo.pot then
      bo.P, bo.eta = need("bP", "la potencia P de la bomba"), need("bEta", "la eficiencia de la bomba")
      if not (bo.eta > 0 and bo.eta <= 1) then herr("Eficiencia de la bomba: 0 a 1") end
      bo.bpg = bo.eta * bo.P * 1000 / gamma_cfg()     -- eta P/gamma (sin redondear)
    else
      bo.HB = r3(need("bHB", "la carga HB de la bomba"))
    end
  end
  return bo
end

local function o_memo_bomba(bo, Q)
  if not bo.on then return end
  msec("BOMBA")
  mline(" Energia: dZ + HB = (c + f L/D + SumK) V^2/2g", C_GRAY)
  if bo.pot then
    vval("Potencia P", bo.P, "kW")
    vval("Eficiencia eta", bo.eta)
    meq("eta P/gamma", nil, fv(bo.eta) .. "(" .. fv(bo.P * 1000) .. ")/" .. fv(gamma_cfg()), bo.bpg, "m4/s")
    if Q then
      meq("HB", "eta P/(gamma Q)", fv(bo.eta) .. "(" .. fv(bo.P * 1000) .. ")/(" .. fv(gamma_cfg()) ..
          "(" .. fv(Q) .. "))", r3(bo.bpg / Q), "m")
    end
  else
    vval("HB (dato)", bo.HB, "m")
  end
end

local function oc_Q()
  local c = (oi.cs == 0) and 1 or 0
  local dz, D, L = need("dz", "dZ"), rmm(need("D", "D") / 1000), need("L", "L")
  local ks, nu, K, f0 = r3(need("ks", "ks") / 1000), need("nu0", "nu"), val("K") or 0, need("f0", "f inicial")
  pos(D, "D"); pos(nu, "nu")
  local bo = o_bomba()
  local dzf = r3(dz + bo.HB)
  if not bo.pot and not (dzf > 0) then herr(bo.on and "dZ + HB debe ser > 0" or "dZ debe ser > 0") end
  local eD = r3(ks / D)
  local LD = r3(L / D)
  local k4 = r3(G0 * pi * pi * D ^ 4)
  local function Qf(x)
    local Cc = r3(c + r3(x * LD) + K)
    if bo.pot then
      local a = r3(8 * Cc / k4)
      return raiz_cubica(a, dz, bo.bpg), Cc, a
    end
    return rls(sqrt(dzf * k4 / (8 * Cc))), Cc, 0
  end
  local rows, ok = {}, false
  local Qi, C0, a0 = Qf(f0)
  local Qn, Qp2 = Qi, nil
  local f = f0
  local it1
  for i = 1, NMAX0 do
    local Re = o_re(Qi, D, nu)
    f = o_colebrook(Re, eD)
    local Cn, an
    Qn, Cn, an = Qf(f)
    if i == 1 then it1 = { Q1 = Qi, Re = Re, f = f, Q2 = Qn, C1 = Cn, a1 = an } end
    local row = { tostring(i), fmt3(r3(Qi * 1000)), fmt3(Re), fmt3(f), fmt3(r3(Qn * 1000)) }
    if bo.pot then row[6] = fmt3(r3(bo.bpg / Qn)) end
    rows[#rows + 1] = row
    if abs(Qn - Qi) * 1000 < TOL0 or Qn == Qp2 then ok = true; break end
    Qp2 = Qi
    Qi = Qn
  end
  local HB = bo.pot and r3(bo.bpg / Qn) or bo.HB
  local V = r3(Qn / area(D))
  local hv = o_k8(Qn, D)
  local hf, hl = r3(f * LD * hv), r3(K * hv)
  local r = { { "Caudal Q", u3(r3(Qn * 1000), "l/s") }, { "Q", u3(Qn, "m3/s") },
    { "V", u3(V, "m/s") }, { "f", fmt3(f) }, { "e/D", fmt3(eD) },
    { "Re", fmt3(o_re(Qn, D, nu)) }, { "hf", u3(hf, "m") }, { "hL", u3(hl, "m") } }
  if bo.on then
    r[#r + 1] = { "HB bomba", u3(HB, "m") }
    r[#r + 1] = { "dZ + HB", u3(r3(dz + HB), "m") }
  end
  r[#r + 1] = { "Iteraciones", tostring(#rows) }
  local hdr = { "i", "Qi l/s", "Re", "f", "Qi+1" }
  if bo.pot then hdr[6] = "HB m" end
  local res = R(r, { hdr = hdr, rows = rows }, ok and {} or { "Aviso: max. iteraciones" })
  res.memo = function()
    vadd("MEMORIA  Calculo de Q", C_TITLE)
    vsep()
    msec("DATOS")
    vval("dZ = z1 - z2", dz, "m")
    vval("D", D, "m"); vval("L", L, "m"); vval("ks", ks, "m")
    vval("nu", nu, "m2/s"); vval("Suma K", K); vval("c (salida)", c)
    vval("f inicial", f0); vval("g", G0, "m/s2")
    o_memo_bomba(bo, nil)
    if bo.on and not bo.pot then meq("H", "dZ + HB", fv(dz) .. " + " .. fv(bo.HB), dzf, "m") end
    msec("ITERACION 1")
    meq("e/D", "ks/D", fv(ks) .. "/" .. fv(D), eD)
    meq("L/D", nil, fv(L) .. "/" .. fv(D), LD)
    meq("C0", "c + f L/D + SumK", fv(c) .. " + " .. fv(f0) .. "(" .. fv(LD) .. ") + " .. fv(K), C0)
    if bo.pot then
      mline("(dZ + eta P/(gamma Q)) = C 8 Q^2/(g pi^2 D^4)")
      mline(" => a Q^3 - dZ Q - eta P/gamma = 0", C_GRAY)
      meq("a", "8 C0/(g pi^2 D^4)", "8(" .. fv(C0) .. ")/(" .. fv(G0) .. " pi^2 (" .. fv(D) .. ")^4)", a0)
      meq("Q1", nil, "raiz de " .. fv(a0) .. " Q^3 - (" .. fv(dz) .. ") Q - " .. fv(bo.bpg), it1.Q1, "m3/s")
      meq("HB1", "eta P/(gamma Q1)", fv(bo.eta) .. "(" .. fv(bo.P * 1000) .. ")/(" .. fv(gamma_cfg()) ..
          "(" .. fv(it1.Q1) .. "))", r3(bo.bpg / it1.Q1), "m")
    else
      local Hs = bo.on and "(dZ + HB)" or "dZ"
      meq("Q1", "sqrt(" .. Hs .. " g pi^2 D^4/(8 C0))",
          "sqrt(" .. fv(dzf) .. "(" .. fv(G0) .. ")pi^2(" .. fv(D) .. ")^4/(8(" .. fv(C0) .. ")))",
          it1.Q1, "m3/s")
    end
    meq("Re1", "4 Q1/(pi D nu)", "4(" .. fv(it1.Q1) .. ")/(pi(" .. fv(D) .. ")(" .. fv(nu) .. "))", it1.Re)
    mline("1/sqrt(f) = -2 log(e/(3.71 D) + 2.51/(Re sqrt(f)))")
    mline("      = -2 log(" .. fv(eD) .. "/3.71 + 2.51/(" .. fv(it1.Re) .. " sqrt(f)))", C_GRAY)
    mres("f1 (Colebrook)", it1.f)
    meq("C1", "c + f1 L/D + SumK", fv(c) .. " + " .. fv(it1.f) .. "(" .. fv(LD) .. ") + " .. fv(K), it1.C1)
    if bo.pot then
      meq("a", "8 C1/(g pi^2 D^4)", "8(" .. fv(it1.C1) .. ")/(" .. fv(G0) .. " pi^2 (" .. fv(D) .. ")^4)", it1.a1)
      meq("Q2", nil, "raiz de " .. fv(it1.a1) .. " Q^3 - (" .. fv(dz) .. ") Q - " .. fv(bo.bpg), it1.Q2, "m3/s")
    else
      local Hs = bo.on and "(dZ + HB)" or "dZ"
      meq("Q2", "sqrt(" .. Hs .. " g pi^2 D^4/(8 C1))",
          "sqrt(" .. fv(dzf) .. "(" .. fv(G0) .. ")pi^2(" .. fv(D) .. ")^4/(8(" .. fv(it1.C1) .. ")))",
          it1.Q2, "m3/s")
    end
    mline(" |Q2 - Q1| = " .. fv(r3(abs(it1.Q2 - it1.Q1) * 1000)) .. " l/s", C_GRAY)
    msec("ITERACIONES SIGUIENTES")
    mline(" Se repite con Qi+1 hasta |Qi+1 - Qi| < 1E-4 l/s", C_GRAY)
    mline(" Total: " .. #rows .. " iteraciones (F2 TABLA)", C_GRAY)
    msec("RESULTADO")
    mres("Q", r3(Qn * 1000), "l/s")
    meq("V", "Q/A", fv(Qn) .. "/" .. fv(area(D)), V, "m/s")
    meq("V^2/2g", "8 Q^2/(g pi^2 D^4)", nil, hv, "m")
    meq("hf", "f (L/D) V^2/2g", fv(f) .. "(" .. fv(LD) .. ")(" .. fv(hv) .. ")", hf, "m")
    meq("hL", "SumK V^2/2g", fv(K) .. "(" .. fv(hv) .. ")", hl, "m")
    if bo.on then mres("HB", HB, "m") end
  end
  return res
end

local function oc_D()
  local c = (oi.cs == 0) and 1 or 0
  local dz, Q, L = need("dz", "dZ"), rls(need("Q", "Q") / 1000), need("L", "L")
  local ks, nu, K = r3(need("ks", "ks") / 1000), need("nu0", "nu"), val("K") or 0
  local Di = rmm(need("D0", "D inicial") / 1000)
  pos(Q, "Q"); pos(nu, "nu"); pos(Di, "D inicial")
  local bo = o_bomba()
  local HB = bo.pot and r3(bo.bpg / Q) or bo.HB
  local dzf = r3(dz + HB)
  if not (dzf > 0) then herr(bo.on and "dZ + HB debe ser > 0" or "dZ debe ser > 0") end
  local A = r3(8 * Q * Q / (pi * pi * G0 * dzf))
  local D1 = Di
  local rows, ok, Dn, f, Dp2 = {}, false, Di, 0, nil
  local it1
  for i = 1, NMAX0 do
    local eD = r3(ks / Di)
    local Re = o_re(Q, Di, nu)
    f = o_colebrook(Re, eD)
    local LDi = r3(L / Di)
    Dn = rmm((A * (r3(f * LDi) + K + c)) ^ 0.25)
    if i == 1 then it1 = { eD = eD, Re = Re, f = f, LD = LDi, D2 = Dn } end
    rows[#rows + 1] = { tostring(i), fmt3(r3(Di * 1000)), fmt3(eD), fmt3(Re), fmt3(f), fmt3(r3(Dn * 1000)) }
    if abs(Dn - Di) * 1000 < TOL0 or Dn == Dp2 then ok = true; break end
    Dp2 = Di
    Di = Dn
  end
  local r = { { "Diametro D", u3(r3(Dn * 1000), "mm") }, { "V", u3(r3(Q / area(Dn)), "m/s") },
    { "f", fmt3(f) }, { "Re", fmt3(o_re(Q, Dn, nu)) } }
  if bo.on then
    r[#r + 1] = { "HB bomba", u3(HB, "m") }
    r[#r + 1] = { "dZ + HB", u3(dzf, "m") }
  end
  r[#r + 1] = { "Iteraciones", tostring(#rows) }
  local res = R(r, { hdr = { "i", "Di mm", "e/D", "Re", "f", "Di+1" }, rows = rows },
                ok and {} or { "Aviso: max. iteraciones" })
  res.memo = function()
    vadd("MEMORIA  Calculo de D", C_TITLE)
    vsep()
    msec("DATOS")
    vval("dZ = z1 - z2", dz, "m"); vval("Q", Q, "m3/s"); vval("L", L, "m")
    vval("ks", ks, "m"); vval("nu", nu, "m2/s"); vval("Suma K", K)
    vval("c (salida)", c); vval("D inicial", D1, "m"); vval("g", G0, "m/s2")
    o_memo_bomba(bo, Q)
    local Hs = "dZ"
    if bo.on then
      Hs = "H"
      meq("H", "dZ + HB", fv(dz) .. " + " .. fv(HB), dzf, "m")
    end
    msec("CONSTANTE")
    mline(Hs .. " = (c + f L/D + SumK) 8 Q^2/(g pi^2 D^4)", C_GRAY)
    mline(" => D = [A (f L/D + SumK + c)]^(1/4)", C_GRAY)
    meq("A", "8 Q^2/(pi^2 g " .. Hs .. ")", "8(" .. fv(Q) .. ")^2/(pi^2(" .. fv(G0) .. ")(" .. fv(dzf) .. "))", A)
    msec("ITERACION 1  (D1 = " .. fv(D1) .. " m)")
    meq("e/D1", "ks/D1", fv(ks) .. "/" .. fv(D1), it1.eD)
    meq("Re1", "4 Q/(pi D1 nu)", "4(" .. fv(Q) .. ")/(pi(" .. fv(D1) .. ")(" .. fv(nu) .. "))", it1.Re)
    mline("1/sqrt(f) = -2 log(e/(3.71 D) + 2.51/(Re sqrt(f)))")
    mline("      = -2 log(" .. fv(it1.eD) .. "/3.71 + 2.51/(" .. fv(it1.Re) .. " sqrt(f)))", C_GRAY)
    mres("f1 (Colebrook)", it1.f)
    meq("L/D1", nil, fv(L) .. "/" .. fv(D1), it1.LD)
    meq("D2", "[A (f1 L/D1 + SumK + c)]^(1/4)",
        "[" .. fv(A) .. "(" .. fv(it1.f) .. "(" .. fv(it1.LD) .. ") + " .. fv(K) .. " + " .. fv(c) .. ")]^(1/4)",
        it1.D2, "m")
    mline(" |D2 - D1| = " .. fv(r3(abs(it1.D2 - D1) * 1000)) .. " mm", C_GRAY)
    msec("ITERACIONES SIGUIENTES")
    mline(" Se repite con Di+1 hasta |Di+1 - Di| < 1E-4 mm", C_GRAY)
    mline(" Total: " .. #rows .. " iteraciones (F2 TABLA)", C_GRAY)
    msec("RESULTADO")
    mres("D", r3(Dn * 1000), "mm")
    meq("V", "Q/A", fv(Q) .. "/" .. fv(area(Dn)), r3(Q / area(Dn)), "m/s")
  end
  return res
end

-- perdidas con Q conocido (H bomba, H turbina y perdidas totales)
local function o_perd()
  local Q, D, L = rls(need("Q", "Q") / 1000), rmm(need("D", "D") / 1000), need("L", "L")
  local ks, nu, K = r3(need("ks", "ks") / 1000), need("nu0", "nu"), val("K") or 0
  pos(Q, "Q"); pos(D, "D"); pos(nu, "nu")
  local p = { Q = Q, D = D, L = L, ks = ks, nu = nu, K = K }
  p.Re = o_re(Q, D, nu)
  p.eD = r3(ks / D)
  local f, t, w = o_tabla_f(p.Re, p.eD)
  p.f = f
  p.lam = p.Re < 2000
  if not p.lam then
    p.f1 = r3((-2 * log10(p.eD / 3.71 + 2.51 / (p.Re * sqrt(0.05)))) ^ -2)
    p.nit = #t.rows
  end
  p.A = area(D)
  p.V = r3(Q / p.A)
  p.LD = r3(L / D)
  p.hv = o_k8(Q, D)
  p.hf, p.hl = r3(f * p.LD * p.hv), r3(K * p.hv)
  p.hT = r3(p.hf + p.hl)
  p.cs = oi.cs == 0
  p.vs = 0
  if p.cs then p.vs = val("vs") or p.V end
  p.hs = r3(p.vs * p.vs / (2 * G0))
  local r = { { "f", fmt3(f) }, { "Re", fmt3(p.Re) .. " (" .. o_reg(p.Re) .. ")" },
    { "V", u3(p.V, "m/s") }, { "V2/2g", u3(p.hv, "m") }, { "hf", u3(p.hf, "m") },
    { "hL", u3(p.hl, "m") }, { "hT = hf+hL", u3(p.hT, "m") } }
  if p.cs then r[#r + 1] = { "Vs2/2g", u3(p.hs, "m") } end
  return Q, p.hT, p.hs, r, t, w, p
end

local function o_memo_perd(p, titulo, extra)
  vadd("MEMORIA  " .. titulo, C_TITLE)
  vsep()
  msec("DATOS")
  if extra then extra() end
  vval("Q", p.Q, "m3/s"); vval("D", p.D, "m"); vval("L", p.L, "m")
  vval("ks", p.ks, "m"); vval("nu", p.nu, "m2/s"); vval("Suma K", p.K)
  vval("g", G0, "m/s2")
  msec("CALCULOS")
  meq("A", "pi D^2/4", "pi(" .. fv(p.D) .. ")^2/4", p.A, "m2")
  meq("V", "Q/A", fv(p.Q) .. "/" .. fv(p.A), p.V, "m/s")
  meq("Re", "4 Q/(pi D nu)", "4(" .. fv(p.Q) .. ")/(pi(" .. fv(p.D) .. ")(" .. fv(p.nu) .. "))", p.Re)
  meq("e/D", "ks/D", fv(p.ks) .. "/" .. fv(p.D), p.eD)
  if p.lam then
    meq("f", "64/Re", "64/" .. fv(p.Re), p.f)
  else
    msec("f: ITERACION 1 (f0 = 0.05)")
    mline("f1 = [-2 log(e/(3.71 D) + 2.51/(Re sqrt(f0)))]^-2")
    mline("   = [-2 log(" .. fv(p.eD) .. "/3.71 + 2.51/(" .. fv(p.Re) .. " sqrt(5.000E-2)))]^-2", C_GRAY)
    mres("f1", p.f1)
    mline(" Se repite hasta |f1 - f0| < 1E-4: " .. p.nit .. " iteraciones", C_GRAY)
    mline(" (F2 TABLA)", C_GRAY)
    mres("f", p.f)
  end
  meq("V^2/2g", "8 Q^2/(g pi^2 D^4)", nil, p.hv, "m")
  meq("hf", "f (L/D) V^2/2g", fv(p.f) .. "(" .. fv(p.LD) .. ")(" .. fv(p.hv) .. ")", p.hf, "m")
  meq("hL", "SumK V^2/2g", fv(p.K) .. "(" .. fv(p.hv) .. ")", p.hl, "m")
  meq("hT", "hf + hL", fv(p.hf) .. " + " .. fv(p.hl), p.hT, "m")
  if p.cs then meq("Vs^2/2g", nil, "(" .. fv(p.vs) .. ")^2/(2(" .. fv(G0) .. "))", p.hs, "m") end
end

local function oc_HB()
  local Q, hT, hs, r, t, w, p = o_perd()
  local eta, dz = need("eta", "la eficiencia"), need("dz", "dZ")
  pos(eta, "Eficiencia")
  local HB = r3(dz + hs + hT)
  local P = r3(GAM0 * Q * HB / eta)
  local res = R(cat({ { "Altura bomba HB", u3(HB, "m") } }, o_pot(P), r), t, w)
  res.memo = function()
    o_memo_perd(p, "H bomba", function() vval("dZ = z2 - z1", dz, "m"); vval("eta", eta) end)
    msec("BOMBA")
    meq("HB", "dZ + Vs^2/2g + hT", fv(dz) .. " + " .. fv(hs) .. " + " .. fv(hT), HB, "m")
    meq("P", "gamma Q HB/eta", fv(GAM0) .. "(" .. fv(Q) .. ")(" .. fv(HB) .. ")/" .. fv(eta), P, "W")
  end
  return res
end
local function oc_HT()
  local Q, hT, hs, r, t, w, p = o_perd()
  local eta, dz = need("eta", "la eficiencia"), need("dz", "dZ")
  local HT = r3(dz - hs - hT)
  local P = r3(GAM0 * Q * HT * eta)
  local res = R(cat({ { "Altura turbina HTur", u3(HT, "m") } }, o_pot(P), r), t, w)
  res.memo = function()
    o_memo_perd(p, "H turbina", function() vval("dZ = z1 - z2", dz, "m"); vval("eta", eta) end)
    msec("TURBINA")
    meq("HT", "dZ - Vs^2/2g - hT", fv(dz) .. " - " .. fv(hs) .. " - " .. fv(hT), HT, "m")
    meq("P", "gamma Q HT eta", fv(GAM0) .. "(" .. fv(Q) .. ")(" .. fv(HT) .. ")(" .. fv(eta) .. ")", P, "W")
  end
  return res
end
local function oc_hT()
  local Q, hT, hs, r, t, w, p = o_perd()
  local bo = o_bomba()
  local HB = bo.pot and r3(bo.bpg / Q) or bo.HB
  local dZ = r3(hT + hs - HB)
  local lab = bo.on and "dZ = hT+Vs2/2g-HB" or "dZ = hT+Vs2/2g"
  local top = { { lab, u3(dZ, "m") } }
  if bo.on then top[#top + 1] = { "HB bomba", u3(HB, "m") } end
  local res = R(cat(top, r), t, w)
  res.memo = function()
    o_memo_perd(p, "Perdidas totales", nil)
    o_memo_bomba(bo, Q)
    msec("DESNIVEL")
    if bo.on then
      mline(" Energia: dZ + HB = hT + Vs^2/2g", C_GRAY)
      meq("dZ", "hT + Vs^2/2g - HB", fv(hT) .. " + " .. fv(hs) .. " - " .. fv(HB), dZ, "m")
    else
      meq("dZ", "hT + Vs^2/2g", fv(hT) .. " + " .. fv(hs), dZ, "m")
    end
  end
  return res
end

-- calculos individuales
local function Dm() local d = need("D", "D"); pos(d, "D"); return rmm(d / 1000) end
local function Qm() return rls(need("Q", "Q") / 1000) end
local function oi_V() local D = Dm(); return R({ { "V = Q/A", u3(r3(Qm() / area(D)), "m/s") } }) end
local function oi_Q()
  local Q = r3(need("V", "V") * area(Dm()))
  return R({ { "Q = V*A", u3(r3(Q * 1000), "l/s") }, { "Q", u3(Q, "m3/s") } })
end
local function oi_Re()
  local D = Dm()
  local nu = need("nu0", "nu"); pos(nu, "nu")
  local V
  if val("Q") then V = r3(rls(val("Q") / 1000) / area(D))
  elseif val("V") then V = val("V") else herr("Ingresa Q o V") end
  local Re = r3(V * D / nu)
  return R({ { "Reynolds", fmt3(Re) }, { "Regimen", o_reg(Re) }, { "V", u3(V, "m/s") } })
end
local function oi_eD()
  local D = need("D", "D"); pos(D, "D")
  return R({ { "e/D", fmt3(r3(need("ks", "ks") / D)) } })
end
local function oi_f()
  local Re = need("Re", "Re"); pos(Re, "Re")
  local f, t, w = o_tabla_f(r3(Re), r3(need("eD", "e/D")))
  return R({ { "f Colebrook", fmt3(f) }, { "Regimen", o_reg(Re) } }, t, w)
end
local function oi_hf()
  local Q, D, L = Qm(), Dm(), need("L", "L")
  pos(Q, "Q")
  local f = val("f")
  local t, w, r = nil, {}, {}
  if f == nil then
    if val("ks") == nil then herr("Ingresa f o ks") end
    local nu = need("nu0", "nu"); pos(nu, "nu")
    local Re = o_re(Q, D, nu)
    f, t, w = o_tabla_f(Re, r3(r3(val("ks") / 1000) / D))
    r = { { "f", fmt3(f) }, { "Re", fmt3(Re) } }
  end
  return R(cat({ { "hf = fLV2/(2gD)", u3(r3(f * r3(L / D) * o_k8(Q, D)), "m") } }, r), t, w)
end
local function oi_hL()
  local D = Dm()
  return R({ { "hL = K V2/2g", u3(r3((val("K") or 0) * o_k8(Qm(), D)), "m") } })
end
local function oi_K()
  local Q, D = Qm(), Dm(); pos(Q, "Q")
  return R({ { "K = 2g hL/V2", fmt3(r3(need("hl", "hL") / o_k8(Q, D))) } })
end
local function oi_hv()
  local V
  if val("V") then V = val("V")
  elseif val("Q") and val("D") then V = r3(rls(val("Q") / 1000) / area(Dm()))
  else herr("Ingresa V, o Q y D") end
  return R({ { "V2/2g", u3(r3(V * V / (2 * G0)), "m") }, { "V", u3(V, "m/s") } })
end
local function oi_PB()
  local eta = need("eta", "la eficiencia"); pos(eta, "Eficiencia")
  return R(o_pot(GAM0 * Qm() * need("HB", "HB") / eta))
end
local function oi_PT() return R(o_pot(GAM0 * Qm() * need("HTu", "HTur") * need("eta", "la eficiencia"))) end

local function fdz(lab) return NUMF(lab, "m", "dz", FF_ANY) end
local ORIG = {
  { "Calculo de Q", function() return con_bomba({ fcs(), fdz("dZ = z1-z2"), fD(), fL(), fks(), fnu0(), fK(),
      NUMF("f inicial", nil, "f0", FF_POS) }) end, oc_Q },
  { "Calculo de D", function() return con_bomba({ fcs(), fdz("dZ = z1-z2"), fQ(), fL(), fks(), fnu0(), fK(),
      NUMF("D inicial", "mm", "D0", FF_POS) }) end, oc_D },
  { "H bomba", function() return { fcs(), fdz("dZ = z2-z1"), fQ(), fD(), fL(), fks(), fnu0(), fK(),
      fvs(), feta() } end, oc_HB },
  { "H turbina", function() return { fcs(), fdz("dZ = z1-z2"), fQ(), fD(), fL(), fks(), fnu0(), fK(),
      fvs(), feta() } end, oc_HT },
  { "Perdidas totales", function() return con_bomba({ fcs(), fQ(), fD(), fL(), fks(), fnu0(), fK(),
      fvs() }) end, oc_hT },
}
local ORIG_IND = {
  { "V = Q/A", function() return { fQ(), fD() } end, oi_V },
  { "Q = V*A", function() return { NUMF("V", "m/s", "V", FF_POS), fD() } end, oi_Q },
  { "Reynolds", function() return { NUMF("Q (opc)", "l/s", "Q", FF_POS + FF_OPT),
      NUMF("V (opc)", "m/s", "V", FF_POS + FF_OPT), fD(), fnu0() } end, oi_Re },
  { "e/D", function() return { fks(), fD() } end, oi_eD },
  { "f Colebrook", function() return { NUMF("Re", nil, "Re", FF_POS),
      NUMF("e/D", nil, "eD", FF_NONNEG) } end, oi_f },
  { "hf = fLV2/(2gD)", function() return { fQ(), fD(), fL(), NUMF("f (opc)", nil, "f", FF_POS + FF_OPT),
      NUMF("ks (si no f)", "mm", "ks", FF_NONNEG + FF_OPT), fnu0() } end, oi_hf },
  { "hL = K V2/2g", function() return { fQ(), fD(), fK() } end, oi_hL },
  { "K = 2g hL/V2", function() return { NUMF("hL", "m", "hl", FF_POS), fQ(), fD() } end, oi_K },
  { "V2/2g", function() return { NUMF("V (opc)", "m/s", "V", FF_POS + FF_OPT),
      NUMF("Q (opc)", "l/s", "Q", FF_POS + FF_OPT), NUMF("D (opc)", "mm", "D", FF_POS + FF_OPT) } end, oi_hv },
  { "Potencia bomba", function() return { fQ(), NUMF("HB", "m", "HB", FF_ANY), feta() } end, oi_PB },
  { "Potencia turbina", function() return { fQ(), NUMF("HTur", "m", "HTu", FF_ANY), feta() } end, oi_PT },
}
O.ORIG, O.ORIG_IND = ORIG, ORIG_IND

-- Calcula el problema idx (1..5) o el individual idx (ind = true) con los
-- datos de oi. -> res | nil, texto de error
function O.compute(idx, ind)
  local e = (ind and ORIG_IND or ORIG)[idx]
  if not e then return nil, "Opcion invalida" end
  local ok, r = pcall(e[3])
  if not ok then return nil, tostring(r) end
  r.titulo = e[1]
  return r
end

-- ------------------------------------------------------------------
-- Resultado: resumen, memoria, tabla y filas
-- ------------------------------------------------------------------
local function show_sum(res)
  W.view_clear()
  vadd("RESULTADO  " .. res.titulo, C_TITLE)
  vsep()
  for _, row in ipairs(res.r) do
    local line = " " .. row[1]:sub(1, 18)
    line = line .. string.rep(" ", 19 - #line) .. "= " .. row[2]
    vadd(line, C_FG)
  end
  for _, w in ipairs(res.w or {}) do vadd(" " .. w, U.C_WARN) end
  if res.t then vadd(" F2 TABLA: " .. #res.t.rows .. " iteraciones", C_GRAY) end
end

-- tabla adaptable: columnas del ancho del dato mas largo; si no cabe en 40
-- columnas, cada fila ocupa dos lineas (y F3 FILAS muestra una por pantalla)
local function show_table(res)
  local t = res.t
  W.view_clear()
  vadd("TABLA  " .. res.titulo, C_TITLE)
  vsep()
  local nc = #t.hdr
  local wd = {}
  for k = 1, nc do
    wd[k] = #t.hdr[k]
    for _, row in ipairs(t.rows) do if #(row[k] or "") > wd[k] then wd[k] = #row[k] end end
  end
  local total = 0
  for k = 1, nc do total = total + wd[k] + 1 end
  local function line(cells, k0, k1)
    local s = ""
    for k = k0, k1 do
      local c = cells[k] or ""
      s = s .. string.rep(" ", wd[k] - #c) .. c .. " "
    end
    return s
  end
  if total <= U.UI_COLS then
    vadd(line(t.hdr, 1, nc), C_TITLE)
    for _, row in ipairs(t.rows) do vadd(line(row, 1, nc), C_FG) end
  else
    local half, acc = nc, 0
    for k = 1, nc do
      acc = acc + wd[k] + 1
      if acc > U.UI_COLS then half = k - 1; break end
    end
    vadd(line(t.hdr, 1, half), C_TITLE)
    vadd("   " .. line(t.hdr, half + 1, nc), C_TITLE)
    for _, row in ipairs(t.rows) do
      vadd(line(row, 1, half), C_FG)
      vadd("   " .. line(row, half + 1, nc), C_GRAY)
    end
  end
end

local fila_cur = 0
local function show_rows(res)
  local t = res.t
  local n = #t.rows
  while not U.quit do
    for i = 0, n - 1 do
      local row = t.rows[i + 1]
      local s = ""
      for k = 1, #row do s = s .. row[k] .. ((k < #row) and "  " or "") end
      W.list_line[i] = s:sub(1, U.UI_COLS)
    end
    local r, k = W.list_pick("FILAS  " .. res.titulo, "ENTER: ver la fila completa", n, fila_cur, nil)
    if r < 0 or k ~= K_ENTER then return end
    fila_cur = r
    W.view_clear()
    vadd(string.format("FILA %d / %d  %s", r + 1, n, res.titulo), C_TITLE)
    vsep()
    local row = t.rows[r + 1]
    for kk = 1, #t.hdr do
      local line = " " .. t.hdr[kk]
      line = line .. string.rep(" ", 10 - #line) .. "= " .. (row[kk] or "")
      vadd(line, C_FG)
    end
    W.view_run("FILAS", { "", "", "", "", "VOLVER" })
  end
end

local function results(res)
  local view = 0      -- 0 resumen, 1 memoria, 2 tabla
  fila_cur = 0
  while not U.quit do
    if view == 1 and res.memo then
      W.view_clear(); res.memo()
    elseif view == 2 and res.t then
      show_table(res)
    else
      view = 0; show_sum(res)
    end
    local fk = { view == 1 and "RESUMEN" or (res.memo and "MEMORIA" or ""),
                 res.t and (view == 2 and "RESUMEN" or "TABLA") or "",
                 res.t and "FILAS" or "", "", "VOLVER" }
    local k = W.view_run(res.titulo:upper(), fk)
    if k == K_F1 and res.memo then view = (view == 1) and 0 or 1
    elseif k == K_F2 and res.t then view = (view == 2) and 0 or 2
    elseif k == K_F3 and res.t then show_rows(res)
    elseif k == K_MODE then require("scr.screens").scr_settings()
    else return end
  end
end

-- ------------------------------------------------------------------
-- Formularios y menus
-- ------------------------------------------------------------------
local fcur = {}
local function run_form(idx, ind)
  local e = (ind and ORIG_IND or ORIG)[idx]
  local key = (ind and "i" or "p") .. idx
  local ff = e[2]()
  local fm = { title = e[1]:upper(), f = ff, n = #ff, cur = fcur[key] or 0,
               fk = { "", "", "", "AJUSTES", "CALC" },
               hint = "3 decimales en cada paso (como a mano)" }
  while not U.quit do
    local k = W.form_run(fm)
    if k == K_QUIT or k == K_CLEAR then break end
    if k == U.K_F4 or k == K_MODE then
      require("scr.screens").scr_settings()
    elseif k == K_F5 or k == K_ENTER then
      if W.form_check(fm) then
        local res, err = O.compute(idx, ind)
        if not res then
          fm.msg = err
          fm.msg_color = C_ERR
        else
          fm.msg = nil
          results(res)
        end
      end
    end
  end
  fcur[key] = fm.cur
end

local ind_menu = { title = "CALCULOS INDIVIDUALES", cur = 0, items = {} }
for i, e in ipairs(ORIG_IND) do ind_menu.items[i] = e[1] end
ind_menu.n = #ind_menu.items

local orig_menu = { title = "MI PROGRAMA ORIGINAL", cur = 0, items = {} }
for i, e in ipairs(ORIG) do orig_menu.items[i] = e[1] end
orig_menu.items[#ORIG + 1] = "Calculos individuales"
orig_menu.n = #orig_menu.items

function O.reset_cursors()
  ind_menu.cur, orig_menu.cur, fila_cur = 0, 0, 0
  fcur = {}
end

function O.scr_orig()
  while not U.quit do
    local r = W.menu_run(orig_menu)
    if r == W.MENU_BACK or r == W.MENU_QUIT then return end
    if r == W.MENU_MODE then
      require("scr.screens").scr_settings()
    elseif r < #ORIG then
      run_form(r + 1, false)
    else
      while not U.quit do
        local q = W.menu_run(ind_menu)
        if q == W.MENU_BACK or q == W.MENU_QUIT then break end
        if q == W.MENU_MODE then require("scr.screens").scr_settings()
        else run_form(q + 1, true) end
      end
    end
  end
end

return O
