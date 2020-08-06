#!/bin/bash

. lib.sh

req /account/balance '{ network_identifier: { blockchain: "coda", network: "debug" }, account_identifier: { "address": "B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g" },  metadata: {} }'

