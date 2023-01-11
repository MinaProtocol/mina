#!/bin/bash

set -eo pipefail
source ~/.profile

echo "Install NPM dependencies..."
cd src/lib/snarky_js_bindings/snarkyjs
npm install --no-progress
cd -

echo "Build SnarkyJS..."
./scripts/update-snarkyjs-bindings.sh
