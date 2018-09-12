#!/bin/bash

trap 'kill $(jobs -p)' EXIT
cd "$(dirname "$0")"
cp /testbridge/testbridge.opam /app/echo.opam

eval `opam config env` && dune build
_build/install/default/bin/echo_client > /app/logs 2>&1
