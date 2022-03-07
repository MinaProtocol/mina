#!/bin/bash

. lib.sh

req /block '{ network_identifier: { blockchain: "mina", network: "devnet" }, block_identifier: { index: 15410 }, metadata: {} }'

