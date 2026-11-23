"""Genera icon.png (16x16): tubo horizontal con una gota. Python puro."""
import struct, sys, zlib

W = H = 16
BG = (255, 255, 255)
PIPE = (90, 90, 90)
PIPE_HI = (170, 170, 170)
WATER = (30, 120, 230)
DROP = (0, 80, 200)

px = [[BG] * W for _ in range(H)]
for x in range(W):              # tubo: filas 9 a 14
    px[9][x] = PIPE
    px[14][x] = PIPE
    for y in (10, 11, 12, 13):
        px[y][x] = WATER
    px[10][x] = PIPE_HI if x % 4 == 0 else WATER
drop = ["....##....", "...####...", "..######..", ".########.",
        ".########.", "..######.."]
for j, row in enumerate(drop):  # gota arriba, columnas 3 a 12
    for i, ch in enumerate(row):
        if ch == "#":
            px[1 + j][3 + i] = DROP
raw = b"".join(b"\x00" + bytes(c for p in r for c in p) for r in px)

def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
open(sys.argv[1] if len(sys.argv) > 1 else "icon.png", "wb").write(png)
