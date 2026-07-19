---
name: babysit-pr
description: Use when a pull request needs to be driven to merge-ready — failing CI checks, unresolved bot review comments (CodeRabbit, Copilot, etc.), merge conflicts with the base branch, or the user says "watch this PR", "babysit the PR", "get this PR green".
license: MIT
compatibility: Requires git and gh (GitHub CLI), authenticated with repo access.
---

Babysit the current PR until merge-ready. Alternate between two signals, fixing whatever is broken after each round, terminating only when both are clean at once: **CI checks** (`gh pr checks`) and **bot review threads** (GitHub API). Commits made here follow the global rules (conventional, short, no AI attribution) — committing and pushing fixes is inherent to this workflow.

## Setup

The branch must have a PR. Capture once: `gh pr view --json number,headRefName,baseRefName,url` and `OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)`.

## Phase 1: Initial sweep

### Step 0: Mergeability

Run `gh pr view --json mergeable,mergeStateStatus` and branch on BOTH fields:

- `mergeable: UNKNOWN` → GitHub is still computing; wait ~5s, re-check (up to 3×).
- `mergeStateStatus: BEHIND` → rebase (below) so CI runs against the current base.
- `DRAFT` → not babysittable to merge; ask if it should be marked ready.
- `BLOCKED` with green checks → usually missing required approvals; needs a human — report in the summary, don't loop.
- `MERGEABLE` and none of the above → Step 1.
- `CONFLICTING`/`DIRTY` → rebase onto base: trivial mechanical conflicts (lockfiles, import order, adjacent edits) → resolve, continue, push `--force-with-lease` (never plain `--force`); non-trivial (overlapping logic, schema/API, product judgement) → abort and ask. Re-check mergeability after.

### Step 1: Resolve existing bot threads

```bash
gh api graphql -F owner='{owner}' -F repo='{repo}' -F pr=<number> -f query='
query($owner:String!,$repo:String!,$pr:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviewThreads(first:100){
        pageInfo{hasNextPage endCursor}
        nodes{
          id isResolved isOutdated path line
          comments(first:50){nodes{databaseId author{login} body url}}
        }
      }
    }
  }
}'
```

Page with `after: <endCursor>` while `hasNextPage` (same for 50+-comment threads) — first-page sizes are not the guarantee.

A thread needs attention when `isResolved` is false AND it was **started by a bot** (first comment's author login ends `[bot]` or is a known reviewer bot) — a human reply doesn't make it handled; only resolving does. For each:

1. **Evaluate on the merits** — read the referenced code; bots produce false positives, never blindly apply.
2. True positive → fix; batch related fixes into one conventional commit. False positive / won't-fix → no code change, explain in the reply.
3. **Reply and resolve**:

```bash
# <comment_id> MUST be the databaseId of the thread's FIRST (top-level) comment —
# GitHub rejects replies addressed to a reply.
gh api repos/$OWNER_REPO/pulls/<number>/comments/<comment_id>/replies -f body='<what and why>'
gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -f id='<thread_id>'
```

PR-level bot comments (`gh pr view --json comments`) can't be resolved and usually duplicate the threads — address the threads and move on. Push fixes before proceeding.

### Step 2: CI status

`gh pr checks --required` gates the merge (glance at plain `gh pr checks` for optional failures worth a summary mention — don't loop on them). If the repo has no required checks, `--required` errors — fall back to `gh pr checks`, treat all as gating.

All passing → Phase 2. Pending → Step 3. Failed → Step 4.

### Step 3: Wait

`gh pr checks --watch` blocks until done; then re-run Step 2.

### Step 4: Fix failing checks

1. Identify: `gh pr checks --json name,link,state,workflow`.
2. Logs: GitHub Actions → `gh run view <run-id> --log-failed` (grep the first error). External providers (Vercel, CircleCI, …) have no run id — follow the check's `link`, or ask the user if unreachable.
3. Root-cause from the code, not the log alone. Fix minimally — no unrelated refactoring.
4. Reproduce locally where feasible (lint, typecheck, unit tests). Commit (`fix(ci): …` or whatever fits), push, back to Step 2.

Genuinely unclear failure or architectural fix needed → stop and ask.

## Phase 2: Watch window

All green, all known bot threads resolved. Bots re-review after each push, so:

**Step 5:** Poll ~10 minutes after the last push (every 60–90s): re-run the Step 1 query, diff against handled threads. New unresolved bot thread → handle per Step 1, then back to Step 2 (fixes retrigger CI). Window expires quiet → Step 6.

**Step 6:** Final sanity: re-run `gh pr checks --required` and `gh pr view --json mergeable,mergeStateStatus` — intermediate commits or base movement may have changed things.

- Green + `MERGEABLE` + status `CLEAN`/`HAS_HOOKS` (or `UNSTABLE` with only optional failures — note them) → summary. Done.
- Failing/pending → Step 2. `BEHIND`/conflicting → Step 0. `BLOCKED` → green but needs a human (required reviews) — report.

## Summary report

```
## Babysit PR Summary
- Iterations: N
- Bot threads addressed: X (fixed Y, won't-fix Z)
- CI failures fixed: M
- Final status: all checks green, no unresolved bot threads, mergeable
```

Merging itself is out of scope — report and let the user merge.

## Stopping rules

Bail and ask when: the same check fails 3× after your fixes (diagnosis probably wrong); the same bot re-raises on the same lines after your reply; a failure needs judgement outside the PR's scope (architecture, broken infra, flaky test needing retry policy); the branch is protected or you can't push.

Never use destructive git to get around a failure: `--force-with-lease` after a legitimate rebase is fine; plain `--force`, `reset --hard`, or history rewrites that hide a failing check are not.
