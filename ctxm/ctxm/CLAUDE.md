## ctxm
- Files ctxm manages (`ctxm status`) are read-only for every agent; a change to one is a change to its template, which
  goes to the owner. A hook refuses edits to them and reports at once when any of them changed.
- `.ctxm/` is ctxm's own state: never touch it. `ctxm/` is the agents' folder.
- Only main runs ctxm commands that write (`apply`, `update`, `unapply`, `resolve`), always after showing the owner
  the plan; every other role only reads (`status`, `diff`). How: the `ctxm` skill.
