#!/bin/bash

set -eo pipefail

# execute pre-processing steps like zexe-standardize.sh if set
if [ -n "${PREPROCESSOR}" ]; then echo "--- Executing preprocessor" && ${PREPROCESSOR}; fi

eval `opam config env`
export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go

dune build --verbose --profile=${DUNE_PROFILE} src/app/test_executive/test_executive.exe

# copy built binary to current location
cp _build/default/src/app/test_executive/test_executive.exe .