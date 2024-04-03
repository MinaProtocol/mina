#!/bin/bash

set -eou pipefail

export MINA_NETWORK=berkeley
export MINA_SUFFIX="-dev"
export MINA_CONFIG_FILE=/genesis_ledgers/${MINA_NETWORK}.json

./docker-start.sh $@
