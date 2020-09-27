#!/bin/bash

. lib.sh

req '/construction/derive' '{ network_identifier: { blockchain: "coda", network: "debug" }, public_key: { curve_type: "tweedle", "hex_bytes": "21227618273287912396165511354759877742861476866949599417678373301795282006724,11761867550482237699134088709817635784025718458005116627359241002522206048613" }, metadata: {} }'

