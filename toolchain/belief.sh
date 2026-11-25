#!/usr/bin/env bash
# belief.sh <project> <belief> [confidence] — append a belief to a target's log.
set -euo pipefail
P="${1:?}"; B="${2:?}"; C="${3:-unverified}"
T="$HOME/.hermes/targets/$P"
[ -d "$T" ] || { echo "no target '$P' (run target-init.sh first)"; exit 1; }
ID="H-$(date +%s | tail -c 6)"
printf '| %s | %s | %s | open |\n' "$ID" "$B" "$C" >> "$T/beliefs.md"
echo "$ID  $B"
