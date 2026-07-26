---
name: improve-agents-md
description: Create, review, or clean up a project's AGENTS.md/CLAUDE.md — audit against the canonical structure, prune stale or derivable content, compress pitfalls, fix misfiled sections, decide which areas earn their own nested file.
argument-hint: "Project or sub-project path (default: repo root)"
disable-model-invocation: true
---

# AGENTS.md/CLAUDE.md Maintenance

Own the project's agent docs: one canonical structure, created when missing,
audited and compressed when present. These tests govern every line.

**The deletion test** — the file is part of every prompt, so each line must earn
its place: *would removing it cause an agent to make mistakes?* If not, cut it.

**Map, not documentation** — every entry says what something is *for* and where
to look for more, never *how it works*. A line describing a class's fields, a
function's steps, or a call sequence duplicates what the code states
authoritatively, goes stale on the next commit, and spends always-loaded context
doing it. This is why "Where things live" is a list and depth lives in per-area
READMEs.

## Canonical structure

One `AGENTS.md` per project, plus nested files for areas that earn one (see
below). Agents read the *nearest* file walking up and **all levels stack
additively** — a nested file is read in addition to root, never instead of it.
**`CLAUDE.md` is always a symlink**: `ln -s AGENTS.md CLAUDE.md`. Target well
under ~200 lines per file.

```
repo/
├── AGENTS.md            # + CLAUDE.md -> AGENTS.md symlink
├── services/api/
│   ├── AGENTS.md        # nested file, specific for this domain
└── apps/web/
    └── AGENTS.md
```

```markdown
# <project> — <one-liner>. Full architecture/setup → README.md

## Project in one glance      ← TLDR: purpose, stack, build system
## Where things live          ← LIST (path: one-line purpose), never prose
                                paragraphs; point to per-area READMEs and mark
                                areas that carry their own AGENTS.md
## Terminology                ← domain glossary; only if non-obvious terms exist
## Commands                   ← copy-paste-ready; wrong-vs-right variants
## Core rules                 ← numbered, few, non-overlapping; including 
                                root agent docs rule to update AGENTS.md
## Code style                 ← in the root agent doc, only if differs from
                                the formatter's default;
## Verification               ← change shape → smallest falsifying check;
                                plus PR steps that aren't default
## Gotchas                    ← numbered, symptom → cause → fix, 1–3 lines
```

Use only the sections the project needs. Verification is a decision tree, not
"run the tests": docs-only → lint; one package → its unit tests; shared code →
affected packages then integration; schema → the migration check.

## When a service/domain earns its own AGENTS.md

Two gates: an own build/test story is **necessary**, enough area-specific
non-derivable content is **sufficient**.

Ownership rule: a nested file holds **only what is false or absent at root**.
Restating a shared convention one level down isn't redundancy, it's a conflict
waiting to drift. Each nested file opens with its scope and a pointer up:

```markdown
# services/api — module instructions
> See Project-wide: ../../AGENTS.md
```

| Case | Own file? | Why |
|---|---|---|
| Monorepo `packages/*` behind one root build, shared conventions | No | Everything true of them is true at root — one "Where things live" entry each |
| Monorepo sub-project on its own stack and CI (`services/api` under a JS root) | Yes | Root commands and gotchas would be actively wrong there |
| Rust workspace: small crates covered by one `cargo test` | No | Root commands cover them; a crate's purpose is one line at root |
| Rust workspace: a large crate with own feature flags, integration harness, unsafe invariants | Yes | Several non-derivable facts that hold nowhere else |
| Flutter `apps/driver`, `apps/rider` — own flavors and store-release steps | Yes, one each | Build and release story differs per app |
| Flutter `packages/core` shared by both apps | No | Nothing about it is false at root |

## Good vs bad lines

