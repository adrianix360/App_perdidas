r"""
cemu_golden.py - Corre los casos dorados DENTRO del eZ80 emulado (CEmu, con
el ROM de la calculadora de Adrian y arTIfiCE v2.1) y compara cada valor con
la corrida en float del PC y con el valor esperado.

Uso (desde C:/dev/ti84):  python -I tools/cemu_golden.py
Requiere: tests/cemu/golden/bin/TGOLDEN.8xp y .map (make debug),
          /c/dev/build/tests/golden_f.exe (tools/run_pc_tests.sh),
          ROM en C:/dev/tools/CEmu/ti84ce.rom, librerias en C:/dev/tools/clibs/clibs
"""
import json, os, re, struct, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUN = "C:/dev/build/cemu_run"
ROM = "C:/dev/tools/CEmu/ti84ce.rom"
LIBS = "C:/dev/tools/clibs/clibs"
AUT = "C:/CEdev/bin/cemu-autotester.exe"


def main():
    os.makedirs(RUN, exist_ok=True)
    # v2.0: recompilar TGOLDEN siempre (si cambia la tabla de casos y no se
    # recompila, los valores del eZ80 quedan desalineados con el PC)
    env_make = dict(os.environ, PATH="C:/CEdev/bin;" + os.environ.get("PATH", ""))
    subprocess.run(["make", "debug"], cwd=os.path.join(ROOT, "tests/cemu/golden"),
                   env=env_make, capture_output=True)
    mp = open(os.path.join(ROOT, "tests/cemu/golden/bin/TGOLDEN.map")).read()
    m = re.search(r"0x00(d[0-9a-f]{5})\s+_golden_got\b", mp)
    if not m:
        sys.exit("no se encontro _golden_got en TGOLDEN.map")
    addr = int(m.group(1), 16)
    pc_csv = os.path.join(RUN, "golden_pc.csv")
    subprocess.run(["C:/dev/build/tests/golden_f.exe", "-g", pc_csv], capture_output=True)
    rows = [l.rstrip("\n").split(";") for l in open(pc_csv, encoding="utf-8")]
    n = len(rows)
    for f in os.listdir(RUN):
        if f.startswith("failure_"):
            os.remove(os.path.join(RUN, f))
    for f in ("arTIfiCE_v2.1.8xp",):
        open(os.path.join(RUN, f), "wb").write(open(os.path.join(ROOT, "instalacion", f), "rb").read())
    # v2.0: el programa pasa de 64 KiB y CEdev lo parte en lanzador + AppVars
    gold = [f for f in sorted(os.listdir(os.path.join(ROOT, "tests/cemu/golden/bin")))
            if f.startswith("TGOLDEN.8xp")]
    for f in gold:
        open(os.path.join(RUN, f), "wb").write(
            open(os.path.join(ROOT, "tests/cemu/golden/bin", f), "rb").read())
    cfg = {
        "rom": ROM,
        "transfer_files": ["arTIfiCE_v2.1.8xp"] + gold,
        "target": {"name": "A", "isASM": False},
        "sequence": ["action|launch", "delay|3000", "key|enter", "delay|90000",
                     "hash|1", "hash|2"],
        "hashes": {
            "1": {"description": "pantalla resumen", "start": "vram_start",
                  "size": "vram_16_size", "expected_CRCs": ["00000000"]},
            "2": {"description": "valores obtenidos", "start": hex(addr),
                  "size": str(4 * n), "expected_CRCs": ["00000000"]},
        },
    }
    jp = RUN + "/golden_cemu.json"
    json.dump(cfg, open(jp, "w"), indent=1)
    env = dict(os.environ, AUTOTESTER_LIBS_DIR=LIBS)
    subprocess.run([AUT, "-d", jp], cwd=RUN, env=env, capture_output=True, timeout=900)
    dump = open(os.path.join(RUN, "failure_hash2_num2_dump.bin"), "rb").read()
    ez = struct.unpack("<%df" % n, dump[:4 * n])
    print("| Caso | Magnitud | Esperado | PC (float) | eZ80 (CEmu) | eZ80 vs PC | Resultado eZ80 |")
    print("|---|---|---|---|---|---|---|")
    worst, wcase, cnt = 0.0, "", {"pasa": 0, "pasa (r)": 0, "FALLA": 0}
    for (i, cid, name, exp, dec, trel, tabs, pc), z in zip(rows, ez):
        exp, pc, trel, tabs, dec = float(exp), float(pc), float(trel), float(tabs), int(dec)
        d = abs(z - pc) / abs(pc) if pc else abs(z - pc)
        if d > worst:
            worst, wcase = d, cid + " " + name
        err = abs(z - exp)
        tol = max(trel * abs(exp), tabs)
        if trel == 0 and tabs == 0:
            res = "pasa" if err <= 0.5 else "FALLA"
        elif err <= tol:
            res = "pasa"
        elif err <= 0.5 * 10 ** (-dec):
            res = "pasa (r)"
        else:
            res = "FALLA"
        cnt[res] += 1
        print("| %s | %s | %.10g | %.7g | %.7g | %.1e | %s |" % (cid, name, exp, pc, z, d, res))
    print("\nTotal eZ80: %d pasan, %d pasan (r), %d fallan. Mayor diferencia eZ80 vs PC: %.2e (%s)"
          % (cnt["pasa"], cnt["pasa (r)"], cnt["FALLA"], worst, wcase))
    return 1 if cnt["FALLA"] else 0


if __name__ == "__main__":
    sys.exit(main())
