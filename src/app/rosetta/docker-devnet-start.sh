#!/bin/bash

set -eou pipefail

export MINA_NETWORK=devnet
export MINA_SUFFIX="-dev"
./docker-start.sh $@
