#!/usr/bin/env bash
# Stand-in for a Terraform plan: a hash of everything that would feed one environment's plan.
# Uses tree SHAs, not commit SHAs, so the same content gives the same fingerprint
# whichever merge method was used (merge commit, squash or rebase).
#
# Usage: fingerprint.sh <target_json> <environments_dir> <modules_dir> <runner_dir>
# Prints the inputs, then a final line "fingerprint=<hash>".
set -euo pipefail

target=$1 environments_dir=$2 modules_dir=$3 runner_dir=$4

tree_sha() { git -C "$1" rev-parse 'HEAD^{tree}'; }

if command -v sha256sum >/dev/null; then hash() { sha256sum; }; else hash() { shasum -a 256; }; fi

inputs=$(cat <<EOF
env=$(jq -r .env <<<"$target")
catalogue_entry=$(jq -cS 'del(.env)' <<<"$target")
environments_tree=$(tree_sha "$environments_dir")
modules_tree=$(tree_sha "$modules_dir")
runner_tree=$(tree_sha "$runner_dir")
EOF
)

printf '%s\n' "$inputs"
printf 'fingerprint=%s\n' "$(printf '%s' "$inputs" | hash | cut -c1-16)"
