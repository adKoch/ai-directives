---
name: ctxm
description: How to use ctxm in this project - reading which files it manages and how they changed, applying or updating a template with the owner's approval, settling conflicts, and what to do when the ctxm guard hook reports a managed file changed. Use whenever work touches a ctxm-managed file, a template, `.ctxm/`, or a ctxm command.
---
# Using ctxm

ctxm applies templates from a library to this project and keeps their history in `.ctxm/`. The files it wrote are
**managed**: read-only for agents. `ctxm status` lists them.

## Setup
ctxm is installed once per user and runs from the host, not from the project's dev shell; the project's flake does not
pin it. When it is missing from PATH, the guard reports it once.

## Reading (any role)
- `ctxm status`: each managed file and its state: `unchanged`, `modified` (changed since ctxm wrote it), `missing`,
  `conflicted` (an update left conflict markers) or `unreadable`. `--porcelain` gives tab-separated lines for scripts:
  `file<TAB>path<TAB>state<TAB>template`.
- `ctxm diff [file]`: what changed since ctxm wrote the file. `--incoming` shows what an update would change;
  `--original` shows the file as it was before the first apply.
- `ctxm show <template>`: what a template would apply, entry by entry, with the template each entry comes from.

## Writing (main only, each time with the owner)
1. Run the command with `--dry-run`: it prints the plan, marks changes that can run code, and ends with a plan
   identifier. Nothing is written.
2. Show the owner the plan verbatim, the code-running marks first. Wait for a clear yes.
3. Run it again with `--yes <identifier>`. If anything changed since the dry run, ctxm refuses and writes nothing:
   start again at 1.

Commands: `apply <template>`, `update` (keeps local edits, marks conflicts), `unapply` (gives the original files back).
Exit codes: `0` done, `1` error, `2` done but conflicts are left, `3` aborted.

## Conflicts
An update that cannot merge a file writes conflict markers into it and marks it `conflicted`. Editing a conflicted
file is allowed: settle the markers with the owner's choice, then run `ctxm resolve <file>`.

## When the guard reports a change
The ctxm guard hook runs after every tool call. When it reports a managed file as `modified` or `missing`:
1. Stop. Do not continue the task on top of it.
2. `ctxm diff <file>` shows the change. Undo it: put the file back exactly as ctxm wrote it.
3. If the change was needed, it belongs in the template: describe it to main, who takes it to the owner.
When the guard reports that `ctxm status` itself failed, stop and tell main: the project's ctxm state is broken.

## Never
- Edit a managed file that is not `conflicted`, or anything in `.ctxm/`.
- Run `--yes` without the owner's yes on that exact plan.
- Change ignore rules or settings to hide a managed file from ctxm.
