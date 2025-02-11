#!/usr/bin/env bash
set -euo pipefail

chmod -R +w ../../native_prover
cd ../../native_prover

# build the neon project and produces 'index.node').
npm install --no-audit --ignore-scripts
npm run build

cp index.node ../js/native/plonk_native.node
cd ../js/native

echo "Neon project built and copied to plonk_native.node"