#!/bin/bash

. lib.sh

req /block '{ network_identifier: { blockchain: "mina", network: "devnet" }, block_identifier: { index: 52676 }, metadata: {} }'

