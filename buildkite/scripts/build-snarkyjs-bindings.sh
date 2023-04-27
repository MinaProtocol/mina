#!/bin/bash

set -eo pipefail
source ~/.profile

echo "Install NPM dependencies..."
cd src/lib/snarkyjs
npm install --no-progress
cd -

echo "Build SnarkyJS..."
./scripts/update-snarkyjs-bindings.sh
