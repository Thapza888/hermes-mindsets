# PROFILING — the fuzzing engine, measured

Judgment call goes both ways: if the toolchain is the hands, the engine has to be measured, not
assumed. These are real numbers from this machine (Apple silicon, macOS 26.6.2), taken against
**libexpat 2.11.0 `xmlparse.c`** with a chunked-input harness under ASAN. Same harness, same
corpus, only the build changed.

| Build | Sanitizer | Optimisation | exec/s | New units / run |
|---|---|---|---|---|
| `fuzz.sh` fallback (standalone mutation, no coverage) | ASAN+UBSAN | -O1 | **~12** | n/a (no coverage) |
| libFuzzer, blind (no `-fsanitize=fuzzer` on the objects) | ASAN+UBSAN | -O1 | **395,581** | 0 — no coverage feedback |
| libFuzzer, instrumented, `XML_ParserReset` reuse | ASAN+UBSAN | -O1 | **111** | 549 / 45 s |
| libFuzzer, instrumented, create/free per input | ASAN+UBSAN | -O1 | **137** | 700 / 60 s |
| libFuzzer, instrumented, create/free per input | ASAN only | -O2 | **326–470** | 564 / 20 s |
| libFuzzer, same build, 241 s sustained campaign | ASAN only | -O2 | **567** | 4350 / 241 s |

Conclusions that changed the tool:

1. **12 → 326–470 exec/s, same harness.** ~30× is the real cost of the missing runtime, not a
   rounding error. The fallback exists so a gap can still be proven on a machine with no llvm; it
   is not the engine you fuzz with.
2. **Blind libFuzzer is fast and almost useless.** Without `-fsanitize=fuzzer` on the compile
   step you get 395k exec/s and *zero* new corpus units — the mutator never learns. If a campaign
   reports no coverage growth, this is why.
3. **`XML_ParserReset` reuse lost to create/free** (111 vs 137/s). Reset re-allocates more than it
   saves. Counter-intuitive; measure it on the target rather than assuming.
4. **Speed climbs with a warm corpus.** The 20 s probe ran 326–470/s; the 241 s campaign on the
   same build hit 567/s and 136,666 execs, because small high-coverage units win and the mutator
   spends its time near them. Short probes under-report throughput by roughly a third.
5. **UBSAN costs ~3×.** `SANITIZE=address` alone is the speed build. Run the fast build to find
   crashes, then re-run the interesting corpus under the full ASAN+UBSAN build before believing a
   result — UBSAN catches the overflows the crash-only fuzzer walks past.

## Gotchas, all of them paid for in this session

- **`-lc++` on the link line** when the libFuzzer runtime archive is linked by hand: the runtime is
  C++ and the driver does not add the stdlib for a `.a` pull-in.
- **Compile every source the parser needs.** The harness linked fine, then SEGV'd at `pc=0` in
  `XML_Parse` because two symbols (`xcsncmp`, `xcsnstr`, in `lib/xcs.c`) were unresolved and
  `-undefined,dynamic_lookup` bound them to NULL. A silent unresolved symbol is a null call.
- **A harness that does not consume its output proves nothing.** `malloc(16); memcpy(p, d, len);
  free(p);` at `-O1` — the copy is elided because nothing reads `p`. Store into a `volatile` sink
  or return a checksum.
- **`strlen()` on a length-carrying field.** expat's `EntityDeclHandler` hands you `value` with
  `valueLength`; the value is not terminated. `strlen(value)` reported a heap-buffer-overflow in
  the harness on a five-byte DTD that the library handled fine. Use the length.
- **`fuzzer-no-link` vs `fuzzer`.** Coverage needs instrumentation on every unit; `main` comes
  from the link. One command with `-fsanitize=fuzzer,...` does both. A separate `-c` pass that
  omits it silently loses coverage.
- **Stock Xcode clang ships no libFuzzer runtime** and its `expat.h` is old. Point `CC` at
  homebrew llvm and `EXTRA_CFLAGS` at the project headers, or you build against the SDK's copy and
  lose the new API.

## Corpus hygiene

240 s at 567/s grew the corpus 328 MB — units had bloated to 71 KB because the harness accepts any
size. Cap it on real targets: `-max_len=65536` (or the protocol's real ceiling) keeps units small,
and small units are where the speed is. Re-minimise a fat corpus with `-merge=1` before a long run.

## Reproducing this table

```bash
CC=/opt/homebrew/opt/llvm/bin/clang \
SRCS="lib/xmlparse.c lib/xmltok.c lib/xmlrole.c lib/xcs.c lib/random_arc4random_buf.c" \
EXTRA_CFLAGS="-I. -Ilib" \
SANITIZE=address OPT=-O2 \
toolchain/fuzz.sh harness/parser_fuzz.c corpus 60
```

Then the fidelity pass, same corpus:

```bash
SANITIZE=address,undefined OPT=-O1 toolchain/fuzz.sh harness/parser_fuzz.c corpus 600
```
