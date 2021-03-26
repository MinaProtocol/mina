#!/bin/bash

set -eo pipefail

if [[ -n ${PEERS_LIST_OVERRIDE} ]]; then
    echo "Peers list override, ${PEERS_LIST_OVERRIDE}, provided. Overriding peers list..."

    curl ${PEERS_LIST_OVERRIDE} -o /root/peers.txt
fi
