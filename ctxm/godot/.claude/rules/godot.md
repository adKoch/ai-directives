---
paths: ["**/*.gd", "**/*.tscn", "**/*.tres", "**/project.godot", "**/gdlintrc", "**/.gdformatrc"]
---
# Godot 4, GDScript, GUT
On top of `.claude/rules/clean-code.md`.

## Core and view
1. Game state and rules live in classes extending `RefCounted` or `Resource` that never reach the scene tree, input,
   IO or the wall clock. Scenes, rendering, camera, audio and input are adapters around that core.
2. The core advances in fixed steps and never reads frame delta or the clock. All randomness comes from a seeded
   generator the run owns (`RandomNumberGenerator.new()` is randomly seeded: seed it).
3. Input enters the core as commands per step, not device events. A recording is a seed and commands; a digest of the
   core's state proves a replay.
4. Hot loops: data in packed arrays, not one node or object per entity; no call per entity per step. Measure before
   moving a loop to C# or GDExtension.

## GDScript
5. Static types everywhere, typed arrays and return types. No string node paths or long `get_node` chains: use
   `@export` or typed `@onready` references to the node's own children.
6. Signals up, calls down; one mechanism per job. Autoloads hold services, never game state.
7. Physics code only in `_physics_process`; core stepping is never in `_process`.
8. Traps: packed arrays alias (`.duplicate()` for a snapshot); vectors are float32 while `float` is double (compare
   with a tolerance); class names are not constants (`preload()` the script).
9. Lint and format with gdtoolkit, configured beside `project.godot` (3 arguments, 300 lines); format before lint.
   Restructure instead of `gdlint: ignore`. Third-party `addons/` is exempt.

## Tests and runs
10. Tests are GUT, headless, `test_*.gd` extending `GutTest`. Keep a post-run hook that fails a run where a script did
    not compile or nothing ran. Build fixtures in `before_each`, restore statics in `after_each`, free nodes with
    `add_child_autofree` or `autofree`. Assert expected errors with `assert_push_error`.
11. Every engine run is headless and under a timeout: after a script error Godot may hang. A fresh worktree or clone
    is imported before anything runs.
12. Commit the `.uid` files next to new scripts; `.godot/` is never committed.
13. A scene file, and the project file (autoloads, input map), has one editing item at a time.
14. Screenshots render headlessly, are never stored in the repository, and are judged at low resolution too.
