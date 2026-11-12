r"""
cemu_ui.py - Prueba la interfaz de PERDIDAS dentro de CEmu (ROM de Adrian,
OS 5.8.4 + arTIfiCE v2.1) con el autotester de CEdev. Cada paso teclea una
secuencia y captura la pantalla (CRC32 + PNG en C:/dev/build/cemu_ui/).

Uso (desde C:/dev/ti84):
  python -I tools/cemu_ui.py            captura y guarda los CRC en
                                        tests/cemu/autotest_ui.json
  python -I tools/cemu_ui.py --check    vuelve a correr y compara contra
                                        los CRC guardados (regresion)
"""
import json, os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUN = "C:/dev/build/cemu_ui"
ROM = "C:/dev/tools/CEmu/ti84ce.rom"
LIBS = "C:/dev/tools/clibs/clibs"
AUT = "C:/CEdev/bin/cemu-autotester.exe"
SAVED = os.path.join(ROOT, "tests/cemu/autotest_ui.json")

# El autotester de CEdev v15.0 solo acepta los simbolos (no "dot", "add"...)
CH = {}


def typ(s):
    """Teclas para escribir un numero o expresion"""
    out = []
    for c in s:
        if c == "E":
            out += ["2nd", ","]
        else:
            out.append(CH.get(c, c))
    return out


P02 = (typ("72") + ["enter"] + typ("200") + ["enter"] + typ("1000") + ["enter"]
       + typ("0.0015") + ["enter"] + typ("0.5+3*0.15+167*0.01+12*0.18+6*0.32")
       + ["enter"] + typ("1.007E-6") + ["enter", "enter", "right"])

# (nombre, teclas antes de capturar)
STEPS = [
    ("01_menu_principal", ["enter"]),               # arTIfiCE: ejecuta PERDIDAS
    ("02_menu_tuberia", ["1"]),
    ("03_form_A_vacio", ["1"]),
    ("04_falta_dato", ["graph"]),
    ("05_D_cero", ["down"] + typ("0") + ["enter"]),
    ("06_form_A_P02", ["clear", "clear", "2nd", "up"] + P02),
    ("07_resultado_P02", ["graph"]),
    ("08_resultado_abajo", ["down"] * 6),
    ("09_aviso_memoria", ["y="]),
    ("10_vuelve_resultado", ["enter"]),
    ("11_ajustes", ["mode"]),
    ("12_ajustes_abajo", ["down"] * 13),
    ("13_vuelve_resultado", ["clear"]),
    ("14_vuelve_form", ["clear"]),
    ("15_menu_tuberia", ["clear"]),
    ("16_aviso_pendiente", ["2"]),
    ("17_biblioteca", ["enter", "clear", "3"]),
    ("18_ayuda", ["clear", "6"]),
    ("19_ayuda_pag2", ["right"]),
    ("20_confirmar_salida", ["graph", "clear"]),
    ("21_fuera_de_la_app", ["enter", "delay"]),
]


def build_cfg(crcs=None):
    seq = ["action|launch", "delay|3000"]
    hashes = {}
    for i, (name, keys) in enumerate(STEPS, 1):
        for k in keys:
            seq.append("delay|1500" if k == "delay" else "key|" + k)
        seq += ["delay|700", "hash|%d" % i]
        hashes[str(i)] = {"description": name, "start": "vram_start",
                          "size": "vram_16_size",
                          "expected_CRCs": [crcs[name]] if crcs else ["00000000"]}
    return {"rom": ROM, "transfer_files": ["arTIfiCE_v2.1.8xp", "PERDIDAS.8xp"],
            "target": {"name": "A", "isASM": False}, "delay_after_key": 150,
            "sequence": seq, "hashes": hashes}


def main():
    check = "--check" in sys.argv
    if os.path.isdir(RUN):
        shutil.rmtree(RUN)
    os.makedirs(RUN)
    shutil.copy(os.path.join(ROOT, "instalacion/arTIfiCE_v2.1.8xp"), RUN)
    shutil.copy(os.path.join(ROOT, "bin/PERDIDAS.8xp"), RUN)
    crcs = None
    if check:
        crcs = {}
        saved = json.load(open(SAVED))
        for h in saved["hashes"].values():
            crcs[h["description"]] = h["expected_CRCs"][0]
    cfg = build_cfg(crcs)
    jp = RUN + "/ui.json"
    json.dump(cfg, open(jp, "w"), indent=1)
    env = dict(os.environ, AUTOTESTER_LIBS_DIR=LIBS)
    p = subprocess.run([AUT, "-d", jp], cwd=RUN, env=env, capture_output=True,
                       text=True, timeout=1200)
    for l in p.stdout.splitlines() + p.stderr.splitlines():
        if "[Error]" in l:
            print("AUTOTESTER:", l.strip())
    got = {}
    for m in re.finditer(r'Hash #(\d+) \("([^"]+)"\).*?\(got ([0-9A-F]+)\)', p.stdout):
        got[m.group(2)] = m.group(3)
    for m in re.finditer(r'Hash #(\d+) \("([^"]+)"\) had a matching CRC', p.stdout):
        got[m.group(2)] = "ok"
    for f in sorted(os.listdir(RUN)):
        m = re.match(r"failure_hash(\d+)_num\d+_dump\.bin", f)
        if m:
            name = STEPS[int(m.group(1)) - 1][0]
            subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools/vram8png.py"),
                            os.path.join(RUN, f), os.path.join(RUN, name + ".png")])
    if check:
        m = re.search(r"Out of (\d+) tests attempted, (\d+) passed, and (\d+) failed", p.stdout)
        if not m:
            print(p.stdout[-2000:])
            return 2
        bad = [n for n, _ in STEPS if n in got and got[n] != "ok"]
        if int(m.group(3)) and not bad:
            bad = ["(sin detalle)"]
        print("Regresion de interfaz en CEmu: %d de %d pantallas iguales" % (len(STEPS) - len(bad), len(STEPS)))
        for n in bad:
            print("  distinta:", n, "(ver %s/%s.png)" % (RUN, n))
        return 1 if bad else 0
    for n, _ in STEPS:
        print(n, got.get(n, "SIN CAPTURA"))
    final = build_cfg({n: got[n] for n, _ in STEPS if n in got})
    final["rom"] = "ti84ce.rom (ruta en AUTOTESTER_ROM o editar aqui)"
    json.dump(final, open(SAVED, "w"), indent=1)
    print("CRC guardados en", SAVED)
    return 0


if __name__ == "__main__":
    sys.exit(main())
