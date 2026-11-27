# The figures the comparison shows, each as [name, value], from one setup's roll-up as reading.jq reads it. A figure
# the roll-ups gain is shown by one line here, once reading.jq reads it (tests/metrics/compare/README.md).
# Pure; needs the collector's rollup.jq (round_limit).

def cost_figures: [
  ["runs", .runs],
  ["input tokens", .input],
  ["output tokens", .output],
  ["cache read tokens", .cache_read],
  ["cache write tokens", .cache_write],
  ["wall seconds", .wall_seconds],
  ["compactions", .compactions]
];

# Of a plan (the input: its roll-up). Escapes and the owner's questions stand here, not by item: a roll-up counts
# them for the whole plan (docs/metrics-format.md, The roll-ups).
def plan_figures:
  [["coverage", .coverage], ["items", (.items | length)]]
  + (.total | cost_figures)
  + [
      ["items at the round limit", ([.items[] | select(.rounds >= round_limit)] | length)],
      ["defects found at tests", .defects_at_tests],
      ["release candidates", .candidates],
      ["owner change requests at a candidate", .change_requests],
      ["questions brought to the owner", .owner_questions]
    ];

# Of an item (the input: its entry in the roll-up's items).
def item_figures: [["rounds", .rounds]] + cost_figures;
