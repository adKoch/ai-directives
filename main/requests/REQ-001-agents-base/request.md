---
id: REQ-001
title: agents-base, the shared agent roster as a ctxm template
status: approved
approved_by: owner, 2026-11-13 ("approved, but lets not modify any projects")
source: main/discussions/2026-11-10-agent-templates.md
---
# REQ-001 agents-base

## Goal
A ctxm template that gives any project a main session, a planner and six subagents with fixed jobs, so the owner
approves a request set and the implementation then runs hands-off: fast in wall-clock time, readable code, few tests.
Domain layers (`coding`, then `game-code`; `game-art`) link this one and add their sections; they are separate requests.

## The set
| File | What it fixes |
|---|---|
| `roles.md` | each role: model tier, what it may run and write, its input and output |
| `flow.md` | request → plan → stages → verification groups; fixes, exceptions, round limits |
| (moved) | tests and code rules are REQ-002 `coding`, a separate layer |
| `template.md` | what the ctxm template contains and how it is applied |

## Acceptance
- Given an empty project, when `ctxm apply agents-base` runs with the model variables, then the project has main's
  section in `CLAUDE.md`, the seven role files, the planner guide and main's library README.
- Given a project with its own `CLAUDE.md` and agents, when `--dry-run` runs, then its own sections stay and the
  base sections are added beside them.
- Given a role file, when the owner reads it, then it names no project, domain or model, only a tier.
- Given the inspector, then its tool list has no command, edit or write tool.
- Given the reviewer, then its tool list has no edit or write tool.
- Given any base file, when the owner reads it, then it mentions no code, tests or tags: those come from domain
  layers (`coding`, `game-art`).

## Out of scope
- Code and tests: the `coding` layer, REQ-002, after this one is approved. Godot and art: domain layers.
- The librarian, wiki and records layout: `agents-metawork`, a later request.
- A Codex variant (no Fable there); only the tier variables keep it possible.
- Changing ctxm itself. Gaps found while dogfooding go to ctxm's own records.

## Amendment 2026-11-13 (owner: "Yes, amend")
Unique task names and private task workspaces: "we should have unique task names and have some dedicated directory
like <project>/local-tmp/<task-name> which could be freely used by agents working on only their own given task".
- Every plan item is named `<REQ>-<item>-<slug>` (e.g. `REQ-004-A1-stack-split`); a replan never reuses a name.
- Each task has `<project>/local-tmp/<task-name>/` in the main checkout (not the worktree), ignored by git. Every agent
  on that task may use it freely; no agent writes temporary files anywhere else.
- Main deletes a group's task folders after the group is verified (with `agents-metawork`: after the librarian's
  maintenance batch has read them).
- Acceptance: given an applied template, then `.gitignore` holds `local-tmp/` and every role file names the
  workspace by the project's absolute path.

## Amendment 2026-11-13: one folder for the agents' files
"I think we should have a dedicated directory for all this additional methodology stuff ... read-only for outside
interference by e.g. user(me) by assumption"; named "ctxm ... without .*, so we have both .ctxm and ctxm".
Supersedes the paths above.
- Everything the agents keep lives in `<project>/ctxm/`: `discussions/`, `requests/`, `plans/`, `planner-guide.md`,
  `README.md` (the folder's map) and `tmp/<task-name>/` (was `local-tmp/`). `CLAUDE.md` and `.claude/agents/` stay
  where Claude Code loads them; `.ctxm/` stays ctxm's own.
- Agents own `ctxm/`; the owner reads it and changes it only by telling main, who records their words.
- Roles in `CLAUDE.md` are one subsection each ("let's switch roles to subsections instead of table"), so a layered
  template adds its roles under the same heading.
- Acceptance: given an applied template, then `.gitignore` holds `ctxm/tmp/`, `ctxm/README.md` lists every folder,
  and no role file names a path outside `ctxm/` for the agents' files.

## Amendment 2026-11-16: release-planning (REQ-005, owner: "Approve")
Changed as REQ-005 "Also changes" says; that section supersedes this request where they differ.

## Amendment 2026-11-17: merging, resume point, proposals (owner: "lets do it")
- **Branches and merging:** each item on a branch named after its task, cut from `main`, in its own worktree; commits
  say `<task-name>: <what changed>`. After review PASS with nothing blocking from the inspector, main merges, runs the
  minimal check on `main`, pushes if there is a remote, removes the worktree and branch. A conflict or a failing check
  on `main` goes to `problem-solver`, and nothing else starts in that area until `main` passes.
- **Resume point:** main keeps `ctxm/main/progress.md` current and reads it first in a new session.
- **Proposals:** every role ends a report with `Proposed: <what, why>` for work outside its item and never does it;
  main saves them in `ctxm/proposals/` and sorts them when a group is done (a behaviour-neutral fix inside an approved
  set → `planner`; anything else → the owner).
