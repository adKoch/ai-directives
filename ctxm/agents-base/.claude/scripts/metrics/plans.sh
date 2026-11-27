# shellcheck shell=bash
# What the collector reads of the project besides its transcripts, for the roll-ups: the plans of ctxm/plans/ (the
# task names of their item headings and the time each file was first committed), the commits whose subject names
# a task (their number and size), and the release candidates of ctxm/releases/ (the names of the files). Each
# becomes numbers, task names and versions (rollup_facts.jq); no text is printed, kept or passed on. Read-only.
# Sourced by collect-metrics.sh; needs PROJECT, project_git (project.sh), refuse (tools.sh), metrics_jq (program.sh).

readonly PLANS_FOLDER=ctxm/plans RELEASES_FOLDER=ctxm/releases
# A plan file is read whole, so a longer one is left out.
readonly PLAN_LIMIT_BYTES=4194304

# Ends the collector when a symbolic link stands where the plans or the release candidates are read: the collector
# reads only files that are in the project.
refuse_linked_sources() {
  local place
  for place in "$PLANS_FOLDER" "$RELEASES_FOLDER"; do
    [[ ! -L "$PROJECT/$place" ]] || refuse "$place is a symbolic link: the collector reads only the project's own" \
      "files; remove the link; nothing was written"
  done
}

# Prints the facts of the roll-ups, one JSON object per line: the plans, the commits of each task, the candidates.
rollup_facts() {
  plan_facts
  commit_facts
  candidate_facts
}

# Prints the fact of each plan file of ctxm/plans/. A file that is no plain file, or longer than the limit, is a
# plan left out, and is never read.
plan_facts() (
  local file
  shopt -s nullglob
  for file in "$PROJECT/$PLANS_FOLDER"/*.md; do
    if [[ -f "$file" && ! -L "$file" ]] && is_within_plan_limit "$file"; then
      one_plan_fact "$file"
    else
      printf '{"kind":"plan","name":null}\n'
    fi
  done
)

# Answers whether a file is no longer than a plan may be, from its size alone: wc counts a plain file's bytes
# without reading them.
is_within_plan_limit() {
  local size
  size="$(wc -c <"$1")"
  ((size <= PLAN_LIMIT_BYTES))
}

# Prints the fact of one plan file; the plan's name is the file's name without `.md`.
one_plan_fact() {
  local file=$1 name="${1##*/}" first
  name="${name%.md}"
  first="$(first_commit_time "$PLANS_FOLDER/${name}.md")"
  # shellcheck disable=SC2016 # $name and $first are jq's
  metrics_jq "format rollup_facts" 'plan_facts($name; $first)' --raw-input --slurp --compact-output \
    --arg name "$name" --argjson first "$first" "$file"
}

# Prints the time of the first commit that touched a file of the project, in seconds, or null when none did.
first_commit_time() {
  local path=$1
  project_git rev-parse --verify --quiet HEAD >/dev/null || { printf 'null\n'; return 0; }
  GIT_LITERAL_PATHSPECS=1 project_git log --format=%ct -- "$path" \
    | jq --raw-input --slurp '[split("\n")[] | select(test("\\A[0-9]{1,12}\\z")) | tonumber] | min'
}

# Prints, for each task a commit's subject names, how many commits it has and how many lines they changed.
commit_facts() {
  project_git rev-parse --verify --quiet HEAD >/dev/null || return 0
  project_git log --no-merges --format='C%x09%s' --numstat HEAD \
    | metrics_jq "format rollup_facts" 'commit_facts' --null-input --raw-input --compact-output
}

# Prints the release candidates of ctxm/releases/, from the names of its plain files.
candidate_facts() {
  candidate_names | metrics_jq "format rollup_facts" 'candidate_facts' --null-input --raw-input --compact-output
}

# Prints the names of the plain files of ctxm/releases/ that look like a candidate record, one per line; the
# pattern keeps a line break out of a name.
candidate_names() (
  local file name
  shopt -s nullglob
  for file in "$PROJECT/$RELEASES_FOLDER"/*.md; do
    name="${file##*/}"
    if [[ -f "$file" && ! -L "$file" && "$name" =~ ^v[0-9.]+-rc\.[0-9]+\.md$ ]]; then
      printf '%s\n' "$name"
    fi
  done
)
