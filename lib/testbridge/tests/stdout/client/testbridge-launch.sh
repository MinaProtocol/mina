#!/bin/bash

trap 'kill $(jobs -p)' EXIT
cd "$(dirname "$0")"
cp /testbridge/testbridge.opam /app/stdout.opam

eval `opam config env` && dune build
_build/install/default/bin/stdout_client > /app/logs 2>&1
