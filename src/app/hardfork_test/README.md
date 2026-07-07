# Hardfork Test

A Go application for testing hardfork functionality in the Mina Protocol. This test validates that a network can successfully transition from one protocol version to another through a hardfork mechanism.

## Overview

### Network Topology

By default the test runs a compact network of **2 Mina nodes and 2 snark
workers**: the seed node and the snark coordinator each double as a whale block
producer (via the `--seed-is-whale` / `--snark-coordinator-is-whale` options of
`mina-local-network.sh`), so no standalone whale daemons are spawned. This keeps
two block producers (for healthy slot occupancy) while halving the daemon count.

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

### Fork methods

One or more fork methods are requested via `--allow-fork-method` (repeatable);
valid values are `legacy`, `advanced`, and `auto`:

- **legacy** — migrates the ledger via `runtime_genesis_ledger` (applies the
  slot-reduction update correctly).
- **advanced** — `mina advanced generate-hardfork-config` against the live
  daemon; uses the converting ledger / `migrate_to_mesa`.
- **auto** — daemon self-generates its hardfork config at slot-chain-end under
  `--hardfork-handling migrate-exit`; also uses `migrate_to_mesa`. Auto daemons
  **exit** at slot-chain-end.

Each requested method is assigned to **at least one** daemon (remaining daemons
get a random method from the set), so:

- Requesting more methods than there are daemons fails with an error — request
  fewer methods or grow the network with `--num-whales` / `--num-fish` /
  `--num-nodes`.
- At least one **non-auto** method is required, because auto daemons exit at
  slot-chain-end and the post-fork checks need a still-running daemon. Use
  `advanced` for an auto-equivalent migration path that keeps the daemon alive.

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

#### Network Size
- `--num-whales`: Number of whale (block-producer) accounts (default: 2). Whales
  beyond those absorbed by the seed/snark-coordinator run as standalone daemons.
- `--num-fish`: Number of fish (smaller block-producer) daemons (default: 0)
- `--num-nodes`: Number of plain (non-block-producing) daemons (default: 0)

The number of daemons bounds how many fork methods can be requested: every
`--allow-fork-method` value is assigned to at least one daemon (see "Fork
methods" below), so requesting more methods than there are daemons is an error.

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
