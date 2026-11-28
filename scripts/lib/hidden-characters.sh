# shellcheck shell=bash
# Finds the files of the library that hold a character a reader cannot see as it is, in their bytes or in their names
# (characters.jq says which): a NUL is found as any other, and a file that cannot be read ends the script with its
# name. A name is printed escaped (characters.jq: shown_name), and jq's own words, which would print it as it is, are
# never shown. Sourced by the lint step and by the tests that guard files of their own; needs jq and git, REPO_ROOT
# and die (common.sh).

readonly CHARACTER_RULES="$REPO_ROOT/scripts/lib"

# Prints the files of the checkout under the folder that are no link, one name for each, NUL-ended: tracked or not yet
# tracked, and not ignored (.cache is), dotfiles and subfolders included.
files_of_the_library() {
  local file
  while IFS= read -r -d '' file; do
    [[ -f "$1/$file" && ! -L "$1/$file" ]] && printf '%s\0' "$1/$file"
  done < <(git -C "$1" ls-files -z --cached --others --exclude-standard)
  return 0
}

# Prints each file given that holds a control character but tab and line end, a zero-width or invisible character, or
# a mark that turns text around, one name for each.
files_with_hidden_characters() {
  files_where_a_character 'is_hidden' "$@"
}

# Prints each file given that holds anything but printable ASCII, tab and line end, one name for each.
files_outside_printable_ascii() {
  files_where_a_character 'is_outside_printable_ascii' "$@"
}

# Prints each name given (a path) that holds a hidden character, a tab or a line end, escaped, one for each.
names_with_hidden_characters() {
  (($# > 0)) || return 0
  printf '%s\0' "$@" | jq --raw-input --slurp --raw-output -L "$CHARACTER_RULES" '
    include "characters";
    split("\u0000")[:-1][] | select(explode | any(is_hidden_in_a_name)) | shown_name
  '
}

# Prints each file given with a character the test names (a definition of characters.jq), one escaped name for each.
files_where_a_character() {
  local test=$1
  shift
  (($# > 0)) || return 0
  jq --raw-input --null-input --raw-output -L "$CHARACTER_RULES" "
    include \"characters\";
    [inputs | select(explode | any($test)) | input_filename] | unique[] | shown_name
  " "$@" 2>/dev/null || refuse_unreadable_file "$@"
}

# Ends the script naming the first file given that cannot be read as a file; when each can, the scan itself failed.
refuse_unreadable_file() {
  local file
  for file in "$@"; do
    [[ -f "$file" && -r "$file" ]] || die "$(shown_file_name "$file") could not be read for hidden characters;" \
      "every file of the library must be readable"
  done
  die "the scan for hidden characters failed (jq); check that jq is the version the dev shell gives"
}

# Prints the name escaped as the scan prints names.
shown_file_name() {
  printf '%s' "$1" | jq --raw-input --slurp --raw-output -L "$CHARACTER_RULES" 'include "characters"; shown_name'
}
