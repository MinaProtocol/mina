#!/bin/bash

set -eo pipefail

# Parse CLI arguments
CODENAMES=""
ARCH=""
PARAMS=()

while [[ $# -gt 0 ]]; do
	case $1 in
		--codenames)
			CODENAMES="$2"
			shift 2
			;;
		--arch)
			ARCH="$2"
			shift 2
			;;
		*)
			PARAMS+=("$1")
			shift
			;;
	esac
done

./buildkite/scripts/export-git-env-vars.sh

echo "--- Prepare debian packages"

IFS=',' read -ra CODENAMES_ARRAY <<< "$CODENAMES"

for codename in "${CODENAMES_ARRAY[@]}"; do
	ARCHITECTURE="$ARCH" MINA_DEB_CODENAME="$codename" BRANCH_NAME="$BUILDKITE_BRANCH" ./scripts/debian/build.sh "${PARAMS[@]}"
done

if [[ -z "${LOCAL_BK_RUN+x}" ]]; then
	echo "--- Git diff after build is complete:"
	git diff --exit-code -- .
fi

./buildkite/scripts/cache/manager.sh write-to-dir '_build/mina-*.deb' debians/$MINA_DEB_CODENAME/