---
id: REQ-004
title: game-code, the roster's stance for building a Godot game, and its outline
status: approved
approved_by: owner, 2026-11-13 ("approved, but lets not modify any projects")
source: main/discussions/2026-11-10-agent-templates.md
depends_on: [REQ-001, REQ-003]
---
# REQ-004 game-code

## Goal
A template for building a Godot game with the base roster: fast in wall-clock time, few tests, readable code, and
feel tuned by the owner where it matters. It stays high level: "What if we approached it from higher level and
leave details to library docs". The details are the project's docs, which the librarian writes from this
template's outline.

## The set
| File | What it fixes |
|---|---|
| `stance.md` | the short sections each role file gains |
| `outline.md` | the librarian's outline: topics the project's docs must cover |

## Requirements
- `game-code` links `agents-base` and `agents-metawork`; applying it gives all three.
- It adds stance sections to the role files and main's `CLAUDE.md` section, and ships `main/outlines/game-code.md`.
  Nothing else: no scripts, no docs, no project names, paths or commands.
- Testing follows the agreed model (REQ-002's draft): few tests, reviewer-assigned tags, dormant untagged tests,
  failure history, test-tampering checks. REQ-002 later pulls the parts that are not about games into `coding`.
- Feel: a request set can mark a requirement as feel; the planner ends that group with the owner's play session.

## Acceptance
- Given a scratch project, when `ctxm apply game-code` runs, then the role files hold base and game sections, and
  `main/outlines/game-code.md` exists.
- Given sling-defender (a copy), when `--dry-run` runs, then its own `CLAUDE.md` sections stay.
- Given the template's files, when the owner reads them, then no project name, path or command appears.
- Given a sling-defender copy with the template applied, when the librarian runs its seed batch, then every outline
  topic has a page or a gap listed for the owner.
- Given a request set with a feel requirement, when the planner plans it, then its group ends with a play session.

## Out of scope
- Moving sling-defender onto the template (old agents, `agents/leader/`, its 220 tests): a separate request, after
  v0.6 is accepted.
- The test-history and tagging scripts: the project's own, described by its docs.
- Art: `game-art`.

## Assumed
The current project is sling-defender (not yet confirmed by the owner).

## Amendment 2026-11-13: paths under ctxm/ (REQ-001 amendment)
The outline is `ctxm/outlines/game-code.md`.

## Amendment 2026-11-13: levers, play sessions, tags (owner: "Yes, apply it")
"we should try to stay away from declaring a list of tags up top as there is potentially big changes coming to a game
with much more new turns". The rules are in `classification.md`; in short:
- Domains come from code folders; interaction levers come from approved request sets, proposed by the librarian's
  doc map, kept in the glossary.
- One play session at the end of the plan; two feel requirements on one lever never share one ("a feel session
  handoff at the end or earlier if there would be multiple things clashing in single interaction lever").
- A test carries one tag naming what it protects (`lever:`, `def:`, `rule:`), given by the reviewer behind a
  four-question gate (80:20); when it runs comes from its layer folder. Untagged tests through two finished plans are
  deleted.
- Acceptance: given an applied template, then the reviewer's file has the three tags and the gate, the planner's has
  play sessions by lever, the librarian's has the Levers part of the doc map, and the outline has a Domains and
  levers topic.

## Amendment 2026-11-16: release-planning (REQ-005, owner: "Approve")
Changed as REQ-005 "Also changes" says; that section supersedes this request where they differ.
