#!/bin/bash

set -eu

cd src/lib/snarky

CURR=$(git rev-parse HEAD)

function in_branch {
  if git merge-base --is-ancestor "${CURR}" origin/"$1"; then
    echo "Snarky submodule commit ${CURR} is an ancestor of snarky/$1"
    true
  else
    false
  fi
}

# snarky's master only moves forward, so a commit that is an ancestor of the
# local copy of origin/master is an ancestor of the remote one too. The pin
# rarely changes, so this usually answers without touching the network.
if git rev-parse --verify -q origin/master >/dev/null && in_branch "master"; then
  exit 0
fi

FETCH_ATTEMPTS="${FETCH_ATTEMPTS:-5}"
FETCH_RETRY_DELAY="${FETCH_RETRY_DELAY:-15}"

# GitHub resets connections from the CI agents in episodes, which surfaces
# here as `gnutls_handshake() failed: Error in the pull function`.
for attempt in $(seq 1 "${FETCH_ATTEMPTS}"); do
  # skip SSL verification for this fetch only (for CI)
  if git -c http.sslVerify=false fetch origin; then
    break
  fi
  if [[ "${attempt}" -eq "${FETCH_ATTEMPTS}" ]]; then
    echo "ERROR: could not fetch snarky's origin after ${FETCH_ATTEMPTS} attempts" >&2
    exit 1
  fi
  echo "Fetching snarky's origin failed (attempt ${attempt}/${FETCH_ATTEMPTS}), retrying in ${FETCH_RETRY_DELAY}s" >&2
  sleep "${FETCH_RETRY_DELAY}"
done

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

