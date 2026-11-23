-- texts.lua - Textos de advertencias (port de texts.c). ASCII, 40 columnas.
local nf = require("ui.numfmt")
local T = {}

-- Mascaras de advertencia (mismos valores que hydro.h)
T.W_LAMINAR, T.W_TRANSITION, T.W_KSD_RANGE, T.W_V_HIGH, T.W_V_LOW, T.W_HM_HIGH,
  T.W_P_NEG, T.W_FALLBACK, T.W_LOCAL_SMALL, T.W_SJ_RANGE, T.W_CAVIT, T.W_KS_NEG =
  0x0001, 0x0002, 0x0004, 0x0008, 0x0010, 0x0020, 0x0040, 0x0080, 0x0100,
  0x0200, 0x0400, 0x0800

local function has(w, m) return math.floor(w / m) % 2 == 1 end
T.has_warn = has

-- Devuelve una lista (a lo sumo max, def. 10) de lineas de <= 40 caracteres.
-- c: tabla hydro_cfg (re_lam, v_max, v_min, hm_ratio, ld_limit).
function T.warn_texts(warn, c, dec, max)
  local out = {}
  max = max or 10
  local function add(a, b, cc)
    if #out < max then out[#out + 1] = (a .. (b or "") .. (cc or "")):sub(1, 40) end
  end
  local r = nf.fmt_real
  if has(warn, T.W_FALLBACK) then
    add("! Iteracion del curso no convergio:")
    add("  se resolvio por biseccion")
  end
  if has(warn, T.W_LAMINAR) then add("! Re < ", r(c.re_lam, 0), ": laminar, f = 64/Re") end
  if has(warn, T.W_TRANSITION) then add("! Re en transicion: resultado indicativo") end
  if has(warn, T.W_KSD_RANGE) then add("! ks/D > 0.05: fuera de Colebrook-White") end
  if has(warn, T.W_SJ_RANGE) then add("! Fuera del rango de Swamee-Jain") end
  if has(warn, T.W_V_HIGH) then add("! v > ", r(c.v_max, 2), " m/s: velocidad alta") end
  if has(warn, T.W_V_LOW) then add("! v < ", r(c.v_min, 2), " m/s: velocidad baja") end
  if has(warn, T.W_HM_HIGH) then
    add("! hm > ", r(100 * c.hm_ratio, 0), "% hf: perdidas locales altas")
  end
  if has(warn, T.W_LOCAL_SMALL) then
    add("! L/D > ", r(c.ld_limit, 0), ": locales despreciables")
  end
  if has(warn, T.W_P_NEG) then add("! Presion manometrica negativa") end
  if has(warn, T.W_CAVIT) then add("! p/gamma < -10.3 m: imposible") end
  if has(warn, T.W_KS_NEG) then add("! ks negativo: datos inconsistentes") end
  return out
end

return T
