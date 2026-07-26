---
name: github-project-setup
description: Bring a GitHub repo to a hardened default — squash-only merges, protected default branch via ruleset, Dependabot, PR-title linting. Reads the current settings first and changes only what differs.
argument-hint: "OWNER/REPO (default: origin of the current repo)"
disable-model-invocation: true
---

# GitHub Project Setup

One opinionated target state, applied by difference: read everything first, show
what deviates, change only that. Settings already correct are never rewritten.

**A ruleset is a guardrail, not a boundary.** Any repo admin can delete it or set
`enforcement: disabled` — on a personal repo that admin is always the owner. This
protects against accident, not intent; never report it as security.

## Target state

| Surface | Setting | Value |
|---|---|---|
| Merges | squash only, merge + rebase off; commit title = PR title | `allow_squash_merge`, `squash_merge_commit_title=PR_TITLE` |
| Merges | delete branch on merge, suggest updating PR branches, auto-merge | `delete_branch_on_merge`, `allow_update_branch`, `allow_auto_merge` |
| Features | Discussions on, Wiki off | `has_discussions`, `has_wiki` |
| Default branch | require a PR, dismiss stale reviews, require conversation resolution, linear history, no force-push, no deletion, squash-only merge | one ruleset (`assets/ruleset.json`) |
| Default branch | admin bypass, `always` | `bypass_actors: RepositoryRole 5` |
| Files | weekly Dependabot; advisory PR-title lint | `.github/dependabot.yml`, `.github/workflows/pr-title.yml` |

Deliberately out of scope: **required status checks** (wiring check contexts is
per-repo CI work, and a context that never reports blocks every PR forever).

## 1. Read current state

```bash
R="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
gh api "repos/$R" --jq '{owner_type: .owner.type, private, visibility, default_branch,
  allow_squash_merge, allow_merge_commit, allow_rebase_merge, squash_merge_commit_title,
  delete_branch_on_merge, allow_update_branch, allow_auto_merge, has_discussions, has_wiki}'
gh api "repos/$R/rulesets" --jq '.[] | {id, name, enforcement}'   # rules NOT included here
gh api "repos/$R/rulesets/<id>" --jq '{conditions, rules, bypass_actors}'   # one GET per id
gh api "repos/$R/contents/.github/dependabot.yml" --silent 2>/dev/null && echo "dependabot: present"
ls .github/workflows/ 2>/dev/null   # any PR-title linter already here?
```

Do **not** use `gh repo view --json` for the diff — it lacks `autoMergeAllowed` and
every squash-title field. Branch-protection reads 404 with `"Branch not protected"`
when unset: that is "absent", not an error.

Capability gates, from `owner_type` / `private` — check before proposing anything:

| Feature | Available | On a User-owned repo |
|---|---|---|
| Ruleset / branch protection | public+Free, or private with **Pro** | private + free account → **neither works** |
| Merge queue | public repo **owned by an org**, or private org on GHEC | **unavailable** — no API path at all, even in the UI |
| `commit_message_pattern` (conventional commits) | **GHEC/GHES only** | **unavailable** — fall back to the PR-title workflow |

## 2. Ask, then apply

Ask all four in one batch, each with the detected default pre-filled — **the
answers ARE the approval**, there is no second confirmation gate. Everything not
asked about has one right answer and is applied without a prompt.

1. **Required approvals — 0 or 1?** Default 0 on a solo repo: nobody can approve
   their own PR, so 1 makes every owner-opened PR unmergeable except through the
   admin bypass, which trains routine bypassing. 0 still enforces the PR trail,
   conversation resolution, dismiss-stale-reviews and squash-only.
2. **Discussions — on, or issues only?** Default off for a repo with no user
   community to host; on for anything public-facing.
3. **Dependabot — configure, or skip?** If configuring, propose the ecosystems the
   manifests show (`pyproject.toml`/`requirements*.txt` → pip, `uv.lock` → uv,
   `package.json` → npm, `Cargo.toml` → cargo, `pubspec.yaml` → pub, `Dockerfile`
   → docker, `.github/workflows/` → github-actions) and confirm the set **plus each
   `directory`** — those two are why the asset is an example, not a drop-in.
4. **Conventional commits — enforce how?** Three honest levels: *skip* (squash-only
   + `PR_TITLE` already means your PR title becomes the commit, self-policed);
   *advisory* (add the PR-title workflow — red on a bad title, still merges); or
   *blocking* via the ruleset `commit_message_pattern` rule, **GHEC/GHES only**.
   Check entitlement before offering the third.

