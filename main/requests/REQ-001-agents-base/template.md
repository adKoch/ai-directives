# REQ-001 template

## Sources
Written in `ai-directives/ctxm/agents-base/`, laid out as in a project, imported with
`ctxm template new agents-base` and `ctxm template add agents-base ctxm/agents-base --render`.

## Contents
| Target | Merge type | What |
|---|---|---|
| `CLAUDE.md` | `markdown-merge` | main's sections: Main session, Roles, Running a plan |
| `.claude/agents/<role>.md` | `markdown-merge` | the seven role files, model from the tier variables |
| `main/README.md` | `markdown-merge` | main's library layout: discussions, requests, plans |
| `main/planner-guide.md` | `markdown-merge` | the planner guide (`flow.md`) |

Domain layers add sections to these same files.

## Variables
`model_foundation`, `effort_foundation`, `model_standard`, `model_strong`, with defaults in the template.

## Trial
`ctxm apply --dry-run` against a scratch project with its own `CLAUDE.md`, then against sling-defender (or a copy).
