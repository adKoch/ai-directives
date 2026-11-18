# REQ-003 outlines

An outline is a read-only file a domain template ships at `main/outlines/<template>.md`. It says **what** the
project's docs must cover, never the project's details.

## Shape
```
# Outline: <template>

## <topic>
Must cover: <what an agent needs to know about it>
Assumed: <what the template's stance sections take for granted>
Read by: <roles>
```

## Rules
- A topic is one page's worth; the librarian may split it.
- `Assumed` lines are what the template's role sections rely on. A project that cannot meet one is a gap for the
  owner, not something the librarian works around.
- Outlines of several templates may share a topic; the librarian keeps one page for it.
- An outline never holds project names, paths or commands; the project's pages do.
