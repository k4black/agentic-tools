---
name: critique-loop
description: Use when the user wants cross-model adversarial review — "critique-loop on <task>", "pair with Codex/Cursor on this", "review my changes/branch/diff with Codex", "have another model review this plan", or an iterative review-fix cycle before shipping. Two entry points - full flow (plan → review → implement → review) and review-only (existing diff).
license: MIT
compatibility: Requires either Codex CLI (`codex`, authenticated) or Cursor CLI (`cursor-agent`, Jan 2026+ release with `--mode plan` support, authenticated). Run from inside a git repository, on a feature branch (not `main`/`master`).
allowed-tools: Bash(codex exec *) Bash(codex exec resume *) Bash(cursor-agent *) Bash(git add *) Bash(git commit *) Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git rev-parse *) Bash(git branch --show-current) Bash(mkdir -p .critique-loop) Bash(cat .critique-loop/*) Bash(grep -oE *) Bash(tee .critique-loop/*)
argument-hint: "Task to drive, or empty to review the current diff"
---

Cross-model critique loop: Claude drives, a second model (the **navigator**) adversarially reviews. The same navigator session persists across rounds so it retains context. Two flows:

- **Full flow** — plan → navigator reviews plan → (fix or ask user) → **user approves the plan** → implement → navigator reviews the diff → (fix or ask user) → done. All phases share one navigator session.
- **Review-only flow** — no plan, no implementation; the navigator adversarially reviews an existing diff and Claude fixes what's actionable. See **Review-only flow** at the end.

## Configuration

Defaults live here — edit to override. Everything below reads from these.

- **Navigator CLI:** `codex` (options: `codex` | `cursor`)
- **Navigator model:** *not pinned.* The navigator runs on the CLI's configured default (`~/.codex/config.toml` / Cursor settings). Keep that default on the **latest available model with high reasoning effort** — do not downgrade it to coax an easier verdict.
- **Artifact directory:** `.critique-loop/` — **local working state only, gitignored**. Not committed; not part of the PR. Added to `.gitignore` on first run (Step 1).
- **Slug:** current git branch name, or a kebab-case identifier derived from the task if on `main`/`master`.
- **Plan file path:** `.critique-loop/<slug>-plan.md` (default — **ephemeral mode**, gitignored, never committed).
  Override to a repo path like `docs/plans/<slug>.md` for **repo mode** — the plan becomes a committed design doc (`docs: plan for <slug>` / `docs: revise plan for <slug> (round N)`). Pick repo mode when the plan should be reviewable in the PR.

Session-id file: `.critique-loop/<slug>.session-id` (created on first call, reused on every resume).

### Navigator adapter

The skill body refers to two abstract operations: **START-SESSION** (first call, creates the session) and **RESUME-SESSION** (every follow-up). All navigators accept the same inputs: `<PROMPT>`, `<OUTPUT_FILE>`, `<SLUG>`.

#### If Navigator CLI = `codex` (default)

- **Sandbox:** `read-only` (navigator reviews; it does not write code)
- **Model / effort:** CLI defaults (see Configuration)

**START-SESSION** (tee the log, grep the session ID after the call; `pipefail` so a codex failure isn't masked by `tee`):

```bash
set -o pipefail
codex exec \
  --sandbox read-only \
  -o <OUTPUT_FILE> \
  "<PROMPT>" \
  < /dev/null \
  2>&1 | tee .critique-loop/<SLUG>.nav.log

grep -oE 'session id: [0-9a-f-]{36}' .critique-loop/<SLUG>.nav.log \
  | head -1 | awk '{print $3}' > .critique-loop/<SLUG>.session-id
```

**RESUME-SESSION**:

```bash
SID=$(cat .critique-loop/<SLUG>.session-id)
codex exec resume "$SID" \
  -c sandbox_mode='"read-only"' \
  -o <OUTPUT_FILE> \
  "<PROMPT>" \
  < /dev/null
```

> **Why `< /dev/null`?** `codex exec` reads from stdin in addition to the positional prompt. When the parent agent leaves stdin open, codex blocks indefinitely on `Reading additional input from stdin...` — symptom: a codex process alive for minutes with no log output. Closing stdin is mandatory for non-interactive use.

> **Why `-c sandbox_mode` on resume but `--sandbox` on the first call?** `codex exec resume` does not accept `--sandbox`; it only takes `-c` config overrides (value parsed as TOML, hence the inner quotes). Passing `--sandbox` to `resume` errors out with a help dump.

#### If Navigator CLI = `cursor`

- **Mode:** `plan` (read-only), `--trust` for headless, output format `text`
- **Model:** CLI default (omit `--model` unless the user pins one)

**START-SESSION** (pre-create chat, then run with `--resume`):

```bash
cursor-agent create-chat > .critique-loop/<SLUG>.session-id
SID=$(cat .critique-loop/<SLUG>.session-id)
cursor-agent -p --trust \
  --mode plan \
  --output-format text \
  --resume "$SID" \
  "<PROMPT>" \
  > <OUTPUT_FILE>
```

**RESUME-SESSION**: identical invocation (the chat already exists).

After either START-SESSION: if the command exited non-zero, stop and surface the error (do not proceed to session-id extraction). Then verify `.critique-loop/<SLUG>.session-id` is non-empty before continuing. If empty, surface the raw output to the user and stop.

## Prerequisites

- Navigator CLI installed and authenticated. Smoke tests:
  - **Codex:** `codex exec --sandbox read-only "reply OK" < /dev/null` prints `OK`.
  - **Cursor:** `cursor-agent -p --trust --mode plan "reply with exactly: OK"` prints `OK`.
- Current directory is a git repo; current branch is not `main`/`master` (if it is, ask the user for a branch name and slug first).

## Cross-round issue tracking

Applies to every CHANGES_REQUESTED round in any flow. Maintain an internal log across rounds:

- **All asks ever raised** — indexed by file + location + description.
- **Actions taken** — fixed, pushed back, surfaced to user.
- **Ask history** — track raised → resolved → re-raised patterns.

Rules:

1. **Print all asks from the current round before acting on any of them** — file, location, description — so the user has full visibility.
2. **Recurring ask you already fixed** — the navigator may have missed the fix. Point it at the exact commit/lines in your driver response; if you are confident the fix is correct, do not redo it.
3. **Oscillating ask** (navigator flip-flops: raise → drop → re-raise, or suggests contradictory fixes across rounds) — do NOT keep changing the code back and forth. Document it in place (using the file's native comment syntax — `#`, `//`, `<!-- -->`, …) and move on:

   ```
   # NOTE(critique-loop): navigator oscillated on this.
   # Round N: suggested X. Round M: suggested Y.
   # Keeping current implementation.
   ```

   Mark it resolved in your log and ignore it in all future rounds.
4. **Disagreement you can't resolve** — if you disagree with an ask and it isn't worth a user interruption, leave a `TODO(critique-loop): <why skipped>` comment at the site (file's native comment syntax; for commentless formats like JSON, record it in the driver-response notes instead) and say so in the driver response. Product/architecture disagreements still go to the user (Step 6 classification).
5. **Stuck detection** — before each new round, check: same asks repeating 3+ rounds? all remaining asks oscillating/skipped? ask count not shrinking despite fixes? If any is true, exit the loop early and report why instead of burning rounds.

## Phase 1: Draft the plan

### Step 1: Scope the task, pick the slug, gitignore artifacts

Read the task from the user's request. Explore the repo enough to write a concrete plan (real file paths, existing patterns). Don't implement yet.

```bash
SLUG=$(git branch --show-current | tr '/' '-')   # filesystem-safe: feature/foo -> feature-foo
# If on main/master, ask user for a branch + slug
mkdir -p .critique-loop

if ! grep -qxE '\.critique-loop/?' .gitignore 2>/dev/null; then
  echo ".critique-loop/" >> .gitignore
  git add .gitignore   # required when .gitignore is newly created (untracked)
  # pathspec form: commits ONLY .gitignore, never sweeps in other staged work
  git commit -m "chore: gitignore .critique-loop artifacts" -- .gitignore
fi
```

The `.gitignore` commit is the only critique-loop commit that ever lands in the PR **from ephemeral mode**. In repo mode the plan file is also committed (Step 3).

### Step 2: Write the plan

Write to the configured **Plan file path**. Sections:

- **Task** — one paragraph in your own words.
- **Context** — what the repo constrains (existing patterns, relevant files, prior art).
- **Approach** — numbered steps at the level of "edit function X in file Y to do Z".
- **Files to modify** — paths with one-line reason each.
- **Verification** — how you'll know it worked.
- **Open questions** — things the user or navigator should weigh in on; don't invent answers.

### Step 3: Commit the plan (repo mode only)

If the plan file lives outside `.critique-loop/`, commit it (`docs: plan for <slug>`). Skip in ephemeral mode.

## Phase 2: Navigator reviews the plan

### Step 4: First call (creates the session)

Run **START-SESSION** with `<OUTPUT_FILE>` = `.critique-loop/<slug>-plan-review.md` and `<PROMPT>`:

```
You are the navigator in an XP pair-programming session. The driver (Claude Code) has written a plan for a task.

Read the plan at `${PLAN_FILE_PATH}` and any referenced code in the repo. Be adversarial — probe for:

- missing edge cases and error paths
- risky assumptions or unstated dependencies
- scope that does not match the stated task (too broad, too narrow, misaligned)
- simpler alternatives the driver may have missed
- verification steps that would not actually catch regressions

Output format:

1. One-sentence summary of your overall take.
2. Numbered list of specific asks. For each: **what** is wrong, **why** it matters, and (if you can) **how** you would address it. Reference file paths and line numbers when relevant.
3. End with EXACTLY one of these lines on its own line, nothing after:
   - `VERDICT: APPROVE` — plan is solid; driver may implement.
   - `VERDICT: CHANGES_REQUESTED` — the numbered asks above must be resolved.
   - `VERDICT: BLOCK` — the plan has a fundamental problem needing human input.

Do not write code. Do not modify files. Review only.
```

Substitute `<slug>` and `${PLAN_FILE_PATH}` literally before passing. Verify the session-id file is non-empty.

### Step 5: Read the verdict

Read `.critique-loop/<slug>-plan-review.md`. Last line is the verdict.

- **`VERDICT: APPROVE`** → Step 5b (user-approval gate).
- **`VERDICT: CHANGES_REQUESTED`** → Step 6.
- **`VERDICT: BLOCK`** → Step 7.
- **No `VERDICT:` line** → resume with "please restate your review ending with a single `VERDICT:` line". If it fails again, stop.

### Step 5b: Wait for user approval

The navigator approved, but the user has final say. Present:

- **Slug** and current branch.
- **One-sentence summary** of what will be implemented.
- **Decisions made during review** — user answers from Step 6 that shaped the plan (skip if none).
- **Open questions still unresolved** — from the plan's Open questions section. Do NOT silently proceed with unresolved open questions.
- **Plan file** path.
- **Explicit prompt:** "Ready to implement? Say 'go' to proceed, or tell me what to change."

Wait for the user's response.

- **"go" / approves** → Phase 3.
- **Minor changes** (wording, small scope trim) → revise the plan, show the summary again; no navigator round.
- **Substantive changes** (new requirement, different approach) → revise and go back to Step 6b for another navigator round.
- **Pivot or stop** → stop; the plan file stays on disk.

If unsure whether a change is minor or substantive, prefer another navigator round.

### Step 6: Resolve CHANGES_REQUESTED

Apply **Cross-round issue tracking** (print asks first, check for recurrence/oscillation). Then classify each ask:

**Claude resolves directly (no user input):** missing edge case or error path; unclear/out-of-order steps; wrong paths/names/stale references; missing test or verification step; simpler alternative preserving the user's goal; scope trim inside the task.

**Surface to the user (Claude lacks authority):** product decisions; architecture tradeoffs with no obvious right answer; business rules or domain judgements; anything depending on information outside the repo.

**Apply:**

1. If any user-surface asks exist, pause. Summarize each in 2–3 bullets (the ask, why it matters, the navigator's options if any). Wait for the answer, then fix everything in one revision pass.
2. Otherwise fix directly in the plan file.

Write `.critique-loop/<slug>-driver-response.md`: which asks were addressed and how (one line each); any user answers verbatim; any pushback and why. Round number `N` is tracked by the highest `-plan-review-<N>.md` in `.critique-loop/`.

**Repo mode only:** commit the plan revision (`docs: revise plan for <slug> (round N)`).

### Step 6b: Re-review (resume the same session)

Run **RESUME-SESSION** with `<OUTPUT_FILE>` = `.critique-loop/<slug>-plan-review-<N+1>.md` and `<PROMPT>`:

```
I revised the plan based on your review. Updated plan: `${PLAN_FILE_PATH}`. My response to each ask: `.critique-loop/<slug>-driver-response.md`.

Re-review. Note which prior asks are resolved and which remain open. Same output format, end with `VERDICT:`.
```

Go back to Step 5.

### Step 7: Handle BLOCK

Do not loop. Summarize the blocker for the user in 2–4 sentences, include the navigator's suggested direction, stop until the user responds.

## Phase 3: Implement the approved plan

### Step 8: Record the plan SHA

```bash
git rev-parse HEAD > .critique-loop/<slug>.plan-sha
```

Everything committed after this point is "the implementation" that Phase 4 diffs against.

### Step 9: Implement

Implement exactly what the approved plan describes. Do not expand scope — note gaps for the review phase, or stop and ask if it's a scope question. Conventional commits, one logical change per commit. Run the project's lint + tests before the last commit; if a failure isn't trivially fixable, stop and ask.

### Step 10: Write the diff summary

Write `.critique-loop/<slug>-diff-summary.md`: commit range (`<plan-sha>..HEAD`), what changed (2–5 bullets), files touched, tests added/updated, anything deferred. Gitignored — do not commit.

## Phase 4: Navigator reviews the diff

### Step 11: Resume the session for code review

```bash
PLAN_SHA=$(cat .critique-loop/<slug>.plan-sha)
```

Run **RESUME-SESSION** with `<OUTPUT_FILE>` = `.critique-loop/<slug>-code-review.md` and `<PROMPT>`:

```
The plan you approved is implemented. Review the diff.

- Plan: `${PLAN_FILE_PATH}`
- Diff summary: `.critique-loop/<slug>-diff-summary.md`
- Commit range: `${PLAN_SHA}..HEAD`

Run `git diff ${PLAN_SHA}..HEAD` and read the changed files. Verify:

(a) Implementation matches the approved plan.
(b) No scope creep beyond what the plan approved.
(c) No introduced bugs, regressions, or missed edge cases.
(d) Tests cover the changes adequately.

Output format: same as before — numbered asks with file:line references where possible, ending with `VERDICT: APPROVE | CHANGES_REQUESTED | BLOCK`.

Do not write code. Do not modify files. Review only.
```

### Step 12: Read the verdict

- **`VERDICT: APPROVE`** → Step 14.
- **`VERDICT: CHANGES_REQUESTED`** → Step 13.
- **`VERDICT: BLOCK`** → as Step 7: summarize, stop, ask user.

### Step 13: Resolve CHANGES_REQUESTED on code

Apply **Cross-round issue tracking** first (print asks, detect recurrence/oscillation/stuck). Then the Step 6 classification:

- Code-level asks (bugs, missing tests, in-scope refactors, edge cases) → fix directly, conventional commits.
- Scope / product / architecture asks → surface to the user; wait.

Append to `.critique-loop/<slug>-driver-response.md` (same file; append). After fixes, run project checks (lint, typecheck, tests) — if any fail, fix before resuming the navigator.

Run **RESUME-SESSION** with `<OUTPUT_FILE>` = `.critique-loop/<slug>-code-review-<N+1>.md` and `<PROMPT>`:

```
I addressed your code-review asks. New commits are on top of `${PLAN_SHA}..HEAD`. Response notes appended to `.critique-loop/<slug>-driver-response.md`.

Re-review the full diff (`git diff ${PLAN_SHA}..HEAD`). Note which prior asks are resolved and which remain open. Same output format, end with `VERDICT:`.
```

Go back to Step 12.

### Step 14: Approved — report

```
## Critique-loop summary
- Slug: <slug>
- Plan rounds: X
- Code-review rounds: Y
- User questions surfaced: Z (resolved W)
- Asks fixed / pushed back / oscillating: A / B / C
- Plan SHA: <plan-sha>  Final HEAD: <head-sha>
- Artifacts: .critique-loop/<slug>-*.md
```

PR / merge / push are out of scope for this skill.

## Stopping rules

Bail and ask the user when:

- Stuck detection triggers (see Cross-round issue tracking).
- Round counter hits 5 in either phase without an APPROVE.
- Navigator output missing `VERDICT:` twice in a row — surface the raw output.
- The navigator CLI fails (auth, network, crash) — report the exact error; do not retry blindly; do not silently switch navigator CLIs.
- The session-id file is missing or empty after the first call — do not try to resume.
- The user's answer to a surfaced question is itself ambiguous — re-ask before resuming.
- During Phase 3, lint/tests fail in a way requiring judgement outside the plan.

Never change the model, effort, sandbox mode, or navigator CLI to coerce a different verdict.

## Review-only flow

Use when the user already has changes and wants an adversarial review — no plan, no Claude implementation. The navigator adapter, verdict format, Step 6 classification, Cross-round issue tracking, and RESUME-SESSION loop all apply unchanged.

### R1: Setup

Same as Step 1 — pick `<slug>` (slash-sanitized), create `.critique-loop/`, ensure it's gitignored (pathspec-scoped commit).

### R2: Determine the diff range

Ask the user what to review if not obvious. Default: the branch versus its merge base with the repo's default branch (don't assume `main`):

```bash
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
DEFAULT=${DEFAULT:-$(git branch -l main master --format='%(refname:short)' | head -1)}
BASE=$(git merge-base HEAD "origin/$DEFAULT" 2>/dev/null || git merge-base HEAD "$DEFAULT")
REVIEW_RANGE="${BASE}..HEAD"
echo "${REVIEW_RANGE}" > .critique-loop/<slug>.review-range
```

Other shapes: `HEAD` for uncommitted working-tree changes (navigator reads `git diff HEAD`); `<sha1>..<sha2>`; `<base>...HEAD`.

**Range integrity across rounds** — the recorded range must keep covering the work as fix commits land:

- The recorded `BASE` SHA is fixed; re-reviews always diff `${BASE}..HEAD` so later fix commits are included. Never re-record a range that would exclude them (`<sha1>..<sha2>` becomes `<sha1>..HEAD` after the first fix round — if unrelated commits might land on the branch mid-loop, name the fix SHAs to the navigator explicitly instead).
- If reviewing uncommitted changes (`HEAD` shape): untracked files are invisible to `git diff HEAD` — tell the navigator to also check `git status --porcelain` and read new files; and once you commit fixes, switch the range to `<original-HEAD>..HEAD` plus the dirty tree, or the re-review sees an empty diff and false-approves.

### R3: Navigator reviews the diff

Run **START-SESSION** with `<OUTPUT_FILE>` = `.critique-loop/<slug>-code-review.md` and `<PROMPT>`:

```
You are the navigator in a cross-model code review. The driver has changes they want reviewed adversarially before shipping.

Run `git diff ${REVIEW_RANGE}` and read the changed files. Be adversarial — probe for:

- bugs, regressions, missed edge cases
- missing or inadequate tests
- security, performance, or correctness issues
- scope creep or leftover debug code
- simpler alternatives the driver missed

Output format: numbered asks with file:line refs, ending with `VERDICT: APPROVE | CHANGES_REQUESTED | BLOCK`.

Do not write code. Do not modify files. Review only.
```

### R4: Handle the verdict

- **`APPROVE`** → summarize rounds and surfaced decisions; done. Push / PR is the user's call.
- **`CHANGES_REQUESTED`** → Cross-round issue tracking + Step 6 classification; fix code-level asks (conventional commits), surface product asks, append driver response, run project checks, then **RESUME-SESSION** with `<OUTPUT_FILE>` = `.critique-loop/<slug>-code-review-<N+1>.md`:

  ```
  I addressed your code-review asks. New commits are on top of the range. Response notes: `.critique-loop/<slug>-driver-response.md`.

  Re-review the full diff (`git diff ${REVIEW_RANGE}` — note HEAD has moved since your last review). Note which prior asks are resolved and which remain open. Same output format, end with `VERDICT:`.
  ```

  Loop back to R4 with the new review file.
- **`BLOCK`** → summarize for the user, stop.

All stopping rules apply. No user-approval gate — when the navigator approves, the skill terminates.
