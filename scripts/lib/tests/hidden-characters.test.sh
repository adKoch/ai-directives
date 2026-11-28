#!/usr/bin/env bash
# The library-wide scan for characters a reader cannot see as they are (scripts/lib/hidden-characters.sh): each control
# and bidi character, NUL and a dotfile are found, and a plain text with visible non-ASCII is left alone.
# shellcheck source=../../../tests/metrics/support/testing.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../tests/metrics/support/testing.sh"
# shellcheck source=../hidden-characters.sh
source "$REPO_ROOT/scripts/lib/hidden-characters.sh"

# Writes a file for each code in the list, `<number>` holding `a<the bytes>b`, in ./characters/; the names stay in
# ./names, one per line, in byte order, as the scan prints them.
write_each_character() {
  local number=0 bytes
  mkdir characters
  for bytes in "$@"; do
    number=$((number + 1))
    printf 'a%b\n' "${bytes}b" >"characters/$number"
    printf 'characters/%s\n' "$number" >>names
  done
  LC_ALL=C sort -o names names
}

# Prints the bytes of the characters that hide text, as printf escapes, one per line: the C0 controls but tab and line
# end, DEL, the C1 controls, the separators, zero-width and invisible characters, the bidi marks and the byte-order mark.
hiding_characters() {
  local code
  for code in {1..8} 11 12 {13..31} 127; do
    printf '\\x%02x\n' "$code"
  done
  for code in {128..159}; do
    printf '\\xc2\\x%02x\n' "$code"
  done
  printf '\\xd8\\x9c\n'
  for code in {139..143} {168..174}; do
    printf '\\xe2\\x80\\x%02x\n' "$code"
  done
  for code in {160..175}; do
    printf '\\xe2\\x81\\x%02x\n' "$code"
  done
  printf '\\xef\\xbb\\xbf\n'
}

# catches: a control, zero-width or bidi character that the scan lets pass, so a reader sees other text than the one a
# tool reads.
test_each_control_zero_width_and_bidi_character_is_found() {
  local characters expected
  mapfile -t characters < <(hiding_characters)
  write_each_character "${characters[@]}"
  expected="$(<names)"
  assert_prints "$expected" files_with_hidden_characters characters/*
}

# catches: a NUL passing the scan because the shell drops it from the text it reads.
test_a_nul_is_found() {
  printf 'a\0b\n' >nul
  assert_prints nul files_with_hidden_characters nul
}

# catches: a scan that refuses what a reader sees as it is: tabs, line ends and visible non-ASCII text.
test_tabs_line_ends_and_visible_text_are_left_alone() {
  printf 'a\tb\n\xe2\x80\xa6 \xe2\x86\x92 \xc3\xa9\n' >plain
  assert_prints '' files_with_hidden_characters plain
}

# catches: the stricter scan of the comparison's files letting a visible non-ASCII character or a NUL pass.
test_printable_ascii_only_refuses_any_other_character() {
  printf 'caf\xc3\xa9\n' >accent
  printf 'a\0b\n' >nul
  printf 'a\tb\n' >plain
  assert_prints 'accent
nul' files_outside_printable_ascii accent nul plain
}

# catches: a file that cannot be read passing as clean, so a scan that read nothing says all is well.
test_a_file_that_cannot_be_read_ends_the_scan_with_a_line() {
  local status=0
  mkdir folder
  (files_with_hidden_characters folder) >stdout 2>stderr || status=$?
  assert_equal "$status" 1
  assert_prints 'error: a file could not be read for hidden characters; every file of the library must be readable' \
    tail -n 1 stderr
}

# catches: a name that turns text around printed as it is.
test_a_name_with_a_hidden_character_is_printed_escaped() {
  printf 'a\xe2\x80\xaeb\n' >$'x\xe2\x80\xaey'
  assert_prints 'x%E2%80%AEy' files_with_hidden_characters $'x\xe2\x80\xaey'
}

# catches: a dotfile or a file in a subfolder left out of the scan, or a file the checkout ignores or a link read.
test_the_files_of_the_library_include_dotfiles_and_subfolders_but_not_ignored_files_or_links() {
  git init --quiet repo
  mkdir -p repo/sub/deeper repo/.cache
  printf 'x\n' >repo/.dotfile
  printf 'x\n' >repo/sub/deeper/file
  printf 'x\n' >repo/.cache/ignored
  printf '.cache/\n' >repo/.gitignore
  ln -s sub repo/link
  assert_prints "$PWD/repo/.dotfile
$PWD/repo/.gitignore
$PWD/repo/sub/deeper/file" files_listed repo
}

# Prints the files of the library under the folder, one per line (the scan lists them NUL-ended).
files_listed() {
  files_of_the_library "$PWD/$1" | tr '\0' '\n' | LC_ALL=C sort
}

run_tests
