-- test_ui.lua - Capa de interfaz: runtime, widgets, memoria de calculo, figuras,
-- grafica y menu inicial, con teclas simuladas sobre mock_nspire.
-- Uso: desde la raiz, tras tools/build.py --no-tns (lo hace tools/run_tests.sh).
local mock = dofile("tests/mock_nspire.lua")
local env = mock.load_app("build/app.lua")

local fails, checks = 0, 0
local function check(cond, msg)
  checks = checks + 1
  if not cond then
    fails = fails + 1
    print("FALLO: " .. tostring(msg))
  end
end
local function eq(a, b, msg)
  check(a == b, (msg or "eq") .. ": esperado " .. tostring(b) .. ", obtenido " .. tostring(a))
end

local rt = env.require("ui.rt")
local U = env.require("ui.ui")
local W = env.require("ui.widgets")
local MR = env.require("memo_run")
local M = env.require("ui.memo")
local GC = env.require("ui.gfxcat")
local GR = env.require("ui.graph")
local H = env.require("core.hydro")

os.execute("mkdir build\\png 2>nul")

-- Ejecuta fn en la corrutina de la app; devuelve la tabla donde fn deja resultados
local R
local function run(fn)
  R = { done = false }
  rt.start(function()
    fn(R)
    R.done = true
  end)
  return R
end
local function keys(...)
  for _, k in ipairs({ ... }) do mock.key(k) end
end
local function typed(s)
  for c in s:gmatch(".") do mock.key(c) end
end
local function shown(s) mock.paint(); return mock.has_text(s) end
local function exact(s)
  mock.paint()
  for _, t in ipairs(mock.screen_text()) do if t.text == s then return true end end
  return false
end
local function inside(label)
  -- todo texto cabe en la ventana
  for _, t in ipairs(mock.screen_text()) do
    local ok = t.x >= 0 and t.x + t.w <= mock.W + 2 and t.y >= 0 and t.y + t.h <= mock.H + 2
    if not ok then
      check(false, label .. ": texto fuera de pantalla '" .. t.text .. "' x=" .. t.x .. " w=" .. t.w .. " y=" .. t.y)
    end
  end
end
local function png(name)
  mock.paint()
  mock.dump_ops("build/png/" .. name .. ".json")
  local ok = os.execute('python -I tools/render_png.py build/png/' .. name .. '.json build/png/' ..
    name .. '.png --scale 2')
  check(ok == 0 or ok == true, "render_png " .. name)
end

