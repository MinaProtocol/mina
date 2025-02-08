#!/usr/bin/env bash
set -euo pipefail

pushd ../../native_prover

# build the Neon addon (produces 'index.node').
npm run build
popd

cp ../../native_prover/index.node plonk.node

echo "Neon project built and 'index.node' copied to the 'native' folder."