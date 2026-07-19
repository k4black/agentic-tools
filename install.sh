#!/usr/bin/env bash
# One idempotent run hooks every agent harness on this machine:
#   Claude Code, Codex CLI, OpenCode, Cursor, Kilo Code (+ anything reading ~/.agents/skills).
# Safe to re-run any time (after git pull, after adding a skill, on a fresh machine).
#
#   skills/*            -> symlinked into ~/.claude/skills, ~/.agents/skills, ~/.codex/skills
#                          (OpenCode reads ~/.claude/skills + ~/.agents/skills natively)
#                       -> COPIED into ~/.cursor/skills, ~/.kilocode/skills, ~/.kilo/skills
#                          (both tools have known bugs with symlinked skills)
#   GLOBAL-AGENTS.md    -> ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md, ~/.config/opencode/AGENTS.md,
#                          ~/.kilocode/rules/global-agents.md (copy)
#   codex-hooks.json    -> ~/.codex/hooks.json
#   Claude settings.json: merges RTK PreToolUse hook, marketplaces, enabled plugins
#                         (removes the legacy kchernyshev-dotfiles marketplace/plugin).
#
# Copy-based harnesses (Cursor, Kilo) get a fresh sync each run; symlink-based ones track git live.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO/skills"

# --- helpers -----------------------------------------------------------------

# link <target> <linkpath>: idempotent symlink; backs up a pre-existing real file once.
link() {
  local target="$1" linkpath="$2"
  if [ -e "$linkpath" ] && [ ! -L "$linkpath" ]; then
    mv "$linkpath" "$linkpath.pre-agentic-tools.bak"
    echo "  backed up $linkpath -> $linkpath.pre-agentic-tools.bak"
  fi
  ln -sfn "$target" "$linkpath"
  echo "  linked $linkpath -> $target"
}

# --- 1. skills: symlink harnesses -------------------------------------------

for dst in "$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.codex/skills"; do
  mkdir -p "$dst"
  echo "skills -> $dst (symlinks)"
  for skill in "$SKILLS_SRC"/*/; do
    [ -d "$skill" ] || continue
    link "${skill%/}" "$dst/$(basename "$skill")"
  done
  # drop legacy links into the old dotfiles plugin tree and any dangling links
  for existing in "$dst"/*; do
    [ -L "$existing" ] || continue
    target="$(readlink "$existing")"
    if [[ "$target" == *"/.dotfiles/plugins/"* ]] || [ ! -e "$existing" ]; then
      rm "$existing"
      echo "  removed stale $existing -> $target"
    fi
  done
done

# --- 2. skills: copy harnesses (symlink discovery is broken there) ----------

for root in "$HOME/.cursor" "$HOME/.kilocode" "$HOME/.kilo"; do
  [ -d "$root" ] || continue   # only for tools actually present; re-run after installing one
  dst="$root/skills"
  mkdir -p "$dst"
  echo "skills -> $dst (copies)"
  for skill in "$SKILLS_SRC"/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    # drop a stale symlink from an earlier scheme, then sync a real copy
    [ -L "$dst/$name" ] && rm "$dst/$name"
    rsync -a --delete --exclude='.venv' --exclude='__pycache__' "$skill" "$dst/$name/"
    echo "  synced $dst/$name"
  done
done

# --- 3. global rules ---------------------------------------------------------

echo "global rules"
mkdir -p "$HOME/.claude" "$HOME/.codex"
link "$REPO/GLOBAL-AGENTS.md" "$HOME/.claude/CLAUDE.md"
link "$REPO/GLOBAL-AGENTS.md" "$HOME/.codex/AGENTS.md"
if [ -d "$HOME/.config/opencode" ]; then
  link "$REPO/GLOBAL-AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
fi
if [ -d "$HOME/.kilocode" ]; then
  mkdir -p "$HOME/.kilocode/rules"
  cp "$REPO/GLOBAL-AGENTS.md" "$HOME/.kilocode/rules/global-agents.md"
  echo "  copied ~/.kilocode/rules/global-agents.md"
fi

# --- 4. codex hooks ----------------------------------------------------------

link "$REPO/codex-hooks.json" "$HOME/.codex/hooks.json"

# --- 5. Claude Code settings: hooks, marketplaces, plugins -------------------

echo "claude settings merge"
python3 - <<'PY'
import json, os

path = os.path.expanduser("~/.claude/settings.json")
try:
    with open(path) as f:
        s = json.load(f)
except FileNotFoundError:
    s = {}
before = json.dumps(s, sort_keys=True)

# RTK PreToolUse hook (Claude-only; other harnesses use manual rtk prefixing per GLOBAL-AGENTS.md)
pre = s.setdefault("hooks", {}).setdefault("PreToolUse", [])
rtk = {"matcher": "Bash", "hooks": [{"type": "command", "command": "rtk hook claude"}]}
if not any(
    h.get("matcher") == "Bash"
    and any(x.get("command") == "rtk hook claude" for x in h.get("hooks", []))
    for h in pre
):
    pre.append(rtk)

# Third-party marketplaces this setup depends on
mk = s.setdefault("extraKnownMarketplaces", {})
for name, repo in {
    "apple-notes-mcp": "sweetrb/apple-notes-mcp",
    "litestar": "litestar-org/litestar-skills",
    "elastic-agent-skills": "elastic/agent-skills",
}.items():
    mk.setdefault(name, {"source": {"source": "github", "repo": repo}})

# Third-party plugins to enable
ep = s.setdefault("enabledPlugins", {})
for plugin in [
    "superpowers@claude-plugins-official",
    "code-simplifier@claude-plugins-official",
    "claude-md-management@claude-plugins-official",
    "feature-dev@claude-plugins-official",
    "frontend-design@claude-plugins-official",
    "atlassian@claude-plugins-official",
    "apple-notes@apple-notes-mcp",
    "elastic-elasticsearch@elastic-agent-skills",
    "elastic-kibana@elastic-agent-skills",
    "elastic-observability@elastic-agent-skills",
]:
    ep.setdefault(plugin, True)

# Legacy dotfiles plugin path — superseded by this repo's symlinked skills
mk.pop("kchernyshev-dotfiles", None)
ep.pop("personal@kchernyshev-dotfiles", None)

after = json.dumps(s, sort_keys=True)
if after != before:
    with open(path, "w") as f:
        json.dump(s, f, indent=2)
        f.write("\n")
    print("  updated ~/.claude/settings.json")
else:
    print("  ~/.claude/settings.json already up to date")
PY

echo "done — all detected harnesses are wired."
