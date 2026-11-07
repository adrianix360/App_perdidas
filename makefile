# ----------------------------------------------------------------------
# PERDIDAS - app de perdidas en tuberias para la TI-84 Plus CE
# Compilar SIEMPRE desde C:\dev\ti84 (union sin espacios):
#   make          -> bin/PERDIDAS.8xp
#   make debug    -> con dbg_printf hacia la consola de CEmu
# obj/ es una union hacia C:\dev\build\perdidas\obj (fuera de OneDrive).
# ----------------------------------------------------------------------
NAME = PERDIDAS
ICON = icon.png
DESCRIPTION = "Perdidas en tuberias"
COMPRESSED = NO
# En RAM, igual que el Hola mundo H0 que se probo con arTIfiCE v2.1
ARCHIVED = NO
HAS_PRINTF = NO

CFLAGS = -Wall -Wextra -Oz
CXXFLAGS = -Wall -Wextra -Oz

include $(shell cedev-config --makefile)
