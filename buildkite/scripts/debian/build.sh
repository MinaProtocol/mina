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
	# Pre-build clean: stale .deb files from a previous failed (or
	# different-codename) run must be cleaned before building.  .deb
	# filenames are codename-less, so leftovers cause either silent
	# wrong-codename reuse or build_deb's pre-existing-.deb error.
	# Use _build/*.deb (not mina-*) to cover any non-mina- package
	# (e.g. minimina).  See oracle Debian review.
	rm -f _build/*.deb
	ARCHITECTURE="$ARCH" MINA_DEB_CODENAME="$codename" BRANCH_NAME="$BUILDKITE_BRANCH" ./scripts/debian/build.sh "${PARAMS[@]}"
	./buildkite/scripts/cache/manager.sh write-to-dir '_build/*.deb' debians/$codename/
done

if [[ -z "${LOCAL_BK_RUN+x}" ]]; then
	echo "--- Git diff after build is complete:"
	git diff --exit-code -- .
fi
