--[[
tanks.lua - Problema de los tres tanques (2 a 4 tanques unidos en un nudo).

Metodo (igual al de la solucion a mano del curso):
  1. Se supone la carga piezometrica del nudo Z_J.
  2. En cada tramo H_i = Z_i - Z_J; con |H_i| se obtiene |Q_i| como en el tipo B
     (Colebrook-White u otro metodo de f; si el f es dato, Q = sqrt(H/M)).
     Q_i > 0: el agua va del tanque i al nudo; Q_i < 0: del nudo al tanque.
  3. Balance en el nudo: dQ = sum Q_i - Q_T (Q_T = caudal que sale del nudo).
  4. Ajuste: dZ = 2 dQ / sum(|Q_i| / |H_i|)   (Newton con Q ~ H^0.5)
     Z_J nuevo = Z_J + dZ. Se repite hasta que |dZ| <= tol (o |dQ| <= 0,001 l/s
     con |dZ| <= 1 mm).
  Proteccion: si el paso de Newton cae fuera del intervalo donde ya se sabe
  que esta la raiz (F cambia de signo), se usa el punto medio (biseccion);
  despues de 20 vueltas se alterna con biseccion para asegurar la convergencia.

API
  TK.TK_MAX (4), TK.IT_MAX (60)
  TK.tanks_flows(t, Z, c) -> err, Q[], h[], st[]     caudales con Z_J = Z
  TK.tanks_solve(t, c, r) -> err
    t = { n = 2..4, Z = {Z_1..Z_n} (m), pipe = {H.new_pipe(...) x n},
          QT = caudal que sale del nudo (m3/s, puede ser 0 o negativo),
          ZJ0 = Z_J inicial (nil: promedio de los Z_i) }
    r: ZJ, Q[i], h[i], st[i] (estado del tubo, H.hydro_pipe_state), it, dQ,
       rows[k] = { ZJ, h = {}, Q = {}, sQH, dQ, dZ, bis }   (k = 1..it)
]]

local H = require("core.hydro")

local TK = {}
TK.TK_MAX = 4
TK.IT_MAX = 60
local abs, sqrt = math.abs, math.sqrt

-- Caudal de cada tramo con la carga del nudo Z
function TK.tanks_flows(t, Z, c)
  local Q, h, st = {}, {}, {}
  for i = 1, t.n do
    local hi = t.Z[i] - Z
    h[i] = hi
    if abs(hi) <= 1e-12 then
      Q[i] = 0
      st[i] = nil
    else
      local r = {}
      local e = H.hydro_qmax(t.pipe[i], abs(hi), c, r, nil)
      if e ~= 0 then return e end
      Q[i] = (hi > 0) and r.st.Q or -r.st.Q
      st[i] = r.st
    end
  end
  return H.H_OK, Q, h, st
end

function TK.tanks_solve(t, c, r)
  local n = t.n
  if not (n >= 2 and n <= TK.TK_MAX) then return H.H_ERR_ARG end
  local zmin, zmax = t.Z[1], t.Z[1]
  local zsum = 0
  for i = 1, n do
    local e = H.hydro_check_pipe(t.pipe[i], c)
    if e ~= 0 then return e end
    if t.Z[i] < zmin then zmin = t.Z[i] end
    if t.Z[i] > zmax then zmax = t.Z[i] end
    zsum = zsum + t.Z[i]
  end
  local QT = t.QT or 0
  if zmax - zmin <= 0 and QT == 0 then return H.H_ERR_NOFLOW end
  local Z = t.ZJ0 or zsum / n
  -- evita arrancar justo en el nivel de un tanque (Q/H indefinido)
  local span = (zmax - zmin > 0) and (zmax - zmin) or 1
  for i = 1, n do
    if abs(Z - t.Z[i]) < 1e-9 * span then Z = Z + 1e-3 * span end
  end
  local lo, hi = nil, nil     -- la raiz esta en (lo, hi)
  r.rows = {}
  r.it = 0
  for it = 1, TK.IT_MAX do
    local e, Q, h, st = TK.tanks_flows(t, Z, c)
    if e ~= 0 then return e end
    local sQ, sQH = 0, 0
    for i = 1, n do
      sQ = sQ + Q[i]
      if abs(h[i]) > 1e-12 then sQH = sQH + abs(Q[i]) / abs(h[i]) end
    end
    local F = sQ - QT
    local row = { ZJ = Z, h = h, Q = Q, sQH = sQH, dQ = F, dZ = 0, bis = false }
    r.rows[it] = row
    r.it = it
    r.ZJ, r.Q, r.h, r.st, r.dQ = Z, Q, h, st, F
    if F > 0 then lo = Z elseif F < 0 then hi = Z end
    if F == 0 then return H.H_OK end
    if not (sQH > 0) then return H.H_ERR_NOROOT end
    local dZ = 2 * F / sQH
    local Zn = Z + dZ
    local outside = (lo and Zn <= lo) or (hi and Zn >= hi)
    if lo and hi and (outside or (it > 20 and it % 2 == 1)) then
      Zn = 0.5 * (lo + hi)
      dZ = Zn - Z
      row.bis = true
    end
    row.dZ = dZ
    -- converge: paso menor que la tolerancia, o balance < 0,001 l/s con
    -- paso < 1 mm (el Q de cada tubo trae el redondeo de su propia iteracion)
    if abs(dZ) <= c.tol or (abs(F) <= 1e-6 and abs(dZ) <= 1e-3) then
      return H.H_OK
    end
    Z = Zn
  end
  return H.H_ERR_NOCONV
end

return TK
