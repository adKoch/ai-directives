# The comparison of setups: the roll-ups of the projects given, read back (reading.jq), grouped into setups and
# laid side by side by plan and by item. The input is the list of facts projects.sh prints: {kind: "project",
# project, shown} for each project given and {kind: "rollup", project, file, shown, text} for each roll-up file.
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

# The roll-ups of the plan, each with its setup's number: [{setup, rollup}].
def plan_columns($plan): map(.setup as $setup | .rollups[] | select(.plan == $plan) | {setup: $setup, rollup: .});

def item_names: [.[].rollup.items[].item] | unique;

def plan_view($plan): plan_columns($plan) | {plan: $plan, columns: ., items: item_names};

def plans: . as $setups | [map(.rollups[].plan) | unique | .[] | . as $plan | $setups | plan_view($plan)];

def shown_projects: map(select(.kind == "project") | {key: (.project | tostring), value: .shown}) | from_entries;

def compared:
  shown_projects as $shown
  | map(select(.kind == "rollup") | read_fact)
  | setups($shown)
  | {setups: map(del(.rollups)), plans: plans};

# What compare-setups.sh prints: {text}, or {refusal} with the one line that says why nothing is shown.
def comparison:
  try {text: (compared | comparison_text)}
  catch (if type == "object" and has("refusal") then . else error end);
