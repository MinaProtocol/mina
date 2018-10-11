#!/bin/bash

set -eo pipefail

eval `opam config env`

TEST=$1

# ugly hack to clean up dead processes
pkill -9 exe
pkill -9 kademlia
pkill -9 coda
sleep 1
dune exec coda -- integration-tests ${TEST}
