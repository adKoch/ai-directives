# Locks ctxm rendered
Each file is a `.ctxm/ctxm.lock` written by the real `ctxm` binary (0.8, lock format 8), copied as it stands: the
forms a hand-built lock could miss. `../rendered-locks.test.sh` reads each and checks its fingerprint.

| File | How ctxm wrote it | The form it holds |
|---|---|---|
| `line-break.toml` | `ctxm apply notes --var` with a value holding line breaks, `"""` and `'''` | a `"""` multi-line string in `[values]`, an escaped quote inside it |
| `literal-string.toml` | the same, with a value holding `"""`, a line `[[templates]]` and a closing backslash | a `'''` multi-line string in `[values]` whose lines read as a template |
| `quoted-path.toml` | a template whose file's target holds `'`, `"` and `'''` | a one-line `"""` string in `[[files]]` |
| `no-files.toml` | a template with no files | `files = []` before the tables, no `folders` |
| `nested-name.toml` | a template named `team/Rust.v2` | a name with a capital, a `/` and a `.` |

To make them again: build ctxm (`scripts/build.sh` in its repository); with a throwaway `HOME`, `XDG_CONFIG_HOME` and
`XDG_DATA_HOME`, run `ctxm library init`, make each template with `ctxm template new` and `ctxm template add`, and
apply it to an empty git repository with `ctxm apply <template> [--var ...] --dry-run`, then `--yes <identifier>`.
The commits are the throwaway library's.
