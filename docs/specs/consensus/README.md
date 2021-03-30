# Consensus

Mina uses [Ouroboros Samasika](https://eprint.iacr.org/2020/352.pdf) for consensus.

Samasika consensus is an extends the ideas from [Ouroboros Genesis](https://eprint.iacr.org/2018/378.pdf) and [Ouroboros Praos](https://eprint.iacr.org/2017/573.pdf) to the succint blockchain setting, where the complexity of fully verifying the entire blockchain is independent of chain length.

This documents specifies the protocol and related structures.

**Table of Contents**
* [1 Constants](#1-constants)
* [2 Structures](#2-structures)
  * [2.1 Block](#2.1-block)
  * [2.2 Protocol_state](#2.2-protocol_state)
  * [2.3 Consensus_state](#2.3-consensus_state)
  * [2.4 Epoch_data](#2.4-epoch_data)
* [3 Algorithms](#3-algorithms)
  * [3.1 Chain Selection Rules](#3.1chain-selection-rules)
    * [3.1.1 Short-range](#3.1.1-short-range-fork-rule)
    * [3.1.2 Long-range](#3.1.2-long-range-fork-rule)
  * [3.2 Decentralized Checkpointing](#3.2-decentralized-checkpointing)
  * [3.3 Window Min-density](#3.3-window-min-density)
    * [3.3.1 `isWindowStop`](#3.3.1-iswindowstop)
    * [3.3.2 `shiftWindow`](#3.3.2-shiftwindow)
  * [3.4 Chain Selection Protocol](#3.4-chain-selection-protocol)
    * [3.4.1 `getMinDen`](#3.4.1-getminden)
    * [3.4.2 `isShortRange`](#3.4.2-isshortrange)
    * [3.4.3 `isValidChain`](#3.4.3-isvalidchain)
    * [3.4.4 `maxvalid-sc`](#3.4.4-maxvalid-sc)
    * [3.4.5 `selectChain`](#3.4.5-selectchain)
  * [3.5 Genesis Initialization](#3.5-genesis-initialization)
    * [3.5.1 `initCheckpoints`](#3.5.1-initcheckpoints)
    * [3.5.2 `initSubWindowDensities`](#3.5.2-initsubwindowdensities)
  * [3.6 Staking Procedure](#3.6-staking-procedure)
    * [3.6.1 `updateCheckpoints`](#3.6.1-updatecheckpoints)

**Conventions**
* We use the terms _top_ and _last_ interchangeably to refer to the block with the greatest height on a given chain
* We use the term _local slot number_ to refer to the intra-epoch slot number that resets to 1 every epoch
* We use _global slot number_ to refer to the global slot number since genesis starting at 1

**Notations**
* `a⌢b` - Concatenation of `a` and `b`
* `x[i]` - Element `i` of array `x`, starting at index `0`
* `x[a..b]` - Slice of vector `x` containing elements from indexes `[a, b)`

# 1. Constants

These are the parameters Mina uses for Samasika

| Field | Value | Description |
| - | - | - |
| `delta`                         | `0`                     | Maximum permissable delay of packets (in slots after the current) |
| `k`                             | `290`                   | Point of finality (number of confirmations) |
| `slots_per_epoch`               | `7140`                  | Number of slots per epoch |
| `slots_duration`                | `180000` (= 3m)         | Slot duration in ms |
| `epoch_duration`                | `1285200000` (= 14d21h) | Duration of an epoch in ms |
| `genesis_state_timestamp`       | `1615939200000` (Mar 17, 2021 00:00:00 GMT+0000) | Timestamp of genesis block in unixtime |
| `acceptable_network_delay`      | `180000` (= 3m)         | Acceptable network delay in ms |
| `slots_per_sub_window`          | `7`                     | Slots per sub window (see [Section 3.2](#window-min-density)) |
| `sub_windows_per_window`        | `11`                    | Sub windows per window (see [Section 3.2](#window-min-density)) |

# 2. Structures

The main structures used in Mina consensus are as follows

## 2.1 Block

| Field                           | Type                               | Description |
| - | - | - |
| `version`                       | `u8` (= 0x01)                      | Block structure version |
| `protocol_state`                | `Protocol_state.Value.Stable.V1.t` | |
| `protocol_state_proof`          | `Proof.Stable.V1.t sexp_opaque` | |
| `staged_ledger_diff`            | `Staged_ledger_diff.Stable.V1.t` | |
| `delta_transition_chain_proof`  | `State_hash.Stable.V1.t * State_body_hash.Stable.V1.t list` | |
| `current_protocol_version`      | `Protocol_version.Stable.V1.t`        | |
| `proposed_protocol_version_opt` | `Protocol_version.Stable.V1.t option` | |

## 2.2 Protocol_state

This structure can be thought of like the block header.  It contains the most essential information of a block.

| Field                 | Type                     | Description |
| - | - | - |
| `version`             | `u8` (= 0x01)            | Block structure version      |
| `previous_state_hash` | `State_hash.Stable.V1.t` | Commitment to previous block |
| `body`                | `Protocol_state.Body.Value.Stable.V1` | The body of the protocol state |

### 2.2.1 Protocol_state.Body

| Field                 | Type                     | Description |
| - | - | - |
| `version`             | `u8` (= 0x01)            | Block structure version |
| `genesis_state_hash`  | `State_hash.Stable.V1.t` | Used for hardforks |
| `blockchain_state`    | `Blockchain_state.Value.Stable.V1.t` | |
| `consensus_state`     | `Consensus.Data.Consensus_state.Value.Stable.V1.t` | |
| `constants`           | `Protocol_constants_checked.Value.Stable.V1.t` | |

## 2.3 Consensus_state

This structure encapsulates the succinct state of the consensus protocol.  The stake distribution information is contained by the `staking_epoch_data` field.  Due to its succinct nature, Samasika cannot look back into the past to obtain ledger snapshots for the stake distribution.  Instead, Samasika implements a novel approach where the future stake distribution snapshot is prepared by the current consensus epoch.  Samasika prepares the past for the future!  This future state is stored in the `next_epoch_data` field.

| Field                                    | Type                     | Description |
| - | - | - |
| `version`                                | `u8` (= 0x01)            | Block structure version |
| `blockchain_length`                      | `Length.Stable.V1.t` | Height of block ? |
| `epoch_count`                            | `Length.Stable.V1.t` | Epoch number ? |
| `min_window_density`                     | `Length.Stable.V1.t` | Minimum windows density observed on this chain (see [Section 4.1](#chain-selection-rules)) |
| `sub_window_densities`                   | `Length.Stable.V1.t list` | Current sliding window of densities (see [Section 4.1](#chain-selection-rules)) |
| `last_vrf_output`                        | `Vrf.Output.Truncated.Stable.V1.t` | Additional VRS output from leader (for seeding Random Oracle) |
| `total_currency`                         | `Amount.Stable.V1.t` | Total supply of currency |
| `curr_global_slot`                       | `Global_slot.Stable.V1.t` | |
| `global_slot_since_genesis`              | `Mina_numbers.Global_slot.Stable.V1.t` | Claimed slot |
| `staking_epoch_data`                     | `Epoch_data.Staking_value_versioned.Value.Stable.V1.t` | Epoch data for previous epoch |
| `next_epoch_data`                        | `Epoch_data.Next_value_versioned.Value.Stable.V1.t` | Epoch data for current epoch |
| `has_ancestor_in_same_checkpoint_window` | `bool` | |
| `block_stake_winner`                     | `Public_key.Compressed.Stable.V1.t` | Compressed public key of winning account |
| `block_creator`                          | `Public_key.Compressed.Stable.V1.t` | Compressed public key of the block producer |
| `coinbase_receiver`                      | `Public_key.Compressed.Stable.V1.t` | Compresed public key of account receiving the block reward |
| `supercharge_coinbase`                   | `bool` | `true` if `block_stake_winner` has no locked tokens, `false` otherwise |

## 2.4 Epoch_data

| Field              | Type                     | Description |
| - | - | - |
| `version`          | `u8` (= 0x01)            | Block structure version |
| `ledger`           | `Epoch_ledger.Value.Stable.V1.t` | |
| `seed`             | `Epoch_seed.Stable.V1.t` | |
| `start_checkpoint` | `State_hash.Stable.V1.t` | State hash of _first block_ of epoch (see [Section 3.2](#decentralized-checkpointing))|
| `lock_checkpoint`  | `State_hash.Stable.V1.t` | State hash of _last known block in the first 2/3 of epoch_ (see [Section 3.2](#decentralized-checkpointing))|
| `epoch_length`     | `Length.Stable.V1.t` | |

# 3. Algorithms

This section outlines the main changes in Ouroboros Samasikia.

## 3.1 Chain Selection Rules

Samasika uses two consensus rules: one for *short-range forks* and one for *long-range forks*.

### 3.1.1 Short-range fork rule

This rule is triggered whenever the fork is such that the adversary has not yet had the opportunity to mutate the block density distribution.

```rust
Choose the longest chain
```

A fork is short-range if it occured less than `m` blocks ago.  The naı̈ve implemention of this rule is to always store the last `m` blocks, but for a succinct blockchain this is not desirable.  Mina Samasika adopts an approach that only requires information about two blocks.  The idea is a decentralized checkpointing algorithm, the details of which are given in [Section 3.2](#decentralized-checkpointing).

### 3.1.2 Long-range fork rule

Recall that when an adversary creates a long-range fork, over time it skews the leader selection distribution leading to a longer adversarial chain.  Initially the dishonest chain will have a lower density, but in time the adversary will work to increase it.  Thus, we can only rely on the density difference in the first few slots following the fork, the so-called *critical window*.  The idea is that in the critical window the honest chain the density is overwhelmingly likely to be higher because this contains the majority of stake.

As a succint blockchain, Mina does not have a chain into which it can look back on the fork point to observe the densities.  Moreover, the slot range of the desired densities cannot be know ahead of time.

Samasika overcomes this problem by tracking a moving window of slots over each chain and then storing only the *minimum* of all densities observed for each chain.  The intuition is that if the adversary manages to increase the density on the dishonest chain, the tracked minimum density still points to the critical window following the fork.

[Section 3.2](#window-min-density) specifies how the sliding windows are tracked and how the minimum density is computed.  For now, we assume that each chain contains the minimum window density and describe the long-range fork rule.

For succinctness the minimum window density is stored in each block.  Specifically, it is stored in the `min_window_density` field of the `Consensus_state` (see [Section 2.3](#consensus_state)).

The function [`getMinDen(C)`](#getminden) outputs the minimum chain density observed so far in chain `C`. In other words, it simply outputs the value of the `min_window_density` field of the top block of `C`.

Let `C1` be the local chain and `C2` be a [valid](#isValidChain) alternative chain; the _long-range fork rule_ is

```rust
if getMinDen(C2) > getMinDen(C1) {
    Select C2
}
else {
    Continue with C1
}
```

We specify the chain selection algorithm in more detail in [Section 3.3](#chain-selection-protocol).

## 3.2 Decentralized Checkpointing

<!--
; start_checkpoint: 'start_checkpoint
      (* The lock checkpoint is the hash of the latest state in the seed update range, not including
         the current state. *)
; lock_checkpoint: 'lock_checkpoint
-->

Samasika uses decentralized checkpointing to determine whether a fork is short- or long-range.  The idea is that each chain maintains two checkpoints in every epoch, which are used to estimate how long ago a fork has occured.

* **Start checkpoint** - First block of the epoch
* **Lock checkpoint** - Last known block in the first `2/3` of an epoch

```
epochs:         e1                e2                 e3
                                      ⤺lock
slots:  s1s2s3s4s5s6s7s8s9|s1s2s3s4s5s6s7s8s9|s1s2s3...
                     start⤻⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺
```

These are located in the `start_checkpoint` and `lock_checkpoint` fields of the [`Epoch_data`](#epoch_data) structure, which is part of the [`Consensus_state`](#consensus_state) (See [Section 2.4](#epoch_data)).

As time progresses away from the first slot of the current epoch, the lock checkpoint is pushed along with the last known block until we reach the last block in the first `2/3` of the epoch and it is _frozen_. ❄

A fork is considered _short-range_ if either

1. the fork point of the candidate chains are in the same epoch
2. or the fork point is in the previous epoch with the same `lock_checkpoint`

Since the leader selection distribution for the current epoch is computed by the end of the first `2/3` of the slots in the previous epoch, an adversarial fork after the previous epoch's `lock_checkpoint` cannot skewed the distribution for the remainder of that epoch, nor the current epoch.  Anything before the previous epoch's `lock_checkpoint` _long-range_ fork.

Since Mina is succinct this means that it must stored the checkpoints for the current epoch in addition to the checkpoints for the previous epoch.  This is why the [`Consensus_state`](#consensus_state) structure contains two `Epoch_data` fields: `staking_epoch_data` and `next_epoch_data`.  The former contains the checkpoints for the previous epoch and the latter contains that of the current epoch.


## 3.3 Window Min-density

This section describes how to compute the density windows and minimum density. Firstly we must define some terminology.

* We say a slot is _`filled`_ if it contains a valid non-orphaned block
* An `n-window` is a sequential list of slots s<sub>1</sub>,...,s<sub>n</sub> of length `n`
* The _`density`_ of a window is the number filled slots filled within it

The _`sliding window`_ is referred to as a `v`-shifting `w`-window and it characterisd by two parameters.

| Parameter | Description                                | Value |
| - | - | - |
| `v`       | Length by which the window shifts in slots (shift parameter) | [`slots_per_sub_window`](#constants) (= 7) |
| `w`       | Window length in slots                                       | [`slots_per_sub_window`](#constants)` * `[`sub_windows_per_window`](#constants) (= 7*11 = 77 slots) |

This is a `w`-long window that shifts `v`-slots at a time.  You can think of the `w`-length window as being comprised of `k` sub-windows (`sub_windows_per_window`), each of length `v` slots.  For the parameters given in the table above, the sliding window looks like this:

```
   |s1,...,s7|s8,...,s14| ... |s71,...,s77|
k:      1          2      ...      11
```
where `si` is slot `i`.

Samasika tracks the list of densities of the previous `k = 11` sub-windows and the current window density `dc`

```
                      |s1,...,s7|s8,...,s14| ... |s71,...,s77|s78,...
sub_window_densities:      d1        d2      ...       dk          dc
```

The value of `k` is defined by the [`sub_windows_per_window`](#constants) constant.

This list of window of densities is stored in each block, in the `sub_window_densities` field of the `Consensus_state` (see [Section 2.3](#consensus_state)).  This field is of type `Length.Stable.V1.t list` and because it must be written into blocks as part of the protocol, an implimentation MUST implement serialization for this type.

The values stored in `sub_window_densities` have this format.

| Index | Contents |
| - | - |
| `0` | Oldest window density |
| `...` | |
| `k - 1` | Previous window density |
| `k` | Current window density |

### 3.3.1 `isWindowStop`

This algorithm detects whether we have reached the end of a sub-window.  It is used to decide if we must perform a `v`-shift.  It takes as input the current local slot number `s`, the shift parameter `v` and outputs `true` if we have reached the end of a sub-window and `false` otherwise.

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

### 3.3.2 `shiftWindow`

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

## 3.4 Chain Selection Protocol

The chain selection protocol specifies how peers are required to apply the fork rules from the [Chain Selection Rules Section](#chain-selection-rules).  There are three main algorithms at work.

### 3.4.1 `getMinDen`

As mentioned in [Section 3.1.2]("#long-range-fork-rule") this function returns the current minimum density of a chain `C`.

```rust
fn getMinDen(C) -> density
{
    B = last block of C
    if B is genesis block then
        return 0
    else
        return min(B.protocol_state.body.consensus_state.sub_window_densities)
}
```

### 3.4.2 `isShortRange`

This algorithm determins if the fork of two chains is short-range or long-range.

```rust
fn isShortRange(C1,C2) -> bool
{
    B1 = last block of C1
    B2 = last block of C2
    if B1.staking_epoch_data.lock_checkpoint == B2.staking_epoch_data.lock_checkpoint {
        return true
    }
    else {
        return false
    }
}
```

### 3.4.3 `isValidChain`

```rust
fn isValidChain(C1) -> bool
{
}
```

### 3.4.4 `maxvalid-sc`

```rust
fn maxvalid-sc(Cl,Chains,k) -> Chain
{
}
```

### 3.4.5 `selectChain`

```rust
fn selectChain(Peer,Chains,k) -> ()
{
}
```

## 3.5 Genesis Initialization

### 3.5.1 `initCheckpoints`

This algorithm initializes the checkpoints for genesis block `G`

```rust
fn initCheckpoints(G) -> ()
{
    S = G.protocol_state.body.consensus_state
    state_hash = hash(latest state ϵ S.next_epoch_data.seed's update range) ?
    S.staking_epoch_data.lock_checkpoint = 0 (or empty hash?)
    S.staking_epoch_data.start_checkpoint = 0 ?
    S.next_epoch_data.start_checkpoint = state_hash ?
    S.next_epoch_data.lock_checkpoint =  state_hash ?
}
```

### 3.5.2 `initSubWindowDensities`

This algorithm initializes the sub-window densities for genesis block `G`

```rust
fn initSubWindowDensities(G) -> ()
{
    G.protocol_state.body.consensus_state.sub_window_densities = [0]
    G.protocol_state.body.consensus_state.min_window_density = ω ?
}
```

## 3.6 Staking Procedure

### 3.6.1 `updateCheckpoints`

This algorithm updates the checkpoints of the block being created as part of the staking procedure.  It inputs the parent block `P`, the current block `B` and updates `B`'s checkpoints according to the description in [Section 3.2](#decentralized-checkpointing).

```rust
fn updateCheckpoints(P, B) -> ()
{
    SP = P.protocol_state.body.consensus_state
    SB = B.protocol_state.body.consensus_state
    state_hash = hash(latest state ϵ SP.next_epoch_data.seed's update range) ?
    if SB.slot == 1 then // !? We need the local slot number ?!
        SB.next_epoch_data.start_checkpoint = state_hash

    if 1 ≤ SB.slot < 2/3*slots_duration {
        SB.next_epoch_data.lock_checkpoint = state_hash
    }
}
```
Specifically, if the slot (`SB.slot`) of the new block `B` is the start of a new epoch, then the `start_checkpoint` of the current epoch data (`next_epoch_data`) is updated to the state hash from the parent block `P`.  Next, if the the new block's slot is also within the first `2/3` of the slots in the epoch, then the `lock_checkpoint` of the current epoch data is also updated to the same value.
