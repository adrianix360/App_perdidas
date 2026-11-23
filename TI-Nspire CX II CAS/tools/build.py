#!/usr/bin/env python
"""Concatena src/**/*.lua en build/app.lua (con require propio) y genera el .tns con luna.

Uso: python -I tools/build.py [--no-tns]
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
BUILD = os.path.join(ROOT, "build")
APP = os.path.join(BUILD, "app.lua")
TNS = os.path.join(BUILD, "PerdidasFlujos.tns")
LUAC = r"C:\dev\tools\lua51\luac.exe"
LUNA = r"C:\dev\tools\luna\luna.exe"

PRELUDE = """\
-- GENERADO por tools/build.py: no editar a mano.
local __mods, __loaded, __loading = {}, {}, {}
function require(name)
  local v = __loaded[name]
  if v ~= nil then return v end
  local f = __mods[name]
  if not f then error("modulo no encontrado: " .. tostring(name), 2) end
  if __loading[name] then error("require circular: " .. tostring(name), 2) end
  __loading[name] = true
  local r = f(name)
  __loading[name] = nil
  if r == nil then r = true end
  __loaded[name] = r
  return r
end
"""


def fail(msg):
    sys.stderr.write("ERROR: %s\n" % msg)
    sys.exit(1)


def read_lua(path):
    with open(path, "rb") as fh:
        raw = fh.read()
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as e:
        fail("%s no es UTF-8: %s" % (path, e))
    if text.startswith("\ufeff"):
        text = text[1:]
    return text.replace("\r\n", "\n").replace("\r", "\n")


def collect():
    mods = []
    for dirpath, _dirs, files in os.walk(SRC):
        for fn in files:
            if not fn.endswith(".lua"):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, SRC).replace(os.sep, "/")
            if rel == "main.lua":
                continue
            mods.append((rel[:-4].replace("/", "."), full))
    mods.sort()
    return mods


def main():
    no_tns = "--no-tns" in sys.argv[1:]
    main_path = os.path.join(SRC, "main.lua")
    if not os.path.isfile(main_path):
        fail("falta src/main.lua")
    parts = [PRELUDE]
    for name, path in collect():
        code = read_lua(path)
        parts.append('__mods["%s"]=function(...)\n%s\nend\n' % (name, code))
    parts.append(read_lua(main_path))
    out = "".join(parts)
    if not out.endswith("\n"):
        out += "\n"
    os.makedirs(BUILD, exist_ok=True)
    with open(APP, "wb") as fh:
        fh.write(out.encode("utf-8"))
    r = subprocess.run([LUAC, "-p", APP], capture_output=True, text=True)
    if r.returncode != 0:
        fail("sintaxis Lua invalida en build/app.lua:\n%s%s" % (r.stdout, r.stderr))
    print("build/app.lua OK (%d bytes, sintaxis verificada)" % len(out.encode("utf-8")))
    if no_tns:
        return
    if os.path.exists(TNS):
        os.remove(TNS)
    r = subprocess.run([LUNA, APP, TNS], capture_output=True, text=True)
    sys.stdout.write(r.stdout)
    if r.returncode != 0 or not os.path.isfile(TNS) or os.path.getsize(TNS) == 0:
        fail("luna fallo (codigo %d):\n%s" % (r.returncode, r.stderr))
    print("build/PerdidasFlujos.tns OK (%d bytes)" % os.path.getsize(TNS))


if __name__ == "__main__":
    main()
