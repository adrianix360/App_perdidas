#!/usr/bin/env bash
# Compila (sin .tns) y ejecuta tests/test_*.lua desde la raiz del repo.
cd "$(dirname "$0")/.." || exit 1
LUA=/c/dev/tools/lua51/lua.exe
export LUA_PATH="./?.lua;./tests/?.lua;./src/?.lua"
python -I tools/build.py --no-tns || { echo "FALLO: build"; exit 1; }
pass=0; fail=0; failed=""
for t in tests/test_*.lua; do
  [ -e "$t" ] || continue
  if "$LUA" "$t"; then pass=$((pass+1)); echo "PASS $t"
  else fail=$((fail+1)); failed="$failed $t"; echo "FAIL $t"; fi
done
python -I tools/check_checklist.py || { fail=$((fail+1)); failed="$failed checklist"; }
echo "== Resumen: $pass ok, $fail fallo(s)${failed:+ ->$failed}"
[ "$fail" -eq 0 ]
