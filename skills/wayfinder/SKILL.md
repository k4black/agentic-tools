---
name: wayfinder
description: Plan a huge chunk of work — more than one agent session can hold — as a map of decision tickets, resolved one per session until the way to the destination is clear.
argument-hint: "A loose idea to chart, or an existing map to work through"
disable-model-invocation: true
license: MIT
---

# Wayfinder

A loose idea has arrived — too big for one agent session, and wrapped in fog:
the way from here to the **destination** isn't visible yet. Wayfinder charts
the way as a **map** of **decision tickets** — questions whose resolution is a
decision, not slices of a build to execute — and resolves them one at a time
until the route is clear.

**Plan, don't do.** Each ticket resolves a decision; the map is done when
nothing is left to decide before someone builds the thing. The pull to just do
the work is the signal you've reached the edge of the map — hand off (usually
to `design-doc` or straight to implementation). Produce decisions, not
deliverables.

**Refer by name.** In everything the human reads, refer to maps and tickets by
title, never bare ids — `#42` walls are illegible. The id/link rides inside the
name.

## The medium

Where the map and tickets live depends on what the project already uses —
decide once at charting time, note it in the map:

1. **GitHub issues** — the repo actively uses issues: the map is one issue
   labelled `wayfinder:map`, tickets are sub-issues; use native blocked-by
   relationships where available, else a `Blocked by: #N` body line. Claim a
   ticket by assigning yourself.
2. **GitHub Project** — the team already works from a project board: same
   issues, added to the board so the frontier is visible as a column.
3. **Local markdown** (default) — `docs/plan/<slug>/map.md` plus one
   `NN-<slug>.md` per ticket. Blocking as a `Blocked by:` line; "closed" =
   a `Resolved:` line with the answer's gist.

## The map

The map is an **index**, not a store: a decision lives in exactly one place —
its ticket — the map only gists and links. Load it once per session at low
resolution; zoom into ticket bodies on demand.

```markdown
## Destination

<what reaching the end looks like — the spec, decision, or change this effort
is finding its way to. One or two lines; every session orients to it first.>

## Notes

<domain; skills every session should consult; standing preferences>

## Decisions so far

- [<closed ticket title>](link) — <one-line gist of the answer>

## Not yet specified

<in-scope fog — suspected questions not yet sharp enough to ticket>

## Out of scope

<work consciously ruled beyond the destination; never graduates>
```

**Fog or ticket?** Ticket when you can state the question precisely now (even
if blocked); "Not yet specified" when you can't. Don't pre-slice fog — one
patch may graduate into several tickets, or none. Out-of-scope work isn't fog:
it sits past the destination and returns only if the destination is redrawn.

## Tickets

A ticket's body is one question, sized to one agent session. Each carries a
type — and is either **HITL** (worked with the human, who speaks for
themselves; an agent that answers its own questions has broken HITL) or
**AFK** (agent alone):

- **research** (AFK) — a fact a decision waits on, outside the working
  directory. Resolved by a `research` sub-agent.
- **prototype** (HITL) — raise the fidelity of the discussion with a cheap
  concrete artifact via the `prototype` skill; link it as an asset.
- **grilling** (HITL) — conversation, the default. Use the `grill-me` and
  `domain-modeling` skills.
- **task** (HITL or AFK) — manual work that blocks a decision (provision
  access, move data, sign up for a service). Earns its place by unblocking a
  decision. Record what was done and the resulting facts.

A ticket is **unblocked** when everything blocking it is closed; the
**frontier** is the open, unblocked, unclaimed tickets.

## Chart the map

Invoked with a loose idea:

1. **Name the destination** — a `grill-me` (+ `domain-modeling`) session pins
   what this map is finding its way to. The destination fixes the scope.
2. **Map the frontier** — grill again, **breadth-first**: fan out across the
   space, surfacing open decisions and first takeable steps. **No fog
   surfaced?** The journey fits one session — stop, no map needed; ask how the
   user wants to proceed.
3. **Create the map** — Destination and Notes filled, Decisions-so-far empty,
   fog sketched into Not-yet-specified. Pick and note the medium.
4. **Create the tickets you can specify now**, then wire blocking edges in a
   second pass (tickets need ids before they can reference each other).
5. **Fire the research sub-agents** — one per research ticket, in parallel;
   findings land as a cited file linked from the ticket.
6. Stop — charting is one session's work; it hand-resolves nothing.

## Work through the map

Invoked with a map (a ticket is optional — without one, you pick):

1. Load the map, not every ticket body.
2. Take the named ticket, or the first frontier ticket. Claim it first.
3. Resolve it — zoom into related tickets on demand; use the skills the map's
   Notes name. In doubt: `grill-me` + `domain-modeling`.
4. Record: post the answer on the ticket, close it, add one gist line to
   Decisions-so-far.
5. Update the map: create newly-surfaced tickets (create, then wire);
   graduate fog the answer made specifiable (clearing it from
   Not-yet-specified); close mis-scoped tickets into Out-of-scope with one
   line saying why; fix tickets the decision invalidated.

**Never resolve more than one ticket per session** — research tickets, burned
down by sub-agents, are the one exception.
