#!/bin/bash

. lib.sh

req /block '{ network_identifier: { blockchain: "coda", network: "debug" }, block_identifier: { }, metadata: {} }'

