#!/bin/bash

# Writes the built .deb files to debians/<codename>[/<variant>]/ in the CI
# cache. <variant> is the one buildkite/scripts/apps/write_to_cache.sh takes:
# empty for a standard amd64 build, else "instrumented", "arm64" or
# "instrumented-arm64".

CODENAME=$1
VARIANT=$2

for entry in _build/*.deb; do
  buildkite-cache-manager write "$entry" "debians/${CODENAME}${VARIANT:+/${VARIANT}}/"
done
