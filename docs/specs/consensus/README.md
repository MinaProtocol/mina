Ouroboros Samasika Consensus
----------------------------

Mina uses [Ouroboros Samasika](https://eprint.iacr.org/2020/352.pdf) for consensus, hereafter referred to as Samasika.  The three fundamental guarantees delivered are

* High decentralization - Self-bootstrap, uncapped participation and dynamic availability
* Succinctness - Constant-time synchronization with full-validation and high interoperability
* Universal composability - Proven security for interacting with other protocols, no slashing required

Samasika was invented by [Joseph Bonneau](https://jbonneau.com), [Izaak Meckler](https://math.berkeley.edu/~izaak), [Vanishree Rao](https://www.linkedin.com/in/vanishree-rao) and [Evan Shapiro](https://twitter.com/evanashapiro) as the first succinct blockchain consensus algorithm.  It extends many ideas from [Ouroboros Genesis](https://eprint.iacr.org/2018/378.pdf) and [Ouroboros Praos](https://eprint.iacr.org/2017/573.pdf) to the succinct setting, where the complexity of fully verifying the entire blockchain is independent of chain length.

This document describes some important details not found in the original publication in addition to specifying the specific structures, algorithms and protocol details implemented in the Mina blockchain.

The name Samasika comes from the Sanskrit word, meaning small or succinct.

**Changelog**

| Author | Date | Details |
|-|-|-|
| Joseph Spadavecchia | October 2021 | Complete specification of Samasika algorithms and Mina's implementation |

**Table of Contents**

<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [1. Acknowledgements](#1-acknowledgements)
- [2. Notations and conventions](#2-notations-and-conventions)
- [3. Constants](#3-constants)
- [4. Structures](#4-structures)
  - [4.1 `State_hash.Stable.V1`](#41-state_hashstablev1)
  - [4.2 `Epoch_seed.Stable.V1.t`](#42-epoch_seedstablev1t)
  - [4.2 `External_transition`](#42-external_transition)
  - [4.3 `Protocol_state`](#43-protocol_state)
    - [4.3.1 `Protocol_state.Body`](#431-protocol_statebody)
  - [4.4 `Consensus_state`](#44-consensus_state)
  - [4.6 `Epoch_data`](#46-epoch_data)
  - [4.7 Example block](#47-example-block)
- [5. Algorithms](#5-algorithms)
  - [5.1 Common](#51-common)
    - [5.1.1 `top`](#511-top)
    - [5.1.2 `cState`](#512-cstate)
    - [5.1.3 `globalSlot`](#513-globalslot)
    - [5.1.4 `epochSlot`](#514-epochslot)
    - [5.1.5 `length`](#515-length)
    - [5.1.6 `hashLastVRF`](#516-hashlastvrf)
    - [5.1.7 `hashState`](#517-hashstate)
    - [5.1.10 `subWindow`](#5110-subwindow)
    - [5.1.12 `relativeSubWindow`](#5112-relativesubwindow)
  - [5.2 Chain selection rules](#52-chain-selection-rules)
    - [5.2.1 Short-range fork rule](#521-short-range-fork-rule)
    - [5.2.2 Long-range fork rule](#522-long-range-fork-rule)
  - [5.3 Decentralized checkpointing](#53-decentralized-checkpointing)
    - [5.3.1 Genesis checkpoints](#531-genesis-checkpoints)
    - [5.3.2 Short-range fork check](#532-short-range-fork-check)
  - [5.4 Sliding window density](#54-sliding-window-density)
    - [5.4.1 Terminology](#541-terminology)
    - [5.4.2 Sliding windows](#542-sliding-windows)
    - [5.4.3 Sub-windows](#543-sub-windows)
    - [5.4.4 Window density](#544-window-density)
    - [5.4.5 Window structure](#545-window-structure)
    - [5.4.6 Minimum window density](#546-minimum-window-density)
    - [5.4.7 Relative sub-window index](#547-relative-sub-window-index)
    - [5.4.8 Ring-shift](#548-ring-shift)
    - [5.4.9 Projected window](#549-projected-window)
    - [5.4.10 Genesis window](#5410-genesis-window)
    - [5.4.11 Genesis minimum window density](#5411-genesis-minimum-window-density)
    - [5.4.12 Relative minimum window density](#5412-relative-minimum-window-density)
- [6 Protocol](#6-protocol)
  - [6.1 Initialize consensus](#61-initialize-consensus)
    - [6.1.1 Genesis block](#611-genesis-block)
  - [6.2 Select chain](#62-select-chain)
    - [6.2.3 Bringing it all together](#623-bringing-it-all-together)

<!-- /TOC depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

# 1. Acknowledgements

This document would not exist without the help of the reviewers: [Jiawei Tang](https://github.com/ghost-not-in-the-shell), [Nathan Holland](https://github.com/nholland94), [Izaak Meckler](https://math.berkeley.edu/~izaak/) and [Matthew Ryan](https://github.com/mrmr1993).  Special thanks to Jiawei for many detailed discussions about Mina implementation of Ouroboros Samasika.

# 2. Notations and conventions

**Notations**
* `a⌢b` - Concatenation of `a` and `b`
* `T[N]` - Array of type `T` containing `N` elements
* `T[v; N]` - Array of type `T` containing `N` elements of value `v`
* `x[i]` - Element `i` of array `x`, starting at index `0`
* `x[a..b]` - Slice of vector `x` containing elements from indexes `[a, b)`

**Conventions**
* We use the terms _top_ and _last_ interchangeably to refer to the block with the greatest height on a given chain
* We use the term _epoch slot number_ to refer to the intra-epoch slot number that resets to 1 every epoch
* We use _global slot number_ to refer to the global slot number since genesis starting at 1

# 3. Constants

These are the `mainnet` parameters Mina uses for Samasika

| Field | Value | Description |
| - | - | - |
| `delta`                         | `0`                     | Maximum permissable delay of packets (in slots after the current) |
| `k`                             | `290`                   | Point of finality (number of confirmations) |
| `slots_per_epoch`               | `7140`                  | Number of slots per epoch |
| `slots_duration`                | `180000` (= 3m)         | Slot duration in ms |
| `epoch_duration`                | `1285200000` (= 14d21h) | Duration of an epoch in ms |
| `grace_period_end`              | `1440`                  | Number of slots before minimum window density is used in chain selection |
| `genesis_state_timestamp`       | `1615939200000` (Mar 17, 2021 00:00:00 GMT+0000) | Timestamp of genesis block in unixtime |
| `acceptable_network_delay`      | `180000` (= 3m)         | Acceptable network delay in ms |
| `slots_per_sub_window`          | `7`                     | Slots per sub window (see [Section 5.4](#54-sliding-window-density)) |
| `sub_windows_per_window`        | `11`                    | Sub windows per window (see [Section 5.4](#54-sliding-window-density)) |
| `slots_per_window`              | `slots_per_sub_window*sub_windows_per_window` (= 77) | Slots per window |

# 4. Structures

The main structures used in Mina consensus are as follows

## 4.1 `State_hash.Stable.V1`

| Field                           | Type                               | Description |
| - | - | - |
| `b58_version`                   | `u8` (= 0x10)                      | Base58 check version byte |
| `version`                       | `u8` (= 0x01)                      | Structure version |
| `field`                         | `Field.t`                          | Field element |

## 4.2 `Epoch_seed.Stable.V1.t`

| Field                           | Type                               | Description |
| - | - | - |
| `version`                       | `u8` (= 0x01)                      | Structure version |
| `field`                         | `Field.t`                          | Field element |

## 4.2 `External_transition`

This is Mina's block structure.  In Mina blocks are synonymous with transitions.  A block received from a peer is referred to as an external transition and a block generated and applied locally is referred to as an internal transition.

| Field                           | Type                               | Description |
| - | - | - |
| `version`                       | `u8` (= 0x01)                      | Block structure version |
| `protocol_state`                | `Protocol_state.Value.Stable.V1.t` | The blockchain state, including consensus and the ledger |
| `protocol_state_proof`          | `Proof.Stable.V1.t sexp_opaque`    | Proof that the protocol state and entire history of the chain is valid |
| `staged_ledger_diff`            | `Staged_ledger_diff.Stable.V1.t`   | Diff of the proposed next state of the blockchain |
| `delta_transition_chain_proof`  | `State_hash.Stable.V1.t * State_body_hash.Stable.V1.t list` | Proof that the block was produced within the allotted slot time |
| `current_protocol_version`      | `Protocol_version.Stable.V1.t`        | Current protocol version |
| `proposed_protocol_version_opt` | `Protocol_version.Stable.V1.t option` | Proposed protocol version |

## 4.3 `Protocol_state`

This structure can be thought of like the block header.  It contains the most essential information of a block.

| Field                 | Type                     | Description |
| - | - | - |
| `version`             | `u8` (= 0x01)            | Block structure version      |
| `previous_state_hash` | `State_hash.Stable.V1.t` | Commitment to previous block (hash of previous protocol state hash and body hash)|
| `body`                | `Protocol_state.Body.Value.Stable.V1` | The body of the protocol state |

### 4.3.1 `Protocol_state.Body`

| Field                 | Type                     | Description |
| - | - | - |
| `version`             | `u8` (= 0x01)            | Block structure version |
| `genesis_state_hash`  | `State_hash.Stable.V1.t` | Genesis protocol state hash (used for hardforks) |
| `blockchain_state`    | `Blockchain_state.Value.Stable.V1.t` | Ledger related state |
| `consensus_state`     | `Consensus.Data.Consensus_state.Value.Stable.V1.t` | Consensus related state |
| `constants`           | `Protocol_constants_checked.Value.Stable.V1.t` | Consensus constants |

## 4.4 `Consensus_state`

This structure encapsulates the succinct state of the consensus protocol.  The stake distribution information is contained by the `staking_epoch_data` field.  Due to its succinct nature, Samasika cannot look back into the past to obtain ledger snapshots for the stake distribution.  Instead, Samasika implements a novel approach where the future stake distribution snapshot is prepared by the current consensus epoch.  Samasika prepares the past for the future!  This future state is stored in the `next_epoch_data` field.

| Field                                    | Type                     | Description |
| - | - | - |
| `version`                                | `u8` (= 0x01)            | Block structure version |
| `blockchain_length`                      | `Length.Stable.V1.t` | Height of block |
| `epoch_count`                            | `Length.Stable.V1.t` | Epoch number |
| `min_window_density`                     | `Length.Stable.V1.t` | Minimum windows density observed on this chain (see [Section 5.2.2](#522-long-range-fork-rule)) |
| `sub_window_densities`                   | `Length.Stable.V1.t list` | Current sliding window of densities (see [Section 5.4](#54-sliding-window-density)) |
| `last_vrf_output`                        | `Vrf.Output.Truncated.Stable.V1.t` | Additional VRS output from leader (for seeding Random Oracle) |
| `total_currency`                         | `Amount.Stable.V1.t` | Total supply of currency |
| `curr_global_slot`                       | `Global_slot.Stable.V1.t` | Current global slot number relative to the current hard fork  |
| `global_slot_since_genesis`              | `Mina_numbers.Global_slot.Stable.V1.t` | Absolute global slot number since genesis |
| `staking_epoch_data`                     | `Epoch_data.Staking_value_versioned.Value.Stable.V1.t` | Epoch data for previous epoch |
| `next_epoch_data`                        | `Epoch_data.Next_value_versioned.Value.Stable.V1.t` | Epoch data for current epoch |
| `has_ancestor_in_same_checkpoint_window` | `bool` | |
| `block_stake_winner`                     | `Public_key.Compressed.Stable.V1.t` | Compressed public key of winning account |
| `block_creator`                          | `Public_key.Compressed.Stable.V1.t` | Compressed public key of the block producer |
| `coinbase_receiver`                      | `Public_key.Compressed.Stable.V1.t` | Compressed public key of account receiving the block reward |
| `supercharge_coinbase`                   | `bool` | `true` if `block_stake_winner` has no locked tokens, `false` otherwise |

## 4.6 `Epoch_data`

| Field              | Type                     | Description |
| - | - | - |
| `version`          | `u8` (= 0x01)            | Block structure version |
| `ledger`           | `Epoch_ledger.Value.Stable.V1.t` | |
| `seed`             | `Epoch_seed.Stable.V1.t` | |
| `start_checkpoint` | `State_hash.Stable.V1.t` | State hash of _first block_ of epoch (see [Section 5.3](#53-decentralized-checkpointing))|
| `lock_checkpoint`  | `State_hash.Stable.V1.t` | State hash of _last known block in the first 2/3 of epoch_ (see [Section 5.3](#53-decentralized-checkpointing)) excluding the current state |
| `epoch_length`     | `Length.Stable.V1.t` | |

## 4.7 Example block

This is an example of a Mina block in JSON format

```json
{
  "external_transition": {
    "protocol_state": {
      "previous_state_hash": "3NLKJLNbD7rBAbGdjZz3tfNBPYxUJJaLmwCP9jMKR65KSz4RKV6b",
      "body": {
        "genesis_state_hash": "3NLxYrjb7zmHdoFgBrubCN8ijM8v7eT8kvLiPLc9DHt3M8XrDDEG",
        "blockchain_state": {
          "staged_ledger_hash": {
            "non_snark": {
              "ledger_hash": "jxV4SS44wHUVrGEucCsfxLisZyUC5QddsiokGH3kz5xm2hJWZ25",
              "aux_hash": "UmosfM82dH5xzqdckXgA1JoAvJ5tLxch2wsty4sXmiEPKnPTPq",
              "pending_coinbase_aux": "WLo8mDN6oBUTSyBkFCy7Fky7Na5fN4R6oGq4HMf3YoHCAj4cwY"
            },
            "pending_coinbase_hash": "2mze7iXKwA9JAqVDC1MVvgWfJDgvbgSexKtuShdkgqMfv1tjATQQ"
          },
          "snarked_ledger_hash": "jx9171AbMApHNG1guAcKct1E6nyUFweA7M4ZPCjBZpgNNrE21Nj",
          "genesis_ledger_hash": "jxX6VJ84HaafrKozFRA4qjnni4aPXqXC2H5vQLKSryNpKTXuz1R",
          "snarked_next_available_token": "2",
          "timestamp": "1611691710000"
        },
        "consensus_state": {
          "blockchain_length": "3852",
          "epoch_count": "1",
          "min_window_density": "1",
          "sub_window_densities": [
            "3",
            "1",
            "3",
            "1",
            "4",
            "2",
            "1",
            "2",
            "2",
            "4",
            "5"
          ],
          "last_vrf_output": "g_1vrXSXLhvn1e4Ap1Ey5e8yh3PFMJT0vZyhZLlTBAA=",
          "total_currency": "167255800000001000",
          "curr_global_slot": {
            "slot_number": "12978",
            "slots_per_epoch": "7140"
          },
          "global_slot_since_genesis": "12978",
          "staking_epoch_data": {
            "ledger": {
              "hash": "jxX6VJ84HaafrKozFRA4qjnni4aPXqXC2H5vQLKSryNpKTXuz1R",
              "total_currency": "165950000000001000"
            },
            "seed": "2vb1Mjvydod6sEwn7qpbejKCfRqugMgyG3MHXXRKcAkwQLRs9fj8",
            "start_checkpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
            "lock_checkpoint": "3NK5G8Xqn1Prh3XoTyZ2tqntJC6X2nVwruv5mEJCL3GaTk7jKUNo",
            "epoch_length": "1769"
          },
          "next_epoch_data": {
            "ledger": {
              "hash": "jx7XXjRfJj2mGXmiHQmpm6ZgTxz14udpugyFtw4DefJFpie7apN",
              "total_currency": "166537000000001000"
            },
            "seed": "2vavBR2GfJWvWkpC7yGJQFnts18nHaFjdVEr84r1Y9DQXvnJRhmd",
            "start_checkpoint": "3NLdAqxtBRYxYbCWMXxGu6j1hGDrpQwGkBDF9QvGxmtpziXQDADu",
            "lock_checkpoint": "3NL4Eis1pS1yrPdfCbiJcpCCYsHuXY3ZgEzHojPnFWfMK9gKmhZh",
            "epoch_length": "2084"
          },
          "has_ancestor_in_same_checkpoint_window": true,
          "block_stake_winner": "B62qpBrUYW8SHcKTFWLbHKD7d3FqYFvGRBaWRLQCgsr3V9pwsPSd7Ms",
          "block_creator": "B62qpBrUYW8SHcKTFWLbHKD7d3FqYFvGRBaWRLQCgsr3V9pwsPSd7Ms",
          "coinbase_receiver": "B62qpBrUYW8SHcKTFWLbHKD7d3FqYFvGRBaWRLQCgsr3V9pwsPSd7Ms",
          "supercharge_coinbase": true
        },
        "constants": {
          "k": "290",
          "slots_per_epoch": "7140",
          "slots_per_sub_window": "7",
          "delta": "0",
          "genesis_state_timestamp": "1609355670000"
        }
      }
    },
    "protocol_state_proof": "<opaque>",
    "staged_ledger_diff": "<opaque>",
    "delta_transition_chain_proof": "<opaque>",
    "current_protocol_version": "1.1.0",
    "proposed_protocol_version": "<None>"
  }
}
```

# 5. Algorithms

This section outlines the main algorithms and constructs used by Samasika.

## 5.1 Common

This section outlines some commonly used helpers.

### 5.1.1 `top`

This function returns the last block of a given chain.  The input is a chain `C` and the output is last block of `C` (i.e. the block with greatest height).

```rust
fn top(C) -> Block
{
   return last block of C
}
```

### 5.1.2 `cState`

The function returns the consensus state of a block or chain.  The input is a block or chain `X` and the output is the consensus state.

```rust
fn cState(X) -> Consensus_state
{
    match X {
        Block => X.protocol_state.body.consensus_state,
        Chain => {
            cState(last block of X)
        }
    }
}
```

### 5.1.3 `globalSlot`

The function returns the _global slot number_ of a chain or block.  The input `X` is either a chain or block and the output is the global slot number.

```rust
fn globalSlot(X) -> u64
{
    return cState(X).curr_global_slot
}
```

### 5.1.4 `epochSlot`

The function computes the _epoch slot number_ of a block.  The input is the block's consensus state `C` and the output is the epoch slot number in `[0, slots_per_epoch]`.

```rust
fn epochSlot(B) -> u32
{
   return C.curr_global_slot mod slots_per_epoch
}
```

### 5.1.5 `length`

The function the length of a chain.  The input is the global chain `C` and the output is the length of the chain in blocks.

```rust
fn length(C) -> u64
{
   return cState(C).blockchain_length
}
```

### 5.1.6 `hashLastVRF`

This function returns the hex digest of the hash of the last VRF output of a given chain.  The input is a chain `C` and the output is the hash digest.

```rust
fn hashLastVRF(C) -> String
{
   return Blake2b(cState(C).last_vrf_output).digest()
}
```

### 5.1.7 `hashState`

This function returns hash of the top block's protocol state for a given chain.  The input is a chain `C` and the output is the hash.

```rust
fn hashState(C) -> State_hash
{
   return poseidon_3w_hash(POSEIDON_PROTOCOL_STATE_HASH, top(C).protocol_state.to_roinput())
}
```

The `poseidon_3w_hash` function, `POSEIDON_PROTOCOL_STATE_HASH` parameter and `to_roinput()` method will be provided by the rust signer library.

### 5.1.10 `subWindow`

This function returns the sub-window number of a block.

```rust
fn subWindow(B) -> u64
{
   return globalSlot(B)/slots_per_sub_window
}
```

### 5.1.12 `relativeSubWindow`

This function returns the relative sub-window number of a global slot `S`.

```rust
fn relativeSubWindow(S) -> u64
{
    return (S/slots_per_sub_window) mod sub_windows_per_window
}
```

## 5.2 Chain selection rules

Samasika uses two consensus rules: one for *short-range forks* and one for *long-range forks*.

### 5.2.1 Short-range fork rule

This rule is triggered whenever the fork is such that the adversary has not yet had the opportunity to mutate the block density distribution.

```rust
Choose the longest chain
```

A fork is short-range if it occurred less than `m` blocks ago.  The naı̈ve implementation of this rule is to always store the last `m` blocks, but for a succinct blockchain this is not desirable.  Mina Samasika adopts an approach that only requires information about two blocks.  The idea is a decentralized checkpointing algorithm, the details of which are given in [Section 5.3](#53-decentralized-checkpointing).

### 5.2.2 Long-range fork rule

Recall that when an adversary creates a long-range fork, over time it skews the leader selection distribution leading to a longer adversarial chain.  Initially the dishonest chain will have a lower density, but in time the adversary will work to increase it.  Thus, we can only rely on the density difference in the first few slots following the fork, the so-called *critical window*.  The idea is that for the honest chain's critical window the density is overwhelmingly likely to be higher because this chain contains the majority of stake.

As a succinct blockchain, Mina does not have a chain into which it can look back on the fork point to observe the densities.  Moreover, the slot range of the desired densities cannot be know ahead of time.

Samasika overcomes this problem by storing a succinct summary of a sliding window of slots over each chain and then tracks the *minimum* of all densities observed for each sliding window.  The intuition is that if the adversary manages to increase the density on the dishonest chain, the tracked minimum density still points to the critical window following the fork.

[Section 5.4](#54-sliding-window-density) specifies how the sliding windows are tracked and how the minimum density is computed.  For now, we assume that each chain contains the minimum window density and describe the main idea of the long-range fork rule.

Given chain `C` let `C.min_density` be the minimum density observed in `C` so far.

Let `C1` be the local chain and `C2` be a [valid](../verification/README.md#1.1-isvalidchain) alternative chain; the gist of the _long-range fork rule_ is

```rust
if C2.min_density > C1.min_density {
    Select C2
}
else {
    Continue with C1
}
```

The above pseudocode is only to provide intuition about how the chain selection rules work.  A detailed description of the succinct sliding window structure is described in section [Section 5.4](#54-sliding-window-density) and the actual chain selection algorithm is specified in [Section 6.2](#62-select-chain).

## 5.3 Decentralized checkpointing

**IN REVIEW**

Samasika uses decentralized checkpointing to determine whether a fork is short- or long-range.  Each epoch is split into three parts with an equal number of slots.  The first 2/3 are called the *seed update range* because this is when the VRF is seeded.

For example, consider an example epoch `i` of 15 slots, `s1 ... s15`.

```text
epoch i: s1 s2 s3 s4 s5 | s6 s7 s8 s9 s10 | s11 s12 s13 s14 s15
         \______________________________/
              2/3 (seed update range)
```

As seen above, the slots can be split into 3 parts delimited by `|`.  The first `2/3` of the slots (`s1 ... s10`) are in the seed update range. The epoch seeds of blocks in this range are used to seed the VRF.

The idea of decentralized checkpointing is that each chain maintains two checkpoints in every epoch, which are used to estimate how long ago a fork has occurred.

* **Start checkpoint** - State hash of the first block of the epoch
* **Lock checkpoint** - State hash of the last known block in the seed update range of an epoch (not including the current block)

For example, consider epochs `e1 ... e3` below.

```text
epochs:         e1                e2                 e3
                                      ⤺lock
slots:  s1s2s3s4s5s6s7s8s9|s1s2s3s4s5s6s7s8s9|s1s2s3...
                     start⤻⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺
```

Here the current slot is `s7`, the start checkpoint is `s1` and the lock checkpoint is `s6`.

These are located in the `start_checkpoint` and `lock_checkpoint` fields of the [`Epoch_data`](#46-epoch_data) structure, which is part of the [`Consensus_state`](#44-consensus_state) (See [Section 4.6](#46-epoch_data)).

As time progresses away from the first slot of the current epoch, the lock checkpoint is pushed along with the last known block until we reach the last block in the first `2/3` of the epoch and it is _frozen_. ❄

A fork is considered _short-range_ if either

1. the fork point of the candidate chains are in the same epoch
2. or the fork point is in the previous epoch with the same `lock_checkpoint`

Since the leader selection distribution for the current epoch is computed by the end of the first `2/3` of the slots in the previous epoch, an adversarial fork after (and including) the previous epoch's `lock_checkpoint` cannot skew the distribution for the remainder of that epoch, nor the current epoch.  Anything before the previous epoch's `lock_checkpoint` is a _long-range_ fork.

Since Mina is succinct this means that it must store the checkpoints for the current epoch in addition to the checkpoints for the previous epoch.  This is why the [`Consensus_state`](#44-consensus_state) structure contains two `Epoch_data` fields: `staking_epoch_data` and `next_epoch_data`.  The former contains the checkpoints for the previous epoch and the latter contains that of the current epoch.

### 5.3.1 Genesis checkpoints

The checkpoints for genesis block `G` are initialized like this

```rust
// Set staking epoch data
cState(G).next_epoch_data.ledger.hash = Ledger_hash::from_b58("jx7buQVWFLsXTtzRgSxbYcT8EYLS8KCZbLrfDcJxMtyy4thw2Ee")
cState(G).next_epoch.ledger.total_currency = 805385692840039233
cState(G).staking_epoch_data.seed = Epoch_seed::from_b58("2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA") // Epoch_seed::zero
cState(G).staking_epoch_data.start_checkpoint = State_hash::from_b58("3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x") // State_hash::zero
cState(G).staking_epoch_data.lock_checkpoint = State_hash::from_b58("3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x") // State_hash::zero
cState(G).staking_epoch_data.epoch_length = 1

// Set next epoch data
cState(G).next_epoch_data.ledger.hash = Ledger_hash::from_b58("jx7buQVWFLsXTtzRgSxbYcT8EYLS8KCZbLrfDcJxMtyy4thw2Ee")
cState(G).next_epoch.ledger.total_currency = 805385692840039233
cState(G).next_epoch_data.seed = Epoch_seed::from_b58("2vaRh7FQ5wSzmpFReF9gcRKjv48CcJvHs25aqb3SSZiPgHQBy5Dt")
cState(G).next_epoch_data.start_checkpoint = State_hash::from_b58("3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x") // State_hash::zero
cState(G).next_epoch_data.lock_checkpoint =  State_hash::from_b58("3NLoKn22eMnyQ7rxh5pxB6vBA3XhSAhhrf7akdqS6HbAKD14Dh1d")
cState(G).next_epoch.epoch_length = 2
```

The functions `Epoch_seed::from_b58` and `State_hash::from_b58` are provided by the `bin_prot` implementation.

### 5.3.2 Short-range fork check

Given two candidate chains, we can use the previous epoch data (`staking_epoch_data`) and the current epoch data (`next_epoch_data`) to determine whether the fork point is short-range or long-range.

Remember that short-range forks are those where the fork point happens after the `lock_checkpoint` of the previous epoch, otherwise it is a long-range fork.  Observe, however, that the location of the previous epoch is a relative measurement from the perspective of a block.  If the candidate blocks are in different epochs, then they will each have a different current and previous epoch-- see the figure below.

```text
  ---
e3 |     B1
  ---
e2 |     B2
  ---
e1 |
  ---
```

In this example, `B1`'s current epoch is `e3` and its previous epoch is `e2`, but `B2`'s current and previous epochs are `e2` and `e1` respectively.  Observe that it is not possible to have a short-range fork if the blocks are more than one epoch apart (because the fork point would be beyond one of the blocks' previous epoch's lock checkpoint).

On the other hand, if the blocks are in the same epoch, then both blocks will have the same previous epoch and thus we can simply check whether the blocks have the same `lock_checkpoint` in their previous epoch data (i.e. `B1.staking_epoch_data.lock_checkpoint == B2.staking_epoch_data.lock_checkpoint`).  This gives rise to the following algorithm.

Given two chains `C1` and `C2` `isShortRange` outputs `true` if the fork is short-range, otherwise the fork is long-range and it outputs `false`.

```rust
fn isShortRange(C1, C2) -> bool
{
    // Get consensus state from top blocks of each chain
    let S1 = cState(C1);
    let S2 = cState(C2);

    let check = | S1, S2 | {
      if S1.epoch_count == S2.epoch_count + 1  && epochSlot(S2) >= 2/3*slots_per_epoch {
        // S1 is one epoch ahead of S2 and S2 is not in the seed update range
        return S1.staking_epoch_data.lock_checkpoint == S2.next_epoch_data.lock_checkpoint
      }
      else {
        return false
      }
    };

    if S1.epoch_count == S2.epoch_count {
        // Simple case: blocks have same previous epoch, so compare previous epochs' lock_checkpoints
        return S1.staking_epoch_data.lock_checkpoint == S2.staking_epoch_data.lock_checkpoint
    }
    else {
        // Check for previous epoch case using both orientations
        return check(S1, S2) || check(S2, S1)
    }
}
```

## 5.4 Sliding window density

This section describes Mina's succinct sliding window density algorithm used by the long-range fork rule.  It describes in detail how windows are represented in blocks and how to compute *minimum window density*.

### 5.4.1 Terminology

* We say a slot is _`filled`_ if it contains a valid non-orphaned block
* An _`w-window`_ is a sequential list of slots s<sub>1</sub>,...,s<sub>w</sub> of length `w`
* A _`sub-window`_ is a contiguous interval of a `w-window`
* The _`density`_ of an w-window (or sub-window) is the number non-orphan block within it
* We use the terms _`window`_, _`density window`_, _`sliding window`_ and _`w-window`_ synonymously

### 5.4.2 Sliding windows

In the Samasika paper the _`sliding window`_ is referred to as a `v`-shifting `w`-window and it characterized by two parameters.

| Parameter | Description                                | Value |
| - | - | - |
| `v`       | Length by which the window shifts in slots (shift parameter) | [`slots_per_sub_window`](#3-constants) (= 7) |
| `w`       | Window length in slots                                       | [`slots_per_sub_window`](#3-constants)` * `[`sub_windows_per_window`](#3-constants) (= 7*11 = 77 slots) |

This is a `w`-long window that shifts `v`-slots at a time.

The `v`-shifting `w`-window and the selection of `v` as a fraction of `w` are important for the security of Samasika.  Proper selection of these parameters ensures that the succinct window density algorithm captures the critical window (described in [Section 5.2.2](#522-long-range-fork-rule)).  The Samasika research paper presents security proofs that calculate what values of `v`, `w` and sub-windows per window (discussed next) are safe.

### 5.4.3 Sub-windows

A sliding window can also be viewed as a collection of `sub-windows`.  That is, you can think of a `w`-length window as being comprised of `k` sub-windows, each of length `v` slots.  For the parameters given in the table above, the sliding window looks like this:

```text
   |s1,...,s7|s8,...,s14| ... |s71,...,s77|
k:      1          2      ...      11
```

where `si` is slot `i`.

Instead of storing a window as groups of slots, Samasika is only interested in the density of each sub-window, thus, it need only track a list of `k = 11` (a.k.a. [`sub_windows_per_window`](#3-constants)) sub-window densities.

```text
            |s1,...,s7|s8,...,s14| ... |s71,...,s73|
densities:      d1        d2      ...       dk
```

### 5.4.4 Window density

The density of a window is computed as the sum of the densities of its sub-windows.  Given a window `W` that is a list of sub-window densities, the window density is

> `density(W) = sum(W)`

**Note:** The density of a window is insensitive to the order of the sub-windows.

### 5.4.5 Window structure

Windows look back in time over previous sub-windows, rather than forward.  We use the phrase "window at sub-window `s`" to refer to the window `W` whose most recent global sub-window is `s`.

In the Samasika paper the window structure actually consists of the `11` previous sub-window densities, the current sub-window density and the minimum window density-- a total of `13` densities.  The window's density, however, is only calculated on the previous `11` sub-windows and excludes the current sub-window and minimum.

We say that a sub-window is *in-progress* until it contains the densities for `sub_windows_per_window = 7` slots.  Once a sub-window spans `sub_windows_per_window` slots we say that it is *complete* and at the next non-empty slot it becomes a *previous sub-window*.  The following example illustrates the concept.

```
                                           current (in-progress)
                                           |
sub_windows: 00,01,02,03,04,05,06,07,08,09,10
             \___________________________/
                         previous
```

Initially, above there are only 10 previous sub-windows and the current sub-window is in-progress.  Next, the current sub-window becomes complete, but it's not yet a previous sub-window-- see below.

```
                                           current (complete)
                                           |
sub_windows: 00,01,02,03,04,05,06,07,08,09,10
             \___________________________/
                       previous
```

Now we advance to the first slot of the next sub-window (e.g. a new block in sub-window `11`).  Sub-window (`10`) becomes a previous sub-window and, since there are now `11` previous sub-windows, we compute the window density.

```
                                              11
                                              |
                                              current (in-progress)

sub_windows: 00,01,02,03,04,05,06,07,08,09,10
             \______________________________/
                         previous

compute density <- sum(sub_windows)
```

Finally, we shift in the new current sub-window (`11`) and evict the oldest previous sub-window (`00`).

```
                                               current (in-progress)
                                               |
sub_windows: 00, 01,02,03,04,05,06,07,08,09,10,11
             |   \___________________________/
            \ /            previous
             `
          evicted
```

This example illustrates that we do not need to store the current sub-window separately.

By definition, the window density is only computed on previous sub-windows, so the window density remains unchanged until the current sub-window becomes a previous sub-window and all `11` sub-windows are a previous sub-windows.

It is, therefore, sufficient to only store `11` sub-windows, allowing the most recent sub-window to either be *in-progress* or *complete*.  Mina uses this optimization for both space-saving and SNARK efficiency.

The window of a block `B` is found in its `sub_window_densities` field, which is part of the `Consensus_state` (see [Section 4.4](#44-consensus_state)).  The field is defined as a list of `sub_windows_per_window = 11` sub-window densities up to the global slot of block `B`.  As described above, the most recent sub-window may be a previous sub-window or the current sub-window.

The `sub_windows_per_window` field is of type `Length.Stable.V1.t list` and because it is written into blocks as part of the protocol, Mina implementations MUST implement serialization for this type.

**Observe:** Since the window density at sub-window `s` is only calculated when sub-window `s` is a previous sub-window, the calculation must happen during sub-window `> s` (slots and sub-windows can be empty).

### 5.4.6 Minimum window density

The *minimum window density* at a given slot is defined as the minimum window density observed over all previous sub-windows and previous windows, all the way back to genesis.

The minimum window density is found in the `min_window_density` field of the `Consensus_state` (see [Section 4.4](#44-consensus_state)).

When a new block `B` with parent `P` is created, the minimum window density is computed like this.

`B.min_window_density = min(P.min_window_density, current_window_density)`

where `current_window_density` is the density of `B`'s projected window (more on this later).

**Observe:** By definition the minimum window density `mwd(s)` at slot `s` is monotonically decreasing (i.e. non-increasing) on the canonical chain.  That is, for all slots `s1` and `s2` such that `s1 ≤ s2` then `mwd(s1) ≥ mwd(s2)`.  N.b. when reorganizing based on the long-range fork rule, the new canonical chain's minimum window density is higher than the previous canonical chain's by definition of the rule.  This increase, however, is found between two chains (the previous and new canonical chains) rather than within a single chain-- the new canonical chain still has non-increasing minimum window density within it.

### 5.4.7 Relative sub-window index

The relative sub-window `i` of a sub-window `sw` is its index within the window.

```rust
fn relativeSubWindow(sw) -> u32
{
   return sw mod sub_windows_per_window
}
```

In other words, the relative sub-window is the index of the sub-window within the `sub_window_densities` list.

As the global slot increases the relative sub-window wraps around modulo `sub_windows_per_window`.

```text
                                  window 0                          window 1
          sub-window: 00,01,02,03,04,05,06,07,08,09,10  11,12,13,14,15,16,17,18,19,20,21
 relative sub-window: 00,01,02,03,04,05,06,07,08,09,10  00,01,02,03,04,05,06,07,08,09,10
 ```

**Note:** The global slot of the genesis block is slot `0` and, thus, according to [Section 5.1.10](#5110-subwindow) the genesis block is in sub-window `0`.  Therefore, the genesis block's relative sub-window is also `0`.

### 5.4.8 Ring-shift

For technical reasons we will describe later, in order to compute the minimum window density for the long-range fork rule sometimes we must transform the window.  The Samasika paper describes window updates using a window shifting algorithm.

For example, when we shift a window `[d0, d1, ..., d10]` in order to add in a new sub-window `d11`, we could evict the oldest sub-window `d0` by shifting down all of the other sub-windows.  Unfortunately, shifting a list in a SNARK circuit is very expensive.

It is more efficient (and also equivalent) to just replace the sub-window we wish to evict by overwriting it with the new sub-window, like this -- `[d11, d1, ..., d10]`.  (Recall from [Section 5.4.4](#544-window-density) that the calculation of the window density is order insensitive.)

For example, given the window

```text
sub_window_densities: d0 | d1 | d2 | d3 | d4 | d5 | d6 | d7 | d8 | d9 | d10
                      | --->                                       <--- |
```

where `d0` is the density corresponding to sub-window `0` (i.e. the oldest previous sub-window) and `d10` is the density of the most recent sub-window.

We insert the new element `d11` by wrapping around like this

```text
sub_window_densities: d11 | d1 | d2 | d3 | d4 | d5 | d6 | d7 | d8 | d9 | d10
                 <--- |     | --->
```

Next, if we insert the density `d12` for sub-window `12` then we get

```text
sub_window_densities: d11 | d12 | d2 | d3 | d4 | d5 | d6 | d7 | d8 | d9 | d10
                       <--- |     | --->
```

We continue in this fashion each time we need to insert a new sub-window.

**Note**: The same window can be represented equivalently by many different ring windows.

### 5.4.9 Projected window

As we will see later, both creating a new block and selecting the best chain during the long-range fork rule require computing a *projected window*.

Given a window `W` and a future global slot `next`, the projected window of `W` to slot `next` is a transformation of `W` into what it would look like if it were positioned at slot `next` (i.e. following itself with no intermediate blocks) by ring-shifting.

In the previous section we introduced the concept of ring shifting by one.  When projecting a window sometimes we must shift by more than one sub-window.

For example, when a new block `B` is produced with parent block `P`, the height of `B` will be the height of `P` plus one, but the global slot of `B` will depend on how much time has elapsed since `P` was created.  Since sliding windows are based on slots, we must take this into account when computing `B`'s window.

According to the Samasika paper, the window of `B` must be initialized based on `P`'s window, then shifted because `B` is ahead of `P` and finally the value of `B`'s sub-window is incremented to account for `B` belonging to it.  Observe that the first two steps are equivalent to computing the projection of `W = P.sub_window_densities` to slot `next = B.curr_global_slot`.

The correct number of shifts we must perform is subtle.  Recall from [Section 5.4.5](#545-window-structure) that the window density including sub-window `s` is only calculated during sub-window `> s`, after `s` becomes a previous sub-window.  Therefore, if `next` is `k` sub-windows ahead of `W` we must shift only `k - 1` times because we must keep the most recent previous sub-window.

Given a window that we are projecting `k` sub-windows ahead, the *shift count* is

`shift_count = min(max(k - 1, 0), sub_windows_per_window)`

Now that we know how much to ring-shift, the next question is what density values to shift in.  Remember that when projecting `W` to global slot `next`, we said that there are no intermediate blocks.  That is, all of the slots and sub-windows are empty between `W`'s current slot and `next`.  Consequently, we must ring-shift in zero densities.  The resulting window `W` is the *projected window*.

The following example illustrates the process.

Suppose window `W`'s current sub-window is `11` whose density is `d11` and `d1` is the oldest sub-window density, like this

```text
sub_window_densities: d11 | d1 | d2 | d3 | d4 | d5 | d6 | d7 | d8 | d9 | d10
                 <--- |     | --->
                current     oldest
```

Now imagine we want to project `W` to global slot `next = 15`.  This is `k = 15 - 11 = 4` sub-windows ahead of the most recent sub-window.  Therefore, we compute

`shift_count = min(max(4 - 1, 0), 11) = 3`

and ring-shift in 3 zero densities to obtain,

```text
sub_window_densities: d11 | 0 | 0 | 0 | d4 | d5 | d6 | d7 | d8 | d9 | d10
                               <--- |   | --->
                              current   oldest
```

which is the projected window.

To reinforce the concept, consider our earlier block production context with new block `B` and parent block `P`.  We can derive some instructive cases from the general rule to reinforce our understanding.

* **subWindow(B) == subWindow(P)**  - We do no ring-shift because `B` and `P` have the same previous sub-windows.  In other words, `B.sub_window_densities = P.sub_window_densities` and `B.min_window_density = P.min_window_density`.
* **subWindow(B) == subWindow(P) + 1 (in same window)** - We do not need to ring-shift in any zeros, but `P`'s most-recent sub-window is now a previous sub-window.  `B`'s window density is computed from the new window and the minimum window density is updated.
* **B and P are in disjoint windows** - `B`'s entire window is zeroed and `B.min_window_density = 0`.

In a subsequent section we will learn more about how projected windows are used for chain selection during the long-fork rule.

### 5.4.10 Genesis window

Since the sub-window of a global slot `s` is

> `subWindow(s) = s/slots_per_sub_window`

and the genesis block's global slot is `0`, the genesis block belongs to sub-window `0`.  This means the genesis block's window actually looks back in time over imaginary sub-windows, like this

```text
               index: | 0    | 1    | 2    | 3    | 4    | 5    | 6    | 7    | 8    | 9    | 10   |
sub_window_densities: | d0   | d-10 | d-9  | d-8  | d-7  | d-6  | d-5  | d-4  | d-3  | d-2  | d1   |
                   <--- |      | --->
                  current      oldest
```

where `d-i` denotes density of imaginary sub-window `-i` and `d0` corresponds to the density of sub-window `0`.   Note that the imaginary windows are all previous sub-windows and `d0` corresponds to the genesis block's sub-window.

The genesis block's sub-window is at index `0` because the genesis block's relative sub-window is `0` (i.e. `relativeSubWindow(0) = 0`).  This is the start of a new window, so the genesis block sub-window density `d0` must be initialized to `0` and then incremented to `1` to account for the presence of the genesis block.  The imaginary windows are initialized to `slots_per_window`.

Thus, contents of the genesis window are

```rust
u32[1, slots_per_sub_window, slots_per_sub_window, ..., slots_per_sub_window]
       \___________________________________________________________________/
                   // sub_windows_per_window - 1
```

### 5.4.11 Genesis minimum window density

As detailed in [Section 5.4.5](#545-window-structure), the window density including sub-window `s` is calculated during sub-window `> s`, once `s` becomes a previous sub-window, and then the oldest density is ring-shifted.

Since the genesis block `G` is at the start of a new sub-window and its current sub-window density is `0`, we know that when it was generated all sub-window densities, from oldest to most recent were used to compute the density of the window.  At the time, the density at index `0` was also `slots_per_sub_window` and, thus, the intermediate `sub_window_densities` was

```rust
cState(G).sub_window_densities = u32[slots_per_sub_window; sub_windows_per_window]
                               = u32[7; 11]
```

Consequently the genesis density was

```text
genesis_window_density = sum(G.sub_window_densities)
                       = slots_per_window
                       = 77
```

For technical reasons outside the scope of this document, in Mina there is a negative one block `N`.  The minimum window density of `N` is defined as the maximum window density (`77`).  Therefore, `G`'s minimum window density is initialized to

```text
cState(G).min_window_density = min(N.min_window_density, genesis_window_density)
                             = min(77, 77) = 77
```

### 5.4.12 Relative minimum window density

When performing chain selection during the long-range fork rule Mina does not actually directly use the minimum window densities found in the current and candidate blocks.  Instead, Mina uses the *relative minimum window density*.  To understand the relative minimum window density, we first need to understand the problem with simply using the minimum window density.

Recall from [Section 5.4.6](#546-minimum-window-density) that the minimum window density is monotonically decreasing.  Therefore, a peer that has disconnected from the network for a period and wishes to rejoin could have a higher minimum window density for it current best chain when compared to the canonical chain candidate (i.e. the best chain for the network).

Also remember from [Section 5.2.2](#522-long-range-fork-rule) that the long-range fork rule dictates that the peer select the chain with the higher minimum density.  Due to the problem just described, this could actually be the peer's current chain, rather than the network's canonical chain (since the minimum window density is non-increasing). Thus, the peer will be stuck and synchronization will not succeed.

```text
current:   B1, B2, B3, B4              (ye olde minimum window density = 43) Stuck! 😭
canonical: B1, B2, B3, B4, B5, ..., Bk (current minimum window density = 42)
```

The inversion problem occurs because the calculation of the minimum window density does not take into account the relationship between the current best chain and the canonical chain with respect to time.  In Samasika, time is captured and secured through the concepts of slots and the VRF.  Our calculation of the minimum window density must also take this into account.

The relative minimum window density solves this problem by projecting the joining peer's current block's window to the global slot of the candidate block. (N.b. As described in [Section 6.2.3](#623-bringing-it-all-together), this happens whenever the candidate block's global slot is ahead of the current block's or vice versa.)  In this way, the projection allows a fair comparison.

The relative minimum window density of blocks `B1` and `B2` is defined as.

```rust
fn relativeMinWindowDensity(B1, B2) -> u32
{
    let max_slot = max(globalSlot(B1), globalSlot(B2))

    // Grace-period rule
    if max_slot < grace_period_end {
        return B1.min_window_density
    }

    // Compute B1's window projected to max_slot
    let projected_window = {
        // Compute shift count
        let shift_count = min(max(max_slot - B1.curr_global_slot - 1, 0), sub_windows_per_window)

        // Initialize projected window
        let projected_window = B1.sub_window_densities

        // Ring-shift
        let i = relativeSubWindow(B1.curr_global_slot)
        while shift_count > 0 {
          i = i + 1 mod sub_windows_per_window
          projected_window[i] = 0
          shift_count--;
        }

        return projected_window
    }

    // Compute projected window density
    let projected_window_density = density(projected_window)

    // Compute minimum window density
    return min(B1.min_window_density, projected_window_density)
}
```

This description was adopted to aid understanding, providing explanations where possible of why strategies have been adopted and what conditions are important.  In a production implementation consideration must be given to performance implications and another implementation may be desirable.

**Security note:**  It is important that implementations verify blocks correctly to prevent attacks on the sliding window.  An adversary may attempt to increase the min window density of an adversarial chain relative to the canonical chain, either by increasing the min window density of the adversarial chain or by causing the relative window density of the canonical chain to be decreased by ring-shifting.  The prior is thwarted by only accepting blocks with valid proofs (a valid proof attests to the verification of checked computations on the sliding window during block production).  The latter is thwarted by rejecting blocks whose timestamps are ahead of the current time of the peer verifying the block.  We describe more details in the verification section.

# 6 Protocol

This section specifies the consensus protocol in terms of events and how they MUST be implemented by a compatible peer.  The required events are:

* [`Initialize consensus`](#61-initialize-consensus)
* [`Select chain`](#62-select-chain)

Additionally there are certain local data members that all peers MUST maintain in order to participate in consensus.

| Parameter   | Description |
| - | - |
| `genesis_block` | The initial block in the blockchain |
| `neighbors`     | Set of connections to neighboring peers |
| `chains`        | Set of known (succinct) candidate chains |
| `tip`           | Currently selected chain according to the chain selection algorithm (i.e. secure chain) |

How these are represented is up to the implementation, but careful consideration must be given to scalability.

In the following description we use _dot notation_ to refer the local data members of peers. For example, given peer `P`, we use `P.genesis_block` and `P.tip`, to refer to the genesis block and currently selected chain, respectively.

## 6.1 Initialize consensus

Things a peer MUST do to initialize consensus includes

* Load the genesis block
* Get head of the current chain
* Bootstrap
* Catchup

### 6.1.1 Genesis block

**`Consensus_state`**

| Field                                    | Value         |
| - | - |
| `version`                                | `0x01`        |
| `blockchain_length`                      | `1`           |
| `epoch_count`                            | `0`           |
| `min_window_density`                     | `77 = slots_per_window` |
| `sub_window_densities`                   | `u32[1, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7]` (See [Section 5.4.10](#5410-genesis-window)) |
| `last_vrf_output`                        | `VRF_output::from_b64("NfThG1r1GxQuhaGLSJWGxcpv24SudtXG4etB0TnGqwg=")`
| `total_currency`                         | `805385692840039233` (= 805385692.840039233)
| `curr_global_slot`                       | `0` |
| `global_slot_since_genesis`              | `0` |
| `staking_epoch_data`                     | See [Section 4.1.1.2](#4112-staking_epoch_data) |
| `next_epoch_data`                        | See [Section 4.1.1.3](#4112-next_epoch_data) |
| `has_ancestor_in_same_checkpoint_window` | `true` |
| `block_stake_winner`                     | `Public_key::from_b58("B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg")` |
| `block_creator`                          | `Public_key::from_b58("B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg")` |
| `coinbase_receiver`                      | `Public_key::from_b58("B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg")` |
| `supercharge_coinbase`                   | `true` |

**JSON**

The following JSON specifies the main data in the `mainnet` genesis block.

```json
{
   "data":{
      "block":{
         "blockHeight":1,
         "canonical":true,
         "creator":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
         "creatorAccount":{
            "publicKey":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg"
         },
         "dateTime":"2021-03-17T00:00:00Z",
         "protocolState":{
            "blockchainState":{
               "date":"1615939200000",
               "snarkedLedgerHash":"jx7buQVWFLsXTtzRgSxbYcT8EYLS8KCZbLrfDcJxMtyy4thw2Ee",
               "stagedLedgerHash":"jx7buQVWFLsXTtzRgSxbYcT8EYLS8KCZbLrfDcJxMtyy4thw2Ee",
               "utcDate":"1615939200000"
            },
            "consensusState":{
               "blockchainLength":1,
               "epochCount":0,
               "minWindowDensity":77,
               "sub_window_densities":[
                  1,
                  7,
                  7,
                  7,
                  7,
                  7,
                  7,
                  7,
                  7,
                  7,
                  7
               ],
               "lastVrfOutput":"NfThG1r1GxQuhaGLSJWGxcpv24SudtXG4etB0TnGqwg=",
               "totalCurrency":805385692840039233,
               "currGlobalSlot":0,
               "slotSinceGenesis":0,
               "stakingEpochData":{
                  "epochLength":1,
                  "ledger":{
                     "hash":"jx7buQVWFLsXTtzRgSxbYcT8EYLS8KCZbLrfDcJxMtyy4thw2Ee",
                     "totalCurrency":805385692840039300
                  },
                  "lockCheckpoint":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
                  "seed":"2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA",
                  "startCheckpoint":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x"
               },
               "nextEpochData":{
                  "epochLength":2,
                  "ledger":{
                     "hash":"jx7buQVWFLsXTtzRgSxbYcT8EYLS8KCZbLrfDcJxMtyy4thw2Ee",
                     "totalCurrency":805385692840039300
                  },
                  "lockCheckpoint":"3NLoKn22eMnyQ7rxh5pxB6vBA3XhSAhhrf7akdqS6HbAKD14Dh1d",
                  "seed":"2vaRh7FQ5wSzmpFReF9gcRKjv48CcJvHs25aqb3SSZiPgHQBy5Dt",
                  "startCheckpoint":"3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x"
               },
               "hasAncestorInSameCheckpointWindow":true,
               "block_stake_winner":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
               "block_creator":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
               "coinbase_receiver":"B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
               "supercharge_coinbase":true,
               "receivedTime":"2021-03-17T00:00:00Z",
               "snarkFees":"0",
               "stateHash":"3NKeMoncuHab5ScarV5ViyF16cJPT4taWNSaTLS64Dp67wuXigPZ",
               "stateHashField":"9884505309989150310604636992054488263310056292998048242928359357807664465744",
               "txFees":"0"
            }
         }
      }
   }
}
```

## 6.2 Select chain

The _select chain_ event occurs every time a peer's chains are updated.  A chain is said to be _updated_ anytime a valid block is added or removed from its head.  All compatible peers MUST select chains as described here.

In addition to the high-level idea given in [Section 5.2](#52-chain-selection-rules) and details given in [Section 5.4](#54-sliding-window-density), the chain selection algorithm also employs some tiebreak logic.

Additional tiebreak logic is needed when comparing chains of equal length or equal minimum density.  The minimum density tiebreak rule is simple-- if we are applying the long-range rule and two chains have equal minimum window density, then we apply the short-range rule (i.e. select the longer chain).

### 6.2.3 Bringing it all together

Let `P.tip` refer to the top block of peer `P`'s current best chain.  Assuming an update to either `P.tip` or `P.chains`, `P` must update its `tip` like this

```rust
P.tip = selectSecureChain(P.tip, P.chains)
```

The `selectSecureChain` algorithm, presented below, takes as input the peer's current best chain `P.tip` and its set of known valid chains `P.chains` and outputs the most secure chain.

```rust
fn selectSecureChain(tip, chains) -> Chain
{
    // Compare each candidate in chains with best tip
    for candidate in chains {
        if isShortRange(candidate, tip) {
            // short-range fork, select longer chain
            tip = selectLongerChain(tip, candidate)
        }
        else {
            // long-range fork, compare relative minimum window densities
            let tip_density = relativeMinWindowDensity(tip, candidate)
            let candidate_density = relativeMinWindowDensity(candidate, tip)
            if candidate_density > tip_density {
                tip = candidate
            }
            else if candidate_density == tip_density  {
                // tiebreak with short-range rule
                tip = selectLongerChain(tip, candidate)
            }
        }
    }

    return tip
}
```

It relies on the [`isShortRange`](#532-short-range-fork-check) and [`relativeMinWindowDensity`](#5412-relative-minimum-window-density) algorithms (Section 5.3.2 and Section 5.4.12) and the `selectLongerChain` algorithm below.

```rust
fn selectLongerChain(tip, candidate) -> Chain
{
    if length(tip) < length(candidate) {
        return candidate
    }
    // tiebreak logic
    else if length(tip) == length(candidate) {
        // compare last VRF digests lexicographically
        if hashLastVRF(candidate) > hashLastVRF(tip) {
            return candidate
        }
        else if hashLastVRF(candidate) == hashLastVRF(tip) {
            // compare consensus state hashes lexicographically
            if hashState(candidate) > hashState(tip) {
                return candidate
            }
        }
    }

    return tip
}
```

As mentioned above, tiebreak logic is also needed when the candidate chains have equal length.  In this case the tie is broken using the hashes of the last VRF output ([`hashLastVRF`](#516-hashlastvrf)).  If there is still a tie, we use the protocol state hashes to decide ([`hashState`](#517-hashstate)).  Note that collisions here are overwhelmingly unlikely.