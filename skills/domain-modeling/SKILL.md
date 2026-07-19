---
name: domain-modeling
description: Own the project's agent docs and domain language. Use when creating or restructuring an AGENTS.md/CLAUDE.md, when the user wants to pin down domain terminology, or when another skill needs the project glossary maintained.
---

# Domain Modeling & Agent Docs

Two jobs, one file: the canonical **AGENTS.md/CLAUDE.md format** below, and the
*active* discipline of maintaining its **Terminology** section — challenging
terms, inventing edge-case scenarios, writing the glossary down the moment it
crystallises. (Merely *reading* the Terminology section for vocabulary is not
this skill; use it when changing the docs or the model.)

## Canonical AGENTS.md / CLAUDE.md format

One file per project — and per sub-project in monorepos (colocated, e.g.
`services/api/AGENTS.md`; agents read the nearest file walking up, all levels
are additive). `CLAUDE.md` is a symlink to `AGENTS.md` (`ln -s AGENTS.md CLAUDE.md`). Target well
under ~200 lines per file; depth is delegated to per-area READMEs and dated
`docs/design/` docs (which may also live per sub-project: `<sub>/docs/design/`).

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
## Terminology                ← the domain glossary (format below)
## Gotchas                    ← numbered, symptom → cause → fix, 1–3 lines,
                                ends with "add new gotchas here" self-maintenance
```

Content rules: only what an agent can't derive from the code (pitfalls,
rationale, non-default conventions); no changelogs, no file-by-file tours, no
generic best practices. Test for every line: *would removing it cause mistakes?*

## Terminology section format

```md
## Terminology

**Order**: A confirmed customer purchase, from checkout to fulfillment.
_Avoid_: purchase, transaction

**Customer**: A person or organization that places orders.
_Avoid_: client, buyer, account
```

- **Be opinionated** — pick one canonical term, list the losers under `_Avoid_`.
- **Tight definitions** — one or two sentences; what it IS, not what it does.
- **Project-specific terms only** — general programming concepts don't belong.
- **No implementation details** — it's a glossary, not a spec or scratchpad.
- Add the section lazily, when the first term is resolved.

## During the session

- **Challenge against the glossary.** A term conflicting with Terminology gets
  called out immediately: "Your glossary defines 'cancellation' as X, but you
  seem to mean Y — which is it?"
- **Sharpen fuzzy language.** Vague or overloaded term → propose a precise
  canonical one: "'account' — the Customer or the User? Different things."
- **Stress-test with concrete scenarios.** Invent edge cases that force
  precision about the boundaries between concepts.
- **Cross-reference with code.** The user says how something works → check the
  code agrees; surface contradictions: "Your code cancels entire Orders, but
  you just said partial cancellation is possible — which is right?"
- **Update Terminology inline**, the moment a term resolves — never batch.

## Hard decisions

There is no separate ADR system. A decision that is hard to reverse, surprising
without context, and a real trade-off is recorded as a locked Decision in a
dated `docs/design/yyyy-MM-dd-<slug>.md` doc (see the `design-doc` skill) — a
standalone decision gets a short decision-only doc. Anything less doesn't need
a record.
