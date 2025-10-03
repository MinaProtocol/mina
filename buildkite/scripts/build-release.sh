#!/bin/bash

set -eo pipefail

([ -z ${DUNE_PROFILE+x} ] || [ -z ${MINA_DEB_CODENAME+x} ]) && echo "required env vars were not provided" && exit 1

./buildkite/scripts/build-artifact.sh

echo "--- Bundle all packages for Debian ${MINA_DEB_CODENAME}"
echo " Includes mina daemon, archive-node, rosetta"


echo "--- Prepare debian packages"
BRANCH_NAME="$BUILDKITE_BRANCH" ./scripts/debian/build.sh "$@"

echo "--- Git diff after build is complete:"
git diff --exit-code -- .