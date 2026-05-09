#!/usr/bin/env bash
# Resolve the current mina-build pin (branch or tag) to a commit SHA and
# write it back to .buildkite/mina-build.version. Idempotent: if the file
# already contains a SHA, it's left alone.
#
# Run this before merging a PR that bumped the pin to a branch for
# iteration. Equivalent to a lockfile resolver (e.g. `cargo update`,
# `npm install` writing package-lock.json).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
PIN_FILE="$REPO_ROOT/.buildkite/mina-build.version"
CI_REPO="${MINA_BUILD_REPO:-https://github.com/MinaProtocol/mina-build.git}"
SHA_REGEX='^[0-9a-f]{40}$'

if [[ ! -f "$PIN_FILE" ]]; then
  echo "ERROR: $PIN_FILE not found" >&2
  exit 1
fi

CI_REF="$(grep -vE '^[[:space:]]*(#|$)' "$PIN_FILE" | tr -d '[:space:]')"

if [[ -z "$CI_REF" ]]; then
  echo "ERROR: $PIN_FILE is empty" >&2
  exit 1
fi

if [[ "$CI_REF" =~ $SHA_REGEX ]]; then
  echo "Pin is already a SHA ($CI_REF); nothing to do."
  exit 0
fi

echo "Resolving '$CI_REF' against $CI_REPO ..."

# `git ls-remote` prints "<sha>\t<refname>" lines. Try heads then tags.
RESOLVED="$(git ls-remote "$CI_REPO" "refs/heads/$CI_REF" "refs/tags/$CI_REF" \
            | awk '{print $1; exit}')"

if [[ -z "$RESOLVED" || ! "$RESOLVED" =~ $SHA_REGEX ]]; then
  echo "ERROR: could not resolve '$CI_REF' to a SHA in $CI_REPO" >&2
  echo "       Make sure the branch/tag exists upstream." >&2
  exit 1
fi

echo "$RESOLVED" > "$PIN_FILE"
echo "Updated $PIN_FILE: $CI_REF -> $RESOLVED"
echo
echo "Next steps:"
echo "  git add $PIN_FILE"
echo "  git commit -m 'Pin mina-build to $RESOLVED'"
