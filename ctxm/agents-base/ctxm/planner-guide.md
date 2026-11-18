# Planner guide

## Plan format
Saved by main as `ctxm/plans/REQ-nnn.md`, one plan per request set. Groups of items; a group is done when its items
are merged.

```
## Group A: <demoable outcome>
A1 foundation-worker     <what, why>              scope: <paths>
A2 inspector ∥ reviewer  on A1
A3 problem-solver        A2 findings (skipped if none)
A4 standard-worker       <what, why>, per A1's extension note   after: A3   scope: <paths>
A5 inspector ∥ reviewer  on A4
```

Each work item: id, role, what and why (never how), scope, `after:` dependencies, done when.

## Choosing the role
- `foundation-worker` when the item sets a pattern others will follow, or nothing similar exists.
- `standard-worker` when an existing pattern or extension note covers it.
- Never plan `problem-solver` up front; main sends it when something goes wrong.

## Parallelism
- At most 3 work items at once.
- Scopes of concurrent items never overlap, except shared docs, where a merge keeps both sides.
- Order follows real dependencies only: start everything that does not need another item's result.

## Groups
A group is one outcome the owner could see demoed. Order groups so each one shows something.

## Skipping stages
- A trivial change may skip the inspector; the project's domain sections say what counts as trivial.
- Never skip the reviewer.

## Size
An item fits one worker session. Split larger ones along files.

## Stop and ask
Return a question instead of a plan when the request set is ambiguous, requirements conflict, or a choice would be
expensive to reverse.

## Task names
Every item gets a unique task name, `<REQ>-<item>-<slug>` (e.g. `REQ-004-A1-stack-split`), used for its branch and
its workspace. A replan keeps the names of items already started and never reuses a name.
