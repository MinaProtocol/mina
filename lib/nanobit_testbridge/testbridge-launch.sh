#!/bin/bash

trap 'kill $(jobs -p)' EXIT
cd "$(dirname "$0")"/../../

eval `opam config env` && jbuilder build
_build/install/default/bin/cli rpc > /app/logs 2>&1

