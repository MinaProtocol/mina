#!/bin/bash

. lib.sh

req /network/status '{ network_identifier: { blockchain: "mina", network: "debug" }, metadata: {} }'

