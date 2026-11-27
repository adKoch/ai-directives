# The text of a comparison, from what comparison.jq lays out: {setups, columns, items}. Every value read from a
# roll-up goes through the collector's `field_text`; the places a person gave come escaped from projects.sh. Pure;
# needs the collector's format.jq and rollup_text.jq (table), and figures.jq. Read from the bottom (comparison_text)
# up.

# A column's name: its setup and its plan.
def column_names: map("setup \(.setup), \(.plan | field_text)");

def rule($count): "|\([range($count)] | map("---") | join("|"))|";

# A row of a figure: its name, then its value in each column, `none` in a column that lacks the item.
def figure_row($columns; $at):
  "| \(.) | \($columns | map(if . == null then nothing else .[$at][1] end | field_text) | join(" | ")) |";

# A table with a row per figure and a column per setup and plan; $columns holds each one's figures, or null.
def figure_table($names; $columns):
  ($columns | map(select(. != null)) | first | map(.[0])) as $figures
  | ["| figure | \($names | join(" | ")) |", rule(($names | length) + 1)]
    + ($figures | to_entries | map(.key as $at | .value | figure_row($columns; $at)));

# The figures of the item in a column's roll-up (the input: a column), or null when the roll-up has no such item.
def figures_of_item($item): [.rollup.items[] | select(.item == $item) | item_figures] | first;

def item_section($columns):
  . as $item
  | ["### Item \($item | field_text)", ""]
    + figure_table($columns | column_names; $columns | map(figures_of_item($item)))
    + [""];

# Every plan of every setup in one table, then each item once, with the same columns.
def plans_section:
  .columns as $columns
  | ["## Plans", ""]
    + figure_table($columns | column_names; $columns | map(.rollup | plan_figures))
    + ["", "## Items", ""]
    + (.items | map(item_section($columns)) | add // []);

# A row per fingerprint of each setup: a setup made of several has several rows.
def setup_rows:
  map(. as $setup | .fingerprints[] | [$setup.setup, $setup.project, .templates, .roles] | map(field_text)
    | "| \(.[0]) | \(.[1]) | \($setup.shown) | \(.[2]) | \(.[3]) |");

def setups_section:
  ["## Setups", "", "| setup | project | given as | templates | roles |", rule(5)] + setup_rows + [""];

def introduction: [
  "# Setups side by side",
  "",
  "Read by compare-setups.sh from the roll-ups in ctxm/metrics/ of each project given: numbers, times, checked names",
  "and fixed words only. A setup is a project with its templates and roles; a roll-up made under several of them is",
  "one setup, with a row for each below. Each column is one plan of one setup, whatever the plans are named: later",
  "releases of a project and the plans of other projects stand side by side. Items are matched by task name; `none`:",
  "the column's plan has no line of that item. `unknown`: the roll-up has no source for it. Coverage `partial`: the",
  "project's metrics start after the plan's first commit, so what ended before the start is in no number of that",
  "plan. The rules: docs/compare-setups.md of the template library.",
  ""
];

# The text of the comparison the input lays out.
def comparison_text:
  (introduction + (.setups | setups_section) + plans_section) | join("\n");
