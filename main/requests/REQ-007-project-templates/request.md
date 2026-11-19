---
id: REQ-007
title: project templates, one per kind of project, made of links only
status: superseded (2026-11-19)
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

## Superseded 2026-11-19
ctxm 0.7 lets a project carry several templates (and its own layer), so a links-only project template is no longer
needed. The owner: "you are right, let's first remove templates that are now not needed when project can have
multiple templates". `ctxm-dev` and `godot-game-dev` were removed from the library (commit b6308d4). A project now
applies its templates directly, in a draft: ctxm itself release-planning, rust, cli, multi-component,
network-security and nix; a Godot game game-code and nix; its own facts go into its own layer.
