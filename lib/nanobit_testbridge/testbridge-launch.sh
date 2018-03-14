#!/bin/bash

set -e

trap 'kill $(jobs -p)' EXIT
cd "$(dirname "$0")"/../../

eval `opam config env` && jbuilder build >> /app/logs 2>&1

pushd app/kademlia-haskell
. ~/.profile
nix-build release2.nix >> /app/logs 2>&1
popd

_build/install/default/bin/cli prover -port 8002 >> /app/logs 2>&1 &
_build/install/default/bin/cli rpc >> /app/logs 2>&1 &

wait

killall kademlia || true

