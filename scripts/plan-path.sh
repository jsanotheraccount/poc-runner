#!/usr/bin/env bash
# The one place the plan location is built (T5 touched this). Both the PR and the merge workflows call it,
# so if they're given the same inputs they produce the same path.
#
# Usage: plan-path.sh <source_repo> <pr_number> <head_sha> <env>
set -euo pipefail

printf 'plans/%s/pr-%s/%s/%s/\n' "$1" "$2" "$3" "$4"
