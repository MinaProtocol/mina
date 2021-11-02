#!/bin/bash

set -eou pipefail

export MINA_NETWORK=devnet
./docker-start.sh $@
