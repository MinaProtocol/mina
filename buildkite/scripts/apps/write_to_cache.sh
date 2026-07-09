#!/bin/bash

# Writes the freshly-built application binaries to the CI cache under
#   apps/<codename>/<variant>/
# where <variant> identifies the build (network-profile[-instrumented][-arm64]).
#
# The variant depth is required: several builds share a codename and produce
# identically-named binaries (e.g. mina.exe is emitted by the devnet, mesa and
# instrumented builds alike, differing only by build profile). Without the
# variant they would overwrite each other in apps/<codename>/, leaving whichever
# build finished last -- a non-deterministic, wrong artifact for any consumer.

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

# libp2p_helper is a Go binary (built under src/app/libp2p_helper/result/bin,
# not a dune _build/*.exe), but the daemon needs it at runtime. Cache it
# alongside the exes so bare daemon tests can restore it as coda-libp2p_helper,
# mirroring what the .deb installs.
HELPER="src/app/libp2p_helper/result/bin/libp2p_helper"
if [[ -f "$HELPER" ]]; then
  ./buildkite/scripts/cache/manager.sh write-to-dir "$HELPER" "apps/${CODENAME}/${VARIANT}"
fi

# minimina is a Rust binary (built under src/app/minimina/target/release, not a
# dune _build/*.exe). Cache it alongside the exes so the debian packaging job can
# restore it into the build tree without a separate copy of the binaries.
MINIMINA="src/app/minimina/target/release/minimina"
if [[ -f "$MINIMINA" ]]; then
  ./buildkite/scripts/cache/manager.sh write-to-dir "$MINIMINA" "apps/${CODENAME}/${VARIANT}"
fi
