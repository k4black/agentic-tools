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
| Codex CLI | `~/.codex/skills/*` + `~/.agents/skills/*` (symlinks) | `~/.codex/AGENTS.md` → `GLOBAL-AGENTS.md`, `hooks.json` |
| OpenCode | reads `~/.claude/skills` + `~/.agents/skills` natively | `~/.config/opencode/AGENTS.md` → `GLOBAL-AGENTS.md` |
| Cursor | `~/.cursor/skills/*` (copies — symlink discovery is buggy) | per-project only (no global file support) |
| Kilo Code | `~/.kilocode/skills/*`, `~/.kilo/skills/*` (copies) | `~/.kilocode/rules/global-agents.md` (copy) |

It also merges into `~/.claude/settings.json`: the RTK PreToolUse hook, third-party marketplaces,
and the enabled-plugin list — so a fresh machine gets the full plugin set in one run.

Symlink-based harnesses track this repo live (edit a SKILL.md, it's live everywhere).
Copy-based harnesses (Cursor, Kilo) re-sync on each `install.sh` run.

## Layout

```
skills/            canonical skill tree — agentskills.io spec, one folder per skill
GLOBAL-AGENTS.md   single source of truth for global rules (git conventions, RTK usage)
codex-hooks.json   Codex CLI hooks (→ ~/.codex/hooks.json)
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
