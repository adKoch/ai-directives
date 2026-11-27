# shellcheck shell=bash
# What the comparison reads of the projects given: the roll-up files of each one's ctxm/metrics/. Every place is
# checked where it stands before any file is read, and each roll-up becomes a fact for the rules (comparison.jq).
# Read-only: it writes nothing, anywhere. A place from outside is printed only through `shown`.
# Sourced by compare-setups.sh; needs PROJECT_FOLDERS (compare-setups.sh), comparison_jq (program.sh) and die
# (scripts/lib/common.sh).

readonly METRICS_FOLDER=ctxm/metrics
readonly MOST_PROJECTS=8 MOST_ROLLUPS=100
# A roll-up is read whole, so its size and the size of all together are checked, from the file system, first.
readonly ROLLUP_LIMIT_BYTES=1048576 READ_LIMIT_BYTES=16777216

# The checked roll-up files, and the index in PROJECT_FOLDERS of each one's project.
ROLLUP_FILES=()
ROLLUP_PROJECTS=()

# Finds the roll-up files of every project given (ROLLUP_FILES, ROLLUP_PROJECTS), or ends the comparison with one
# line naming the first place that is not safe to read.
find_rollups() {
  local index
  ((${#PROJECT_FOLDERS[@]} <= MOST_PROJECTS)) || die "more than $MOST_PROJECTS projects given; compare fewer at once"
  for index in "${!PROJECT_FOLDERS[@]}"; do
    refuse_unsafe_project "${PROJECT_FOLDERS[index]}"
    find_project_rollups "$index"
  done
  refuse_too_much_to_read
}

refuse_too_much_to_read() {
  local file bytes read_bytes=0
  for file in "${ROLLUP_FILES[@]}"; do
    bytes="$(file_bytes "$file")" || refuse_unreadable "$file"
    read_bytes=$((read_bytes + bytes))
  done
  ((read_bytes <= READ_LIMIT_BYTES)) || die "the roll-ups given hold more than $READ_LIMIT_BYTES bytes together;" \
    "compare fewer projects at once"
}

# Ends the comparison unless the folder holds a ctxm/metrics/ folder of its own, open to it, that no collection left
# unsettled.
refuse_unsafe_project() {
  local folder=$1 metrics="$1/$METRICS_FOLDER"
  [[ -d "$folder" ]] || refuse_place "$folder" "is no folder; give the folder of a project"
  [[ ! -L "$folder/ctxm" && ! -L "$metrics" ]] || refuse_place "$metrics" "is reached through a symbolic link:" \
    "the comparison reads only a project's own ctxm/metrics/; remove the link"
  [[ -d "$metrics" ]] || refuse_place "$folder" "has no ctxm/metrics/ folder: its metrics have not started"
  [[ -r "$metrics" && -x "$metrics" ]] || refuse_place "$metrics" "could not be read; let the comparison read it and" \
    "list its files"
  refuse_unsettled_metrics "$metrics"
}

# A file an interrupted collection kept (docs/metrics-format.md, Files) means the roll-ups may be a mix of two.
refuse_unsettled_metrics() {
  local kept=()
  shopt -s nullglob dotglob
  kept=("$1"/*.old.[0-9]*)
  shopt -u nullglob dotglob
  ((${#kept[@]} == 0)) || refuse_place "${kept[0]}" "is a file an interrupted collection kept, so the roll-ups" \
    "may be a mix; settle it as docs/metrics-format.md (Files) says"
}

# Adds the roll-up files of the project to ROLLUP_FILES: every .md file of its ctxm/metrics/, each a plain file
# within the limit. Its name is checked by the rules, which refuse a file that is no roll-up.
find_project_rollups() {
  local index=$1 metrics file found=()
  metrics="${PROJECT_FOLDERS[index]}/$METRICS_FOLDER"
  shopt -s nullglob dotglob
  found=("$metrics"/*.md)
  shopt -u nullglob dotglob
  ((${#found[@]} > 0)) || refuse_place "$metrics" "holds no roll-up: no plan of the project has lines yet"
  ((${#found[@]} <= MOST_ROLLUPS)) || refuse_place "$metrics" "holds more than $MOST_ROLLUPS roll-ups; compare" \
    "a project with fewer, or move the files that are no roll-up of a plan out of the folder"
  for file in "${found[@]}"; do
    refuse_unsafe_rollup "$file"
    ROLLUP_FILES+=("$file")
    ROLLUP_PROJECTS+=("$index")
  done
}

refuse_unsafe_rollup() {
  local bytes
  [[ -f "$1" && ! -L "$1" ]] || refuse_place "$1" "is no plain file, so no roll-up; move it out of the folder"
  bytes="$(file_bytes "$1")" || refuse_unreadable "$1"
  ((bytes <= ROLLUP_LIMIT_BYTES)) || refuse_place "$1" "is larger than a roll-up may be" \
    "($ROLLUP_LIMIT_BYTES bytes), so it is not read; move it out of the folder"
}

# Prints a plain file's size: wc counts its bytes without reading them. A file that cannot be opened fails it, without
# bash's own line, which would print the place as it is.
file_bytes() {
  { wc -c <"$1"; } 2>/dev/null
}

# Prints the facts of the rules, one JSON object per line: each project given, then each roll-up with its text.
rollup_facts() {
  local index
  for index in "${!PROJECT_FOLDERS[@]}"; do
    # shellcheck disable=SC2016 # $project and $shown are jq's
    comparison_jq '' '{kind: "project", project: $project, shown: $shown}' --null-input --compact-output \
      --argjson project "$index" --arg shown "$(shown "${PROJECT_FOLDERS[index]}")"
  done
  for index in "${!ROLLUP_FILES[@]}"; do
    rollup_fact "${ROLLUP_FILES[index]}" "${ROLLUP_PROJECTS[index]}"
  done
}

rollup_fact() {
  local file=$1 project=$2
  # shellcheck disable=SC2016 # the $ names are jq's
  jq --null-input --compact-output --argjson project "$project" --arg file "${file##*/}" \
    --arg shown "$(shown "$file")" --rawfile text "$file" \
    '{kind: "rollup", project: $project, file: $file, shown: $shown, text: $text}' 2>/dev/null \
    || refuse_unreadable "$file"
}

refuse_unreadable() {
  refuse_place "$1" "could not be read; let the comparison read it, or move it out of the folder"
}

# Ends the comparison with one line naming the place.
refuse_place() {
  local place=$1
  shift
  die "$(shown "$place") $*"
}

# Prints a place from outside as it may be printed: every byte that is no printable ASCII (a control character,
# an escape sequence, a character that turns text around) written as an escape, as bash's %q writes it.
shown() {
  local LC_ALL=C
  printf '%q\n' "$1"
}
