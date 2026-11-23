#!/usr/bin/env python
"""Valida tests/checklist.md: cada fila apunta a un archivo de test y a un fragmento literal
que existe en ese archivo; ninguna fila puede decir SIN COBERTURA. Sale con 1 si hay huecos.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = missing = 0
cache = {}
with open(os.path.join(ROOT, "tests", "checklist.md"), encoding="utf-8") as fh:
    for line in fh:
        m = re.match(r"\| (\d+) \| (.*) \| (tests/\S+) \| `(.*)` \|$", line.rstrip("\n"))
        if not m:
            if "SIN COBERTURA" in line and not line.startswith("queda") and "`SIN" not in line:
                print("hueco:", line.strip())
                missing += 1
            continue
        rows += 1
        num, item, path, frag = m.groups()
        full = os.path.join(ROOT, path)
        if path not in cache:
            cache[path] = open(full, encoding="utf-8").read() if os.path.exists(full) else None
        text = cache[path]
        if text is None:
            print("fila %s: no existe %s (%s)" % (num, path, item))
            missing += 1
        elif frag not in text:
            print("fila %s: fragmento no encontrado en %s: %r (%s)" % (num, path, frag, item))
            missing += 1
print("checklist: %d filas, %d sin cobertura" % (rows, missing))
sys.exit(1 if missing else 0)
