#!/usr/bin/env bash
# triage.sh <asan-binary> <input> — reproduce a crash under ASAN/UBSAN and classify it.
# Doctrine: STRIKE. A crash is not a finding until it reproduces, classifies, and dedupes.
set -euo pipefail

# hash stdin with whatever exists (shasum is absent on Git for Windows by default)
hashin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 1
  elif command -v sha1sum >/dev/null 2>&1; then sha1sum
  else openssl sha1; fi
}

BIN="${1:?usage: triage.sh <asan-binary> <input>}"
IN="${2:?}"
LOG=$(ASAN_OPTIONS=abort_on_error=1:symbolize=1:detect_leaks=0 \
      UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 \
      "$BIN" "$IN" 2>&1 || true)

echo "## sanitizer verdict"
echo "$LOG" | grep -m1 -E 'ERROR: AddressSanitizer|runtime error:|\*\*\* stack smashing|SEGV' \
  || echo "(no sanitizer hit — rebuild with -fsanitize=address,undefined)"
echo "## class"
echo "$LOG" | grep -oE 'AddressSanitizer: [A-Za-z0-9 -]+|runtime error: [A-Za-z -]+' \
  | head -1 | sed 's/AddressSanitizer: //;s/runtime error: //' || true
echo "$LOG" | grep -oE 'heap-buffer-overflow|stack-buffer-overflow|stack-buffer-underflow|global-buffer-overflow|dynamic-stack-buffer-overflow|container-overflow|heap-use-after-free|double-free|invalid-free|alloc-dealloc-mismatch|memcpy-param-overlap|negative-size-param|calloc-overflow|stack-overflow|SEGV on unknown address|BUS on unknown address|signed integer overflow|unsigned integer overflow|shift-exponent|misaligned-pointer-use|null-pointer|out of bounds|stack smashing' | head -1 || echo "(unclassified)"
echo "## stack (top user frames)"
echo "$LOG" | grep -E '^\s+#[0-9]+' | grep -v libclang_rt | head -12
echo "## dedupe hash"
echo "$LOG" | grep -E '^\s+#[0-9]+' | grep -v libclang_rt | head -3 \
  | sed -E 's/0x[0-9a-f]+//g;s/==[0-9]+==//g' | tr -s ' ' | hashin | cut -c1-12
echo "## reproducer"
echo "  $BIN $IN"
