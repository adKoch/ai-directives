# Outline: rust

## Workspace and toolchain
Must cover: the members and what each owns; the scripts that build, lint, format and test; the lint configuration and
why each limit is set.
Assumed: a cargo workspace.
Read by: main, planner, workers, reviewer

## Error types
Must cover: the error enums per crate, how errors are printed, escaping of untrusted text.
Assumed: none.
Read by: workers, inspector, reviewer

## Dependencies
Must cover: the accepted crates with purpose and enabled features, what counts as a heavy dependency, who decides,
the allowed licences.
Assumed: crates come from crates.io.
Read by: planner, workers, reviewer

## Test layout
Must cover: where unit, integration, golden and end-to-end tests live; shared doubles and fixtures; how a test's
domain is read from its path.
Assumed: none.
Read by: workers, inspector, reviewer, release-tester
