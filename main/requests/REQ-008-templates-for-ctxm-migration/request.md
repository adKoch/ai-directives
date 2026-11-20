---
id: REQ-008
title: template work before moving ctxm onto its templates
status: done (2026-11-20), items 2-4 on main's recommendation, open to the owner's change
approved_by: owner, 2026-11-20 ("let's do all template work for now")
source: main's gap list for migrating ctxm itself (chat, 2026-11-20)
depends_on: [REQ-002, REQ-003, REQ-006]
---
# REQ-008 template work before moving ctxm onto its templates

The owner asked where the templates stand for moving ctxm itself onto them, then: "let's do all template work for
now". The switch-over of ctxm itself is not part of this request.

Items 2-4 needed a decision; main took its own recommendation as the answer and records it here so the owner can
still change it.

## What changed (library commit 57a6956)
1. **`ctxm` template for ctxm 0.7.** The `CLAUDE.md` section, the skill and the guard know drafts, the project's own
   layer, several templates and `ctxm unapply --template`. A change to a template's part goes to the template; a
   change to the project's own part goes into a draft. Agents read a draft with `ctxm draft show [--porcelain]`. The
   guard names the own layer "the project's own" (porcelain writer `.`).
2. **Test tags start with a tagging command** (main's recommendation). `coding`: until a project has a tagging
   command, every test runs, the reviewer tags nothing and no test is dormant; the four-question gate still decides
   which tests are saved. Tests from before tags started are not dormant until the owner approves tagging them.
   Why: ctxm has about 1500 untagged tests and no tagging tool; the old rule would have stopped them all running.
3. **The wiki's folder, index and limits are per-project settings** (main's recommendation). `agents-metawork`
   variables `wiki_path` (default `ctxm/wiki`), `wiki_index` (`ctxm/wiki/README.md`), `wiki_page_words` (`800`),
   `wiki_folder_items` (`10`), used by the librarian, every role's Docs line and the release-tester. ctxm will set
   `wiki`, `wiki/pages/README.md`, `600`.
4. **Records: templates unchanged** (main's recommendation). New requests, plans and releases go into `ctxm/` as the
   templates say; ctxm keeps `records/` as its archive.
5. **New `web-ui` template**, linking `coding`: a rules file (outside text never rendered as markup, strict CSP, one
   API client, tokens in both themes with tested contrast, colour never the only sign, keyboard and phone width,
   confirmed writes, component tests in an emulated DOM against a contract stub, real browser at milestones, new
   runtime packages are the owner's), sections for five roles and an outline. Written from ctxm's web UI pages, kept
   framework-neutral.

## Acceptance (checked on a scratch project with ctxm 0.7.0, 2026-11-20)
- A draft of release-planning, rust, cli, multi-component, network-security, nix and web-ui plus an own `CLAUDE.md`
  section, with ctxm's wiki values: 29 files, no `{{ }}` left, no role file has a section twice, the own section is
  last, the wiki lines carry the project's values.
- Applied: `ctxm status` lists the own layer as `.`; the guard refuses an edit naming "the project's own" and reports
  a changed file once. The scratch project was unapplied and deleted.

## Found on the way (for ctxm 0.8)
- A draft has no command to set variable values: `ctxm apply --var` needs a template name, and `ctxm draft` has no
  `--var`. The trial set them by writing `.ctxm/draft/draft.toml`, which agents may not do.
