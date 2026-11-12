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


def te(*vals):
    """Escribe cada valor y pulsa ENTER"""
    out = []
    for v in vals:
        out += typ(v) + ["enter"]
    return out


P02 = te("72", "200", "1000", "0.0015", "0.5+3*0.15+167*0.01+12*0.18+6*0.32",
         "1.007E-6") + ["enter"] + te("53") + ["right"]          # metodo SJ
TOP = ["2nd", "up"]                                                # primer campo
BACK2 = ["clear", "clear"]                                         # al submenu

# (nombre, teclas antes de capturar)
STEPS = [
    ("01_menu_principal", ["enter"]),               # arTIfiCE: ejecuta PERDIDAS
    ("02_menu_tuberia", ["1"]),
    ("03_form_A_vacio", ["1"]),
    ("04_falta_dato", ["graph"]),
    ("05_D_cero", ["down"] + typ("0") + ["enter"]),
    ("06_form_A_P02", ["clear", "clear"] + TOP + P02),
    ("07_resultado_A_P02", ["graph"]),
    ("08_memoria_A_p1", ["y="]),
    ("09_memoria_A_p2", ["right"]),
    ("10_memoria_A_p3", ["right"]),
    ("11_ajustes", ["mode"]),
    ("12_ajustes_abajo", ["down"] * 13),
    ("13_resultado_B_P03", ["clear", "clear", "clear", "2"] + TOP
     + te("43.5", "293", "700", "0.0015", "11.5", "1E-6") + ["enter", "left", "graph"]),
    ("14_memoria_B_p2", ["y=", "right"]),
    ("15_resultado_C_P11", BACK2 + ["4"] + TOP + ["enter"]
     + te("42", "150", "970", "0.0015", "9.4", "1.14E-6", "16", "0.65") + ["enter"]
     + te("890") + ["graph"]),
    ("16_memoria_C_p3", ["y=", "right", "right"]),
    ("17_resultado_D_P17", BACK2 + ["3"] + TOP
     + te("200", "76", "1900", "0.0015", "12.8", "1E-6") + ["enter", "right", "graph"]),
    ("18_memoria_D_p2", ["y=", "right"]),
    ("19_memoria_D_p5", ["right", "right", "right"]),
    ("20_resultado_F_P18", BACK2 + ["5"] + TOP
     + te("200", "285.75", "1900", "0.0015", "12.8", "1E-6", "76") + ["graph"]),
    ("21_resultado_E_P25", BACK2 + ["6"] + TOP
     + te("1135", "1070", "36", "84", "405", "274", "172", "3.5", "1.17E-6")),
    ("22_memoria_E_p2", ["y=", "right"]),
    ("23_resultado_I_P01", BACK2 + ["7"] + TOP + ["enter"] + te("72") + ["enter"]
     + te("200", "1000", "0.0015", "0", "1.007E-6", "150") + ["graph"]),
    ("24_resultado_I_P10", ["clear"] + TOP + ["right", "enter", "enter"]
     + te("100", "300", "4500", "0.045", "5", "1E-6", "130") + ["graph"]),
    ("25_confirmar_salida", ["clear", "clear", "clear", "clear"]),
    ("26_fuera_de_la_app", ["enter", "delay"]),
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
