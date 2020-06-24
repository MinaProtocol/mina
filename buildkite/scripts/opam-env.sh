#!/bin/bash

set -o pipefail

eval `opam config env` && make client_sdk 2>&1 | tee /tmp/artifacts/buildclientsdk.log
