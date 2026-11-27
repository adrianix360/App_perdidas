r"""Soluciones de referencia (oraculo) de los ejercicios de los examenes IC-605.

Resuelve en Python (double) cada ejercicio de los PDF de la carpeta del curso y
imprime los valores que la app Lua debe reproducir. Sirve de fuente para los
casos dorados de tests/test_examenes.lua. g = 9.81, gamma = 9810 salvo aviso.
Uso: python -I tools/oracle_examenes.py
"""
import math

g = 9.81
GW = 9810.0
PI = math.pi
OUT = []


def out(id_, **kv):
    OUT.append((id_, kv))
    s = ", ".join(f"{k}={v:.6g}" if isinstance(v, float) else f"{k}={v}" for k, v in kv.items())
    print(f"{id_}: {s}")


def bisect(f, a, b, tol=1e-12, it=200):
    fa = f(a)
    for _ in range(it):
        m = 0.5 * (a + b)
        fm = f(m)
        if (fa < 0) == (fm < 0):
            a, fa = m, fm
        else:
            b = m
        if b - a < tol:
            break
    return 0.5 * (a + b)


def simpson(f, a, b, n=2000):
    h = (b - a) / n
    s = f(a) + f(b)
    for i in range(1, n):
        s += (4 if i % 2 else 2) * f(a + i * h)
    return s * h / 3


# ---------------- vertedores / orificios ----------------
def q_rect(Cd, b, H):
    return Cd * 2 / 3 * math.sqrt(2 * g) * b * max(H, 0) ** 1.5


def q_tri(Cd, th_deg, H):
    return Cd * 8 / 15 * math.sqrt(2 * g) * math.tan(math.radians(th_deg) / 2) * max(H, 0) ** 2.5


def q_orif(Cd, A, h):
    return Cd * A * math.sqrt(2 * g * max(h, 0))


# EjercicioResueltoVertedores P4 (dos tanques: orificio + vertedor rect)
A_or = PI * 0.35 ** 2 / 4
Q = 0.25
hc = bisect(lambda h: q_rect(0.6, 1.5, h) - Q, 0, 5)
dh = bisect(lambda h: q_orif(0.6, A_or, h) - Q, 0, 50)
out("VERT-P4a", hc=hc, HB=2 + hc, dh=dh, HA=2 + hc + dh)
# c) rebalse: HA = 3.5 ; incognita H2 (nivel B)
def HA_of_HB(HB):
    q = q_rect(0.6, 1.5, HB - 2)
    return HB + bisect(lambda h: q_orif(0.6, A_or, h) - q, 0, 50)
HB = bisect(lambda x: HA_of_HB(x) - 3.5, 2.0001, 3.5)
out("VERT-P4c", hc=HB - 2, Qmax_ls=q_rect(0.6, 1.5, HB - 2) * 1000)

# Parcial2-2025 P3: tanque2 (aguas arriba, vert rect L=1 cresta 1.1) --orificio 0.2x0.5--> tanque1
# tanque1: orificio riego D=0.2 centro 0.1; vert rect L=0.6 cresta 1.0; vert tri 90 cresta 1.059
def p3(H1):
    Qr = q_orif(0.6, PI * 0.2 ** 2 / 4, H1 - 0.1)
    Q1 = q_rect(0.6, 0.6, H1 - 1.0)
    QT = q_tri(0.6, 90, H1 - 1.059)
    Qor = Qr + Q1 + QT
    dh = (Qor / (0.6 * 0.1 * math.sqrt(2 * g))) ** 2
    H2 = H1 + dh
    Q2 = q_rect(0.6, 1.0, H2 - 1.1)
    return dict(Qr=Qr * 1e3, Q1=Q1 * 1e3, QT=QT * 1e3, Qor=Qor * 1e3, H2=H2, Q2=Q2 * 1e3, QE=(Qor + Q2) * 1e3)
out("P2-2025-P3a", H1=1.059, **p3(1.059))
H1b = 1.059 + bisect(lambda h: q_tri(0.6, 90, h) - 0.05, 0, 5)
out("P2-2025-P3b", H1=H1b, **p3(H1b))

