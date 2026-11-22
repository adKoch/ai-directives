# shellcheck shell=bash
# The one place the makers write. Their jq modules only say what the files hold: one {file, content} entry per line.

# Reads the entries and writes each file whole under the root, with the folders it needs.
write_files() {
  local root=$1 entry file
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    file="$root/$(jq -r '.file' <<<"$entry")"
    mkdir -p "$(dirname "$file")"
    jq -j '.content' <<<"$entry" >"$file"
  done
}
