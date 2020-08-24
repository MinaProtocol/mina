#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 '<yarn-args>'"
    exit 1
fi

yarn_args="${1}"

echo "--- Client SDK execute: ${yarn_args}"
eval `opam config env` && \
  pushd frontend/client_sdk && \
  yarn install && \
  yarn ${yarn_args} && \
  popd 
