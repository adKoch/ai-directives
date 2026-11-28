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
# Sourced by collect-metrics.sh; needs PROJECT (project.sh), the checks of places.sh and remove_abandoned_files
# (leftovers.sh).

readonly METRICS_FOLDER=ctxm/metrics
# shellcheck disable=SC2034 # TASKS_FILE and COUNTED_FILE are read by places.sh, telling.sh and collect-metrics.sh
readonly START_FILE=$METRICS_FOLDER/start TASKS_FILE=$METRICS_FOLDER/tasks.csv
# shellcheck disable=SC2034 # read by places.sh and collect-metrics.sh
readonly COUNTED_FILE=$METRICS_FOLDER/counted.csv
# The places a write is prepared for, in the order they are renamed into; empty when no write is under way.
PREPARED_PLACES=()
# The places whose rename has begun, so whose old file must be put back if the write stops before its end. A place
# is named here before its rename: a stop right after the rename returns still finds it.
RENAMED_PLACES=()
# The places a stopped write could not put back: each keeps its old file (`<file>.old.<process id>`) for good.
UNRESTORED_PLACES=()

has_stored() {
  [[ -f "$PROJECT/$1" ]]
}

# Prints what the start record holds.
stored_start() {
  printf '%s\n' "$(<"$PROJECT/$START_FILE")"
}

# Replaces a file of ctxm/metrics/ with the content, whole or not at all.
store() {
  begin_write
  prepare_file "$1" "$2"
  publish_prepared
}

# Starts a write, before its first file is prepared: ends the collector when it may not write where the files go
# (places.sh), and removes the new files a killed collector left (leftovers.sh).
begin_write() {
  refuse_unwritable_store
  remove_abandoned_files
}

# Prepares the new content of a file under a name of this collector's own, so a second collector at the same time
# can neither remove it nor rename it into place. Nothing is replaced before publish_prepared.
prepare_file() {
  local place="$PROJECT/$1"
  refuse_folder_in_the_way "$1"
  run_escaped mkdir -p -- "$PROJECT/$METRICS_FOLDER"
  run_escaped rm -f -- "$(prepared_name "$place")"
  PREPARED_PLACES+=("$place")
  run_escaped write_new_file "$(prepared_name "$place")" "$2"
}

prepared_name() {
  printf '%s.new.%s\n' "$1" "$$"
}

kept_name() {
  printf '%s.old.%s\n' "$1" "$$"
}

# Renames every prepared file into place, the last step of a collection: the old files are kept first, and dropped
# only once every rename is done. A signal during the last rename is acted on when it returns, and puts the old
# files back; once the collector has gone past the renames, the write is whole and no signal stops it.
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
