#!/usr/bin/env bash
set -euo pipefail

+chmod -R +w ../../native_prover
cd ../../native_prover


cd ../../native_prover

# build the Neon addon (produces 'index.node').
npm install --no-audit --ignore-scripts
npm run build

cp index.node ../js/native/plonk.node

echo "Neon project built and 'index.node' copied to the 'native' folder."

+chmod -R +w ../../native_prover