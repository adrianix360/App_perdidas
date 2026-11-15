r"""
cemu_sheet.py - Rehace los PNG de la ultima corrida de cemu_ui.py (con la
paleta de PERDGFX) y arma la hoja de contacto del catalogo de C_D con las
17 fichas de detalle capturadas en CEmu (tests/cemu/hoja_contacto_cemu.png).
Uso (desde C:/dev/ti84), despues de python -I tools/cemu_ui.py --flujos (sin --check):
  python -I tools/cemu_sheet.py
"""
import importlib.util, os, subprocess, sys
from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUN = "C:/dev/build/cemu_flujos"
sys.argv.append("--flujos")   # el catalogo esta en FLUJOS
spec = importlib.util.spec_from_file_location("cu", os.path.join(ROOT, "tools/cemu_ui.py"))
cu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cu)

for i, (name, _) in enumerate(cu.STEPS, 1):
    f = os.path.join(RUN, "failure_hash%d_num%d_dump.bin" % (i, i))
    if os.path.exists(f):
        subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools/vram8png.py"),
                        f, os.path.join(RUN, name + ".png")])

# fichas de detalle: cada captura tiene la ficha actual y la anterior en
# los dos buferes; se toman las mitades distintas en orden de aparicion
halves = []
for name, _ in cu.STEPS:
    if "_cat_detalle_" not in name or not os.path.exists(os.path.join(RUN, name + ".png")):
        continue
    im = Image.open(os.path.join(RUN, name + ".png")).convert("RGB")
    for h in (im.crop((0, 0, 320, 240)), im.crop((328, 0, 648, 240))):
        if not any(ImageChops.difference(h, o).getbbox() is None for o in halves):
            halves.append(h)
# fuera la lista (pantalla previa a la primera ficha): fila marcada en celeste
halves = [h for h in halves if h.getpixel((300, 20)) != (170, 205, 255)]
cols = 3
n = len(halves)
sheet = Image.new("RGB", (cols * 330, ((n + cols - 1) // cols) * 250), "white")
for k, h in enumerate(halves):
    sheet.paste(h, ((k % cols) * 330, (k // cols) * 250))
out = os.path.join(ROOT, "tests/cemu/hoja_contacto_cemu.png")
sheet.save(out)
print("%d pantallas en %s" % (n, out))
