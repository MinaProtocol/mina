#!/bin/bash

set -eu

cd src/lib/snarky

CURR=$(git rev-parse HEAD)
# skip SSL verification for this fetch only (for CI)
git -c http.sslVerify=false fetch origin

function in_branch {
  if git merge-base --is-ancestor "${CURR}" origin/"$1"; then
    echo "Snarky submodule commit ${CURR} is an ancestor of snarky/$1"
    true
  else
    false
  fi
}

if (! in_branch "master"); then
  cat >&2 <<EOF
ERROR: the snarky submodule is pinned to ${CURR}, which is not an
ancestor of snarky's origin/master.

This means the pinned snarky commit has not been merged upstream.
Push the snarky commit to snarky's master (or a branch merged into
master) before merging the change that updates this submodule.

Branches on snarky's origin that do contain ${CURR}:
EOF
  BRANCHES=$(git branch -r --contains "${CURR}" 2>/dev/null || true)
  if [ -n "${BRANCHES}" ]; then
    printf '%s\n' "${BRANCHES}" | sed 's/^/  /' >&2
  else
    echo "  (none - the commit may not be pushed to snarky's origin at all)" >&2
  fi
  exit 1
fi

