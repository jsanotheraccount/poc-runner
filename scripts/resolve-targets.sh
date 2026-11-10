#!/usr/bin/env bash
# Decides which environments a change targets, using the deployment catalogue.
#
# Usage: resolve-targets.sh <source_role> <base_branch> <changed_files> <catalogue_dir>
#   source_role    environments | modules | runner (the repo the change is in)
#   base_branch    the branch the change lands on (the PR base)
#   changed_files  a file with one changed path per line
#   catalogue_dir  the directory holding production.yaml and non-production.yaml
#
# Prints JSON: {"needs_plan": bool, "reason": str, "targets": [{env, tier, region, branches}, ...]}
set -euo pipefail

role=$1 base=$2 changed_files=$3 catalogue_dir=$4

# Changes that never need a plan.
no_plan_pattern='(^|/)[^/]*\.md$|^docs/'

relevant=$(grep -Ev "$no_plan_pattern" "$changed_files" || true)
if [[ -z $relevant ]]; then
  jq -n '{needs_plan: false, reason: "only documentation changed", targets: []}'
  exit 0
fi

# Both catalogue files as one list: [{env, tier, region, branches}, ...]
catalogue=$(
  for tier in production non-production; do
    yq -o=json '.' "$catalogue_dir/$tier.yaml" |
      jq --arg tier "$tier" '(. // {}) | to_entries | map(.value + {env: .key, tier: $tier})'
  done | jq -s 'add'
)

# Environments whose <role> branch in the catalogue is the branch the change lands on.
following_base() {
  jq --arg role "$1" --arg base "$base" 'map(select(.branches[$role] == $base))' <<<"$catalogue"
}

case $role in
  modules | runner)
    reason="every environment whose $role branch is $base"
    targets=$(following_base "$role")
    ;;
  environments)
    if grep -qv '^envs/' <<<"$relevant"; then
      reason="shared environments code changed: every environment whose environments branch is $base"
      targets=$(following_base environments)
    else
      changed_envs=$(sed -n 's#^envs/\([^/]*\)/.*#\1#p' <<<"$relevant" | sort -u | jq -R . | jq -s .)
      reason="changed env folders whose environments branch is $base"
      targets=$(following_base environments |
        jq --argjson envs "$changed_envs" 'map(select(.env as $e | $envs | index($e)))')
    fi
    ;;
  *)
    echo "Unknown source role: $role" >&2
    exit 1
    ;;
esac

jq -n --arg reason "$reason" --argjson targets "$targets" \
  '{needs_plan: true, reason: $reason, targets: $targets}'
