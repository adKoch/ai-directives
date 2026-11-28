# The comparison of setups: the roll-ups of the projects given, read back (reading.jq), grouped into setups and
# laid side by side: a column for each setup and plan, whatever the plans are named, and the items matched by task
# name across the columns. The input is the list of facts projects.sh prints: {kind: "project", project, shown} for
# each project given and {kind: "rollup", project, file, shown, text} for each roll-up file.
# `shown` is a place as it may be printed, escaped by projects.sh. Pure; needs the collector's format.jq,
# rollup.jq and rollup_text.jq, and reading.jq, figures.jq and comparison_text.jq. Read from the bottom
# (comparison) up.

# The plan a roll-up file is named after (`<plan>.md`), or null when its name is no plan name.
def file_plan: .file | select(endswith(".md")) | .[:-3] | select(is_plan_name);

def refuse_file($why): refuse("\(.shown) \($why)");

def unnamed_refusal:
  "is no roll-up: its name is no plan name, and ctxm/metrics/ holds no other .md file; move it out of the folder";

def unread_refusal:
  "is no roll-up in the format of the collector (docs/metrics-format.md, The roll-ups):"
  + " collect the project again with the current templates, or move the file out of the folder";

# A roll-up fact, read: {project, rollup}; a file that is none is refused, naming it.
def read_fact:
  . as $fact
  | (file_plan // refuse_file(unnamed_refusal)) as $plan
  | (.text | read_rollup($plan)) // ($fact | refuse_file(unread_refusal))
  | {project: $fact.project, rollup: .};

def fingerprints: .setups | map({templates, roles});

# A setup is what made a roll-up: its project (as given, and as the collector named it) and its fingerprints. A
# roll-up made under several fingerprints is one setup, as its numbers cannot be told apart.
def setup_key: [.project, .rollup.project, (.rollup | fingerprints)];

def setups($shown):
  group_by(setup_key) | to_entries
  | map({
      setup: (.key + 1),
      shown: $shown[.value[0].project | tostring],
      project: .value[0].rollup.project,
      fingerprints: (.value[0].rollup | fingerprints),
      rollups: (.value | map(.rollup))
    });

# A name as it sorts: its numbers as numbers, so `v0.9` comes before `v0.10` and `REQ-900-1A` before `REQ-900-10A`.
def natural_order: [scan("[0-9]+|[^0-9]+") | tonumber? // .];

# A column for each roll-up of each setup, in the setups' order and then their plans': [{setup, plan, rollup}].
# Plans of different names stand side by side: later releases of one project, or the plans of different projects.
def plan_columns:
  map(.setup as $setup | .rollups | sort_by(.plan | natural_order) | .[] | {setup: $setup, plan, rollup: .});

# The task names of every column's items, each once: an item that only one column has gets `none` in the others.
def item_names: [.[].rollup.items[].item] | unique | sort_by(natural_order);

def shown_projects: map(select(.kind == "project") | {key: (.project | tostring), value: .shown}) | from_entries;

def compared:
  shown_projects as $shown
  | map(select(.kind == "rollup") | read_fact)
  | setups($shown)
  | plan_columns as $columns
  | {setups: map(del(.rollups)), columns: $columns, items: ($columns | item_names)};

# What compare-setups.sh prints: {text}, or {refusal} with the one line that says why nothing is shown.
def comparison:
  try {text: (compared | comparison_text)}
  catch (if type == "object" and has("refusal") then . else error end);
