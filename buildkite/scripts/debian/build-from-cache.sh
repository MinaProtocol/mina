#!/bin/bash

# Builds Debian packages from application binaries that were compiled by a
# SEPARATE app-build Buildkite job and cached with its full build-tree layout
# (see buildkite/scripts/apps/write_build_tree_to_cache.sh).
#
# This is the debian half of what buildkite/scripts/build-release.sh does in a
# single step: build-release.sh compiles the binaries AND packages them together
# in one workspace, whereas here the compile already happened elsewhere and we
# only restore the tree and package it. Keep the packaging logic below in sync
# with build-release.sh.
#
# Usage: build-from-cache.sh <apps-variant> <build-variant> <package-token> [<package-token> ...]

set -eo pipefail

[ -z "${MINA_DEB_CODENAME+x}" ] && echo "MINA_DEB_CODENAME env var was not provided" && exit 1

APPS_VARIANT=$1
BUILD_VARIANT=$2
shift 2

if [[ -z "$APPS_VARIANT" || -z "$BUILD_VARIANT" ]]; then
  echo "Usage: $0 <apps-variant> <build-variant> <package-token> [...]" >&2
  exit 1
fi

./buildkite/scripts/apps/restore_build_tree.sh "${MINA_DEB_CODENAME}" "${APPS_VARIANT}" "${BUILD_VARIANT}"

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
