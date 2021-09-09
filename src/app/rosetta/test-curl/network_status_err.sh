#!/bin/bash

. lib.sh

req /network/status '{ network_identifier: { blockchain: "not_coda", network: "not_debug" }, metadata: {} }'

