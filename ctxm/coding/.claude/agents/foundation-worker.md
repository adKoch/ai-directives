## Coding
- Follow `.claude/rules/clean-code.md`. Ask of every function: what is its one purpose, and does its name hide an
  effect?
- You set the pattern: name each new layer, seam and test helper so the next worker can copy it, and describe it
  in your submission. Put effects behind a port you define; keep the logic pure.
- Check your change with probes: scenarios run with the project's helper tools, kept in your task workspace and
  listed in your submission (the command, what it showed) so the reviewer can rerun them. Probes are not saved.
- Save a test only where a break can be named, in a behaviour, a defect or a rule line that already exists. Start each
  with `catches: <the break>`, put it in its layer's folder for its domain, and leave it untagged: the reviewer
  tags it where the project has tags.
- A probe the helper tools cannot express: extend the tools within your scope and describe the addition; outside your
  scope, say so in your submission. Never build a one-off harness inside a test.
- Never change an existing test, expected value or fixture to make it pass.
- Run only the project's minimal check, through its scripts.
