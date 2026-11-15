r"""
gen_gfx.py - Ilustraciones 3D del catalogo de coeficientes de arrastre
(v2.0) para el AppVar PERDGFX.

Cada figura se define por su funcion de distancia con signo (SDF), se traza
con rayos en vista tres cuartos (proyeccion ortogonal, luz arriba a la
izquierda) con supermuestreo 3x3, se cuantiza a una rampa de 12 tonos gris
azulado y se le agrega la flecha del flujo (naranja). El flujo va en +x.

Formato de PERDGFX (little endian):
  "PGX" ver(1) n(1) W(1) H(1) TW(1) TH(1) pal[16] x uint16 (RGB1555)
  n x uint16 desplazamiento de la imagen grande
  n x uint16 desplazamiento de la miniatura
  datos: RLE de 4 bits, un byte por tramo: (largo - 1) << 4 | simbolo,
  filas seguidas (el tramo puede pasar de una fila a la siguiente).
  Simbolo 0 = transparente; 1..12 rampa (oscuro a claro); 13 flecha;
  14 contorno del area de referencia; 15 contorno oscuro.

Uso (desde C:/dev/ti84):
  python -I tools/gen_gfx.py            -> bin/PERDGFX.bin y
                                           tests/cemu/hoja_contacto_cd.png
"""
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 96, 80          # imagen grande
TW, TH = 32, 18        # miniatura (fila doble de la lista: 20 px)
SS = 3                 # supermuestreo
VER = 1

# ---------------------------------------------------------------- paleta
def rgb1555(r, g, b):
    return (1 << 15) | ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3)

RAMP = [(int(30 + (232 - 30) * t), int(40 + (238 - 40) * t), int(62 + (250 - 62) * t))
        for t in np.linspace(0, 1, 12)]
PAL = [(255, 255, 255)] + RAMP + [(235, 110, 0), (0, 150, 70), (20, 25, 40)]

# ---------------------------------------------------------------- SDF
def length(v):
    return np.sqrt((v * v).sum(-1))

def sd_sphere(p, r):
    return length(p) - r

def sd_box(p, b):
    q = np.abs(p) - b
    return length(np.maximum(q, 0)) + np.minimum(q.max(-1), 0)

def sd_cyl_x(p, r, h):
    """cilindro de eje x, radio r, medio largo h"""
    d = np.stack([np.sqrt(p[..., 1] ** 2 + p[..., 2] ** 2) - r, np.abs(p[..., 0]) - h], -1)
    return np.minimum(d.max(-1), 0) + length(np.maximum(d, 0))

def rot_z(p, a):
    c, s = np.cos(a), np.sin(a)
    x, y = p[..., 0], p[..., 1]
    return np.stack([c * x + s * y, -s * x + c * y, p[..., 2]], -1)

def swap(p, order):
    return np.stack([p[..., i] for i in order], -1)

def sd_cone_x(p, r, l, apex_up):
    """cono de eje x: base de radio r, largo l. apex_up: punta hacia -x"""
    x = p[..., 0] if apex_up else -p[..., 0]
    q = np.sqrt(p[..., 1] ** 2 + p[..., 2] ** 2)
    # punta en x = -l/2, base en x = +l/2
    xa = x + l / 2
    k = r / l
    d_side = (q - k * xa) / np.sqrt(1 + k * k)
    d_cap = x - l / 2
    d_tip = -xa
    return np.maximum(np.maximum(d_side, d_cap), d_tip)

def sd_round_cone_x(p, r1, r2, h):
    """cono redondeado de eje x (gota): esfera r1 en 0, esfera r2 en x = h"""
    q = np.stack([np.sqrt(p[..., 1] ** 2 + p[..., 2] ** 2), p[..., 0]], -1)
    b = (r1 - r2) / h
    a = np.sqrt(1 - b * b)
    k = (q * np.array([-b, a])).sum(-1)
    d0 = length(q) - r1
    d1 = length(q - np.array([0, h])) - r2
    d2 = (q * np.array([a, b])).sum(-1) - r1
    return np.where(k < 0, d0, np.where(k > a * h, d1, d2))

