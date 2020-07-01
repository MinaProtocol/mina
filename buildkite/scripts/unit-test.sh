#!/bin/bash
set -o pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <dune-profile> <path-to-source-tests>"
    exit 1
fi

profile=$1
path=$2

echo "--- CPU frequency info"
lscpu | grep -i hz

source ~/.profile

echo "--- Make build"
make build 2>&1 | tee /tmp/make-build.log

echo "--- Run unit tests"
(dune runtest "${path}" --profile="${profile}" -j8 || (./scripts/link-coredumps.sh && false)) 2>&1 | tee /tmp/unit-test.log
