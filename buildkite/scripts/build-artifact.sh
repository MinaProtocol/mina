#!/bin/bash

set -eox pipefail

([ -z ${DUNE_PROFILE+x} ]) && echo "required env vars were not provided" && exit 1

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

make build_logproc

[[ ${MINA_BUILD_MAINNET} ]] && make build_mainnet_sigs

make build_testnet_sigs

make build_daemon_utils

make build_archive_utils

make build_test_utils