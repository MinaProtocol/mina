#!/bin/bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0  <path-to-source-tests>"
    exit 1
fi

path=$1

eval "$(opam config env)"
export PATH="/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH"
export GO=/usr/lib/go/bin/go

# TODO: Stop building lib_p2p multiple times by pulling from buildkite-agent artifacts or docker or somewhere
echo "--- Build libp2p_helper TODO: use the previously uploaded build artifact"
make -C src/app/libp2p_helper

export MINA_LIBP2P_PASS="naughty blue worm"
export MINA_PRIVKEY_PASS="naughty blue worm"

echo "--- Make build"
export LIBP2P_NIXLESS=1 PATH=/usr/lib/go/bin:$PATH GO=/usr/lib/go/bin/go
time make build

echo "--- Run tests"
dune exec "${path}" -- -v 
