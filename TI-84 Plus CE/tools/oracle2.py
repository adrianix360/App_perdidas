"""
oracle2.py - Oraculo independiente (Python, doble precision) de las formulas
nuevas de la v2.0. Genera casos aleatorios en rangos realistas y escribe
tests/random_cases2.csv (o la ruta del primer argumento).

Cada fila: tipo;x1;...;x9;r1;r2  (las x sobrantes van en 0)
  T velocidad terminal     x: W rho vol Cd A            r: v
  S estructura (3 cuerpos) x: V rho Cd1 A1 y1 Cd2 A2 y2 Cd3   (A3 = 10, y3 = 5)
                           r: Ftot M
  Q compuesto, dado h      x: th zt b zr d zo n Cd h    r: Qtot
  H compuesto, dado Q      x: th zt b zr d zo n Cd Q    r: h
  V Venturi (fisico)       x: D1 beta Q S               r: dp h
  J salto hidraulico       x: Q b y1                    r: y2 dE
  P placa plana            x: L V nu                    r: Cf_turb Cf_mix
  F friccion               x: Re ksD m                  r: f   (m: 0 CW,1 SJ,2 Haaland,3 GS)
Las formulas se escriben aqui otra vez a proposito (sin copiar el motor C).
"""
import csv
import math
import random
import sys

G = 9.81
GAMMA = 9810.0
N = 75
SEED = 20261115


def tri(cd, th, H):
    return cd * 8.0 / 15.0 * math.sqrt(2 * G) * math.tan(math.radians(th) / 2) * H ** 2.5 if H > 0 else 0.0


def rect(cd, b, H):
    return cd * 2.0 / 3.0 * math.sqrt(2 * G) * b * H ** 1.5 if H > 0 else 0.0


def orif(cd, d, hc):
    return cd * math.pi * d * d / 4.0 * math.sqrt(2 * G * hc) if hc > 0 else 0.0


def comp(x, h):
    th, zt, b, zr, d, zo, n, cd = x[:8]
    return tri(cd, th, h - zt) + rect(cd, b, h - zr) + n * orif(cd, d, h - zo)


def comp_level(x, Q):
    lo = min(x[1], x[3], x[5])
    hi = lo + 1.0
    while comp(x, hi) < Q:
        lo, hi = hi, hi * 2 + 1
    for _ in range(300):
        m = 0.5 * (lo + hi)
        if comp(x, m) > Q:
            hi = m
        else:
            lo = m
    return 0.5 * (lo + hi)


def f_cw(re, k):
    """Colebrook-White por Newton sobre x = 1/sqrt(f)."""
    a, b, x = k / 3.7, 2.51 / re, 8.0
    for _ in range(100):
        u = a + b * x
        xn = x - (x + 2 * math.log10(u)) / (1 + 2 * b / (u * math.log(10)))
        if abs(xn - x) < 1e-15 * xn:
            break
        x = xn
    return 1 / (xn * xn)


def f_method(re, k, m):
    if m == 0:
        return f_cw(re, k)
    if m == 1:
        return 0.25 / math.log10(k / 3.7 + 5.74 / re ** 0.9) ** 2
    if m == 2:   # Haaland con 1,8 (motor v1.0, material del curso)
        return (-1.8 * math.log10((k / 3.7) ** 1.11 + 6.9 / re)) ** -2
    c = 0.124 * re * k + math.log(0.4587 * re)
    return (0.8686 * math.log(0.4587 * re / (c - 0.31) ** (c / (c + 1)))) ** -2


def lu(r, a, b):
    return math.exp(r.uniform(math.log(a), math.log(b)))


def main():
    r = random.Random(SEED)
    rows = []
    for _ in range(N):
        W, rho, Cd, A = lu(r, 1, 5e4), r.choice((1.2, 1000.0)), r.uniform(0.05, 2), lu(r, 1e-3, 100)
        vol = 0.0 if rho < 2 else W / (rho * G) * r.uniform(0, 0.9)
        v = math.sqrt(2 * (W - rho * G * vol) / (rho * Cd * A))
        rows.append(["T", W, rho, vol, Cd, A, 0, 0, 0, 0, v, 0])
    for _ in range(N):
        V, rho = r.uniform(1, 60), 1.2
        b = [(r.uniform(0.1, 2), lu(r, 0.5, 200), r.uniform(0, 80)) for _ in range(2)]
        cd3 = r.uniform(0.1, 2)
        q = 0.5 * rho * V * V
        F = [cd * a * q for cd, a, _ in b] + [cd3 * 10 * q]
        M = F[0] * b[0][2] + F[1] * b[1][2] + F[2] * 5
        rows.append(["S", V, rho, b[0][0], b[0][1], b[0][2], b[1][0], b[1][1], b[1][2], cd3, sum(F), M])
    for kind in "QH":
        for _ in range(N):
            x = [r.uniform(20, 120), r.uniform(0.2, 2), r.uniform(0.2, 3), r.uniform(0.2, 2.5),
                 r.uniform(0.05, 0.4), r.uniform(0.25, 1), r.randint(1, 4), r.uniform(0.55, 0.65)]
            h = max(x[1], x[3], x[5]) + r.uniform(0.05, 1.5)
            Q = comp(x, h)
            if kind == "Q":
                rows.append(["Q"] + x + [h, Q, 0])
            else:
                Qg = Q * r.uniform(0.05, 1)
                rows.append(["H"] + x + [Qg, comp_level(x, Qg), 0])
    for _ in range(N):
        D1, beta, S = r.uniform(0.05, 1), r.uniform(0.3, 0.8), r.choice((1.6, 2.95, 4.0, 13.6))
        A1 = math.pi * D1 * D1 / 4
        Q = A1 * r.uniform(0.3, 4)
        v1, v2 = Q / A1, Q / (A1 * beta * beta)
        dp = GAMMA / (2 * G) * (v2 * v2 - v1 * v1)
        rows.append(["V", D1, beta, Q, S, 0, 0, 0, 0, 0, dp, dp / ((S - 1) * GAMMA)])
    for _ in range(N):
        b, y1 = r.uniform(0.5, 10), r.uniform(0.05, 1)
        Fr = r.uniform(1.2, 12)
        Q = Fr * math.sqrt(G * y1) * y1 * b
        y2 = y1 / 2 * (math.sqrt(1 + 8 * Fr * Fr) - 1)
        rows.append(["J", Q, b, y1, 0, 0, 0, 0, 0, 0, y2, (y2 - y1) ** 3 / (4 * y1 * y2)])
    for _ in range(N):
        L, V, nu = r.uniform(0.2, 20), r.uniform(1, 50), r.choice((1.5e-5, 1e-6))
        re = V * L / nu
        rows.append(["P", L, V, nu, 0, 0, 0, 0, 0, 0, 0.074 / re ** 0.2, 0.074 / re ** 0.2 - 1742 / re])
    for m in range(4):
        for _ in range(N // 3):
            re, k = lu(r, 5000, 1e8), lu(r, 1e-6, 1e-2)
            rows.append(["F", re, k, m, 0, 0, 0, 0, 0, 0, f_method(re, k, m), 0])
    out = sys.argv[1] if len(sys.argv) > 1 else "tests/random_cases2.csv"
    with open(out, "w", newline="") as fh:
        w = csv.writer(fh, delimiter=";")
        for row in rows:
            w.writerow([row[0]] + ["%.12g" % v for v in row[1:]])
    print("%d casos en %s" % (len(rows), out))


if __name__ == "__main__":
    main()
