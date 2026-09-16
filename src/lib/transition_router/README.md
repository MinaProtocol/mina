# Transition Router

The transition router is the top-level component responsible for routing
incoming transitions (blocks and headers) from the network to the appropriate
sub-system. It manages the lifecycle between two mutually exclusive operational
modes: the **bootstrap controller** and the **transition frontier controller**.

## Overview

When a Mina node starts up, or when it falls too far behind the canonical chain,
it must first synchronize its state with the rest of the network before it can
participate in consensus. The transition router orchestrates this by:

1. Waiting until the chain's genesis timestamp has been reached
   (`wait_till_genesis`). If the node starts before the chain launch time, it
   blocks and logs periodic status updates until the genesis time arrives.
2. Waiting for the node to reach sufficient network connectivity.
3. Downloading the best tip from a sample of peers.
4. Loading the local persistent frontier (if one exists).
5. Deciding, based on the downloaded best tip and local frontier state, whether
   to enter **bootstrap mode** or **normal participation mode**.
6. Continuously monitoring the network for transitions that require switching
   from normal participation back into bootstrap mode.

## Operational Modes

### Bootstrap Mode

Bootstrap mode is activated when the node cannot catch up to the network using
only its local frontier. This happens in two cases:

- The node has no local frontier (e.g., first start or corrupted state).
- The network's best tip is so far ahead of the node's best tip that
  catchup is not feasible (more than `k + 5` blocks beyond the local best
  tip, where `k` is the consensus security parameter and 5 is a small slack
  constant; on mainnet `k = 290`, so the threshold is 295 blocks). Note:
  the code currently hardcodes 290 rather than reading `k` from the
  consensus constants.

In bootstrap mode, the **bootstrap controller** reconstructs the root of the
transition frontier from scratch by downloading the snarked ledger, scan state,
pending coinbases, and local consensus state from peers. Once bootstrapping
completes, the transition router automatically transitions to normal
participation mode.

### Normal Participation Mode (Transition Frontier Controller)

Normal participation mode is activated when the node's local frontier is close
enough to the network's best tip that standard catchup can close the gap. In
this mode, the **transition frontier controller** processes incoming blocks and
headers, extending the frontier and participating in consensus.

## Data Flow

```
Network Transitions
      │
      ▼
 Initial Validator
  (validates time, genesis state, proofs, protocol version)
      │
      ▼
 valid_transition_pipe
      │
      ├──► most_recent_valid_block_writer (broadcast pipe, updated on best tip changes)
      │
      └──► network_transition_pipe (Swappable)
                │
                ├── Bootstrap Controller (during bootstrap)
                │
                └── Transition Frontier Controller (during normal participation)
                          │
                          ▼
               verified_transition_reader (output to the rest of the daemon)
```

The `network_transition_pipe` is a **swappable pipe**: when switching between
bootstrap and frontier controller, the reader end of the pipe is swapped so the
new controller receives subsequent transitions without losing buffered ones.

## Key Functions

### `run`

The main entry point for the transition router. Sets up all internal pipes,
starts the initial validator background thread, and calls `initialize` to
determine the starting operational mode. After initialization, it also monitors
the stream of validated transitions to detect when the node has fallen behind
the network and must re-enter bootstrap mode.

### `initialize`

Concurrently downloads the network's best tip and attempts to load the local
persistent frontier, then decides which mode to start in:

| Frontier available? | Best tip far ahead? | Action |
|---------------------|---------------------|--------|
| No                  | —                   | Start bootstrap |
| Yes                 | Yes                 | Close frontier, start bootstrap |
| Yes                 | No                  | Sync local state, start frontier controller |

### `start_bootstrap_controller`

Starts the bootstrap controller. When bootstrapping completes, automatically
calls `start_transition_frontier_controller` with the newly constructed
frontier and any transitions collected during the bootstrap phase.

### `start_transition_frontier_controller`

Starts the transition frontier controller with an existing frontier. Swaps the
`network_transition_pipe` reader so the controller receives new transitions from
the point of the swap onward.

### `is_transition_for_bootstrap`

Determines whether a newly observed transition header is so far ahead of the
local frontier that the node must bootstrap again rather than catch up. The
function uses a multi-stage check:

1. Runs `Consensus.Hooks.select` comparing the candidate against the frontier
   **root** consensus state. If the root is already preferred (`Keep`), the
   transition does not trigger bootstrap.
2. If the candidate is preferred (`Take`), checks whether it is more than
   `k + 5` blocks beyond the node's current **best tip**, where `k` is the
   consensus security parameter (290 on mainnet) and 5 is a slack constant.
   If so, the entire frontier is considered useless and bootstrap is
   triggered immediately. (The value 290 is hardcoded in
   `transition_router.ml` rather than derived from `consensus_constants`.)
3. Otherwise, falls through to `Consensus.Hooks.should_bootstrap`, which
   applies the full consensus-level bootstrap check comparing the candidate
   against the frontier root.

### `download_best_tip`

Queries up to 16 random peers for their best tips, verifies the proofs attached
to each tip, and returns the strongest verified tip. This is used during
initialization to determine the starting operational mode.

### `load_frontier`

Attempts to load the node's previously persisted transition frontier from disk.
Returns `None` if no usable frontier is found (e.g., bootstrap is required or
the persistent state is out of sync). Note: the node will crash (`failwith`)
if the persistent frontier is malformed or if frontier initialization fails
with an unrecoverable error.

## Initial Validator

The `Initial_validator` submodule performs a series of validation checks on
each incoming block or header before it enters the main processing pipeline:

- **Time received**: the block must not arrive too early or too late relative
  to the expected slot time.
- **Genesis protocol state**: the block's genesis state hash must match the
  node's genesis state.
- **Blockchain SNARK proof**: the header's blockchain proof is verified through
  the external verifier process. This check is asynchronous and uses the
  `Interruptible` monad so it can be cancelled if the libp2p validation
  callback expires.
- **Delta block chain proof**: the header's delta transition chain proof must
  be valid.
- **Protocol version**: the block's protocol version must be compatible with
  the node's version.
- **Duplicate block detection**: the `Duplicate_block_detector` tracks blocks
  by (producer, epoch, slot). If a different block hash is seen for the same
  producer and slot as a previously observed block, an error is logged to flag
  potential double-block production. This check does not reject the block but
  serves as a protocol monitoring signal.

Blocks that fail initial validation are dropped and the sending peer's trust
score is penalized accordingly.
