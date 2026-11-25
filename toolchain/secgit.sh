#!/usr/bin/env bash
# secgit.sh <repo-dir> — security-shaped commit scan + backport-gap finder.
# A security commit that is NOT on every maintained branch is a live, unpatched vuln candidate.
# Doctrine: SORONA vector A. Run before reading code.
set -euo pipefail
REPO="${1:?usage: secgit.sh <repo-dir>}"
cd "$REPO"

echo "## security-shaped commits (last 200)"
git log --all -i -E --grep='security|cve|overflow|bypass|bounds|sanitiz|harden|validate|fix check|edge case' \
  --pretty='%h %ad %s' --date=short | head -200
echo

echo "## branches"
git for-each-ref --format='%(refname:short)' refs/heads refs/remotes | sed 's#^origin/##' | sort -u
echo

echo "## backport gaps (security commit missing on some branch)"
ALL=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes | sed 's#^origin/##' | sort -u)
COMMITS=$(git log --all -i -E --grep='security|cve|overflow|bypass|bounds|sanitiz|harden' --pretty='%H')
for c in $COMMITS; do
  short=$(git rev-parse --short "$c")
  subj=$(git log -1 --pretty='%s' "$c")
  have=$(git branch -a --contains "$c" 2>/dev/null | sed 's#^[* ]*##;s#remotes/##;s#^origin/##' | sort -u)
  miss=$(comm -23 <(printf '%s\n' "$ALL") <(printf '%s\n' "$have") 2>/dev/null || true)
  if [ -n "$miss" ]; then
    echo "--- $short  $subj"
    echo "    missing on: $(printf '%s' "$miss" | tr '\n' ' ')"
  fi
done
