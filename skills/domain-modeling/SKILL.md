---
name: domain-modeling
description: Maintain the project's domain language. Use when the user wants to pin down domain terminology, when terms are fuzzy or conflicting during design, or when another skill needs the project glossary maintained.
---

# Domain Modeling

The *active* discipline of maintaining the **Terminology** section of the
project's AGENTS.md/CLAUDE.md — challenging terms, inventing edge-case
scenarios, writing the glossary down the moment it crystallises. (Merely
*reading* Terminology for vocabulary is not this skill; use it when changing
the model. The agent-docs file itself — structure, creation, cleanup — is the
`agents-md` skill's job; in monorepos the glossary lives in the *nearest*
AGENTS.md.)

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
