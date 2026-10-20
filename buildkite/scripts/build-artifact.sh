#!/bin/bash

set -eox pipefail

# shellcheck disable=SC1090
source ~/.profile

MINA_COMMIT_SHA1=$(git rev-parse HEAD)

# reexporting DUNE_INSTRUMENT_WITH
if [[ -v DUNE_INSTRUMENT_WITH ]]; then
  export DUNE_INSTRUMENT_WITH="$DUNE_INSTRUMENT_WITH"
fi


echo "--- Build all major targets required for packaging"
echo "Building from Commit SHA: ${MINA_COMMIT_SHA1}"
echo "Rust Version: $(rustc --version)"

make libp2p_helper

make build-logproc

make build-mina

make build-daemon-utils

make build-archive-utils

make build-test-utils

make build-delegation-verify