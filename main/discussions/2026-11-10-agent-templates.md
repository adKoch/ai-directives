# Agent templates: discussion with the owner (ended 2026-11-10)

Source of REQ-001. The owner's words are quoted; the rest is what was agreed.

## Why
- "After a couple releases the work seems to be very very slow. There also seems to be a similar problem with test
  bloat. I believe the review, planning and librarian processes seem to be ok, but I also have no way to know how much
  they improve."
- "Regarding 3d models, my main gripe is that it also takes very long with model doing a lot and a lot of checks."
- Priorities, in the owner's order: wall-clock time; 2–3 parallel workers; feel and tuning matter "only for some
  features"; ceremony may go.
- "I can make plan and then have the implementation time be hands-off for me. I also ideally would like to understand
  what is written and also avoid some llm known problem like reintroducing variables, spamming comments, making
  unreadable functions without any understanding level abstraction"
- Goal: "end this discussion with 2 templates for gamedev, one for making the game, the other for making art related
  assets for it, like 3d models and animations."

## Testing
- "tester is actually, not only redundant, but bloats tests even more. I think the reviewer should be given directives
  to actually watch out for fixing tests to make them green. I also think that we should aim to follow 80:20 rule"
- "making testing tools and running custom scenarios on the fly and only commiting regression test suite for 80:20"
- "We should probably write only 80:20 unit tests or even 90:10 [...] Maybe we could introduce tags to tests. [...] if
  test doesn't have a tag it doesn't run."
- "how about assigning tags be a reviewers choice"
- "we don't need to do drop, we can just leave it tagless, so it sort of serves as documentation."
- "We should probably have a cleanup where we remove unmarked tests after approving next release. We also should have
  some deterministic tool that tell us that tests at some point failed and probably some context around them. Probably
  if they fail the first time they were written it might be that the feature just wasnt implemented yet"

## Roster
- "would it make sense that we actually make fable do raw base implementation and then do a handoff to other models
  to continue, even for coding?"
- The owner's roster: foundation-worker (Fable), standard-worker (Sonnet), problem-solver (Opus), quick-scan-checker
  (Fable, "Does not run anything or check any logs/command output."), reviewer (Sonnet), planner (Opus), Librarian
  (Sonnet). "We could make make our ctxm templates that would sort of fill with assumption that these exist"
- Main: "we also need to have a "main" as the main session user interacts with. This is the leader. For each of
  template that has these, we also need to mention those in main."
- "Main would just note down requests and then we would have a dedicated planner to actually formulate it into plan.
  With main doing planning it has poluted context, no?"
- Fixes: "we should actually turn to problem solver for implementing fixes to whatever reviewer/checker find." Also
  "if we ever upon custom check, like game feel check or discovered bug during playsession(anything outside the
  plan), we do those with problem-solver." Agreed: after a fix, back to whoever found it; all findings go to the
  problem-solver ("Problem-solver").
- Reviewer: "there mostly for technical reviewer and should be quite lenient with requirements adherence. If something
  has been obviously skipped, then it's ok for it to point it out [...] If there are some big edge cases which might
  make it so that requirement cannot be fully filled [...] it should break and come back to main session for
  clarification."
- "main session should have it's own library of documents where it keeps a lot from user discussions."
- Planner: "from this document planner creates a list of potentially a lot of steps and separation into agents [...]
  but also we have general grouping verification task, which would replace those 80:20 tests inbetween. This means
  that we would actually have a lot of pointers on how to create a plan."
- "We no longer have leader as named, but instead have main, instead of creating plans it creates request document
  sets which could be quite long."
- Tester "Should probably stay, but if something is much more complex or caused issues before, the planner can decide
  that this step should have foundation worker create additional potential caselist [...] otherwise just small
  tester". Then: the checker writes the caselist ("Checker"), renamed **inspector** ("inspector is cool").
- Approval: "I would probably just approve the request set."
- Template sources live in ai-directives.

