#!/bin/bash

. lib.sh

req /account/balance '{ network_identifier: { blockchain: "coda", network: "debug" }, account_identifier: { "address": "ZsMSUuKL9zLAF7sMn951oakTFRCCDw9rDfJgqJ55VMtPXaPa5vPwntQRFJzsHyeh8R8" },  metadata: {} }'

