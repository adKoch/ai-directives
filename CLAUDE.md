# Claude AI Project Guidelines

## Core Principles

- Be brief in all documentation
- Follow hexagonal architecture with clean, understandable solutions
- No explanation comments - code should be self-explanatory
- Minimal documentation

## Development Environment

- This library has no flake and ships no toolchain: its scripts use the tools of the caller's own toolchain, on the `PATH` (`README.md`, Tools)
- Use the scripts in `scripts/` as the entry points, never ad-hoc commands: `scripts/check.sh` is the check, `scripts/compare-setups.sh` the comparison
- A repeatable step is a script; each script checks its tools first and runs within a time budget
- A project that applies these templates keeps its own toolchain pinned (for example a Nix flake with `nix develop`) and runs the library's scripts inside it

## Clean Code Principles

- **Intention-revealing names**: Names should explain why, what, and how
- **Single Responsibility**: Functions do one thing only
- **Small functions**: Ideally <20 lines, single level of abstraction
- **Command-Query Separation**: Functions either do something or return something
- **Boy Scout Rule**: Leave code cleaner than you found it
- **Self-explanatory code**: Minimize comments, code should speak for itself

## Clean Architecture Principles

- **Dependency Rule**: Dependencies point inward only (outer → inner layers)
- **Layers**: Frameworks → Adapters → Use Cases → Entities
- **Dependency Inversion**: Depend on abstractions, not concretions
- **Independence**: Business logic isolated from frameworks, databases, UI
- **Testability**: Inner layers testable without external dependencies
- **Hexagonal Architecture**: Same isolation via ports & adapters pattern
