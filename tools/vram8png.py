"""vram8png.py - Convierte un volcado de VRAM (153600 bytes) de un programa
con graphx (8 bpp, doble bufer) a PNG con los dos buferes lado a lado,
usando la paleta de PERDIDAS (src/ui/ui.c). Python puro.
Uso: python -I tools/vram8png.py volcado.bin salida.png"""
import struct, sys, zlib

PAL = {0: (255, 255, 255), 1: (0, 0, 0), 2: (0, 51, 102), 3: (170, 205, 255),
       4: (190, 90, 0), 5: (200, 0, 0), 6: (110, 110, 110), 7: (215, 215, 215),
       8: (0, 120, 0), 9: (255, 240, 170), 10: (0, 70, 200), 11: (210, 0, 0),
       12: (150, 120, 90), 13: (120, 180, 255)}
d = open(sys.argv[1], "rb").read()
W, H = 320, 240
rows = []
for y in range(H):
    line = bytearray()
    for half in (0, 1):
        base = half * W * H + y * W
        for x in range(W):
            line += bytes(PAL.get(d[base + x], (255, 0, 255)))
        line += bytes((128, 128, 128)) * 8
    rows.append(b"\x00" + bytes(line))

def chunk(t, x):
    return struct.pack(">I", len(x)) + t + x + struct.pack(">I", zlib.crc32(t + x) & 0xFFFFFFFF)

png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 2 * W + 16, H, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(b"".join(rows))) + chunk(b"IEND", b""))
open(sys.argv[2], "wb").write(png)
