# Hardfork Test

A Go application for testing hardfork functionality in the Mina Protocol. This test validates that a network can successfully transition from one protocol version to another through a hardfork mechanism.

Reading a CI log for this test? [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) catalogues
the warnings, fatal-looking crash reports and timing errors that every healthy
run produces, so you can tell known noise from a new problem.

## Overview

### Network Topology

The network's shape is **data, not code**. It lives with mina-local-network's
other presets, in
[`scripts/mina-local-network/presets/`](../../../scripts/mina-local-network/presets),
next to the schema that governs it:

| preset | `build-and-test.sh --topology` | daemons | used by |
| --- | --- | --- | --- |
| `hf-test-legacy.jsonc` | `legacy` (default) | 2 | `HardForkTestLegacy` |
| `hf-test-mixed.jsonc` | `mixed` | 3 | `HardForkTestMixed` — three fork methods need three daemons |

The presets are read from disk, not compiled in, so editing one does not mean
rebuilding this binary. `build-and-test.sh` maps the short name to a path and
passes it as `--topology-file`; the binary itself only ever takes a path.

The default `legacy` network is compact: **2 Mina nodes and 2 snark workers**.
Both whale accounts are absorbed by the two nodes rather than being spawned as
standalone whale daemons, so the network keeps two block producers (for healthy
slot occupancy) while halving the daemon count.

To change the network — add a node, retune a balance, resize a worker pool —
edit the preset. The daemon list is derived from it, so there is nothing to keep
in sync. To add a shape, drop in a new `hf-test-<name>.jsonc` and pass `<name>`
to `build-and-test.sh --topology`. mina-local-network's own test suite validates
every preset against the schema, so a malformed one fails there rather than
mid-run.

The test overlays only what cannot be known until the run (binaries, the state
root, the genesis timestamp, per-node fork arguments) and hands the result to
`mina-local-network.py`, which plans and spawns it. Ports are never assigned
here: the planner allocates them and the test reads them back from
`<root>/network-plan.json`.

#### Node names

Nodes are named after what they are, so a name cannot drift from a node's actual
role:

```
<balance-tier>-<cap1>+<cap2>+...-<id>
```

The tier prefix is omitted for a node with no balance tier, a node with no
capabilities is named `plain`, and `<id>` is unique across the network.
Capability tokens are `seed`, `bp` (block producer), and `coordinator` (snark
coordinator). The `legacy` topology is:

```
whale-seed+bp+coordinator-0   seed, block producer (whale-0), snark coordinator
whale-bp-1                    block producer (whale-1)
```

and `mixed` adds `plain-2`, which validates only. A larger network would extend
the same scheme:

```
whale-bp-2, whale-bp-3        further standalone whale block producers
fish-bp-4, fish-bp-5          fish block producers (accounts fish-0, fish-1)
```

Note the snark coordinator runs on the seed node; there is no separate
coordinator daemon.

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
- **Vesting Slot-Reduction Update**: A timed (vesting) account is seeded into the pre-fork genesis ledger, and after the fork its timing is checked to confirm the Mesa slot-reduction update was applied (vesting period doubled, cliff advanced) — see "Vesting account test" below

### Vesting account test

Before the fork, the harness injects a timed account into the pre-fork genesis
ledger (by pointing the topology's `ledger_generation.extra_accounts_file` at a
file it generates). The account is "not yet vesting" at the hardfork slot and
fully unlocks at its cliff, which is placed `2 * offset` slots after the
hardfork under correct migration (`offset` slots without it).

After the fork the harness:
1. Asserts the migrated `timingInfo` (queried via GraphQL) equals the expected
   slot-reduction-updated values — i.e. `vesting_period` doubled and
   `cliff_time` advanced to `hardfork_slot + 2*(cliff_time - hardfork_slot)`.
2. Watches the account's `liquid` balance and fails if it unlocks before the
   correct (migrated) cliff slot.

This specifically targets the `Account.Hardfork.migrate_to_mesa` migration path
(`src/lib/mina_base/account.ml`). That path is exercised by the live daemon
during migration, so to test the bug end-to-end run with the `auto` (or
`advanced`) fork method; with `legacy` the account is migrated via
`runtime_genesis_ledger` instead, and the same assertions validate that path.
The test is always on and requires no extra flags.

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
  fewer methods, or select a topology with more nodes via `--topology-file`.
- At least one **non-auto** method is required, because auto daemons exit at
  slot-chain-end and the post-fork checks need a still-running daemon. Use
  `advanced` for an auto-equivalent migration path that keeps the daemon alive.

**Caveat — do not mix `legacy` with `auto`/`advanced` while the vesting test is
on.** Because of the `migrate_to_mesa` bug, `legacy` (correct) and
`auto`/`advanced` (buggy) migrate the injected timed account differently,
producing different post-fork genesis ledger hashes; the nodes then compute
different chain IDs and cannot peer, so the network fails to form instead of the
vesting assertion firing. For a clean single-path signal use **`--allow-fork-method advanced`**
(all daemons hit the buggy `migrate_to_mesa` path, the network forms, and
`ValidateVestingAfterFork` fails as designed); use `--allow-fork-method legacy`
as the green control.

