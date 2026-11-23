"""vram2png.py - Convierte un volcado de VRAM de 16 bits (320x240, RGB565
little endian, como el LCD del CE en modo 16 bpp) a PNG. Python puro.
Uso: python -I tools/vram2png.py volcado.bin salida.png [escala]"""
import struct, sys, zlib

src, out = sys.argv[1], sys.argv[2]
k = int(sys.argv[3]) if len(sys.argv) > 3 else 2
d = open(src, "rb").read()
W, H = 320, 240
rows = []
for y in range(H):
    line = bytearray()
    for x in range(W):
        v = d[2 * (y * W + x)] | d[2 * (y * W + x) + 1] << 8
        r = (v >> 11) & 31; g = (v >> 5) & 63; b = v & 31
        px = bytes(((r * 255) // 31, (g * 255) // 63, (b * 255) // 31))
        line += px * k
    rows.extend([b"\x00" + bytes(line)] * k)

def chunk(t, x):
    return struct.pack(">I", len(x)) + t + x + struct.pack(">I", zlib.crc32(t + x) & 0xFFFFFFFF)

png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W * k, H * k, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(b"".join(rows))) + chunk(b"IEND", b""))
open(out, "wb").write(png)
