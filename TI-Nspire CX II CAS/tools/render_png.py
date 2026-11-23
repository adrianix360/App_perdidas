#!/usr/bin/env python
"""Renderiza un volcado de operaciones (mock.dump_ops, JSON) a PNG.

Uso: python -I tools/render_png.py ops.json out.png [--scale 2]
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

_fonts = {}


def get_font(size, bold):
    key = (size, bold)
    if key in _fonts:
        return _fonts[key]
    f = None
    for name in (("arialbd.ttf" if bold else "arial.ttf"), "DejaVuSans.ttf"):
        try:
            f = ImageFont.truetype(name, int(size))
            break
        except OSError:
            pass
    if f is None:
        try:
            f = ImageFont.load_default(size=int(size))
        except TypeError:
            f = ImageFont.load_default()
    _fonts[key] = f
    return f


def render(data, scale=1):
    w, h = data["w"], data["h"]
    S = scale
    img = Image.new("RGB", (w * S, h * S), (255, 255, 255))
    d = ImageDraw.Draw(img)
    color = (0, 0, 0)
    pen = 1
    font = ("sansserif", "r", 11)

    def sc(v):
        return int(round(v * S))

    def pts(flat):
        return [(sc(flat[i]), sc(flat[i + 1])) for i in range(0, len(flat) - 1, 2)]

    for op in data["ops"]:
        n, a = op[0], op[1:]
        if n == "setColorRGB":
            color = (int(a[0]), int(a[1]), int(a[2]))
        elif n == "setPen":
            pen = 2 if a and a[0] in ("medium", "thick") else 1
        elif n == "setFont":
            font = (a[0], a[1] or "r", min(24, max(7, a[2] or 11)))
        elif n == "fillRect":
            d.rectangle([sc(a[0]), sc(a[1]), sc(a[0] + a[2]) - 1, sc(a[1] + a[3]) - 1], fill=color)
        elif n == "drawRect":
            d.rectangle([sc(a[0]), sc(a[1]), sc(a[0] + a[2]), sc(a[1] + a[3])], outline=color, width=S)
        elif n == "drawLine":
            d.line([sc(a[0]), sc(a[1]), sc(a[2]), sc(a[3])], fill=color, width=S * pen)
        elif n == "drawPolyLine":
            p = pts(a[0])
            if len(p) > 1:
                d.line(p, fill=color, width=S * pen)
        elif n == "fillPolygon":
            p = pts(a[0])
            if len(p) > 2:
                d.polygon(p, fill=color)
        elif n in ("drawArc", "fillArc"):
            box = [sc(a[0]), sc(a[1]), sc(a[0] + a[2]), sc(a[1] + a[3])]
            start, ang = a[4], a[5]
            args = (-(start + ang), -start)
            if n == "fillArc":
                d.pieslice(box, *args, fill=color)
            else:
                d.arc(box, *args, fill=color, width=S)
        elif n == "drawString":
            ft = get_font(font[2] * S * 0.95, font[1] in ("b", "bi"))
            d.text((sc(a[1]), sc(a[2])), a[0], fill=color, font=ft)
        elif n == "drawImage":
            im = a[0] if isinstance(a[0], dict) else {"image": [8, 8]}
            iw, ih = im["image"]
            d.rectangle([sc(a[1]), sc(a[2]), sc(a[1] + iw), sc(a[2] + ih)],
                        outline=(200, 0, 200), width=S)
        # clipRect: ignorado
    return img


def main():
    args = list(sys.argv[1:])
    scale = 1
    if "--scale" in args:
        i = args.index("--scale")
        scale = int(args[i + 1])
        del args[i:i + 2]
    if len(args) != 2:
        sys.exit(__doc__)
    with open(args[0], "r", encoding="utf-8") as fh:
        data = json.load(fh)
    render(data, scale).save(args[1])
    print("escrito", args[1])


if __name__ == "__main__":
    main()
