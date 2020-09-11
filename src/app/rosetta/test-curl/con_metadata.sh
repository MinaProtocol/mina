#!/bin/bash

. lib.sh

req '/construction/metadata' '{ network_identifier: { blockchain: "coda", network: "debug" }, options: {sender: "B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g", token_id: "1"}, metadata: {} }'

