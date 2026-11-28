#!/usr/bin/env bash
# The collector reads every lock ctxm writes: the locks in rendered-locks/ were written by the real ctxm binary, with
# the forms a hand-built lock could miss (a value with line breaks, a path with quotes, no files, a nested name).
# Each is read with its fingerprint right, as it stands and with its lines ended by a carriage return too.
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"
# shellcheck source=locks.sh
source "$(dirname "${BASH_SOURCE[0]}")/locks.sh"

readonly RENDERED_LOCKS="$COLLECTOR_TESTS/rendered-locks"
readonly LIBRARY_COMMIT=e90b39e8bb3fd8afc8cae0f2d80f8a0926893f60

# Fails unless the lock file, collected, gives the templates of the fingerprint.
assert_lock_read_as() {
  collect_with_lock_file "$1"
  assert_prints 0 cat status
  assert_prints "$2" line_fields a0000000000000001 templates
}

# catches: a value ctxm writes as a multi-line string (a line break, quotes, lines that read as a template inside
# it) refused as a line the collector does not read, or a line inside it taken for a header or a key.
test_a_lock_with_a_multi_line_value_is_read() {
  assert_lock_read_as "$RENDERED_LOCKS/line-break.toml" "notes@$LIBRARY_COMMIT"
  assert_lock_read_as "$RENDERED_LOCKS/literal-string.toml" "notes@$LIBRARY_COMMIT"
}

# catches: a file's path ctxm writes as a one-line string holding quotes and `'''` refused, or read as the start of
# a multi-line string, so the templates after it are lost.
test_a_lock_with_a_quoted_path_is_read() {
  assert_lock_read_as "$RENDERED_LOCKS/quoted-path.toml" "quoted@$LIBRARY_COMMIT"
}

# catches: the `files = []` of a lock whose templates manage no file refused as a line before the tables.
test_a_lock_without_files_is_read() {
  assert_lock_read_as "$RENDERED_LOCKS/no-files.toml" "empty@$LIBRARY_COMMIT"
}

# catches: a template name ctxm accepts (a capital, a `/`, a `.`) refused as a name that is none.
test_a_lock_with_a_nested_template_name_is_read() {
  assert_lock_read_as "$RENDERED_LOCKS/nested-name.toml" "team/Rust.v2@c9c0fab97867a6be867823617912f572f399ef7a"
}

# catches: a lock whose lines end in a carriage return and a line feed (a checkout on Windows) refused, or read as
# another setup.
test_a_lock_with_carriage_returns_is_read_as_the_same_setup() {
  sed 's/$/\r/' "$RENDERED_LOCKS/line-break.toml" >crlf.toml
  assert_lock_read_as crlf.toml "notes@$LIBRARY_COMMIT"
  assert_prints 19 carriage_returns_in_the_lock
}

# Prints how many lines of the lock the project holds end in a carriage return.
carriage_returns_in_the_lock() {
  git -C project show HEAD:.ctxm/ctxm.lock | grep --count $'\r$'
}

run_tests
