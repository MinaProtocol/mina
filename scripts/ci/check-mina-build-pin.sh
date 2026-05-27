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

# Read the single payload line. The file may carry leading/trailing blank
# lines or `#`-prefixed comments, but it must contain exactly one non-comment
# value — multiple lines would silently concatenate into an invalid ref.
mapfile -t CI_REF_LINES < <(grep -vE '^[[:space:]]*(#|$)' "$PIN_FILE" || true)

if [[ "${#CI_REF_LINES[@]}" -eq 0 ]]; then
  echo "ERROR: $PIN_FILE is empty (after stripping comments/whitespace)" >&2
  exit 1
fi

if [[ "${#CI_REF_LINES[@]}" -gt 1 ]]; then
  echo "ERROR: $PIN_FILE must contain exactly one non-comment line, got ${#CI_REF_LINES[@]}:" >&2
  printf '  %s\n' "${CI_REF_LINES[@]}" >&2
  exit 1
fi

# Strip surrounding whitespace from the single line only.
CI_REF="${CI_REF_LINES[0]}"
CI_REF="${CI_REF#"${CI_REF%%[![:space:]]*}"}"
CI_REF="${CI_REF%"${CI_REF##*[![:space:]]}"}"

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

# Mirror the hook's behavior: a PR build targeting a protected branch is
# still PR-time iteration, so a non-SHA ref is allowed until merge. The
# enforcement check only blocks direct/merge commits to the protected
# branch itself.
if [[ "${BUILDKITE_PULL_REQUEST:-false}" != "false" ]]; then
  echo "OK: PR build (BUILDKITE_PULL_REQUEST=${BUILDKITE_PULL_REQUEST}); non-SHA ref '$CI_REF' allowed."
  echo "    Resolve to a SHA via scripts/ci/resolve-mina-build-pin.sh before merging."
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
