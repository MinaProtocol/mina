#!/bin/bash
set -o pipefail
set +x

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <dune-profile> <path-to-source-tests>"
    exit 1
fi

profile=$1
path=$2

source ~/.profile
    && make build
    && (dune runtest ${path} --profile=${profile} -j8 || (./scripts/link-coredumps.sh && false))
