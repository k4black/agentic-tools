---
name: agents-md
description: Create, review, or clean up a project's AGENTS.md/CLAUDE.md — audit against the canonical structure, prune stale or derivable content, compress pitfalls, fix misfiled sections.
argument-hint: "Project or sub-project path (default: repo root)"
disable-model-invocation: true
---

# AGENTS.md Maintenance

Own the project's agent docs: one canonical structure, created when missing,
audited and compressed when present. The file is part of every prompt — each
line must earn its place. Test for every line: *would removing it cause an
agent to make mistakes?* If not, cut it.

## Canonical structure

One `AGENTS.md` per project — and per sub-project in monorepos (colocated;
agents read the nearest file walking up, all levels are additive).
**`CLAUDE.md` is always a symlink**: `ln -s AGENTS.md CLAUDE.md`. Target well
under ~200 lines per file; depth is delegated to per-area READMEs and dated
`docs/design/` docs.

```
repo/
├── AGENTS.md            # this format; CLAUDE.md -> AGENTS.md symlink
├── docs/design/         # dated design docs (cross-cutting)
├── services/api/
│   ├── AGENTS.md        # sub-project file, same format, own Terminology
│   └── docs/design/
└── apps/web/
    └── AGENTS.md
```

```markdown
# <project> — <one-liner>. Full architecture/setup → README.md

## Project in one glance      ← TLDR: purpose, stack, build system
## Where things live          ← TABLES (path | one-line purpose), never prose
                                paragraphs; point to per-area READMEs
## First-time setup           ← only if non-obvious
## Commands                   ← copy-paste-ready; wrong-vs-right variants
## Core rules                 ← numbered, few, non-overlapping
## Code style                 ← only deviations from defaults; "X, NOT Y" form
## Testing / Making a PR      ← short
## Terminology                ← domain glossary (format: domain-modeling skill)
## Gotchas                    ← numbered, symptom → cause → fix, 1–3 lines,
                                ends with "add new gotchas here" self-maintenance
```

Use only the sections the project needs. Content rules — include only what an
agent can't derive from the code: pitfalls, rationale, non-default conventions,
commands that aren't guessable. Never: changelogs, file-by-file tours, generic
best practices, API docs (link instead), anything the code itself shows.

## Flow

Explore first (README, build files, existing agent docs, a stretch of
`git log` for hot spots), then branch:

### No AGENTS.md present — create

1. Derive each section from the repo: real commands (verify they run), the
   directory map as a table, conventions that differ from defaults, gotchas
   from README warnings / CI configs / recent fix commits.
2. Write `AGENTS.md` per the structure; skip sections with nothing non-obvious.
3. `ln -s AGENTS.md CLAUDE.md` (if a real CLAUDE.md already exists, merge its
   content in first, then replace it with the symlink).
4. In monorepos, offer per-sub-project files only for areas with their own
   build/test story — don't scaffold empties.

### AGENTS.md exists — review and maintain

Audit, then present the findings and proposed edits as a short report
(what/why per change); apply after the user agrees.

1. **Currency** — run the commands; check referenced paths exist; flag stale
   tech versions, dead files, never-completed TODOs.
2. **Misfiled content** — the common failure modes:
   - design-doc paragraphs grown inside "Where things live" bullets → move to
     a per-area README or `docs/design/`, leave a one-line row;
   - terminology buried in Gotchas → move to Terminology;
   - multi-hundred-word incident writeups in Gotchas → compress to
     symptom → cause → fix + pointer;
   - rules duplicated across sections (or across nested files) → keep one.
3. **Prune** — delete everything failing the "would removing this cause
   mistakes?" test: derivable-from-code content (directory layouts an agent
   can ls, dependency lists), changelog-style entries, generic advice.
4. **Restructure** — reorder to the canonical section skeleton; convert prose
   directory maps to tables; add the missing self-maintenance line to Gotchas.
5. **Symlink check** — if CLAUDE.md and AGENTS.md are separate real files,
   merge and symlink (AGENTS.md is the real file).
6. Report the before/after line count.

## Rules

- The file is advisory context, not enforcement — behavior that MUST happen
  belongs in hooks/permissions, multi-step procedures belong in skills.
- Emphasis (**IMPORTANT**, "X, NOT Y") sparingly — it works because it's rare.
- Conflicting rules across files are picked arbitrarily by agents — dedupe on
  sight.
- Keep the global layer (GLOBAL-AGENTS.md → `~/.claude/CLAUDE.md`,
  `~/.codex/AGENTS.md`) out of project files — never duplicate global rules
  (git conventions, RTK usage) locally.
