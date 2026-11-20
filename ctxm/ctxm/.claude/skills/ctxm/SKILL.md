---
name: ctxm
description: How to use ctxm in this project - reading which files it manages, which templates and which project-specific parts write them, making a draft of a change and showing it before anything is written, applying, updating or taking out templates with the owner's approval, settling conflicts, and what to do when the ctxm guard hook reports a managed file changed. Use whenever work touches a ctxm-managed file, a template, a draft, `.ctxm/`, or a ctxm command.
---
# Using ctxm

ctxm applies templates from a library to this project and keeps their history in `.ctxm/`. A project can use several
templates, combined in the order they were added, and its **own layer**: project-specific files and sections applied
last, on top of every template. The files ctxm wrote are **managed**: read-only for agents. `ctxm status` lists them.

## Setup
ctxm is installed once per user and runs from the host, not from the project's dev shell; the project's flake does not
pin it. When it is missing from PATH, the guard reports it once. This skill describes ctxm 0.7 or later.

## Reading (any role)
- `ctxm status`: the project's templates in order, then each managed file with its state: `unchanged`, `modified`
  (changed since ctxm wrote it), `missing`, `conflicted` (an update left conflict markers) or `unreadable`, and which
  templates write it ("the project's own" for the own layer). `--porcelain` gives tab-separated lines for scripts:
  `file<TAB>path<TAB>state<TAB>first writer<TAB>other writers…`, where `.` is the own layer.
- `ctxm diff [file]`: what changed since ctxm wrote the file. `--incoming` shows what an update would change;
  `--original` shows the file as it was before the first apply.
- `ctxm show <template>`: what a template would apply, entry by entry, with the template each entry comes from.
- `ctxm draft show [file]`: the files a draft would write, each line marked by where it comes from (a template, the
  project's own, or already in the file), and which files would no longer be managed. `--porcelain` for scripts;
  `--out <dir>` writes the files to a folder outside the project.

## Changing the setup (main only, each time with the owner)
Prefer a **draft**: it is planned exactly as applying it would be, and nothing outside `.ctxm/` is written until it is
applied.
1. `ctxm draft add <template>` / `ctxm draft remove <template>` change the templates; `ctxm draft add-file <file>
   --target <path>` / `ctxm draft remove-file <target>` change the project's own layer. A draft starts from the
   project's current setup and is the whole setup: what it does not hold leaves the project.
2. Show the owner `ctxm draft show` (and the files that matter, `ctxm draft show <file>`), the code-running marks first.
3. `ctxm apply --dry-run` prints the plan and its identifier; on the owner's clear yes, `ctxm apply --yes <identifier>`.
   `ctxm draft drop` discards a draft.

Direct commands, with the same `--dry-run`, owner's yes, `--yes <identifier>` steps:
- `ctxm apply <template>` adds one template; `ctxm update` brings every template up to date together, keeping local
  edits and marking conflicts.
- `ctxm unapply --template <name>` takes one template out and keeps the others; `ctxm unapply <file>` gives one file
  back; plain `ctxm unapply` takes everything out (the project's own parts stay as plain text).
- A template taken out always leaves: a file of it the owner edited or deleted stays as it is and is no longer managed.
If anything changed since the dry run, `--yes` refuses and writes nothing: start again at the dry run.
Exit codes: `0` done, `1` error, `2` done but conflicts are left, `3` aborted.

## Conflicts
An update that cannot merge a file writes conflict markers into it and marks it `conflicted`. Editing a conflicted
file is allowed: settle the markers with the owner's choice, then run `ctxm resolve <file>`.

## When the guard reports a change
The ctxm guard hook runs after every tool call. When it reports a managed file as `modified` or `missing`:
1. Stop. Do not continue the task on top of it.
2. `ctxm diff <file>` shows the change. Undo it: put the file back exactly as ctxm wrote it.
3. If the change was needed, tell main: a template's part belongs in the template; a project-specific part belongs in
   the project's own layer, through a draft. Main takes either to the owner.
When the guard reports that `ctxm status` itself failed, stop and tell main: the project's ctxm state is broken.

## Never
- Edit a managed file that is not `conflicted`, or anything in `.ctxm/`.
- Run `--yes` without the owner's yes on that exact plan.
- Change ignore rules or settings to hide a managed file from ctxm.
