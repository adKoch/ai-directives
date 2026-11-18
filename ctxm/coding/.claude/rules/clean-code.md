# Clean code
Write code that reads top to bottom like prose. These rules cover product code, test code and scripts. Numbers are
defaults; a language template may tighten them, never loosen them.

## Functions: one purpose, no secondary effects
1. A function has one main purpose, named by its verb. If it also does something else (writes a file, logs, caches,
   changes an argument, touches global state), that is a second function. The name must predict every effect.
2. One level of detail per function: it either decides and delegates, or does one concrete step, never both. A
   comment separating sections means each section is a function named after that comment.
3. Command-query separation: change state or answer a question, never both. No hidden writes inside a getter,
   validator or formatter.
4. At most 20 lines (hard 30), at most 3 parameters; more parameters mean a missing type. No flag parameters: a bool
   that picks behaviour becomes two functions.
5. Step-down order: the public function first, then what it calls, in call order.
6. Error handling is its own function, apart from the happy path.

## Effects
7. Pure logic in the middle, effects (files, network, clock, randomness, terminal) at the edges, passed in. Logic is
   testable without them.
8. Dependencies point inward: the core never knows the adapters.
9. No test-mode branches in product code.

## Names
10. A name says why the thing exists. No abbreviations, no noise words (`data`, `info`, `manager`, `util`). Types are
    nouns, functions are verbs, one word per concept; the glossary names the concepts.
11. A value is named once. No variable that only restates an expression or its source under the same name; no
    wrapper that only renames.

## Types and modules
12. One reason to change per module. Test and demo support never lives in product code.
13. At most 200 lines per file (hard 300), tests included; data files (fixtures, vectors) are exempt.
14. Data that belongs together travels in a type, not in parallel lists.
15. Don't repeat logic, and don't add an abstraction for a single use.

## Comments
16. Comments say why, never what. No comment that repeats the code, no task-number or changelog comments, no
    commented-out code. Keep doc comments on public items and the reason for a non-obvious choice.

## Tests
17. Tests are fast, independent, repeatable and self-validating. One concept per test; names are sentences.
18. Most checking is a probe: a scenario run with the project's helper tools and not saved. A test is saved only for a
    break that can be named and could plausibly happen (the project's testing pages).
19. Never edit a test, expected value or fixture to make it pass.

## Workflow
20. Work through the project's scripts, never ad-hoc commands; add a script before repeating a command by hand.
21. Leave touched code a little better, only inside your item's scope and never changing behaviour; more goes to main
    as a proposal.
22. A limit may be broken only where the alternative reads worse; mark it with a one-line reason the reviewer checks.
