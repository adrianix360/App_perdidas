#!/bin/sh
# Compila todo para la calculadora (desde C:\dev\ti84):
#   1. genera el AppVar de textos bin/PERDTXT.8xv (tools/gen_txt.c)
#   2. compila bin/PERDIDAS.8xp (make)
set -e
GCCDIR="$(ls -d /c/Users/castr/AppData/Local/Microsoft/WinGet/Packages/BrechtSanders.WinLibs.POSIX.UCRT*/mingw64/bin 2>/dev/null | head -1)"
[ -n "$GCCDIR" ] && PATH="$GCCDIR:$PATH"
PATH="/c/CEdev/bin:$PATH"
OUT=/c/dev/build/gen
mkdir -p "$OUT" bin
gcc -std=c99 -O1 -Wall -Wextra -Werror -Wno-unused-variable -Wno-unused-const-variable \
    -o "$OUT/gen_txt.exe" tools/gen_txt.c
"$OUT/gen_txt.exe" bin/PERDTXT.bin
convbin -j bin -k 8xv -n PERDTXT -r -i bin/PERDTXT.bin -o bin/PERDTXT.8xv -l 1
# Ilustraciones del catalogo de CD: se regeneran con python -I tools/gen_gfx.py (lento)
[ -f bin/PERDGFX.bin ] && convbin -j bin -k 8xv -n PERDGFX -r -i bin/PERDGFX.bin -o bin/PERDGFX.8xv -l 1
make 2>&1 | grep -v -E "GNU-stack|deprecated"
