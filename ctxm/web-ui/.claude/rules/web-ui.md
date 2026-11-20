# Web user interfaces
On top of `.claude/rules/clean-code.md`. For the browser code of a single-page UI (for example Svelte or TypeScript).

## Safety
1. Text from outside (names, file content, server messages) is shown as text, never as markup: no `{@html}`,
   `innerHTML` or the like for it. Rich text (Markdown) goes through one renderer with an allowlist.
2. The page loads nothing from outside its origin and runs under a strict Content Security Policy: no inline script,
   no inline style attributes, a nonce where a library needs one. The CSP is the server's contract; the UI adapts to
   it and a check reads the built page against it.
3. Secrets (tokens, keys) never sit in a screen's address, a log or the page's text.
4. A write asks first: the screen shows what will change, then sends only on the user's confirmation. A refusal or a
   changed plan keeps the question open with the server's words.

## Structure
5. One module talks to the server; screens never build URLs. Its types follow the API contract and change with it.
6. One screen per file, its parts as components, logic in plain modules that test without a DOM.
7. Every screen has its own address, so back, forward and reload work; a screen loads with a visible state for
   loading and for errors (`role="alert"`).
8. A file's limit counts its markup and its styles too; split by part before raising it.

## Look
9. Colours, sizes and spacing come from shared tokens; components set no literal colour. Shared building blocks
   (buttons, cards, badges, headers) are used, never copied.
10. Both themes (light and dark) from the same tokens. Text contrast at least 4.5:1, other marks 3:1, in both,
    checked by a test.
11. Colour is never the only sign: a state has its word. Every control is reachable and usable from the keyboard,
    named by its text or label, with a visible focus.
12. Every screen works at phone width (about 360 px) without sideways scrolling.

## Checks
13. The minimal check runs the linter and formatter, the type check (with the framework's checker) and the
    component tests.
14. Component tests mount the app in an emulated DOM against a stub that answers from the API contract's examples,
    and find controls as a user does: by text or label.
15. What the emulated DOM cannot show (the CSP, layout, focus, real rendering) is checked in a real browser at
    milestones, not on every change.
16. Packages are pinned by the lock file; a new runtime package is the owner's decision.
