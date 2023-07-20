#!/bin/bash

set -eo pipefail
source ~/.profile

echo "Installing binaryen..."
sudo apt-get update
sudo apt-get install -y binaryen

echo "Install NPM dependencies..."
cd src/lib/snarkyjs
npm install --no-progress
cd -

echo "Build SnarkyJS..."
./scripts/update-snarkyjs-bindings.sh
