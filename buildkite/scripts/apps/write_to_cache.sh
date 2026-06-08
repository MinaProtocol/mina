#!/bin/bash

# Writes the freshly-built application binaries to the CI cache under
#   apps/<codename>/<variant>/
# where <variant> identifies the build (network-profile[-instrumented][-arm64]).
#
# The variant depth is required: several builds share a codename and produce
# identically-named binaries (e.g. mina_testnet_signatures.exe is emitted by the
# devnet, mesa and instrumented builds alike). Without the variant they would
# overwrite each other in apps/<codename>/, leaving whichever build finished last
# -- a non-deterministic, wrong artifact for any consumer.

CODENAME=$1
VARIANT=$2

if [[ -z "$CODENAME" || -z "$VARIANT" ]]; then
  echo "Usage: $0 <codename> <variant>" >&2
  exit 1
fi

find _build -type f -name "*.exe" | while read -r entry; do
  # Exclude files ending with ppx.exe
  if [[ "$entry" == *ppx.exe ]]; then
    continue
  fi

  ./buildkite/scripts/cache/manager.sh write-to-dir "$entry" "apps/${CODENAME}/${VARIANT}"
done
