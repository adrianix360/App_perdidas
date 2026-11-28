--[[
numfmt.lua - Formato de numeros para la pantalla (puerto 1:1 de src/ui/numfmt.c).
Muestra hasta `dec` decimales sin pasar de 7 cifras significativas y quita los
ceros finales. Notacion cientifica (6 cifras) si |x| >= 1e7 o 0 < |x| < 1e-4.
Ejemplos con dec = 6: 17.96984 | 455180.6 | 0.01349 | 1.5E-6

API PUBLICA
  fmt_real(x, dec) -> string      (NaN o infinito: "ERR")
  fmt_int(v) -> string            (entero)
]]

local N = {}
local R3 = require("core.round3")
local Hy = require("core.hydro")      -- Hy.R3on(): ajuste "Redondeo a mano"

local floor, format = math.floor, string.format
local SIG_MAX = 7

local function fmt_int(v)
    return format("%d", v)
end
N.fmt_int = fmt_int

-- Escribe u con `nd` decimales implicitos y quita ceros finales
local function put_scaled(u, nd)
    local s = format("%.0f", u)
    while #s <= nd do
        s = "0" .. s
    end
    local ip = s:sub(1, #s - nd)
    if nd > 0 then
        local fp = s:sub(#s - nd + 1):gsub("0+$", "")
        if fp ~= "" then
            return ip .. "." .. fp
        end
    end
    return ip
end

local function p10(e)
    local r = 1
    while e > 0 do r = r * 10; e = e - 1 end
    while e < 0 do r = r / 10; e = e + 1 end
    return r
end

-- notacion cientifica: m.mmmmmE+ee con hasta min(dec, 5) decimales
local function sci(a, dec)
    local e = 0
    while a >= 10 do a = a / 10; e = e + 1 end
    while a < 1 do a = a * 10; e = e - 1 end
    local nd = dec < SIG_MAX - 2 and dec or (SIG_MAX - 2)
    local u = floor(a * p10(nd) + 0.5)
    if u >= floor(p10(nd + 1)) then -- 9.9999995 -> 10.0
        u = floor(u / 10)
        e = e + 1
    end
    return put_scaled(u, nd) .. "E" .. fmt_int(e)
end

function N.fmt_real(x, dec)
    if Hy.R3on() then return R3.fmt3(x) end      -- 3 decimales (Modificaciones JV)
    local pre = ""
    if not (x == x) or x - x ~= 0 then
        return "ERR"
    end
    if x < 0 then
        pre = "-"
        x = -x
    end
    if x == 0 then
        return pre .. "0"
    end
    local a = x
    if a >= 1e7 or a < 1e-4 then
        return pre .. sci(a, dec)
    end
    local intd = 1
    while intd < SIG_MAX and a >= p10(intd) do
        intd = intd + 1
    end
    local nd = SIG_MAX - intd
    if nd > dec then nd = dec end
    if a < 1 then -- 0.0xyz: cuenta los ceros
        local z = 0
        local t = a
        while t < 0.1 and z < 6 do t = t * 10; z = z + 1 end
        nd = SIG_MAX + z
        if nd > dec then nd = dec end
    end
    local u = floor(a * p10(nd) + 0.5)
    if nd == 0 and u >= 10000000 then -- 9999999.6 -> 1E7
        return pre .. sci(x, dec)
    end
    return pre .. put_scaled(u, nd)
end

return N
