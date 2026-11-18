#!/bin/bash

# Writes the built .deb files to debians/<codename>[/<variant>]/ in the CI
# cache. <variant> is the one buildkite/scripts/apps/write_to_cache.sh takes:
# empty for a standard amd64 build, else "instrumented", "arm64" or
# "instrumented-arm64".
#
# Each .deb is written with a hidden .<file>.producer next to it, naming the
# step that wrote it. A .deb that another step already wrote is not replaced:
# the write fails instead. A retry of the same step may replace its own files.

CODENAME=$1
VARIANT=$2

DEST="debians/${CODENAME}${VARIANT:+/${VARIANT}}"
PRODUCER="${BUILDKITE_STEP_KEY:?BUILDKITE_STEP_KEY is not set}"

SIDECARS=$(mktemp -d)
trap 'rm -rf "$SIDECARS"' EXIT

conflict=0
for entry in _build/*.deb; do
  sidecar=".$(basename "$entry").producer"
  if buildkite-cache-manager read "${DEST}/${sidecar}" "$SIDECARS" >/dev/null 2>&1; then
    owner=$(head -n 1 "${SIDECARS}/${sidecar}")
    if [[ "$owner" != "$PRODUCER" ]]; then
      echo "❌ ${DEST}/$(basename "$entry") was already written by step ${owner}, not ${PRODUCER}" >&2
      conflict=1
    fi
  fi
done
[[ "$conflict" -eq 0 ]] || exit 1

for entry in _build/*.deb; do
  sidecar=".$(basename "$entry").producer"
  printf '%s\n' "$PRODUCER" "${BUILDKITE_JOB_ID:-}" "${BUILDKITE_LABEL:-}" > "${SIDECARS}/${sidecar}"
  buildkite-cache-manager write "$entry" "${SIDECARS}/${sidecar}" "${DEST}/"
done
