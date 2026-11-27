# shellcheck shell=bash
# The collector's only place to write: ctxm/metrics/ of the project.
#   ctxm/metrics/start      where the project's metrics start (one time, written by the first collection)
#   ctxm/metrics/tasks.csv  the lines
# A file is replaced whole, by a rename: an interrupted collection leaves what was there. Nothing here follows a
# symbolic link: a link on the way would let a write land outside the project.
# Sourced by collect-metrics.sh; needs PROJECT (project.sh) and refuse (tools.sh).

readonly METRICS_FOLDER=ctxm/metrics
readonly START_FILE=$METRICS_FOLDER/start TASKS_FILE=$METRICS_FOLDER/tasks.csv
# The files a write is prepared in, each with the file it replaces; empty when no write is under way.
declare -A PREPARED_FILES=()

# Ends the collector when a symbolic link, or anything but a folder or a plain file, stands where the collector
# reads and writes.
refuse_unsafe_store() {
  local place
  for place in ctxm "$METRICS_FOLDER" "$START_FILE" "$TASKS_FILE"; do
    [[ ! -L "$PROJECT/$place" ]] || refuse "$place is a symbolic link: the collector writes only the project's own" \
      "$METRICS_FOLDER/; remove the link; nothing was written"
  done
  for place in ctxm "$METRICS_FOLDER"; do
    [[ ! -e "$PROJECT/$place" || -d "$PROJECT/$place" ]] || refuse "$place is no folder; nothing was written"
  done
  for place in "$START_FILE" "$TASKS_FILE"; do
    [[ ! -e "$PROJECT/$place" || -f "$PROJECT/$place" ]] || refuse "$place is no plain file; nothing was written"
  done
}

has_stored() {
  [[ -f "$PROJECT/$1" ]]
}

# Prints what the start record holds.
stored_start() {
  printf '%s\n' "$(<"$PROJECT/$START_FILE")"
}

# Replaces a file of ctxm/metrics/ with the content, whole or not at all.
store() {
  prepare_file "$1" "$2"
  publish_prepared
}

# Prepares the new content of a file under a name of this collector's own, so a second collector at the same time
# can neither remove it nor rename it into place. Nothing is replaced before publish_prepared.
prepare_file() {
  local file=$1 content=$2 prepared="$PROJECT/$1.new.$$"
  mkdir -p -- "$PROJECT/$METRICS_FOLDER"
  remove_abandoned_files
  rm -f -- "$prepared"
  PREPARED_FILES["$prepared"]="$PROJECT/$file"
  write_new_file "$prepared" "$content"
}

# Renames every prepared file into place: the last step of a collection, so a collection that fails before it
# replaces nothing.
publish_prepared() {
  local prepared
  for prepared in "${!PREPARED_FILES[@]}"; do
    mv -f -- "$prepared" "${PREPARED_FILES[$prepared]}"
    unset "PREPARED_FILES[$prepared]"
  done
}

# Writes a file that must not be there yet: never through a link someone put in its place.
write_new_file() (
  set -o noclobber
  printf '%s\n' "$2" >"$1"
)

# Removes the files a collector that was killed left (`<file>.new.<its process id>`) when that process is gone; the
# files of a collector that still runs are never touched.
remove_abandoned_files() (
  local file process
  shopt -s nullglob
  for file in "$PROJECT/$METRICS_FOLDER"/*.new.*; do
    process="${file##*.new.}"
    [[ "$process" =~ ^[0-9]+$ ]] || continue
    kill -0 "$process" 2>/dev/null || rm -f -- "$file"
  done
)

# Removes the files of a write that did not reach its rename; collect-metrics.sh calls it when the collector ends.
discard_prepared_files() {
  local prepared
  for prepared in "${!PREPARED_FILES[@]}"; do
    rm -f -- "$prepared"
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
