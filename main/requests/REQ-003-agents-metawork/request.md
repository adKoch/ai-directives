---
id: REQ-003
title: agents-metawork, the librarian who keeps a project's docs from template outlines
status: approved
approved_by: owner, 2026-11-13 ("approved, but lets not modify any projects")
source: main/discussions/2026-11-10-agent-templates.md (2026-11-12 – 2026-11-13)
depends_on: [REQ-001]
---
# REQ-003 agents-metawork

## Goal
Templates stay read-only in a project and carry only short stances and outlines; the project's own docs, written in
its own words, are kept by a librarian. The owner: "templates should be assumed read-only by project. [...] we
should have this outline or assumptions be given to librarian".

## The set
| File | What it fixes |
|---|---|
| `librarian.md` | the role, its batches, inputs and outputs |
| `outlines.md` | what an outline is, where it lives, how the librarian uses it |

## Requirements
- A file ctxm manages is read-only for every agent. A change to it is a change to the template.
- A domain template ships one outline, `main/outlines/<template>.md`: the topics the project's docs must cover and
  what is assumed about each.
- The librarian writes and keeps the project's docs (`wiki/`) so that every topic of every applied outline is covered
  in the project's own words, within the wiki's limits.
- The librarian is domain-neutral: it names no code, tests, game or art; outlines bring the domain.
- Main's section in `CLAUDE.md` gains when to call the librarian.

## Acceptance
- Given a project with an outline and no wiki, when the librarian runs its seed batch, then every outline topic has
  a page or a listed gap for the owner, and `wiki/README.md` indexes the pages.
- Given a project with existing docs, when the seed batch runs, then existing pages are kept and adapted, not
  replaced, and nothing project-specific is written into a template file.
- Given an agent that changed a ctxm-managed file, when the reviewer runs, then `ctxm status` shows it `modified`
  and the reviewer returns a blocking finding.
- Given an updated outline (`ctxm update`), when the librarian runs a reconcile batch, then pages follow the new
  outline and the report lists what changed.
- Given a page over 800 words or a folder over 10 items, when a maintenance batch runs, then it is split.

## Out of scope
- Records beyond the wiki (defects, releases, ITSM tickets): a later request, once it is clear which project uses
  which tracker.
- Any domain outline (REQ-004 brings the first).

## Also changes REQ-001 (still a draft)
The reviewer's checks include `ctxm status`: a `modified` managed file is a blocking finding.

## Amendment 2026-11-13 (owner: "Yes, amend")
- Pages may hold up to 800 words: "some subjects were tough to encompass in that many words."
- **Doc map before planning.** Main sends each drafted request set to the librarian, so the map is ready by the
  owner's approval. The map is a report, not a list ("a whole report with also some context on pages"): per
  requirement, each relevant page with what it says, how current it is and when it matters; knowledge about the
  existing project that has no page (the librarian writes it now); new spaces the work will create, with pointers.
- The planner reads the map instead of the wiki, gives each item at most 4 pages, each with its own comment on why
  and when this item needs it ("a comment on why/when they might be relevant made from the context by planner"),
  and puts new spaces into the items' *done when*.
- The maintenance batch also reads the group's task folders (`local-tmp/`, REQ-001 amendment) for lasting
  knowledge, before main deletes them.
- Acceptance: given a drafted request set, when the librarian runs its map batch, then every requirement has its
  pages with context, the missing pages are written, and the new spaces are listed.

## Amendment 2026-11-13: paths under ctxm/ (REQ-001 amendment)
- The wiki is `ctxm/wiki/`, outlines `ctxm/outlines/`, doc maps `ctxm/requests/<REQ>/doc-map.md`, task folders
  `ctxm/tmp/`. "This also means wiki I think?"
- The librarian is a subsection under main's `## Roles`, not a section of its own; it adds its folders to
  `ctxm/README.md`.

## Amendment 2026-11-16: release-planning (REQ-005, owner: "Approve")
Changed as REQ-005 "Also changes" says; that section supersedes this request where they differ.
