# Consensus

Mina uses [Ouroboros Samasika](https://eprint.iacr.org/2020/352.pdf) for consensus.  This documents specifies the protocol and related structures.

**Table of Contents**
* [1 Constants](#constants)
* [2 Structures](#structures)
  * [2.1 Block](#block)
  * [2.2 Protocol_state](#protocol_state)
  * [2.3 Consensus_state](#consensus_state)
  * [2.4 Epoch_data](#epoch_data)
* [3 Algorithms](#algorithms)
  * [3.1 Chain Selection Rules](#chain-selection-rules)
    * [3.1.1 Short-range](#short-range-fork-rule)
    * [3.1.2 Long-range](#long-range-fork-rule)
  * [3.2 Window Min-density](#window-min-density)
  * [3.3 Chain Selection Protocol](#chain-selection-protocol)
  * [3.4 Genesis Initialization](#genesis-initialization)
  * [3.5 Staking Procedure](#staking-procedure)

**Conventions**
* We use the terms _top_ and _last_ interchangeably to refer to the block with the greatest height on a given chain

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
| `staking_epoch_data`                     | `Epoch_data.Staking_value_versioned.Value.Stable.V1.t` | |
| `next_epoch_data`                        | `Epoch_data.Next_value_versioned.Value.Stable.V1.t` | |
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
| `start_checkpoint` | `State_hash.Stable.V1.t` | |
| `lock_checkpoint`  | `State_hash.Stable.V1.t` | |
| `epoch_length`     | `Length.Stable.V1.t` | |

# 3. Algorithms

This section outlines the main changes in Ouroboros Samasikia.

## 3.1 Chain Selection Rules

Samasika uses two consensus rules: one for *short-range forks* and one for *long-range forks*.

### 3.1.1 Short-range fork rule

This rule is triggered whenever the fork is such that the adversary has not yet had the opportunity to mutate the block density distribution.

> `Choose the longest chain`

### 3.1.2 Long-range fork rule

Recall that when an adversary creates a long-range fork, over time it skews the leader selection distribution leading to a longer adversarial chain.  Initially the dishonest chain will have a lower density, but in time the adversary will work to increase it.  Thus, we can only rely on the density difference in the first few slots following the fork, the so-called *critical window*.  The idea is that in the critical window the honest chain the density is overwhelmingly likely to be higher because this contains the majority of stake.

As a succint blockchain, Mina does not have a chain into which it can look back on the fork point to observe the densities.  Moreover, the slot range of the desired densities cannot be know ahead of time.

Samasika overcomes this problem by tracking a moving window of slots over each chain and then storing only the *minimum* of all densities observed for each chain.  The intuition is that if the adversary manages to increase the density on the dishonest chain, the tracked minimum density still points to the critical window following the fork.

[Section 3.2](#window-min-density) specifies how the sliding windows are tracked and how the minimum density is computed.  For now, we assume that each chain contains the minimum window density and describe the long-range fork rule.

For succinctness the minimum window density is stored in each block.  Specifically, it is stored in the `min_window_density` field of the `Consensus_state` (see [Section 2.3](#consensus_state)).

The function [`getMinDen(C)`](#getminden) outputs the minimum chain density observed so far in chain `C`. In other words, it simply outputs the value of the `min_window_density` field of the top block of `C`.

Let `C1` be the local chain and `C2` be a [valid](#isValidChain) alternative chain; the _long-range fork rule_ is

>```bash
if getMinDen(C2) > getMinDen(C1) then
    Select C2
else
    Continue with C1

We specify the chain selection algorithm in more detail in [Section 3.3](#chain-selection-protocol).

## 3.2 Window Min-density

This section describes how to compute the density windows and minimum density. Firstly we must define some terminology.

* We say a slot is _`filled`_ if it contains a valid non-orphaned block
* An `n-window` is a sequential list of slots s<sub>1</sub>,...,s<sub>n</sub> of length `n`
* The density of a window, `density(W)`, is the number of slots filled in window `W`

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

Samasika tracks the list of densities of the previous `k` sub-windows and the current window density `dc`

```
                      |s1,...,s7|s8,...,s14| ... |s71,...,s77|s78,...
sub_window_densities:      d1        d2      ...       dk          dc
```

This list of window of densities is stored in each block, in the `sub_window_densities` field of the `Consensus_state` (see [Section 2.3](#consensus_state)).  This field is of type `Length.Stable.V1.t list` and because it must be written into blocks as part of the protocol, all implimentations of Mina will at least require serialization for this type.

The values stored in `sub_window_densities` have this format.

| Index | Contents |
| - | - |
| `0` | Oldest window density |
| `...` | |
| `k - 1` | Previous window density |
| `k` | Current window density |

### 3.2.1 `isWindowStop`

>```rust
fn isWindowStop(sl,v) -> bool
{
}

### 3.2.2 `shiftWindow`

<!-- This algorithm is responsible for shifting the sliding window.  It inputs the sliding window `W` = [d<sub>1</sub>,...,d<sub>w</sub>] and the current sub window densities `Curr` = [d<sub>w+1</sub>,...,d<sub>w+v</sub>] and then outputs the result `W'` = [d<sub>1+v</sub>,...,d<sub>w+v</sub>], where `v` is the shift parameter. -->

This algorithm is responsible for shifting the sliding window.  It inputs the sub-window densities `D` = [d<sub>0</sub>,...,d<sub>k</sub>] and then outputs the result `D'` = [d<sub>1</sub>,...,d<sub>k</sub>].

>```rust
fn shiftWindow(D) -> D'
{
    return D[1..]
}

## 3.3 Chain Selection Protocol

The chain selection protocol specifies how peers are required to apply the fork rules from the [Chain Selection Rules Section](#chain-selection-rules).  There are three main algorithms at work.

### 3.3.1 `getMinDen`

>```rust
fn getMinDen(C) -> length?
{
    B := last block of C
    if B is genesis block then
        return 0
    else
        return min(B.protocol_state.body.consensus_state.sub_window_densities)
}

### 3.3.2 `isShortRange`

>```rust
fn isShortRange(C1,C2) -> bool
{
}

### 3.3.3 `isValidChain`

>```rust
fn isValidChain(C1) -> bool
{
}

### 3.3.4 `maxvalid-sc`

>```rust
fn maxvalid-sc(Cl,Chains,k) -> Chain
{
}


### 3.3.5 `selectChain`

>```rust
fn selectChain(Peer,Chains,k) -> ()
{
}

## 3.4 Genesis Initialization

## 3.5 Staking Procedure
