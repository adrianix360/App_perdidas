"""
oracle.py - Oraculo de referencia en doble precision (Python puro, sin scipy).

Genera casos aleatorios dentro de rangos realistas y calcula, con una
implementacion independiente de Colebrook-White (Newton sobre x = 1/sqrt f)
y biseccion de 300 pasos, los valores de referencia de:
  F: f y hf dado Q            B: caudal maximo dado H
  D: diametro exacto dado Qd y H
Salida: CSV en tests/random_cases.csv (o la ruta del primer argumento).

Rangos (prompt, sec. 6): D 20 mm a 1,5 m; L 1 m a 20 km;
nu 0,8e-6 a 1,5e-6 m2/s; ks/D 1e-6 a 0,05.
"""
import csv
import math
import random
import sys

G = 9.81
RE_LAM = 2000.0
N_PER_KIND = 250
SEED = 20261106


def f_colebrook(re, ksd):
    """Colebrook-White por Newton sobre x = 1/sqrt(f), hasta precision de maquina."""
    if re < RE_LAM:
        return 64.0 / re
    a = ksd / 3.7
    b = 2.51 / re
    x = 8.0
    for _ in range(100):
        u = a + b * x
        fx = x + 2.0 * math.log10(u)
        dfx = 1.0 + 2.0 * b / (u * math.log(10.0))
        xn = x - fx / dfx
        if abs(xn - x) < 1e-15 * abs(xn):
            x = xn
            break
        x = xn
    return 1.0 / (x * x)


def h_total(Q, D, L, ks, K, nu):
    A = math.pi * D * D / 4.0
    v = Q / A
    re = v * D / nu
    f = f_colebrook(re, ks / D)
    hv = v * v / (2.0 * G)
    hf = f * L / D * hv
    return f, hf, hf + K * hv, re


def q_max(H, D, L, ks, K, nu):
    A = math.pi * D * D / 4.0
    lo, hi = 0.0, 1.0
    while h_total(hi * A, D, L, ks, K, nu)[2] < H:
        lo, hi = hi, hi * 2.0
    for _ in range(300):
        mid = 0.5 * (lo + hi)
        if h_total(mid * A, D, L, ks, K, nu)[2] > H:
            hi = mid
        else:
            lo = mid
    return 0.5 * (lo + hi) * A


def d_design(Qd, H, L, ks, K, nu):
    lo, hi = 0.001, 20.0
    if h_total(Qd, hi, L, ks, K, nu)[2] > H or h_total(Qd, lo, L, ks, K, nu)[2] < H:
        return None
    for _ in range(300):
        mid = math.sqrt(lo * hi)
        if h_total(Qd, mid, L, ks, K, nu)[2] > H:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def logu(rng, a, b):
    return math.exp(rng.uniform(math.log(a), math.log(b)))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "tests/random_cases.csv"
    rng = random.Random(SEED)
    rows = []
    # F: f y hf dado Q (velocidades de 0,02 a 6 m/s: incluye laminar)
    for i in range(N_PER_KIND):
        D = logu(rng, 0.02, 1.5)
        L = logu(rng, 1.0, 20000.0)
        nu = rng.uniform(0.8e-6, 1.5e-6)
        ks = logu(rng, 1e-6, 0.05) * D
        K = rng.uniform(0.0, 20.0)
        v = logu(rng, 0.02, 6.0)
        Q = v * math.pi * D * D / 4.0
        f, hf, ht, re = h_total(Q, D, L, ks, K, nu)
        rows.append(["F", i, D, L, ks, K, nu, Q, f, hf, re])
    # B: caudal maximo dado H
    for i in range(N_PER_KIND):
        D = logu(rng, 0.02, 1.5)
        L = logu(rng, 1.0, 20000.0)
        nu = rng.uniform(0.8e-6, 1.5e-6)
        ks = logu(rng, 1e-6, 0.05) * D
        K = rng.uniform(0.0, 20.0)
        H = logu(rng, 0.5, 300.0)
        Q = q_max(H, D, L, ks, K, nu)
        f, hf, ht, re = h_total(Q, D, L, ks, K, nu)
        rows.append(["B", i, D, L, ks, K, nu, H, Q, f, re])
    # D: diametro de diseno dado Qd y H
    n = 0
    while n < N_PER_KIND:
        L = logu(rng, 1.0, 20000.0)
        nu = rng.uniform(0.8e-6, 1.5e-6)
        Dref = logu(rng, 0.02, 1.5)          # diametro tipico para fijar Qd
        ks = logu(rng, 1e-6, 0.05) * Dref
        K = rng.uniform(0.0, 20.0)
        v = logu(rng, 0.3, 4.0)
        Qd = v * math.pi * Dref * Dref / 4.0
        H = logu(rng, 0.5, 300.0)
        D = d_design(Qd, H, L, ks, K, nu)
        if D is None or not (0.02 <= D <= 1.5) or ks / D > 0.05:
            continue
        f, hf, ht, re = h_total(Qd, D, L, ks, K, nu)
        rows.append(["D", n, D, L, ks, K, nu, Qd, H, f, re])
        n += 1
    with open(out, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["tipo", "i", "D", "L", "ks", "K", "nu", "a", "b", "c", "Re"])
        for r in rows:
            w.writerow([r[0], r[1]] + ["%.17g" % x for x in r[2:]])
    print("%d casos escritos en %s" % (len(rows), out))


if __name__ == "__main__":
    main()
