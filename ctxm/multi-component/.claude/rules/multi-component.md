# Systems of several components
On top of `.claude/rules/clean-code.md`.

## Boundaries
1. Hexagonal: the core holds the model and the logic and knows no adapter. It reaches outside only through ports
   (interfaces it owns); adapters implement ports and depend on the core, never the other way.
2. Entry points (a CLI, a server) and adapters depend on the core; a client UI depends only on the server's API. A
   new dependency edge is a design decision, checked against this rule.
3. The core calls no IO, terminal, network or process API; anything that needs one is a port.
4. Ports are small and typed in domain terms. A port that fails changes nothing.
5. Entry points open adapters, call core functions and format the answer; they never decide domain behaviour. Two
   entry points serving the same need call the same core function, so they cannot disagree.
6. A hosted mode differs from a local one only in the adapters behind its ports.

## Contracts
7. A contract between components is a document (OpenAPI for HTTP), written before the server and the client; it names
   for each operation the core function behind it.
8. The contract is machine-checked in the minimal tier: the document is validated (warnings fail), and contract tests
   check every real reply against it. Objects are closed: an undeclared field fails.
9. Fixed words that cross a boundary (states, change kinds, error codes) are defined once in the core and listed in
   the contract as enums; adding one changes the core, the contract, every client and the test comparing them.
10. A contract change is versioned: an added field moves the minor version, a removed or renamed one the major.

## Tests
11. Each component is tested with in-memory doubles of its ports; doubles live with the tests.
12. One behaviour is tested on each side: a contract test against the document, a client test against a stub that
    follows it, and an end-to-end test over the real parts. A refusal is tested for what it changes: nothing.