def sd_cap_seg(p, a, b, r):
    pa, ba = p - a, b - a
    h = np.clip((pa * ba).sum(-1) / (ba * ba).sum(), 0, 1)
    return length(pa - ba * h[..., None]) - r

def cup(p, r, t, open_up):
    """casco hemisferico de espesor t; open_up: abierto hacia -x (al flujo)"""
    shell = np.abs(sd_sphere(p, r)) - t
    half = -p[..., 0] if open_up else p[..., 0]
    return np.maximum(shell, half)

# figuras: (nombre corto, sdf, escala relativa)
def f_sphere(p): return sd_sphere(p, 0.5)
def f_hemi_conv(p): return np.maximum(sd_sphere(p, 0.5), p[..., 0])         # domo hacia -x
def f_hemi_flat(p): return np.maximum(sd_sphere(p, 0.5), -p[..., 0])        # cara plana hacia -x
def f_cup(p): return cup(p, 0.5, 0.025, True)
def f_chute(p):
    d = cup(p - np.array([0.3, 0, 0]), 0.55, 0.02, True)
    pay = sd_sphere(p - np.array([-1.0, 0, 0]), 0.09)
    for a in np.linspace(0, 2 * np.pi, 8, endpoint=False):
        rim = np.array([0.3, 0.55 * np.cos(a), 0.55 * np.sin(a)])
        d = np.minimum(d, sd_cap_seg(p, rim, np.array([-0.95, 0, 0]), 0.008))
    return np.minimum(d, pay)
def f_disc(p): return sd_cyl_x(p, 0.5, 0.025)
def f_cone_tip(p): return sd_cone_x(p, 0.5, 0.5 / np.tan(np.radians(15)) * 0.6, True)
def f_cone_base(p): return sd_cone_x(p, 0.5, 0.75, False)
def f_cube_face(p): return sd_box(p, np.array([0.45, 0.45, 0.45]))
def f_cube_edge(p): return sd_box(rot_z(p, np.pi / 4), np.array([0.45, 0.45, 0.45]))
def f_cyl_perp(p): return sd_cyl_x(swap(p, (2, 1, 0)), 0.3, 0.6)          # eje z, L/D = 2
def f_cyl_axial(p): return sd_cyl_x(p, 0.45, 0.45)                         # eje x, L/D = 1
def f_drop(p): return sd_round_cone_x(p + np.array([0.6, 0, 0]), 0.4, 0.03, 1.8)
def f_plate(p): return sd_box(p, np.array([0.025, 0.55, 0.4]))
def f_long_cyl(p): return sd_cyl_x(swap(p, (1, 0, 2)), 0.25, 1.4)         # eje y, largo
def f_bar(p): return sd_box(p, np.array([0.25, 1.4, 0.25]))
def f_long_plate(p): return sd_box(p, np.array([0.025, 1.7, 0.3]))

SHAPES = [f_sphere, f_hemi_conv, f_hemi_flat, f_cup, f_chute, f_disc, f_cone_tip,
          f_cone_base, f_cube_face, f_cube_edge, f_cyl_perp, f_cyl_axial, f_drop,
          f_plate, f_long_cyl, f_bar, f_long_plate]

# ---------------------------------------------------------------- camara
CAM0 = np.array([-0.35, -0.72, 0.60])       # aguas arriba, costado y desde arriba
CAM_TOP = np.array([0.0, -0.33, 0.94])     # cubos: desde arriba, cuadrado frente a rombo
LIGHT = np.array([-0.75, -0.35, 0.56]); LIGHT /= np.linalg.norm(LIGHT)
LIGHT2 = np.array([0.6, -0.2, 0.2]); LIGHT2 /= np.linalg.norm(LIGHT2)


def set_cam(c):
    global FWD, RIGHT, UP
    c = np.asarray(c, float)
    FWD = -c / np.linalg.norm(c)
    RIGHT = np.cross(FWD, [0, 0, 1.0]); RIGHT /= np.linalg.norm(RIGHT)
    UP = np.cross(RIGHT, FWD)


set_cam(CAM0)


