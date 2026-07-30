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

Tool configuration is never manually-edited: Claude Code marketplaces/plugins go through the
`claude plugin` CLI, and the Dart/Flutter MCP server through `claude mcp add` /
`codex mcp add` — so a fresh machine gets the full setup in one run.

Read-only commands (`ls`, `grep`, `find`, `git log/diff/…`, `gh pr view/…`) are pre-approved in
every repo: `permissions/claude-allow.json` is merged into user-level
`~/.claude/settings.json` (rules merge additively across scopes; project denies still win), and
`permissions/codex.rules` is an execpolicy file symlinked into `~/.codex/rules/` (additive —
codex's own "always allow" amendments stay in `default.rules`).
Deliberately excluded: test runners (project-level decision), `gh api` (can POST).

Everything is symlinked, so the harnesses track this repo live (edit a SKILL.md, it's live everywhere).

### Removed: RTK (Rust Token Killer)

RTK used to be wired in here — a `PreToolUse` hook rewriting Bash commands (`git status` →
`rtk git status`), a global-rules section telling other harnesses to prefix manually, and
`rtk`-variant permission rules. It's gone as of 2026-07-30, per
[Does "rtk" skill really cut agent tokens by 60–90%? We tested it](https://blog.jetbrains.com/ai/2026/07/rtk-claude-code-token-savings/):
the measured result was a **median +7.6% cost increase** at low reasoning effort (p=0.004) and
flat zero at high effort — not the advertised 60–90% savings. RTK compresses only ~20% of shell
output, while Claude Code already truncates long results and cached input dominates the bill.
Its own "tokens saved" counter measures compression ratio, not billing impact.

Don't re-add it without paired-invoice evidence.

### Unwired: ralph-orchestrator

Also 2026-07-30: ralph is no longer wired into any harness — the `ralph` MCP server, the
`ralph-orchestrator@ralph-orchestrator` plugin and its marketplace, and the
`~/.ralph/config.yml` + `~/.config/ralph/presets` symlinks are all removed. The MCP server
never connected (`ralph mcp` is a real subcommand on 2.10.1, but it failed health checks).

Unlike RTK this is a *pause, not a deletion*: `ralph/` stays in the repo with its config, five
hat-collection presets and project template, and the `install.sh` blocks are commented out
rather than removed. To re-enable, uncomment every block marked `ralph (disabled)` (including
the `ralph_supported()` helper) and re-run `./install.sh`. The `ralph` binary itself is
untouched.

## Layout

```
skills/            canonical skill tree — agentskills.io spec, one folder per skill
GLOBAL-AGENTS.md   single source of truth for global rules (orientation docs, git conventions)
ralph/             ralph-orchestrator config, presets (design-doc, implement[-plus], tdd[-plus]), project template — UNWIRED, kept for later
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
| `ponytail` | Lazy senior dev mode — YAGNI ladder, stdlib/native before custom code, shortest diff; `review` (diff) and `audit` (repo) sub-flows (user-triggered) |
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
[mattpocock/skills](https://github.com/mattpocock/skills) (MIT); `ponytail` from
[DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) v4.8.4 (MIT) — the
`ponytail`, `ponytail-review` and `ponytail-audit` skills collapsed into one user-triggered
skill with a single intensity (upstream's `lite`/`ultra` levels, hooks, MCP server and
`gain`/`debt`/`help` skills are deliberately not ported).
