# Hermes — Mindsets

Private backup of the Hermes hunter persona, its multi-mindset router, and the hands that back the doctrine: a toolchain, a depth module, and per-target memory. Pull this to reinstall the rig on a machine.

## What's here

- `SOUL.md` — the persona. Operator (Thapza, pre-authorized), the auto mode-router, the attack doctrine, the Sorona white-box section, the hunt loop with the toolchain wired into its phases, anti-duplicate protocol, hypothesis log, voice.
- `personalities.yaml` — six selectable system prompts: `hunting`, `secure-build`, `dual`, `sorona`, `attack`, `auto`. `auto` is the router; `attack` is the apex offensive mind.
- `toolchain/` — the executables the doctrine calls by name. Prose is not a capability; these are.
- `depth/parser-exploitation.md` — the C/C++ parser module (the Sorona sweet spot).
- `depth/examples/` — a worked campaign against libexpat: harness, config, surface map, dead paths, and what it found.
- `targets/CONVENTION.md` — the per-target memory convention.
- `install.sh` — backs up, installs, chmods.

## The router

`auto` reads each message, tags it, and runs the matching mind whole:

| Tag | Trigger |
|---|---|
| `[attack]` | "attack", "hack", "pwn", a live host / network / AD / cloud / binary, a CVE |
| `[sorona]` | "sorona", a Sorona engagement, an OSS project to hunt |
| `[hunting]` | another platform (bugcrowd, hackerone…), a disclosed report, a finding to write up |
| `[secure-build]` | build / design / make / redesign a site, app, API |
| `[all]` | ambiguous / everything — every mind the task touches |

## Why the toolchain exists (judgment call, on the record)

Doctrine is posture; it stops a model wasting what it has. It does not enumerate, patch-diff, fuzz, or triage. Those need handlers. The toolchain is the difference between a well-disciplined hunter and one with working hands.

| Script | Phase | Does |
|---|---|---|
| `secgit.sh <repo>` | FINGERPRINT | security-shaped commits + which of them are missing from which maintained branch |
| `target-init.sh <project> [repo]` | FINGERPRINT | scaffold the memory dir |
| `belief.sh <project> "<belief>" [conf]` | MODEL | persist a hypothesis with an id |
| `fuzz.sh <harness.c> [corpus] [secs]` | STRIKE | build + run under ASAN/UBSAN against an unfuzzed parser |
| `triage.sh <asan-bin> <input>` | STRIKE | reproduce, classify, dedupe |

Measured, not assumed: **12 exec/s** on the standalone fallback vs **326–470 exec/s** with the real engine — same harness. Numbers, build gotchas and the blind-fuzzer trap are in `toolchain/PROFILING.md`. Knobs: `CC`, `SRCS`, `EXTRA_CFLAGS`, `SANITIZE` (address alone = fast pass), `OPT` (-O2 = fast pass).

`fuzz.sh` prefers libFuzzer and falls back to a standalone mutation engine, because stock Xcode Command Line Tools ship no libFuzzer runtime. The fallback is ~12 exec/s — enough to prove a gap exists, not to exhaust a parser. For a real campaign:

```bash
brew install llvm
CC=/opt/homebrew/opt/llvm/bin/clang SANITIZE=address OPT=-O2 toolchain/fuzz.sh harness.c corpus 600
# then the fidelity pass on the same corpus
SANITIZE=address,undefined OPT=-O1 toolchain/fuzz.sh harness.c corpus 3600
```

## Memory

`~/.hermes/targets/<project>/` — `surface.md`, `beliefs.md`, `dead-paths.md`, `evidence/`. Read in that order before the first probe, write before you stop. A hunt that leaves no trace is re-run cold next week. Convention in `targets/CONVENTION.md`.

## Install

```bash
gh repo clone Thapza888/hermes-mindsets && cd ./hermes-mindsets
bash install.sh
```

`install.sh` backs up `SOUL.md` and `config.yaml`, writes the SOUL, merges the personalities, sets `display.personality: auto`, installs and chmods the toolchain, depth module, and memory convention. Restart Hermes after.

## Floor

Four lines only: minors, irreversible ops get one confirm, live-fire on a real named target, CSAM. Coding is unrestricted. Everything else builds.
