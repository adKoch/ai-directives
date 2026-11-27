# Reads a roll-up (ctxm/metrics/<plan>.md of another project) back into the numbers the collector made it from, as
# rollup.jq's `rollup_of` gives them. A text is taken only when the collector's own `rollup_text` writes it back
# byte for byte, so the comparison never takes anything from another project but numbers, times, checked names and
# the fixed words; any other text, a line added, a cell changed, a control character, is refused naming the file.
# Pure; needs the collector's format.jq, rollup.jq and rollup_text.jq. Read from the bottom (read_rollup) up.

def lines_of: split("\n");

def cells_of: ltrimstr("| ") | rtrimstr(" |") | split(" | ");

# The rows of the table under that header, each as its cells; none when the text has no such table.
def rows($headers):
  ("| \($headers | join(" | ")) |") as $head
  | (indices([$head]) | first) as $at
  | if $at == null then []
    else .[$at + 2:] | (map(startswith("| ")) | index(false)) as $end | .[:$end] | map(cells_of)
    end;

# The value of the bullet `- <what>: <value>`; null when the text has none.
def bullet($what): first(.[] | select(startswith("- \($what): ")) | ltrimstr("- \($what): ")) // null;

def count: if matches("[0-9]{1,16}") then tonumber else error("no count") end;
def count_or_unknown: if . == unknown then . else count end;
def time_or_null: if . == unknown then null else time_seconds end;

def costs_of: map(count) | {
  runs: .[0], input: .[1], output: .[2], cache_read: .[3], cache_write: .[4], wall_seconds: .[5], compactions: .[6]
};

def cost_rows: rows(["item"] + cost_headers("runs"));

def item_of($flow; $product):
  {item: .[0], rounds: ($flow[1] | count)} + (.[1:] | costs_of)
  + {commits: ($product[1] | count_or_unknown), added: ($product[2] | count_or_unknown),
    deleted: ($product[3] | count_or_unknown)};

def items:
  (rows(["item", "rounds", "at the round limit"])) as $flow
  | (rows(["item", "commits", "lines added", "lines deleted"])) as $product
  | cost_rows[:-1] | to_entries | map(.key as $at | .value | item_of($flow[$at]; $product[$at]));

def main_row: rows(["from", "to"] + cost_headers("lines")) | first;

def review_roles: rows(["role", "reports", "blocking", "nits"])
  | map({role: .[0], reports: (.[1] | count), blocking: (.[2] | count), nits: (.[3] | count)});

def review_items: rows(["item", "role", "reports", "blocking", "nits", "blocking by round", "nits by round"])
  | map({task: .[0], role: .[1], reports: (.[2] | count), blocking: (.[3] | count), nits: (.[4] | count),
    blocking_by_round: .[5], nits_by_round: .[6]});

def setups: rows(["templates", "roles", "lines"]) | map({templates: .[0], roles: .[1], lines: (.[2] | count)});

# The numbers of the text (its lines), as `rollup_of` gives them: what rollup_text writes from. A figure it writes as
# a fixed word (`unknown`) is not read; the write-back check holds the text to that word.
def parsed:
  main_row as $main
  | {
      plan: (first | ltrimstr("# Metrics of plan ")),
      project: bullet("project"),
      start: (bullet("metrics start") | time_seconds),
      first_commit: (bullet("plan first committed") | time_or_null),
      coverage: bullet("coverage"),
      setups: setups,
      items: items,
      total: (cost_rows | last | .[1:] | costs_of),
      review_roles: review_roles,
      review_items: review_items,
      defects_at_tests: (bullet("defects found at tests (blocking findings of the release-tester)") | count),
      candidates: (bullet("release candidates") | count_or_unknown),
      period: (if $main == null then null else {from: ($main[0] | time_seconds), to: ($main[1] | time_seconds)} end),
      main: (if $main == null then null else $main[2:] | costs_of end)
    };

def is_coverage: IN("whole", "partial", unknown);

# Whether the values the comparison shows are what the collector writes: the plan is the file's, each item a task
# name, the project a project name.
def is_shown_right($plan):
  .plan == $plan and (.project | is_project_name) and (.coverage | is_coverage)
  and all(.items[].item; is_task_name) and (.items | length) > 0;

# The roll-up the text (the input) holds, for the plan the file is named after; null when the text is not, byte for
# byte, what the collector writes for the numbers read from it.
def read_rollup($plan):
  . as $text
  | (try (lines_of | parsed | select(is_shown_right($plan) and rollup_text == $text)) catch null) // null;
