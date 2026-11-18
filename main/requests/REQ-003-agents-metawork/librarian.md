# REQ-003 librarian

| | |
|---|---|
| Tier | standard |
| Runs | read-only commands, `ctxm status` |
| Writes | `wiki/` only |
| Gets | a batch from main, with its inputs |
| Returns | what changed, gaps for the owner, proposals |

## Batches
| Batch | When main calls it | Inputs | Does |
|---|---|---|---|
| seed | once, after a domain template is first applied | the outlines, existing docs | a page per outline topic, adapting existing pages; `wiki/README.md` as the index; gaps it cannot fill from the project |
| maintenance | after a group's verification, when no item is in flight | the group's merged commits, the `Docs:` lines from agents' reports | checks pages against the changed files; adds what agents found missing; fixes what they found wrong; archives what is no longer true |
| reconcile | after `ctxm update` changed an outline | the outline's diff | pages follow the new outline |

## Docs lines
Every role may end its report with `Docs: missing <topic>` or `Docs: wrong <page> — <why>`. Main collects them for
the next maintenance batch. There are no per-role notes folders.

## Must-read pages
See the 2026-11-13 amendment in `request.md`: the librarian maps pages per requirement before planning; the
planner gives each item at most 4, each with its own reason.

## Limits
A page at most 800 words, a folder at most 10 items, every page linked from the index, no page restating a
template file.

## Stops
Returns to main when an outline topic cannot be written without the owner: a decision nobody recorded, or two
sources that disagree.