| Bad | Good |
|---|---|
| "Write clean code, follow SOLID and DRY." | *(deleted — costs context, changes no behavior)* |
| "`src/` holds the source, `tests/` holds the tests." | *(deleted — `ls` shows this)* |
| "`OrderService.submit()` validates the cart, writes the order, then emits `OrderPlaced`." | "`domain/order/` — order lifecycle. Never called from `api/` handlers directly." |
| "Be careful when modifying authentication." | "Session revocation is checked in `api/auth/session.ts` **and** `workers/auth/session-cache.ts` — change both or sessions survive logout." |
| "Run the tests before committing." | "`pnpm --filter <pkg> test` for one package; `pnpm test:integration` only when `packages/core` changed." |
| "Use 2-space indent, single quotes, sorted imports." | "Format with `pnpm format` — don't hand-fix style." |
| "For releases make steps 1 2 3 ....10" | "Releases: use the `release-service` skill." or "See `docs/releasing.md`" |

## Maintenance workflow

Explore first (README, build files, existing agent docs, a stretch of
`git log` for hot spots), then branch:

### No AGENTS.md present — create

1. Derive each section from the repo: real commands (verify they run), the
   directory map, conventions that differ from defaults, gotchas from README 
   warnings / CI configs / recent fix commits.
2. Write `AGENTS.md` per the structure; skip sections with nothing non-obvious.
3. `ln -s AGENTS.md CLAUDE.md` (if a real CLAUDE.md already exists, merge its
   content in first, then replace it with the symlink).
4. Apply the two gates before offering any nested file — never scaffold empties.

### AGENTS.md exists — review and maintain

Audit, then present the findings and proposed edits as a short report
(what/why per change); apply after the user agrees.

1. **Currency** — run the commands; check referenced paths exist; flag stale
   tech versions, dead files, never-completed TODOs.
2. **Smells** — name them (below); don't force a finding into the nearest label.
3. **Misfiled content** — fix is *move*, not delete: design-doc paragraphs grown
   inside "Where things live" bullets → a per-area README or `docs/design/`,
   leaving a one-line row; terminology buried in Gotchas → Terminology;
   multi-hundred-word incident writeups → compress to symptom → cause → fix.
4. **Restructure** — reorder to the canonical skeleton; collapse prose directory
   maps into the "Where things live" list.
5. **Split check** — run the two gates over nested files in both directions:
   files failing them collapse into "Where things live" entries at root;
   qualifying areas without a file get one, with the pointer header.
6. **Symlink check** — if CLAUDE.md and AGENTS.md are separate real files,
   merge and symlink (AGENTS.md is the real file).
7. Report the before/after line count.

## Smells

| Smell | Symptom | Fix |
|---|---|---|
| **Context bloat** | Lines failing the deletion test — derivable from code, changelog entries, generic advice | Delete |
| **Code paraphrase** | Lines describing what a class or function *does* — its steps, fields, signature | Cut to one map line: path, purpose, why it exists |
| **Lint leakage** | Indentation, quotes, import order, naming already enforced by a formatter | Delete; name the formatter command instead |
| **Skill leakage** | A multi-step procedure (release, migration, review) inlined in always-loaded context | Move to a skill, leave a one-line routing rule |
| **Blind reference** | `See docs/x.md` with no what-and-when | Say what's in it and when to open it — or delete |
| **Conflict** | The same rule stated differently at two levels, or contradicting the global layer | Keep one, at the level where it's always true |
| **Init fossilization** | Untouched `/init` output — file-by-file tour, dependency lists, stale versions | Rewrite from the skeleton |

## Rules

- The file is advisory context, not enforcement — behavior that MUST happen
  belongs in hooks/permissions, multi-step procedures belong in skills/docs.
- Emphasis (**IMPORTANT**, "X, NOT Y") sparingly — it works because it's rare.
- Conflicting rules across files are picked arbitrarily by agents — dedupe.
- Keep the global layer (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`) out of 
  project files — never duplicate global rules locally.
