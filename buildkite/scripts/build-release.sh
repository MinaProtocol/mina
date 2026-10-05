#!/bin/bash

set -eo pipefail

([ -z ${MINA_DEB_CODENAME+x} ]) && echo "MINA_DEB_CODENAME env var was not provided" && exit 1

./buildkite/scripts/build-artifact.sh

echo "--- Bundle all packages for Debian ${MINA_DEB_CODENAME}"
echo " Includes mina daemon, archive-node, rosetta"

echo "--- Building debian packages"
export BRANCH_NAME="$BUILDKITE_BRANCH"

# Deduplicate package arguments, preserving order. The pipeline emits one build
# token per artifact, but several artifacts can map to the same network-agnostic
# package (e.g. every per-network daemon maps to the single `daemon_generic`
# package). Dhall has no text-equality primitive, so we dedup here instead.
mapfile -t deduped_packages < <(printf '%s\n' "$@" | awk 'NF && !seen[$0]++')
echo "Building packages: ${deduped_packages[*]}"
./scripts/debian/build.sh "${deduped_packages[@]}"

if [[ -z "${LOCAL_BK_RUN+x}" ]]; then
	echo "--- Git diff after build is complete:"
	git diff --exit-code -- .
fi
