## ctxm
- Files ctxm manages (`ctxm status`) are read-only for every agent. A hook refuses edits to them and reports at once
  when any of them changed.
- A managed file is written by the project's templates, in the order they were added, and by the project's own layer
  (its project-specific files and sections, applied last). A change to a template's part goes to the template; a
  change to the project's own part goes into a draft (`ctxm draft add-file`). Both go to the owner.
- `.ctxm/` is ctxm's own state: never touch it. `ctxm/` is the agents' folder.
- Only main runs ctxm commands that write (`apply`, `update`, `unapply`, `resolve`, `draft`), always after showing the
  owner the plan or the draft; every other role only reads (`status`, `diff`, `draft show`). How: the `ctxm` skill.
