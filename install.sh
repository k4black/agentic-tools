#!/usr/bin/env bash
# One idempotent run hooks every agent harness on this machine:
#   Claude Code, Codex CLI, OpenCode (+ anything reading ~/.agents/skills).
# Safe to re-run any time (after git pull, after adding a skill, on a fresh machine).
#
#   skills/*            -> symlinked into ~/.claude/skills, ~/.agents/skills, ~/.codex/skills
#                          (OpenCode reads ~/.claude/skills + ~/.agents/skills natively)
#   GLOBAL-AGENTS.md    -> ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md, ~/.config/opencode/AGENTS.md
#   rtk hook            -> installed by rtk's own installer (rtk init)
#   Claude plugins/MCP  -> installed via the claude/codex CLIs (never hand-edited configs)
#   ralph/              -> ~/.ralph/config.yml + ~/.config/ralph/presets (ralph-orchestrator)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO/skills"

# --- helpers -----------------------------------------------------------------

# ralph_supported: ralph >= 2.10 (split config: -H collections, backend_args).
# Older monolithic-preset binaries would misread our assets — warn and skip.
ralph_supported() {
  command -v ralph >/dev/null 2>&1 || return 1
  local v major minor
  v="$(ralph --version 2>/dev/null | awk '{print $NF}')"
  major="${v%%.*}"
  minor="${v#*.}"; minor="${minor%%.*}"
  [ "${major:-0}" -gt 2 ] || { [ "${major:-0}" -eq 2 ] && [ "${minor:-0}" -ge 10 ]; }
}

# link <target> <linkpath>: idempotent symlink; backs up a pre-existing real file.
link() {
  local target="$1" linkpath="$2"
  if [ -e "$linkpath" ] && [ ! -L "$linkpath" ]; then
    local bak="$linkpath.pre-agentic-tools.$(date +%Y%m%d%H%M%S).bak"
    mv "$linkpath" "$bak"
    echo "  backed up $linkpath -> $bak"
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
  # cleanup, ownership-scoped: only links we (or the legacy dotfiles setup) created
  for existing in "$dst"/*; do
    [ -L "$existing" ] || continue
    target="$(readlink "$existing")"
    if [[ "$target" == *"/.dotfiles/plugins/"* ]] \
       || { [[ "$target" == "$SKILLS_SRC/"* ]] && [ ! -e "$existing" ]; }; then
      rm "$existing"
      echo "  removed stale $existing -> $target"
    fi
  done
done

# --- 2. global rules ----------------------------------------------------------

echo "global rules"
mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.config/opencode"
link "$REPO/GLOBAL-AGENTS.md" "$HOME/.claude/CLAUDE.md"
link "$REPO/GLOBAL-AGENTS.md" "$HOME/.codex/AGENTS.md"
link "$REPO/GLOBAL-AGENTS.md" "$HOME/.config/opencode/AGENTS.md"

# --- 3. rtk hook (rtk's own installer; no hand-edited configs) ---------------

if command -v rtk >/dev/null 2>&1; then
  echo "rtk hook (rtk init)"
  rtk init -g --hook-only --auto-patch
else
  echo "rtk not installed — skipping hook setup (install rtk, then re-run)"
fi

# --- 4. Claude Code marketplaces + plugins (via claude CLI, never hand-edits) -

if command -v claude >/dev/null 2>&1; then
  echo "claude marketplaces"
  marketplaces="$(claude plugin marketplace list 2>/dev/null || true)"
  add_marketplace() {
    local name="$1" source="$2"
    if grep -q "$name" <<<"$marketplaces"; then
      echo "  marketplace $name ok"
    else
      claude plugin marketplace add "$source"
      echo "  added marketplace $name"
    fi
  }
  add_marketplace "litestar" "litestar-org/litestar-skills"
  add_marketplace "elastic-agent-skills" "elastic/agent-skills"
  if ralph_supported; then
    add_marketplace "ralph-orchestrator" "mikeyobrien/ralph-orchestrator"
  fi

  # legacy sources, superseded by this repo / dropped
  for legacy in kchernyshev-dotfiles apple-notes-mcp; do
    if grep -q "$legacy" <<<"$marketplaces"; then
      claude plugin marketplace remove "$legacy"
      echo "  removed legacy marketplace $legacy"
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
    # `claude plugin list` prints full plugin@marketplace ids — match exactly
    if grep -qF "$plugin" <<<"$installed"; then
      echo "  $plugin ok"
    else
      claude plugin install "$plugin"
      echo "  installed $plugin"
    fi
  done

  # ralph's own skills (ralph-hats, ralph-loop, ralph-docs) — only useful with ralph
  if ralph_supported; then
    plugin="ralph-orchestrator@ralph-orchestrator"
    if grep -qF "$plugin" <<<"$installed"; then
      echo "  $plugin ok"
    else
      claude plugin install "$plugin"
      echo "  installed $plugin"
    fi
  fi
else
  echo "claude CLI not installed — skipping plugin setup (install claude, then re-run)"
fi

# --- 5. MCP servers (via each CLI, never hand-edits) --------------------------

# Dart/Flutter MCP server (https://docs.flutter.dev/ai/mcp-server), needs Dart >= 3.9
if command -v dart >/dev/null 2>&1; then
  echo "mcp servers"
  if command -v claude >/dev/null 2>&1; then
    if claude mcp list 2>/dev/null | grep -q '^dart:'; then
      echo "  claude: dart ok"
    else
      claude mcp add --scope user --transport stdio dart -- dart mcp-server
      echo "  claude: added dart"
    fi
  fi
  if command -v codex >/dev/null 2>&1; then
    if codex mcp list 2>/dev/null | grep -q 'dart'; then
      echo "  codex: dart ok"
    else
      codex mcp add dart -- dart mcp-server --force-roots-fallback
      echo "  codex: added dart"
    fi
  fi
else
  echo "dart not installed — skipping Dart/Flutter MCP server"
fi

# ralph-orchestrator MCP server — drive ralph loops from Claude Code directly
if ralph_supported && command -v claude >/dev/null 2>&1; then
  if claude mcp list 2>/dev/null | grep -q '^ralph:'; then
    echo "  claude: ralph ok"
  else
    claude mcp add --scope user ralph -- ralph mcp
    echo "  claude: added ralph"
  fi
fi

# --- 6. ralph-orchestrator: global config + shared presets --------------------

if ralph_supported; then
  echo "ralph global config + presets"
  mkdir -p "$HOME/.ralph" "$HOME/.config/ralph"
  link "$REPO/ralph/config.yml" "$HOME/.ralph/config.yml"
  link "$REPO/ralph/presets" "$HOME/.config/ralph/presets"
else
  echo "ralph missing or < 2.10 — skipping (npm i -g @ralph-orchestrator/ralph-cli, then re-run)"
fi

echo "done — all detected harnesses are wired."