# Final 2025 P4 vertedor triangular 90
for nm, q in (("a", 0.2), ("b", 0.26064)):
    out(f"FIN-2025-P4{nm}", H=bisect(lambda h: q_tri(0.6, 90, h) - q, 0, 5))

# ---------------- tuberias ----------------
def colebrook(Re, rr):
    f = 0.25 / math.log10(rr / 3.7 + 5.74 / Re ** 0.9) ** 2
    for _ in range(100):
        f = (-2 * math.log10(rr / 3.7 + 2.51 / (Re * math.sqrt(f)))) ** -2
    return f


nu = 1e-6
L, ks, K, H = 1900, 1.5e-6, 12.8, 76.0
def head(D, Q):
    v = 4 * Q / (PI * D * D); f = colebrook(v * D / nu, ks / D)
    return f * L / D * v * v / (2 * g) + K * v * v / (2 * g), f, v
D = bisect(lambda d: head(d, 0.2)[0] - H, 0.05, 1)
out("FIN-2025-P1a", D_mm=D * 1000)
Dc = 0.28575
Qm = bisect(lambda q: head(Dc, q)[0] - H, 1e-4, 2)
out("FIN-2025-P1b", D_mm=285.75, Q_ls=Qm * 1000, v=4 * Qm / (PI * Dc ** 2))
hT, f, v = head(Dc, 0.2)
hf = f * L / Dc * v * v / (2 * g)
hv = H - hT
out("FIN-2025-P2", f=f, v=v, hf=hf, hm=hT - hf, hv=hv, Kv=hv * 2 * g / v ** 2)
out("FIN-2025-P3a", Pb_kW=GW * hv * 0.2 / 1e3, Pn_kW=0.65 * GW * hv * 0.2 / 1e3)
HB = H + hT
out("FIN-2025-P3b", HB=HB, Pn_kW=GW * 0.2 * HB / 1e3, Peje_kW=GW * 0.2 * HB / 0.6 / 1e3)
# Venturi Qmax
V1 = 4 * Qm / (PI * Dc ** 2); V2 = V1 / 0.36
dP = 1000 * (V2 ** 2 - V1 ** 2) / 2
out("FIN-2025-P4c", V1=V1, V2=V2, dP=dP, h_S_1=dP / (3 * GW))
# P5 tres tuberias, f fijo
def M(f, L, D, K):
    return 8 / (g * PI ** 2) * (f * L / D ** 5 + K / D ** 4)
MA, MB, MC = M(0.014, 500, 0.15, 0), M(0.018, 600, 0.10, 0), M(0.015, 700, 0.2, 5)
MAB = 1 / (1 / math.sqrt(MA) + 1 / math.sqrt(MB)) ** 2
Qt = math.sqrt(20 / (MAB + MC)); hAB = 20 - MC * Qt ** 2
out("FIN-2025-P5", QA=math.sqrt(hAB / MA) * 1e3, QB=math.sqrt(hAB / MB) * 1e3, QC=Qt * 1e3)
# chorro: tanque 10 m, tubo D=0.03 L=5 30 grados, ks=0.045mm, salida z=2.5
def hj(q):
    D = 0.03; v = 4 * q / (PI * D * D); f = colebrook(v * D / nu, 0.045e-3 / D)
    return f * 5 / D * v * v / (2 * g) + v * v / (2 * g)
q = bisect(lambda q: hj(q) - 7.5, 1e-6, 1)
v = 4 * q / (PI * 0.03 ** 2)
out("FIN-2025-chorro (hf + v2/2g = 7.5)", Q_ls=q * 1e3, v=v, hmax=(v * math.sin(math.radians(30))) ** 2 / (2 * g))
def hj2(q):
    D = 0.03; v = 4 * q / (PI * D * D); f = colebrook(v * D / nu, 0.045e-3 / D)
    return f * 5 / D * v * v / (2 * g)
