# shellcheck shell=bash
# The collector's only place to write: ctxm/metrics/ of the project.
#   ctxm/metrics/start        where the project's metrics start (one time, written by the first collection)
#   ctxm/metrics/tasks.csv    the lines
#   ctxm/metrics/counted.csv  the record of what the lines counted, by id (counted.jq); written with tasks.csv
#   ctxm/metrics/<plan>.md    the roll-ups
# A collection's files are written all or nothing: each is prepared beside its place, the old one kept under a
# second name, then all are renamed into place; a collection stopped or failing before the last rename puts back
# every file it had replaced (end_collector). Nothing here follows a symbolic link: a link on the way would let a
# write land outside the project.
# Sourced by collect-metrics.sh; needs PROJECT (project.sh) and refuse (tools.sh).

readonly METRICS_FOLDER=ctxm/metrics
readonly START_FILE=$METRICS_FOLDER/start TASKS_FILE=$METRICS_FOLDER/tasks.csv
readonly COUNTED_FILE=$METRICS_FOLDER/counted.csv
# tasks.csv and its record are read whole, so a larger file is refused: both are committed files another tool or a person
# may edit.
readonly LINES_LIMIT_BYTES=16777216
# The places a write is prepared for, in the order they are renamed into; empty when no write is under way.
PREPARED_PLACES=()
# The places whose rename has begun, so whose old file must be put back if the write stops before its end. A place
# is named here before its rename: a stop right after the rename returns still finds it.
RENAMED_PLACES=()
# The places a stopped write could not put back: each keeps its old file (`<file>.old.<process id>`) for good.
UNRESTORED_PLACES=()

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

# Ends the collector when tasks.csv or its record is empty (0 bytes) or larger than the collector reads. A missing file is
# another case (counted.jq), and an empty one is no missing one: the collector never writes either.
refuse_unfit_lines_files() {
  local place bytes
  for place in "$TASKS_FILE" "$COUNTED_FILE"; do
    has_stored "$place" || continue
    bytes="$(wc -c <"$PROJECT/$place")"
    ((bytes > 0)) || refuse "$place is empty (0 bytes); restore it from git; nothing was written"
    ((bytes <= LINES_LIMIT_BYTES)) || refuse "$place is larger than the collector reads ($LINES_LIMIT_BYTES bytes);" \
      "nothing was written"
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
  remove_abandoned_files
  prepare_file "$1" "$2"
  publish_prepared
}

# Prepares the new content of a file under a name of this collector's own, so a second collector at the same time
# can neither remove it nor rename it into place. Nothing is replaced before publish_prepared.
prepare_file() {
  local place="$PROJECT/$1"
  mkdir -p -- "$PROJECT/$METRICS_FOLDER"
  rm -f -- "$(prepared_name "$place")"
  PREPARED_PLACES+=("$place")
  write_new_file "$(prepared_name "$place")" "$2"
}

prepared_name() {
  printf '%s.new.%s\n' "$1" "$$"
}

kept_name() {
  printf '%s.old.%s\n' "$1" "$$"
}

# Renames every prepared file into place, the last step of a collection: the old files are kept first, and dropped
# only once every rename is done. From the last rename on, the write is whole: a signal no longer stops the
# collector, so it never reports as stopped a collection that wrote everything.
publish_prepared() {
  local place
  keep_old_files
  for place in "${PREPARED_PLACES[@]}"; do
    RENAMED_PLACES+=("$place")
    mv -f -T -- "$(prepared_name "$place")" "$place"
  done
  trap '' TERM INT HUP
  RENAMED_PLACES=()
  discard_written_files
}

# Keeps each file a write replaces under a second name (a hard link: the same bytes, nothing copied).
keep_old_files() {
  local place
  for place in "${PREPARED_PLACES[@]}"; do
    rm -f -- "$(kept_name "$place")"
    [[ ! -e "$place" ]] || ln -P -T -- "$place" "$(kept_name "$place")"
  done
}

# Writes a file that must not be there yet: never through a link someone put in its place.
write_new_file() (
  set -o noclobber
  printf '%s\n' "$2" >"$1"
)

# Puts back the old file of every place a stopped write had begun to rename (unless the rename never happened, so
# the place is still its old file), and removes the new file of a place that had none (a folder put there meanwhile
# is left); collect-metrics.sh calls it when the collector ends. A place that cannot be put back is named in
# UNRESTORED_PLACES, and its old file stays.
restore_renamed_files() {
  local place
  for place in "${RENAMED_PLACES[@]}"; do
    restore_place "$place" || UNRESTORED_PLACES+=("$place")
  done
  RENAMED_PLACES=()
}

restore_place() {
  local place=$1 kept
  kept="$(kept_name "$place")"
  if [[ -e "$kept" ]]; then
    [[ "$kept" -ef "$place" ]] || mv -f -T -- "$kept" "$place"
  elif [[ ! -d "$place" ]]; then
    rm -f -- "$place"
  fi
}

# Removes this collector's working files: the prepared files a write did not rename, and the old files it kept,
# except the old file of a place it could not put back (the only copy of those bytes).
discard_written_files() {
  local place
  for place in "${PREPARED_PLACES[@]}"; do
    rm -f -- "$(prepared_name "$place")"
    is_unrestored "$place" || rm -f -- "$(kept_name "$place")"
  done
  PREPARED_PLACES=()
}

is_unrestored() {
  local place
  for place in "${UNRESTORED_PLACES[@]}"; do
    [[ "$place" != "$1" ]] || return 0
  done
  return 1
}

# Ends the collector when a roll-up's place is a symbolic link or anything but a plain file: a write there would
# land outside the project, or inside a folder.
refuse_unsafe_rollup() {
  local place="$METRICS_FOLDER/$1.md"
  [[ ! -L "$PROJECT/$place" ]] || refuse "$place is a symbolic link: the collector writes only the project's own" \
    "$METRICS_FOLDER/; remove the link; nothing was written"
  [[ ! -e "$PROJECT/$place" || -f "$PROJECT/$place" ]] || refuse "$place is no plain file; nothing was written"
}
