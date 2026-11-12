#!/bin/sh
# Compila y ejecuta las pruebas del motor en el PC, con real = float y double.
# Uso (desde C:\dev\ti84):  sh tools/run_pc_tests.sh [-v]
# El motor se compila con -Wdouble-promotion y, en float, con
# -fsingle-precision-constant para que ninguna cuenta se haga en double.
set -e
sh tools/build_all.sh > /dev/null
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
for m in f d; do
  D=""; [ $m = d ] && D="-DHYDRO_USE_DOUBLE"; S=""; [ $m = f ] && S="-fsingle-precision-constant"
  gcc $CF -Wdouble-promotion $S $D -c src/ui/expr.c -o "$OUT/expr_$m.o"
  gcc $CF -Wdouble-promotion $S $D -c src/ui/numfmt.c -o "$OUT/numfmt_$m.o"
  gcc $CF $D -c tests/test_ui_pure.c -o "$OUT/test_ui_pure_$m.o"
  gcc -o "$OUT/test_ui_pure_$m.exe" "$OUT/test_ui_pure_$m.o" "$OUT/expr_$m.o" "$OUT/numfmt_$m.o" -lm
done
# Interfaz con pantalla y teclado simulados (float, como la calculadora)
UIS="src/scr_net.c tests/mock/mock_graph.c src/screens.c src/scr_pipe.c src/scr_lib.c src/cases.c src/data/lib.c src/data/diams.c src/ui/memo.c src/store.c src/ui/widgets.c src/ui/expr.c src/ui/numfmt.c src/ui/texts.c src/hydro/hydro.c tests/mock/mock_ui.c tests/test_nav.c"
gcc -std=c99 -O1 -g -Wall -Wextra -Werror -Wno-unused-parameter -Itests/mock -fsanitize=undefined,bounds -fsanitize-trap=all     -fsingle-precision-constant -o "$OUT/test_nav.exe" $UIS -lm
[ -f tests/random_cases.csv ] || python -I tools/oracle.py tests/random_cases.csv
st=0
echo "=================== interfaz simulada (float) ==================="
"$OUT/test_nav.exe" || st=1
for p in f d; do
  echo "=================== golden ($p) ==================="
  "$OUT/golden_$p.exe" "$@" || st=1
  echo "=================== interfaz pura ($p) ==================="
  "$OUT/test_ui_pure_$p.exe" || st=1
  echo "=================== aleatorios ($p) ==================="
  "$OUT/random_check_$p.exe" tests/random_cases.csv || st=1
done
exit $st
