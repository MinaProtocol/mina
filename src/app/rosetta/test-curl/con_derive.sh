#!/bin/bash

# echo "update me for pasta curves"
# exit 1

. lib.sh

req '/construction/derive' '{"network_identifier": { "blockchain": "mina", "network": "debug" }, "public_key": { "curve_type": "pallas", "hex_bytes": "3C2B5B48C22DC8B8C9D2C9D76A2CEAAF02BEABB364301726C3F8E989653AF513"}}'

