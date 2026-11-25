#!/usr/bin/env bash
# fuzz.sh <harness.c> [corpus-dir] [seconds] — build + run a coverage-guided fuzz campaign
# with ASAN/UBSAN. Doctrine: SORONA vector B (fuzzing gap).
#
# Engine probe order: $CC, then homebrew llvm, then system clang. If none can link libFuzzer,
# fall back to a standalone mutation loop (no coverage, ~10-15 exec/s).
# bash 3.2 safe.
set -euo pipefail
H="${1:?usage: fuzz.sh <harness.c> [corpus] [seconds]}"
CORPUS="${2:-}"
SECS="${3:-300}"
SRCDIR="$(cd "$(dirname "$H")" && pwd)"
OUT="/tmp/fuzz_$(basename "$H" .c)"
HERE="$(cd "$(dirname "$0")" && pwd)"
OPT="${OPT:--O1}"                     # -O2 raises throughput ~3x at some fidelity cost
SANITS="${SANITIZE:-address,undefined}"   # SANITIZE=address alone is ~3x faster
XCF="${EXTRA_CFLAGS:-}"   # e.g. -I/path/to/lib for a project header

# ── compiler selection ──────────────────────────────────────────────────────
CANDIDATES=()
[ -n "${CC:-}" ] && CANDIDATES+=("$CC")
for c in /opt/homebrew/opt/llvm/bin/clang /usr/local/opt/llvm/bin/clang; do
  [ -x "$c" ] && CANDIDATES+=("$c")
done
CANDIDATES+=("clang")

ENGINE=""
for c in "${CANDIDATES[@]}"; do
  printf 'int LLVMFuzzerTestOneInput(const unsigned char*d,unsigned long n){return 0;}' > /tmp/_fzprobe.c
  if "$c" -fsanitize=fuzzer /tmp/_fzprobe.c -o /tmp/_fzprobe 2>/dev/null; then
    CC="$c"; ENGINE="libfuzzer"
    break
  fi
done
rm -f /tmp/_fzprobe.c /tmp/_fzprobe
[ -n "$ENGINE" ] || { CC="${CC:-clang}"; ENGINE="standalone"; }

SIBLINGS=()
while IFS= read -r f; do
  case "$f" in */"$(basename "$H")") continue ;; esac
  SIBLINGS+=("$f")
done < <(find "$SRCDIR" -maxdepth 2 -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' \) 2>/dev/null || true)

# SRCS="a.c b.c" overrides the sibling scan when the harness sits outside the source tree
[ -n "${SRCS:-}" ] && SIBLINGS=($SRCS)

mkdir -p "$OUT.seeds"
if [ -n "$CORPUS" ] && [ -d "$CORPUS" ]; then cp -n "$CORPUS"/* "$OUT.seeds/" 2>/dev/null || true; fi
[ -n "$(ls -A "$OUT.seeds" 2>/dev/null || true)" ] || {
  printf '' > "$OUT.seeds/empty"
  printf '\x00' > "$OUT.seeds/nul"
  printf '\xff\xff\xff\xff\xff\xff\xff\xff' > "$OUT.seeds/ff8"
  printf 'AAAAAAAAAAAAAAAA' > "$OUT.seeds/a16"
}

echo "## build ($ENGINE, $CC)"
if [ "$ENGINE" = "libfuzzer" ]; then
  $CC -fsanitize=fuzzer,"$SANITS" -fno-omit-frame-pointer -g $OPT $XCF -I"$SRCDIR" "$H" ${SIBLINGS[@]+"${SIBLINGS[@]}"} -o "$OUT" 2>&1 | tail -4
  [ -x "$OUT" ] || { echo "build failed"; exit 1; }
  mkdir -p "$OUT.crashes"
  exec "$OUT" -max_total_time="$SECS" -print_final_stats=1 \
      -artifact_prefix="$OUT.crashes/" "$OUT.seeds"
fi

echo "no libFuzzer-capable compiler — standalone engine (brew install llvm to fix)"
$CC -fsanitize=address,undefined -fno-omit-frame-pointer -g "$OPT" $XCF \
    -I"$SRCDIR" "$H" ${SIBLINGS[@]+"${SIBLINGS[@]}"} -o "$OUT" "$HERE/fuzz_shim.c" 2>&1 | tail -6
[ -x "$OUT" ] || { echo "build failed"; exit 1; }

ITER=$(( SECS * 20 ))
echo "running $ITER mutations (~${SECS}s)"
python3 "$HERE/mutate.py" "$OUT" "$OUT.seeds" "$OUT.crashes" "$ITER"
echo "crashes in $OUT.crashes — triage: $HERE/triage.sh $OUT <input>"
