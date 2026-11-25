#!/usr/bin/env bash
# fuzz.sh <harness.c> [corpus-dir] [seconds] — build + run a fuzz campaign with ASAN/UBSAN.
# Doctrine: SORONA vector B (fuzzing gap). Point it at a parser that has no fuzz target.
# Prefers libFuzzer; falls back to a standalone mutation loop when the clang has no
# libFuzzer runtime (stock Xcode Command Line Tools). bash 3.2 safe.
set -euo pipefail
H="${1:?usage: fuzz.sh <harness.c> [corpus] [seconds]}"
CORPUS="${2:-}"
SECS="${3:-300}"
SRCDIR="$(cd "$(dirname "$H")" && pwd)"
OUT="/tmp/fuzz_$(basename "$H" .c)"
CC="${CC:-clang}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SAN="-fsanitize=address,undefined -fno-omit-frame-pointer -g -O1"

SIBLINGS=()
while IFS= read -r f; do
  case "$f" in */"$(basename "$H")") continue ;; esac
  SIBLINGS+=("$f")
done < <(find "$SRCDIR" -maxdepth 2 -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' \) 2>/dev/null || true)

mkdir -p "$OUT.seeds"
if [ -n "$CORPUS" ] && [ -d "$CORPUS" ]; then cp -n "$CORPUS"/* "$OUT.seeds/" 2>/dev/null || true; fi
[ -n "$(ls -A "$OUT.seeds" 2>/dev/null || true)" ] || {
  printf '' > "$OUT.seeds/empty"
  printf '\x00' > "$OUT.seeds/nul"
  printf '\xff\xff\xff\xff\xff\xff\xff\xff' > "$OUT.seeds/ff8"
  printf 'AAAAAAAAAAAAAAAA' > "$OUT.seeds/a16"
}

echo "## build (libFuzzer)"
if $CC -fsanitize=fuzzer,address,undefined -fno-omit-frame-pointer -g -O1 \
      -I"$SRCDIR" "$H" ${SIBLINGS[@]+"${SIBLINGS[@]}"} -o "$OUT" 2>"$OUT.build.log"; then
  echo "libFuzzer engine"
  "$OUT" -max_total_time="$SECS" -print_final_stats=1 "$OUT.seeds"
  exit $?
fi
tail -3 "$OUT.build.log"
echo "## no libFuzzer runtime — standalone engine (ASAN/UBSAN only)"

SHIM="/tmp/fuzz_shim_$$.c"
cat > "$SHIM" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
int LLVMFuzzerTestOneInput(const unsigned char*, size_t);
int main(int argc, char **argv) {
    if (argc < 2) return 2;
    FILE *f = fopen(argv[1], "rb");
    if (!f) return 2;
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    if (n < 0) { fclose(f); return 2; }
    unsigned char *b = malloc((size_t)n + 1);
    size_t got = fread(b, 1, (size_t)n, f);
    fclose(f);
    LLVMFuzzerTestOneInput(b, got);
    free(b);
    return 0;
}
EOF

$CC $SAN -I"$SRCDIR" "$SHIM" "$H" ${SIBLINGS[@]+"${SIBLINGS[@]}"} -o "$OUT" 2>&1 | tail -6
rm -f "$SHIM"
[ -x "$OUT" ] || { echo "build failed"; exit 1; }

ITER=$(( SECS * 20 ))
echo "running $ITER mutations (~${SECS}s)"
python3 "$HERE/mutate.py" "$OUT" "$OUT.seeds" "$OUT.crashes" "$ITER"
echo "crashes in $OUT.crashes — triage: $HERE/triage.sh $OUT <input>"
echo "note: standalone engine is ~10-15 exec/s. For a real campaign install llvm:"
echo "      brew install llvm   then   CC=/opt/homebrew/opt/llvm/bin/clang $0 $H \"$CORPUS\" $SECS"
