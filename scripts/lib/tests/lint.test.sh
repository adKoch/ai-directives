#!/usr/bin/env bash
# The lint step end to end (scripts/lib/steps/lint.sh), run on a small copy of the library: it passes a clean copy,
# and fails naming the file when one holds a hidden character or a name does.
# shellcheck source=../../../tests/metrics/support/testing.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../tests/metrics/support/testing.sh"

# The files the lint step needs to run in a copy: itself, what it sources, the character rules and the ignore list.
readonly LINT_FILES=(
  .gitignore
  scripts/lib/budget.sh
  scripts/lib/characters.jq
  scripts/lib/common.sh
  scripts/lib/hidden-characters.sh
  scripts/lib/steps/lint.sh
  scripts/lib/test-files.sh
  scripts/lib/tools.sh
)
# The right-to-left override U+202E, made from its bytes when the test runs, so this file holds none.
TURN_AROUND="$(printf '\342\200\256')"
readonly TURN_AROUND

# Copies the lint step's files into ./library, a checkout of its own that git knows nothing of yet: the step lists
# the files that are not ignored, tracked or not.
copy_the_lint_step() {
  local file
  for file in "${LINT_FILES[@]}"; do
    mkdir -p "library/${file%/*}"
    cp "$REPO_ROOT/$file" "library/$file"
  done
  git init --quiet library
}

# Runs the copy's lint step; leaves ./stdout, ./stderr and the exit status in ./status.
lint_the_copy() {
  local status=0
  bash library/scripts/lib/steps/lint.sh >stdout 2>stderr || status=$?
  printf '%s\n' "$status" >status
}

# catches: a lint step that passes a file or a name with a hidden character, because the step's own wiring (the file
# list, the order of its checks, its exit) lost what the scan's own tests show it finds.
test_the_lint_step_fails_on_a_planted_hidden_character_and_a_hidden_name_and_passes_without() {
  copy_the_lint_step
  lint_the_copy
  assert_prints 0 cat status
  printf 'synthetic%stext\n' "$TURN_AROUND" >library/planted.md
  lint_the_copy
  assert_prints 1 cat status
  assert_prints "error: hidden characters (scripts/lib/characters.jq) in: $PWD/library/planted.md; remove them" \
    cat stderr
  rm library/planted.md
  printf 'synthetic text\n' >"library/planted${TURN_AROUND}.md"
  lint_the_copy
  assert_prints 1 cat status
  assert_prints "error: hidden characters (scripts/lib/characters.jq) in the names of:\
 $PWD/library/planted%E2%80%AE.md; rename them" cat stderr
}

run_tests
