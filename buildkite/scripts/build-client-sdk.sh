#!/bin/bash

set -o pipefail

echo "--- Make client sdk"
mkdir -p /tmp/artifacts
make client_sdk 2>&1 | tee /tmp/artifacts/buildclientsdk.log

echo "--- Yarn deps"
pushd frontend/client_sdk && yarn install && popd

echo "--- Build and test Client SDK"
eval `opam config env` && \
  pushd frontend/client_sdk && \
  yarn prepublishOnly && \
  popd

