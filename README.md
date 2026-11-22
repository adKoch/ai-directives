# AI Directives

General directives for AI assistants to use as templates across all projects.

## What's Inside

**CLAUDE.md** - Comprehensive guidelines for AI development assistants covering:

- **Core Principles**: Brief documentation, hexagonal architecture, self-explanatory code
- **Development Environment**: Nix-only setup with Taskfile, no random scripts
- **Nix Best Practices**: Flakes, `nix develop`, direnv automation, dependency locking
- **Clean Code Principles**: Naming, single responsibility, small functions, DRY principle
- **Clean Architecture**: Dependency rule, layered architecture, framework independence

## Purpose

These directives ensure consistent, clean, and maintainable development practices across all projects using AI assistance. Copy and adapt for specific project needs.

## Tools

The library ships no toolchain: `bash`, `jq`, `shellcheck`, `git` and GNU `coreutils` come from the caller's own toolchain, on the `PATH`. `scripts/check.sh`, the library's check (shellcheck on the library's scripts and tests and on the scripts `agents-base` ships, not yet on the rest of `ctxm/`; then every test; within 300 seconds; `LIBRARY_BUDGET_SECONDS=<n>` changes that), looks for them first and, when one is missing, stops with one line naming it and runs nothing. Tested with bash 5.3, jq 1.8.2, shellcheck 0.11.0, git 2.54.0 and coreutils 9.11. How its tests are built: `tests/metrics/support/README.md`.
