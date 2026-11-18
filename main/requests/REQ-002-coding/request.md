---
id: REQ-002
title: coding and its specializations - rust, cli, multi-component, network-security, godot, nix
status: approved
approved_by: owner, 2026-11-18 ("ok, all those templates are approved")
source: main/discussions/2026-11-10-agent-templates.md (2026-11-16)
depends_on: [REQ-001, REQ-003, REQ-005]
---
# REQ-002 coding and specializations

## Goal
"guidelines on how to actually write code [...] mostly readable, testable with minimized risk of having multiple
levels of focus in a single function, where something could be done as main purpose, but there would be secondary
effects [...] It also focused on having script/task centered workflow." Specializations sit on top: "this project
additionally is a cli tool written in rust, which is also multicomponent and is related to network logic, which
actually needs emphasis on security validation and verification". Filled from ctxm and the gamedev projects: "ok,
actually try to fill all others based on ctxm and gamedev projects".

## The stack
| Template | Links | Ships |
|---|---|---|
| `coding` | agents-metawork | `.claude/rules/clean-code.md` (22 rules), role sections, main section, outline |
| `rust` | coding | `.claude/rules/rust.md` (`**/*.rs`, cargo files), role sections, outline |
| `cli` | coding | `.claude/rules/cli.md`, role sections, outline |
| `multi-component` | coding | `.claude/rules/multi-component.md`, role sections, outline |
| `network-security` | coding | `.claude/rules/network-security.md`, role sections, main section, outline |
| `godot` | coding | `.claude/rules/godot.md` (`**/*.gd`, scenes), role sections, outline |
| `nix` | none | `.claude/rules/nix.md` and an outline only |
| `game-code` | release-planning, godot | game design only: levers, feel and play sessions, replays and probes, art |

## Requirements
- `coding` holds the generic test approach of REQ-004's classification: `behaviour:<name>` in place of `lever:`,
  `def:`, `rule:`, the four-question gate, dormant tests and their cleanup, failure history, tampering.
- `game-code` calls its behaviours levers and tags `lever:<name>`.
- A template ships a section for a role only if it links the template that defines that role: so `coding` links
  `agents-metawork`, `nix` ships no role sections, and only templates linking `release-planning` add to
  `release-tester` (other templates put what the release-tester tries into their rule files).

## Choices made while filling, for the owner
1. `coding` is not usable without the agents (it links `agents-metawork`); `nix` stays standalone.
2. Rust tests: a small inline `#[cfg(test)] mod tests` is allowed, moving to `<module>/tests.rs` past the file limit.
   ctxm's own rule is stricter (always the child file).
3. New, not found in the sources: the `boundary: yes` plan mark and a dependency audit at review
   (`network-security`); a removed or renamed contract field moves the major version (`multi-component`); "a value is
   named once" and "no abstraction for a single use" (`coding`, from the owner's LLM-habit list).
4. Script time budgets (5 minutes, stop and say which budget) sit in `nix`; the generic "every step is a script"
   in `coding`.

## Acceptance
- Given the ctxm stack (release-planning, rust, cli, multi-component, network-security, nix) applied to an empty
  project, then every role file has each section once, `coding` is included once, and no `{{ }}` is left.
- Given `game-code` applied, then the game sections hold only levers, feel, replays and art; Godot rules come from
  `godot`, test rules from `coding`.
- Given `nix` alone, then only `.claude/rules/nix.md` and its outline are written.

## Amendment 2026-11-17: dev shell and user-level tools
`nix` rule 1: every project command runs inside the dev shell, through the scripts; tools that manage the project
from outside (ctxm, Claude Code) are installed once per user, run from the host, and are not pinned by the flake.

## Amendment 2026-11-18: probes first, saved tests the exception
The owner: "previosuly we discussed that we want most of our tests to be special cases that are executed with helper
tools and not neccesarily saved" (restating 2026-11-10: "making testing tools and running custom scenarios on the fly
and only commiting regression test suite for 80:20"). The filled `coding` treated a worker's tests as saved candidates
filtered by tags; it now says:
- **clean-code rule 18:** most checking is a probe, a scenario run with the project's helper tools and not saved; a
  test is saved only for a nameable, plausible break.
- **Workers:** check a change with probes kept in the task workspace and listed in the submission (command, what it
  showed); save a test only for a named break. foundation-worker extends the helper tools within its scope;
  standard-worker reports a missing tool and never builds a second harness.
- **Planner:** an area whose probes need a missing helper tool gets a foundation item that builds it first.
- **Reviewer:** reruns the listed probes; a saved test that only repeats a probe with no named break stays untagged.
- **Outline:** a "Helper tools and probes" topic; the Commands topic lists the helper tools.
Unchanged: problem-solver saves a regression test per defect; release-tester commits only checks for defects it found;
game-code's replays and probes are the game's form of these.