## Still open
- Commit the failure-history counts in the manifest, keep the raw run log local? (Recommended: yes.)
- Godot specifics (game-code); the art workflow (game-art).

## Layers and docs (2026-11-12 – 2026-11-13)
- On code in the base: "Should we actually mention code in this base template? Won't this be a part of more
  specialized inheritant?" Agreed: `agents-base` names no code, tests or tags; they come from domain layers.
- "we will do coding after I review and approve this one" — the parked testing draft is REQ-002.
- "ok, that looks good for now. Now let's try to make the gamedev implementation template that we will use in our
  current project." (Assumed: sling-defender; not yet confirmed.)
- "What if we approached it from higher level and leave details to library docs"
- "templates should be assumed read-only by project. I think we shouldn't try to make this library, instead we
  should have this outline or assumptions be given to librarian"
- Agreed: a domain template holds short stance sections in the role files and one outline for the librarian; the
  librarian writes and keeps the project's own docs from it. The librarian comes forward as `agents-metawork`.
- "Yes, draft both" — REQ-003 agents-metawork, REQ-004 game-code.

## Page limit, doc map, task workspaces (2026-11-13)
- "let's make a limit of words in documents from 600 to 800. It was very often encountered that some subjects were
  tough to encompass in that many words."
- "should librarian actually receive a reqest before planner and make a list of relevant wiki pages, while also
  pointing out new spaces and pointers what should be created? Then it would pass this info to planner."
- "librarian shouldn't return just a list, but a whole report with also some context on pages. I think it could be
  good for those pages to also have a comment on why/when they might be relevant made from the context by planner."
- "we should have unique task names and have some dedicated directory like <project>/local-tmp/<task-name> which
  could be freely used by agents working on only their own given task"
- Agreed: the librarian's doc map per requirement before planning (drafted request set, so no wait); the planner
  gives each item at most 4 pages with its own why/when; task names `<REQ>-<item>-<slug>`; `local-tmp/<task>/` in
  the main checkout, ignored by git, read by the maintenance batch, then deleted. "Yes, amend"

## Roles as subsections, one folder for the agents' files (2026-11-13)
- "is it possible to have an md merger where we merge based on matching header? So if we have multiple # Roles, we
  join them? That way we could put librarian in with others" — `markdown-merge` already joins matching headings;
  only a table cannot join. "let's switch roles to subsections instead of table"
- "I think we should have a dedicated directory for all this additional methodology stuff ... which should be
  read-only for outside interference by e.g. user(me) by assumption. This also means wiki I think?" — "I meant all
  the files which are actually used by this methodologies we are creating"
- On the name: "how about just ctxm ... So that it's obvious that we have .ctxm tool and all which is related and
  created there should be put into ctxm?" — "without .*, so we have both .ctxm and ctxm"
- Agreed: `ctxm/` holds everything the agents keep (discussions, requests, plans, planner guide, outlines, wiki,
  `tmp/<task>/`); only `CLAUDE.md` and `.claude/agents/` stay where Claude Code loads them. Agents own `ctxm/`; the
  owner changes it by telling main. `.ctxm/` stays ctxm's own.

## Feel sessions, tags and classification (2026-11-13)
- "I think the plan should actually have a feel session handoff at the end or earlier if there would be multiple
  things clashing in single interaction lever like 2 unit behaviour changes like unit range and movement speed."
- "What about our testing approach with tags and 80:20"
- "we need more elaborate guidelines on tag creation. I would expect they would have something with also how we
  create pages in wiki. Can you check what's currently there and try to figure out the decision framework for
  classification of concepts based on that" — draft: `requests/REQ-004-game-code/classification.md`.
- "I think we should try to stay away from declaring a list of tags up top as there is potentially big changes
  coming to a game with much more new turns. How could we come up with guidelines? Should it be connected to data
  domains or interaction levers?" — both: domains from code folders (place), levers from request sets (tags).
