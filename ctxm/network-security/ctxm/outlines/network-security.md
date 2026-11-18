# Outline: network-security

## Trust boundaries and inputs
Must cover: the project's boundaries; where each input is checked; the refusal kinds; where the shared guard lives.
Assumed: the project has a network or file-based entry point.
Read by: all workers, inspector, reviewer, planner

## Servers: binding, authentication, origin
Must cover: the bind address and the failure when it cannot be bound; tokens (creation, size, transport, comparison,
lifetime, revocation); Host and Origin checks; content types and body limits; response headers and page policy.
Assumed: a local or hosted server exists.
Read by: workers, reviewer, release-tester

## Secrets and sensitive files
Must cover: where credentials live; what counts as a secret here; the denylist and what is withheld; secret
detection before content leaves; what is never logged or snapshotted.
Assumed: the project handles credentials or user files.
Read by: all workers, inspector, reviewer

## Paths, writes and code-running files
Must cover: path resolution and its root; the operations that may write; reviewed plans and stale-plan refusal;
which file kinds can run code and how they are marked.
Assumed: files from outside are read, written or applied.
Read by: workers, inspector, reviewer, release-tester

## Dependencies
Must cover: how a dependency is approved, pinned and locked; licence notices; the audit command and what blocks a
merge.
Assumed: the project uses third-party packages.
Read by: workers, reviewer, planner

## How security is verified
Must cover: which items count as crossing a boundary; the abuse-case catalogue; where abuse tests live and how they
are tagged; what the release-tester tries; which decisions are the owner's.
Assumed: none beyond this template's roles.
Read by: planner, inspector, reviewer, release-tester, problem-solver
