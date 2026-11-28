# shellcheck shell=bash
# What a collector that is gone left in ctxm/metrics/: files under the second names the collector gives its own files
# while it writes (store.sh), `<own file>.new.<its process id>` and `<own file>.old.<its process id>`. Only a name of
# the collector's own (format.jq: is_leftover_name) is touched or counted: a file of the folder that is none of them
# (another setup's roll-up, a note) is never read, changed or removed, whatever its name looks like. The own names are
# plain ASCII, so they are printed as they are. A step here that fails ends the collector, so no leftover goes unseen.
# Sourced by collect-metrics.sh; needs PROJECT and METRICS_FOLDER (store.sh), metrics_jq (program.sh) and refuse
# (tools.sh).

# Removes the new files a killed collector left, when that process is gone; the files of a collector that still runs
# are never touched, nor any old file kept (refuse_unsettled_files), nor a folder: the collector makes none there, so
# a folder of such a name is none of its files. Called once per write (begin_write), before its first file is prepared.
remove_abandoned_files() {
  local names name path
  names="$(left_by_gone_collectors new)"
  while IFS= read -r name; do
    path="$PROJECT/$METRICS_FOLDER/$name"
    [[ -z "$name" ]] || [[ -d "$path" && ! -L "$path" ]] || rm -f -- "$path"
  done <<<"$names"
}

# Ends the collector when a collector that is gone left an old file it kept: the only copy of bytes a stopped write
# could not put back, or of a write a kill cut off. Nothing is written until a person has moved each over its file or
# removed it; a collector that still runs is left alone. The line names the first and counts all.
refuse_unsettled_files() {
  local names files
  names="$(left_by_gone_collectors old)"
  [[ -n "$names" ]] || return 0
  mapfile -t files <<<"$names"
  refuse "$METRICS_FOLDER/ holds ${#files[@]} old file(s) a stopped collection kept, the first ${files[0]};" \
    "move each over its file (the name without .old.<process id>), or remove it once its file is right;" \
    "nothing was written"
}

# Prints the name of each file `<own file>.<kind>.<process id>` of ctxm/metrics/ (kind `new` or `old`) whose process
# is gone, in byte order.
left_by_gone_collectors() {
  local names name
  names="$(own_leftover_names "$1")"
  while IFS= read -r name; do
    [[ -z "$name" ]] || kill -0 "${name##*.}" 2>/dev/null || printf '%s\n' "$name"
  done <<<"$names"
}

# Prints the name of each file `<own file>.<kind>.<process id>` of ctxm/metrics/, in byte order whatever the caller's
# locale.
own_leftover_names() (
  local kind=$1 LC_ALL=C paths=()
  shopt -s nullglob
  paths=("$PROJECT/$METRICS_FOLDER"/*."$kind".*)
  ((${#paths[@]} > 0)) || return 0
  # shellcheck disable=SC2016 # $kind is jq's
  printf '%s\0' "${paths[@]##*/}" | metrics_jq format '
    split("\u0000")[:-1][] | select(is_leftover_name($kind))
  ' --raw-input --slurp --raw-output --arg kind "$kind"
)
