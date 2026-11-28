-- round3.lua - Redondeo "como a mano" de las Modificaciones JV (tuberias_2.lua).
--   r3(x):  |x| >= 1 con 3 decimales fijos; |x| < 1 en cientifica con 3
--           decimales (1.116E-2, 1.020E-6).
--   rmm(x): resolucion 1E-6 en SI = 0,001 mm y 0,001 l/s (D en m, Q en m3/s).
--   fmt3(x): texto con ese mismo formato (3 decimales; cientifica si |x| < 1).
-- API: R3.r3, R3.rmm, R3.rls (= rmm), R3.fmt3
local R3 = {}
local floor, abs = math.floor, math.abs
local function log10(x) return math.log(x) / math.log(10) end

function R3.r3(x)
  if type(x) ~= "number" or x ~= x or x == 0 or x == math.huge or x == -math.huge then
    return x
  end
  local s = (x < 0) and -1 or 1
  local a = abs(x)
  if a >= 1 then return s * floor(a * 1000 + 0.5) / 1000 end
  local e = floor(log10(a))
  local m = floor(a / 10 ^ e * 1000 + 0.5) / 1000
  if m >= 10 then m = m / 10; e = e + 1 end
  if m < 1 then m = m * 10; e = e - 1 end
  local r = s * m * 10 ^ e
  if abs(r) >= 1 then return s * floor(abs(r) * 1000 + 0.5) / 1000 end
  return r
end

function R3.rmm(x)
  if type(x) ~= "number" or x ~= x then return x end
  return floor(x * 1e6 + 0.5) / 1e6
end
R3.rls = R3.rmm

function R3.fmt3(x)
  if x == nil then return "0.000" end
  if x ~= x or x == math.huge or x == -math.huge then return "ERR" end
  x = R3.r3(x)
  if x == 0 then return "0.000" end
  local a = abs(x)
  if a >= 1 then return string.format("%.3f", x) end
  local e = floor(log10(a))
  local m = floor(a / 10 ^ e * 1000 + 0.5) / 1000
  if m >= 10 then m = m / 10; e = e + 1 end
  if m < 1 then m = m * 10; e = e - 1 end
  if e >= 0 then return string.format("%.3f", x) end
  return ((x < 0) and "-" or "") .. string.format("%.3f", m) .. "E" .. string.format("%d", e)
end

return R3
