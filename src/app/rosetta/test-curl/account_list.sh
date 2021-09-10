#!/bin/bash

. lib.sh

req /account/balance '{ network_identifier: { blockchain: "mina", network: "debug" }, account_identifier: { "address": "B62qmnkbvNpNvxJ9FkSkBy5W6VkquHbgN2MDHh1P8mRVX3FQ1eWtcxV" },  metadata: {} }'