q = bisect(lambda q: hj2(q) - 7.5, 1e-6, 1)
v = 4 * q / (PI * 0.03 ** 2)
out("FIN-2025-chorro (hoja: hf = 7.5)", Q_ls=q * 1e3, v=v, hmax=(v * 0.5) ** 2 / (2 * g))

# ---------------- viscosidad ----------------
def bearing_T(mu, D, L, e, rpm):
    w = rpm * 2 * PI / 60
    return PI * mu * w * D ** 3 * L / (4 * e)
out("EPS-P1a", T=bearing_T(0.005, 0.08, 1, 1e-4, 500))
w = 4 * 0.2 * 2e-4 / (PI * 0.005 * 0.08 ** 3 * 2)
out("EPS-P1b", w=w, rpm=w * 60 / (2 * PI))
T = bearing_T(0.2, 0.04, 0.06, 1e-4, 1250)
out("P1-2024-P1", T=T, P=T * 1250 * 2 * PI / 60)
# placa entre pared fija (1 mm arriba) y pared movil -0.3 m/s (2.6 mm abajo)
mu, A, V = 0.0027, 0.16, 1.0
tau_up = mu * (V - 0) / 1e-3
tau_dn = mu * (V - (-0.3)) / 2.6e-3
out("P1-2018-P4", F=(tau_up + tau_dn) * A, y0_mm=0.3 / 1.3 * 2.6)
# bloque en rampa: F horizontal, W, theta
def ramp(W, th, mu, A, V, t):
    Fv = mu * A * V / t
    return (Fv + W * math.sin(math.radians(th))) / math.cos(math.radians(th))
out("P1-2022-P1", F=ramp(150, 20, 0.015, 0.25, 1.2, 5e-4))
out("P1-2017-P3a", F=ramp(150, 20, 0.012, 0.25, 0.8, 4e-4))
th = math.radians(20); mus = 0.27
Fx = (150 * math.sin(th) + mus * 150 * math.cos(th)) / (1 - mus * math.tan(th))
out("P1-2017-P3b", F=Fx / math.cos(th))

# ---------------- hidrostatica ----------------
gc = 2.5 * GW
out("EPS-P2-1", F=gc * 1.5 / 2 * 1.5 * 6)
out("EPS-P2-2", F=gc * (4 + 1.5) / 2 * math.hypot(2.5, 1) * 6)
out("EPS-P2-3", F=gc * (4 / 2 * 4 * 1 + (2 * 4 + 1.5) / 3 * (1 * 2.5 / 2)))
out("EPS-P3a", Fperno=GW * 1.5 * 0.16 / 2 * (0.75 + 3 - PI * 1.5 / 8))
FH = GW * (5 + 2.5) * 5 * 2; FV = GW * 2 * 5 * (5 + PI * 5 / 4)
out("EPS-P3b", FH=FH, FV=FV, F=FV)
# compuerta en L: h^3 - 4.32h - 0.102384 = 0  (ancho 3, tapa 1.2, lamina 3mm S=7.9)
Wp = 0.003 * 1.2 * 3 * 7.9 * GW
h = bisect(lambda h: (1.2 * h * 3 * GW + Wp) * 0.6 - GW * h * h / 2 * 3 * h / 3, 0.5, 10)
out("P1-2018-P2", H=h)
out("P1-2018-P3", Pa=(13.6 * 0.45 - 0.85 * 0.3 - 0.2) * GW)
out("P1-2017-P1", d_mm=(2700 / GW - 13.6 * 0.02 + 0.6 * 0.06) / 1.4 * 1000)
# compuerta circular inclinada 30 deg
gn = 1.1 * GW; A = PI * 2.4 ** 2 / 4; yc = 3 / math.cos(math.radians(30))
out("P1-2022-P2", F=gn * 3 * A, yp=yc + (PI * 1.2 ** 4 / 4) / (yc * A))
# superficie curva cuarto de circulo R=1.2, 2.8 m sobre el tope, w=1
R = 1.2; FH = GW * (2.8 + R / 2) * R
FV1 = GW * ((2.8 + R) * R - PI * R * R / 4); FV2 = GW * (2.8 * R + PI * R * R / 4)
out("P1-2022-P3-1", FH=FH, FV=FV1, F=math.hypot(FH, FV1), ang=math.degrees(math.atan2(FV1, FH)))
out("P1-2022-P3-2", FH=FH, FV=FV2, F=math.hypot(FH, FV2), ang=math.degrees(math.atan2(FV2, FH)))
# 2017 P2 compuerta plana 45 deg, longitud l, bisagra a l/4 de profundidad (por gamma l^2 w)
l = 1.0; s = math.sin(math.radians(45))
hc = l / 4 + l * s / 2; A = l
F = hc * A; yc = hc / s; yp = yc + (l ** 3 / 12) / (yc * A)
out("P1-2017-P2plana", F_gl2w=F, dist_B=yp - (l / 4) / s, RA=F * (yp - (l / 4) / s) / l)

