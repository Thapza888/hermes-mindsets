# Windows

Everything here runs on Windows. The doctrine and the personalities are plain markdown/YAML;
the toolchain scripts are bash and run under **Git Bash**, which is a one-line install.

## Prerequisites

```powershell
winget install Git.Git            # bash for the toolchain
winget install Python.Python.3.12 # mutate.py / triage.sh helper
winget install LLVM.LLVM          # clang + libFuzzer runtime, for real fuzzing
winget install OpenJS.NodeJS.LTS  # only if the app does not bundle node
```

After `Git.Git`, add its bash to PATH (one-time, this user):

```powershell
$gitBash = "${env:ProgramFiles}\Git\bin"
[Environment]::SetEnvironmentVariable(
  'Path', "$env:Path;$gitBash", 'User')
```

Open a new terminal. `bash --version` must answer.

## Install

```powershell
gh repo clone Thapza888/hermes-mindsets
cd hermes-mindsets
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

`install.ps1` backs up `SOUL.md` and `config.yaml`, writes the persona, merges the personalities
with node + js-yaml, sets `display.personality: auto`, installs the toolchain, depth module and
memory convention, and warns if bash is missing. Restart Hermes after.

PowerShell blocks unsigned scripts by default — either `-ExecutionPolicy Bypass` as above, or once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## Running the toolchain

From **Git Bash**, not PowerShell:

```bash
cd /c/Users/<you>/.hermes
toolchain/target-init.sh myproject https://github.com/org/repo.git
toolchain/secgit.sh /c/src/myproject
```

Paths are POSIX under Git Bash (`/c/Users/...`, `/c/src/...`). `$HOME` there is your Windows
profile, so memory lands in the same `targets/` the installer created.

## Fuzzing on Windows

`fuzz.sh` probes `$CC`, then homebrew paths, then `clang` — on Windows only the last two are real.
Give it the LLVM clang explicitly and it will find the runtime:

```bash
CC="/c/Program Files/LLVM/bin/clang.exe" \
SRCS="src/parser.c src/util.c" EXTRA_CFLAGS="-Iinclude" \
SANITIZE=address OPT=-O2 \
toolchain/fuzz.sh harness/parser_fuzz.c corpus 300
```

If libFuzzer will not link, the script falls back to the standalone engine by itself — slower
(~12 exec/s) but it needs nothing beyond clang. Two Windows notes:

- **`-O2` and `SANITIZE=address`** as above; the full ASAN+UBSAN build is the second, slower pass
  and the one you trust.
- **MSVC's `clang-cl` is not a drop-in** for these scripts: `-fsanitize=fuzzer` works, but the
  flag spelling and the CRT differ. Use LLVM's `clang.exe` in a bash shell.

Speed baselines are in `toolchain/PROFILING.md`. Same harness on this hardware: 12 exec/s fallback
versus 326–567 exec/s guided, so the fallback is for proving a gap, not for exhausting a parser.

## Differences from the shell installer

None in outcome. `install.ps1` copies the same files to the same places under `%USERPROFILE%\.hermes`
and performs the same YAML merge. Only the mechanics differ:

| | `install.sh` | `install.ps1` |
|---|---|---|
| shell | bash | PowerShell 5.1+ / 7 |
| home default | `$HOME/.hermes` | `%USERPROFILE%\.hermes` |
| executable bit | `chmod +x` | not used (bash decides) |
| merge | node `-e` inline | node script file, same js-yaml |

## Checking the install

```bash
bash -c 'cd ~/.hermes && ls toolchain'
node -e "const y=require('$HOME/.hermes/hermes-agent/node_modules/js-yaml');const c=y.load(require('fs').readFileSync('$HOME/.hermes/config.yaml','utf8'));console.log(c.display.personality,Object.keys(c.agent.personalities).length)"
```

Expect `auto 6`.
