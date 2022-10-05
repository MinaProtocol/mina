#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 '<yarn-args>'"
    exit 1
fi

TAG=$(git tag --points-at HEAD)

[[ -z $TAG ]] && exit

yarn_args="${1}"

echo "//registry.yarnpkg.com/:_authToken=${NPM_TOKEN}" >> ~/.npmrc

echo "--- Client SDK execute: ${yarn_args}"
eval `opam config env` && \
  pushd frontend/client_sdk && \
  yarn install && \
  yarn ${yarn_args} && \
  popd 
