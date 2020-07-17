#!/bin/bash

set -o pipefail

eval `opam config env`

export LIBP2P_NIXLESS=1

echo "--- Explicitly generate PV-keys and upload before building"
make build_pv_keys

#echo "--- Publish pvkeys"
#./scripts/publish-pvkeys.sh

echo "--- Rebuild for pvkey changes"
make build

echo "--- Build generate-keypair binary"
dune build src/app/generate_keypair/generate_keypair.exe

echo "--- Build runtime_genesis_ledger binary"
dune exec --profile=$DUNE_PROFILE src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe

echo "--- Generate runtime_genesis_ledger with 10k accounts"
dune exec --profile=$DUNE_PROFILE src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe -- --config-file genesis_ledgers/phase_three/config.json

#echo "--- Upload genesis data"
#./scripts/upload-genesis.sh

#echo "--- Build deb package with pvkeys"
#make deb

#echo "--- Store genesis keys"
#make genesiskeys

#echo "--- Upload deb to repo"
#make publish_debs

#echo "--- Copy artifacts to cloud"
# buildkite-agent artifact upload occurs outside of docker after this script exits

# TODO save docker cache
