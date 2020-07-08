#!/bin/bash

set -o pipefail

eval `opam config env`

echo "--- Explicitly generate PV-keys and uploading before building"
LIBP2P_NIXLESS=1 make build_pv_keys 2>&1 | tee /tmp/artifacts/buildocaml.log

echo "--- Publish pvkeys"
./scripts/publish-pvkeys.sh

echo "--- Rebuild for pvkey changes"
make build 2>&1 | tee /tmp/artifacts/buildocaml2.log

echo "--- Build generate-keypair binary"
dune build src/app/generate_keypair/generate_keypair.exe

echo "--- Build generate-keypair binary"
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
make publish_deb

echo "--- Copy artifacts to cloud"
make publish_deb

# TODO save docker cache
