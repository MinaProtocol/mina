#!/usr/bin/env bash
# Lint the mina-build pin. Exits non-zero (blocking merge) when the file
# does not contain a 40-char commit SHA on a protected target branch.
# Branch refs are allowed for PR-time iteration but must be resolved to
# a SHA before merge — analogous to Cargo.lock / package-lock.json rules.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
PIN_FILE="$REPO_ROOT/.buildkite/mina-build.version"

PROTECTED_BRANCH_REGEX="${MINA_BUILD_PIN_PROTECTED_REGEX:-^(master|compatible|develop|release/.*)$}"
SHA_REGEX='^[0-9a-f]{40}$'

if [[ ! -f "$PIN_FILE" ]]; then
  echo "ERROR: $PIN_FILE not found" >&2
  exit 1
fi

CI_REF="$(grep -vE '^[[:space:]]*(#|$)' "$PIN_FILE" | tr -d '[:space:]')"

if [[ -z "$CI_REF" ]]; then
  echo "ERROR: $PIN_FILE is empty (after stripping comments/whitespace)" >&2
  exit 1
fi

# For PR builds the merge target is BUILDKITE_PULL_REQUEST_BASE_BRANCH; for
# direct branch builds it's BUILDKITE_BRANCH. Override with $TARGET_BRANCH
# when invoking outside Buildkite (e.g. local pre-commit).
TARGET_BRANCH="${TARGET_BRANCH:-${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-${BUILDKITE_BRANCH:-}}}"

if [[ "$CI_REF" =~ $SHA_REGEX ]]; then
  echo "OK: mina-build pin is a SHA ($CI_REF)"
  exit 0
fi

if [[ -z "$TARGET_BRANCH" ]]; then
  echo "WARN: target branch unknown; allowing non-SHA ref '$CI_REF'."
  echo "      Set TARGET_BRANCH=<branch> to enforce protected-branch rules."
  exit 0
fi

if [[ "$TARGET_BRANCH" =~ $PROTECTED_BRANCH_REGEX ]]; then
  cat >&2 <<EOF
ERROR: $PIN_FILE must contain a 40-char mina-build commit SHA when
       merging into protected branch '$TARGET_BRANCH'.
       Got: '$CI_REF'

       Resolve the current value to a SHA before merging:
         scripts/ci/resolve-mina-build-pin.sh
       then commit and push.
EOF
  exit 1
fi

echo "OK: target '$TARGET_BRANCH' is not protected; non-SHA ref '$CI_REF' allowed."
