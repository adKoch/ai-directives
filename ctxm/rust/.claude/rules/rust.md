---
paths: ["**/*.rs", "**/Cargo.toml", "**/clippy.toml", "**/rustfmt.toml"]
---
# Rust
On top of `.claude/rules/clean-code.md`.

## Workspace and tools
1. Edition, version and licence are set once in `[workspace.package]`, dependency versions once in
   `[workspace.dependencies]`; members use `.workspace = true`.
2. rustfmt and clippy with warnings as errors, configured in the repository, run through the project's scripts.
3. Clippy's argument limit counts `self`: set it so a method with `self` and 3 arguments passes. A free function
   with 4 arguments still breaks the coding rule; the reviewer catches what the lint cannot.
4. A new dependency is proposed with its purpose, alternatives, transitive size, licence and build impact. Turn off
   default features you do not use.

## Code
5. No `unwrap`, `panic!`, fallible indexing or `unsafe` in product code. An invariant that cannot fail is
   `expect("<why it holds>")`. Tests may unwrap.
6. A library crate has one error enum per concern, with named variants whose `Display` says what the user can do. A
   variant wraps its cause or carries the facts (names, paths), never a pre-formatted string. No `Box<dyn Error>` or
   `anyhow` in a library crate.
7. `?` converts through `From` only when the variant is the same concept; otherwise map explicitly.
8. Format an error once, where it is printed. Escape untrusted text where the message is made; never `{:?}` in a
   message.
9. Private fields where an invariant exists, built through a function that checks it. Enums over strings and bools
   for kinds and states; one `match` over all variants may pass the length limit with a one-line reason.
10. Borrow in parameters (`&str`, `&[T]`, `&Path`), own in returns. Never clone to silence the borrow checker.
11. One module per responsibility; the public surface is re-exported from the crate root, everything else private or
    `pub(crate)`.
12. Doc comments (`///`) go above attributes; public items have one, saying why.

## Tests
13. Unit tests sit in a `#[cfg(test)] mod tests` at the foot of the file; when the file would pass its size limit,
    the module moves to `<module>/tests.rs`. Test doubles live under `#[cfg(test)]` and are shared by path, never
    reloaded with `#[path]`.
14. Integration, contract and golden tests live in the crate's `tests/` folder, one binary per concern. Tests that
    run a built binary live in their own workspace member with a shared fixtures library.
15. The module path gives a test's domain; its place gives its layer (inline: unit, `tests/`: integration, the
    end-to-end member: end-to-end).