# ---------------- flotacion ----------------
def hollow_cyl(e, Di, H, S):
    Do = Di + 2 * e
    Vc = PI / 4 * (Do ** 2 * H - Di ** 2 * (H - e))
    h = S * Vc / (PI / 4 * Do ** 2)
    zG = (Do ** 2 * H ** 2 / 2 - Di ** 2 * ((H) ** 2 - e ** 2) / 2) / (Do ** 2 * H - Di ** 2 * (H - e))
    zB = h / 2
    I = PI * Do ** 4 / 64; Vd = PI / 4 * Do ** 2 * h
    return h, zB, zG, I / Vd - (zG - zB)
h, zB, zG, GM = hollow_cyl(0.25, 3, 4.5, 2.5)
out("EPS-P4a", h=h, zB=zB, zG=zG, GM=GM)
h, zB, zG, GM = hollow_cyl(0.25, 3, 0.75, 2.5)
out("EPS-P4b (H=3e)", h=h, zB=zB, zG=zG, GM=GM)
# prisma triangular (equilatero altura 0.6, base 0.69 -> se usa base = 2*0.6/sqrt(3))
hT = 0.6; bT = 2 * hT / math.sqrt(3)
At = bT * hT / 2
h = math.sqrt(2 * 0.7 * At * hT / bT)
out("P1-2018-P1a", b=bT, h=h)
# vertice arriba: sumergido trapecio altura h desde la base
h = bisect(lambda h: (bT * h - bT / hT * h * h / 2) - 0.3 * At, 0, hT)
out("P1-2018-P1b", h=h)
# barcaza 2022: rect 2.4 ancho x 1.2 alto + triangulo 0.6 abajo, 7.5 largo, calado 1.5
b, Lb = 2.4, 7.5
Vb = (b * 1.2 + b * 0.6 / 2) * Lb; Vd = (b * 0.9 + b * 0.6 / 2) * Lb
yB = (b * 0.9 * (0.6 + 0.45) + b * 0.3 * 0.4) / (b * 0.9 + b * 0.3)
yG = (b * 1.2 * (0.6 + 0.6) + b * 0.3 * 0.4) / (b * 1.2 + b * 0.3)
I = Lb * b ** 3 / 12
out("P1-2022-P4", rho=1000 * Vd / Vb, yB=yB, yG=yG, GM=I / Vd - (yG - yB))
# cubo 1 m, rho 500
out("P1-2017-P4i", h=0.5, GM=(1 / 12) / 0.5 - (0.5 - 0.25))
h = math.sqrt(0.5); bw = 2 * h
out("P1-2017-P4ii", h=h, GM=(1 * bw ** 3 / 12) / 0.5 - (math.sqrt(2) / 2 - 2 * h / 3))

# ---------------- equilibrio relativo ----------------
ay = g * (0.3 - 0.2) / 0.5
out("EPS-P5b", ay=ay, P1=1000 * (g + ay) * 0.2, P2=1000 * (g - ay) * 0.3)
dz = 2.5 / g * 7
out("P1-2018-P5", dz=dz, Pmax_kPa=(100000 + GW * (dz + 3)) / 1000)
gf = 0.9 * GW; ax = 4.903
out("P1-2022-P5", PB=gf * (1.2 - ax / g * 1.8), PC=gf * 1.35 + 900 * ax * 0.15, ax0=1.2 * g / 1.8)

