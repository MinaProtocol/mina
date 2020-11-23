#!/bin/bash

. lib.sh

req '/construction/derive' '{"network_identifier": { "blockchain": "coda", "network": "debug" }, "public_key": { "curve_type": "tweedle", "hex_bytes": "34113cb487a3f7620eade46a6d4ffce2cab59c31b28e7c57ba2c58a02158a9ec0a6c3eb1eeaec79c61ea5421c8e4f244e64f7e336ce15d8d9ce3d325ebe40b73"}}'
