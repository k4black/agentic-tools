# Global Agent Rules

## Project orientation docs

- When starting work in a project, read (when present): `README.md`, the agent
  instructions (`CLAUDE.md`/`AGENTS.md`), `CONTEXT.md` (domain glossary), and
  `TODO.md` / `PROGRESS.md` — before exploring the code.
- Keep those files updated as you work: a new service/module/command gets described
  in the README, new domain terms go to `CONTEXT.md`, finished/discovered work is
  reflected in `TODO.md`/`PROGRESS.md`. Update in place as part of the change, not
  as a separate chore to ask about.

## Git

- Use Conventional Commits 1.0.0: `<type>[optional scope]: <description>` (e.g. `feat(lang): add Polish language`).
- Keep the first line ≤ 72 characters; no long commit bodie, for complex features short bulletpoints.
- Never add AI-attribution strings to commits or PRs: no `Co-Authored-By: Claude/Codex/...`, no "Generated with ..." footers.
- Commit only when explicitly asked, or when the active workflow/skill inherently requires commits (e.g. babysit-pr, critique-loop).

## RTK — Rust Token Killer

Token-optimized CLI proxy in installed to save context tokens.

### Harness-specific usage

- **Claude Code**: a PreToolUse hook rewrites Bash commands automatically (`git status` → `rtk git status`). Do NOT prefix commands yourself.
- **Codex CLI / all other harnesses** (no hook): always prefix shell commands with `rtk` yourself: `rtk git status`, `rtk cargo test`, `rtk npm run build`, `rtk pytest -q`.
- If `rtk` is not installed on this machine, run commands directly and suggest installing it once.

### Meta commands (always call rtk directly)

```bash
rtk gain              # Token savings analytics
rtk proxy <cmd>       # Execute raw command without filtering (debugging)
rtk --version         # Should show: rtk X.Y.Z
which rtk             # Verify correct binary
```

