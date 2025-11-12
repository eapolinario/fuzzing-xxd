# /// script
# ///

import os, subprocess, sys, tempfile, shutil, time, random
from pathlib import Path

# CONFIG
XXDA = "/home/eduardo/repos/eapolinario-ggd/build/ggd"   # path to implementation A
XXDB = "xxd"   # path to implementation B
SEED_DIR = Path("seeds")  # folder with seed hexdumps (raw bytes or textual hexdump)
OUT_DIR = Path("diff_findings")
OUT_DIR.mkdir(exist_ok=True)

RADAMSA = shutil.which("radamsa")  # optional

def mutate(data: bytes) -> bytes:
    if RADAMSA:
        p = subprocess.Popen([RADAMSA], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        out, _ = p.communicate(data)
        return out
    # simple fallback: flip random bytes, insert random ascii hex
    b = bytearray(data)
    for _ in range(max(1, len(b)//50)):
        i = random.randrange(0, len(b))
        b[i] = random.randrange(0, 256)
    # sometimes insert ascii hex-like chars to exercise parser
    if random.random() < 0.2:
        pos = random.randrange(0, len(b))
        b[pos:pos] = b" deadbeef "
    return bytes(b)

def run_xxd(binary_path, input_bytes):
    try:
        p = subprocess.run([binary_path, "-r"], input=input_bytes,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return 124, b"", b"TIMED OUT"

def save_case(prefix, inp, a_out, b_out, a_err, b_err):
    ts = int(time.time()*1000)
    base = OUT_DIR / f"{prefix}_{ts}"
    base.mkdir(parents=True, exist_ok=True)
    (base / "input.bin").write_bytes(inp)
    (base / "xxdA.stdout").write_bytes(a_out)
    (base / "xxdB.stdout").write_bytes(b_out)
    (base / "xxdA.stderr").write_bytes(a_err)
    (base / "xxdB.stderr").write_bytes(b_err)

# load seeds
seeds = []
for p in SEED_DIR.glob("*"):
    if p.is_file():
        seeds.append(p.read_bytes())

if not seeds:
    print("No seeds found in seeds/. Please add some example hexdumps (text files).")
    sys.exit(1)

# main loop
iters = 0
try:
    while True:
        iters += 1
        seed = random.choice(seeds)
        mutated = mutate(seed)
        a_rc, a_out, a_err = run_xxd(XXDA, mutated)
        b_rc, b_out, b_err = run_xxd(XXDB, mutated)

        # crash detection
        if a_rc != 0 and a_rc != 1:  # adjust acceptable rc if needed
            print(f"[ITER {iters}] crash/err in A rc={a_rc}")
            save_case("crashA", mutated, a_out, b_out, a_err, b_err)
        if b_rc != 0 and b_rc != 1:
            print(f"[ITER {iters}] crash/err in B rc={b_rc}")
            save_case("crashB", mutated, a_out, b_out, a_err, b_err)

        # behavioral difference: stdout binary different OR one produced output and the other didn't
        if a_out != b_out or a_rc != b_rc:
            print(f"[ITER {iters}] DIFF rcA={a_rc} rcB={b_rc} sizeA={len(a_out)} sizeB={len(b_out)}")
            save_case("diff", mutated, a_out, b_out, a_err, b_err)

        if iters % 100 == 0:
            print(f"iters={iters}")
except KeyboardInterrupt:
    print("Stopped by user")
