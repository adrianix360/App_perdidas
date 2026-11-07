#!/bin/sh
# Compila y ejecuta las pruebas del motor en el PC, con real = float y double.
# Uso (desde C:\dev\ti84):  sh tools/run_pc_tests.sh [-v]
# El motor se compila con -Wdouble-promotion y, en float, con
# -fsingle-precision-constant para que ninguna cuenta se haga en double.
set -e
GCCDIR="$(ls -d /c/Users/castr/AppData/Local/Microsoft/WinGet/Packages/BrechtSanders.WinLibs.POSIX.UCRT*/mingw64/bin 2>/dev/null | head -1)"
[ -n "$GCCDIR" ] && PATH="$GCCDIR:$PATH"
OUT=/c/dev/build/tests
mkdir -p "$OUT"
CF="-std=c99 -O2 -Wall -Wextra -Werror"
gcc $CF -Wdouble-promotion -fsingle-precision-constant -c src/hydro/hydro.c -o "$OUT/hydro_f.o"
gcc $CF -Wdouble-promotion -DHYDRO_USE_DOUBLE -c src/hydro/hydro.c -o "$OUT/hydro_d.o"
for t in golden random_check; do
  gcc $CF -c tests/$t.c -o "$OUT/${t}_f.o"
  gcc $CF -DHYDRO_USE_DOUBLE -c tests/$t.c -o "$OUT/${t}_d.o"
  gcc -o "$OUT/${t}_f.exe" "$OUT/${t}_f.o" "$OUT/hydro_f.o" -lm
  gcc -o "$OUT/${t}_d.exe" "$OUT/${t}_d.o" "$OUT/hydro_d.o" -lm
done
[ -f tests/random_cases.csv ] || python -I tools/oracle.py tests/random_cases.csv
st=0
for p in f d; do
  echo "=================== golden ($p) ==================="
  "$OUT/golden_$p.exe" "$@" || st=1
  echo "=================== aleatorios ($p) ==================="
  "$OUT/random_check_$p.exe" tests/random_cases.csv || st=1
done
exit $st
