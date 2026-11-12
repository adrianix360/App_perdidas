"""
build_rom.py - Arma la imagen ROM de CEmu a partir de los AppVars ROMData*
que deja el volcador DUMP.8xp en la calculadora (misma logica que
RomSelection::parseROMSegments de CEmu, gui/qt/romselection.cpp).

Uso: python -I tools/build_rom.py <carpeta_con_ROMData*.8xv> <salida.rom>

Formato de cada .8xv (cabecera 8xv de TI): nombre en 0x3C (8 bytes).
  ROMData0: tamano del SO (3 bytes, little endian) en 0x4A
  ROMData1: certificado, 65512 bytes desde 0x4A, va en 0x3B0000
  ROMDataA, B, ...: segmentos de 65512 bytes del SO, en orden
"""
import os
import sys

ROM_SIZE = 0x400000
CERT_LOC = 0x3B0000
SEG_SIZE = 65512


def main():
    src, out = sys.argv[1], sys.argv[2]
    rom = bytearray(b"\xff" * ROM_SIZE)
    os_size = None
    segs = {}
    cert = False
    for fn in sorted(os.listdir(src)):
        if not fn.lower().endswith(".8xv"):
            continue
        data = open(os.path.join(src, fn), "rb").read()
        name = data[0x3C:0x44]
        if name[:7] != b"ROMData":
            print("ignorado (no es ROMData):", fn)
            continue
        tag = chr(name[7])
        if tag == "0":
            os_size = data[0x4A] | data[0x4B] << 8 | data[0x4C] << 16
            continue
        size = data[0x48] | data[0x49] << 8
        if size != SEG_SIZE or len(data) < 0x4A + SEG_SIZE:
            sys.exit("segmento invalido (tamano %d): %s" % (size, fn))
        payload = data[0x4A:0x4A + SEG_SIZE]
        if tag == "1":
            rom[CERT_LOC:CERT_LOC + SEG_SIZE] = payload
            cert = True
        else:
            seg = ord(tag) - ord("A")
            if seg < 0 or seg * SEG_SIZE >= ROM_SIZE:
                sys.exit("segmento fuera de rango: %s" % fn)
            segs[seg] = payload
    if os_size is None:
        sys.exit("falta ROMData0 (tamano del SO)")
    needed = os_size // SEG_SIZE + 1
    missing = [chr(ord("A") + i) for i in range(needed) if i not in segs]
    if missing or not cert:
        sys.exit("faltan segmentos: %s%s" % (" ".join(missing),
                                             "" if cert else " 1 (certificado)"))
    for i, p in segs.items():
        rom[i * SEG_SIZE:i * SEG_SIZE + len(p)] = p
    open(out, "wb").write(rom)
    print("ROM armado: %s (%d bytes); SO de %d bytes en %d segmentos + certificado"
          % (out, len(rom), os_size, needed))


if __name__ == "__main__":
    main()
