#!/usr/bin/env bash
# Validate every skill against the agentskills.io spec (skills-ref).
# Claude Code extension fields (argument-hint, disable-model-invocation) are
# stripped before validation — they are harness extensions, not spec fields.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail=0
for skill in skills/*/; do
  name=$(basename "$skill")
  cp -R "$skill" "$tmp/$name"
  sed -i.bak -E '/^(argument-hint|disable-model-invocation):/d' "$tmp/$name/SKILL.md"
  rm -f "$tmp/$name/SKILL.md.bak"
  if out=$(npx --yes skills-ref@0.1.5 validate "$tmp/$name" 2>&1); then
    echo "Valid skill: $name"
  else
    echo "$out" | sed "s|$tmp/|skills/|g"
    fail=1
  fi
done
exit $fail
