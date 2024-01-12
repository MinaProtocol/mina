#!/bin/bash

. lib.sh

req /account/balance '{ network_identifier: { blockchain: "mina", network: "devnet" }, account_identifier: { "address": "B62qmo4nfFemr9hFtvz8F5h4JFSCxikVNsUJmZcfXQ9SGJ4abEC1RtH" }, block_identifier: { index: 100 },  metadata: {} }'

