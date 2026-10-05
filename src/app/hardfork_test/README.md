# Hardfork Test

A Go application for testing hardfork functionality in the Mina Protocol. This test validates that a network can successfully transition from one protocol version to another through a hardfork mechanism.

## Overview

### High-Level Test Sequence

The hardfork test simulates a complete protocol upgrade by running two sequential networks:

**Phase 1: Pre-Fork Network**
1. **Network Initialization**: Starts a Mina network using the pre-fork executable with genesis configuration
2. **Activity Verification**: Waits for blocks to be produced and sends transactions to ensure the network is functioning properly
3. **Fork Preparation**: At a specified slot, queries the network's best chain to capture the current state, validates stop slots function well
4. **State Extraction**: Extracts the fork config needed for the hardfork
5. **Shutdown**: Stops the pre-fork network cleanly

**Phase 2: Post-Fork Network**
6. **Hardfork Ledger Generation**: Processes the extracted state to create hardfork-compatible genesis ledgers using the fork version's `runtime_genesis_ledger` tool
7. **Fork Network Start**: Launches a new network using the post-fork executable with the generated hardfork ledgers
8. **Continuity Verification**: Validates that the new network can continue from the forked state by producing blocks and processing transactions

### What This Tests

This validates the critical hardfork mechanism:
- **State Continuity**: The new protocol version can correctly interpret and continue from the old version's ledger state
- **Protocol Compatibility**: The fork configuration and ledger format are compatible between versions
- **Network Functionality**: Both pre-fork and post-fork networks operate correctly (block production, transaction processing)
- **Hardfork Tooling**: The `runtime_genesis_ledger` tool correctly generates hardfork genesis ledgers from the extracted state

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

#### Test Configuration
- `--slot-tx-end`: Slot at which transactions should end (default: 30)
- `--slot-chain-end`: Slot at which chain should end (default: 38)
- `--best-chain-query-from`: Slot from which to start calling bestchain query (default: 25)

#### Slot Configuration
- `--main-slot`: Slot duration in seconds for main version (default: 15)
- `--fork-slot`: Slot duration in seconds for fork version (default: 15)

#### Delay Configuration
- `--main-delay`: Delay before genesis slot in minutes for main version (default: 5)
- `--fork-delay`: Delay before genesis slot in minutes for fork version (default: 5)

#### Script Configuration
- `--script-dir`: Path to the hardfork script directory (default: "$PWD/scripts/hardfork")

#### Timeout Configuration
- `--shutdown-timeout`: Timeout in minutes to wait for graceful shutdown before forcing kill (default: 10)
- `--http-timeout`: HTTP client timeout in seconds for GraphQL requests (default: 600)

#### Polling and Retry Configuration
- `--polling-interval`: Interval in seconds for polling height checks (default: 5)
- `--fork-config-retry-delay`: Delay in seconds between fork config fetch retries (default: 60)
- `--fork-config-max-retries`: Maximum number of retries for fork config fetch (default: 15)
- `--no-new-blocks-wait`: Wait time in seconds to verify no new blocks after chain end (default: 300)
- `--user-command-check-max-iterations`: Max iterations to check for user commands in blocks (default: 10)
- `--fork-earliest-block-max-retries`: Maximum number of retries to wait for earliest block in fork network (default: 10)
- `--graphql-max-retries`: Maximum number of retries for GraphQL requests (default: 5)

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
