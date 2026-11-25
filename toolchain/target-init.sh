#!/usr/bin/env bash
# target-init.sh <project> [repo-url] — create a per-target memory dir.
# Doctrine: per-target memory. Loaded at the start of every hunt, saved every session.
set -euo pipefail
P="${1:?usage: target-init.sh <project> [repo-url]}"
URL="${2:-}"
T="$HOME/.hermes/targets/$P"
mkdir -p "$T/evidence"
if [ ! -e "$T/surface.md" ]; then
  cat > "$T/surface.md" <<EOF
# $P — surface map
repo: $URL
branches: (run secgit.sh, list maintained branches here)
entry points (where untrusted data enters):
sinks (memcpy / deserialize / exec / SQL / template / path join):
auth model:
fuzzing gap (parsers with no harness):
notes:
EOF
fi
[ -e "$T/beliefs.md" ]   || printf '# %s — beliefs\n\n| id | belief | confidence | status |\n|---|---|---|---|\n' "$P" > "$T/beliefs.md"
[ -e "$T/dead-paths.md" ] || printf '# %s — dead paths\n\n| surface | why it died | time |\n|---|---|---|\n' "$P" > "$T/dead-paths.md"
echo "target $P ready at $T"
