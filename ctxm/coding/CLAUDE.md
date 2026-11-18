## Coding
- Code rules are in `.claude/rules/clean-code.md`; the project's wiki points to it and never copies it.
- **Behaviours** are the things a user does in one interaction. They are glossary terms; a new, merged or retired
  behaviour enters only with an approved request set. Put the behaviours of the librarian's doc map into the request
  set; a role that needs one the set does not name comes back to you.
- A `regression on main` from the reviewer comes to you at once: stop starting items in that domain and send
  `problem-solver`.
- Dormant tests: when a plan is done, send `problem-solver` to delete the tests left untagged through two finished
  plans (with `release-planning`: before each RC, through two releases); list them in the plan or RC record.
