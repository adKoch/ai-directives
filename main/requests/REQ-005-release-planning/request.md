---
id: REQ-005
title: release-planning, versioned releases with milestones, the tester and RC acceptance
status: approved
approved_by: owner, 2026-11-16 ("Approve")
source: main/discussions/2026-11-10-agent-templates.md (2026-11-16)
depends_on: [REQ-001, REQ-003]
---
# REQ-005 release-planning

## Goal
The milestone → final test → RC → release rhythm becomes its own template instead of a silent assumption of
`agents-base`. The owner: the tester "relies on specific structure of the plan which actually is based on silent
assumption that we are doing rc into release workflow. This should also be described as a dedicated template".
`release-planning` links `agents-metawork`.

## Requirements

### Releases and the plan
- Every project versions with SemVer; a release candidate is tagged `v<x.y.z>-rc.<n>` ("yes").
- A release is the request sets the owner assigns to it. There is **one plan per release**, `ctxm/plans/v<x.y>.md`
  ("A, one plan per release"). A request set approved later for the release joins the plan as further milestones;
  the planner replans only the parts not started.
- A **milestone** is a group of the plan: one outcome the owner could see demoed, with a demo list, ending in the
  tester's milestone test.
- A **patch release** (fixes from the owner's own use, e.g. an install smoke test) is a small request set with one
  milestone and the same RC steps.

### The tester
- The tester role belongs to this template, with its whole workflow ("tester should be bound to this plan with it's
  main workflow description").
- **Milestone test:** after a milestone's items are merged, the full tier plus the milestone's acceptance and the
  inspector's caselists. The tester gets only requirements, acceptance, caselists and the commit; never the
  workers' submissions or the review findings.
- **Final test:** when the release scope is merged. It starts with a scope review: delete tests the release made
  redundant (each with what still covers it), merge overlapping ones, speed up slow ones. Then the full tier and
  every acceptance scenario of the release.
- Defects go to `problem-solver` as fix items; a fix is retested at the next milestone test or the final test.
- The inspector's caselist belongs here too: it exists to feed the tester.

### The RC
- After the final test passes and the librarian's maintenance batch has run, main tags the RC and writes its record
  in `ctxm/releases/v<x.y.z>-rc.<n>.md`:
  - what changed, in the owner's terms, before and after;
  - an **acceptance checklist**: what to check, how, the expected result;
  - the important decisions and trade-offs, with their sources;
  - results: the checks, the final test, numbers the project tracks (size, speed).
- The owner approves → main tags `v<x.y.z>`. The owner asks for changes → fix items, then the next RC.
- Owner checks (a game's play sessions, any owner-judged requirement) happen at RC acceptance by default; earlier
  only where the plan has a reason (a lever clash, REQ-004).
- A user-facing changelog is the project's own file; the RC record feeds it.

### Timed by releases
- Dormant tests still untagged through two releases are deleted (replaces "two finished plans", REQ-004).
- Benchmarks run at the final test, report only.
- Verification tiers: the worker runs the minimal tier, the reviewer once per review; the full tier belongs to the
  milestone and final tests.

## Acceptance
- Given `agents-base` alone, when a plan is made, then it has no tester steps and no versions, and every item is
  merged after review.
- Given `release-planning`, when the owner approves a request set for a release, then the planner writes or extends
  `ctxm/plans/v<x.y>.md` with milestones, each ending in a milestone test.
- Given a second request set approved for a release in progress, when the planner runs, then items already started
  keep their names and the new set's milestones are added.
- Given a release whose scope is merged, when main finishes it, then the final test began with a scope review, the
  maintenance batch ran, and the RC record has the checklist, decisions and results.
- Given an RC the owner rejects with changes, when they are fixed, then the next RC is `-rc.<n+1>` with its own
  record.

## Out of scope
- ITIL records (REL, DEF, TSK, RFC): a template on top, once the owner's ITIL tool is done ("ITIL should be another
  template on top that would be done alter when I actually finish my itil tool").
- Publishing, packaging and distribution: the project's own scripts.
- Domain owner checks (play sessions): their templates; this one only says when they happen.

## Also changes
- **REQ-001 agents-base:** without this template a plan is items, one plan per request set
  (`ctxm/plans/REQ-nnn.md`); items may still be grouped into outcomes, but no group has a tester step. The tester
  role, the verification step and the inspector's caselist move here. Main reports a finished plan to the owner with
  a short summary.
- **REQ-003 agents-metawork:** the maintenance batch runs after a group (with this template: a milestone) when no
  item is in flight, and before every RC.
- **REQ-004 game-code:** links `release-planning`; the play-session handoff happens at RC acceptance unless a lever
  clash needs one earlier; the dormant cleanup is timed by releases.

## Amendment 2026-11-16: the role is `release-tester` (owner: "yes")
The tester role is named `release-tester` (`.claude/agents/release-tester.md`): the name shows that it comes with this
template, and it does not invite writing tests, which under the 80:20 rules it mostly tries and removes. "The tester"
in this request means `release-tester`.
