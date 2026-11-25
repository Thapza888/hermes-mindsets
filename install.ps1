<#
.SYNOPSIS
  Install the Hermes hunter persona, multi-mindset router, toolchain, depth module and
  memory convention on Windows.

.DESCRIPTION
  Windows-native counterpart to install.sh. Same end state: SOUL.md written, personalities
  merged, display.personality=auto, toolchain + depth + convention installed.

  The toolchain scripts are bash. They run under Git Bash (Git for Windows) — it is a hard
  prerequisite for the scripts themselves, not for this installer. Fuzzing additionally needs
  an LLVM clang; without one, fuzz.sh degrades to its standalone engine.

.PARAMETER HermesHome
  Hermes home. Defaults to $env:HERMES_HOME, else %USERPROFILE%\.hermes

.EXAMPLE
  .\install.ps1
  .\install.ps1 -HermesHome D:\rig\.hermes
#>
[CmdletBinding()]
param([string]$HermesHome)

$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $HermesHome) { $HermesHome = $env:HERMES_HOME }
if (-not $HermesHome) { $HermesHome = Join-Path $env:USERPROFILE '.hermes' }
if (-not (Test-Path $HermesHome)) {
  throw "no Hermes home at $HermesHome (pass -HermesHome, or set HERMES_HOME)"
}

$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) {
  $node = Get-ChildItem -Path (Join-Path $HermesHome 'tools') -Filter 'node.exe' -Recurse -ErrorAction SilentlyContinue |
          Select-Object -First 1 -ExpandProperty FullName
}
if (-not $node) { throw 'node not found (install Node, or use the Hermes-bundled one)' }

$jsyaml = Join-Path $HermesHome 'hermes-agent\node_modules\js-yaml'
if (-not (Test-Path $jsyaml)) { throw "js-yaml not found at $jsyaml" }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$soul = Join-Path $HermesHome 'SOUL.md'
$cfg = Join-Path $HermesHome 'config.yaml'
if (Test-Path $soul) { Copy-Item $soul "$soul.bak-$stamp" }
if (Test-Path $cfg) { Copy-Item $cfg "$cfg.bak-$stamp" }

Copy-Item (Join-Path $dir 'SOUL.md') $soul -Force

# ── personality merge ────────────────────────────────────────────────────────
$merge = Join-Path ([System.IO.Path]::GetTempPath()) "hermes-merge-$stamp.js"
@'
const fs = require("fs"), path = require("path"), y = require(process.argv[2]);
const home = process.argv[3], src = process.argv[4];
const pers = y.load(fs.readFileSync(src, "utf8")).personalities;

// js-yaml output wins over a hand-rolled parser; config.yaml must round-trip
const cfgPath = path.join(home, "config.yaml");
const cfg = y.load(fs.readFileSync(cfgPath, "utf8")) || {};
cfg.agent = cfg.agent || {};
cfg.agent.personalities = pers;
cfg.display = cfg.display || {};
cfg.display.personality = "auto";
fs.writeFileSync(cfgPath, y.dump(cfg, { indent: 2, lineWidth: -1, noRefs: true }));
console.log("personalities merged, display.personality=auto");
'@ | Set-Content -Path $merge -Encoding utf8
& $node $merge $jsyaml $HermesHome (Join-Path $dir 'personalities.yaml')
if ($LASTEXITCODE -ne 0) { throw 'personality merge failed' }
Remove-Item $merge -Force

# ── toolchain, depth, convention ────────────────────────────────────────────
$tc = Join-Path $HermesHome 'toolchain'
$dp = Join-Path $HermesHome 'depth'
$tg = Join-Path $HermesHome 'targets'
New-Item -ItemType Directory -Force -Path $tc, $dp, $tg | Out-Null

Get-ChildItem (Join-Path $dir 'toolchain') -File | Copy-Item -Destination $tc -Force
if (-not (Test-Path (Join-Path $tg 'CONVENTION.md'))) {
  Copy-Item (Join-Path $dir 'targets\CONVENTION.md') (Join-Path $tg 'CONVENTION.md')
}

Get-ChildItem (Join-Path $dir 'depth') -Filter '*.md' -File | Copy-Item -Destination $dp -Force
$ex = Join-Path $dp 'examples'
New-Item -ItemType Directory -Force -Path $ex | Out-Null
Get-ChildItem (Join-Path $dir 'depth\examples') -File | Copy-Item -Destination $ex -Force

Write-Host "toolchain: $((Get-ChildItem $tc -File).Name -join ' ')"
Write-Host "depth:     $((Get-ChildItem $dp -File).Name -join ' ') + examples"

if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
  Write-Warning 'bash not on PATH — the toolchain scripts will not run until Git for Windows is installed (winget install Git.Git) and its bash is on PATH.'
} else {
  Write-Host 'bash found — toolchain runnable.'
}
Write-Host 'done. restart Hermes.'
