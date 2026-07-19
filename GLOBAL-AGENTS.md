# Global Agent Rules

Single source of truth for all agent harnesses. Installed by `install.sh` as
`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md`, `~/.kilocode/rules/global-agents.md`.

## Git

- Use Conventional Commits 1.0.0: `<type>[optional scope]: <description>` (e.g. `feat(lang): add Polish language`). No long commit bodies.
- Never add AI-attribution strings to commits or PRs: no `Co-Authored-By: Claude/Codex/...`, no "Generated with ..." footers.
- Commit only when explicitly asked, or when the active workflow/skill inherently requires commits (e.g. babysit-pr, critique-loop).

## RTK — Rust Token Killer

Token-optimized CLI proxy (60–90% savings on dev operations).

### Harness-specific usage

- **Claude Code**: a PreToolUse hook rewrites Bash commands automatically (`git status` → `rtk git status`). Do NOT prefix commands yourself.
- **Codex CLI / all other harnesses** (no hook): always prefix shell commands with `rtk` yourself: `rtk git status`, `rtk cargo test`, `rtk npm run build`, `rtk pytest -q`.

### Meta commands (always call rtk directly)

```bash
rtk gain              # Token savings analytics
rtk gain --history    # Command usage history with savings
rtk discover          # Analyze agent history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (debugging)
```

### Verification

```bash
rtk --version         # Should show: rtk X.Y.Z
which rtk             # Verify correct binary
```

⚠️ **Name collision**: if `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.
