-- test_perdidas.lua - Pantallas de PERDIDAS (F3): menus, tipos de problema A..I,
-- sistemas serie/paralelo, calcular f, biblioteca, ajustes, Mis casos y
-- persistencia. Se maneja solo con teclas (como el usuario) sobre mock_nspire.
-- Port de los escenarios de PERDIDAS de ti84/tests/test_nav.c.
local mock = dofile("tests/mock_nspire.lua")
local env = mock.load_app("build/app.lua")

local fails, checks = 0, 0
local debug_dump                       -- definida mas abajo
local function check(cond, msg)
  checks = checks + 1
  if not cond then
    fails = fails + 1
    print("FALLO: " .. tostring(msg))
    if os.getenv("TDEBUG") and debug_dump then debug_dump() end
  end
  return cond
end

local rt = env.require("ui.rt")
local U = env.require("ui.ui")
local W = env.require("ui.widgets")
local H = env.require("core.hydro")
local diams = env.require("data.diams")
local ex = env.require("data.examples")
local lib = env.require("data.lib")
local Pipe = env.require("scr.scr_pipe")
local Cases = env.require("scr.cases")
local Store = env.require("scr.store")

os.execute("mkdir build\\png 2>nul")

-- ------------------------------------------------------------------ ayudas
local function keys(...) for _, k in ipairs({ ... }) do mock.key(k) end end
local function typed(s) for c in s:gmatch(".") do mock.key(c) end end
local function TE(s) typed(s); mock.key("enter") end
local function F(i)
  mock.paint()
  mock.click(math.floor((i - 0.5) * mock.W / 5), mock.H - 5)
end
local function downs(n) for _ = 1, n do mock.key("down") end end

