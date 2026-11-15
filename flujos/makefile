# ----------------------------------------------------------------------
# FLUJOS - segundo programa de la app (v2.0): arrastre y sustentacion,
# vertedores y orificios, canales y medicion. Mismo codigo que PERDIDAS
# (../src) con -DPROG_FLUJOS; el enlazador (LTO) deja solo lo que usa.
# Compilar desde C:\dev\ti84\flujos (o con tools/build_all.sh).
# ----------------------------------------------------------------------
NAME = FLUJOS
ICON = ../icon.png
DESCRIPTION = "Flujos externos y medicion"
COMPRESSED = NO
ARCHIVED = NO
HAS_PRINTF = NO
# src es una union hacia ../src (CEdev no acepta SRCDIR con ..)
BINDIR = ../bin
# obj es una union hacia C:devbuildlujosobj (fuera de OneDrive)

# Como PERDIDAS: lanzador chico en RAM y el codigo en AppVars archivados
# (FLUJOS0, FLUJOS1...). Un .8xp grande en RAM ocuparia el doble al correr.
CONVBINFLAGS = -m 32768

CFLAGS = -Wall -Wextra -Oz -DPROG_FLUJOS
CXXFLAGS = -Wall -Wextra -Oz -DPROG_FLUJOS

include $(shell cedev-config --makefile)
