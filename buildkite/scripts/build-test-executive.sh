#!/bin/bash

set -eo pipefail

echo "--- setup opam config environment"
eval `opam config env`
export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go

echo "--- build test-executive"
dune build --verbose --profile=${DUNE_PROFILE} src/app/test_executive/test_executive.exe src/app/logproc/logproc.exe

echo "--- build complete, preparing test-executive for caching"
# copy built binary to current location and adjust permissions
cp _build/default/src/app/test_executive/test_executive.exe .
chmod +rwx test_executive.exe

cp _build/default/src/app/logproc/logproc.exe .
chmod +rwx logproc.exe
