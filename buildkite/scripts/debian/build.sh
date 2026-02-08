#!/bin/bash

set -eo pipefail

./buildkite/scripts/export-git-env-vars.sh

echo "--- Prepare debian packages"
BRANCH_NAME="$BUILDKITE_BRANCH" ./scripts/debian/build.sh "$@"

if [[ -z "${LOCAL_BK_RUN+x}" ]]; then
	echo "--- Git diff after build is complete:"
	git diff --exit-code -- .
fi

./buildkite/scripts/cache/manager.sh write-to-dir '_build/mina-*.deb' debians/$MINA_DEB_CODENAME/