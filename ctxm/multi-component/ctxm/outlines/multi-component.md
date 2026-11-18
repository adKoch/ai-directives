# Outline: multi-component

## Architecture and dependency direction
Must cover: the components and what each owns, the ports and their adapters, the allowed dependency edges, where
hosted and local differ.
Assumed: hexagonal architecture.
Read by: main, planner, foundation-worker, inspector, reviewer

## The contract
Must cover: where the document is, how it is validated, how operations map to core functions and commands, the
versioning policy.
Assumed: none.
Read by: planner, workers, reviewer, inspector

## Shared vocabulary
Must cover: every fixed word that crosses a boundary, where it is defined, every place that changes when one is added.
Assumed: none.
Read by: workers, inspector

## Component tests
Must cover: the port doubles, contract tests, client stubs, the end-to-end member and its fixtures, which tier runs
each.
Assumed: none.
Read by: workers, reviewer, release-tester
