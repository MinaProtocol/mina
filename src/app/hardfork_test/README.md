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

### Example Usage

This is the use in `scripts/hardfork/build-and-test.sh`:
```
./hardfork_test/bin/hardfork_test \
  --main-mina-exe prefork-devnet/bin/mina \
  --main-runtime-genesis-ledger prefork-devnet/bin/runtime_genesis_ledger \
  --fork-mina-exe postfork-devnet/bin/mina \
  --fork-runtime-genesis-ledger postfork-devnet/bin/runtime_genesis_ledger \
  --slot-tx-end "$SLOT_TX_END" \
  --slot-chain-end "$SLOT_CHAIN_END" \
  --script-dir "$SCRIPT_DIR" \
  --root "$NETWORK_ROOT"
```

### CLI arguments

Run `hardfork_test --help` for a human readable list of CLI args, or refer to `internal/app/root.go` and `internal/config/config.go` for the implementation of them.

