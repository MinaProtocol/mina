#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <release-branch>"
    exit 1
fi

TESTNET_NAME="${TESTNET_NAME:-devnet-generic}"

git config --global --add safe.directory /workdir

source buildkite/scripts/debian/update.sh --verbose

source buildkite/scripts/handle-fork.sh
source buildkite/scripts/export-git-env-vars.sh

pip3 install sexpdata==1.0.0 requests

source ./buildkite/scripts/refresh_code.sh

base_branch=origin/${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-compatible}
pr_branch=${BUILDKITE_BRANCH}
release_branch=origin/$1

echo "--- Run Python version linter with branches: ${pr_branch} ${base_branch} ${release_branch}"
./scripts/version-linter.py ${pr_branch} ${base_branch} ${release_branch}

echo "--- Audit type shapes"
source buildkite/scripts/export-git-env-vars.sh

# audit-type-shapes only inspects the binary's compiled-in type registry, so the
# freshly-built bare binary from the apps cache is sufficient; no debian package
# is required. Fall back to the .deb when the bare binary is unavailable. Either
# way `mina` ends up on PATH.
if ./buildkite/scripts/apps/restore_binary.sh devnet; then
  echo "Using bare mina from apps cache"
else
  echo "Falling back to debian-installed mina"
  source buildkite/scripts/debian/install.sh "mina-${TESTNET_NAME}" 1
fi

mina internal audit-type-shapes
