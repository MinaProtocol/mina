#!/bin/bash

set -eo pipefail

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
export CODA_LIBP2P_HELPER_PATH="${PWD}/src/app/libp2p_helper/result/bin/libp2p_helper"
export LIBP2P_NIXLESS=1
export PATH=/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go
time make build

echo "--- Run unit tests"
time dune runtest "${path}" --profile="${profile}" -j16 || (./scripts/link-coredumps.sh && false)
