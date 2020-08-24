#!/bin/bash

set -o pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 '<yarn-args>'"
    exit 1
fi

yarn_args="${1}"

echo "--- (Pre)publish Client SDK"
source ~/.profile
cd frontend/client_sdk && yarn ${yarn_args}
