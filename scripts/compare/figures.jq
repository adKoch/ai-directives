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
# them for the whole plan (docs/metrics-format.md, The roll-ups). The owner's change requests and questions have no
# source yet: the collector writes them `unknown`, and the write-back check (reading.jq) takes no roll-up that says
# anything else, so they are shown so, not read. The day they get a source, rollup_text writes their numbers and every
# roll-up is refused until reading.jq reads them.
def plan_figures:
  [["coverage", .coverage], ["items", (.items | length)]]
  + (.total | cost_figures)
  + [
      ["items at the round limit", ([.items[] | select(.rounds >= round_limit)] | length)],
      ["defects found at tests", .defects_at_tests],
      ["release candidates", .candidates],
      ["owner change requests at a candidate", unknown],
      ["questions brought to the owner", unknown]
    ];

# Of an item (the input: its entry in the roll-up's items).
def item_figures: [["rounds", .rounds]] + cost_figures;
