# shellcheck shell=bash
# The collector's only place to write: ctxm/metrics/ of the project.
#   ctxm/metrics/start      where the project's metrics start (one time, written by the first collection)
#   ctxm/metrics/tasks.csv  the lines
# A file is replaced whole, by a rename: an interrupted collection leaves what was there. Nothing here follows a
# symbolic link: a link on the way would let a write land outside the project.
# Sourced by collect-metrics.sh; needs PROJECT (project.sh) and refuse (tools.sh).

readonly METRICS_FOLDER=ctxm/metrics
readonly START_FILE=$METRICS_FOLDER/start TASKS_FILE=$METRICS_FOLDER/tasks.csv
# The file a write is prepared in, until the rename; empty when no write is under way.
PREPARED_FILE=''

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

# Replaces a file of ctxm/metrics/ with the content, whole or not at all. The file is prepared under a name of
# this collector's own, so a second collector at the same time can neither remove it nor rename it into place.
store() {
  local file=$1 content=$2
  mkdir -p -- "$PROJECT/$METRICS_FOLDER"
  PREPARED_FILE="$PROJECT/$file.new.$$"
  rm -f -- "$PREPARED_FILE"
  write_new_file "$PREPARED_FILE" "$content"
  mv -f -- "$PREPARED_FILE" "$PROJECT/$file"
  PREPARED_FILE=''
}

# Writes a file that must not be there yet: never through a link someone put in its place.
write_new_file() (
  set -o noclobber
  printf '%s\n' "$2" >"$1"
)

# Removes the file of a write that did not reach its rename; collect-metrics.sh calls it when the collector ends.
discard_prepared_file() {
  [[ -z "$PREPARED_FILE" ]] || rm -f -- "$PREPARED_FILE"
}
