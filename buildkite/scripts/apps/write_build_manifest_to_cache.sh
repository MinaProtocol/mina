#!/bin/bash

# Publishes a small MANIFEST describing where each freshly-built binary lives in
# the build tree, so the debian packaging job (which runs on a separate agent)
# can reconstruct the nested dune layout from the flat apps cache WITHOUT the
# binaries being stored a second time.
#
# The binaries themselves are already in the flat apps cache (written by
# apps/write_to_cache.sh, keyed by basename). scripts/debian/builder-helpers.sh
# copies them from their exact dune paths (e.g. _build/default/src/app/cli/src/
# mina.exe), so the debian job needs the path for each cached basename. This
# manifest is that mapping: one workspace-relative path per line. It is a few KB
# of text -- the opposite of tarring the binaries.
#
# Every basename in the manifest is unique across the set builder-helpers.sh
# consumes, so restoring each cached basename to its manifest path is
# unambiguous (see apps/restore_build_tree.sh).
#
# Usage: write_build_manifest_to_cache.sh <codename> <build-variant>

set -eo pipefail

CODENAME=$1
BUILD_VARIANT=$2

if [[ -z "$CODENAME" || -z "$BUILD_VARIANT" ]]; then
  echo "Usage: $0 <codename> <build-variant>" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

MANIFEST="${TMP_DIR}/build-manifest.txt"

# The dune binaries (same set apps/write_to_cache.sh flattens into the apps
# cache), plus the non-dune binaries it also caches.
find _build/default -type f -name "*.exe" ! -name "*ppx.exe" > "$MANIFEST"

for extra in \
  "src/app/libp2p_helper/result/bin/libp2p_helper" \
  "src/app/minimina/target/release/minimina"; do
  [[ -f "$extra" ]] && echo "$extra" >> "$MANIFEST"
done

echo "--- Publishing build manifest ($(wc -l < "$MANIFEST") entries) for ${CODENAME}/${BUILD_VARIANT}"
./buildkite/scripts/cache/manager.sh write-to-dir "$MANIFEST" "build-manifest/${CODENAME}/${BUILD_VARIANT}"
