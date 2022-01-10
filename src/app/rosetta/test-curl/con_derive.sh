#!/bin/bash

echo "update me for pasta curves"
exit 1

. lib.sh

req '/construction/derive' '{"network_identifier": { "blockchain": "mina", "network": "debug" }, "public_key": { "curve_type": "tweedle", "hex_bytes": "207115e9f11a9134c2d99270354e02a0b3fcee5bea40a1fbd410e05948a181631ff4f1f372ef6ae2b2e391fd4d6254810118b3c8b2c6697d68ea10bc3b059ffb"}}'

