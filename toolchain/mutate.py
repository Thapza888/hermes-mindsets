#!/usr/bin/env python3
"""mutate.py <binary> <seed-dir> <out-crash-dir> [iterations] [timeout-secs]
Standalone mutation loop for when the toolchain clang has no libFuzzer runtime.
Saves any input that crashes the target into out-crash-dir, deduped by
(class, first user frame) so 400 variants of one bug collapse to one entry.
"""
import os
import random
import re
import subprocess
import sys
import tempfile
import time

BIN, SEED_DIR, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
ITERS = int(sys.argv[4]) if len(sys.argv) > 4 else 5000
TIMEOUT = float(sys.argv[5]) if len(sys.argv) > 5 else 5.0
MAX_UNIQUE = 300

BITS = [0x00, 0x01, 0x02, 0x07, 0x0F, 0x10, 0x1F, 0x20, 0x40, 0x7F,
        0x80, 0xFE, 0xFF]
INTERESTING = [b"\x00", b"\xff" * 4, b"\xff" * 8, b"\x7f\xff\xff\xff",
               b"\x80\x00\x00\x00", b"\xff" * 16, b"0", b"-1", b"%s" * 8,
               b"\x00" * 4096]

FRAME_RE = re.compile(r"in (\S+) (\S+:\d+)")
CLASS_RE = re.compile(r"AddressSanitizer: ([a-z0-9-]+)")


def mutate(data: bytes) -> bytes:
    r = random.random()
    if not data or r < 0.10:
        return bytes(random.choice(BITS) for _ in range(random.randint(1, 40)))
    i = random.randrange(len(data))
    if r < 0.35:                                    # bitflip
        return data[:i] + bytes([data[i] ^ (1 << random.randrange(8))]) + data[i + 1:]
    if r < 0.55:                                    # byte set
        return data[:i] + bytes([random.choice(BITS)]) + data[i + 1:]
    if r < 0.75:                                    # splice
        j = random.randrange(len(data))
        return data[:i] + data[j:j + random.randint(1, 32)] + data[i:]
    if r < 0.88:                                    # truncate
        return data[:max(1, i)]
    if r < 0.95:                                    # append interesting
        return data + random.choice(INTERESTING)
    return data + bytes(random.choice(BITS) for _ in range(random.randint(1, 16)))


def signature(err: str, rc: int) -> str:
    """Collapse a crash report to (class | user frame). Addresses stripped."""
    cls = ""
    for line in err.splitlines():
        m = CLASS_RE.search(line)
        if m:
            cls = m.group(1)
            break
        if "runtime error:" in line:
            cls = "ubsan:" + line.split("runtime error:")[-1].strip()[:48]
            break
    if not cls:
        return "rc:%d" % rc
    for line in err.splitlines():
        if "libclang_rt" in line:
            continue
        m = FRAME_RE.search(line)
        if m:
            return "%s|%s %s" % (cls, m.group(1), m.group(2).split("/")[-1])
    return cls + "|?"


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    seeds = []
    for name in os.listdir(SEED_DIR):
        p = os.path.join(SEED_DIR, name)
        if os.path.isfile(p):
            seeds.append(open(p, "rb").read())
    if not seeds:
        seeds = [b"", b"\x00", b"\xff" * 16, b"A" * 32]
    start = time.time()
    seen, saved, execs = set(), 0, 0
    tmp = tempfile.mkdtemp(prefix="fz_")
    path = os.path.join(tmp, "case")
    env = dict(os.environ, ASAN_OPTIONS="abort_on_error=1:symbolize=1:detect_leaks=0",
               UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=1")
    for n in range(ITERS):
        if len(seen) >= MAX_UNIQUE:
            print("unique-crash cap reached, stopping")
            break
        data = mutate(random.choice(seeds))
        with open(path, "wb") as fh:
            fh.write(data)
        try:
            p = subprocess.run([BIN, path], capture_output=True, timeout=TIMEOUT, env=env)
        except subprocess.TimeoutExpired:
            continue
        execs += 1
        err = p.stderr.decode("utf-8", "replace")
        crashed = ("ERROR: AddressSanitizer" in err or "runtime error:" in err
                   or p.returncode != 0)
        if not crashed:
            if random.random() < 0.01:            # novelty retention
                seeds.append(data)
            continue
        sig = signature(err, p.returncode)
        if sig in seen:
            continue
        seen.add(sig)
        saved += 1
        out = os.path.join(OUT, "crash_%03d_%d" % (saved, n))
        with open(out, "wb") as fh:
            fh.write(data)
        print("[%d/%d] %s\n    -> %s   %s" % (n + 1, ITERS, sig[:110], out, data[:20].hex()))
    print("\n%d unique crashes / %d execs in %ds" %
          (saved, execs, int(time.time() - start)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
