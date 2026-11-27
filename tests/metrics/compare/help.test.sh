#!/usr/bin/env bash
# docs/compare-setups.md shows what --help prints; scripts/compare/help.txt is the one source of both.
# shellcheck source=comparing.sh
source "$(dirname "${BASH_SOURCE[0]}")/comparing.sh"

# Prints the first `text` block under the page's heading `## Usage`.
usage_block_of_the_page() {
  jq --raw-input --slurp --raw-output '
    split("\n## ") | map(select(startswith("Usage\n"))) | first
    | split("```text\n")[1] | split("\n```")[0]
  ' "$REPO_ROOT/docs/compare-setups.md"
}

# catches: an option or an exit code changed in the command's help but not on its page (or the other way round),
# or a --help that is refused or ends with another code.
test_help_prints_the_usage_block_of_the_docs_page_and_exits_0() {
  local block
  block="$(usage_block_of_the_page)"
  compared --help
  assert_prints "$block" cat stdout
  assert_prints '' cat stderr
}

run_tests
