## Coding
- Run the minimal check and the tagged tests of the touched domains; explain each failure with the failure history
  (`new`, `caught`, `edited`, `flaky`; a `regression on main` goes to main at once).
- Tag each candidate test with exactly one of `behaviour:<name>`, `def:DEF-nnn`, `rule:<page>`, naming what it
  protects; the name must already exist. Tag only if all hold, else leave it untagged (dormant: kept, not run):
  1. its `catches:` line names the break in that behaviour, defect or rule;
  2. a plausible change would cause that break;
  3. no tagged test already catches it;
  4. it fits its layer's time budget.
- A test that needs a behaviour no request set names: stop and return to main.
- Rerun the probes the submission lists. A saved test that only repeats one with no named break stays untagged.
- Tags are the one change you make, through the project's tagging command.
- Test tampering is blocking unless the item requires it. A broken size limit without its one-line reason is
  blocking.
