# What the collector says about a collection: the notes on stderr, one per reason a run or a session was not
# written, and the result on stdout. Counts only: no id and no name. Pure; needs format.jq.

def note_texts: [
  ["unreadable", "transcripts that cannot be read whole, not written"],
  ["unfinished", "runs not finished yet, written once they are"],
  ["unnamed", "finished runs whose first prompt names no task after Task:, not written"],
  ["unplain", "runs and parts of main sessions with a role or a model that is no plain word, not written"],
  ["open", "main sessions with a record in the last \(quiet_seconds / 60) minutes, written once they are quiet"],
  ["before_start", "runs and main sessions that ended before the project's metrics start, never written"],
  ["no_setup", "runs and parts of main sessions at a commit without .ctxm/, not written"],
  ["left_out_plans", "plan files left out: a name, a size or a kind of file that is no plan's"],
  [
    "malformed_findings",
    "runs written without counts: their last line opens with Findings: and is no line of the format"
  ]
];

# The notes of a collection, from how many times each reason occurred (the input), in the order above.
def notes: . as $counts | note_texts | map(select($counts[.[0]] > 0) | "\(.[1]): \($counts[.[0]])");

def of_main: map(select(.role == main_role)) | length;

# The result of a collection, from the lines it adds (the input): how many, and whose.
def result: "\(length) (of runs: \(length - of_main), of main sessions: \(of_main))";
