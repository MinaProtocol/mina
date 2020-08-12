#!/bin/bash

set -eo pipefail

eval `opam config env`
export PATH=$HOME/.cargo/bin:$PATH

# TODO: Stop building lib_p2p multiple times (due to excessive dependencies in make)
export LIBP2P_NIXLESS=1

echo "--- Explicitly generate PV-keys and upload before building"
make build_or_download_pv_keys 2>&1 | tee /tmp/buildocaml.log

echo "--- Publish pvkeys"
./scripts/publish-pvkeys.sh

# TODO: Investigate if this adds any value, but its never worked properly in CI
# echo "--- Rebuild for pvkey changes"
# make build 2>&1 | tee /tmp/buildocaml2.log

echo "--- Build generate-keypair binary"
dune build src/app/generate_keypair/generate_keypair.exe

echo "--- Build runtime_genesis_ledger binary"
dune exec --profile=$DUNE_PROFILE src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe

echo "--- Generate runtime_genesis_ledger with 10k accounts"
dune exec --profile=$DUNE_PROFILE src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe -- --config-file genesis_ledgers/phase_three/config.json

echo "--- Upload genesis data"
./scripts/upload-genesis.sh

echo "--- Build deb package with pvkeys"
make deb

echo "--- Store genesis keys"
make genesiskeys

echo "--- Upload deb to repo"
make publish_debs

echo "--- Copy artifacts to cloud"
# buildkite-agent artifact upload occurs outside of docker after this script exits

# TODO save docker cache
