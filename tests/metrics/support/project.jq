# What a project on the templates holds at one commit of a history (tests/metrics/fixtures/projects/*.json): the
# lock ctxm 0.7 writes, with the applied templates and their library commit, and the agent files, with each role's
# model and effort. Pure: a commit in, its date and its {file, content} entries out; make-project.sh writes them.
# jq reads a definition before its use: the entries, commit_files and commit_date, are the last two.

def template_entry: "\n[[templates]]\nname = \(.name | tojson)\nsource = \"local\"\ncommit = \(.commit | tojson)\n";

def lock_file: {
  file: ".ctxm/ctxm.lock",
  content: ("version = \(.version)\nfolders = [\".claude/agents\"]\n" + (.templates | map(template_entry) | add))
};

# A value the history leaves out has no line: a real agent file may name no model or no effort.
def front_matter_line($key): if .[$key] == null then "" else "\($key): \(.[$key])\n" end;

def agent_file: {
  file: ".claude/agents/\(.name).md",
  content: (
    "---\n" + front_matter_line("name") + front_matter_line("description") + front_matter_line("model")
    + front_matter_line("effort") + "---\n\(.description)\n"
  )
};

# A commit without a lock is a project not on the templates (yet).
def commit_files: (.lock // empty | lock_file), (.agents // [] | .[] | agent_file);

def commit_date($epoch): ($epoch | fromdateiso8601) + .minute * 60 | todate;
