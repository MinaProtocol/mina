#!/bin/bash

# Read every codename's debian packages out of this build's cache.
#
# The codenames are discovered, not declared. The packaging stage decides which
# ones exist -- a devnet release builds five, a mainnet release builds one --
# and a list written here would be a second statement of that, free to drift
# from the first. Drift would be quiet in the worst direction: a codename
# missing from the list is built, cached, and never published, and nothing
# reports it.
#
# The destination gets one folder per codename, because that is the layout
# `release-manager publish` reads: it takes {codename}/*.deb and uses the
# directory name as the codename, rather than parsing it back out of file
# names.

set -euo pipefail

CACHE_BASE_URL="${CACHE_BASE_URL:-/var/storagebox}"
ROOT="${MINA_READ_CACHE_ROOT:-${BUILDKITE_BUILD_ID:?BUILDKITE_BUILD_ID is not set}}"
DEST="${1:?usage: $0 <destination-folder>}"

SRC="${CACHE_BASE_URL}/${ROOT}/debians"

if [[ ! -d "$SRC" ]]; then
  echo "❌ No debians in the cache at ${SRC}." >&2
  echo "   The packaging stage writes them there, so either it did not run or" >&2
  echo "   it ran against a different build id." >&2
  exit 1
fi

CODENAMES=()
for dir in "${SRC}"/*/; do
  [[ -d "$dir" ]] || continue
  CODENAMES+=("$(basename "$dir")")
done

if [[ ${#CODENAMES[@]} -eq 0 ]]; then
  echo "❌ ${SRC} holds no codename folders." >&2
  echo "   Refusing to report a successful read of nothing." >&2
  exit 1
fi

echo "--- Codenames found in the cache: ${CODENAMES[*]}"

for codename in "${CODENAMES[@]}"; do
  echo "--- Reading ${codename}"
  MINA_DEB_CODENAME="$codename" \
  ROOT="$ROOT" \
  LOCAL_DEB_FOLDER="${DEST}/${codename}" \
    ./buildkite/scripts/debian/read_all_from_cache.sh
done

echo "--- Read ${#CODENAMES[@]} codename(s) into ${DEST}"
