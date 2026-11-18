# Network security
A **trust boundary** is any place data or authority crosses between parties: a network request, a browser page,
another local process or user, an uploaded or fetched file, a remote or subscribed source, a path from outside.
Anything crossing one is hostile until checked.

## Inputs
1. Validate every outside input at the boundary before use: type, size, count, range, and the properties it may
   carry. Reject undeclared properties; cap request bodies.
2. The side that holds authority decides. Never trust a value, flag or role the other side sends. A remote party
   only proposes; a local, reviewed step accepts.
3. A refusal is explicit and leaks nothing: the right status or error kind, nothing written, no input echoed back.
   Fail closed.
4. Resolve every path from outside against its root: no `..`, no absolute paths, no symlink escapes; compare names
   case-insensitively.

## Servers
5. Listen on loopback only unless a requirement says otherwise; if the address cannot be bound, do not start. Check
   Host and Origin on every request; send no cross-origin permission headers; accept only the content types real
   clients send.
6. Authenticate every request. Tokens are random (at least 256 bits), new per start, revocable when long-lived,
   compared in constant time, sent in a header, never in a cookie, a URL query, process arguments or logs.
7. Served pages get no-store, no-sniff, no-frame and a strict content policy: no inline scripts, no third-party loads.

## Secrets and code
8. Secrets live in the OS keyring or the environment, never in stored data, templates, fixtures or the repository.
   A secret never reaches debug output, logs, errors or test snapshots.
9. Never send or accept the content of secret-bearing files (env files, keys, certificates): keep a denylist, compare
   case-insensitively. Scan content for secrets before it leaves the machine.
10. Anything that can run code (hooks, scripts, executables, environment loaders, tool and server configs, VCS hooks)
    is marked in every plan and diff, and runs only after a local person's review.
11. A write needs a reviewed plan bound to what was shown; if the target changed since, refuse and write nothing.
    Writes are all-or-nothing and limited to a named list of operations.

## Dependencies
12. A dependency is added only with the owner's approval, pinned and locked; its licence notices stay in step with
    the lock. The project's dependency audit runs at review; a known-vulnerable dependency blocks a merge.

## Verification
13. Every rule that protects a boundary has a test that sends the abuse case and expects the refusal, and that
    nothing was written. A boundary change without such a test is not done.
14. Abuse cases to try: foreign Host or Origin, missing or wrong token, wrong content type, oversize body, `..`,
    absolute and symlinked paths, case variants of denylisted names, a stale plan, a write without review, a secret in
    any output. A refusal of the wrong kind, or any write after a refusal, is a defect; the only test covering a
    refusal is never deleted.
