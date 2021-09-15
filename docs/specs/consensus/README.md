Consensus
---------

Mina uses [Ouroboros Samasika](https://eprint.iacr.org/2020/352.pdf) for consensus, hereafter referred to as Samasika.  The three fundamental guarantees delivered are
* High decentralization - Self-bootstrap, uncapped participation and dynamic availability
* Succinctness - Constant-time synchronization with full-validation and high interoperability
* Universal composability - Proven security for interacting with other protocols, no slashing required

Samasika extends the ideas from [Ouroboros Genesis](https://eprint.iacr.org/2018/378.pdf) and [Ouroboros Praos](https://eprint.iacr.org/2017/573.pdf) to the succinct blockchain setting, where the complexity of fully verifying the entire blockchain is independent of chain length.  The name Samasika comes from the Sanskrit word, meaning small or succinct.

This documents specifies required structures, algorithms and protocol details.

**Table of Contents**

<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [1. Constants](#1-constants)
- [2. Structures](#2-structures)
  - [2.1 `State_hash.Stable.V1`](#21-state_hashstablev1)
  - [2.2 `Epoch_seed.Stable.V1.t`](#22-epoch_seedstablev1t)
  - [2.2 `External_transition`](#22-external_transition)
  - [2.3 `Protocol_state`](#23-protocol_state)
    - [2.3.1 `Protocol_state.Body`](#231-protocol_statebody)
  - [2.4 `Consensus_state`](#24-consensus_state)
  - [2.6 `Epoch_data`](#26-epoch_data)
  - [2.7 Example block](#27-example-block)
- [3. Algorithms](#3-algorithms)
  - [3.1 Common](#31-common)
    - [3.1.1 `top`](#311-top)
    - [3.1.2 `cState`](#312-cstate)
    - [3.1.3 `globalSlot`](#313-globalslot)
    - [3.1.4 `epochSlot`](#314-epochslot)
    - [3.1.5 `length`](#315-length)
    - [3.1.6 `lastVRF`](#316-lastvrf)
    - [3.1.7 `stateHash`](#317-statehash)
    - [3.1.8 `subWindow`](#318-subwindow)
    - [3.1.9 `sameSubWindow`](#319-samesubwindow)
    - [3.1.10 `relativeSubWindow`](#3110-relativesubwindow)
  - [3.2 Chain selection rules](#32-chain-selection-rules)
    - [3.2.1 Short-range fork rule](#321-short-range-fork-rule)
    - [3.2.2 Long-range fork rule](#322-long-range-fork-rule)
  - [3.3 Decentralized checkpointing](#33-decentralized-checkpointing)
    - [3.3.1 `initCheckpoints`](#331-initcheckpoints)
    - [3.3.2 `updateCheckpoints`](#332-updatecheckpoints)
    - [3.3.3 `isShortRange`](#333-isshortrange)
  - [3.4 Window min-density](#34-window-min-density)
    - [Terminology](#terminology)
    - [Sliding windows](#sliding-windows)
    - [Sub-windows](#sub-windows)
    - [Structure](#structure)
    - [Minimum window density](#minimum-window-density)
    - [3.4.1 `isWindowStop`](#341-iswindowstop)
    - [3.4.2 `shiftWindow`](#342-shiftwindow)
    - [3.4.3 `initSubWindowDensities`](#343-initsubwindowdensities)
    - [3.4.4 `updateSubWindowDensities`](#344-updatesubwindowdensities)
    - [3.4.5 `getMinWindowDensity`](#345-getminwindowdensity)
- [4 Protocol](#4-protocol)
  - [4.1 Initialize consensus](#41-initialize-consensus)
    - [4.1.1 Genesis block](#411-genesis-block)
  - [4.2 Select chain](#42-select-chain)
    - [4.2.1 Virtual chains](#421-virtual-chains)
    - [4.2.2 Tiebreak logic](#422-tiebreak-logic)
    - [4.2.3 Bringing it all together](#423-bringing-it-all-together)

<!-- /TOC --> depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [1. Constants](#1-constants)
- [2. Structures](#2-structures)
  - [2.1 `State_hash.Stable.V1`](#21-state_hashstablev1)
  - [2.2 `Epoch_seed.Stable.V1.t`](#22-epoch_seedstablev1t)
  - [2.2 `External_transition`](#22-external_transition)
  - [2.3 `Protocol_state`](#23-protocol_state)
    - [2.3.1 `Protocol_state.Body`](#231-protocol_statebody)
  - [2.4 `Consensus_state`](#24-consensus_state)
  - [2.6 `Epoch_data`](#26-epoch_data)
  - [2.7 Example block](#27-example-block)
- [3. Algorithms](#3-algorithms)
  - [3.1 Common](#31-common)
    - [3.1.1 `top`](#311-top)
    - [3.1.2 `cState`](#312-cstate)
    - [3.1.3 `globalSlot`](#313-globalslot)
    - [3.1.4 `epochSlot`](#314-epochslot)
    - [3.1.5 `length`](#315-length)
    - [3.1.6 `lastVRF`](#316-lastvrf)
    - [3.1.7 `stateHash`](#317-statehash)
    - [3.1.8 `subWindow`](#318-subwindow)
    - [3.1.9 `sameSubWindow`](#319-samesubwindow)
    - [3.1.10 `relativeSubWindow`](#3110-relativesubwindow)
  - [3.2 Chain selection rules](#32-chain-selection-rules)
    - [3.2.1 Short-range fork rule](#321-short-range-fork-rule)
    - [3.2.2 Long-range fork rule](#322-long-range-fork-rule)
  - [3.3 Decentralized checkpointing](#33-decentralized-checkpointing)
    - [3.3.1 `initCheckpoints`](#331-initcheckpoints)
    - [3.3.2 `updateCheckpoints`](#332-updatecheckpoints)
    - [3.3.3 `isShortRange`](#333-isshortrange)
  - [3.4 Window min-density](#34-window-min-density)
    - [Terminology](#terminology)
    - [Sliding windows](#sliding-windows)
    - [Sub-windows](#sub-windows)
    - [Structure](#structure)
    - [Minimum window density](#minimum-window-density)
    - [3.4.1 `isWindowStop`](#341-iswindowstop)
    - [3.4.2 `shiftWindow`](#342-shiftwindow)
    - [3.4.3 `initSubWindowDensities`](#343-initsubwindowdensities)
    - [3.4.4 `updateSubWindowDensities`](#344-updatesubwindowdensities)
    - [3.4.5 `getMinWindowDensity`](#345-getminwindowdensity)
- [4 Protocol](#4-protocol)
  - [4.1 Initialize consensus](#41-initialize-consensus)
    - [4.1.1 Genesis block](#411-genesis-block)
  - [4.2 Select chain](#42-select-chain)
    - [4.2.1 Virtual chains](#421-virtual-chains)
    - [4.2.2 Tiebreak logic](#422-tiebreak-logic)
    - [4.2.3 Bringing it all together](#423-bringing-it-all-together)

<!-- /TOC -->

**Conventions**
* We use the terms _top_ and _last_ interchangeably to refer to the block with the greatest height on a given chain
* We use the term _epoch slot number_ to refer to the intra-epoch slot number that resets to 1 every epoch
* We use _global slot number_ to refer to the global slot number since genesis starting at 1

**Notations**
* `a⌢b` - Concatenation of `a` and `b`
* `T[N]` - Array of type `T` containing `N` elements
* `T[v; N]` - Array of type `T` containing `N` elements of value `v`
* `x[i]` - Element `i` of array `x`, starting at index `0`
* `x[-1]` - Last element of array `x`
* `x[a..b]` - Slice of vector `x` containing elements from indexes `[a, b)`

# 1. Constants

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
| `slots_per_sub_window`          | `7`                     | Slots per sub window (see [Section 3.4](#34-window-min-density)) |
| `sub_windows_per_window`        | `11`                    | Sub windows per window (see [Section 3.4](#34-window-min-density)) |
| `slots_per_window`              | `slots_per_sub_window*sub_windows_per_window` (= 77) | Slots per window |

# 2. Structures

The main structures used in Mina consensus are as follows

## 2.1 `State_hash.Stable.V1`

| Field                           | Type                               | Description |
| - | - | - |
| `b58_version`                   | `u8` (= 0x10)                      | Base58 check version byte |
| `version`                       | `u8` (= 0x01)                      | Structure version |
| `field`                         | `Field.t`                          | Field element |

## 2.2 `Epoch_seed.Stable.V1.t`

| Field                           | Type                               | Description |
| - | - | - |
| `version`                       | `u8` (= 0x01)                      | Structure version |
| `field`                         | `Field.t`                          | Field element |

## 2.2 `External_transition`

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

## 2.3 `Protocol_state`

This structure can be thought of like the block header.  It contains the most essential information of a block.

| Field                 | Type                     | Description |
| - | - | - |
| `version`             | `u8` (= 0x01)            | Block structure version      |
| `previous_state_hash` | `State_hash.Stable.V1.t` | Commitment to previous block (hash of previous protocol state hash and body hash)|
| `body`                | `Protocol_state.Body.Value.Stable.V1` | The body of the protocol state |

### 2.3.1 `Protocol_state.Body`

| Field                 | Type                     | Description |
| - | - | - |
| `version`             | `u8` (= 0x01)            | Block structure version |
| `genesis_state_hash`  | `State_hash.Stable.V1.t` | Genesis protocol state hash (used for hardforks) |
| `blockchain_state`    | `Blockchain_state.Value.Stable.V1.t` | Ledger related state |
| `consensus_state`     | `Consensus.Data.Consensus_state.Value.Stable.V1.t` | Consensus related state |
| `constants`           | `Protocol_constants_checked.Value.Stable.V1.t` | Consensus constants |

## 2.4 `Consensus_state`

This structure encapsulates the succinct state of the consensus protocol.  The stake distribution information is contained by the `staking_epoch_data` field.  Due to its succinct nature, Samasika cannot look back into the past to obtain ledger snapshots for the stake distribution.  Instead, Samasika implements a novel approach where the future stake distribution snapshot is prepared by the current consensus epoch.  Samasika prepares the past for the future!  This future state is stored in the `next_epoch_data` field.

| Field                                    | Type                     | Description |
| - | - | - |
| `version`                                | `u8` (= 0x01)            | Block structure version |
| `blockchain_length`                      | `Length.Stable.V1.t` | Height of block |
| `epoch_count`                            | `Length.Stable.V1.t` | Epoch number |
| `min_window_density`                     | `Length.Stable.V1.t` | Minimum windows density observed on this chain (see [Section 3.2.2](#322-long-range-fork-rule)) |
| `sub_window_densities`                   | `Length.Stable.V1.t list` | Current sliding window of densities (see [Section 3.4](#34-window-min-density)) |
| `last_vrf_output`                        | `Vrf.Output.Truncated.Stable.V1.t` | Additional VRS output from leader (for seeding Random Oracle) |
| `total_currency`                         | `Amount.Stable.V1.t` | Total supply of currency |
| `curr_global_slot`                       | `Global_slot.Stable.V1.t` | Current global slot number relative to the current hard fork  |
| `global_slot_since_genesis`              | `Mina_numbers.Global_slot.Stable.V1.t` | Absolute global slot number since genesis |
| `staking_epoch_data`                     | `Epoch_data.Staking_value_versioned.Value.Stable.V1.t` | Epoch data for previous epoch |
| `next_epoch_data`                        | `Epoch_data.Next_value_versioned.Value.Stable.V1.t` | Epoch data for current epoch |
| `has_ancestor_in_same_checkpoint_window` | `bool` | |
| `block_stake_winner`                     | `Public_key.Compressed.Stable.V1.t` | Compressed public key of winning account |
| `block_creator`                          | `Public_key.Compressed.Stable.V1.t` | Compressed public key of the block producer |
| `coinbase_receiver`                      | `Public_key.Compressed.Stable.V1.t` | Compresed public key of account receiving the block reward |
| `supercharge_coinbase`                   | `bool` | `true` if `block_stake_winner` has no locked tokens, `false` otherwise |

## 2.6 `Epoch_data`

| Field              | Type                     | Description |
| - | - | - |
| `version`          | `u8` (= 0x01)            | Block structure version |
| `ledger`           | `Epoch_ledger.Value.Stable.V1.t` | |
| `seed`             | `Epoch_seed.Stable.V1.t` | |
| `start_checkpoint` | `State_hash.Stable.V1.t` | State hash of _first block_ of epoch (see [Section 3.3](#33-decentralized-checkpointing))|
| `lock_checkpoint`  | `State_hash.Stable.V1.t` | State hash of _last known block in the first 2/3 of epoch_ (see [Section 3.3](#33-decentralized-checkpointing)) excluding the current state |
| `epoch_length`     | `Length.Stable.V1.t` | |

## 2.7 Example block

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

# 3. Algorithms

This section outlines the main algorithms and constructs used by Samasikia.

## 3.1 Common

This section outlines some commonly used helpers.

### 3.1.1 `top`

This function returns the last block of a given chain.  The input is a chain `C` and the output is last block of `C` (i.e. the block with greatest height).

```rust
fn top(C) -> Block
{
   return last block of C
}
```

### 3.1.2 `cState`

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

### 3.1.3 `globalSlot`

The function returns the _global slot number_ of a chain or block.  The input `X` is either a chain or block and the output is the global slot number.

```rust
fn globalSlot(X) -> u64
{
    return cState(X).curr_global_slot
}
```

### 3.1.4 `epochSlot`

The function computes the _epoch slot number_ of a block.  The input is the block `B` and the output is the epoch slot number in `[0, slots_per_epoch]`.

```rust
fn epochSlot(B) -> u32
{
   return globalSlot(B) mod slots_per_epoch
}
```

### 3.1.5 `length`

The function the length of a chain.  The input is the global chain `C` and the output is the length of the chain in blocks.

```rust
fn length(C) -> u64
{
   return cState(C).blockchain_length
}
```

### 3.1.6 `lastVRF`

This function returns the hex digest of the hash of the last VRF output of a given chain.  The input is a chain `C` and the output is the hash digest.

```rust
fn lastVRF(C) -> String
{
   return Digest(Blake2b(cState(C).last_vrf_output))
}
```

### 3.1.7 `stateHash`

This function returns hash of the top block's consensus state for a given chain.  The input is a chain `C` and the output is the hash.

```rust
fn stateHash(C) -> Hash
{
   return Blake2b(cState(C))
}
```

### 3.1.8 `subWindow`

This function returns the sub-window number of a block.

```rust
fn subWindow(B) -> u64
{
   return globalSlot(B)/slots_per_sub_window
}
```

### 3.1.9 `sameSubWindow`

This function returns true if two blocks are in the same global sub-window.

```rust
fn sameSubWindow(A, B) -> bool
{
   return subWindow(A) == subWindow(B)
}
```

### 3.1.10 `relativeSubWindow`

This function returns the relative sub-window number of a block.

```rust
fn relativeSubWindow(B) -> u64
{
   return subWindow(B) mod sub_windows_per_window
}
```

## 3.2 Chain selection rules

Samasika uses two consensus rules: one for *short-range forks* and one for *long-range forks*.

### 3.2.1 Short-range fork rule

This rule is triggered whenever the fork is such that the adversary has not yet had the opportunity to mutate the block density distribution.

```rust
Choose the longest chain
```

A fork is short-range if it occured less than `m` blocks ago.  The naı̈ve implemention of this rule is to always store the last `m` blocks, but for a succinct blockchain this is not desirable.  Mina Samasika adopts an approach that only requires information about two blocks.  The idea is a decentralized checkpointing algorithm, the details of which are given in [Section 3.3](#33-decentralized-checkpointing).

### 3.2.2 Long-range fork rule

Recall that when an adversary creates a long-range fork, over time it skews the leader selection distribution leading to a longer adversarial chain.  Initially the dishonest chain will have a lower density, but in time the adversary will work to increase it.  Thus, we can only rely on the density difference in the first few slots following the fork, the so-called *critical window*.  The idea is that for the honest chain's critical window the density is overwhelmingly likely to be higher because this chain contains the majority of stake.

As a succint blockchain, Mina does not have a chain into which it can look back on the fork point to observe the densities.  Moreover, the slot range of the desired densities cannot be know ahead of time.

Samasika overcomes this problem by storing a succinct summary of a sliding window of slots over each chain and then tracks the *minimum* of all densities observed for each sliding window.  The intuition is that if the adversary manages to increase the density on the dishonest chain, the tracked minimum density still points to the critical window following the fork.

[Section 3.4](#34-window-min-density) specifies how the sliding windows are tracked and how the minimum density is computed.  For now, we assume that each chain contains the minimum window density and describe the main idea of the long-range fork rule.

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

The above pseudocode is only to provide intuition about how the chain selection rules work.  A detailed description of the succinct sliding window structure is described in section [Section 3.4](#34-window-min-density) and the actual chain selection algorithm is specified in [Section 4.2](#42-select-chain).

## 3.3 Decentralized checkpointing

<!--
; start_checkpoint: 'start_checkpoint
      (* The lock checkpoint is the hash of the latest state in the seed update range, not including
         the current state. *)
; lock_checkpoint: 'lock_checkpoint
-->

Samasika uses decentralized checkpointing to determine whether a fork is short- or long-range.  Each epoch is split into three parts with an equal number of slots.  The first 2/3 are called the *seed update range* because this is when the VRF is seeded.

For example, consider an example epoch `i` of 15 slots, `s1 ... s15`.

```text
epoch i: s1 s2 s3 s4 s5 | s6 s7 s8 s9 s10 | s11 s12 s13 s14 s15
         \______________________________/
              2/3 (seed update range)
```

As seen above, the slots can be split into 3 parts delimited by `|`.  The first `2/3` of the slots (`s1 ... s10`) are in the seed update range. The epoch seeds of blocks in this rage are used to seed the VRF.

The idea of decentralized checkpointing is that each chain maintains two checkpoints in every epoch, which are used to estimate how long ago a fork has occured.

* **Start checkpoint** - State hash of the first block of the epoch
* **Lock checkpoint** - State hash of the last known block in the seed update range of an epoch (not including the current block)

For example, consider epoch `e1 ... e3` below.

```text
epochs:         e1                e2                 e3
                                      ⤺lock
slots:  s1s2s3s4s5s6s7s8s9|s1s2s3s4s5s6s7s8s9|s1s2s3...
                     start⤻⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺
```

Here the current slot is `s7`, the start checkpoint is `s1` and the lock checkpoint is `s6`.

These are located in the `start_checkpoint` and `lock_checkpoint` fields of the [`Epoch_data`](#26-epoch_data) structure, which is part of the [`Consensus_state`](#25-consensus_state) (See [Section 2.6](#26-epoch_data)).

As time progresses away from the first slot of the current epoch, the lock checkpoint is pushed along with the last known block until we reach the last block in the first `2/3` of the epoch and it is _frozen_. ❄

A fork is considered _short-range_ if either

1. the fork point of the candidate chains are in the same epoch
2. or the fork point is in the previous epoch with the same `lock_checkpoint`

Since the leader selection distribution for the current epoch is computed by the end of the first `2/3` of the slots in the previous epoch, an adversarial fork after the previous epoch's `lock_checkpoint` cannot skewed the distribution for the remainder of that epoch, nor the current epoch.  Anything before the previous epoch's `lock_checkpoint` _long-range_ fork.

Since Mina is succinct this means that it must stored the checkpoints for the current epoch in addition to the checkpoints for the previous epoch.  This is why the [`Consensus_state`](#25-consensus_state) structure contains two `Epoch_data` fields: `staking_epoch_data` and `next_epoch_data`.  The former contains the checkpoints for the previous epoch and the latter contains that of the current epoch.

### 3.3.1 `initCheckpoints`

**WIP**

This algorithm initializes the checkpoints for genesis block `G`

```rust
fn initCheckpoints(G) -> ()
{
    cState(G).staking_epoch_data.seed = zero
    cState(G).staking_epoch_data.start_checkpoint = zero
    cState(G).staking_epoch_data.lock_checkpoint = zero
    cState(G).staking_epoch_data.length = 1

    state_hash = poseidon_3w_hash(latest state ϵ cState(G).next_epoch_data.seed's update range) ?
    cState(G).next_epoch_data.start_checkpoint = state_hash ?
    cState(G).next_epoch_data.lock_checkpoint =  state_hash ?
}
```

### 3.3.2 `updateCheckpoints`

This algorithm updates the checkpoints of the block being created `B` based on its parent block `P`.  It inputs the blocks `P` and `B` and updates `B`'s checkpoints according to the description in [Section 3.3](#33-decentralized-checkpointing).

```rust
fn updateCheckpoints(P, B) -> ()
{
    state_hash = poseidon_3w_hash(latest state ϵ cState(P).next_epoch_data.seed's update range) ?
    if epochSlot(B) == 0 then
        cState(B).next_epoch_data.start_checkpoint = state_hash

    if 0 ≤ epochSlot(B) < 2/3*slots_per_epoch {
        cState(B).next_epoch_data.lock_checkpoint = state_hash
    }
}
```

Specifically, if the epoch slot of the new block `B` is the start of a new epoch, then the `start_checkpoint` of the current epoch data (`next_epoch_data`) is updated to the state hash from the previous block `P`.  Next, if the the new block's slot is also within the first `2/3` of the slots in the epoch ([`slots_per_epoch`](#1-constants)), then the `lock_checkpoint` of the current epoch data is also updated to the same value.

### 3.3.3 `isShortRange`

This algorithm uses the checkpoints to determine if the fork of two chains is short-range or long-range.  It inputs two chains with a fork `C1` and `C2` and outputs `true` if the fork is short-range, otherwise the fork is long-range and it outputs `false`.

```rust
fn isShortRange(C1, C2) -> bool
{
    if cState(C1).staking_epoch_data.lock_checkpoint == cState(C2).staking_epoch_data.lock_checkpoint {
        return true
    }
    else {
        return false
    }
}
```

## 3.4 Window min-density

This section describes the succinct sliding window density structure, how to compute it and how to compute minimum density. Firstly we must define some terminology.

### Terminology

* We say a slot is _`filled`_ if it contains a valid non-orphaned block
* An `n-window` is a sequential list of slots s<sub>1</sub>,...,s<sub>n</sub> of length `n`
* A `sub-window` is a contiguous region of a `n-window`
* The _`density`_ of an n-window (or sub-window) is the number non-orphan block within it

### Sliding windows

The _`sliding window`_ can be thought of different ways.  In the Ouroborus Samasika paper it is referred to as a `v`-shifting `w`-window and it characterisd by two parameters.

| Parameter | Description                                | Value |
| - | - | - |
| `v`       | Length by which the window shifts in slots (shift parameter) | [`slots_per_sub_window`](#1-constants) (= 7) |
| `w`       | Window length in slots                                       | [`slots_per_sub_window`](#1-constants)` * `[`sub_windows_per_window`](#1-constants) (= 7*11 = 77 slots) |

This is a `w`-long window that shifts `v`-slots at a time.

### Sub-windows

Another way to imagine the `sliding window` is as a collection of sub-windows.  That is, you can think of the `w`-length window as being comprised of `k` sub-windows, each of length `v` slots.  For the parameters given in the table above, the sliding window looks like this:

```text
   |s1,...,s7|s8,...,s14| ... |s71,...,s77|
k:      1          2      ...      11
```

where `si` is slot `i`.

Instead of storing the slots Samasika is only interested in the density of each sub-window, thus, it need only track a list of densities.

As hinted at in the table above, Mina Samasika tracks the previous `k = 11` sub-windows

```text
                      |s1,...,s7|s8,...,s14| ... |s71,...,s77|
sub_window_densities:      d1        d2      ...       dk
```

The value of `k` is defined by the [`sub_windows_per_window`](#1-constants) constant.

### Structure

This sliding window is stored as list of sub-window of densities in each block.  Specifically, it is the `sub_window_densities` field of the `Consensus_state` (see [Section 2.5](#25-consensus_state)).  This field is of type `Length.Stable.V1.t list` and because it must be written into blocks as part of the protocol, an implimentation MUST implement serialization for this type.

Given block `B`, the values stored in `B.sub_window_densities` has this format.

| Index | Contents |
| - | - |
| `0` | Oldest sub-window density |
| `...` | |
| `k - 2` | Previous sub-window density |
| `k - 1` | Current sub-window density (i.e. the sub-window density of `B`'s sub-window) |

### Minimum window density

Each block also stores the minimum window density, found in the `min_window_density` field of the `Consensus_state` (see [Section 2.5](#25-consensus_state)).

In order to define the *minimum window density* of block, we first need to define the *window density*.  Given a block `C` whose sub-window densities has been computed, the window density of `C` is

> window_density(C) = sum(C.sub_window_densities)

The minimum window density for block `C` is defined as the minimum of `C`'s window density and the previous blocks minimum window density (i.e. the minimum window density of `C`'s parent block).

> min_window_density(C) = min(window_density(C), window_density(C.parent))

We will describe how to compute the minimum window density in [Section 3.4.5](#345-getminwindowdensity); however, in order to understand it you will also need to understand the algorithm for updating the window (i.e. updating the sub-window densities), which is the subject of [Section 3.4.4](#344-updatesubwindowdensity).

### 3.4.1 `isWindowStop`

This algorithm detects whether we have reached the end of a sub-window.  It is used to decide if we must perform a `v`-shift.  It takes as input the current epoch slot number `s`, the shift parameter `v` and outputs `true` if we have reached the end of a sub-window and `false` otherwise.

```rust
fn isWindowStop(s, v) -> bool
{
    if s mod v == 0 {
        return true
    }
    else {
        return false
    }
}
```

### 3.4.2 `shiftWindow`

**WIP**

<!--
This algorithm is responsible for shifting the sliding window.  It inputs the sliding window `W` = [d<sub>1</sub>,...,d<sub>w</sub>] and the current sub window densities `C = [d<sub>w+1</sub>,...,d<sub>w+v</sub>] and then outputs the result `W'` = [d<sub>1+v</sub>,...,d<sub>w+v</sub>], where `v` is the shift parameter.

>```rust
fn shiftWindow(W, C) -> W'
{
    return W[4..]⌢C
}

-->

This algorithm is responsible for shifting the sliding window.  It inputs the sub-window densities `D` = [d<sub>0</sub>,...,d<sub>k</sub>] and then outputs the result `D'` = [d<sub>1</sub>,...,d<sub>k</sub>].

```rust
fn shiftWindow(D) -> D'
{
    return D[1..]
}
```

### 3.4.3 `initSubWindowDensities`

This algorithm initializes the sub-window densities and minimm window density for genesis block `G`.  This method is used to update the sub-window densities

<!-- cState(G).sub_window_densities = u32[0]⌢u32[slots_per_window; sub_windows_per_window - 1] -->

```rust
fn initSubWindowDensities(G) -> ()
{
    cState(G).sub_window_densities = u32[0, slots_per_window, slots_per_window, ..., slots_per_window]
    //                                      \_______________________________________________________/
    //                                                   sub_windows_per_window - 1

    cState(G).min_window_density = slots_per_window
}
```

### 3.4.4 `updateSubWindowDensities`

**WIP**

This algorithm computes the density window for the current block `B` based on its parent block `P` and returns the minimum window density.  It is used both in block production and during chain selection for reasons described in [Section 4.2.1](#421-virtual-chains).  For details about density windows and minimum window density see [Section 3.4](#34-window-min-density)

```rust
fn updateSubWindowDensities(P, B) -> ()
{
    cState(B).sub_window_densities = cState(P).sub_window_densities

    // Compute how many slots B is ahead of P and use it to shift sub_window_densities
    let shift = MIN { globalSubWindow(B) - globalSubWindow(P), cState(B).sub_window_densities.len() }

    let curr_density = cState(B).sub_window_densities[current_sub_window mod sub_windows_per_window]

    if shift > 0 {
        // Left-shift the sub-window densities
        cState(B).sub_window_densities = cState(B).sub_window_densities[shift..]⌢[0; shift]
    }

    // Update the minimum window density
    if shift == 0 or globalSlot(B) < grace_period_end {
        // Minimum window density is parents minimum window density
        cState(B).min_window_density = cState(P).min_window_density
    }
    else {
        new_min_window_density = 0
        for density in cState(B).sub_window_densities {
            new_min_window_density += density
        }
        cState(B).min_window_density = MIN { new_min_window_density, cState(P).min_window_density }
    }

    // Update the density of B's sub-window to reflect B's existence
    cState(B).sub_window_densities[-1] += 1
}
```

```rust
fn updateWindowDensities(P, B) -> ()
{
    cState(B).sub_window_densities = cState(P).sub_window_densities

    // Compute how many slots B is ahead of P and use it to shift sub_window_densities
    let shift = MIN { globalSubWindow(B) - globalSubWindow(P), cState(B).sub_window_densities.len() }
    if shift > 0 {
        // Left-shift the sub-window densities
        cState(B).sub_window_densities = cState(B).sub_window_densities[shift..]⌢[0; shift]
    }

    // Update the minimum window density
    if shift == 0 or globalSlot(B) < grace_period_end {
        // Minimum window density is parents minimum window density
        cState(B).min_window_density = cState(P).min_window_density
    }
    else {
        new_min_window_density = 0
        for density in cState(B).sub_window_densities {
            new_min_window_density += density
        }
        cState(B).min_window_density = MIN { new_min_window_density, cState(P).min_window_density }
    }

    // Update the density of B's sub-window to reflect B's existence
    cState(B).sub_window_densities[-1] += 1
}
```

### 3.4.5 `getMinWindowDensity`

**WIP**

This function returns the current minimum density of a chain.  It inputs a chain `C` and the `max_slot` observed between `C`  and the alternative chain (See [selectSecureChain](#42-select-chain)).

```rust
fn getMinWindowDensity(C, max_slot) -> density
{
    if globalSlot(C) == max_slot {
        return cState(C).min_window_density
    }
    else {
        prev_global_sub_window = globalSlot(C) / slots_per_sub_window
        prev_relative_sub_window = prev_global_sub_window mod sub_windows_per_window

        next_global_sub_window = max_slot / slots_per_sub_window
        next_relative_sub_window = next_global_sub_window mod sub_windows_per_window

        if prev_global_sub_window == next_relative_sub_window {
            // Same sub window
        }

        if prev_global_sub_window + sub_windows_per_window >= next_global_sub_window {
            // Same window
        }
     }
}
```

# 4 Protocol

This section specifies the consensus protocol in terms of events and how they MUST be implemented by a compatible peer.  The required events are:
* [`Initialize consensus`](#41-initialize-consensus)
* [`Select chain`](#42-select-chain)

Additionally there are certain local data members that all peers MUST maintain in order to participate in consensus.

| Parameter   | Description |
| - | - |
| `genesis_block` | The initial block in the blockchain |
| `neighbors`     | Set of connections to neighboring peers |
| `chains`        | Set of known (succinct) candidate chains |
| `tip`           | Currently selected chain according to the chain selection algorithm (i.e. secure chain) |

How these are represented is up to the implementation, but careful consideration must be given to scalability.

In the following description we use _dot notation_ to refer the local data members of peers. For example, given peer `P`, we use `P.genesis_block` and `P.tip`, to refer to the genesis block and currently selected chain, respectively.

## 4.1 Initialize consensus

Things a peer MUST do to initialize consensus includes
* Load the genesis block
* Get head of the current chain
* Decide if peer should bootstrap or sync

### 4.1.1 Genesis block

**`Consensus_state`**

| Field                                    | Value         |
| - | - |
| `version`                                | `0x01`        |
| `blockchain_length`                      | `1`           |
| `epoch_count`                            | `0`           |
| `min_window_density`                     | `77 = slots_per_window` |
| `sub_window_densities`                   | `u32[77, 11]` (See [initSubWindowDensities](#343-initsubwindowdensities)) |
| `last_vrf_output`                        | `0x0000000000000000000000000000000000000000000000000000000000000000`
| `total_currency`                         | `805385692.840039233`
| `curr_global_slot`                       | `0` |
| `global_slot_since_genesis`              | `0` |
| `staking_epoch_data`                     | See [Section 4.1.1.2](#4112-staking_epoch_data) |
| `next_epoch_data`                        | See [Section 4.1.1.3](#4112-next_epoch_data) |
| `has_ancestor_in_same_checkpoint_window` | `false` | |
| `block_stake_winner`                     | `Public_key.Compressed.Stable.V1.t(B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)` |
| `block_creator`                          | `Public_key.Compressed.Stable.V1.t(B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)` |
| `coinbase_receiver`                      | `Public_key.Compressed.Stable.V1.t(B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg)` |
| `supercharge_coinbase`                   | `false` |

**JSON**

**WIP**

The following JSON specifies most of the genesis block (work in progress).

```json
{
  "data": {
    "block": {
      "blockHeight": 1,
      "canonical": true,
      "creator": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg",
      "creatorAccount": {
        "publicKey": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg"
      },
      "dateTime": "2021-03-17T00:00:00Z",
      "protocolState": {
        "blockchainState": {
          "date": "1615939200000",
          "snarkedLedgerHash": "jx7buQVWFLsXTtzRgSxbYcT8EYLS8KCZbLrfDcJxMtyy4thw2Ee",
          "stagedLedgerHash": "jx7buQVWFLsXTtzRgSxbYcT8EYLS8KCZbLrfDcJxMtyy4thw2Ee",
          "utcDate": "1615939200000"
        },
        "consensusState": {
          "blockchainLength": 1,
          "epochCount": 0,
          "minWindowDensity": 77,
		  "sub_window_densities": TODO: Missing
		  "lastVrfOutput": "EiRs4sfLJRsfCoy92Bb2mR7zYLDXDAnSqnE2uXbhodfmGykDy8UdS", (TODO: Doesn't match)
		  "totalCurrency": 805385692840039300, (TODO: Doesn't match 805385692840039233)
		  "currGlobalSlot": 0,
		  "slotSinceGenesis": 0,
		  "stakingEpochData": {
			"epochLength": 1,
			"ledger": {
			  "hash": "jx7buQVWFLsXTtzRgSxbYcT8EYLS8KCZbLrfDcJxMtyy4thw2Ee",
			  "totalCurrency": 805385692840039300
			},
			"lockCheckpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x",
			"seed": "2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA",
			"startCheckpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x"
		  },
          "nextEpochData": {
            "epochLength": 2,
            "ledger": {
              "hash": "jx7buQVWFLsXTtzRgSxbYcT8EYLS8KCZbLrfDcJxMtyy4thw2Ee",
              "totalCurrency": 805385692840039300
            },
            "lockCheckpoint": "3NLoKn22eMnyQ7rxh5pxB6vBA3XhSAhhrf7akdqS6HbAKD14Dh1d",
            "seed": "2vaRh7FQ5wSzmpFReF9gcRKjv48CcJvHs25aqb3SSZiPgHQBy5Dt",
            "startCheckpoint": "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x"
          }
		  "hasAncestorInSameCheckpointWindow": true,
		  "block_stake_winner": TODO: Missing,
		  "block_creator": TODO: Missing,
		  "coinbase_receiver": TODO: Missing,
		  "supercharge_coinbase": TODO: Missing,
        },
        "previousStateHash": "3NLoKn22eMnyQ7rxh5pxB6vBA3XhSAhhrf7akdqS6HbAKD14Dh1d"
      },
      "receivedTime": "2021-03-17T00:00:00Z",
      "snarkFees": "0",
      "snarkJobs": [],
      "stateHash": "3NKeMoncuHab5ScarV5ViyF16cJPT4taWNSaTLS64Dp67wuXigPZ",
      "stateHashField": "9884505309989150310604636992054488263310056292998048242928359357807664465744",
      "transactions": {
        "coinbase": "720000000000",
        "coinbaseReceiverAccount": {
          "publicKey": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg"
        },
        "feeTransfer": [],
        "userCommands": []
      },
      "txFees": "0",
      "winnerAccount": {
        "balance": {
          "blockHeight": 0,
          "liquid": 0,
          "locked": "0",
          "stateHash": "3NKeMoncuHab5ScarV5ViyF16cJPT4taWNSaTLS64Dp67wuXigPZ",
          "total": "0",
          "unknown": "0"
        },
        "publicKey": "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg"
      }
    }
  }
}
```

## 4.2 Select chain

**WIP**

The _select chain_ event occurs every time a peer's chains are updated.  A chain is said to be _updated_ anytime a valid block is added or removed from its head.  All compatible peers MUST select chains as described here.

In addition to the high-level idea given in the [Chain Selection Rules Section](#32-chain-selection-rules) described in [Section 3.2](#32-chain-selection-rules), the chain selection algorithm employs two additional concepts

* Virtual chains
* Tiebreak logic

### 4.2.1 Virtual chains

When a peer computes the best chain it does not actually directly compare the current chain against each candidate chain.  Instead, it compares the current chain against a *virtual chain* for each candidate chain.

Virtual chains are used to solve a minimum window density *inversion problem* that can happen when applying the long-fork chain selection rule, for example, when a peer that has been disconnected for a long time attempts to join the network again.

**Inversion problem**

Observe that by definition the minimum window density is always decreasing.  Therefore, a peer that has disconnected from the network for a long period and wishes to rejoin will have a higher minimum window density for it current best chain when compared to the canonical chain (i.e. the best chain for the network).

Recall that the long-range fork rule dictates that the peer select the chain with the higher minimum density.  However, this will actually be the peer's current chain, rather than the network's canonical chain (since the minimum window density is always decreasing).  Thus, the peer will be stuck and synchronization will not succeed-- the so-called inversion problem.

**Solution**

The invesrion problem is overcome by using *virtual chains*.  A virtual chain is created by temporarily mutating an existing chain and adding a virtual top block to it.  The virtual top block's global slot will reflect the current time, which is the time at which the peer is joining the network.

```rust
TODO: Spec of how to create a virtual top block for a given chain
```

During chain selection the peer uses the [`getMinWindowDensity`](#345-getminwindowdensity) algorithm to compare its current chain to virtual chains of the candidates.

### 4.2.2 Tiebreak logic

Additional tiebreak logic is needed when comparing chains of equal length or equal minimum density.  The rule is simple-- if we are applying the long-range rule and two chains have equal minimum window density, then we apply the short-range rule (i.e. select the longer chain).

### 4.2.3 Bringing it all together

Assuming an update to either `P.tip` or `P.chains`, the peer `P` must update its `tip` like this

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
            // long-range fork, compare minimum window densities
            max_slot = max(globalSlot(tip), globalSlot(candidate))
            if getMinWindowDensity(candidate, max_slot) > getMinWindowDensity(tip, max_slot) {
                tip = candidate
            }
            else if getMinWindowDensity(candidate, max_slot) == getMinWindowDensity(tip, max_slot) {
                // tiebreak
                tip = selectLongerChain(tip, candidate)
            }
        }
    }

    return tip
}
```

It relies on the [`isShortRange`](#333-isshortrange) and [`getMinWindowDensity`](#345-getminwindowdensity) algorithms (Section 3.3.3 and Section 3.4.5) and the `selectLongerChain` algorithm below.

```rust
fn selectLongerChain(tip, candidate) -> Chain
{
    if length(tip) < length(candidate) {
        return candidate
    }
    // tiebreak logic
    else if length(tip) == length(candidate) {
        // compare last VRF digests lexographically
        if lastVRF(candidate) > lastVRF(tip) {
            return candidate
        }
        else if lastVRF(candidate) == lastVRF(tip) {
            // compare consensus state hashes lexographically
            if stateHash(candidate) > stateHash(tip) {
                return candidate
            }
        }
    }

    return tip
}
```
