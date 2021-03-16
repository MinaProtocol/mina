#!/bin/bash

set -eo pipefail
set +x

# Activate service account/cluster credentials if provided
if [[ -n ${PEERS_LIST_OVERRIDE} ]]; then
    echo "Peers list override, ${PEERS_LIST_OVERRIDE}, provided. Overriding peers list..."

    curl ${PEERS_LIST_OVERRIDE} -o /root/peers.txt
fi
