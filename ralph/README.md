# ralph — global ralph-orchestrator setup

Reusable [ralph-orchestrator](https://github.com/mikeyobrien/ralph-orchestrator) assets,
wired globally by `../install.sh` (guarded by `command -v ralph`):

| File | Linked to | Purpose |
|---|---|---|
| `config.yml` | `~/.ralph/config.yml` | Global defaults (backend claude, memories, repo-local skill injection from `skills/`, `.claude/skills/`, `.agents/skills/` of the project ralph runs in) — deep-merged under every project's `ralph.yml` |
| `presets/` | `~/.config/ralph/presets` | Custom hat collections: `ralph run -H ~/.config/ralph/presets/<name>.yml` |
| `templates/ralph.yml` | — (copy manually) | Per-project overlay starter: backpressure gates, required_events, project guardrails |

The `ralph-orchestrator` Claude Code plugin (skills `ralph-hats`, `ralph-loop`, `ralph-docs`)
is installed by install.sh via the claude CLI.

## Workflows

Five custom presets. Makers run on claude; reviews run on **codex** by default.
A second independent reviewer on **opencode with GLM** (`openrouter/z-ai/glm-5.2`)
is always part of `design-doc`, and added to implement/tdd by their `-plus`
variants — two model families, chained so each gate must pass. Every hat is
fail-closed: makers default to `*.blocked` dead-ends (validator warns about
them by design), critics default to rejection, so a hat that dies before
emitting stops the loop instead of advancing it. Events carry a JSON envelope
(doc/task/slice identity + files) that every hat must echo. The GLM critics
run opencode with `--auto` (auto-approve permissions) — needed because ralph
spills large prompts to a temp file opencode must read; they are read-only by
instruction, but sandbox the loop for real autonomy.

| Preset | Hats | Produces |
|---|---|---|
| `design-doc` | architect + codex critic + GLM critic | Reviewed `docs/design/yyyy-MM-dd-<slug>.md` (design-doc skill; no code, no commits) |
| `implement` | planner + builder + codex critic + simplifier | Task-per-iteration implementation, tests mandatory; one bounded simplification pass before completion |
| `implement-plus` | … + GLM critic | Same, two review gates |
| `tdd` | planner + builder + codex critic | Red→green vertical slices per the tdd skill |
| `tdd-plus` | … + GLM critic | Same, two review gates |

```bash
P=~/.config/ralph/presets

# 1. Plan: reviewed design doc (no code, no commits — you commit after reading)
ralph run -H $P/design-doc.yml -p "Design a rate limiter for the public API"

# 2. Build from it (pick discipline and review depth)
ralph run -H $P/tdd.yml            -p "Implement docs/design/2026-07-19-rate-limiter.md"
ralph run -H $P/implement-plus.yml -p "Implement docs/design/2026-07-19-rate-limiter.md"

# 3. Everything else: use the builtins (don't rebuild them)
ralph run -H builtin:review -p "Review PR #123"
ralph run -H builtin:debug -p "..."
ralph run -H builtin:research -p "..."
```

Quirks of ralph 2.10.1, found empirically:

- **Bare `-H <name>` only resolves TOML-directory presets** (`<name>/` with
  `autoloops.toml` + `topology.toml`); YAML collections show up in
  `ralph hats list-presets` but must be passed by path — hence the full paths above.
- **A `-H` file only contributes hats + events + `starting_event`/
  `completion_promise`/`cancellation_promise`.** Its `core:` keys are ignored,
  and `max_iterations` / `max_runtime_seconds` / `required_events` come from
  config — set those in the project `ralph.yml`. Without `required_events` the
  loop is fail-open (a stray completion-promise string ends it), so the template
  ships a must-replace placeholder.

## Per-project kickstart

1. `cp ~/Projects/personal/agentic-tools/ralph/templates/ralph.yml ./ralph.yml`
   (or `ralph init --backend claude` for the vanilla starter), fill the
   `[test command]` / `[lint command]` gate placeholders and REPLACE the
   `required_events` placeholder with the line for the preset you run.
2. Add `.ralph/` to the project `.gitignore`.
3. Run one of the workflows above.

## Extending builtin collections

Hats do **not** merge: with `-H`, the collection wholly owns hats/events
("hats source takes precedence"), so builtin hat instructions can't be edited or
extended. The supported steering knobs, both per-project:

- `core.guardrails` in the project `ralph.yml` — injected into every iteration
  alongside any `-H` collection;
- `CODEASSIST.md` in the repo root — read by `builtin:code-assist`'s Builder.

If a builtin needs deeper changes than that, copy it into `presets/` here and fork
deliberately (source: `ralph` repo `presets/*.yml`).

## Conventions baked into the custom presets

- Fail-closed everywhere: critics `default_publishes` a rejection, makers a
  `*.blocked` dead-end — silent failure stops the loop, never advances it.
- Independent review chain: codex first, GLM (different model family) second
  (always in design-doc, via `-plus` for implement/tdd); the second critic is
  told not to rubber-stamp the first.
- Payload envelopes: every event carries the JSON identity of the work item
  (doc path / task / slice + files); hats echo what they receive and add fields.
- Safe commits: planners stage exactly the reviewed envelope's file list, never
  `.ralph/`, and block instead of sweeping unrelated dirty files.
- Subagents for context management: builders fan out parallel read-only research
  subagents (and may delegate separable implementation pieces, verifying
  serially); critics review from multiple perspectives in parallel where the
  harness supports it.
- Simplification stage (implement/implement-plus): when all tasks are done, a
  Simplifier hat gets one bounded pass — parallel subagents hunt architecture /
  YAGNI / code simplifications; material findings become reviewed tasks, and
  only then does the loop complete. (tdd stays without it by design — its skill
  keeps refactoring out of the loop.)
- Skills are name-dropped, never copied — the `design-doc` method (research rules,
  document template), `tdd` semantics (seams, vertical slices, no refactor phase)
  and `domain-modeling`'s CONTEXT.md vocabulary live in the skills under
  `../skills/`, the single source of truth. Hats add only loop mechanics
  (triggers, payloads, emits, verdict gates).
- Critics emit via `"$RALPH_BIN" emit` and stop immediately after emitting
  (works the same on codex/opencode backends, which also see our skills through
  `~/.codex/skills` / `~/.claude/skills`).
- Code commits (implement/tdd planners) follow GLOBAL-AGENTS.md (conventional,
  ≤72 chars, no AI attribution); the design-doc flow never commits — the human
  reviews and commits the doc.
