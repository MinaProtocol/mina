#!/bin/bash

set -e

trap 'kill $(jobs -p)' EXIT
cd "$(dirname "$0")"
cp /testbridge/testbridge.opam /app/ccc.opam

eval `opam config env` && dune build
_build/install/default/bin/ccc_client > /app/logs 2>&1
