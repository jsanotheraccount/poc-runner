#!/usr/bin/env bash
# Lists catalogue changes between two commits of poc-environments, per environment.
# A catalogue change updates that environment's pipeline settings, not its infrastructure.
#
# Usage: catalogue-diff.sh <repo_dir> <from> <to>
# Prints JSON: [{env, tier, change: added|removed|changed, details: ["branches.modules: main → x", ...]}, ...]
set -euo pipefail

repo_dir=$1 from=$2 to=$3
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The catalogue file at a commit, as JSON ({} if the file doesn't exist there).
catalogue_at() {
  if git -C "$repo_dir" show "$1:catalogue/$2.yaml" >"$tmp/file.yaml" 2>/dev/null; then
    yq -o=json '.' "$tmp/file.yaml" | jq '. // {}'
  else
    echo '{}'
  fi
}

for tier in production non-production; do
  jq -n --arg tier "$tier" --argjson old "$(catalogue_at "$from" "$tier")" --argjson new "$(catalogue_at "$to" "$tier")" '
    # Leaf values keyed by dotted path, e.g. {"branches.modules": "main"}
    def flat: [paths(scalars) as $p | {key: ($p | map(tostring) | join(".")), value: getpath($p)}] | from_entries;
    [($old + $new | keys[]) as $env
      | select($old[$env] != $new[$env])
      | ($old[$env] // {} | flat) as $before
      | ($new[$env] // {} | flat) as $after
      | {
          env: $env,
          tier: $tier,
          change: (if $old[$env] == null then "added" elif $new[$env] == null then "removed" else "changed" end),
          details: [($before + $after | keys[]) as $k
            | select($before[$k] != $after[$k])
            | "\($k): \($before[$k] // "—") → \($after[$k] // "—")"]
        }]'
done | jq -s 'add'