Report the diff as you apply, one line per change; skip anything already correct.

### Repo settings (one call, idempotent)

```bash
gh repo edit "$R" \
  --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false \
  --squash-merge-commit-message=pr-title \
  --delete-branch-on-merge --allow-update-branch --enable-auto-merge \
  --enable-discussions --enable-wiki=false
```

`--squash-merge-commit-message=pr-title` sets title `PR_TITLE` + body `BLANK`. The
default `COMMIT_OR_PR_TITLE` silently uses the *commit* subject on single-commit
PRs, bypassing the PR title — so it must not stay at default.

### Ruleset

Repo merge settings must be applied first: linear history is rejected unless
squash or rebase merging is allowed. Then create disabled, verify, activate.
`assets/` paths below are relative to **this skill's directory**, not the target
repo — resolve them against the base directory given when the skill loaded.

```bash
# 1. create, inert. Set approvals per answer 1 first.
jq '.rules[0].parameters.required_approving_review_count = 0' assets/ruleset.json \
  | gh api -X POST "repos/$R/rulesets" --input -

# 2. org-owned only: append merge queue. GHEC only: append commit_message_pattern.
jq --slurpfile o assets/optional-rules.json '.rules += [$o[0].merge_queue]' ...

# 3. verify the server kept what was sent — especially the bypass
gh api "repos/$R/rulesets/<id>" --jq '{enforcement, bypass_actors, rules: [.rules[].type]}'

# 4. activate
jq '.enforcement = "active"' <edited-payload> | gh api -X PUT "repos/$R/rulesets/<id>" --input -
gh ruleset check "$(gh api "repos/$R" --jq .default_branch)" -R "$R"
```

Step 3 is not optional: `actor_id: 5` for repository admin is **community-derived
and officially undocumented** ([rest-api-description#4406], open since 2024) —
accepted and echoed back on a User-owned public repo as of 2026-07, but unversioned
and liable to change, so confirm rather than assume it every time. If
`bypass_actors` comes back empty, the id is wrong — stop and report it rather than
activating a ruleset that locks the owner out. `PUT` is a full replace, not a merge.

### Files (only if absent — never edit an existing one)

Copy `assets/dependabot.example.yml` → `.github/dependabot.yml`, keeping only the
confirmed ecosystems and fixing each `directory`. Copy `assets/pr-title.yml` →
`.github/workflows/pr-title.yml` only when no PR-title linter exists already.

## 3. Report

State per surface: changed / already correct / skipped-and-why. Name every
unavailable feature with its reason, so the gap is a known limit and not a mystery.
Close by re-reading `repos/$R` and the ruleset to confirm the applied state.

## Gotchas

- Ruleset field names differ from the UI labels **and from GitHub's own rendered
  docs**: `dismiss_stale_reviews_on_push` (not `dismiss_stale_reviews`),
  `required_review_thread_resolution` (not `require_conversation_resolution`). The
  wrong names are the *classic branch protection* ones. Use `assets/ruleset.json`.
- All five `pull_request` parameters are schema-required; a partial object 422s.
- Bypass is **per-ruleset, not per-rule** — the admin bypass here also covers
  force-push and deletion. Split into two rulesets if that matters.
- A bypassed push is not silent: git prints `remote: Bypassed rule violations for
  refs/heads/main` and lists the rule it stepped over. Treat that line as the
  guardrail working, not as a warning to suppress. (`bypass_mode: exempt` would
  suppress the audit entry — which is why this ruleset uses `always`.)
- `OrganizationAdmin` is hard-rejected on personal repos, and actors are validated
  at create time even with `enforcement: disabled`.
- `bypass_actors` is only returned to callers with write access to the ruleset.
- The merger can hand-edit the squash commit title in the merge dialog; nothing
  revalidates it. That hole cannot be closed on a non-Enterprise plan.

## Docs

[Rulesets REST](https://docs.github.com/en/rest/repos/rules) ·
[Available rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) ·
[Ruleset plan gating](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) ·
[Repo settings REST](https://docs.github.com/en/rest/repos/repos#update-a-repository) ·
[gh repo edit](https://cli.github.com/manual/gh_repo_edit) ·
[Merge queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue) ·
[Dependabot options](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference)

[rest-api-description#4406]: https://github.com/github/rest-api-description/issues/4406
