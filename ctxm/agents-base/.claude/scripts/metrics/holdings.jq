# What the project already holds, read for a collection: where each session's records end, which agents have their
# line, and the start record. Pure; needs format.jq. Used by lines.jq.

# The last time each session named by a session's own transcript wrote a record.
def last_records:
  reduce (.[] | select(.kind == "session") | .sessions | to_entries[]) as $seen ({};
    .[$seen.key] = ([.[$seen.key], $seen.value] | max));

def written_agents: map(select(.role != main_role) | {key: .agent, value: true}) | from_entries;

# The start record: one past time. Anything else there is refused, never repaired from the transcripts.
def start_seconds($now):
  if is_time and time_seconds <= $now then time_seconds
  else refuse("ctxm/metrics/start does not hold one past time such as 2026-01-05T09:00:00Z; restore it from git")
  end;
