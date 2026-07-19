---
name: critique-loop
description: Use when the user wants cross-model adversarial review — "critique-loop on <task>", "pair with Codex/Cursor on this", "review my changes/branch/diff with Codex", "have another model review this plan", or an iterative review-fix cycle before shipping. Two entry points - full flow (plan → review → implement → review) and review-only (existing diff).
license: MIT
compatibility: Requires either Codex CLI (`codex`, authenticated) or Cursor CLI (`cursor-agent`, Jan 2026+ release with `--mode plan` support, authenticated). Run from inside a git repository, on a feature branch (not `main`/`master`).
allowed-tools: Bash(codex exec *) Bash(codex exec resume *) Bash(cursor-agent *) Bash(git add *) Bash(git commit *) Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git rev-parse *) Bash(git branch --show-current) Bash(mkdir -p .critique-loop) Bash(cat .critique-loop/*) Bash(grep -oE *) Bash(tee .critique-loop/*)
argument-hint: "Task to drive, or empty to review the current diff"
---

Cross-model critique loop: Claude drives, a second model (the **navigator**) adversarially reviews in one persistent session. Two flows:

- **Full flow** — plan → navigator reviews plan → (fix or ask user) → **user approves** → implement → navigator reviews diff → done.
- **Review-only flow** — navigator reviews an existing diff, Claude fixes what's actionable (see end).

## Configuration

- **Navigator CLI:** `codex` (options: `codex` | `cursor`). **Model:** not pinned — the CLI's configured default; keep that on the latest model with high reasoning effort, never downgrade to coax an easier verdict.
- **Artifacts:** `.critique-loop/` — local working state, gitignored on first run, never part of the PR. Session id: `.critique-loop/<slug>.session-id`.
- **Slug:** current branch name (slash-sanitized), or kebab-case from the task if on `main`/`master`.
- **Plan file:** `.critique-loop/<slug>-plan.md` — always ephemeral (gitignored, never committed). If the plan deserves to be a committed deliverable, that's a design doc: use the `design-doc` skill (`docs/design/yyyy-MM-dd-<slug>.md`) and run critique-loop on it.

### Navigator adapter

Two abstract ops — **START-SESSION** (first call) and **RESUME-SESSION** (every follow-up) — taking `<PROMPT>`, `<OUTPUT_FILE>`, `<SLUG>`.

**codex** (default; sandbox `read-only` — navigator never writes):

```bash
# START-SESSION — pipefail so a codex failure isn't masked by tee
set -o pipefail
codex exec --sandbox read-only -o <OUTPUT_FILE> "<PROMPT>" \
  < /dev/null 2>&1 | tee .critique-loop/<SLUG>.nav.log
grep -oE 'session id: [0-9a-f-]{36}' .critique-loop/<SLUG>.nav.log \
  | head -1 | awk '{print $3}' > .critique-loop/<SLUG>.session-id

# RESUME-SESSION — resume takes -c overrides, NOT --sandbox (errors out)
SID=$(cat .critique-loop/<SLUG>.session-id)
codex exec resume "$SID" -c sandbox_mode='"read-only"' -o <OUTPUT_FILE> "<PROMPT>" < /dev/null
```

`< /dev/null` is mandatory: codex also reads stdin and blocks forever ("Reading additional input from stdin...") when the parent leaves it open.

**cursor** (`--mode plan` read-only, `--trust` headless):

```bash
# START-SESSION — pre-create chat; RESUME-SESSION is the identical command
cursor-agent create-chat > .critique-loop/<SLUG>.session-id
SID=$(cat .critique-loop/<SLUG>.session-id)
cursor-agent -p --trust --mode plan --output-format text --resume "$SID" "<PROMPT>" > <OUTPUT_FILE>
```

After START-SESSION: non-zero exit → stop and surface the error. Empty session-id file → surface raw output and stop.

## Prerequisites

- Navigator authenticated. Smoke test: `codex exec --sandbox read-only "reply OK" < /dev/null` / `cursor-agent -p --trust --mode plan "reply with exactly: OK"`.
- Git repo, not on `main`/`master` (else ask the user for a branch + slug).

## Cross-round issue tracking

Applies to every CHANGES_REQUESTED round. Keep an internal log: every ask ever raised (file + location + description), action taken (fixed / pushed back / surfaced), raised→resolved→re-raised history. Rules:

1. **Print all of the round's asks before acting on any** — full user visibility.
2. **Recurring ask you already fixed** — navigator likely missed the fix; point at the exact commit/lines in the driver response, don't redo it.
3. **Oscillating ask** (raise → drop → re-raise, or contradictory fixes across rounds) — don't ping-pong the code. Document in place with the file's native comment syntax and ignore it in future rounds:

   ```
   # NOTE(critique-loop): navigator oscillated (round N: X, round M: Y). Keeping current implementation.
   ```
4. **Unresolved disagreement not worth a user interruption** — `TODO(critique-loop): <why skipped>` comment at the site (commentless formats like JSON: record in the driver response instead); say so in the driver response. Product/architecture disagreements still go to the user (Step 6).
5. **Stuck detection** — before each round: same asks 3+ rounds? all remaining asks oscillating/skipped? ask count not shrinking? Any yes → exit early and report why.

## Phase 1: Draft the plan

**Step 1 — setup.** Read the task; explore the repo enough for a concrete plan (real paths, existing patterns). Don't implement.

```bash
SLUG=$(git branch --show-current | tr '/' '-')   # feature/foo -> feature-foo
mkdir -p .critique-loop
if ! grep -qxE '\.critique-loop/?' .gitignore 2>/dev/null; then
  echo ".critique-loop/" >> .gitignore
  git add .gitignore   # needed when .gitignore is new (untracked)
  git commit -m "chore: gitignore .critique-loop artifacts" -- .gitignore  # pathspec: only this file
fi
```

**Step 2 — write the plan** to the configured plan file. Sections: **Task** (one paragraph), **Context** (repo constraints, prior art), **Approach** (numbered, "edit function X in file Y to do Z" level), **Files to modify** (+ one-line reason), **Verification**, **Open questions** (don't invent answers).


## Phase 2: Navigator reviews the plan

**Step 4 — START-SESSION**, `<OUTPUT_FILE>` = `.critique-loop/<slug>-plan-review.md`, `<PROMPT>`:

```
You are the navigator in an XP pair-programming session. The driver (Claude Code) has written a plan.

Read the plan at `${PLAN_FILE_PATH}` and any referenced code. Be adversarial — probe for: missing edge cases and error paths; risky assumptions or unstated dependencies; scope not matching the task; simpler alternatives; verification steps that wouldn't catch regressions.

Output: (1) one-sentence overall take; (2) numbered asks — what is wrong, why it matters, how you'd address it, with file:line refs; (3) end with EXACTLY one line, nothing after:
- `VERDICT: APPROVE` — driver may implement.
- `VERDICT: CHANGES_REQUESTED` — asks must be resolved.
- `VERDICT: BLOCK` — fundamental problem needing human input.

Do not write code. Do not modify files. Review only.
```

Verify the session-id file is non-empty.

**Step 5 — read the verdict** (last line of the review file): APPROVE → Step 5b; CHANGES_REQUESTED → Step 6; BLOCK → Step 7. Missing `VERDICT:` line → resume once with "restate your review ending with a single `VERDICT:` line"; if it fails again, stop.

**Step 5b — user-approval gate.** Navigator approval is not enough. Present: slug + branch, one-sentence summary, decisions made during review, **unresolved open questions (never silently proceed with them)**, plan file path, and "Ready to implement? Say 'go' or tell me what to change." Then: approval → Phase 3; minor edit (wording/trim) → revise, re-present, no navigator round; substantive change → revise and back to Step 6b; pivot/stop → stop. Unsure minor-vs-substantive → another navigator round.

**Step 6 — resolve CHANGES_REQUESTED.** Apply Cross-round tracking, then classify each ask:

- **Claude resolves directly:** missing edge case/error path; unclear or out-of-order steps; wrong paths/names/stale refs; missing test/verification; simpler alternative preserving the goal; in-task scope trim.
- **Surface to the user:** product decisions; architecture tradeoffs with no obvious answer; business/domain judgements; anything depending on info outside the repo.

If any user-surface asks exist, pause: summarize each (ask, why it matters, navigator's options), wait, then fix everything in one pass. Write `.critique-loop/<slug>-driver-response.md` — how each ask was addressed (one line), user answers verbatim, any pushback. Round N = highest `-plan-review-<N>.md`.

**Step 6b — re-review.** RESUME-SESSION, `<OUTPUT_FILE>` = `.critique-loop/<slug>-plan-review-<N+1>.md`:

```
I revised the plan based on your review. Updated plan: `${PLAN_FILE_PATH}`. My response to each ask: `.critique-loop/<slug>-driver-response.md`.

Re-review. Note which prior asks are resolved and which remain open. Same output format, end with `VERDICT:`.
```

Back to Step 5.

**Step 7 — BLOCK.** Don't loop. Summarize the blocker (2–4 sentences + navigator's suggested direction), stop until the user responds.

## Phase 3: Implement the approved plan

**Step 8:** `git rev-parse HEAD > .critique-loop/<slug>.plan-sha` — everything after this is "the implementation".

**Step 9:** Implement exactly the approved plan; no scope expansion (note gaps for review, or ask if it's a scope question). Conventional commits, one logical change each. Run lint + tests before the last commit; non-trivial failure → stop and ask.

**Step 10:** Write `.critique-loop/<slug>-diff-summary.md`: commit range (`<plan-sha>..HEAD`), what changed (2–5 bullets), files touched, tests, anything deferred. Not committed.

## Phase 4: Navigator reviews the diff

**Step 11 — RESUME-SESSION**, `<OUTPUT_FILE>` = `.critique-loop/<slug>-code-review.md` (with `PLAN_SHA=$(cat .critique-loop/<slug>.plan-sha)`):

```
The plan you approved is implemented. Review the diff.

- Plan: `${PLAN_FILE_PATH}`  - Diff summary: `.critique-loop/<slug>-diff-summary.md`  - Commit range: `${PLAN_SHA}..HEAD`

Run `git diff ${PLAN_SHA}..HEAD` and read the changed files. Verify: (a) implementation matches the plan; (b) no scope creep; (c) no bugs, regressions, or missed edge cases; (d) adequate test coverage.

Output format: numbered asks with file:line refs, ending with `VERDICT: APPROVE | CHANGES_REQUESTED | BLOCK`.

Do not write code. Do not modify files. Review only.
```

**Step 12 — verdict:** APPROVE → Step 14; CHANGES_REQUESTED → Step 13; BLOCK → as Step 7. (Missing-VERDICT handling as Step 5.)

**Step 13 — resolve.** Cross-round tracking first, then Step 6 classification: code-level asks → fix directly (conventional commits); scope/product/architecture → surface and wait. Append to the same driver-response file. Run project checks (lint, typecheck, tests) — fix failures before resuming. RESUME-SESSION, `<OUTPUT_FILE>` = `.critique-loop/<slug>-code-review-<N+1>.md`:

```
I addressed your code-review asks. New commits are on top of `${PLAN_SHA}..HEAD`. Response notes appended to `.critique-loop/<slug>-driver-response.md`.

Re-review the full diff (`git diff ${PLAN_SHA}..HEAD`). Note which prior asks are resolved and which remain open. Same output format, end with `VERDICT:`.
```

Back to Step 12.

**Step 14 — report:**

```
## Critique-loop summary
- Slug: <slug>  Plan rounds: X  Code rounds: Y
- User questions surfaced: Z (resolved W)
- Asks fixed / pushed back / oscillating: A / B / C
- Plan SHA: <plan-sha>  Final HEAD: <head-sha>
- Artifacts: .critique-loop/<slug>-*.md
```

PR / merge / push are out of scope.

## Stopping rules

Bail and ask the user when: stuck detection triggers; round counter hits 5 in either phase without APPROVE; `VERDICT:` missing twice in a row (surface raw output); navigator CLI fails (report exact error — no blind retries, no silent CLI switch); session-id file missing/empty after first call (never resume); user's answer to a surfaced question is itself ambiguous (re-ask); Phase 3 lint/tests fail needing judgement outside the plan.

**Never change the model, effort, sandbox mode, or navigator CLI to coerce a different verdict.**

## Review-only flow

Existing changes, no plan or Claude implementation. Adapter, verdict format, Step 6 classification, Cross-round tracking, and the RESUME loop apply unchanged.

**R1 — setup:** as Step 1 (slug, `.critique-loop/`, gitignore pathspec commit).

**R2 — diff range.** Ask if not obvious. Default: branch vs merge-base with the repo's default branch (don't assume `main`):

```bash
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
DEFAULT=${DEFAULT:-$(git branch -l main master --format='%(refname:short)' | head -1)}
BASE=$(git merge-base HEAD "origin/$DEFAULT" 2>/dev/null || git merge-base HEAD "$DEFAULT")
echo "${BASE}..HEAD" > .critique-loop/<slug>.review-range
```

Other shapes: `HEAD` (uncommitted work), `<sha1>..<sha2>`, `<base>...HEAD`.

**Range integrity across rounds** — the range must keep covering the work as fix commits land: `BASE` stays fixed and re-reviews diff `${BASE}..HEAD`; never re-record a range that excludes fixes (`<sha1>..<sha2>` becomes `<sha1>..HEAD` after the first fix round — if unrelated commits might land mid-loop, name the fix SHAs to the navigator instead). For the `HEAD` shape: untracked files are invisible to `git diff HEAD` — tell the navigator to also check `git status --porcelain` and read new files; once fixes are committed, switch to `<original-HEAD>..HEAD` plus the dirty tree, or the re-review sees an empty diff and false-approves.

**R3 — START-SESSION**, `<OUTPUT_FILE>` = `.critique-loop/<slug>-code-review.md`:

```
You are the navigator in a cross-model code review. The driver has changes to review adversarially before shipping.

Run `git diff ${REVIEW_RANGE}` and read the changed files. Probe for: bugs, regressions, missed edge cases; missing/inadequate tests; security, performance, correctness issues; scope creep or leftover debug code; simpler alternatives.

Output format: numbered asks with file:line refs, ending with `VERDICT: APPROVE | CHANGES_REQUESTED | BLOCK`.

Do not write code. Do not modify files. Review only.
```

**R4 — verdict:** APPROVE → summarize rounds + surfaced decisions; done (push/PR is the user's call). CHANGES_REQUESTED → track/classify/fix/surface, append driver response, run checks, RESUME-SESSION (`-code-review-<N+1>.md`):

```
I addressed your code-review asks. New commits are on top of the range. Response notes: `.critique-loop/<slug>-driver-response.md`.

Re-review the full diff (`git diff ${REVIEW_RANGE}` — note HEAD has moved since your last review). Note which prior asks are resolved and which remain open. Same output format, end with `VERDICT:`.
```

Loop back to R4. BLOCK → summarize, stop. All stopping rules apply; no user-approval gate — navigator APPROVE terminates the skill.
