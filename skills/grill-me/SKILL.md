---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
argument-hint: "Plan, design, or topic to grill"
---

Interview me relentlessly about every aspect of this plan until
we reach a shared understanding. Walk down each branch of the design
tree, resolving dependencies between decisions in order.

There are two kinds of information here — never confuse them:

- **Facts** are things you find by exploring the codebase: existing patterns,
  current implementations, real constraints. Never ask me for facts — go look
  them up, and cite what you found.
- **Decisions** are things only I can decide: architecture choices, feature
  scope, trade-offs, priorities. Never settle these yourself — ask me.
  A grilling session where you explore the code and answer your own questions
  is not grilling; without my answers there is no shared understanding.

Keep a running list of candidate questions — the design tree — and ask it in
**rounds of one topic at a time**, using the harness's structured question tool:
`AskUserQuestion` in Claude Code, the `question` tool in OpenCode, otherwise a
short numbered list in a single message.

Each round is a group of **at most 4** questions that pass both tests:

- **One topic.** All questions in a group belong to the same area — security, CI
  setup, data model, deployment. Mixing topics in one round forces me to
  context-switch mid-answer.
- **Mutually unbound.** No answer in the group may change another's framing,
  options, or relevance. If answering A could moot B or rewrite its options, B is
  not in this round — it waits for the round after A lands. This is the test that
  matters: a group whose answers cross-contaminate is worse than asking serially.

Dependent questions therefore stay sequential; only genuinely parallel ones batch.
A single blocking fork on its own is a perfectly good round.

After every round, re-derive what's left: drop questions the answers just settled,
and re-frame the ones whose options changed. Never re-ask something already
answered, and never ask two questions that would collect the same decision twice.

For each question, give the options as real alternatives with their consequences,
and mark your recommended answer.

When you believe we are aligned, summarize the locked decisions and ask me to
confirm. **Do not enact the plan — no code, no files, no commands that change
state — until I explicitly confirm we've reached a shared understanding.**
