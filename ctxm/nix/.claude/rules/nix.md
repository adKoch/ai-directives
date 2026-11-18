# A Nix flake as the only toolchain

1. Every tool that builds, lints, tests or runs the project comes from `flake.nix`, pinned by `flake.lock`. Nothing is
   installed on the host, and no doc or record calls a host tool.
   Every project command runs inside the dev shell, through the project's scripts. The only exceptions are tools that
   manage the project from outside (ctxm, Claude Code): they are installed once per user, run from the host, and the
   flake does not pin them.
2. Pin a nixpkgs release channel, not unstable. Inputs that are not flakes are pinned in `inputs` too, with the
   version matched to the tool that loads it, and a comment saying how.
3. Update tools on purpose: `nix flake update` in a change of its own, then run every check. A commit that edits
   `flake.nix` carries its `flake.lock`. A new tool or a version bump is the owner's decision.
4. Nix sees only files tracked by git: `git add` a new file before a step that needs it.
5. Every repeatable step is a script in `scripts/`; what cannot be scripted is documented in `docs/`. Agents and the
   owner use the same entry points.
6. Every script re-enters the dev shell unless a variable the flake sets says it is already inside, so it works the
   same from a plain shell and from `nix develop`.
7. Scripts are idempotent, exit non-zero on failure and run within a time budget (5 minutes by default); a script over
   its budget stops everything it started and says which budget it hit.
8. Logs and scratch files go to an ignored cache folder, one per concurrent step; long output is read from there.
9. A tool a task needs is added to the flake, never fetched at run time or installed with another package manager.
   Development-only tools stay out of the shipped product.
10. A release artifact is built by `nix build` from a file set that lists what goes in; fetched dependencies are named
    by their lock and hash.
11. Shell scripts pass `shellcheck`; shared helpers live in `scripts/lib/`.
12. Setup is: Nix with flakes enabled, then run any script. A check of a script runs from a plain shell and inside the
    dev shell, from a clean checkout.
