#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <dune-profile> <path-to-source-tests>"
    exit 1
fi

profile=$1
path=$2

source ~/.profile
make build 2>&1 | tee /tmp/artifacts/make-build.log
dune runtest "${path}" --profile="${profile}" -j8 || (./scripts/link-coredumps.sh && false) 2>&1 | tee /tmp/artifacts/unit-test.log