-- texto en pantalla (filas unidas por y)
local function rows()
  mock.paint()
  local by, ys = {}, {}
  for _, t in ipairs(mock.screen_text()) do
    if not by[t.y] then by[t.y] = {}; ys[#ys + 1] = t.y end
    by[t.y][#by[t.y] + 1] = t.text
  end
  table.sort(ys)
  local out = {}
  for i, y in ipairs(ys) do out[i] = table.concat(by[y], " ") end
  return out
end
local function shown(s)
  mock.paint()
  return mock.has_text(s) and true or false
end
local function dump()
  for _, r in ipairs(rows()) do print("   | " .. r) end
end
debug_dump = function()
  dump()
  for i = 1, math.min(W.view_n, 14) do print("   v| " .. W.view_line[i]) end
end
-- texto del visor (todas las lineas, no solo la pagina)
local function view()
  local t = {}
  for i = 1, W.view_n do t[i] = W.view_line[i] end
  return table.concat(t, "\n")
end
local function vhas(s) return view():find(s, 1, true) ~= nil end
local function ok_app(msg)
  if rt.fatal then
    check(false, msg .. ": error de Lua: " .. tostring(rt.fatal))
    return false
  end
  return true
end
local function inside(label)
  for _, t in ipairs(mock.screen_text()) do
    if not (t.x >= 0 and t.x + t.w <= mock.W + 2 and t.y >= 0 and t.y + t.h <= mock.H + 2) then
      check(false, label .. ": texto fuera de pantalla '" .. t.text .. "'")
      return
    end
  end
end
local function png(name)
  mock.paint()
  mock.dump_ops("build/png/" .. name .. ".json")
  local r = os.execute('python -I tools/render_png.py build/png/' .. name .. '.json build/png/' ..
    name .. '.png --scale 2')
  check(r == 0 or r == true, "render_png " .. name)
end

-- Reinicia la app (menu inicial) y entra a PERDIDAS (menu principal)
local Sc = env.require("scr.screens")
local function start_perdidas()
  rt.start(rt.app_main)
  W.APP_NAME = "PERDIDAS"
  Sc.reset_menus()
  Pipe.pin_reset()
  env.require("scr.scr_lib").reset_cursors()
  keys("1")
end
local function start_root() rt.start(rt.app_main) end
-- Vuelve al menu inicial desde donde este (hasta 12 ESC)
local function back_root()
  for _ = 1, 12 do
    if shown("PERDIDAS / FLUJOS") then return true end
    if shown("Desea salir") or shown("Datos guardados") or shown("Modulo") then
      keys("enter")
    else
      keys("esc")
    end
  end
  return shown("PERDIDAS / FLUJOS")
end

-- ================================================================== 1. menus
do
  start_root()
  check(shown("PERDIDAS / FLUJOS"), "menu inicial")
  keys("1")
  check(shown("MENU PRINCIPAL"), "PERDIDAS: menu principal")
  inside("menu principal")
  png("perd_menu")
  -- 1 Tuberia simple: sus 8 hojas
  local pipe_titles = { "PERDIDAS DADO Q", "CAUDAL MAXIMO", "DIAMETRO DE DISENO", "BOMBA O TURBINA",
    "VALVULA DE CONTROL", "CALIBRAR RUGOSIDAD", "DARCY-W. vs HAZEN-W.", "FACTOR DE FRICCION f" }
  keys("1")
  check(shown("TUBERIA SIMPLE"), "menu tuberia simple")
  for i = 1, 8 do
    keys(tostring(i))
    check(shown(pipe_titles[i]), "tipo " .. i .. ": " .. pipe_titles[i])
    inside("form " .. i)
    keys("esc")
    check(shown("TUBERIA SIMPLE"), "tipo " .. i .. ": ESC vuelve al menu")
  end
  keys("menu")                                   -- Ajustes desde cualquier menu
  check(shown("AJUSTES"), "tuberia: menu abre Ajustes")
  keys("esc")
  keys("esc")
  check(shown("MENU PRINCIPAL"), "vuelve al principal")
  -- 2 Sistemas, 3 Calcular f
  keys("2"); check(shown("SISTEMA SERIE/PARALELO (G)"), "sistemas"); keys("esc")
  keys("3"); check(shown("FACTOR DE FRICCION f"), "calcular f"); keys("esc")
  -- 4 Flujos externos: abre FLUJOS (o avisa si el modulo no esta)
  keys("4")
  if shown("Elija FLUJOS") then
    keys("enter")
  else
    check(W.APP_NAME == "FLUJOS" and ok_app("flujos") and shown("FLUJOS"), "flujos externos abre FLUJOS")
    keys("esc")
    for _ = 1, 3 do                -- el menu de FLUJOS puede pedir confirmar la salida
      if shown("MENU PRINCIPAL") then break end
      keys("enter")
    end
    check(W.APP_NAME == "PERDIDAS", "vuelve de FLUJOS como PERDIDAS")
  end
  check(shown("MENU PRINCIPAL"), "tras Flujos externos")
  keys("5"); check(shown("ESTATICA Y DINAMICA") and shown("Estatica de fluidos") and shown("Dinamica de fluidos"), "estatica y dinamica: submenu"); keys("esc")
  -- 5 Estatica y dinamica, 6 Biblioteca
  keys("6")
  check(shown("BIBLIOTECA"), "biblioteca")
  for i = 1, 4 do keys(tostring(i)); keys("esc"); keys("esc") end   -- 4 hojas (algunas con un ESC extra)
  keys("esc")
  -- 6 Mis casos vacio
  keys("7"); check(shown("MIS CASOS") and shown("(vacio)"), "mis casos vacio"); keys("esc")
  -- 7 Ajustes
  keys("8"); check(shown("AJUSTES"), "ajustes"); keys("esc")
  -- 8 Ayuda: 8 temas + casos del curso + acerca de
  keys("9")
  check(shown("AYUDA"), "ayuda")
  local helps = 0
  for i = 1, 8 do
    start_perdidas(); keys("9")
    if i < 9 then keys(tostring(i)) end
    if check(ok_app("ayuda " .. i) and shown("AYUDA") and W.view_n > 3, "ayuda tema " .. i) then
      helps = helps + 1
    end
  end
  start_perdidas(); keys("9"); downs(8); keys("enter")
  check(shown("CASOS DEL CURSO"), "ayuda: casos del curso")
  keys("esc")
  downs(1); keys("enter")
  check(shown("ACERCA DE") and vhas("PERDIDAS v1.1") and vhas("Memoria Lua"), "ayuda: acerca de")
  png("perd_acerca")
  -- 9 Salir
  start_perdidas()
  mock.marked_changed = 0
  downs(9); keys("enter")
  check(shown("Guarde el documento"), "Salir avisa de guardar (ctrl+S)")
  check(mock.marked_changed > 0, "Salir marca cambios")
  keys("enter")
  check(shown("PERDIDAS / FLUJOS"), "Salir vuelve al menu inicial")
  -- ESC en el menu principal pide confirmacion; ESC la rechaza
  keys("1"); keys("esc")
  check(shown("Desea salir de PERDIDAS"), "ESC en el principal pide confirmacion")
  keys("esc")
  check(shown("MENU PRINCIPAL"), "rechazar confirmacion")
  keys("esc"); keys("enter"); keys("enter")
  check(shown("PERDIDAS / FLUJOS"), "confirmar salida")
end

-- =============================================== 2. casos del curso por tipo
-- Entra a Ayuda > Casos del curso, abre la entrada r (0-based) y deja el resultado
local function open_course(r)
  start_perdidas()
  keys("9"); downs(8); keys("enter")
  downs(r); keys("enter")
end
local function numtxt(label)       -- "label = valor" de las lineas del visor
  for l in view():gmatch("[^\n]+") do
    local a = l:match("^%s*" .. label:gsub("%p", "%%%0") .. "%s+=%s+(.*)$")
    if a then return a end
  end
end

local expect = {
  -- indice (0-based en la lista) = { texto del visor que debe aparecer, ... }
  [0] = { "= 19.76", "p/gamma punto" },          -- P-02 A (SJ)
  [1] = { "Hazen" },                               -- P-01 I
  [2] = { "= 318.8" },                             -- P-03 B
  [3] = { "RESULTADO" },
  [4] = { "= 5.69", "biseccion" },                 -- P-07 B (la iteracion diverge)
  [5] = { "RESULTADO" },
  [6] = { "Hazen" },
  [7] = { "= 45.6" },                              -- P-11 C bomba
  [8] = { "RESULTADO" },
  [9] = { "= 329.1" },                             -- P-15 D (D exacto, lista Pract.3)
  [10] = { "= 256.8", "= 285.75" },                -- P-17 D
  [11] = { "Kv" },                                 -- P-18 F
  [12] = { "= 30.1" },                             -- P-19 C turbina
  [13] = { "RESULTADO" },
  [14] = { "RESULTADO" },
  [15] = { "RESULTADO" },                          -- P-25 E
  [16] = { "RESULTADO" },
  [17] = { "RESULTADO" },
  [18] = { "Q total" },                            -- S-01 .. S-05
  [19] = { "Q total" }, [20] = { "Q total" }, [21] = { "Q total" }, [22] = { "Q total" },
  [23] = { "f" }, [24] = { "f" }, [25] = { "f" }, [26] = { "f" }, [27] = { "f" },
}
local graphable = { A = true, B = true, C = true, D = true, F = true }
local tipo_of = {}
for i, e in ipairs(ex.examples) do tipo_of[i - 1] = e.tipo end
local tipo_name = { [0] = "A", "B", "D", "C", "F", "E", "I" }

do
  H.hydro_cfg_default(U.g_set.h)
  U.g_set.h.method = H.FM_SJ        -- P-02 se carga con Swamee-Jain (fija el metodo del caso)
  for r = 0, 27 do
    open_course(r)
    local good = ok_app("curso " .. r)
    if good then
      local isnet = r >= 18 and r <= 22
      local isf = r >= 23
      check(shown("RESULTADO") or shown("FACTOR DE FRICCION f") or isf,
        "curso " .. r .. ": muestra el resultado")
      for _, s in ipairs(expect[r] or {}) do
        check(vhas(s), "curso " .. r .. ": resultado contiene '" .. s .. "'")
      end
      -- memoria (F1)
      F(1)
      if ok_app("curso " .. r .. " memoria") then
        local memo_ok = shown("MEMORIA") or shown("MEMORIA DE CALCULO") or W.view_n > 5
        check(memo_ok and not vhas("{") and not vhas("%v"), "curso " .. r .. ": memoria sin plantillas")
        if r == 0 then png("perd_memoria") end
      end
      F(1)                                    -- vuelve al resumen
      -- grafico (F2)
      local tn = (not isnet and not isf) and tipo_name[tipo_of[r]] or nil
      if isnet or (tn and graphable[tn]) then
        F(2)
        if ok_app("curso " .. r .. " grafico") then
          check(shown("Esquema sin escala"), "curso " .. r .. ": grafica LE/LP")
          if r == 0 then png("perd_grafica") end
          keys("esc")
        end
      elseif tn == "E" or tn == "I" then
        F(2)
        check(shown("No aplica"), "curso " .. r .. ": grafico no aplica a E/I")
        keys("enter")
      end
      -- el resumen sigue abierto
      if ok_app("curso " .. r .. " cierre") then keys("esc") end
    end
    check(back_root(), "curso " .. r .. ": se vuelve al menu inicial")
    if r == 0 then
      -- captura del resumen del caso P-02
    end
  end
  U.g_set.h.method = H.FM_CW
end

-- Captura del resumen de P-02
do
  H.hydro_cfg_default(U.g_set.h); U.g_set.h.method = H.FM_SJ
  open_course(0)
  inside("resumen A")
  png("perd_resumen_A")
  back_root()
  H.hydro_cfg_default(U.g_set.h)
end

-- ================================== 3. formularios: errores y valores tecleados
do
  H.hydro_cfg_default(U.g_set.h)
  start_perdidas(); keys("1", "1")
  F(5)
  check(shown("Falta este dato"), "A: calcular sin datos avisa")
  keys("esc")
  -- D = 0 rechazado; 3+ rechazado; 1/0 rechazado; ks < 0 rechazado
  keys("1")
  keys("down"); TE("0")
  check(shown("Debe ser mayor que 0"), "A: D = 0 rechazado")
  keys("esc"); keys("esc")
  start_perdidas(); keys("1", "1"); TE("3+")
  check(shown("Error de sintaxis"), "A: 3+ rechazado")
  keys("esc"); keys("esc")
  start_perdidas(); keys("1", "1"); TE("1/0")
  check(shown("Division entre cero"), "A: 1/0 rechazado")
  keys("esc"); keys("esc")
  start_perdidas(); keys("1", "1"); downs(3); TE("-1")
  check(shown("No puede ser negativo"), "A: ks < 0 rechazado")
  back_root()
  -- P-02 tecleado en el formulario (Swamee-Jain), con H sobre el punto
  U.g_set.h.method = H.FM_SJ
  start_perdidas(); keys("1", "1")
  TE("72"); TE("200"); TE("1000"); TE("0.0015")
  TE("0.5+3*0.15+167*0.01+12*0.18+6*0.32")
  TE("1.007E-6")
  keys("enter")                    -- f dado vacio (opcional)
  TE("53")                         -- H sobre el punto
  F(5)
  check(vhas("RESULTADO"), "A tecleado: resultado")
  check(numtxt("hT = hf + hm") and numtxt("hT = hf + hm"):find("^19.76"), "A tecleado: hT = 19,76 m")
  check(numtxt("hm") and numtxt("hm"):find("^1.79"), "A tecleado: hm = 1,79 m")
  check(numtxt("v") and numtxt("v"):find("^2.29"), "A tecleado: v = 2,29 m/s")
  check(numtxt("p/gamma punto") and numtxt("p/gamma punto"):find("^32.96"), "A tecleado: p/gamma = 32,96 m")
  -- memoria con los cuatro metodos de f
  keys("esc")
  for m = 0, 3 do
    U.g_set.h.method = m
    F(5)
    F(1)
    check(ok_app("memoria A metodo " .. m) and vhas("DATOS") and vhas(H.hydro_method_name(m)),
      "memoria A con metodo " .. m)
    keys("esc")
  end
  U.g_set.h.method = H.FM_CW
  back_root()
  -- laminar
  start_perdidas(); keys("1", "1")
  TE("0.00002"); TE("20"); TE("50"); TE("0"); TE("0"); F(5)
  F(1)
  check(ok_app("laminar") and vhas("64/Re"), "memoria A laminar")
  back_root()
end

-- ===================================== 4. cada tipo desde el formulario y F3 guardar
do
  H.hydro_cfg_default(U.g_set.h)
  -- B, P-03 tecleado
  start_perdidas(); keys("1", "2")
  TE("43.5"); TE("293"); TE("700"); TE("0.0015"); TE("11.5"); TE("1E-6")
  F(5)
  check(ok_app("B") and vhas("RESULTADO") and (numtxt("Q") or ""):find("^318.8"), "B P-03 tecleado: Q = 318,8 l/s")
  check(vhas("curso"), "B P-03: iteracion del curso")
  F(1)
  check(vhas("ITERACIONES"), "B P-03: memoria con tabla de iteraciones")
  back_root()
  -- B con secante y C_H de arranque (v2.1)
  start_perdidas(); keys("1", "2")
  TE("43.5"); TE("293"); TE("700"); TE("0.0015"); TE("11.5"); TE("1E-6")
  keys("enter")                    -- f dado vacio
  keys("down")                     -- metodo
  TE("140")                        -- C_H inicio
  keys("right")                    -- iteracion: secante
  F(5)
  check(ok_app("B secante") and vhas("RESULTADO") and (numtxt("Q") or ""):find("^318"), "B secante con C_H de arranque")
  F(1)
  check(ok_app("B secante memo") and vhas("DATOS"), "B secante: memoria")
  back_root()
  -- C bomba (P-11) y turbina (P-19)
  start_perdidas(); keys("1", "4")
  keys("enter")                    -- equipo: bomba
  TE("42"); TE("150"); TE("970"); TE("0.0015"); TE("9.4"); TE("1.14E-6")
  TE("16"); TE("0.65"); keys("enter"); TE("890"); F(5)
  check(ok_app("C") and vhas("RESULTADO"), "C bomba")
  check(vhas("45.6") and vhas("28.9"), "C P-11: HB = 45,6 m, Pb = 28,9 kW")
  check(vhas("935.6"), "C P-11: cota piezometrica 935,6")
  F(1); check(vhas("DATOS"), "C: memoria"); back_root()
  -- D con valvula: P-17 + P-18
  start_perdidas(); keys("1", "3")
  TE("200"); TE("76"); TE("1900"); TE("0.0015"); TE("12.8"); TE("1E-6")
  keys("enter")                    -- lista: la primera (PVC examen 2025)
  keys("right")                    -- valvula: Si
  F(5)
  check(ok_app("D") and vhas("256.8") and vhas("285.75") and vhas("262.38"), "D P-17 con valvula: 256,8 / 285,75 / 262,38")
  check(vhas("60.7"), "D P-18: Kv = 60,7")
  F(1); check(vhas("DATOS"), "D: memoria"); F(1)
  F(2); check(shown("Esquema sin escala"), "D: grafica"); keys("esc")
  back_root()
  -- E calibracion
  start_perdidas(); keys("1", "6")
  TE("1135"); TE("1070"); TE("36"); TE("84"); TE("405"); TE("274"); TE("172"); TE("3.5"); TE("1.17E-6")
  check(ok_app("E") and vhas("RESULTADO"), "E calibracion tecleada")
  F(1); check(ok_app("E memo") and vhas("DATOS"), "E: memoria")
  back_root()
  -- F valvula
  start_perdidas(); keys("1", "5")
  TE("200"); TE("285.75"); TE("1900"); TE("0.0015"); TE("12.8"); TE("1E-6"); TE("76"); keys("enter", "enter")
  check(ok_app("F") and vhas("RESULTADO") and vhas("60.7"), "F valvula: Kv = 60,7")
  back_root()
  -- I modo hf y modo Q
  start_perdidas(); keys("1", "7")
  keys("enter")                    -- calcular: hf dado Q
  TE("72"); keys("down"); TE("200"); TE("1000"); TE("0.0015"); TE("0"); TE("1.007E-6"); TE("150")
  F(5)
  check(ok_app("I hf") and vhas("RESULTADO") and vhas("Hazen"), "I modo hf")
  F(1); check(vhas("DATOS"), "I: memoria"); back_root()
  start_perdidas(); keys("1", "7")
  keys("right")                    -- calcular: Q dado H
  keys("down"); keys("down"); TE("72")   -- (H) tras saltar Q
  F(5)
  check(ok_app("I Q") and (vhas("RESULTADO") or shown("Falta") or shown("Debe")), "I modo Q")
  back_root()
end

-- ============================================================ 5. serie / paralelo
local net_cases = {
  -- {indice curso (0-based lista), Qtotal esperado aprox (l/s) o nil}
  { 18, "S-01" }, { 19, "S-02" }, { 20, "S-03" }, { 21, "S-04 hacia atras" }, { 22, "S-05" },
}
do
  H.hydro_cfg_default(U.g_set.h)
  for _, c in ipairs(net_cases) do
    open_course(c[1])
    check(ok_app(c[2]) and vhas("Sistema serie/paralelo"), c[2] .. ": resultado")
    check(vhas("Comprobacion"), c[2] .. ": comprobacion de nudos y rutas")
    if c[1] == 21 then
      check(vhas("H necesaria") and vhas("H en kPa"), "S-04: hacia atras da H necesaria")
    end
    if c[1] == 18 then png("perd_red") end
    F(1); check(ok_app(c[2] .. " memo") and vhas("MODULOS DE CAUDAL"), c[2] .. ": memoria")
    if c[1] == 21 then
      check(vhas("CAUDAL Y CARGA") and vhas("REPARTO"), "S-04: secciones de la memoria")
    end
    F(2)
    check(ok_app(c[2] .. " graf") and shown("Esquema sin escala"), c[2] .. ": grafica")
    if c[1] == 18 then png("perd_red_graf") end
    keys("esc")
    F(1)
    keys("esc")
    check(back_root(), c[2] .. ": vuelta")
  end
  -- Valores del S-01: sistema A en serie con tres tubos en paralelo; Q total = 22,3 l/s? se compara con el motor
  local net = H.new_net()
  local cfg = H.new_cfg()
  local ia = H.hydro_net_add_pipe(net, 100, 0.15, 0.020, 0, 0)
  local i2 = H.hydro_net_add_pipe(net, 100, 0.10, 0.015, 0, 5)
  local i3 = H.hydro_net_add_pipe(net, 100, 0.10, 0.015, 0, 5)
  local i4 = H.hydro_net_add_pipe(net, 100, 0.10, 0.015, 0, 5)
  local par = H.hydro_net_add_group(net, H.NODE_PARALLEL, { i2, i3, i4 }, 3)
  H.hydro_net_add_group(net, H.NODE_SERIES, { ia, par }, 2)
  cfg.nu = 1e-6
  check(H.hydro_net_solve(net, 20, cfg) == 0, "S-01 motor")
  local qls = 1000 * net.node[net.root].Q
  open_course(18)
  local qshown = tonumber((numtxt("Q total") or ""):match("^([%d%.eE%-]+)"))
  check(qshown and math.abs(qshown - qls) < 1e-3 * qls, "S-01: Q total de la pantalla = motor (" .. tostring(qshown) .. " vs " .. qls .. ")")
  back_root()

  -- formulario del sistema tecleado: 2 tubos en serie, hacia adelante; luego hacia atras
  start_perdidas(); keys("2")
  TE("2"); keys("down"); TE("30"); keys("down"); keys("down"); TE("1E-6"); keys("down"); keys("down")
  for i = 1, 2 do
    TE(tostring(i)); TE("100"); TE("150"); TE("0.02"); keys("down"); TE("0")
  end
  check(ok_app("red tecleada") and vhas("Q total"), "red: 2 tubos en serie tecleados")
  local q_fwd = numtxt("Q total")
  F(5)                              -- vuelve al formulario (CALC no existe en resumen: es VOLVER)
  back_root()
  -- F1 (CALC f) sin cursor en "f dado" avisa
  start_perdidas(); keys("2"); F(1)
  check(shown("Ubique el cursor"), "red: CALC f exige cursor en f dado")
  back_root()
  -- error: tubo sin f ni ks
  local Net = env.require("scr.scr_net")
  local ni = Net.ni
  ni.np, ni.snp, ni.H, ni.sH, ni.nu, ni.snu, ni.mode = 1, 1, 20, 1, 1e-6, 1, 0
  ni.p[1] = { tr = 1, L = 100, D = 100, f = 0, ks = 0, K = 0, str = 1, sL = 1, sD = 1, sf = 0, sks = 0, sK = 1 }
  start_perdidas(); keys("2"); F(5)
  check(shown("Cada tubo necesita f o ks"), "red: aviso sin f ni ks")
  back_root()
  -- hacia atras sin tubo conocido
  ni.p[1].sf, ni.p[1].f = 1, 0.02
  ni.mode, ni.skp, ni.sQk = 1, 0, 0
  start_perdidas(); keys("2"); F(5)
  check(shown("Falta el tubo conocido"), "red: hacia atras sin tubo conocido avisa")
  ni.mode = 0; ni.sH = 0
  keys("right"); F(5)
  check(shown("Falta la carga H") or shown("Falta"), "red: sin carga H avisa")
  back_root()
end

-- ==================================================================== 6. calcular f
do
  H.hydro_cfg_default(U.g_set.h)
  local fexp = {
    [23] = "0.0", [24] = "0.0", [25] = "0.0", [26] = "0.0", [27] = "0.0",
  }
  -- modo Re y ks/D tecleado: Re 20000, ks/D 1E-4 (ej. 3a)
  local Fric = env.require("scr.scr_fric")
  Fric.fric_preset(0); Fric.fi.sRe, Fric.fi.sksd = 0, 0
  start_perdidas(); keys("3")
  keys("down")
  TE("20000"); TE("1E-4")
  keys("down", "down")
  F(5)
  check(ok_app("f tecleado") and shown("FACTOR DE FRICCION f"), "calcular f tecleado: resultado")
  -- cuatro metodos: la tabla de los 4 metodos con su diferencia
  check(vhas("Colebrook") and vhas("Swamee") and vhas("Haaland") and vhas("Goudar"), "calcular f: tabla de los 4 metodos")
  local fcw = tonumber((numtxt("f") or ""):match("^([%d%.]+)")) or 0
  local c = H.new_cfg(); local o = {}
  H.hydro_friction(20000, 1e-4, H.FM_CW, c, o)
  check(math.abs(o.f - 0.0264) < 1e-3, "motor f(20000,1e-4) = 0,0264")
  F(1)
  check(ok_app("f memo") and vhas("ITERACIONES"), "calcular f: memoria con iteraciones")
  F(1)
  png("perd_f")
  -- todos los metodos de Ajustes: la memoria cambia
  keys("esc")
  for m = 0, 3 do
    U.g_set.h.method = m
    F(5)
    check(ok_app("f metodo " .. m) and vhas(H.hydro_method_name(m)), "calcular f: metodo " .. H.hydro_method_name(m))
    F(1)
    check(vhas(H.hydro_method_name(m)) or vhas("f"), "calcular f: memoria metodo " .. m)
    keys("esc")
  end
  U.g_set.h.method = H.FM_CW
  -- F2 cambia de modo y las funciones MAT/FLUIDO avisan en el modo 1
  F(1)
  check(shown("solo en modo datos"), "calcular f: MAT solo en modo 2")
  F(3)
  check(shown("solo en modo datos"), "calcular f: FLUIDO solo en modo 2")
  F(2)
  check(shown("Caudal Q (o v)"), "calcular f: F2 pasa al modo datos de tuberia")
  back_root()
  -- tabla de iteraciones: laminar (F-05) y casos del curso F-01..F-05
  for k = 0, 4 do
    open_course(23 + k)
    check(ok_app("F-0" .. (k + 1)) and shown("FACTOR DE FRICCION f"), "F-0" .. (k + 1) .. ": resultado")
    if k == 4 then check(vhas("lamin") or vhas("64/Re"), "F-05: laminar") end
    F(1)
    check(ok_app("F-0" .. (k + 1) .. " memo") and W.view_n > 5, "F-0" .. (k + 1) .. ": memoria")
    if k == 0 then check(vhas("ITERACIONES (COLEBROOK-WHITE)") and vhas("Converge en"), "F-01: tabla de iteraciones de Colebrook") end
    keys("esc")
    check(back_root(), "F-0" .. (k + 1) .. ": vuelta")
  end
end

-- ================================================================== 7. biblioteca
do
  H.hydro_cfg_default(U.g_set.h)
  Pipe.pin_reset()
  start_perdidas(); keys("6")
  -- materiales: todos los materiales listados; USAR deja ks y C_H en pin
  keys("1")
  check(shown("MATERIALES"), "biblioteca: materiales")
  png("perd_materiales")
  downs(8)                         -- Hierro fundido: ks 0.15, CH 130
  keys("enter")
  check(shown("ks y C_H quedan"), "biblioteca: material elegido")
  check(Pipe.pin.ks == 0.15 and Pipe.pin.sks == 1 and Pipe.pin.CH == 130 and Pipe.pin.sCH == 1,
    "material: ks = 0.15 y C_H = 130 en los formularios")
  keys("enter")
  -- todos los materiales: ks y C_H correctos
  local last = 8
  for i = 0, lib.MATERIALS - 1 do
    keys("1")
    for _ = 1, math.abs(i - last) do keys(i > last and "down" or "up") end
    last = i
    keys("enter")
    local m = lib.materials[i + 1]
    if m.ks_mm >= 0 then check(Pipe.pin.ks == m.ks_mm, "material " .. m.name .. ": ks") end
    if m.ch > 0 then check(Pipe.pin.CH == m.ch, "material " .. m.name .. ": C_H") end
    keys("enter")
  end
  -- accesorios: lista, sumador, conjuntos del curso
  keys("2")
  check(shown("SUMADOR DE ACCESORIOS"), "sumador")
  F(1)
  check(shown("ACCESORIOS"), "sumador: AGREGAR abre la lista de accesorios")
  keys("enter")                    -- primer accesorio: entrada borde recto K 0.5
  check(shown("Entrada borde recto"), "sumador: accesorio agregado")
  F(4)                             -- OTRO
  check(shown("Otro accesorio"), "sumador: OTRO agrega linea libre")
  F(3)                             -- QUITAR
  F(2)                             -- conjuntos del curso
  check(shown("CONJUNTOS DEL CURSO"), "sumador: conjuntos del curso")
  keys("enter")                    -- PVC 200 mm (SumK 6.7 incluido)
  png("perd_sumador")
  F(5)                             -- USAR
  check(shown("Suma K"), "sumador: aviso de uso")
  check(math.abs(Pipe.pin.K - 6.7) < 0.01 and Pipe.pin.sK == 1, "sumador: PVC 200 mm da Suma K = 6.7 (" .. Pipe.pin.K .. ")")
  keys("enter")
  -- todos los conjuntos y todos los accesorios
  keys("2"); F(2)
  check(shown("CONJUNTOS DEL CURSO") and ok_app("conj"), "sumador: otra vez los conjuntos"); keys("esc")
  for i = 0, lib.FITTINGS - 1 do
    F(1); downs(i); keys("enter")
  end
  check(ok_app("accesorios") and shown("SUMADOR"), "sumador: los 30 accesorios (maximo 10 lineas)")
  keys("esc")
  -- fluido por defecto: agua 20 C cambia nu, gamma, pv
  keys("3")
  check(shown("FLUIDO POR DEFECTO"), "biblioteca: fluido")
  downs(3); keys("enter")
  check(shown("nu, gamma = rho g"), "fluido: aviso")
  check(math.abs(U.g_set.h.nu - 1.004e-6) < 1e-12 and math.abs(U.g_set.h.gamma - 998.2 * U.g_set.h.g) < 1e-6 and
    U.g_set.h.pv == 2339, "fluido agua 20 C: nu, gamma y pv a Ajustes")
  keys("enter")
  keys("3"); downs(9); keys("enter")      -- aire (curso): rho y nu del aire
  check(shown("Aire por defecto") and U.g_set.rho_air == 1.2 and U.g_set.nu_air == 1.5e-5, "fluido aire en Ajustes")
  keys("enter")
  keys("3"); for _ = 1, 5 do keys("up") end; keys("enter")       -- Curso 2025 T4: solo nu
  check(shown("nu del curso") and U.g_set.h.nu == 1e-6, "fluido de curso: solo nu")
  keys("enter")
  -- diametros comerciales: 5 listas + lista propia (15 campos)
  keys("4")
  check(shown("DIAMETROS COMERCIALES"), "diametros")
  for i = 0, 4 do
    if i > 0 then downs(1) end
    keys("enter")
    check(shown("Diametros internos") and vhas(diams.diam_set_names[i + 1]), "diametros: lista " .. diams.diam_set_names[i + 1])
    keys("esc"); keys("esc")
    keys("4")
  end
  keys("esc")
  H.hydro_cfg_default(U.g_set.h)
  back_root()
end

-- ============================ 8. lista propia de diametros y tipo D con ella
do
  H.hydro_cfg_default(U.g_set.h)
  for i = 1, 15 do diams.diam_custom[i] = 0 end
  start_perdidas(); keys("6", "4")
  downs(5); keys("enter")
  check(shown("LISTA PROPIA"), "lista propia: formulario")
  TE("200"); TE("300"); TE("100")
  F(5)
  check(diams.diam_custom[1] == 200 and diams.diam_custom[2] == 300 and diams.diam_custom[3] == 100,
    "lista propia: guardada (200, 300, 100)")
  check(mock.marked_changed > 0, "lista propia: marca cambios")
  back_root()
  -- tipo D con la lista propia: el D comercial sale de ella
  start_perdidas(); keys("1", "3")
  TE("200"); TE("76"); TE("1900"); TE("0.0015"); TE("12.8"); TE("1E-6")
  keys("right", "right", "right", "right", "right")   -- lista propia (indice 5)
  F(5)
  check(ok_app("D propia") and vhas("RESULTADO"), "D con lista propia: resultado")
  F(1); check(vhas("Lista propia"), "D con lista propia: la memoria nombra la lista"); keys("esc")
  back_root()
  -- lista propia vacia: error
  for i = 1, 15 do diams.diam_custom[i] = 0 end
  start_perdidas(); keys("1", "3")
  TE("200"); TE("76"); TE("1900"); TE("0.0015"); TE("12.8"); TE("1E-6")
  keys("right", "right", "right", "right", "right")
  F(5)
  check(shown("Lista propia vacia"), "D con lista propia vacia avisa")
  back_root()
end

-- ===================================================================== 9. ajustes
do
  H.hydro_cfg_default(U.g_set.h)
  Store.settings_default(U.g_set)
  start_perdidas(); keys("8")
  check(shown("AJUSTES") and shown("Metodo de f") and shown("Colebrook"), "ajustes: formulario")
  png("perd_ajustes")
  keys("right")                    -- metodo: Swamee-Jain
  check(U.g_set.h.method == 1, "ajustes: metodo cambia")
  keys("down"); TE("9.8")          -- g (el cursor pasa a gamma)
  keys("down", "down"); TE("4")    -- nu, decimales
  F(5)
  check(shown("MENU PRINCIPAL") and U.g_set.dec == 4 and math.abs(U.g_set.h.g - 9.8) < 1e-12,
    "ajustes: g y decimales guardados")
  -- rango invalido: g = 50
  keys("8"); keys("backtab"); keys("down"); TE("50")
  check(shown("Fuera del rango"), "ajustes: g = 50 fuera de rango")
  keys("esc"); keys("esc")
  -- Re laminar > Re turbulento: aviso al salir
  keys("8"); keys("backtab")
  downs(11); TE("5000")            -- Re laminar = 5000 > Re turbulento (4000)
  F(5)
  check(shown("Revise: Re turb"), "ajustes: Re lam > Re turb avisa")
  keys("up"); TE("2000")           -- vuelve a un valor valido
  F(5)
  check(shown("MENU PRINCIPAL") and U.g_set.h.re_lam == 2000, "ajustes: valor valido sale")
  -- defecto
  keys("8"); F(1)
  check(shown("Restaurar"), "ajustes: DEFECTO pide confirmacion")
  keys("enter")
  check(U.g_set.dec == 6 and U.g_set.h.method == 0 and U.g_set.h.g == 9.81, "ajustes: valores por defecto")
  -- cada campo de Ajustes se puede editar
  keys("esc")
  -- ajuste persistente a traves de on.save/on.restore
  keys("8"); keys("backtab"); keys("right", "right", "right")     -- Goudar-Sonnad
  downs(4); TE("5")
  F(5)
  local t = mock.save()
  check(t.cfg.h.method == 3 and t.cfg.dec == 5 and t.ver == 3, "ajustes: on.save contiene metodo, decimales y version")
  U.g_set.h.method = 0; U.g_set.dec = 6
  mock.restore(t)
  check(U.g_set.h.method == 3 and U.g_set.dec == 5, "ajustes: on.restore devuelve metodo y decimales")
  Store.settings_default(U.g_set)
  back_root()
end

-- ================================================ 10. Mis casos y persistencia
local function save_case(name)
  F(3)
  check(shown("GUARDAR CASO"), "guardar: pide nombre")
  typed(name); keys("enter")
end
do
  H.hydro_cfg_default(U.g_set.h)
  for i = #U.state.cas, 1, -1 do U.state.cas[i] = nil end
  mock.marked_changed = 0
  -- guardar un caso por cada tipo (desde su pantalla de resultado) y desde Calcular f
  local nsave = 0
  local order = { 0, 2, 4, 7, 11, 15, 1 }       -- cursos: A B D... se mezclan
  for _, r in ipairs({ 0, 2, 10, 7, 11, 15, 1 }) do
    open_course(r)
    save_case("C" .. r)
    check(shown("Caso guardado"), "guardar caso del curso " .. r)
    keys("enter")
    nsave = nsave + 1
    back_root()
  end
  open_course(23); save_case("FRIC1"); keys("enter"); back_root()
  nsave = nsave + 1
  check(#U.state.cas == nsave, "Mis casos: " .. nsave .. " guardados (" .. #U.state.cas .. ")")
  check(mock.marked_changed > 0, "guardar: marca cambios")
  -- tipos y datos
  local tipos = {}
  for i, c in ipairs(U.state.cas) do tipos[i] = c.tipo end
  check(tipos[1] == 0 and tipos[2] == 1 and tipos[3] == 2 and tipos[4] == 3 and tipos[5] == 4 and tipos[6] == 5
    and tipos[7] == 6 and tipos[8] == 7, "tipos guardados A B D C F E I f")
  check(type(U.state.cas[1].datos) == "table" and U.state.cas[1].datos.Q == 72 and U.state.cas[1].nombre == "C0",
    "caso: datos son una copia de la tabla de entradas")
  -- nombre repetido pide confirmacion; invalido (vacio) no guarda
  open_course(0)
  F(3); typed("C0"); keys("enter")
  check(shown("Reemplazarlo"), "guardar: nombre repetido pide confirmar")
  keys("esc")
  F(3); keys("enter")                       -- nombre vacio: no avanza
  check(shown("GUARDAR CASO"), "guardar: nombre vacio no se acepta")
  keys("esc")
  back_root()
  -- la lista de Mis casos: nombres y tipos
  start_perdidas(); keys("7")
  check(shown("MIS CASOS") and shown("C0") and shown("(A) Perdidas dado Q") and shown("Casos: 8 de 20"), "Mis casos: lista")
  png("perd_casos")
  -- cargar (F1): reabre el calculo
  keys("enter")
  check(ok_app("cargar") and vhas("RESULTADO"), "Mis casos: ENTER carga y calcula (A)")
  keys("esc")                                -- resultado
  keys("esc")                                -- formulario
  check(shown("MIS CASOS"), "Mis casos: vuelve a la lista")
  -- cargar cada caso
  for i = 0, #U.state.cas - 1 do
    start_perdidas(); keys("7"); downs(i); F(1)
    check(ok_app("cargar " .. i) and (vhas("RESULTADO") or vhas("Colebrook") or vhas("Re")), "Mis casos: carga el caso " .. (i + 1))
    check(back_root(), "Mis casos: vuelta " .. (i + 1))
  end
  -- persistencia a traves de on.save / on.restore
  local snap = mock.save()
  check(#snap.cas == nsave and snap.ver == 3 and snap.cas[1].nombre == "C0" and snap.cas[1].datos.Q == 72,
    "on.save: casos con nombre, tipo y datos")
  for i = #U.state.cas, 1, -1 do U.state.cas[i] = nil end
  check(#U.state.cas == 0, "casos vaciados")
  mock.restore(snap)
  check(#U.state.cas == nsave and U.state.cas[3].tipo == 2, "on.restore: casos de vuelta")
  -- el caso restaurado sigue siendo funcional
  start_perdidas(); keys("7"); downs(2); keys("enter")
  check(ok_app("caso restaurado") and vhas("RESULTADO"), "caso restaurado se carga y calcula")
  back_root()
  -- datos danados se ignoran
  mock.restore({ ver = 3, cas = { { nombre = "bad name", tipo = 0, datos = {} }, { nombre = "OK", tipo = 99, datos = {} },
                                  { nombre = "OK2", tipo = 0, datos = { [true] = 1 } } } })
  check(#U.state.cas == 0, "on.restore: casos invalidos descartados")
  mock.restore(snap)
  -- borrar
  start_perdidas(); keys("7")
  F(3)
  check(shown("Se borra para siempre"), "borrar: pide confirmacion")
  keys("esc")
  check(#U.state.cas == nsave, "borrar: ESC cancela")
  F(3); keys("enter")
  check(#U.state.cas == nsave - 1 and U.state.cas[1].nombre ~= "C0", "borrar: elimina el caso")
  keys("esc")
  -- limite de 20 casos y nombre de 8 caracteres
  for i = #U.state.cas, 1, -1 do U.state.cas[i] = nil end
  for i = 1, 20 do U.state.cas[i] = { nombre = "N" .. i, tipo = 0, datos = Store.deep_copy(Pipe.pin) } end
  open_course(0)
  F(3); typed("NUEVO"); keys("enter")
  check(shown("Lista llena"), "guardar: limite de 20 casos")
  keys("enter")
  F(3); typed("ABCDEFGHIJK")
  check(not shown("ABCDEFGHI"), "nombre: maximo 8 caracteres")
  keys("esc")
  back_root()
  for i = #U.state.cas, 1, -1 do U.state.cas[i] = nil end
  -- casos de FLUJOS: se listan, pero se abren en el otro programa
  U.state.cas[1] = { nombre = "ARR", tipo = Cases.KT_DRAG, datos = { x = 1 } }
  start_perdidas(); keys("7")
  check(shown(">") and shown("AR-1 Fuerza FD/FL"), "Mis casos: caso de FLUJOS marcado con >")
  keys("enter")
  check(shown("el programa FLUJOS"), "Mis casos: un caso de FLUJOS se abre en FLUJOS")
  keys("enter"); keys("esc")
  back_root()
  U.state.cas[1] = nil
  -- guardado de la lista propia con el documento
  diams.diam_custom[1] = 123
  local sn = mock.save()
  diams.diam_custom[1] = 0
  mock.restore(sn)
  check(diams.diam_custom[1] == 123, "persistencia: lista propia de diametros")
  diams.diam_custom[1] = 0
end

-- ================================================ 11. almacenamiento y validacion
do
  local s = Store.copy_settings(U.g_set)
  Store.settings_default(s)
  check(Store.settings_valid(s), "store: ajustes por defecto validos")
  s.h.g = 0
  check(not Store.settings_valid(s), "store: g = 0 invalido")
  Store.settings_default(s); s.h.re_turb = 100; s.h.re_lam = 2000
  check(not Store.settings_valid(s), "store: re_turb < re_lam invalido")
  Store.settings_default(s); s.dec = 10
  check(not Store.settings_valid(s), "store: dec > 9 invalido")
  Store.settings_default(s); s.h.nu = 0 / 0
  check(not Store.settings_valid(s), "store: NaN invalido")
  Store.settings_default(s); s.cd_user[3] = 99
  check(not Store.settings_valid(s), "store: Cd propio fuera de rango")
  -- on.restore ignora ajustes invalidos y conserva los actuales
  Store.settings_default(U.g_set)
  U.g_set.dec = 3
  local bad = mock.save()
  bad.cfg.h.g = -5
  U.g_set.dec = 6
  mock.restore(bad)
  check(U.g_set.dec == 6 and U.g_set.h.g == 9.81, "restore: ajustes invalidos ignorados")
  local good = mock.save()
  good.cfg.dec = 2; good.cfg.cd_user[4] = 0.5
  mock.restore(good)
  check(U.g_set.dec == 2 and U.g_set.cd_user[3] == 0.5, "restore: Cd propio (base 1 en el documento) vuelve a base 0")
  mock.restore({ ver = 99 })
  check(U.g_set.dec == 2, "restore: version futura ignorada")
  Store.settings_default(U.g_set)
end

print(string.format("test_perdidas: %d comprobaciones, %d fallo(s)", checks, fails))
if fails > 0 then os.exit(1) end
print("test_perdidas OK")
