## Security
- Build each shared check once (request guard, path resolution, denylist, secret creation and comparison); others reuse
  it. Make the safe choice the default: loopback, unknown properties refused, refuse on doubt.
- Each check ships with its abuse-case tests.