- "Don't we already assume that librarian proposes creation of new pages or find out if something is new? Should it
  also propose that it needs new levers?" — yes: the map batch proposes levers, flags synonyms and clashes; the owner
  approves them with the request set. "go ahead"

## Template stack: release planning, coding, specializations (2026-11-16)
- "when doing coding I didn't actually mean the end template to use in this project. I assume from there we would
  actually have to further specialize."
- "we did quite a bit of specification for tester, which also relies on specific structure of the plan which actually
  is based on silent assumption that we are doing rc into release workflow. This should also be described as a
  dedicated template as something related to release-based-planning or smth like that."
- "Another template when I meant by coding is actually guidelines on how to actually write code. Before I mainly
  focused on clean-code approach. I wanted it to be mostly readable, testable with minimized risk of having multiple
  levels of focus in a single function, where something could be done as main purpose, but there would be secondary
  effects, which I could assume would be problematic in llm based coding. It also focused on having script/task
  centered workflow."
- "This would serve as base, for example this project additionally is a cli tool written in rust, which is also
  multicomponent and is related to network logic, which actually needs emphasis on security validation and
  verification, which would be an additonal template."
- "Please create all of them as placeholders, create also one for nix" — placeholders in the library and in
  `ai-directives/ctxm/`: release-planning (links agents-metawork), coding, rust, cli, multi-component,
  network-security, godot (each links coding), nix (standalone).

## Release planning (2026-11-16)
- Tester: "Yes, I think tester should be bound to this plan with it's main workflow description" — the tester role
  moves from agents-base to release-planning.
- SemVer with `-rc.n` tags for every project: "yes".
- "ITIL should be another template on top that would be done alter when I actually finish my itil tool."
- Q1 (one plan per release or per request set): "I don't understand Q1" — explained again.
- Q1: "A, one plan per release" — `ctxm/plans/v<x.y>.md`; a request set approved later for the release joins it as
  further milestones, and the planner replans the parts not started. Plain agents-base keeps one plan per request set.
- REQ-005 drafted and approved: "Approve" (2026-11-16).
- "with that in mind, should tester be named somehow differently?" — proposed `release-tester` (shows the binding to
  release-planning; "tester" invites writing tests). "yes"
- "ok, actually try to fill all others based on ctxm and gamedev projects" — filled coding, rust, cli,
  multi-component, network-security, godot, nix; game-code narrowed to game design. Draft in
  `requests/REQ-002-coding/request.md`, with the choices made for the owner to review.
- "I realised we actually need also ctxm template for the actual ctxm usage. What type of file would be best suited
  for it" — a skill plus a few CLAUDE.md lines; optionally a hook. "yes, do it with a hook in such a way that it gives
  fast feedback in case the tool breaks the setup" — built as REQ-006; agents-base links it.
- "should nix develop setup to also have all dependencies there like we do with most of our project be in nix or
  somewhere else?" — the flake holds what the project's own work needs; tools that manage the project from outside
  (ctxm, Claude Code) are installed once per user. "this would also include that it runs everything via there" —
  every project command runs inside the dev shell through the scripts; only the user-level tools run on the host.
- "ok, that's good. What other thing from our templates is missng" — listed: merging, main's resume point, a home for
  proposals, project templates, a web UI template, Python script rules, the test-tag tooling, game-art, ITIL, review
  pages. "lets do it" — the first four built (REQ-001 amendment, REQ-007).

## Probes first (2026-11-18)
- "previosuly we discussed that we want most of our tests to be special cases that are executed with helper tools and
  not neccesarily saved" — the filled `coding` had drifted to saved candidate tests; corrected (REQ-002 amendment
  2026-11-18).

## Approval and next step (2026-11-18)
- "ok, all those templates are approved. Can we commit and push them in directives? Afterwards let's do cleanup of all
  the temp projects and then try to think how we can migrate sling-defender" — REQ-002, REQ-006 and REQ-007 approved;
  all seven request sets are now approved.
