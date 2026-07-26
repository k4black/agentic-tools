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
| ralph-orchestrator | `~/.config/ralph/presets` → `ralph/presets/` | `~/.ralph/config.yml` → `ralph/config.yml` |

Tool configuration is never manually-edited: the RTK hook is installed by `rtk init`, Claude Code
marketplaces/plugins through the `claude plugin` CLI, and MCP servers (Dart/Flutter, ralph)
through `claude mcp add` / `codex mcp add` — so a fresh machine gets the full setup in one run.
ralph-orchestrator (≥ 2.10) additionally gets a global config with repo-local skill injection
and five custom hat-collection presets (see `ralph/README.md`).

Read-only commands (`ls`, `grep`, `find`, `git log/diff/…`, `gh pr view/…` and their `rtk`
variants) are pre-approved in every repo: `permissions/claude-allow.json` is merged into
user-level `~/.claude/settings.json` (rules merge additively across scopes; project denies
still win), and `permissions/codex.rules` is an execpolicy file symlinked into
`~/.codex/rules/` (additive — codex's own "always allow" amendments stay in `default.rules`).
Deliberately excluded: `rtk proxy` (arbitrary passthrough), test runners, `gh api`.

Everything is symlinked, so the harnesses track this repo live (edit a SKILL.md, it's live everywhere).

## Layout

```
skills/            canonical skill tree — agentskills.io spec, one folder per skill
GLOBAL-AGENTS.md   single source of truth for global rules (git conventions, RTK usage)
ralph/             ralph-orchestrator global config, custom presets (design-doc, implement[-plus], tdd[-plus]), project template
permissions/       pre-approved read-only commands: claude-allow.json (merged into
                   ~/.claude/settings.json) + codex.rules (execpolicy, symlinked)
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
| `design-doc` | Research → grill → write `docs/design/yyyy-MM-dd-<slug>.md` feature design doc |
| `domain-modeling` | Maintain the project's Terminology section (domain glossary) in AGENTS.md |
| `github-project-setup` | Harden a GitHub repo to one target state: squash-only merges, protected default branch (ruleset), Dependabot, PR-title lint (user-triggered) |
| `grill-me` | Relentless interview to stress-test a plan until shared understanding |
| `handoff` | Compact the current conversation into a handoff doc for the next session |
| `improve-agents-md` | Create/audit/compress a project's AGENTS.md/CLAUDE.md against the canonical structure, decide which areas earn nested files (user-triggered) |
| `improve-codebase-architecture` | Scan for module-deepening opportunities, visual HTML report, grill through picks |
| `test-driven-dev` | Test-driven development: red-green loop, pre-agreed seams, vertical slices |

Skills follow the [Agent Skills spec](https://agentskills.io/specification) (`SKILL.md` + optional
`scripts/`, `references/`, `agents/openai.yaml` for Codex metadata), validated in CI
(`scripts/validate-skills.sh`).

## Shared project conventions

The skills and ralph presets interlock through a small set of per-project files — these are the
agreements to check when editing any skill:

| File (in the target project) | Owner / consumers |
|---|---|
| `docs/design/yyyy-MM-dd-<slug>.md` | Written by `design-doc` (skill or ralph preset); input to `implement`/`tdd` loops. **Decisions are locked** — implementers don't re-open them, changes go through the doc first. Also the home for standalone hard-to-reverse decisions (no separate ADR system). Monorepos: may live per sub-project (`<sub>/docs/design/`) |
| `CLAUDE.md` / `AGENTS.md` | Agent instructions in the `improve-agents-md` skill's canonical structure (CLAUDE.md is a symlink), including the **Terminology** section (glossary, maintained by `domain-modeling` — vocabulary source for `design-doc`, `test-driven-dev`, `improve-codebase-architecture`). Global layer comes from `GLOBAL-AGENTS.md` symlinks; read at session start, kept updated. Monorepos: nested files stack additively (nearest wins) but only for areas that earn one — see the skill's two gates |
| `README.md`, `TODO.md` / `PROGRESS.md` | Orientation docs — read before exploring code, updated in place as part of any change (new service → README, progress → TODO/PROGRESS) |

Cross-skill agreements: skills are the single source of truth for method (orkestration tools and other
skills name-drop them, never copy); `grill-me` separates codebase **facts** (look up) from user
**decisions** (ask in single-topic rounds of mutually independent questions,
confirmation gate before acting); `test-driven-dev` seams are
pre-agreed with the user — headless loops substitute an approved design doc; reviews are
fail-closed with numbered concrete objections (`design-doc` review checklist, critique-loop
verdicts, ralph critics).

TODO: evaluate standalone `CONTEXT.md` files later, once the inline Terminology section
outgrows AGENTS.md — reference format:
[mattpocock/skills CONTEXT.md](https://github.com/mattpocock/skills/blob/main/CONTEXT.md).

Credits: `babysit-pr` and `critique-loop` are adapted from
[gzaripov/agent-skills](https://github.com/gzaripov/agent-skills) (MIT); `handoff`,
`improve-codebase-architecture`, and `test-driven-dev` (upstream `tdd`) from
[mattpocock/skills](https://github.com/mattpocock/skills) (MIT).
