# Outline: web-ui

## Structure and screens
Must cover: the folder layout, one line per screen and per shared module; how a screen gets its address; how a
screen loads, shows errors and asks before a write.
Assumed: a single-page app with no router library unless the page says otherwise.
Read by: planner, workers, reviewer

## The API client and the stub
Must cover: the one module that talks to the server, the type files and how they follow the contract, how the token
is kept, the stub and how it answers from the contract's examples.
Assumed: the server publishes a contract (for example OpenAPI) with examples.
Read by: workers, reviewer, release-tester

## The look
Must cover: the tokens and where they live, both themes, the building blocks and their options, the contrast test,
how a colour is added, where long names wrap, the phone-width layout.
Assumed: hand-written CSS on tokens.
Read by: workers, inspector, reviewer

## Security in the page
Must cover: the CSP and how the built page is checked, how outside text is shown, the rich-text renderer and its
allowlist, what never goes into an address.
Assumed: the server sets the CSP.
Read by: workers, inspector, reviewer

## Testing the UI
Must cover: the emulated DOM and its limits, the test helpers (mount, reload, back, key presses, typing), how a
reviewer probes a screen, the real-browser check and its driver, what each can and cannot show.
Assumed: component tests run in the minimal check; the real browser only at milestones.
Read by: workers, reviewer, release-tester, problem-solver

## Toolchain and packages
Must cover: where the tools come from, the lint, format and type-check commands, the lock file, how a package is
added and reviewed, the gotchas met.
Assumed: the project's dev shell provides the tools.
Read by: workers, reviewer, planner
