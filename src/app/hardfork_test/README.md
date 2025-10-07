# Hardfork Test

A Go application that implements the control flow from `scripts/hardfork/test.sh`, allowing for testing of hardfork functionality in the Mina Protocol.

## Overview

This application replicates the functionality of the shell script `scripts/hardfork/test.sh` but with the added benefit of using Go's more structured programming environment. The hardfork test:

1. Starts a main network with a specified Mina executable
2. Verifies that blocks are being produced and transactions are flowing
3. Extracts the necessary fork configuration at a specified slot
4. Shuts down the main network
5. Processes the fork configuration to generate hardfork ledgers
6. Starts a new network with the fork executable and verifies its operation

## Installation

```
cd /path/to/mina/src/app/hardfork_test
go build -o hardfork_test ./cmd
```

## Usage

```
./hardfork_test --main-mina-exe /path/to/mina \
  --main-runtime-genesis-ledger /path/to/runtime_genesis_ledger \
  --fork-mina-exe /path/to/mina-fork \
  --fork-runtime-genesis-ledger /path/to/runtime_genesis_ledger-fork
```

### Required Arguments

- `--main-mina-exe`: Path to the main Mina executable
- `--main-runtime-genesis-ledger`: Path to the main runtime genesis ledger executable
- `--fork-mina-exe`: Path to the fork Mina executable
- `--fork-runtime-genesis-ledger`: Path to the fork runtime genesis ledger executable

### Optional Arguments

- `--slot-tx-end`: Slot at which transactions should end (default: 30)
- `--slot-chain-end`: Slot at which chain should end (default: slot-tx-end + 8)
- `--best-chain-query-from`: Slot from which to start calling bestchain query (default: 25)
- `--main-slot`: Slot duration in seconds for main version (default: 15)
- `--fork-slot`: Slot duration in seconds for fork version (default: 15)
- `--main-delay`: Delay before genesis slot in minutes for main version (default: 20)
- `--fork-delay`: Delay before genesis slot in minutes for fork version (default: 10)
- `--timeout`: Timeout for the test in minutes (default: 30)

## Environment Variables

- `DEBUG=1`: Enable debug logging

## Example

```
./hardfork_test \
  --main-mina-exe ./mina \
  --main-runtime-genesis-ledger ./runtime_genesis_ledger \
  --fork-mina-exe ./mina-develop \
  --fork-runtime-genesis-ledger ./runtime_genesis_ledger-develop \
  --slot-tx-end 40 \
  --main-delay 10
```
