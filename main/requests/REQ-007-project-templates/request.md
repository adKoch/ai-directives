---
id: REQ-007
title: project templates, one per kind of project, made of links only
status: approved
approved_by: owner, 2026-11-18 ("ok, all those templates are approved")
source: main/discussions/2026-11-10-agent-templates.md (2026-11-17)
depends_on: [REQ-002, REQ-005, REQ-006]
---
# REQ-007 project templates

A project applies one template; a project template only links the layers it needs and ships no files of its own.

| Template | Links | Not yet covered |
|---|---|---|
| `ctxm-dev` | release-planning, rust, cli, multi-component, network-security, nix | the Svelte web UI |
| `godot-game-dev` | game-code (release-planning, godot), nix | Python check tooling, game art |

## Acceptance (checked on scratch projects, 2026-11-17)
- Each applies cleanly; no `{{ }}` left; no role file has a section twice; every role has one Proposals section; the
  ctxm guard passes on the fresh project.
