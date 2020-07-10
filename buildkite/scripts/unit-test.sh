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

echo "--- CPU general info"
cat /proc/cpuinfo

source ~/.profile

echo "--- Make build"
time make build

echo "--- Run unit tests"
time dune runtest "${path}" --profile="${profile}" -j16 || (./scripts/link-coredumps.sh && false)
