# A shape turned into another shape, so that one shape file shows a rule under more than one arrangement.
# Pure, and without a key name of a real record, as layout.jq.

# The session ids, each as the one that stands opposite it in sort order: the first sorted id takes the last one's
# place, and so on, in `id` and in `copies`. The shape is otherwise the same, so a rule that depends on which id sorts
# first gives other lines.
def with_session_ids_reversed:
  ([.sessions[].id] | sort) as $ids
  | ([$ids, ($ids | reverse)] | transpose | map({key: .[0], value: .[1]}) | from_entries) as $opposite
  | .sessions |= map(.id = $opposite[.id] | if .copies then .copies = $opposite[.copies] else . end);
