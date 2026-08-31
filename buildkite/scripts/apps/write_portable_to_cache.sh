#!/bin/bash

# Publishes the portable bundle produced by build-artifact.sh to the CI cache,
# so a docker or debian job on a DIFFERENT agent can consume it:
#
#   portable/<codename>[/<variant>]/mina-portable.tar.gz
#   portable/<codename>[/<variant>]/closure-report.txt
#
# Usage: write_portable_to_cache.sh <codename> [<variant>]
#
# The variant follows the apps cache exactly (apps/write_to_cache.sh): empty for
# a standard amd64 build, otherwise "instrumented", "arm64" or
# "instrumented-arm64". Same reasoning -- an instrumented build emits binaries
# with the same names, and sharing a directory would leave whichever job
# finished last.
#
# Unlike the apps cache this stores ONE tarball for the whole tree rather than
# one per binary. The bundle is a single deduplicated bin/libexec/lib tree whose
# libraries are shared between binaries; there is no way to hand a consumer one
# binary out of it without the shared lib directory, so splitting it would only
# duplicate.
#
# Exits 0 doing nothing when there is no bundle. Whether a build produces one is
# decided by MINA_BUILD_PORTABLE in build-artifact.sh, and this step is present
# on every apps job, so "no bundle" is the ordinary case for a job that did not
# opt in -- not an error.

set -eo pipefail

CODENAME=$1
VARIANT=$2

if [[ -z "$CODENAME" ]]; then
  echo "Usage: $0 <codename> [<variant>]" >&2
  exit 1
fi

PORTABLE_ROOT="${MINA_PORTABLE_ROOT:-_build_portable}"

if [[ ! -d "$PORTABLE_ROOT" ]]; then
  echo "write_portable_to_cache: no ${PORTABLE_ROOT}, nothing to publish" >&2
  exit 0
fi

DEST="portable/${CODENAME}${VARIANT:+/${VARIANT}}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# -C the parent and name the directory, so the tarball unpacks to a directory
# rather than spraying bin/ libexec/ lib/ into the consumer's cwd.
TARBALL="${TMP_DIR}/mina-portable.tar.gz"
tar -czf "$TARBALL" \
    -C "$(dirname "$PORTABLE_ROOT")" "$(basename "$PORTABLE_ROOT")"

echo "--- Publishing portable bundle to ${DEST}"
echo "write_portable_to_cache: $(du -h "$TARBALL" | cut -f1) tarball"
./buildkite/scripts/cache/manager.sh write-to-dir "$TARBALL" "$DEST"

# The closure report goes up uncompressed as well as inside the tarball, so it
# can be read straight out of the cache without fetching the whole bundle.
if [[ -f "${PORTABLE_ROOT}/closure-report.txt" ]]; then
  ./buildkite/scripts/cache/manager.sh write-to-dir \
    "${PORTABLE_ROOT}/closure-report.txt" "$DEST"
fi
