# What a project on the templates holds at one commit of a history (tests/metrics/fixtures/projects/*.json): the
# lock ctxm writes (format 6 to 8), with the applied templates, their commit and their version, and the agent files,
# with each role's model and effort. Pure: a commit in, its date and its {file, content} entries out;
# make-project.sh writes them.
# jq reads a definition before its use: the entries, commit_files and commit_date, are the last two.

# A template of the lock: a pin to a released version names it (format 8), and its commit. A history can also hold
# what no ctxm would write: `header` replaces the table's header, a `source` of null leaves the line out, and
# `extra_lines` are written as they stand after the entry (a malformed or a doubled key).
def raw_lines($lines): ($lines // []) | map(. + "\n") | add // "";
def version_line: if .version == null then "" else "version = \(.version | tojson)\n" end;
def source_line: if has("source") and .source == null then "" else "source = \(.source // "local" | tojson)\n" end;

def template_entry:
  "\n\(.header // "[[templates]]")\nname = \(.name | tojson)\n" + source_line + version_line
  + "commit = \(.commit | tojson)\n" + raw_lines(.extra_lines);

# The lock: `top_lines` are written as they stand before the first table, `end_lines` after the last template; a lock
# given as `text` (one ctxm rendered: ../collector/rendered-locks/) is written as it stands.
def lock_file: {
  file: ".ctxm/ctxm.lock",
  content: .text // (
    "version = \(.version)\nfolders = [\".claude/agents\"]\n" + raw_lines(.top_lines)
    + (.templates | map(template_entry) | add // "") + raw_lines(.end_lines)
  )
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
