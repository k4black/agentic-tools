---
name: design-doc
description: Use when a feature or significant change needs a design document before implementation — the user says "design X", "write a design doc", or the work is too big or risky to start without locking decisions first.
argument-hint: Feature or change to design
---

Produce `docs/design/yyyy-MM-dd-<slug>.md` — a feature design document complete
enough that another agent (or a ralph loop) can implement from it without access
to this conversation, and lean enough to be read in one sitting.

## Flow

1. **Research the code.** Design against verified facts, not assumptions.
2. **Grill the user.** Resolve every open decision with the `grill-me` skill.
3. **Write the doc** using the template below.
4. **Hand off.** Offer a `critique-loop` review of the doc; implementation
   (a later session, the `test-driven-dev` skill, or a ralph loop) takes the doc as input.

## 1. Research

Before proposing anything:

- Trace the entry points, the nearest similar feature, and its tests — the
  design should look native to the codebase.
- Every claim about existing behavior gets a `path/to/file.py:123` citation you
  actually read. A design built on a misremembered contract fails in review or,
  worse, in implementation.
- Hunt the constraints that bind the design: compatibility contracts, identity
  keys, callers/consumers of anything you touch, patterns already present that
  the design should copy rather than reinvent.
- Never assume something is missing — search first.
- If the project's AGENTS.md/CLAUDE.md has a Terminology section
  (`domain-modeling` skill), use its vocabulary and record new terms there.

## 2. Grill

Collect the decisions research could not settle — scope cuts, API shape,
trade-offs, rollout — and run the `grill-me` skill on them: every question with
a recommended answer, walking dependent decisions in order. The answers become
**locked decisions**; capture each verbatim enough that the rationale survives.

### Headless mode

When no user is available (autonomous loops, CI), there is no grill session:
make each open decision yourself — pick the safest defensible option, lock it
in "Decisions" with rationale, flagged "(headless call — revisit)". Anything
you cannot responsibly decide goes to "Open questions".

## 3. The document

`docs/design/yyyy-MM-dd-<slug>.md`, sections in this order:

```markdown
# <Feature> — design

**Status:** draft | grilled | reviewed | implemented
**Date:** yyyy-MM-dd

## 1. Problem & context
A few sentences: what hurts, for whom, why now. Link prior docs; don't retell them.

## 2. Goals & non-goals
Bulleted, decided, including consumers/callers in scope. Non-goals are as
load-bearing as goals — they stop scope creep at implementation time.

## 3. Decisions (locked)
Numbered. Each: the decision, the rationale, the alternative that lost and why.
Implementers do not re-open these; changing one means updating this doc first.

## 4. Fact base (verified)
The code facts the design stands on, each with file:line. This is what reviewers
check first and what makes the doc trustworthy.

## 5. Design
Main flow first — one narrative or diagram of the end-to-end path. Then
per-component details: interfaces/seams concrete enough to write a failing test
against, data flow, error handling, compatibility/rollout notes.

## 6. Implementation phases
Numbered; each phase = green tests + a reviewable increment.

## 7. Decision log
The grill session Q→A, dated — why the locked decisions say what they say.

## 8. Open questions
Only what genuinely remains; anything blocking belongs in the grill, not here.
```

Target well under ~200 lines. The doc is clear when a reader can start phase 1
without asking anything; it is lean when nothing can be deleted without losing
a decision, a fact, or a seam.

## Reviewing a design doc

The reviewer's checklist — same standard for humans, critique-loop, and
autonomous critics. Read the doc as the engineer who must implement phase 1
tomorrow with no other context:

1. **Implementable?** Could you start phase 1 from the doc alone? Every vague
   sentence is an objection.
2. **Facts true?** Verify the Fact base and behavioral claims against the
   actual code — a wrong `file:line` or misdescribed contract is an objection.
3. **Decisions justified?** Real alternatives, reasons that survive scrutiny;
   "(headless call — revisit)" decisions get extra suspicion.
4. **Seams concrete?** Interfaces specific enough to write a failing test
   against right now.
5. **Scope honest?** YAGNI speculation, silently narrowed requirements,
   missing non-goals.
6. **Contradictions?** Internal, or with the Terminology section / prior
   design docs.

Objections are numbered and concrete: section, what's wrong, what would fix it.
Never approve with "minor issues to fix later"; never invent objections to look
thorough — approve when it is genuinely implementable.

## Style rules

- Prefer concise tables (callers, phases, comparisons) or bullet points
  (reasoning, ideas) over prose.
- Use mermaid diagrams to show complex relations.
- Cite code as `path:line`, always from files read during this session.
- Don't duplicate content that lives elsewhere (AGENTS.md Terminology, prior
  designs) — link it.
- Reviews append to the doc (a dated review-round section or status bump), they
  don't fork it.
