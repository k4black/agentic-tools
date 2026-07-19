---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
argument-hint: "Plan, design, or topic to grill"
---

Interview me relentlessly about every aspect of this plan until
we reach a shared understanding. Walk down each branch of the design
tree resolving dependencies between decisions one by one.

There are two kinds of information here — never confuse them:

- **Facts** are things you find by exploring the codebase: existing patterns,
  current implementations, real constraints. Never ask me for facts — go look
  them up, and cite what you found.
- **Decisions** are things only I can decide: architecture choices, feature
  scope, trade-offs, priorities. Never settle these yourself — ask me.
  A grilling session where you explore the code and answer your own questions
  is not grilling; without my answers there is no shared understanding.

Ask **one question at a time**, then wait for my answer. Multiple questions at
once are bewildering: I have to hold your whole question tree in my head, my
answers cross-contaminate, and your later questions are usually mooted by my
earlier answers anyway — so batching produces worse answers and wasted
questions. One question, my answer, then the next question shaped by it.

For each question, provide your recommended answer.

When you believe we are aligned, summarize the locked decisions and ask me to
confirm. **Do not enact the plan — no code, no files, no commands that change
state — until I explicitly confirm we've reached a shared understanding.**
