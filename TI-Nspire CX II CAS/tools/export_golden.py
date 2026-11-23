#!/usr/bin/env python
"""Convierte los datos de prueba de la app TI-84 (solo lectura) en tablas Lua.

Entradas (C:\\dev\\ti84\\tests):
  golden_table.h      -> tests/data/golden_table.lua   (id, name, expected, dec, tol_rel, tol_abs, ref)
  random_cases.csv    -> tests/data/random1.lua        (tipo F/B/D del oraculo 1)
  random_cases2.csv   -> tests/data/random2.lua        (tipos T S Q H V J P F del oraculo 2)

`ref` es el valor que obtiene el C compilado con -DHYDRO_USE_DOUBLE para cada fila
dorada (se compila golden.c en C:\\dev\\build\\nspire_ref; nunca se escribe en
C:\\dev\\ti84). Si no hay gcc se conserva el `ref` del archivo anterior o queda en nil.

Regla de aprobacion de las filas doradas (golden.c, end()):
  tol = max(tol_rel*|esp|, tol_abs); si tol_rel == 0 y tol_abs == 0: tol = 0.5 (exacto)
  PASA si |got-esp| <= tol; si no, PASA (r) si |got-esp| <= 0.5*10^-dec
  (no aplica a las exactas); si no FALLA. random_check*.c: error rel <= 1e-3.

Uso: python -I tools/export_golden.py
"""
import os
import re
import subprocess
import sys

TI84 = r"C:\dev\ti84"
TESTS = os.path.join(TI84, "tests")
REF_DIR = r"C:\dev\build\nspire_ref"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "data")

DRIVER = r'''
#include <stdio.h>
#define GOLDEN_NO_MAIN
#include "C:/dev/ti84/tests/golden.c"
int main(int argc, char **argv)
{
    size_t i;
    FILE *f;
    int r = golden_run(0);
    f = fopen(argv[1], "w");
    for (i = 0; f && i < GOLDEN_N; i++)
        fprintf(f, "%.17g\n", golden_got[i]);
    if (f) fclose(f);
    return r;
}
'''


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def parse_golden():
    rows = []
    pat = re.compile(r'^\s*(GX|GF|GT|G)\s*\(\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*([^)]*)\)')
    with open(os.path.join(TESTS, "golden_table.h"), encoding="utf-8") as fh:
        for line in fh:
            m = pat.match(line)
            if not m:
                continue
            kind, gid, name, rest = m.groups()
            nums = [x.strip() for x in rest.split(",")]
            if kind == "GX":
                rows.append((gid, name, float(nums[0]), 0, 0.0, 0.0))
            elif kind == "G":
                rows.append((gid, name, float(nums[0]), int(nums[1]), 1e-3, 0.0))
            elif kind == "GF":
                rows.append((gid, name, float(nums[0]), int(nums[1]), 0.0, 1e-4))
            else:  # GT
                rows.append((gid, name, float(nums[0]), int(nums[1]), float(nums[2]), 0.0))
    return rows


def c_reference(n):
    """Valores del C (double) por fila, o None si no se pudo compilar."""
    try:
        os.makedirs(REF_DIR, exist_ok=True)
        drv = os.path.join(REF_DIR, "golden_dump.c")
        exe = os.path.join(REF_DIR, "golden_dump.exe")
        txt = os.path.join(REF_DIR, "golden_got.txt")
        with open(drv, "w") as fh:
            fh.write(DRIVER)
        src = [os.path.join(TI84, "src", "hydro", m) for m in
               ("hydro.c", "drag.c", "weir.c", "chan.c")]
        subprocess.check_call(["gcc", "-std=c99", "-O2", "-DHYDRO_USE_DOUBLE", "-o", exe,
                               drv] + src + ["-lm"], stdout=subprocess.DEVNULL)
        subprocess.call([exe, txt], stdout=subprocess.DEVNULL)
        with open(txt) as fh:
            vals = [float(x) for x in fh.read().split()]
        if len(vals) != n:
            sys.stderr.write("AVISO: el C da %d filas y la tabla tiene %d\n" % (len(vals), n))
            return None
        return vals
    except (OSError, subprocess.CalledProcessError) as e:
        sys.stderr.write("AVISO: sin referencia C (%s)\n" % e)
        return None


def write_golden():
    rows = parse_golden()
    ref = c_reference(len(rows))
    with open(os.path.join(OUT, "golden_table.lua"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("-- GENERADO por tools/export_golden.py desde tests/golden_table.h: no editar.\n")
        fh.write("-- Cada fila: id, name, expected, dec, tol_rel, tol_abs, ref (C double, nil si no hay).\n")
        fh.write("return {\n")
        for i, (gid, name, e, dec, tr, ta) in enumerate(rows):
            r = repr(ref[i]) if ref else "nil"
            fh.write("  { id = %s, name = %s, expected = %s, dec = %d, tol_rel = %s, tol_abs = %s, ref = %s },\n"
                     % (lua_str(gid), lua_str(name), repr(e), dec, repr(tr), repr(ta), r))
        fh.write("}\n")
    print("golden_table.lua: %d filas%s" % (len(rows), "" if ref else " (sin ref C)"))


def write_random1():
    n = 0
    with open(os.path.join(TESTS, "random_cases.csv"), encoding="utf-8") as fh, \
            open(os.path.join(OUT, "random1.lua"), "w", encoding="utf-8", newline="\n") as out:
        out.write("-- GENERADO por tools/export_golden.py desde tests/random_cases.csv: no editar.\n")
        out.write("-- Fila: {tipo, i, D, L, ks, K, nu, a, b, c, Re} (oraculo de Python, tolerancia 0,1 %).\n")
        out.write("return {\n")
        next(fh)  # cabecera
        for line in fh:
            p = line.strip().split(",")
            if len(p) != 11:
                continue
            out.write('  { "%s", %s, %s },\n' % (p[0], p[1], ", ".join(p[2:])))
            n += 1
        out.write("}\n")
    print("random1.lua: %d filas" % n)


def write_random2():
    n = 0
    with open(os.path.join(TESTS, "random_cases2.csv"), encoding="utf-8") as fh, \
            open(os.path.join(OUT, "random2.lua"), "w", encoding="utf-8", newline="\n") as out:
        out.write("-- GENERADO por tools/export_golden.py desde tests/random_cases2.csv: no editar.\n")
        out.write("-- Fila: {tipo, x1..x9, r1, r2} (oraculo 2 de Python, tolerancia 0,1 %).\n")
        out.write("return {\n")
        for line in fh:
            p = line.strip().split(";")
            if len(p) != 12:
                continue
            out.write('  { "%s", %s },\n' % (p[0], ", ".join(p[1:])))
            n += 1
        out.write("}\n")
    print("random2.lua: %d filas" % n)


def main():
    os.makedirs(OUT, exist_ok=True)
    write_golden()
    write_random1()
    write_random2()


if __name__ == "__main__":
    main()
