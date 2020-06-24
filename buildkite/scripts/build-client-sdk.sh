#!/bin/bash

set -o pipefail

mkdir -p /tmp/artifacts
eval `opam config env` && make client_sdk 2>&1 | tee /tmp/artifacts/buildclientsdk.log