## Usage

```
./hardfork_test --main-mina-exe /path/to/mina \
  --main-runtime-genesis-ledger /path/to/runtime_genesis_ledger \
  --fork-mina-exe /path/to/mina-fork \
  --fork-runtime-genesis-ledger /path/to/runtime_genesis_ledger-fork \
  --allow-fork-method advanced \
  --script-dir /path/to/scripts/hardfork \
  --topology-file /path/to/scripts/mina-local-network/presets/hf-test-legacy.jsonc
```

Most runs go through
[`scripts/hardfork/build-and-test.sh`](../../../scripts/hardfork/build-and-test.sh),
which builds both binaries and resolves `--topology <name>` to the preset path
for you.

### Required Arguments

- `--main-mina-exe`: Path to the main Mina executable
- `--main-runtime-genesis-ledger`: Path to the main runtime genesis ledger executable
- `--fork-mina-exe`: Path to the fork Mina executable
- `--fork-runtime-genesis-ledger`: Path to the fork runtime genesis ledger executable
- `--allow-fork-method`: Fork method to allow (repeatable; `legacy`, `advanced`, or
  `auto`). See "Fork methods" above.
- `--script-dir`: Path to the hardfork script directory. Has no default and is
  rejected when empty, so it must be passed even though it is not enforced by the
  flag parser.
- `--topology-file`: Path to the topology preset to run, e.g.
  `scripts/mina-local-network/presets/hf-test-legacy.jsonc`. Same story: no
  default, rejected when empty. Takes a **path**, not a name — resolving a name
  is `build-and-test.sh`'s job, so this binary never has to know the repo layout.

The topology declares the daemons, so it also bounds how many fork methods can
be requested: every `--allow-fork-method` value is assigned to at least one
daemon (see "Fork methods" below), so requesting more methods than the topology
has daemons is an error. Network size is not a command-line option — edit the
preset, or add a new one.

### Optional Arguments

#### Test Configuration
- `--slot-tx-end`: Slot at which transactions should end. Default: a random slot
  in `[30, 149]`, so runs sweep a range of fork points rather than always forking
  at the same slot. The effective value is logged at startup — pass it back to
  reproduce a run, as nothing else about the slot schedule is random.
- `--slot-chain-end`: Slot at which the chain should end; must exceed
  `--slot-tx-end` (default: `--slot-tx-end + 8`). The slots between the two are
  the run of empty blocks that buries the fork block, so the nodes agree on which
  block the fork was cut at.
- `--best-chain-query-from`: Slot from which to start calling bestchain query (default: 25)

#### Slot Configuration
- `--main-slot`: Slot duration in seconds for main version (default: 30)
- `--fork-slot`: Slot duration in seconds for fork version (default: 30)

#### Delay Configuration
- `--main-delay`: Delay before genesis slot in minutes for main version (default: 4).
  Must exceed the time it takes to materialize and spawn the network (~2min), or
  nodes start after the chain start time and miss early slots.
- `--hf-slot-delta`: Difference in slots between `--slot-chain-end` and the genesis
  of the new network (default: 18). Fork genesis is fixed before the run starts, so
  the daemons' idle wait before it is a residual — this many slots minus the work
  between chain end and the fork network being ready (413-446s across 12 measured CI
  runs, 300s of which is `--no-new-blocks-wait`). That residual is also the whole
  margin: if the work overruns it, the daemons start after fork genesis and produce
  no block.

#### Network Root
- `--root`: Directory in which to create a network; use an absolute path.

#### Timeout Configuration
- `--shutdown-timeout`: Timeout in minutes to wait for graceful shutdown before forcing kill (default: 10)
- `--http-timeout`: HTTP client timeout in seconds for GraphQL requests (default: 600)

#### Polling and Retry Configuration
- `--polling-interval`: Interval in seconds for polling height checks (default: 8)
- `--fork-config-retry-delay`: Delay in seconds between fork config fetch retries (default: 60)
- `--fork-config-max-retries`: Maximum number of retries for fork config fetch (default: 15)
- `--no-new-blocks-wait`: Wait time in seconds to verify no new blocks after chain end (default: 300)
- `--user-command-check-max-iterations`: Max iterations to check for user commands in blocks (default: 10)
- `--fork-earliest-block-max-retries`: Maximum number of retries to wait for earliest block in fork network (default: 10)
- `--client-max-retries`: Maximum number of retries for client requests (default: 5)

## Example

```
./hardfork_test \
  --main-mina-exe ./mina \
  --main-runtime-genesis-ledger ./runtime_genesis_ledger \
  --fork-mina-exe ./mina-develop \
  --fork-runtime-genesis-ledger ./runtime_genesis_ledger-develop \
  --allow-fork-method advanced \
  --script-dir ./scripts/hardfork \
  --slot-tx-end 40 \
  --main-delay 10
```
