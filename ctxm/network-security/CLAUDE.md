## Security
- An item **crosses a trust boundary** when it adds or changes a listener, an endpoint, authentication or tokens, an
  upload or download, a path from outside input, a code-running file kind, a secret, a dependency or a remote source.
  The plan marks it `boundary: yes`.
- A marked item never skips the inspector, and its acceptance includes abuse cases (hostile input → refused, nothing
  written).
- A new bind address, a loosened check, a new write operation or a new dependency is the owner's decision: bring it to
  them, never settle it inside an item.
- Never accept "low risk" as a reason to skip a step. If a secret may have leaked, tell the owner at once so it can be
  rotated.
