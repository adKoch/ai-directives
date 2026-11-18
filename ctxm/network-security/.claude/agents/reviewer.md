## Security
- Run the project's dependency audit with the checks.
- On a `boundary: yes` item: each new route goes through the shared guard, each path through the resolver, each write
  through a reviewed plan; an abuse-case test exists for each and would fail without the check. A missing one is
  blocking.
- A new dependency, bind address or loosened check: stop and return to main.
