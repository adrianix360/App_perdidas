--[[
expr.lua - Evaluador de expresiones numericas de los campos (puerto 1:1 de
src/ui/expr.c). Gramatica:
   expr   := term { (+|-) term }
   term   := unary { (*|/) unary | '(' ... implicito }
   unary  := (+|-) unary | power
   power  := primary [ ^ unary ]          (asociativo a la derecha)
   primary:= numero | ( expr )
Acepta numeros (12, 0.5, .5, 1.5E-6), multiplicacion implicita antes de un
parentesis (4(0.2) = 0.8). Extra Nspire: acepta el signo menos U+2212 como '-'
y la 'E' pequena U+1D07 (tecla EE) como exponente, ademas de 'E' y 'e'.

API PUBLICA
  Constantes: EXPR_OK EXPR_EMPTY EXPR_SYNTAX EXPR_DIV0 EXPR_RANGE EXPR_DEPTH EXPR_COUNT
  expr_eval(str) -> err, valor        (valor solo si err == EXPR_OK)
  expr_err_text(err) -> string
]]

local X = {}

X.EXPR_OK, X.EXPR_EMPTY, X.EXPR_SYNTAX, X.EXPR_DIV0 = 0, 1, 2, 3
X.EXPR_RANGE, X.EXPR_DEPTH, X.EXPR_COUNT = 4, 5, 6
local EXPR_OK, EXPR_EMPTY, EXPR_SYNTAX, EXPR_DIV0 = 0, 1, 2, 3
local EXPR_RANGE, EXPR_DEPTH, EXPR_COUNT = 4, 5, 6

local EXPR_MAX_DEPTH = 12

local sub = string.sub

local p_expr, p_unary

-- s = { str, pos, err, depth }
local function cur(s)
    return sub(s.str, s.pos, s.pos)
end

local function skip(s)
    while sub(s.str, s.pos, s.pos) == " " do
        s.pos = s.pos + 1
    end
end

local function isdigit(c)
    return c ~= "" and c >= "0" and c <= "9"
end

local function p_number(s)
    local v = 0
    local digits, e, es, edig = 0, 0, 1, 0

    while isdigit(cur(s)) do
        v = v * 10 + (cur(s) - 0)
        s.pos = s.pos + 1
        digits = digits + 1
    end
    if cur(s) == "." then
        s.pos = s.pos + 1
        local scale = 1
        while isdigit(cur(s)) do
            scale = scale / 10
            v = v + scale * (cur(s) - 0)
            s.pos = s.pos + 1
            digits = digits + 1
        end
    end
    if digits == 0 then
        s.err = EXPR_SYNTAX
        return 0
    end
    local c = cur(s)
    if c == "E" or c == "e" then
        s.pos = s.pos + 1
        c = cur(s)
        if c == "-" then
            es = -1
            s.pos = s.pos + 1
        elseif c == "+" then
            s.pos = s.pos + 1
        end
        while isdigit(cur(s)) do
            if e < 100 then
                e = e * 10 + (cur(s) - 0)
            end
            s.pos = s.pos + 1
            edig = edig + 1
        end
        if edig == 0 then
            s.err = EXPR_SYNTAX
            return 0
        end
        while e > 0 do
            e = e - 1
            if es > 0 then v = v * 10 else v = v / 10 end
        end
    end
    return v
end

local function p_primary(s)
    skip(s)
    if cur(s) == "(" then
        s.depth = s.depth + 1
        if s.depth > EXPR_MAX_DEPTH then
            s.err = EXPR_DEPTH
            return 0
        end
        s.pos = s.pos + 1
        local v = p_expr(s)
        if s.err ~= 0 then return 0 end
        skip(s)
        if cur(s) ~= ")" then
            s.err = EXPR_SYNTAX
            return 0
        end
        s.pos = s.pos + 1
        s.depth = s.depth - 1
        return v
    end
    return p_number(s)
end

local function p_power(s)
    local b = p_primary(s)
    if s.err ~= 0 then return 0 end
    skip(s)
    if cur(s) == "^" then
        s.depth = s.depth + 1
        if s.depth > EXPR_MAX_DEPTH then
            s.err = EXPR_DEPTH
            return 0
        end
        s.pos = s.pos + 1
        local x = p_unary(s)
        s.depth = s.depth - 1
        if s.err ~= 0 then return 0 end
        if b == 0 and x < 0 then
            s.err = EXPR_DIV0
            return 0
        end
        b = b ^ x
    end
    return b
end

p_unary = function(s)
    skip(s)
    local c = cur(s)
    if c == "-" or c == "+" then
        local neg = (c == "-")
        s.depth = s.depth + 1
        if s.depth > EXPR_MAX_DEPTH then
            s.err = EXPR_DEPTH
            return 0
        end
        s.pos = s.pos + 1
        local v = p_unary(s)
        s.depth = s.depth - 1
        return neg and -v or v
    end
    return p_power(s)
end

local function p_term(s)
    local v = p_unary(s)
    while s.err == 0 do
        skip(s)
        local op = cur(s)
        if op == "*" or op == "/" then
            s.pos = s.pos + 1
        elseif op == "(" then
            op = "*" -- multiplicacion implicita
        else
            break
        end
        local r = p_unary(s)
        if s.err ~= 0 then return 0 end
        if op == "/" then
            if r == 0 then
                s.err = EXPR_DIV0
                return 0
            end
            v = v / r
        else
            v = v * r
        end
    end
    return v
end

p_expr = function(s)
    local v = p_term(s)
    while s.err == 0 do
        skip(s)
        local op = cur(s)
        if op ~= "+" and op ~= "-" then break end
        s.pos = s.pos + 1
        local r = p_term(s)
        if s.err ~= 0 then return 0 end
        if op == "+" then v = v + r else v = v - r end
    end
    return v
end

-- -> err, valor
function X.expr_eval(str)
    str = tostring(str or "")
    -- Nspire: U+2212 (menos) -> '-', U+1D07 (tecla EE) -> 'E'
    str = str:gsub("\226\136\146", "-"):gsub("\225\180\135", "E")
    local s = { str = str, pos = 1, err = EXPR_OK, depth = 0 }
    skip(s)
    if cur(s) == "" then return EXPR_EMPTY end
    local v = p_expr(s)
    if s.err ~= 0 then return s.err end
    skip(s)
    if cur(s) ~= "" then return EXPR_SYNTAX end
    if not (v == v and v - v == 0) then return EXPR_RANGE end
    return EXPR_OK, v
end

local err_text = { [0] = "OK", "Campo vacio", "Error de sintaxis",
    "Division entre cero", "Resultado fuera de rango",
    "Demasiados parentesis" }

function X.expr_err_text(e)
    if e >= 0 and e < EXPR_COUNT then return err_text[e] end
    return "Error"
end

return X