# ---------------- perfiles de velocidad ----------------
out("EPS-P5a", Q=2 / 3 * 1 * 8 * 1, Vm=2 / 3, Re=2 / 3 * 1 / 1.007e-6)
Qc = simpson(lambda y: 2 * (y / 1) ** 2 * 2, 0, 1)
out("P2-2024-P4a", Q=Qc)
out("P2-2024-P4b", H=bisect(lambda h: q_tri(0.6, 90, h) - Qc, 0, 5))
v1 = Qc / 2
y2 = bisect(lambda y: y + (Qc / (2 * y)) ** 2 / (2 * g) - (1 + v1 ** 2 / (2 * g)), 0.05, 0.5)
out("P2-2024-P4c", h1=y2, v2=Qc / (2 * y2))
r0, vm = 0.2, 2.0
Qp = simpson(lambda r: vm * (1 - r * r / r0 ** 2) * 2 * PI * r, 0, r0)
Vb_ = Qp / (PI * r0 ** 2)
al = simpson(lambda r: (vm * (1 - r * r / r0 ** 2) / Vb_) ** 3 * 2 * PI * r, 0, r0) / (PI * r0 ** 2)
be = simpson(lambda r: (vm * (1 - r * r / r0 ** 2) / Vb_) ** 2 * 2 * PI * r, 0, r0) / (PI * r0 ** 2)
out("VAR-parabolico", Q=Qp, V=Vb_, alfa=al, beta=be)

# ---------------- continuidad / Bernoulli / momentum ----------------
Qh = 12e-3 / 50
out("VAR-Ej1", Q=Qh, mdot=1000 * Qh, V12=4 * Qh / (PI * 0.012 ** 2), V5=4 * Qh / (PI * 0.005 ** 2))
V1 = 4 * 0.12 / (PI * 0.22 ** 2); V2 = 4 * 0.12 / (PI * 0.10 ** 2)
dP = 1.2 * (V2 ** 2 - V1 ** 2) / 2
out("P2-2025-P1", V1=V1, V2=V2, dP=dP, h_mm=dP / (GW - 1.2 * g) * 1000, h_mm_hoja=dP / GW * 1000)
v2 = math.sqrt(2 * g * 3.6); Qd = v2 * PI * 0.05 ** 2 / 4; vt = Qd / (PI * 0.15 ** 2 / 4)
hv = vt ** 2 / (2 * g)
out("P2-2024-P2", Q_ls=Qd * 1e3, PA=GW * (6 - 0 - hv), PB=GW * (6 - 6 - hv), PC=GW * (6 - 7.5 - hv), PD=GW * (6 - 2.4 - hv))
D1, D2, V1, p1 = 0.2, 0.15, 2.5, 10000
A1, A2 = PI * D1 ** 2 / 4, PI * D2 ** 2 / 4
Qc = V1 * A1; V2 = Qc / A2
p2 = p1 + 1000 * (V1 ** 2 - V2 ** 2) / 2 - GW * 2
th = math.radians(45)
Rx = p1 * A1 - p2 * A2 * math.cos(th) - 1000 * Qc * (V2 * math.cos(th) - V1)
Ry = -p2 * A2 * math.sin(th) - 1000 * Qc * (V2 * math.sin(th))
out("P2-2024-P3", Q_ls=Qc * 1e3, V2=V2, p2=p2, Rx=Rx, Ry=Ry, R=math.hypot(Rx, Ry))

