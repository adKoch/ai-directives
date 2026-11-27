# The text of a roll-up (ctxm/metrics/<plan>.md), from the numbers of rollup.jq. Every value goes through
# `field_text`, so a value that is no number, fixed word or checked name stops the collection: a roll-up holds
# nothing but those and the fixed words of this file. Pure; needs format.jq. Read from the bottom (rollup_text) up.

def cells: map(field_text) | join(" | ") | "| \(.) |";

# A table: the header words, a rule, and a row for each list of values.
def table($headers; $rows):
  ["| \($headers | join(" | ")) |", "|\($headers | map("---") | join("|"))|"] + ($rows | map(cells));

def bullet($what; $value): "- \($what): \($value | field_text)";

def time_or_unknown: if . == null then unknown else time_text end;

def cost_cells: [.runs, .input, .output, .cache_read, .cache_write, .wall_seconds, .compactions];

def cost_headers($count): [
  $count, "input tokens", "output tokens", "cache read tokens", "cache write tokens", "wall seconds", "compactions"
];

def where_it_starts: [
  "## Where the metrics start",
  bullet("project"; .project),
  bullet("metrics start"; .start | time_text),
  bullet("plan first committed"; .first_commit | time_or_unknown),
  bullet("coverage"; .coverage),
  "Coverage is `partial` when the project's metrics start after the plan's first commit: what ended before the",
  "start is in no number below. `unknown` means no commit of the plan file is known.",
  ""
];

def setups_section:
  ["## Setups", ""] + table(["templates", "roles", "lines"]; .setups | map([.templates, .roles, .lines])) + [""];

def main_table:
  table(["from", "to"] + cost_headers("lines"); [[.period.from, .period.to | time_text] + (.main | cost_cells)]);

def cost_section:
  ["## Cost", ""]
  + table(["item"] + cost_headers("runs"); (.items | map([.item] + cost_cells)) + [["all"] + (.total | cost_cells)])
  + ["", "Main's sessions that overlap the plan's period (the plan file's first commit to the end of its last line),",
    "each counted whole:", ""]
  + (if .main == null then [bullet("main"; unknown)] else main_table end)
  + [""];

def round_state: if .rounds >= round_limit then "yes" else "no" end;

def flow_section:
  ["## Flow", ""]
  + table(["item", "rounds", "at the round limit"]; .items | map([.item, .rounds, round_state]))
  + ["", bullet("items at the round limit"; [.items[] | select(.rounds >= round_limit)] | length)]
  + (["exceptions", "replans", "out-of-plan requests", "proposals raised"] | map(bullet(.; unknown)))
  + [""];

def review_cells: [.reports, .blocking, .nits];

def review_section:
  ["## Review", "", "By role:", ""]
  + table(["role", "reports", "blocking", "nits"]; .review_roles | map([.role] + review_cells))
  + ["", "By item and role, each round in turn:", ""]
  + table(["item", "role", "reports", "blocking", "nits", "blocking by round", "nits by round"];
      .review_items | map([.task, .role] + review_cells + [.blocking_by_round, .nits_by_round]))
  + [""];

def escapes_section: [
  "## Escapes",
  bullet("defects found at tests (blocking findings of the release-tester)"; .defects_at_tests),
  bullet("release candidates"; .candidates),
  bullet("owner change requests at a candidate"; unknown),
  bullet("regressions on main"; unknown),
  bullet("check failures after a merge"; unknown),
  "",
  "## Owner effort",
  bullet("questions brought to the owner"; unknown),
  bullet("seconds items waited on the owner"; unknown),
  ""
];

def product_section:
  ["## Product", ""]
  + table(["item", "commits", "lines added", "lines deleted"]; .items | map([.item, .commits, .added, .deleted]))
  + ["", bullet("seconds of the minimal check on main"; unknown), bullet("tests added"; unknown), ""];

def introduction: [
  "Written by collect-metrics.sh from ctxm/metrics/tasks.csv, git and ctxm/: numbers, ids and fixed words only,",
  "never edited by hand. `unknown`: no source for it in those three. The rules: docs/metrics-format.md of the",
  "template library.",
  ""
];

# The text of the roll-up the input describes.
def rollup_text:
  (["# Metrics of plan \(.plan | field_text)", ""] + introduction
    + where_it_starts + setups_section + cost_section + flow_section
    + review_section + escapes_section + product_section)
  | join("\n");
