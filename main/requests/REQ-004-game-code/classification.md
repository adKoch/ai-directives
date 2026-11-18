# REQ-004 game-code: classifying concepts (approved 2026-11-13, owner: "Yes, apply it")

How a game project names and places its knowledge and tests, without a list of names fixed up front: the game will
change a lot, so the template ships rules for making names, and the project's glossary holds the names.

## Two kinds of name
| | Data domain | Interaction lever |
|---|---|---|
| What | a part of the code's model: horde, turret, stage | one thing the player does or judges in one interaction: engaging an enemy, outrunning the horde, aiming a turret |
| Comes from | the code folder (`client/rules/<domain>/`) | a request set, approved by the owner |
| Answers | where it lives; which checks a change selects | what it is for; what the owner judges by playing |
| Shows in | wiki folder, test folder, check group | test tags, feel requirements, play sessions |
| Crosses | nothing: one folder | several domains (engaging: turret range, horde speed, stage contact) |

- A **domain** exists once the code has its folder; nobody declares one. The wiki folder and test folder use its name.
- A **lever** exists once an approved request set names it. Each is a glossary term: meaning, the domains it crosses,
  where it was defined, retired names. Levers are merged, split or retired the same way, through a request set.

## Levers enter with the request set
- The librarian's **map batch** (run while the owner reviews the drafted set) reports, per requirement, besides pages:
  - **Levers touched**: existing levers the requirement changes.
  - **New levers**: proposed name, one-line meaning, the domains it crosses.
  - **Same as**: a proposed name that is an existing lever in other words; the existing name is used.
  - **Clashes**: two feel requirements on one lever.
- Main puts the levers into the request set; the owner approves them with it. The librarian then writes them into the
  glossary.
- A role that needs a lever the request set does not name stops and returns to main, like any unforeseen case.

## Feel and play sessions
- A feel requirement names its lever.
- The plan ends with one play-session handoff for all feel requirements.
- Two feel requirements on one lever never share a session: the first one's group ends with a play session, the second
  is built after the owner's notes.
- A handoff lists each feel requirement, what to try, what changed, and where its tuning values live. The owner's notes
  are recorded and go to `problem-solver`.

## Tests
A test's **place** is its domain and layer (`tests/<layer>/<domain>/`); its **tag** names what it protects.

### Tags: what a test protects
Exactly one of:
- `lever:<name>`: a behaviour the player sees; the lever is in the glossary.
- `def:DEF-nnn`: a past defect.
- `rule:<page>`: a domain invariant stated by a rule line on that wiki page (obscure logic no player sees directly).

Only the reviewer tags, through the project's tagging command, and only with names that already exist. A test with no
tag is **dormant**: kept as documentation, not run.

### The gate (80:20)
Before tagging, in order; the first "no" leaves the test dormant:
1. **Named:** can its `catches:` line name the break in a lever, a defect or a rule that already exists?
2. **Realistic:** would a plausible change cause that break?
3. **Not covered:** does no tagged test already catch the same break?
4. **Cheap enough:** does it fit its layer's time budget?

### When it runs: by layer, not by tag
- `unit/`, `arch/` (or the project's equivalents): every change to their domain; `arch/` on every change.
- `e2e/` and replays of whole runs: the tester's group step.
- `bench/`: reports at the end of a plan, never fails.

The project's own layers and their folders are written by the librarian from the outline.

### Keeping it small
- A dormant test still untagged after two finished plans is deleted by `problem-solver` at main's call; the plan
  record lists it.
- A retired lever or rule: its tests are re-tagged by the reviewer in the next item touching them, or go dormant.
- A check group over its time budget splits by domain, as a page over the word limit becomes a folder.

## Where this lands
- `game-code` outline: a **Levers** topic (glossary form, how one is created, merged, retired); **Tests and tags**
  rewritten to the above.
- `game-code` librarian section: the Levers part of the doc map.
- `game-code` planner section: play sessions by lever.
- `game-code` reviewer, worker and tester sections: the three tags, the gate, layer by folder.
- `game-code` main section: feel requirements name their lever; main runs the dormant cleanup.