# flyboard (rho 1040)
rho = 1040; A1 = PI * 0.1 ** 2 / 4; A2 = PI * 0.05 ** 2 / 4; Wt = 130 * g
# V2 = 2*V1*(A1/(2A2))... continuidad Q1 = 2 Q2 -> V1 A1 = 2 V2 A2 -> V2 = V1*A1/(2A2) = 2 V1
# Momentum en y sobre VC (manguera entra en 1, salen 2 chorros hacia abajo):
# P1 A1 - W = -(2 rho A2 V2^2 cos10) - rho A1 V1^2   (hoja)
def fly(V2):
    V1 = V2 * 2 * A2 / A1
    P1 = rho * (V2 ** 2 - V1 ** 2) / 2
    return P1 * A1 + rho * A1 * V1 ** 2 + 2 * rho * A2 * V2 ** 2 * math.cos(math.radians(10)) - Wt
V2 = bisect(fly, 0.1, 100); V1 = V2 * 2 * A2 / A1; Qf = V1 * A1
P1 = rho * (V2 ** 2 - V1 ** 2) / 2
P0 = P1 + rho * g * 6.5
HBf = P0 / (rho * g) + V1 ** 2 / (2 * g)
out("P2-2025-P5", V2=V2, V1=V1, Q=Qf, P0_kPa=P0 / 1e3, HB=HBf, Pot_kW=rho * g * Qf * HBf / 1e3)

# ---------------- arrastre ----------------
for V in (120, 90):
    v = V / 3.6
    out(f"P2-2025-P4 {V}", PA_kW=0.5 * 1.2 * 0.21 * 2.4 * v ** 3 / 1e3, PB_kW=0.5 * 1.2 * 0.20 * 2.45 * v ** 3 / 1e3)
V = 125 / 3.6; w = 4800 * 2 * PI / 60; D = 0.065
Ap = PI * D ** 2 / 4
out("P2-2024-P5", SR=w * D / (2 * V), W=0.06 * g, FB=1.25 * g * PI * D ** 3 / 6, FL_CL012=0.12 * 1.25 * Ap * V ** 2 / 2)

# ---------------- tanques no permanentes ----------------
def rk4(f, y, t0, t1, n=20000):
    h = (t1 - t0) / n; t = t0
    for _ in range(n):
        k1 = f(t, y); k2 = f(t + h / 2, y + h / 2 * k1); k3 = f(t + h / 2, y + h / 2 * k2); k4 = f(t + h, y + h * k3)
        y += h / 6 * (k1 + 2 * k2 + 2 * k3 + k4); t += h
    return y
y90 = rk4(lambda t, y: (0.1 - 0.1 * (1 + math.sin(t / (8 * PI)))) / 4, 5.0, 0, 90)
Qs = 0.1 * (1 + math.sin(90 / (8 * PI)))
out("P2-2024-P1", y=y90, Qs=Qs, v=Qs / (PI * 0.15 ** 2 / 4))
At = PI * 12 ** 2 / 4
t = bisect(lambda t: At * 6.5 + 0.1 * t - 0.4 * 18000 * math.sin(t / 18000), 100, 6000)
out("P2-2025-P2", t=t)
# Ejemplo 2: D tanque 1.5, orificio 0.15 m (como en la hoja), baja 1 m desde 2 m
r = (1.5 / 0.15) ** 2
t = r * simpson(lambda y: 1 / math.sqrt(2 * g * (2 - y)), 0, 1)
a = PI * 0.15 ** 2 / 4
out("VAR-Ej2", t=t, Q0=a * math.sqrt(2 * g * 2), Q1=a * math.sqrt(2 * g * 1))
# tanque 3 m, A=20, tubo 150 mm, sin friccion
a = PI * 0.15 ** 2 / 4
out("VAR-3m", t=2 * 20 * math.sqrt(3) / (a * math.sqrt(2 * g)), V2_0=math.sqrt(2 * g * 3), dV2dt=-a * g / 20)
# tanque 5 m, Qe=0.1, A0=36, orificio 150 mm, carga sobre orificio; vacia hasta h0=0.5 ?
a = PI * 0.15 ** 2 / 4
heq = (0.1 / a) ** 2 / (2 * g)
out("VAR-5m", h_equilibrio=heq, nota="Qe=100 l/s > Qs(5 m)=%.4f m3/s: el nivel no baja de %.3f m" % (a * math.sqrt(2 * g * 5), heq))
