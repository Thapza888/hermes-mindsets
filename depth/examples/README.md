# Example — a worked parser campaign (expat)

Not a toy. This is the harness and the target notes from a live campaign against libexpat
2.11.0, kept because a working example beats a described one.

## What is here

- `expat_fuzz.c` — chunked-input fuzzer. DTD declarations and namespaces live, external entities
  stubbed to OK, start-tag handler reads `XML_GetIdAttributeIndex` (the field that was
  uninitialised before 2.11), `volatile` sink consumes the result so `-O1` cannot elide the work.
- `expat_config.h` — hand-written config so the library builds without cmake.
- `expat-surface.md` — the surface map: entry points, sinks, backport state at the time.
- `expat-dead-paths.md` — what was tried and killed, with the reason. Read this before repeating
  any of it.

## Run it

From a checkout of `github.com/libexpat/libexpat`, with `lib/` in the tree:

```bash
CC=/opt/homebrew/opt/llvm/bin/clang \
SRCS="lib/xmlparse.c lib/xmltok.c lib/xmlrole.c lib/xcs.c lib/random_arc4random_buf.c" \
EXTRA_CFLAGS="-I<dir-with-expat_config.h> -Ilib" \
SANITIZE=address OPT=-O2 \
toolchain/fuzz.sh path/to/expat_fuzz.c corpus 300
```

Then once something lands, re-run the corpus under the fidelity build
(`SANITIZE=address,undefined OPT=-O1`) before you believe it.

## What it found

No library crash in the first ~20k execs — expat is OSS-Fuzz'd and mature. The yield was in the
build and harness, three real bugs paid for once:

- unresolved `xcsncmp`/`xcsnstr` (in `lib/xcs.c`) linked fine and called `NULL` at `pc=0`
- `strlen()` on the `EntityDeclHandler` value, which is not NUL-terminated
- the copy elided at `-O1` until the sink became `volatile`

Throughput numbers and every other gotcha: `toolchain/PROFILING.md`.
