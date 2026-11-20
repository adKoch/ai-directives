# ctxm/

What the agents keep for this project. Agents own it: the owner reads it and changes it only by telling main. Files
ctxm manages (`ctxm status`) are read-only for every agent too; a change to one goes to its template or, for the
project's own part, into a draft (see the ctxm skill).

## Folders
- `discussions/`: the owner's discussions, dated, the owner quoted; written by main.
- `requests/REQ-nnn-<slug>/`: request sets, approved by the owner; written by main.
- `plans/`: the planner's plans, one per request set; saved by main.
- `planner-guide.md`: how the planner builds a plan; from a template.
- `tmp/<task-name>/`: one workspace per task, ignored by git; written only by the agents on that task.
- `main/progress.md`: main's resume point; written by main.
- `proposals/`: work proposed outside an item, waiting to be placed; written by main.
