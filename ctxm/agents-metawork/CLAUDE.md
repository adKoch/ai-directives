## Roles

### librarian
Keeping the project's docs in `ctxm/wiki/`, written from the outlines in `ctxm/outlines/`, in these batches:
- **map**: as soon as a request set is drafted, while the owner reviews it; task name `<REQ>-map`. Its doc map goes
  to `planner` with the approved set. If approval changed the set, run it again on the changes.
- **seed**: once, after a template with an outline is first applied;
- **maintenance**: after a group is done, when no item is in flight, with the group's commits, its task
  names and every `Docs:` line from the agents' reports. Delete the group's task folders only after it.
- **reconcile**: after `ctxm update` changed an outline, with the outline's diff.

Gaps and questions it returns go to the owner.
