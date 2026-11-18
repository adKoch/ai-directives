# REQ-001 flow

## Request → plan
1. The owner and main discuss; main records it in its library.
2. Main writes a **request set**: goal, requirements, acceptance, out of scope, notes on feel or risk. Long is fine.
3. The owner approves the request set. That is the only approval before implementation.
4. Main gives it to the planner and runs the returned plan.

## Plan shape
Groups of plan items. A group is something that can be demoed and ends in one verification step.

```
## Group A: inventory                         verify: V-A
A1 foundation-worker   stack split/merge rules        scope: src/inventory/**
A2 inspector ∥ reviewer  on A1                          (caselist: yes)
A3 problem-solver      A2 findings (skipped if none)
A4 standard-worker     drag-to-split UI, per A1's extension note   after A3
A5 inspector ∥ reviewer  on A4
V-A tester             group A requirements (+ caselist from A2)
```

Each item: id, role, what and why (never how), scope, depends on, done when.

## Planner guide (contents to write)
- tier: foundation when an item sets a new pattern, standard when it follows one;
- at most 3 workers at once; scopes of concurrent items never overlap;
- group size: one demoable outcome, one verification step;
- when to skip a stage (a trivial change may skip the inspector);
- when to ask for a caselist: complex items, or areas with past defects or failures;
- risk inputs: failure history, defects, main's notes;
- the plan file format, so main can run it without judgement.

## Fixes and rounds
- Inspector and reviewer run in parallel; main joins their reports.
- All findings go to the problem-solver, which runs the minimal checks, then only the finder looks again, at the fix.
- 3 rounds per item; at the limit main goes to the owner.

## Exceptions
- A worker or reviewer that hits a case the request set did not foresee stops and returns to main.
- Main decides within the request set, asks the owner, or sends the planner to replan.
