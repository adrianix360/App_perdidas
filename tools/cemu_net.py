r"""
cemu_net.py - Fase 5 en CEmu (ROM de Adrian, OS 5.8.4 + arTIfiCE v2.1):
sistemas S-01 a S-05 tecleados en el formulario, memoria de calculo y
graficas de LE y LP (sistemas y tubo simple con bomba).
Uso (desde C:/dev/ti84): python -I tools/cemu_net.py  -> PNG en C:/dev/build/cemu_net/
"""
import json, os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUN = "C:/dev/build/cemu_net"
ROM = "C:/dev/tools/CEmu/ti84ce.rom"
LIBS = "C:/dev/tools/clibs/clibs"
AUT = "C:/CEdev/bin/cemu-autotester.exe"
FILES = ["arTIfiCE_v2.1.8xp", "PERDIDAS.8xp.0.8xv", "PERDIDAS.8xp.1.8xv",
         "PERDTXT.8xv", "PERDIDAS.8xp"]


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


_mode = [0]


def net(np_, mode, H, kp, Qk, pipes):
    """Teclas para un sistema desde el menu principal hasta el resultado"""
    k = ["2", "2nd", "up"] + te(str(np_))
    if mode != _mode[0]:
        k.append("right")
        _mode[0] = mode
    k.append("down")
    k += (["down"] + te(kp, Qk)) if mode else (te(H) + ["down", "down"])
    k += te("1E-6") + ["down", "down"]
    for tr, L, D, f, K in pipes:
        k += te(tr, L, D, f) + ["down"] + te(K)
    return k


S01 = [("1", "100", "150", "0.020", "0")] + [("2", "100", "100", "0.015", "5")] * 3
S02 = [("1", "500", "150", "0.014", "0"), ("1", "600", "100", "0.018", "0"),
       ("2", "700", "200", "0.015", "5")]
S03 = [("1", "100", "100", "0.025", "0"), ("2", "100", "100", "0.025", "0"),
       ("2", "100", "200", "0.020", "30"), ("3", "100", "100", "0.025", "0")]
S04 = [("1", "400", "200", "0.02", "0"), ("2", "180", "100", "0.025", "0"),
       ("2", "50", "100", "0.025", "0"), ("2", "400", "200", "0.02", "0")]
S05 = [("1", "700", "300", "0.014", "5"), ("2", "600", "150", "0.020", "0"),
       ("2", "500", "200", "0.011", "0"), ("3", "600", "250", "0.028", "3")]
BACK = ["clear", "clear"]           # del resultado al menu principal

STEPS = [
    ("01_menu", ["enter"]),
    ("02_S01_resultado", net(4, 0, "20", 0, 0, S01)),
    ("03_S01_memoria_p2", ["y=", "right"]),
    ("04_S01_memoria_p3", ["right"]),
    ("05_S01_grafica", ["window"]),
    ("06_S02_resultado", ["clear"] + BACK + net(3, 0, "20", 0, 0, S02)),
    ("07_S03_resultado", BACK + net(4, 0, "24", 0, 0, S03)),
    ("08_S03_grafica", ["window"]),
    ("09_S04_resultado", ["clear"] + BACK + net(4, 1, 0, "4", "40", S04)),
    ("10_S04_memoria_p4", ["y=", "right", "right", "right"]),
    ("11_S05_resultado", BACK + net(4, 0, "75", 0, 0, S05)),
    ("12_S05_grafica", ["window"]),
    # tubo simple con bomba (P-20: Hs = 76, Q 200, D 285.75, ...) y su grafica
    ("13_P20_bomba", ["clear"] + BACK + ["1", "4", "2nd", "up", "enter"]
     + te("200", "285.75", "1900", "0.0015", "12.8", "1E-6", "76", "0.60") + ["graph"]),
    ("14_P20_grafica", ["window"]),
]


def main():
    if os.path.isdir(RUN):
        shutil.rmtree(RUN)
    os.makedirs(RUN)
    shutil.copy(os.path.join(ROOT, "instalacion", FILES[0]), RUN)
    for f in FILES[1:]:
        shutil.copy(os.path.join(ROOT, "bin", f), RUN)
    seq = ["action|launch", "delay|3000"]
    hashes = {}
    for i, (name, keys) in enumerate(STEPS, 1):
        seq += ["key|" + k for k in keys]
        seq += ["delay|1200", "hash|%d" % i]
        hashes[str(i)] = {"description": name, "start": "vram_start",
                          "size": "vram_16_size", "expected_CRCs": ["00000000"]}
    cfg = {"rom": ROM, "transfer_files": FILES, "target": {"name": "A", "isASM": False},
           "delay_after_key": 150, "sequence": seq, "hashes": hashes}
    jp = RUN + "/net.json"
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
            name = STEPS[int(m.group(1)) - 1][0]
            subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools/vram8png.py"),
                            os.path.join(RUN, f), os.path.join(RUN, name + ".png")])
    print("capturas en", RUN)


if __name__ == "__main__":
    main()
