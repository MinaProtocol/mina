#!/bin/bash

set -o pipefail

echo "--- Make client sdk"
mkdir -p /tmp/artifacts
make client_sdk 2>&1 | tee /tmp/artifacts/buildclientsdk.log

echo "--- Get yarn"
sudo apt install apt-transport-https
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update && sudo apt install nodejs yarn

echo "--- Yarn deps"
cd frontend/client_sdk && yarn install

echo "--- Build and test Client SDK"
eval `opam config env` && cd frontend/client_sdk && yarn prepublishOnly

