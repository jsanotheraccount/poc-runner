#!/usr/bin/env bash
# Stand-in for a Terraform plan: the change a commit range introduces for one environment.
#
# A real plan only contains what the change does to the current state, so two PRs that
# change different things each keep the same plan, whichever merges first. To mimic that,
# this describes the change itself (file names plus removed and added lines) and leaves out
# anything that depends on commits or position: no commit, tree or blob SHAs, no line numbers.
#   - Different files, or different lines of one file: the change is the same after the other
#     PR merges, so the fingerprint matches.
#   - The same line: the "removed" side differs once the other PR has merged, so it doesn't.
#
# PR side:    <from> = the PR base, <to> = the PR merge result  (HEAD^1 and HEAD on the merge ref)
# Merge side: <from> = main before the push, <to> = main after it
#
# Usage: fingerprint.sh <repo_dir> <from> <to> <source_role> <env>
# Prints the normalised change, then a final line "fingerprint=<hash>".
set -euo pipefail

repo_dir=$1 from=$2 to=$3 role=$4 env=$5

# Paths that never affect a plan.
skip=(':(exclude,glob)**/*.md' ':(exclude)docs')

# Fail loudly if either commit is missing (for example, a shallow checkout), instead of an empty change.
for commit in "$from" "$to"; do
  git -C "$repo_dir" rev-parse --verify --quiet "$commit^{commit}" >/dev/null ||
    { echo "fingerprint.sh: $commit is not available in $repo_dir" >&2; exit 1; }
done

# Normalised diff: drop "diff --git" and "index <sha>" lines and "@@ -1 +1 @@" position headers.
change() {
  local diff
  diff=$(git -C "$repo_dir" diff -U0 --no-color --no-ext-diff --no-renames "$from" "$to" -- "$@")
  grep -vE '^(diff --git |index |@@ )' <<<"$diff" || true # grep exits 1 when nothing is left
}

if [[ $role == environments ]]; then
  # An environment's plan depends on the shared code and its own folder, not other envs' folders.
  shared=$(change . ':(exclude)envs' "${skip[@]}")
  own=$(change "envs/$env" "${skip[@]}")
  result=$(printf '%s\n%s' "$shared" "$own" | sed '/^$/d')
else
  result=$(change . "${skip[@]}")
fi

if command -v sha256sum >/dev/null; then hash() { sha256sum; }; else hash() { shasum -a 256; }; fi

if [[ -z $result ]]; then
  echo "(no changes for $env)"
else
  printf '%s\n' "$result"
fi
printf 'fingerprint=%s\n' "$(printf '%s' "$result" | hash | cut -c1-16)"
