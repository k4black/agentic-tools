---
name: babysit-pr
description: Use when a pull request needs to be driven to merge-ready — failing CI checks, unresolved bot review comments (CodeRabbit, Copilot, etc.), merge conflicts with the base branch, or the user says "watch this PR", "babysit the PR", "get this PR green".
license: MIT
compatibility: Requires git and gh (GitHub CLI), authenticated with repo access.
---

Babysit the current PR until it is merge-ready. Alternate between two signals and fix whatever is broken after each round:

1. **CI checks** — all required checks pass (`gh pr checks`).
2. **Bot review comments** — no unresolved bot review threads (GitHub API via `gh`).

Terminate only when both signals are clean at the same time.

Commits made by this workflow follow the global rules: Conventional Commits, short messages, no AI-attribution strings. Committing and pushing fixes is inherent to this workflow — that is what the user asked for by invoking it.

## Setup

The current branch must have an associated PR. Capture the coordinates once:

```bash
gh pr view --json number,headRefName,baseRefName,url
OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

## Phase 1: Initial sweep

### Step 0: Ensure the PR is mergeable

A stale base can make CI pass on obsolete code or block merge even when every check is green.

Run `gh pr view --json mergeable,mergeStateStatus,baseRefName`.

- **`MERGEABLE`** → Step 1.
- **`UNKNOWN`** → GitHub hasn't computed it yet; wait ~5s and re-check (up to 3 tries).
- **`CONFLICTING` / `DIRTY`** → rebase onto the base branch:
  - Trivial, mechanical conflicts (lockfiles, import ordering, adjacent edits to separate symbols): resolve, continue the rebase, push with `--force-with-lease` (never plain `--force`).
  - Non-trivial conflicts (overlapping logic, schema/API changes, anything needing product judgement): abort the rebase and ask the user.
  - Re-check mergeability before proceeding.

### Step 1: Resolve existing bot comments

Fetch unresolved review threads and identify which are from bots:

```bash
gh api graphql -F owner='{owner}' -F repo='{repo}' -F pr=<number> -f query='
query($owner:String!,$repo:String!,$pr:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviewThreads(first:100){
        nodes{
          id isResolved isOutdated path line
          comments(first:50){nodes{databaseId author{login} body url}}
        }
      }
    }
  }
}'
```

A thread needs attention when `isResolved` is false and the last comment is from a bot (login ends in `[bot]`, or is a known reviewer bot). For each such thread:

1. **Evaluate the finding on the merits.** Read the referenced code. Bots produce false positives; do not blindly apply suggestions.
2. **True positive** → fix the code. Batch related fixes into one conventional commit.
3. **False positive / won't-fix** → no code change; explain why in the reply.
4. **Reply and resolve** the thread:

```bash
# Reply to the thread (use the last comment's databaseId)
gh api repos/$OWNER_REPO/pulls/<number>/comments/<comment_id>/replies -f body='<what you did and why>'

# Mark the thread resolved
gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -f id='<thread_id>'
```

Also check PR-level bot comments (`gh pr view --json comments`) — these can't be "resolved", but summary comments from review bots often duplicate the threads; address the threads and move on.

Push any fixes before proceeding.

### Step 2: Check CI status

Run `gh pr checks`.

- **All passing** → Phase 2.
- **Any pending / in-progress** → Step 3.
- **Any failed** → Step 4.

### Step 3: Wait for in-flight checks

`gh pr checks --watch` blocks until every check finishes. When it returns, re-run Step 2.

### Step 4: Fix failing checks

For each failed check:

1. Identify the failing run: `gh pr checks --json name,link,state,workflow`.
2. Fetch failing logs: `gh run view <run-id> --log-failed` (grep for the first error in long logs).
3. Analyze the root cause — read the relevant code, don't guess from the log alone.
4. Fix minimally; do not refactor unrelated code.
5. Reproduce the check locally where feasible (lint, type-check, unit tests).
6. Commit (`fix(ci): …` or whatever type actually fits) and push.
7. Return to Step 2.

If the failure is genuinely unclear or the fix would require architectural changes, stop and ask the user.

## Phase 2: Watch window

All checks are green and all known bot threads are resolved. Bots typically re-review after each push, so wait to see whether anything new appears.

### Step 5: Poll for new bot activity

Poll for a bounded window (default ~10 minutes after the last push, checking every 60–90s):

- Re-run the reviewThreads query from Step 1 and diff against the threads you've already handled.
- **New unresolved bot thread** → handle as in Step 1, then back to **Step 2** (your fix commits retrigger CI).
- **Window expires with nothing new** → Step 6.

### Step 6: Final sanity check

Re-run `gh pr checks` and `gh pr view --json mergeable` once more — intermediate commits may have kicked off a new run, and the base may have moved.

- **All green and mergeable** → summary report. Done.
- **Anything failing/pending** → back to Step 2.
- **Conflicting with base** → back to Step 0.

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

Bail out and ask the user when:

- The same check fails 3 times in a row after your fixes — your diagnosis is probably wrong.
- The same bot re-raises a comment on the same lines after your reply — it isn't accepting the fix or dismissal.
- A failure requires judgement outside the PR's scope (architectural change, broken infra, flaky test needing a retry policy rather than a fix).
- The branch is protected or you were not authorized to push to it.

Never use destructive git operations to get around a failure. `--force-with-lease` after a legitimate rebase is fine; plain `--force`, `reset --hard`, or history rewrites that hide a failing check are not.
