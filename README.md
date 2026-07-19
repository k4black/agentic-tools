# agentic-tools

Personal agentic setup: skills, global agent rules, hooks, and workflows — separated from
dotfiles (which stays a pure shell/system config repo).

**One command wires every agent harness on any machine, idempotently:**

```bash
./install.sh
```

Re-run it any time: after `git pull`, after adding a skill, after installing a new agent CLI.

## What it wires

| Harness | Skills | Global rules |
|---|---|---|
| Claude Code | `~/.claude/skills/*` (symlinks) | `~/.claude/CLAUDE.md` → `GLOBAL-AGENTS.md` |
| Codex CLI | `~/.codex/skills/*` + `~/.agents/skills/*` (symlinks) | `~/.codex/AGENTS.md` → `GLOBAL-AGENTS.md` |
| OpenCode | reads `~/.claude/skills` + `~/.agents/skills` natively | `~/.config/opencode/AGENTS.md` → `GLOBAL-AGENTS.md` |

Tool configuration is never hand-edited: the RTK hook is installed by `rtk init`, Claude Code
marketplaces/plugins through the `claude plugin` CLI, and MCP servers (Dart/Flutter) through
`claude mcp add` / `codex mcp add` — so a fresh machine gets the full setup in one run.

Everything is symlinked, so the harnesses track this repo live (edit a SKILL.md, it's live everywhere).

## Layout

```
skills/            canonical skill tree — agentskills.io spec, one folder per skill
GLOBAL-AGENTS.md   single source of truth for global rules (git conventions, RTK usage)
ralph/             reusable ralph-orchestrator templates (scaffold)
install.sh         the idempotent bootstrap
```

## Skills

| Skill | Purpose |
|---|---|
| `anki-connect` | Create/find/update Anki flashcards via AnkiConnect |
| `apple-notes` | Read/reorganize Apple Notes without stripping hyperlinks |
| `apple-reminders` | Add/view/complete Apple Reminders |
| `babysit-pr` | Drive a PR to merge-ready: fix CI, resolve bot review threads (gh-only) |
| `critique-loop` | Cross-model adversarial review (Codex/Cursor navigator), plan + code flows |
| `domain-modeling` | Maintain a project's domain model / ubiquitous language / ADRs |
| `grill-me` | Relentless interview to stress-test a plan until shared understanding |

Skills follow the [Agent Skills spec](https://agentskills.io/specification) (`SKILL.md` + optional
`scripts/`, `references/`), validated in CI.

Credits: `babysit-pr` and `critique-loop` are adapted from
[gzaripov/agent-skills](https://github.com/gzaripov/agent-skills) (MIT).
