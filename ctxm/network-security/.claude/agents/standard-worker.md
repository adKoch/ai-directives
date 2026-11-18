## Security
- On a `boundary: yes` item, send every outside value through the shared checks; never re-implement or skip them.
- Write an abuse-case test for each input you accept, and name in your submission the boundary and the test that
  proves the refusal.
- Never add a dependency or a bind address: stop and return to main.
