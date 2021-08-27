#!/bin/bash

set -eou pipefail

export MINA_NETWORK=devnet2
export MINA_SUFFIX="-dev"
./docker-start.sh $@
