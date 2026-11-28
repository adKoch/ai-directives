# shellcheck shell=bash
# What a collector that is gone left in ctxm/metrics/: files under the second names the collector gives its own files
# while it writes (store.sh), `<own file>.new.<its process id>` and `<own file>.old.<its process id>`. Only a name of
# the collector's own is touched or counted: a file of the folder that is none of them (another setup's roll-up, a
# note) is never read, changed or removed, whatever its name looks like. The own names are plain ASCII, so they are
# printed as they are.
# Sourced by collect-metrics.sh; needs PROJECT and METRICS_FOLDER (store.sh) and refuse (tools.sh).

# The collector's own files: start, tasks.csv, counted.csv and a plan's roll-up (format.jq: is_plan_name).
readonly OWN_FILE='(start|tasks\.csv|counted\.csv|[A-Za-z0-9]+([._-][A-Za-z0-9]+){0,15}\.md)'
readonly MOST_PLAN_NAME_LENGTH=64
# A process id as the system gives one; never 0, which would signal the whole group.
readonly PROCESS_ID='[1-9][0-9]{0,9}'

# Removes the new files a killed collector left, when that process is gone; the files of a collector that still runs
# are never touched, nor any old file kept (refuse_unsettled_files). Called once per write, before its first file is
# prepared.
remove_abandoned_files() {
  local file
  while IFS= read -r file; do
    rm -f -- "$file"
  done < <(left_by_gone_collectors new)
}

# Ends the collector when a collector that is gone left an old file it kept: the only copy of bytes a stopped write
# could not put back, or of a write a kill cut off. Nothing is written until a person has moved each over its file or
# removed it; a collector that still runs is left alone. The line names the first and counts all.
refuse_unsettled_files() {
  local files
  mapfile -t files < <(left_by_gone_collectors old)
  ((${#files[@]} == 0)) && return
  refuse "$METRICS_FOLDER/ holds ${#files[@]} old file(s) a stopped collection kept, the first ${files[0]##*/};" \
    "move each over its file (the name without .old.<process id>), or remove it once its file is right;" \
    "nothing was written"
}

# Prints the path of each file `<own file>.<kind>.<process id>` of ctxm/metrics/ (kind `new` or `old`) whose process is
# gone, in byte order.
left_by_gone_collectors() (
  local kind=$1 file name process
  shopt -s nullglob
  for file in "$PROJECT/$METRICS_FOLDER"/*."$kind".*; do
    name="${file##*/}"
    process="${name##*.}"
    is_process_id "$process" || continue
    is_own_file_name "${name%".$kind.$process"}" || continue
    kill -0 "$process" 2>/dev/null || printf '%s\n' "$file"
  done
)

# Answers whether the text is a process id.
is_process_id() {
  [[ "$1" =~ ^$PROCESS_ID$ ]]
}

# Answers whether the name is one of the collector's own files.
is_own_file_name() {
  [[ "$1" =~ ^$OWN_FILE$ ]] || return 1
  [[ "$1" != *.md || ${#1} -le $((MOST_PLAN_NAME_LENGTH + 3)) ]]
}
