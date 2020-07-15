#!/bin/bash

. lib.sh

req /network/status '{ network_identifier: { blockchain: "coda", network: "debug" }, metadata: {} }'