def proj(pt):
    return np.array([np.dot(pt, RIGHT), np.dot(pt, UP)])


def trace(f, w, h, span, center):
    """devuelve intensidad (h, w) y cobertura (bool)"""
    xs = (np.arange(w) + 0.5) / w - 0.5
    ys = 0.5 - (np.arange(h) + 0.5) / h
    gx, gy = np.meshgrid(xs * span * w / h, ys * span)
    org = (center[None, None, :] + gx[..., None] * RIGHT + gy[..., None] * UP
           - FWD * 8.0)
    t = np.zeros((h, w))
    hit = np.zeros((h, w), bool)
    for _ in range(220):
        p = org + FWD * t[..., None]
        d = f(p)
        hit |= d < 4e-4
        t = np.where(hit, t, t + np.maximum(d * 0.8, 2e-4))
        if (t > 16).all():
            break
    hit &= t < 16
    p = org + FWD * t[..., None]
    e = 1e-3
    n = np.stack([f(p + np.array([e, 0, 0])) - f(p - np.array([e, 0, 0])),
                  f(p + np.array([0, e, 0])) - f(p - np.array([0, e, 0])),
                  f(p + np.array([0, 0, e])) - f(p - np.array([0, 0, e]))], -1)
    n /= np.maximum(length(n)[..., None], 1e-9)
    # dos caras (cascos y placas): la normal mira a la camara
    flip = (n * FWD).sum(-1) > 0
    n[flip] *= -1
    dif = np.clip((n * LIGHT).sum(-1), 0, 1)
    dif2 = np.clip((n * LIGHT2).sum(-1), 0, 1)
    hv = LIGHT - FWD; hv /= np.linalg.norm(hv)
    spec = np.clip((n * hv).sum(-1), 0, 1) ** 24
    I = 0.16 + 0.62 * dif + 0.12 * dif2 + 0.35 * spec
    return np.clip(I, 0, 1), hit


def bounds(f):
    """caja aproximada en pantalla de la figura (muestreo grueso)"""
    I, hit = trace(f, 160, 160, 5.0, np.zeros(3))
    ys, xs = np.nonzero(hit)
    px = (xs + 0.5) / 160 - 0.5
    py = 0.5 - (ys + 0.5) / 160
    return px.min() * 5, px.max() * 5, py.min() * 5, py.max() * 5


def arrow_dir():
    d = proj(np.array([1.0, 0, 0]))
    return d / np.linalg.norm(d)


def render(f, w, h, arrow=True):
    x0, x1, y0, y1 = bounds(f)
    ad = arrow_dir()
    alen = 0.55 * max(x1 - x0, y1 - y0, 1.0)
    # la flecha va aguas arriba del cuerpo, centrada en su altura
    if arrow:
        x0 -= alen * 0.95
    span_y = (y1 - y0) * 1.18
    span_x = (x1 - x0) * 1.18
    span = max(span_y, span_x * h / w)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    center = RIGHT * cx + UP * cy
    I, hit = trace(f, w * SS, h * SS, span, center)
    I = I.reshape(h, SS, w, SS).mean((1, 3))
    cov = hit.reshape(h, SS, w, SS).mean((1, 3))
    hitm = hit.reshape(h, SS, w, SS)
    # intensidad media solo de las submuestras que tocan la figura
    Iobj = np.where(cov > 0, (I * SS * SS) / np.maximum(cov * SS * SS, 1), 0)
    sym = np.zeros((h, w), np.uint8)
    inside = cov >= 0.45
    sym[inside] = 1 + np.clip(np.round(Iobj[inside] * 11), 0, 11).astype(np.uint8)
    # contorno oscuro en el borde de la silueta (mejor lectura en pequeno)
    edge = inside & ~(np.roll(inside, 1, 0) & np.roll(inside, -1, 0) &
                      np.roll(inside, 1, 1) & np.roll(inside, -1, 1))
    if w <= 40:
        sym[edge] = 15
    else:
        sym[edge] = np.minimum(sym[edge], 3)
    if arrow:
        img = Image.fromarray(sym, "L")
        dr = ImageDraw.Draw(img)
        def to_px(px, py):
            return ((px - cx) / span * h + w / 2, (cy - py) / span * h + h / 2)
        tip = np.array([x0 + alen * 0.85, cy + 0.0])
        tail = tip - ad * alen * 0.75
        lw = max(1, int(round(h / 26)))
        a = to_px(*tail); b = to_px(*tip)
        dr.line([a, b], fill=13, width=lw)
        hl = alen * 0.28
        nrm = np.array([-ad[1], ad[0]])
        p1 = tip - ad * hl + nrm * hl * 0.55
        p2 = tip - ad * hl - nrm * hl * 0.55
        dr.polygon([b, to_px(*p1), to_px(*p2)], fill=13)
        sym = np.array(img)
    return sym


