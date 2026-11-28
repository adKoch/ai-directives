# shellcheck shell=bash
# Finds the files of the library that hold a character a reader cannot see as it is, reading their bytes (characters.jq
# says which): a NUL is found as any other, and a file that cannot be read ends the script with its name. Sourced by
# the lint step and by the tests that guard files of their own; needs jq and git, REPO_ROOT and die (common.sh).

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

# Prints each file given with a character the test names (a definition of characters.jq), one name for each, with every
# byte but a letter, a digit, `/` `-` `_` `.` `~` written as `%` and two hex digits: a name may hold what it is searched
# for.
files_where_a_character() {
  local test=$1
  shift
  ((${#@} > 0)) || return 0
  jq --raw-input --null-input --raw-output -L "$REPO_ROOT/scripts/lib" "
    include \"characters\";
    [inputs | select(explode | any($test)) | input_filename] | unique[] | @uri | gsub(\"%2F\"; \"/\")
  " "$@" || die "a file could not be read for hidden characters; every file of the library must be readable"
}
