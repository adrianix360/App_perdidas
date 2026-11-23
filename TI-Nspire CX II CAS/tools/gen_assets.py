#!/usr/bin/env python
r"""Genera src/gen/*.lua a partir de la app TI-84 (C:\dev\ti84, solo lectura).

  - compila tools/gen_txt.c del repo TI-84 con gcc en C:\dev\build\nspire_gen\ y
    lo ejecuta para producir PERDTXT.bin (no escribe nada en C:\dev\ti84)
  - toma bin/PERDGFX.bin del repo TI-84
  - emite src/gen/perdtxt.lua y src/gen/perdgfx.lua (cadena binaria Lua)
  - emite src/gen/memo_defs.lua con las constantes de memo_defs.h (V_*, G_*, M_*, ...)

Uso: python -I tools/gen_assets.py
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TI84 = r"C:\dev\ti84"
OUTBUILD = r"C:\dev\build\nspire_gen"
GEN = os.path.join(ROOT, "src", "gen")


def fail(msg):
    sys.stderr.write("ERROR: %s\n" % msg)
    sys.exit(1)


def find_gcc():
    pat = (r"C:\Users\*\AppData\Local\Microsoft\WinGet\Packages"
           r"\BrechtSanders.WinLibs.POSIX.UCRT*\mingw64\bin\gcc.exe")
    hits = glob.glob(pat)
    return hits[0] if hits else "gcc"


def lua_string(data, name, comment):
    """Cadena binaria como table.concat de literales (lineas cortas)."""
    lines = []
    chunk = 64
    for i in range(0, len(data), chunk):
        part = data[i:i + chunk]
        s = []
        for b in part:
            if 32 <= b <= 126 and b not in (34, 92):
                s.append(chr(b))
            else:
                s.append("\\%03d" % b)
        lines.append('"' + "".join(s) + '"')
    out = ["-- GENERADO por tools/gen_assets.py: no editar a mano.",
           "-- %s (%d bytes)" % (comment, len(data)),
           "return table.concat({"]
    out.append(",\n".join(lines))
    out.append("})")
    return "\n".join(out) + "\n"


def strip_comments(t):
    t = re.sub(r"/\*.*?\*/", "", t, flags=re.S)
    return re.sub(r"//[^\n]*", "", t)


def parse_defs(paths):
    """Enums y #define simples (numericos o alias) de los .h indicados."""
    syms = {}
    order = []

    def ev(expr):
        e = expr.strip()
        e = re.sub(r"\b(0[xX][0-9a-fA-F]+)[uUlL]+\b", r"\1", e)
        e = re.sub(r"\b(\d+)[uUlL]+\b", r"\1", e)
        for k in sorted(syms, key=len, reverse=True):
            e = re.sub(r"\b%s\b" % re.escape(k), str(syms[k]), e)
        return int(eval(e, {"__builtins__": {}}, {}))

    for p in paths:
        with open(p, encoding="latin-1") as fh:
            t = strip_comments(fh.read())
        # reunir en orden: #define y enum
        pos = 0
        pat = re.compile(r"#define[ \t]+(\w+)(?!\()[ \t]+([^\n]+)|enum\s*\{(.*?)\}\s*;", re.S)
        for m in pat.finditer(t):
            if m.group(3) is not None:
                val = -1
                for item in m.group(3).split(","):
                    item = item.strip()
                    if not item:
                        continue
                    if "=" in item:
                        n, v = item.split("=", 1)
                        val = ev(v)
                        n = n.strip()
                    else:
                        n = item
                        val += 1
                    syms[n] = val
                    order.append(n)
            else:
                n, v = m.group(1), m.group(2).strip()
                if "(" in v and not re.match(r"^\(?[\w\s+*-]+\)?$", v):
                    continue
                try:
                    syms[n] = ev(v)
                    order.append(n)
                except Exception:
                    pass
    return syms, order


def main():
    os.makedirs(GEN, exist_ok=True)
    os.makedirs(OUTBUILD, exist_ok=True)
    src = os.path.join(TI84, "tools", "gen_txt.c")
    exe = os.path.join(OUTBUILD, "gen_txt.exe")
    txt = os.path.join(OUTBUILD, "PERDTXT.bin")
    r = subprocess.run([find_gcc(), "-std=c99", "-O1", "-Wno-unused-variable",
                        "-Wno-unused-const-variable", "-o", exe, src],
                       capture_output=True, text=True)
    if r.returncode != 0:
        fail("gcc fallo:\n%s%s" % (r.stdout, r.stderr))
    r = subprocess.run([exe, txt], capture_output=True, text=True)
    if r.returncode != 0 or not os.path.isfile(txt):
        fail("gen_txt fallo:\n%s%s" % (r.stdout, r.stderr))
    with open(txt, "rb") as fh:
        txt_data = fh.read()
    with open(os.path.join(TI84, "bin", "PERDGFX.bin"), "rb") as fh:
        gfx_data = fh.read()
    if txt_data[:3] != b"PTX" or gfx_data[:3] != b"PGX":
        fail("cabeceras de PERDTXT/PERDGFX invalidas")

    with open(os.path.join(GEN, "perdtxt.lua"), "w", newline="\n") as fh:
        fh.write(lua_string(txt_data, "perdtxt", "PERDTXT.bin (programas de memoria de calculo)"))
    with open(os.path.join(GEN, "perdgfx.lua"), "w", newline="\n") as fh:
        fh.write(lua_string(gfx_data, "perdgfx", "PERDGFX.bin (ilustraciones del catalogo de C_D)"))

    syms, order = parse_defs([os.path.join(TI84, "src", "app.h"),
                              os.path.join(TI84, "src", "memo_defs.h")])
    keep = [n for n in order if re.match(
        r"^(V_|G_|M_|S_|XP_|TB_|PT_|TX_|HELP_COUNT|CAT_N|DEC_MAX|KT_|CASES_MAX|CASE_NAME)", n)]
    seen = set()
    lines = ["-- GENERADO por tools/gen_assets.py desde memo_defs.h/app.h: no editar a mano.",
             "return {"]
    for n in keep:
        if n in seen:
            continue
        seen.add(n)
        lines.append("  %s = %d," % (n, syms[n]))
    lines.append("}")
    with open(os.path.join(GEN, "memo_defs.lua"), "w", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("PERDTXT %d bytes, PERDGFX %d bytes, %d constantes -> src/gen/" %
          (len(txt_data), len(gfx_data), len(seen)))


if __name__ == "__main__":
    main()
