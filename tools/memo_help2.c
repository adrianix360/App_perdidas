/*
 * memo_help2.c - Temas de ayuda de la v2.0 (lo incluye memo_tables.c).
 * Lineas de 40 caracteres como maximo.
 */

static const mstep h_fric[] = {
    LN("FACTOR DE FRICCION f", C_TITLE), SEP,
    TX("PERDIDAS > 3 Calcular f (o Tuberia 8)."),
    TX("Modos (F2 MODO): Re y ks/D directos, o"),
    TX("datos de tuberia (Q o v, D, ks, nu)."),
    TG("Re < 2000: laminar, f = 64/Re."),
    TG("2000 a 4000: transicion; CW indicativo."),
    TX("Metodos (Ajustes > Metodo de f):"),
    TX(" Colebrook-White: el del curso,"),
    TG("  implicito; sustitucion desde 0.0001."),
    TX(" Swamee-Jain: explicito, usado en las"),
    TG("  soluciones 2024-2025 (D exacto)."),
    TG("  Valido Re 5E3-1E8, ks/D 1E-6 a 1E-2."),
    TX(" Haaland (coef. 1.8 del curso) y"),
    TX(" Goudar-Sonnad: explicitos, para"),
    TG("  comparar (tabla del resultado)."),
    TX("Zona: k+ = (ks/D) Re sqrt(f/8);"),
    TG(" < 5 lisa, 5-70 transicion, > 70 rugosa"),
    TX("USAR f lleva el valor al formulario que"),
    TX("abrio la pantalla (F4 CALC f en A, B,"),
    TX("C y F; F1 en Sistemas, sobre el f)."),
    STOP
};

static const mstep h_drag[] = {
    LN("ARRASTRE Y SUSTENTACION", C_TITLE), SEP,
    TX("FD = 0.5 rho CD A V^2  (A frontal)"),
    TX("FL = 0.5 rho CL A V^2  (A en planta)"),
    TX("Re = V L/nu; L = D salvo que se de."),
    TX("AR-2: W - B = FD; en agua B = rho g V."),
    TX("AR-3: Fi a su cota yi; M = suma Fi yi."),
    TX("AR-4: CL = W/(q A); lea alfa y CD en"),
    TX("  la grafica y escribalos (paso 2)."),
    TG("  rho(h) = 1.3(1 - 2.26E-5 h)^4.256"),
    TX("Catalogo (F1 CD): 17 figuras, tablas"),
    TX("  por L/D, b/h o angulo; EDITAR guarda"),
    TX("  un CD propio. Area con la formula"),
    TX("  de la figura si no se teclea A."),
    TX("Avisos: Re < 1E4 fuera de la tabla;"),
    TX("  crisis de arrastre (esfera > 2E5,"),
    TX("  cilindro largo > 5E5); Re < 1 usa"),
    TX("  Stokes (CD = 24/Re en la esfera)."),
    TX("Placa: Cf = 1.328/sqrt(Re) laminar,"),
    TX("  0.074/Re^0.2 turb., - 1742/Re mixto."),
    STOP
};

static const mstep h_weir[] = {
    LN("VERTEDORES Y ORIFICIOS", C_TITLE), SEP,
    TX("Triangular: Q = Cd 8/15 sqrt(2g)"),
    TX("  tan(theta/2) H^2.5 (H desde vertice)"),
    TX("Rectangular: Q = Cd 2/3 sqrt(2g) b H^1.5"),
    TG("  Francis: be = b - 0.1 n H (opcional)"),
    TX("Orificio: Q = Cd A sqrt(2 g H), con H"),
    TX("  hasta el CENTRO del orificio."),
    TX("Cd por defecto 0.6 (Ajustes), editable."),
    TX("Compuesta: hasta 8 elementos con cota"),
    TX("  z; Qi = 0 si h <= z. Dado Q, nivel por"),
    TX("  biseccion. Reparto: Qi del resultado."),
    TX("Cota de la cresta: h0 = h - H (dado el"),
    TX("  nivel aguas arriba, modo Q -> H)."),
    TX("Perfil: v = k y^n -> Q = b k h^(n+1)/"),
    TX("  (n+1); o puntos con Simpson."),
    TX("Aguas abajo: v = Q/(b h), E = h + v^2/2g"),
    TX("  y tirantes alternos con E2 = E1 - dz."),
    STOP
};

static const mstep h_chan[] = {
    LN("CANALES Y MEDICION", C_TITLE), SEP,
    TX("Venturi: v2 = v1 (D1/D2)^2;"),
    TX("  dp = gamma (v2^2 - v1^2)/2g."),
    TX("  Manometro: dp = (S - 1) gamma h"),
    TG("  (fisico, por defecto) o S gamma h"),
    TG("  (solucion 2025; Ajustes > Manometro)"),
    TX("Salto: Fr1 = v1/sqrt(g y1);"),
    TX("  y2 = y1/2 (sqrt(1 + 8 Fr1^2) - 1);"),
    TX("  dE = (y2 - y1)^3/(4 y1 y2);"),
    TX("  P = gamma Q dE."),
    TX("Chorro: Q con la tuberia tipo B; luego"),
    TX("  h max = (v sin t)^2/2g,"),
    TX("  R = v^2 sin(2t)/g."),
    TG("  Energia de salida: Suma K + 1 (opc.)"),
    TX("Placa plana y Stokes: Canales 4 (o"),
    TX("  Arrastre 5)."),
    STOP
};
