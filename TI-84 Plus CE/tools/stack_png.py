"""stack_png.py - Apila PNG (mismo ancho) verticalmente. Python puro.
Uso: python -I tools/stack_png.py salida.png a.png b.png ..."""
import struct, sys, zlib

def rd(fn):
    d = open(fn, "rb").read(); i = 8; idat = b""; w = h = 0
    while i < len(d):
        n = struct.unpack(">I", d[i:i + 4])[0]; t = d[i + 4:i + 8]; c = d[i + 8:i + 8 + n]
        if t == b"IHDR": w, h = struct.unpack(">II", c[:8])
        if t == b"IDAT": idat += c
        i += 12 + n
    raw = zlib.decompress(idat)
    return w, [raw[y * (w * 3 + 1) + 1:(y + 1) * (w * 3 + 1)] for y in range(h)]

rows = []; W = 0
for fn in sys.argv[2:]:
    w, r = rd(fn); W = w; rows += r + [bytes([255, 0, 0]) * w] * 3
def ch(t, x): return struct.pack(">I", len(x)) + t + x + struct.pack(">I", zlib.crc32(t + x) & 0xFFFFFFFF)
raw = b"".join(b"\x00" + bytes(x) for x in rows)
open(sys.argv[1], "wb").write(b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", W, len(rows), 8, 2, 0, 0, 0)) + ch(b"IDAT", zlib.compress(raw)) + ch(b"IEND", b""))