-- ============================================================ traduccion de teclas
do
  local got = {}
  run(function()
    for _ = 1, 16 do
      local k = U.ui_getkey()
      got[#got + 1] = k.k .. (k.c and (":" .. k.c) or "")
    end
  end)
  keys("up", "down", "left", "right", "enter", "return", "esc", "clear", "backspace", "delete",
    "tab", "backtab", "menu")
  mock.key("7"); mock.key("\226\136\146"); mock.key("\225\180\135")
  local want = { "1", "2", "3", "4", "5", "5", "6", "6", "7", "7", "19", "18", "13", "15:7",
    "15:-", "15:E" }
  for i, w in ipairs(want) do eq(got[i], w, "tecla " .. i) end
  check(R.done, "getkey: 16 teclas leidas")
  -- mouseDown en la barra de acciones solo si hay etiqueta
  local r = run(function(t) U.ui_begin("T", nil); U.ui_fbar({ "UNO", "", "", "", "CINCO" }); U.ui_end()
    t.k = U.ui_getkey() end)
  mock.paint()
  mock.click(10, mock.H - 5)
  eq(r.k and r.k.k, U.K_F1, "clic F1")
  r = run(function(t) U.ui_begin("T", nil); U.ui_fbar({ "UNO", "", "", "", "CINCO" }); U.ui_end()
    t.k = U.ui_getkey() end)
  mock.click(mock.W - 10, mock.H - 5)
  eq(r.k and r.k.k, U.K_F5, "clic F5")
  -- toolpalette refleja las etiquetas + Ajustes
  local r2 = run(function(t) U.ui_begin("T", nil); U.ui_fbar({ "UNO", "", "TRES", "", "" }); U.ui_end()
    t.k = U.ui_getkey() end)
  local tp = mock.toolpalette_menu
  check(tp and tp[1][2][1] == "UNO" and tp[1][3][1] == "TRES" and tp[1][4][1] == "Ajustes",
    "toolpalette con etiquetas")
  tp[1][3][2]()
  eq(r2.k and r2.k.k, U.K_F3, "toolpalette TRES -> F3")
end

-- ============================================================ layout y filas
do
  eq(U.ui_rows(), 12, "filas en 318x212")
  mock.W, mock.H = 400, 300
  check(U.ui_rows() > 12, "mas filas con ventana mayor")
  mock.W, mock.H = 318, 212
end

-- ============================================================ menu_run
do
  local items = {}
  for i = 1, 15 do items[i] = "Opcion numero " .. i end
  local m = { title = "Menu de prueba", items = items, n = 15, cur = 0 }
  local r = run(function(t) t.v = W.menu_run(m) end)
  check(shown("Menu de prueba"), "menu: titulo")
  check(shown("Opcion numero 1"), "menu: item 1")
  check(not shown("Opcion numero 15"), "menu: item 15 fuera (scroll)")
  inside("menu")
  keys("up")                                -- sube a la ultima (envuelve)
  check(shown("Opcion numero 15"), "menu: scroll muestra el ultimo")
  keys("enter")
  eq(r.v, 14, "menu: ENTER devuelve indice 0-based")
  r = run(function(t) t.v = W.menu_run(m) end)
  mock.key("3")
  eq(r.v, 2, "menu: tecla 3")
  r = run(function(t) t.v = W.menu_run(m) end)
  keys("esc"); eq(r.v, W.MENU_BACK, "menu: ESC")
  r = run(function(t) t.v = W.menu_run(m) end)
  keys("menu"); eq(r.v, W.MENU_MODE, "menu: contextMenu = Ajustes")
  r = run(function(t) t.v = W.menu_run(m) end)
  mock.paint(); mock.click(100, mock.H - 5)  -- 2.o boton vacio: nada
  check(not r.done, "menu: clic en boton sin etiqueta no hace nada")
  mock.click(mock.W - 10, mock.H - 5)        -- F5 = ELEGIR
  check(r.done and type(r.v) == "number", "menu: F5 elige")
  r = run(function(t) m.cur = 0; t.v = W.menu_run(m) end)
  mock.paint(); mock.click(50, 17 + 13 * 2 + 3)   -- 3.a fila del cuerpo
  eq(r.v, 2, "menu: clic en fila")
  r = run(function(t) m.cur = 0; t.v = W.menu_run(m) end)
  keys("tab"); keys("enter")
  check(r.v == 11 or r.v == 12, "menu: tab = pagina abajo (" .. tostring(r.v) .. ")")
  m.cur = 0
  r = run(function(t) t.v = W.menu_run(m) end)
  png("menu"); keys("esc")
end

-- ============================================================ formulario
local function make_form()
  local d = { q = 1.5, pos = 2, nn = 0, ch = 1, i = 3, opt = 0, optset = 0, rg = 0.5, info = 42,
    chosen = 0 }
  local fm = {
    title = "Formulario", page = "1/1",
    f = {
      { label = "Q libre", unit = "m3/s", t = d, k = "q", flags = W.FF_ANY },
      { label = "D positivo", unit = "m", t = d, k = "pos", flags = W.FF_POS },
      { label = "ks no negativo", unit = "mm", t = d, k = "nn", flags = W.FF_NONNEG },
      { label = "Metodo", t = d, chk = "ch", flags = W.FF_CHOICE,
        choices = { "Colebrook", "Swamee", "Haaland" }, nchoices = 3 },
      { label = "Entero 1-9", t = d, k = "i", flags = W.FF_INT, lo = 1, hi = 9 },
      { label = "Opcional", unit = "m", t = d, k = "opt", setk = "optset", flags = W.FF_OPT },
      { label = "Rango 0-1", t = d, k = "rg", flags = W.FF_RANGE, lo = 0, hi = 1 },
      { label = "Solo lectura", unit = "m", t = d, k = "info", flags = W.FF_INFO },
    },
    n = 8, cur = 0, top = 0,
    fk = { "Y=", "", "", "", "CALC" }, hint = "Pista del formulario",
    on_commit = function() d.chosen = d.chosen + 1 end,
  }
  return fm, d
end

do
  local fm, d = make_form()
  local r = run(function(t) t.v = W.form_run(fm) end)
  check(shown("Formulario"), "form: titulo")
  check(shown("Q libre"), "form: etiqueta")
  inside("form")
  -- editar con expresion del examen
  typed("0.5+1.0+4*1.10+10*0.30+3*0.3+3.0")
  check(shown("_"), "form: cursor de edicion")
  keys("enter")
  check(math.abs(d.q - 12.8) < 1e-9, "form: expresion = 12.8 (" .. tostring(d.q) .. ")")
  eq(fm.cur, 1, "form: ENTER avanza")
  eq(d.chosen, 1, "form: on_commit")
  -- POS rechaza 0
  typed("0"); keys("enter")
  check(shown("Debe ser mayor que 0"), "form: FF_POS")
  eq(fm.cur, 1, "form: no avanza con error")
  keys("esc")   -- borra el buffer
  typed("2.5"); keys("enter")
  eq(d.pos, 2.5, "form: pos=2.5")
  -- NONNEG
  typed("-1"); keys("enter")
  check(shown("No puede ser negativo"), "form: FF_NONNEG")
  keys("esc", "esc")  -- cancela edicion
  eq(d.nn, 0, "form: nn intacto")
  keys("down")
  eq(fm.cur, 3, "form: down a CHOICE")
  keys("right"); eq(d.ch, 2, "form: choice derecha")
  keys("right"); keys("right"); eq(d.ch, 1, "form: choice envuelve")
  keys("left"); eq(d.ch, 0, "form: choice izquierda")
  check(shown("Colebrook"), "form: texto de opcion")
  keys("down")
  typed("2.5"); keys("enter")
  check(shown("entero"), "form: FF_INT no entero")
  keys("esc"); typed("12"); keys("enter")
  check(shown("rango"), "form: FF_INT fuera de rango")
  keys("esc"); typed("7"); keys("enter")
  eq(d.i, 7, "form: entero ok")
  eq(fm.cur, 5, "form: avanza a OPT")
  -- OPT: vaciar con DEL y con edicion vacia
  d.optset = 1; d.opt = 3
  keys("backspace")
  eq(d.optset, 0, "form: DEL vacia FF_OPT")
  check(shown("--"), "form: valor vacio muestra --")
  typed("4"); keys("enter")
  check(d.optset == 1 and d.opt == 4, "form: OPT con valor")
  eq(fm.cur, 6, "form: avanza a RANGE")
  typed("1.5"); keys("enter")
  check(shown("rango"), "form: FF_RANGE")
  keys("esc"); typed("0.25"); keys("enter")
  eq(d.rg, 0.25, "form: rango ok")
  eq(fm.cur, 0, "form: salta el campo INFO y vuelve al inicio")
  check(not r.done, "form: sigue abierto")
  -- edicion del valor actual con flecha derecha, coma decimal y E
  keys("right"); keys("esc"); typed("1,5e-3"); keys("enter")
  check(math.abs(d.q - 1.5e-3) < 1e-12, "form: coma decimal y e minuscula (" .. tostring(d.q) .. ")")
  -- letras no inician edicion
  typed("x"); check(not shown("_"), "form: letra ignorada")
  -- F1 devuelve la tecla y la barra tiene sus etiquetas
  check(shown("CALC"), "form: barra F5")
  mock.click(mock.W - 10, mock.H - 5)
  eq(r.v, U.K_F5, "form: clic en F5 devuelve K_F5")
  -- form_check
  fm, d = make_form(); d.pos = 0
  local okc
  run(function(t) okc = W.form_check(fm); t.cur = fm.cur end)
  check(okc == false and fm.cur == 1 and fm.msg == "Debe ser mayor que 0", "form_check: detecta D=0")
  fm, d = make_form()
  run(function(t) okc = W.form_check(fm) end)
  check(okc == true, "form_check: valido")
  -- ENTER en el ultimo campo; restart
  fm, d = make_form(); fm.n = 7; fm.cur = 6
  r = run(function(t) t.v = W.form_run(fm) end)
  keys("enter")
  eq(r.v, U.K_ENTER, "form: ENTER en el ultimo campo devuelve K_ENTER")
  fm, d = make_form()
  fm.on_commit = function() fm.restart = 1 end
  r = run(function(t) t.v = W.form_run(fm) end)
  typed("9"); keys("enter")
  eq(r.v, U.K_NONE, "form: restart devuelve K_NONE")
  eq(fm.cur, 1, "form: restart avanza")
  -- get/put alternativos y desplazamiento con muchos campos
  local big = { v = {} }
  local f2 = { title = "Muchos", f = {}, n = 20, cur = 0, top = 0, fk = { "", "", "", "", "" } }
  for i = 1, 20 do
    big.v[i] = i
    f2.f[i] = { label = "Campo " .. i, unit = "u", flags = 0,
      get = function() return big.v[i] end, put = function(v) big.v[i] = v end }
  end
  r = run(function(t) t.v = W.form_run(f2) end)
  keys("up")
  eq(f2.cur, 19, "form: up envuelve al ultimo")
  check(shown("Campo 20"), "form: scroll al ultimo campo")
  check(not exact("Campo 1"), "form: primer campo fuera")
  typed("99"); keys("esc", "esc"); keys("esc")
  eq(r.v, U.K_CLEAR, "form: ESC sale con K_CLEAR")
  r = run(function(t) t.v = W.form_run(f2) end)
  keys("tab")
  eq(f2.cur, 19, "form: tab = ultimo")
  keys("backtab"); eq(f2.cur, 0, "form: backtab = primero")
  typed("55"); keys("enter")
  eq(big.v[1], 55, "form: put/get")
  -- png
  fm, d = make_form()
  run(function(t) t.v = W.form_run(fm) end)
  keys("down"); typed("12.5")
  png("form")
end

-- ============================================================ visor
do
  W.view_clear()
  for i = 1, 30 do W.view_add("Linea " .. i, U.C_FG) end
  W.view_add_val("caudal Q", 0.0123456, "m3/s")
  W.view_add_sep()
  local fk = { "", "", "", "", "SALIR" }
  local r = run(function(t) t.v = W.view_run("Visor", fk) end)
  check(shown("Linea 1"), "view: primera linea")
  check(shown("1/"), "view: indicador de pagina")
  keys("down", "down", "down")
  check(not exact("Linea 1") and exact("Linea 4"), "view: desplaza con flechas")
  keys("tab")
  check(shown("Linea 16"), "view: tab = pagina abajo")
  keys("tab", "tab", "tab")
  check(shown("m3/s"), "view: ultima pagina muestra view_add_val")
  check(shown("caudal Q"), "view_add_val etiqueta")
  keys("backtab")
  keys("esc")
  eq(r.v, U.K_CLEAR, "view: ESC")
  r = run(function(t) t.v = W.view_run("Visor", fk) end)
  mock.click(mock.W - 10, mock.H - 5)
  eq(r.v, U.K_F5, "view: clic F5")
end

-- ============================================================ lista
do
  for i = 0, 24 do W.list_line[i] = string.format("%2d  Elemento de lista %d", i + 1, i + 1) end
  local fk = { "NUEVO", "", "", "", "BORRAR" }
  local r = run(function(t) t.v, t.k = W.list_pick("Lista", nil, 25, 3, fk) end)
  check(shown("Elemento de lista 4"), "lista: muestra")
  keys("down", "enter")
  check(r.v == 4 and r.k == U.K_ENTER, "lista: ENTER devuelve 4")
  r = run(function(t) t.v, t.k = W.list_pick("Lista", nil, 25, 0, fk) end)
  keys("up", "enter")
  eq(r.v, 24, "lista: up envuelve")
  r = run(function(t) t.v, t.k = W.list_pick("Lista", nil, 25, 0, fk) end)
  mock.click(10, mock.H - 5)
  check(r.v == 0 and r.k == U.K_F1, "lista: F1 devuelve el indice actual")
  r = run(function(t) t.v, t.k = W.list_pick("Lista", nil, 0, 0, fk) end)
  check(shown("(vacio)"), "lista: vacia")
  keys("enter"); check(not r.done, "lista vacia: ENTER no hace nada")
  keys("esc"); check(r.v == -1 and r.k == U.K_CLEAR, "lista: ESC -1")
end

-- ============================================================ entrada de texto y alerta
do
  local r = run(function(t) t.ok, t.s = W.text_input("Nombre", "Nombre del caso:", "", 8) end)
  typed("pozo1x"); keys("backspace"); typed("2")
  check(shown("POZO12_"), "text_input: mayusculas y cursor")
  typed("123456789")
  keys("enter")
  check(r.ok == true and r.s == "POZO1212", "text_input: maxlen 8 (" .. tostring(r.s) .. ")")
  r = run(function(t) t.ok, t.s = W.text_input("Nombre", "Nombre:", "AB", 8) end)
  keys("esc")
  check(r.ok == false and r.s == "AB", "text_input: ESC cancela")
  r = run(function(t) t.ok, t.s = W.text_input("Nombre", "Nombre:", "", 8) end)
  keys("enter"); check(not r.done, "text_input: vacio no acepta")
  keys("esc")

  r = run(function(t)
    U.ui_begin("Fondo", nil); U.ui_text(1, 1, "texto de fondo", U.C_FG, U.C_BG); U.ui_end()
    t.a = U.ui_alert("Aviso", "Primera linea", "Segunda linea", U.C_WARN)
    t.b = U.ui_alert("Aviso 2", "L1", nil, U.C_ERR)
  end)
  check(shown("Aviso") and shown("Primera linea") and shown("texto de fondo"), "alert: sobre el fondo")
  inside("alert")
  keys("enter")
  check(r.a == true, "alert: ENTER true")
  keys("esc")
  check(r.b == false and r.done, "alert: ESC false")
  run(function() W.todo_alert("Algo", 3) end)
  check(shown("Disponible en la fase 3"), "todo_alert")
  keys("esc")
end

-- ============================================================ memoria de calculo
do
  local nprog, bad = 0, 0
  local function fill(flags_on)
    MR.memo_reset()
    for i = 0, MR.V_COUNT - 1 do MR.V[i] = 1.2345 * (1 + i % 7) end
    if flags_on then
      for g = 0, 31 do MR.FL[g] = true end
    end
    MR.W = flags_on and 4095 or 0
    MR.cfg = { method = 1, g = 9.81, gamma = 9810, nu = 1e-6, tol = 1e-5, re_lam = 2000,
      re_turb = 4000, ld_limit = 4000, v_min = 0.3, v_max = 5, pv = 2339, hm_ratio = 0.3,
      max_iter = 200 }
    local lg = H.new_log()
    for i = 1, 12 do H.hydro_log_row(lg, i, 0.01 * i, 2.5 * i, 1 / i, 12345.678 * i) end
    for i = 13, 40 do H.hydro_log_row(lg, i, 0.01 * i, 2.5 * i, 1 / i, 1e-7 * i) end
    MR.log = lg
    MR.dlist = { 0.05, 0.075, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.8, 1.0 }
    MR.dlist_n = 12
    MR.txt = "texto de prueba"
    MR.hook = function() W.view_add("(tabla por hook)", U.C_FG) end
    MR.listname = function() return "Lista de prueba" end
  end
  check(MR.memo_tx_open(), "PERDTXT valido")
  eq(MR.PROG_COUNT, 55, "PROG_COUNT")
  for pass = 1, 2 do
    fill(pass == 1)
    for prog = 0, MR.PROG_COUNT - 1 do
      local ok, err = pcall(MR.memo_show, prog)
      if not ok then bad = bad + 1; check(false, "memo prog " .. prog .. ": " .. tostring(err)) end
      if ok then
        nprog = nprog + 1
        for i = 1, W.view_n do
          if #W.view_line[i] > 40 then check(false, "memo prog " .. prog .. ": linea > 40") end
        end
        if pass == 1 and prog >= MR.S_COUNT then check(W.view_n > 0, "memo prog " .. prog .. " vacio") end
      end
    end
  end
  check(nprog == 2 * MR.PROG_COUNT, "todos los programas corrieron")
  -- ayuda y muestras visibles
  fill(true)
  check(MR.help_topic(0) and W.view_n > 3, "help_topic(0)")
  for i = 0, MR.HELP_COUNT - 1 do check(MR.help_topic(i) and W.view_n > 3, "help_topic " .. i) end
  -- contenido concreto: memoria tipo A con valores conocidos
  fill(false)
  MR.V[MR.V_Q] = 0.025; MR.V[MR.V_D] = 0.2; MR.V[MR.V_L] = 150; MR.V[MR.V_HF] = 3.4567
  MR.msetf(MR.G_FIX, true)
  MR.memo_show(MR.PROG_MEMO(MR.PT_A))
  local all = {}
  for i = 1, W.view_n do all[#all + 1] = W.view_line[i] end
  local txt = table.concat(all, "\n")
  check(txt:find("0.025", 1, true) ~= nil, "memo A contiene Q = 0.025")
  check(txt:find("3.4567", 1, true) ~= nil, "memo A contiene hf = 3.4567")
  -- memo_line corta y mfmt
  W.view_clear()
  M.memo_line("hT = hf + hm = 0.5 + 1.0 + 4*1.10 + 10*0.30 + 3*0.3 + 3.0 + 12.5E-6 + 7.77777 ok", U.C_FG)
  check(W.view_n >= 2 and #W.view_line[1] <= 40 and W.view_line[2]:sub(1, 6) == "      ",
    "memo_line corta en 40 columnas")
  eq(M.mfmt("a=%v b=%w c=%d d=%s %%", 1.5, 123.456789, 7, "x"), "a=1.5 b=123.457 c=7 d=x %", "mfmt")
  -- memo_table
  W.view_clear()
  M.memo_table({ "i", "hf", "v", "hm", "hf+1" }, 5, MR.log, { 1, 1, 1, 1, 1 })
  check(W.view_n >= 2 and W.view_line[W.view_n]:sub(1, 2) == "40", "memo_table ultima fila = 40")
  check(table.concat(W.view_line, "|", 1, W.view_n):find("...", 1, true) ~= nil, "memo_table salto '...'")
  -- imagen del visor
  fill(true)
  MR.memo_show(MR.PROG_MEMO(MR.PT_B))
  local fk = { "", "", "", "", "VOLVER" }
  run(function(t) t.v = W.view_run("Memoria de calculo B", fk) end)
  keys("down", "down", "down", "down")
  inside("memo")
  png("memo")
  keys("esc")
end

-- ============================================================ figuras del catalogo
do
  check(GC.gfxcat_open(), "PERDGFX valido")
  local r = run(function(t)
    for i = 0, GC.CAT_N - 1 do
      U.ui_begin("Figura " .. (i + 1), nil)
      GC.gfxcat_draw(i, true, 10, 10, 1)
      GC.gfxcat_draw(i, true, 120, 10, 2)
      GC.gfxcat_draw(i, false, 10, 120, 1)
      GC.gfxcat_draw(i, false, 60, 120, 2)
      GC.gfxcat_rect(200, 120, 50, 8, U.C_LE)
      U.ui_msg("figura", U.C_GRAY); U.ui_fbar({ "", "", "", "", "OK" }); U.ui_end()
      t.n = (t.n or 0) + 1
      U.ui_getkey()
    end
  end)
  for i = 1, GC.CAT_N do
    local ops = mock.paint()
    check(#ops > 50, "figura " .. i .. ": hay operaciones (" .. #ops .. ")")
    if i == 5 then png("catalogo") end
    keys("enter")
  end
  check(r.done and r.n == GC.CAT_N, "17 figuras dibujadas")
end

-- ============================================================ grafica LE / LP
do
  local segs = {
    { L = 100, jump = 0, hloc = 0.5, hfr = 2.0, vh = 0.2, name = "T1" },
    { L = 250, jump = 15, hloc = 0.3, hfr = 4.5, vh = 0.35, name = "T2" },
    { L = 60, jump = -3, hloc = 1.2, hfr = 0.8, vh = 0.8, name = "T3" },
  }
  local r = run(function(t) GR.graph_run("LE y LP", 20, segs, 3, 18.5, true) end)
  local ops = mock.paint()
  check(#ops > 30 and mock.has_text("LE"), "graph: dibuja")
  inside("graph")
  png("grafica")
  keys("esc")
  check(r.done, "graph: ESC vuelve")
  run(function(t) GR.graph_run("Sin tanque", 10, segs, 1, 0, false) end)
  mock.paint(); keys("enter")
  check(R.done, "graph: sin tanque 2")
  run(function(t) GR.graph_run("Vacia", 10, {}, 0, 0, false) end)
  mock.paint(); keys("f5" == nil and "esc" or "esc")
  check(R.done, "graph: 0 tramos")
end

-- ============================================================ menu inicial y errores
do
  mock.marked_changed = 0
  rt.start(rt.app_main)   -- reinicia con la app principal (menu inicial)
  check(shown("PERDIDAS / FLUJOS"), "inicio: titulo")
  check(shown("PERDIDAS - tuberias"), "inicio: opcion PERDIDAS")
  check(shown("FLUJOS - arrastre"), "inicio: opcion FLUJOS")
  inside("inicio")
  mock.key("1")
  check(shown("MENU PRINCIPAL"), "inicio: PERDIDAS abre su menu principal")
  keys("esc")
  keys("enter")                       -- confirma salir de PERDIDAS
  keys("enter")                       -- aviso de datos guardados
  check(shown("PERDIDAS / FLUJOS"), "inicio: vuelve del menu de PERDIDAS")
  mock.key("2")
  -- FLUJOS puede no existir aun (F4): aviso de modulo pendiente; si existe, su menu
  if shown("Modulo scr.flujos") then keys("enter") else
    keys("esc")
    for _ = 1, 3 do                   -- ESC en el menu de FLUJOS pide confirmar la salida
      if shown("PERDIDAS / FLUJOS") and not shown("Datos guardados") then break end
      keys("enter")
    end
  end
  check(shown("PERDIDAS / FLUJOS"), "inicio: vuelve del menu de FLUJOS")
  mock.key("3")
  check(shown("Guarde el documento"), "inicio: Salir avisa de guardar")
  keys("enter")
  check(mock.marked_changed > 0, "inicio: markChanged")
  check(shown("PERDIDAS / FLUJOS"), "inicio: vuelve al menu")
  -- Ajustes desde el menu inicial
  keys("menu")
  check(shown("AJUSTES"), "inicio: ajustes")
  keys("esc")

  -- guardar / restaurar
  U.g_set.dec = 4
  U.state.cas[1] = { nombre = "A", tipo = 0, datos = { v = { 1, 2, 3 } } }
  local t = mock.save()
  eq(t.ver, 3, "save: ver")
  eq(t.cfg.dec, 4, "save: cfg.dec")
  U.g_set.dec = 6; U.state.cas[1] = nil
  mock.restore(t)
  check(U.g_set.dec == 4 and U.state.cas[1] and U.state.cas[1].datos.v[3] == 3, "restore: cfg y cas")
  mock.restore({ ver = 99, cfg = { dec = 1 } })
  eq(U.g_set.dec, 4, "restore: version futura ignorada")
  U.g_set.dec = 6; U.state.cas[1] = nil

  -- error de la corrutina se muestra
  rt.start(function() local x = nil; return x.campo end)
  check(shown("Error de la app"), "error: pantalla de error")
  check(mock.has_text("campo") or #mock.screen_text() > 3, "error: mensaje")
  png("error")
  rt.start(function() error("boom") end)
  check(shown("boom"), "error: texto del error")
  keys("enter")                       -- reinicia con la funcion previa: otra vez error
  check(shown("Error de la app"), "error: reinicio")
  -- restaurar la app real
  rt.start(function() end)
  mock.paint()
  check(rt.finished, "app termina limpiamente")

  -- redimensionado: el cuadro se rehace con la nueva geometria
  run(function(t) t.v = W.menu_run({ title = "R", items = { "a", "b" }, n = 2, cur = 0 }) end)
  mock.W, mock.H = 480, 320
  env.on.resize(480, 320)
  mock.paint()
  local tt = mock.screen_text()
  local maxx = 0
  for _, x in ipairs(tt) do if x.x > maxx then maxx = x.x end end
  check(maxx > 318 - 20 and #tt > 3, "resize: usa el ancho nuevo")
  mock.W, mock.H = 318, 212
  env.on.resize(318, 212)
end

print(string.format("test_ui: %d comprobaciones, %d fallo(s)", checks, fails))
if fails > 0 then os.exit(1) end
print("test_ui OK")
