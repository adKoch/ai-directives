## Plan format
With releases there is one plan per release instead, `ctxm/plans/v<x.y>.md`: every request set the owner assigns to
the release. A set approved later joins it as further milestones; replan only what has not started. Each group is a
milestone and ends in the release-tester's milestone test:

```
## Milestone 1: <demoable outcome>                 test: T-1
Demo: <what the owner will see, as a short list>
1A foundation-worker     <what, why>              scope: <paths>
1B inspector ∥ reviewer  on 1A                    caselist: yes
T-1 release-tester       requirements <ids> (+ cases from 1B)
```

The last step of every plan is `final test`, then the RC.

## Groups
With releases, a group is done when its milestone test passes. No other verification is planned between items.

## Caselists
Ask the inspector for one (`caselist: yes`) when an item is complex, or its area had defects or repeated failures.

## Task names
In a release plan the planner's run is `v<x.y>-plan`; items keep `<REQ>-<item>-<slug>`, the release-tester's runs are
`v<x.y>-T-<n>` and `v<x.y>-final`.
