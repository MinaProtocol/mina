#!/bin/bash

FORK_CONFIG_JSON=${FORK_CONFIG_JSON:=fork_config.json}
RUNTIME_CONFIG_JSON=${RUNTIME_CONFIG_JSON:=runtime_config.json}

# If not given, the genesis timestamp is set to 10 mins into the future
GENESIS_TIMESTAMP=${GENESIS_TIMESTAMP:=$(date -u +"%Y-%m-%dT%H:%M:%SZ" -d "10 mins")}
LEDGER_NAME=${LEDGER_NAME:="\"berkeley\""}

# Construct the runtime config.
# Note that we do not transfer all values, to allow the network configuration
# etc. to differ from the pre-hard-fork one.
# Note also that only those fields of accounts that may have non-default values
# in accounts have been preserved, to minimize parsing errors.

# This is formed of:
# * The genesis configuration, containing
#   - the genesis timestamp
# * The fork configuration, containing
#   - the previous state hash,
#   - the bockchain length, and
#   - the global slot.
# * The genesis ledger, containing
#   - the ledger name ("berkeley"),
#   - a false flag for adding an extra 'genesis winner account' (used for testing), and
#   - the accounts from the ledger, formed of:
#     + the public key,
#     + the balance,
#     + the balance timing data (if present),
#     + the delegate,
#     + the nonce, and
#     + the receipt chain hash.
# * The staking epoch data, containing
#   - the epoch seed, and
#   - the accounts from the ledger, formed of:
#     + the public key,
#     + the balance,
#     + the balance timing data (if present),
#     + the delegate,
#     + the nonce, and
#     + the receipt chain hash.
# * The next epoch data, containing
#   - the epoch seed, and
#   - the accounts from the ledger, formed of:
#     + the public key,
#     + the balance,
#     + the balance timing data (if present),
#     + the delegate,
#     + the nonce, and
#     + the receipt chain hash.
jq "{\
    genesis: .genesis,\
    proof: .proof,\
    ledger: {\
        name: $LEDGER_NAME,\
        add_genesis_winner: false,\
        accounts:\
            .ledger.accounts\
            | map({\
                pk: .pk,\
                balance: .balance,\
                timing: .timing,\
                delegate: .delegate,\
                nonce: .nonce,\
                receipt_chain_hash: .receipt_chain_hash}\
                | del(..|nulls))\
    },\
    epoch_data: {\
        staking: {\
            seed: .epoch_data.staking.seed,\
            accounts:\
                .epoch_data.staking.accounts\
                | map({\
                    pk: .pk,\
                    balance: .balance,\
                    timing: .timing,\
                    delegate: .delegate,\
                    nonce: .nonce,\
                    receipt_chain_hash: .receipt_chain_hash}\
                    | del(..|nulls))\
        },\
        next: {\
            seed: .epoch_data.next.seed,\
            accounts:\
                .epoch_data.next.accounts\
                | map({\
                    pk: .pk,\
                    balance: .balance,\
                    timing: .timing,\
                    delegate: .delegate,\
                    nonce: .nonce,\
                    receipt_chain_hash: .receipt_chain_hash}\
                    | del(..|nulls))\
        }\
    }\
} | .genesis.genesis_state_timestamp = \"$GENESIS_TIMESTAMP\"" $FORK_CONFIG_JSON > $RUNTIME_CONFIG_JSON