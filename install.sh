#!/usr/bin/env bash
# One idempotent run hooks every agent harness on this machine:
#   Claude Code, Codex CLI, OpenCode (+ anything reading ~/.agents/skills).
# Safe to re-run any time (after git pull, after adding a skill, on a fresh machine).
#
#   skills/*            -> symlinked into ~/.claude/skills, ~/.agents/skills, ~/.codex/skills
#                          (OpenCode reads ~/.claude/skills + ~/.agents/skills natively)
#   GLOBAL-AGENTS.md    -> ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md, ~/.config/opencode/AGENTS.md
#   rtk hook            -> installed by rtk's own installer (rtk init)
#   Claude plugins      -> installed via the claude CLI (marketplaces + plugins)

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

# --- 1. skills: symlink into every harness dir -------------------------------

for dst in "$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.codex/skills"; do
  mkdir -p "$dst"
  echo "skills -> $dst"
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

# --- 2. global rules ----------------------------------------------------------

echo "global rules"
mkdir -p "$HOME/.claude" "$HOME/.codex"
link "$REPO/GLOBAL-AGENTS.md" "$HOME/.claude/CLAUDE.md"
link "$REPO/GLOBAL-AGENTS.md" "$HOME/.codex/AGENTS.md"
if [ -d "$HOME/.config/opencode" ]; then
  link "$REPO/GLOBAL-AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
fi

# --- 3. rtk hook (rtk's own installer; no hand-edited configs) ---------------

if command -v rtk >/dev/null 2>&1; then
  echo "rtk hook (rtk init)"
  rtk init -g --hook-only
else
  echo "rtk not installed — skipping hook setup (install rtk, then re-run)"
fi

# --- 4. Claude Code marketplaces + plugins (via claude CLI, never hand-edits) -

if command -v claude >/dev/null 2>&1; then
  echo "claude marketplaces"
  marketplaces="$(claude plugin marketplace list 2>/dev/null || true)"
  add_marketplace() {
    local name="$1" source="$2"
    if ! grep -q "$name" <<<"$marketplaces"; then
      claude plugin marketplace add "$source" && echo "  added marketplace $name"
    else
      echo "  marketplace $name ok"
    fi
  }
  add_marketplace "litestar" "litestar-org/litestar-skills"
  add_marketplace "elastic-agent-skills" "elastic/agent-skills"

  # legacy sources, superseded by this repo / dropped
  for legacy in kchernyshev-dotfiles apple-notes-mcp; do
    if grep -q "$legacy" <<<"$marketplaces"; then
      claude plugin marketplace remove "$legacy" && echo "  removed legacy marketplace $legacy"
    fi
  done

  echo "claude plugins"
  installed="$(claude plugin list 2>/dev/null || true)"
  for plugin in \
    superpowers@claude-plugins-official \
    code-simplifier@claude-plugins-official \
    claude-md-management@claude-plugins-official \
    feature-dev@claude-plugins-official \
    frontend-design@claude-plugins-official \
    atlassian@claude-plugins-official \
    elastic-elasticsearch@elastic-agent-skills \
    elastic-kibana@elastic-agent-skills \
    elastic-observability@elastic-agent-skills \
  ; do
    if ! grep -q "${plugin%%@*}" <<<"$installed"; then
      claude plugin install "$plugin" && echo "  installed $plugin"
    else
      echo "  $plugin ok"
    fi
  done
else
  echo "claude CLI not installed — skipping plugin setup (install claude, then re-run)"
fi

echo "done — all detected harnesses are wired."
