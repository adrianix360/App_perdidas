r"""
cemu_reset.py - Fase 4 en CEmu (ROM de Adrian, OS 5.8.4 + arTIfiCE v2.1):
pantallas de la biblioteca y de Mis casos, y prueba de que un caso guardado
sobrevive a un reinicio de la RAM.

Secuencia: abre PERDIDAS, usa MAT / SUMA K / FLUIDO, calcula P-03, guarda
el caso "PRUEBA", sale (la app archiva PERDCAS), archiva prgmA y
prgmPERDIDAS desde el menu MEM del sistema, provoca un reinicio de la RAM
(action|reset), vuelve a lanzar arTIfiCE y PERDIDAS desde el archivo y
carga el caso desde Mis casos.

Uso (desde C:/dev/ti84): python -I tools/cemu_reset.py
Deja PNG de cada paso en C:/dev/build/cemu_reset/.
"""
import json, os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUN = "C:/dev/build/cemu_reset"
ROM = "C:/dev/tools/CEmu/ti84ce.rom"
LIBS = "C:/dev/tools/clibs/clibs"
AUT = "C:/CEdev/bin/cemu-autotester.exe"


def typ(s):
    out = []
    for c in s:
        out += ["2nd", ","] if c == "E" else [c]
    return out


def te(*vals):
    out = []
    for v in vals:
        out += typ(v) + ["enter"]
    return out


# (nombre, teclas, formato de la captura: 8 = app graphx, 16 = pantalla del SO)
STEPS = [
    ("01_menu", ["enter"], 8),
    ("02_materiales", ["1", "2", "y="], 8),
    ("03_form_con_PVC", ["enter"], 8),
    ("04_sumador_vacio", ["window"], 8),
    ("05_conjuntos", ["window"], 8),
    ("06_sumador_2025", ["down", "enter"], 8),
    ("07_form_K_12_8", ["graph"], 8),
    ("08_fluidos", ["zoom"], 8),
    ("09_form_P03", ["enter", "2nd", "up"]
     + te("43.5", "293", "700", "0.0015", "11.5", "1E-6"), 8),
    ("10_resultado_P03", ["graph"], 8),
    # nombre PRUEBA con alpha-lock: P=8 R=* U=5 E=sin B=apps A=math
    ("11_nombre_PRUEBA", ["zoom", "8", "*", "5", "sin", "apps", "math"], 8),
    ("12_caso_guardado", ["enter"], 8),
    ("13_mis_casos", ["enter", "clear", "clear", "clear", "4"], 8),
    ("14_salida_app", ["clear", "clear", "enter", "delay"], 16),
    # salir de arTIfiCE y archivar A y PERDIDAS desde MEM (2nd +, 5:Archive)
    ("15_archivados", ["mode", "delay", "clear", "2nd", "+", "5", "prgm", "1", "enter",
                       "delay", "2nd", "+", "5", "prgm", "2", "enter", "delay"], 16),
    ("16_tras_reinicio", ["RESET"], 16),
    ("17_artifice_desde_archivo", ["LAUNCH"], 16),
    ("18_perdidas_desde_archivo", ["enter", "delay"], 8),
    ("19_mis_casos_tras_reinicio", ["4"], 8),
    ("20_caso_cargado", ["enter", "delay"], 8),
]


def main():
    if os.path.isdir(RUN):
        shutil.rmtree(RUN)
    os.makedirs(RUN)
    for f in ("instalacion/arTIfiCE_v2.1.8xp", "bin/PERDIDAS.8xp", "bin/PERDIDAS.8xp.0.8xv",
              "bin/PERDIDAS.8xp.1.8xv", "bin/PERDTXT.8xv"):
        shutil.copy(os.path.join(ROOT, f), RUN)
    seq = ["action|launch", "delay|3000"]
    hashes = {}
    for i, (name, keys, _) in enumerate(STEPS, 1):
        for k in keys:
            if k == "delay":
                seq.append("delay|2500")
            elif k == "RESET":
                seq += ["action|reset", "delay|6000"]
            elif k == "LAUNCH":
                seq += ["key|clear", "delay|1500", "action|launch", "delay|3000"]
            else:
                seq.append("key|" + k)
        seq += ["delay|800", "hash|%d" % i]
        hashes[str(i)] = {"description": name, "start": "vram_start",
                          "size": "vram_16_size", "expected_CRCs": ["00000000"]}
    cfg = {"rom": ROM, "transfer_files": ["arTIfiCE_v2.1.8xp", "PERDIDAS.8xp.0.8xv", "PERDIDAS.8xp.1.8xv", "PERDTXT.8xv", "PERDIDAS.8xp"],
           "target": {"name": "A", "isASM": False}, "delay_after_key": 200,
           "sequence": seq, "hashes": hashes}
    jp = RUN + "/reset.json"
    json.dump(cfg, open(jp, "w"), indent=1)
    env = dict(os.environ, AUTOTESTER_LIBS_DIR=LIBS)
    p = subprocess.run([AUT, "-d", jp], cwd=RUN, env=env, capture_output=True,
                       text=True, timeout=1800)
    for l in (p.stdout + p.stderr).splitlines():
        if "[Error]" in l:
            print("AUTOTESTER:", l.strip())
    for f in sorted(os.listdir(RUN)):
        m = re.match(r"failure_hash(\d+)_num\d+_dump\.bin", f)
        if m:
            name, _, fmt = STEPS[int(m.group(1)) - 1]
            tool = "vram8png.py" if fmt == 8 else "vram2png.py"
            subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", tool),
                            os.path.join(RUN, f), os.path.join(RUN, name + ".png")])
    print("capturas en", RUN)


if __name__ == "__main__":
    main()