def rle(sym):
    out = bytearray()
    flat = sym.flatten()
    i = 0
    while i < len(flat):
        s = flat[i]
        n = 1
        while i + n < len(flat) and flat[i + n] == s and n < 16:
            n += 1
        out.append(((n - 1) << 4) | int(s))
        i += n
    return bytes(out)


def unrle(data, w, h):
    flat = []
    for b in data:
        flat += [b & 15] * ((b >> 4) + 1)
    return np.array(flat[:w * h], np.uint8).reshape(h, w)


def to_rgb(sym):
    pal = np.array(PAL, np.uint8)
    return pal[sym]


def main():
    big, small = [], []
    for k, f in enumerate(SHAPES):
        set_cam(CAM_TOP if f in (f_cube_face, f_cube_edge) else CAM0)
        big.append(render(f, W, H))
        small.append(render(f, TW, TH, arrow=False))
        print("figura %2d listo" % (k + 1), file=sys.stderr)
    n = len(SHAPES)
    hdr = b"PGX" + bytes([VER, n, W, H, TW, TH])
    hdr += b"".join(struct.pack("<H", rgb1555(*c)) for c in PAL)
    off = len(hdr) + 4 * n
    data = bytearray()
    offs_b, offs_s = [], []
    for s in big:
        offs_b.append(off + len(data)); e = rle(s); data += e
        assert (unrle(e, W, H) == s).all()
    for s in small:
        offs_s.append(off + len(data)); e = rle(s); data += e
        assert (unrle(e, TW, TH) == s).all()
    blob = hdr + b"".join(struct.pack("<H", o) for o in offs_b + offs_s) + bytes(data)
    os.makedirs(os.path.join(ROOT, "bin"), exist_ok=True)
    open(os.path.join(ROOT, "bin/PERDGFX.bin"), "wb").write(blob)
    print("PERDGFX: %d figuras, %d bytes" % (n, len(blob)))
    # hoja de contacto: grande x2 y miniatura x2
    names = ["1 Esfera", "2 Hemisf. convexo", "3 Hemisf. plano", "4 Copa hueca",
             "5 Paracaidas", "6 Disco", "7 Cono punta", "8 Cono base", "9 Cubo cara",
             "10 Cubo arista", "11 Cil. perpend.", "12 Cil. axial", "13 Gota",
             "14 Placa rect.", "15 Cil. largo 2D", "16 Barra cuadr.", "17 Placa larga"]
    cols = 4
    cw, ch = W * 2 + 16, H * 2 + TH * 2 + 40
    sheet = Image.new("RGB", (cols * cw, ((n + cols - 1) // cols) * ch), "white")
    dr = ImageDraw.Draw(sheet)
    for k in range(n):
        x, y = (k % cols) * cw + 8, (k // cols) * ch + 6
        bi = Image.fromarray(to_rgb(big[k])).resize((W * 2, H * 2), Image.NEAREST)
        si = Image.fromarray(to_rgb(small[k])).resize((TW * 2, TH * 2), Image.NEAREST)
        sheet.paste(bi, (x, y))
        sheet.paste(si, (x, y + H * 2 + 4))
        dr.text((x + TW * 2 + 8, y + H * 2 + 14), names[k], fill=(0, 0, 0))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tests/cemu/hoja_contacto_cd.png")
    sheet.save(out)
    print("hoja de contacto: %s" % out)


if __name__ == "__main__":
    main()
