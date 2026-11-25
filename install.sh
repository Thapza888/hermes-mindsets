#!/usr/bin/env bash
# Install the Hermes hunter persona, multi-mindset router, toolchain, depth module,
# and memory convention into a local Hermes install.
set -euo pipefail
H="${HERMES_HOME:-$HOME/.hermes}"
DIR="$(cd "$(dirname "$0")" && pwd)"

[ -d "$H" ] || { echo "no Hermes home at $H (set HERMES_HOME)"; exit 1; }

NODE="$(command -v node || true)"
if [ -z "$NODE" ]; then
  for c in "$H"/tools/node-*/bin/node; do [ -x "$c" ] && NODE="$c" && break; done
fi
[ -n "$NODE" ] || { echo "node not found (install node or use the Hermes-bundled one)"; exit 1; }

JSY="$H/hermes-agent/node_modules/js-yaml"
[ -e "$JSY" ] || { echo "js-yaml not found at $JSY"; exit 1; }

TS="$(date +%Y%m%d-%H%M%S)"
cp -p "$H/SOUL.md"  "$H/SOUL.md.bak-$TS"  2>/dev/null || true
cp -p "$H/config.yaml" "$H/config.yaml.bak-$TS" 2>/dev/null || true

cp "$DIR/SOUL.md" "$H/SOUL.md"

"$NODE" -e '
const fs=require("fs"), y=require(process.argv[1]);
const H=process.argv[2];
const pers=y.load(fs.readFileSync(process.argv[3],"utf8")).personalities;
const cfg=y.load(fs.readFileSync(H+"/config.yaml","utf8"));
cfg.agent=cfg.agent||{}; cfg.agent.personalities=pers;
cfg.display=cfg.display||{}; cfg.display.personality="auto";
fs.writeFileSync(H+"/config.yaml", y.dump(cfg,{indent:2,lineWidth:-1,noRefs:true}));
console.log("personalities merged, display.personality=auto");
' "$JSY" "$H" "$DIR/personalities.yaml"

# toolchain
mkdir -p "$H/toolchain" "$H/depth" "$H/targets"
cp "$DIR"/toolchain/*.sh "$DIR"/toolchain/*.py "$H/toolchain/"
chmod +x "$H"/toolchain/*.sh "$H"/toolchain/*.py

# depth module
cp "$DIR"/depth/*.md "$H/depth/"

# memory convention (never clobber an existing one)
[ -e "$H/targets/CONVENTION.md" ] || cp "$DIR"/targets/CONVENTION.md "$H/targets/CONVENTION.md"

echo "toolchain: $(ls "$H/toolchain" | tr '\n' ' ')"
echo "depth:     $(ls "$H/depth" | tr '\n' ' ')"
echo "done. restart Hermes."
