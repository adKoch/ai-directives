# shellcheck shell=bash
# The checks of the places the collector reads and writes in ctxm/metrics/ (store.sh), each ending the collector with
# its one refusal before any file is replaced: what stands there, how large it is, whether the collector may write
# there. A check here never changes a file.
# Sourced by collect-metrics.sh after store.sh; needs PROJECT (project.sh), refuse (tools.sh), and from store.sh the
# places METRICS_FOLDER, START_FILE, TASKS_FILE and COUNTED_FILE and the functions has_stored, prepared_name and
# kept_name.

# tasks.csv and its record are read whole, so a larger file is refused: both are committed files another tool or a
# person may edit.
readonly LINES_LIMIT_BYTES=16777216
# The start record holds one time, read whole and given to jq as an argument, so a larger file is refused.
readonly START_LIMIT_BYTES=64

# Ends the collector when a symbolic link, or anything but a folder or a plain file, stands where the collector
# reads and writes.
refuse_unsafe_store() {
  local place
  for place in ctxm "$METRICS_FOLDER" "$START_FILE" "$TASKS_FILE" "$COUNTED_FILE"; do
    [[ ! -L "$PROJECT/$place" ]] || refuse "$place is a symbolic link: the collector writes only the project's own" \
      "$METRICS_FOLDER/; remove the link; nothing was written"
  done
  for place in ctxm "$METRICS_FOLDER"; do
    [[ ! -e "$PROJECT/$place" || -d "$PROJECT/$place" ]] || refuse "$place is no folder; nothing was written"
  done
  for place in "$START_FILE" "$TASKS_FILE" "$COUNTED_FILE"; do
    [[ ! -e "$PROJECT/$place" || -f "$PROJECT/$place" ]] || refuse "$place is no plain file; nothing was written"
  done
}

# Ends the collector when the start record, tasks.csv or its record is larger than the collector reads.
refuse_oversized_files() {
  refuse_larger_than "$START_LIMIT_BYTES" "$START_FILE"
  refuse_larger_than "$LINES_LIMIT_BYTES" "$TASKS_FILE" "$COUNTED_FILE"
}

refuse_larger_than() {
  local limit=$1 place bytes
  shift
  for place in "$@"; do
    has_stored "$place" || continue
    bytes="$(wc -c <"$PROJECT/$place")"
    ((bytes <= limit)) || refuse "$place is larger than the collector reads ($limit bytes); restore it from git;" \
      "nothing was written"
  done
}

# Ends a later collection when tasks.csv or its record is empty (0 bytes) while the other is full: one of the two
# was lost, and the collector never writes an empty one. Beside an empty or missing partner, an empty file reads as
# a missing one (counted.jq), as it always has; the first collection reads neither.
refuse_lone_empty_lines_file() {
  refuse_empty_beside_full "$TASKS_FILE" "$COUNTED_FILE"
  refuse_empty_beside_full "$COUNTED_FILE" "$TASKS_FILE"
}

refuse_empty_beside_full() {
  has_stored "$1" && [[ ! -s "$PROJECT/$1" && -s "$PROJECT/$2" ]] || return 0
  refuse "$1 is empty (0 bytes); restore it from git; nothing was written"
}

# Ends the collector when it may not write in the folder a write lands in, so no tool prints its own words first.
refuse_unwritable_store() {
  local folder
  folder="$(nearest_store_folder)"
  [[ -w "$PROJECT/$folder" && -x "$PROJECT/$folder" ]] && return
  refuse "the collector may not write in ${folder:-the project folder}; let it write there, $METRICS_FOLDER/ is its" \
    "only place; nothing was written"
}

# Prints the folder a write lands in, or makes its first folder in: ctxm/metrics/ or ctxm/; nothing for the
# project's own folder.
nearest_store_folder() {
  local folder
  for folder in "$METRICS_FOLDER" ctxm; do
    [[ ! -d "$PROJECT/$folder" ]] || { printf '%s/\n' "$folder"; return 0; }
  done
}

# Ends the collector when a folder stands under a working name of this collector's for the file (a process of the
# same number made it): rm would not remove it, and the write would fail with that tool's own words.
refuse_folder_in_the_way() {
  local name
  for name in "$(prepared_name "$1")" "$(kept_name "$1")"; do
    [[ ! -d "$PROJECT/$name" || -L "$PROJECT/$name" ]] || refuse "$name is a folder where the collector keeps a" \
      "working file; remove it; nothing was written"
  done
}

# Ends the collector when a roll-up's place is a symbolic link or anything but a plain file: a write there would
# land outside the project, or inside a folder.
refuse_unsafe_rollup() {
  local place="$METRICS_FOLDER/$1.md"
  [[ ! -L "$PROJECT/$place" ]] || refuse "$place is a symbolic link: the collector writes only the project's own" \
    "$METRICS_FOLDER/; remove the link; nothing was written"
  [[ ! -e "$PROJECT/$place" || -f "$PROJECT/$place" ]] || refuse "$place is no plain file; nothing was written"
}
