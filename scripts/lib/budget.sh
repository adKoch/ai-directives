# shellcheck shell=bash
# The time budget of the library's scripts. Sourced by common.sh. A script takes its budget with one line, after its
# tools are checked:
#   ensure_budget "$@"
# The script then runs again as a process group of its own, while the first shell (the holder) keeps the time. Over
# the budget, the holder stops the whole group and says which budget was hit; a signal that ends the holder stops the
# group first. So nothing a budgeted script starts may leave its group: no `setsid`, `timeout` only with
# `--foreground`.
# Limits: the run starts with INT and QUIT ignored (bash does that to a background command; the holder answers
# them), and a holder that is killed outright (KILL) leaves the run to the group's own `timeout`, which ends it
# a little after the budget.

readonly BUDGET_VARIABLE=LIBRARY_BUDGET_SECONDS
readonly DEFAULT_BUDGET_SECONDS=300
# How long a stopped run gets to end by itself (TERM) before what is left of it is killed (KILL).
readonly STOP_GRACE_SECONDS=5
# What run_within_budget returns for a run it stopped over its budget; a run's own 124 comes back as 1.
readonly OVER_BUDGET=124

# Runs the calling script again within its budget and ends with its result, unless a budget already covers this run
# (a script called by a budgeted script runs inside the caller's budget).
ensure_budget() {
  if [[ -n "${LIBRARY_WITHIN_BUDGET:-}" ]]; then
    return
  fi
  local seconds status=0
  seconds="$(budget_seconds)"
  run_within_budget "$seconds" "$(script_path)" "$@" || status=$?
  if ((status == OVER_BUDGET)); then
    die "$(shown_script_path) stopped: over its budget of ${seconds}s ($BUDGET_VARIABLE sets it)"
  fi
  exit "$status"
}

budget_seconds() {
  local seconds="${!BUDGET_VARIABLE:-$DEFAULT_BUDGET_SECONDS}"
  [[ "$seconds" =~ ^[1-9][0-9]{0,4}$ ]] || die "$BUDGET_VARIABLE must be a whole number of seconds from 1 to 99999"
  printf '%s\n' "$seconds"
}

# Runs the command as a process group of its own, without input, and returns its status, or OVER_BUDGET when the
# budget ended first and the run was stopped. SECONDS counts whole seconds, so the deadline is one further on: a run
# is never stopped early, and at most a second late.
run_within_budget() {
  local seconds=$1 deadline status=0
  shift
  deadline=$((SECONDS + seconds + 1))
  start_run "$seconds" "$@"
  stop_run_when_signalled
  while run_goes_on && ((SECONDS < deadline)); do
    sleep 0.1
  done
  if run_goes_on; then
    stop_run
    status=$OVER_BUDGET
  else
    wait "$RUN_GROUP" || status=$?
    ((status != OVER_BUDGET)) || status=1
  fi
  trap - INT TERM HUP
  return "$status"
}

# `timeout` makes the run a process group, numbered by its PID. The holder keeps the time; the time `timeout` gets
# is only the backstop for a holder that was killed.
start_run() {
  local seconds=$1
  shift
  LIBRARY_WITHIN_BUDGET=1 timeout "$((seconds + 2 * STOP_GRACE_SECONDS))" "$@" </dev/null &
  RUN_GROUP=$!
}

# A signal that ends the holder stops the run first; the holder then ends with that signal's usual status.
stop_run_when_signalled() {
  trap 'stop_run; exit 130' INT
  trap 'stop_run; exit 143' TERM
  trap 'stop_run; exit 129' HUP
}

run_goes_on() {
  kill -0 "$RUN_GROUP" 2>/dev/null
}

# Ends every process of the run's group: TERM first, then KILL for what is left when the grace is over. The run is
# collected at the end, so bash adds no job line ("Terminated") to the output.
stop_run() {
  local polls_left=$((STOP_GRACE_SECONDS * 10))
  signal_run TERM
  while run_has_members && ((polls_left > 0)); do
    sleep 0.1
    polls_left=$((polls_left - 1))
  done
  signal_run KILL
  wait "$RUN_GROUP" 2>/dev/null || true
}

signal_run() {
  kill -"$1" -- "-$RUN_GROUP" 2>/dev/null || true
}

run_has_members() {
  kill -0 -- "-$RUN_GROUP" 2>/dev/null
}
