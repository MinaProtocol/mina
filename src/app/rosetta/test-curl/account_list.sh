#!/bin/bash

. lib.sh

req /account/balance '{ network_identifier: { blockchain: "coda", network: "debug" }, account_identifier: { "address": "B62qkV77S1iHryAAWRdRAp4HDBXfQhka3wYmMQSWhoHc8ftNpR44Zct" },  metadata: {} }'

