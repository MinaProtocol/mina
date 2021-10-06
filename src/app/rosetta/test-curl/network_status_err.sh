#!/bin/bash

. lib.sh

req /network/status '{ network_identifier: { blockchain: "not_mina", network: "not_debug" }, metadata: {} }'

