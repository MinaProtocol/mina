#!/usr/bin/env bash
set -euo pipefail

+chmod -R +w ../../native_prover
cd ../../native_prover

# build the Neon addon (produces 'index.node').
npm run build
popd

cp ../../native_prover/index.node plonk.node

echo "Neon project built and 'index.node' copied to the 'native' folder."

+chmod -R +w ../../native_prover