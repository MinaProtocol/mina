Runtime Genesis Ledger
=====================

The `runtime_genesis_ledger` utility is a tool for generating genesis ledgers and
associated proof data for the Mina blockchain. It allows developers and network
operators to create custom genesis configurations for testing, development, or
launching new networks.

A genesis ledger is the initial state of accounts in a blockchain network. In
Mina, the genesis ledger is cryptographically encoded in the genesis block, and
this tool helps create the necessary files and cryptographic proofs for that
process.

Features
--------

- Generates genesis ledger from a JSON configuration file
- Creates cryptographic proof files necessary for blockchain initialization
- Outputs hash information for ledger verification
- Supports custom account configurations
- Handles both main ledger and epoch ledgers (staking and next)

Prerequisites
------------

Before using `runtime_genesis_ledger`, you need:

1. A configuration file in JSON format that defines the initial accounts and
   their balances. Examples can be found in the `genesis_ledgers` directory in
   the Mina repository.

2. A directory where the generated ledger and proof files will be stored.

Compilation
----------

To compile the `runtime_genesis_ledger` executable, run:

```shell
$ dune build src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --profile=dev
```

Or use the following make command:

```shell
$ make genesis_ledger
```

The executable will be built at:
`_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe`

Usage
-----

The basic syntax for running `runtime_genesis_ledger` is:

```shell
$ runtime_genesis_ledger --config-file PATH --genesis-dir DIR --hash-output-file PATH [OPTIONS]
```

### Required Parameters

- `--config-file PATH`: Path to the JSON configuration file defining the genesis
  accounts and other parameters.

- `--genesis-dir DIR`: Directory where the genesis ledger and genesis proof will
  be saved. This directory will contain tar files with the encoded ledger data.

- `--hash-output-file PATH`: Path to the file where the hashes of the ledgers
  will be saved. This is essential for ledger verification.

### Optional Parameters

- `--ignore-missing`: If provided, missing fields in account definitions will be
  ignored and replaced with default values. Otherwise, missing fields will cause
  errors.

### Configuration File Format

The configuration file should be a JSON file with a structure that defines the
accounts in the genesis ledger. Here's a simplified example:

```json
{
  "ledger": {
    "base": {
      "accounts": [
        {
          "pk": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
          "balance": "66000",
          "delegate": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg"
        },
        {
          "pk": "B62qjsV6WQfXf7JjCNbKL5Q5WPU3XdECRmNS7Jgx5Lv9JvKvs3xASmR",
          "balance": "10000"
        }
      ]
    },
    "add_genesis_winner": false
  },
  "epoch_data": {
    "staking": {
      "ledger": {
        "base": {
          "accounts": [
            {
              "pk": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
              "balance": "66000",
              "delegate": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg"
            }
          ]
        },
        "add_genesis_winner": false
      }
    }
  }
}
```

Each account must have a public key (`pk`) and a balance. Other fields like
`delegate` are optional.

Examples
--------

Generate a genesis ledger using a custom configuration file:

```shell
$ runtime_genesis_ledger \
    --config-file ./genesis_ledgers/devnet.json \
    --genesis-dir /tmp/coda_cache_dir \
    --hash-output-file /tmp/ledger_hashes.json
```

Generate a genesis ledger, ignoring missing fields in the configuration:

```shell
$ runtime_genesis_ledger \
    --config-file ./genesis_ledgers/custom.json \
    --genesis-dir /tmp/coda_cache_dir \
    --hash-output-file /tmp/ledger_hashes.json \
    --ignore-missing
```

Technical Notes
--------------

- The tool generates three ledgers: the main genesis ledger, a staking epoch
  ledger, and a next epoch ledger.

- If the epoch ledgers are not specified in the configuration, they will default
  to using the main genesis ledger configuration.

- The tool outputs a JSON file containing the cryptographic hashes of the
  generated ledgers, which can be used for verification.

- The generated tar files contain the Merkle tree representation of the ledger,
  which is used by the Mina daemon during startup.

- The JSON hashes file includes:
  - `ledger.hash`: The Merkle root hash of the genesis ledger
  - `ledger.s3_data_hash`: A hash of the ledger tarball
  - `epoch_data.staking.hash`: The Merkle root hash of the staking epoch ledger
  - `epoch_data.next.hash`: The Merkle root hash of the next epoch ledger