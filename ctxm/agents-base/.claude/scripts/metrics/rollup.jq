# The roll-up of a plan: what its items cost, how many rounds they took, what the reviews found, what git says of
# their commits. Numbers are added up from the lines of tasks.csv, git and ctxm/, never reported by an agent; a
# number with no source there is `unknown`, never guessed. What each figure is made from, and which have no source:
# docs/metrics-format.md of the template library ("The roll-ups").
# The input of a definition is the source {lines, plans, commits, candidates, start, project}, or lines (a list of
# tasks.csv lines, by column) where the name says so. Pure; needs format.jq. Read from the bottom (rollups) up.

# A plan item is reviewed in rounds: after a submission, findings, a fix and a second look (3 rounds at most, the
# project's rule).
def round_limit: 3;

def numbers($column): map(.[$column] | tonumber?);
def total($column): numbers($column) | add // 0;

def costs: {
  runs: length,
  input: total("input_tokens"),
  output: total("output_tokens"),
  cache_read: total("cache_read_tokens"),
  cache_write: total("cache_write_tokens"),
  wall_seconds: total("wall_seconds"),
  compactions: total("compactions")
};

def in_order: sort_by([.start, .end, .agent]);

# The lines whose report ended with a Findings line of the format.
def with_findings: map(select(.blocking | matches("[0-9]+")));

def passes($role): map(select(.role == $role)) | length;

# A review round is one look of the inspector or the reviewer: the item's rounds are the larger count of the two.
def rounds: [passes("inspector"), passes("reviewer")] | max;

def findings: {
  reports: length,
  blocking: total("blocking"),
  nits: total("nits"),
  blocking_by_round: (in_order | map(.blocking) | join("+")),
  nits_by_round: (in_order | map(.nits) | join("+"))
};

# The reports of one role (the input: lines of one group), added up.
def review_of: {role: .[0].role} + findings;

def reviews_by_role: with_findings | group_by(.role) | map(review_of);

def reviews_by_item_and_role: with_findings | group_by([.task, .role]) | map({task: .[0].task} + review_of);

def defects_at_tests: map(select(.role == "release-tester")) | with_findings | total("blocking");

def item_of($commits): {rounds: rounds} + costs + $commits;

# An item with no commit in the project's repository has `unknown` commits, never 0: the collector cannot tell an
# item that committed nothing from one whose commits are in another repository (a plan may hold the items of
# another repository, as the library's items in a project's plan).
def no_known_commits: {commits: unknown, added: unknown, deleted: unknown};

def commits_of($task): [.commits[] | select(.task == $task) | {commits, added, deleted}] | first // no_known_commits;

def items_of($mine):
  . as $source
  | $mine | group_by(.task)
  | map(. as $lines | .[0].task as $task | {item: $task} + ($lines | item_of($source | commits_of($task))));

# The fingerprints of the plan's lines, each with the number of lines made under it.
def setups_of: group_by([.templates, .roles]) | map({templates: .[0].templates, roles: .[0].roles, lines: length});

def coverage($first): if $first == null then unknown elif .start > $first then "partial" else "whole" end;

# The plan's period: from the first commit of the plan file to the end of its last line. A plan with no commit, or
# whose lines all end before its file was first committed, has none that can be relied on.
def period_of($first; $mine):
  ($mine | map(.end | time_seconds) | max) as $to
  | if $first == null or $to < $first then null else {from: $first, to: $to} end;

# The main sessions' lines that overlap the period. A line covers a whole session (or the rest of one), which is not
# split by time, so a line counts whole in every plan whose period it overlaps: two plans running at once both count
# the session that served them.
def main_lines($period):
  map(select(
    .role == main_role
    and (.start | time_seconds) <= $period.to
    and (.end | time_seconds) >= $period.from
  ));

# The release candidates of a plan named for a release (`v0.8`: every `0.8.*`); `unknown` for any other plan.
def candidates_of($plan):
  if ($plan | matches("v[0-9]{1,4}\\.[0-9]{1,4}")) then
    [.candidates[] | select(.version | startswith($plan[1:] + "."))] | length
  else unknown
  end;

def rollup_of($plan):
  . as $source
  | ($source.lines | map(select(.task | IN($plan.items[])))) as $mine
  | $plan.first_commit as $first
  | period_of($first; $mine) as $period
  | {
      plan: $plan.name,
      project: $source.project,
      start: $source.start,
      first_commit: $first,
      coverage: ($source | coverage($first)),
      setups: ($mine | setups_of),
      items: ($source | items_of($mine)),
      total: ($mine | costs),
      review_roles: ($mine | reviews_by_role),
      review_items: ($mine | reviews_by_item_and_role),
      defects_at_tests: ($mine | defects_at_tests),
      candidates: ($source | candidates_of($plan.name)),
      period: $period,
      main: (if $period == null then null else $source.lines | main_lines($period) | costs end)
    };

# The roll-ups of the plans that have lines: [{plan, rollup}], in the order of the plan names.
def rollups:
  . as $source
  | $source.plans | map(select(.name != null)) | sort_by(.name)
  | map(. as $plan | $source | rollup_of($plan) | select(.items | length > 0));
