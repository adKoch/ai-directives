---
id: REQ-006
title: ctxm, using ctxm in a project - read-only managed files, a skill, and a guard hook
status: approved
approved_by: owner, 2026-11-18 ("ok, all those templates are approved")
source: main/discussions/2026-11-10-agent-templates.md (2026-11-16)
depends_on: []
---
# REQ-006 ctxm

## Goal
"we actually need also ctxm template for the actual ctxm usage". Agents know which files ctxm manages, never change
them, and learn at once when anything (an agent, a script, ctxm itself) breaks the setup.

## Requirements
- `CLAUDE.md` gains a `## ctxm` section: managed files are read-only, `.ctxm/` is ctxm's own, only main runs ctxm
  commands that write, always after showing the owner the plan. `agents-base` links `ctxm` and drops its own line.
- A skill, `.claude/skills/ctxm/SKILL.md`: reading (`status`, `diff`, `show`), writing (dry run → owner's yes on the
  exact plan → `--yes <identifier>`), conflicts (`resolve`), what to do when the guard reports.
- A guard hook (`.claude/hooks/ctxm-guard.sh`, wired in `.claude/settings.json`):
  - before Edit, Write, MultiEdit and NotebookEdit: refuses a managed file that is not `conflicted`, and anything in
    `.ctxm/`;
  - after Bash and every edit tool: runs `ctxm status`; reports a `modified`, `missing` or `unreadable` managed file,
    a failing `ctxm status`, or a missing `ctxm`, once per new finding, and goes quiet when the setup is clean again.
- The hook never blocks a project without `.ctxm/`, and needs no `jq`.

## Acceptance (checked on a scratch project, 2026-11-16)
- An edit to a managed file is refused with the template's name; an edit elsewhere passes; `.ctxm/` is refused.
- A shell edit to a managed file is reported after the call, once; restoring it clears the report.
- A broken `.ctxm/` state and a missing `ctxm` are each reported once.
- Ten checks take about 0.1 s in all.
- `ctxm apply` marks the hook script and the settings as code-running.

## Noted for ctxm itself
There is no command that puts a managed file back as ctxm wrote it; the skill tells agents to undo by hand with
`ctxm diff`. A `ctxm restore <file>` would make the guard's advice one step.

## Amendment 2026-11-17
The skill says ctxm is a user-level tool, run from the host and not pinned by the project's flake.
