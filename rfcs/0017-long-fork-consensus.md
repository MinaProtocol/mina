## Summary
[summary]: #summary

We currently do not support long forks. This means that to join the network you need a recent checkpoint, in other words to have always been online or to trust another party that has always been online.

This adds support for a client to join the network at any point of time, regardless of if its been online recently. It adds this safely under a [50% + epsilon] security assumption. It also includes a mechanism to restore a chain to strength if this assumption was to be temporarily violated.

This mechanism also does not require checkpointing at any time horizon, compared to alternatives.

## Motivation

[motivation]: #motivation

It's not realistic for clients to have always been online, and it is a poor trust model to require clients to find a trusted third party (high friction and not always feasible).

With this feature, clients will be able to join the network from any device at any time.

## Detailed design

[detailed-design]: #detailed-design

### Part 1: min-window

This version of the implementation is correct given that [50% + epsilon] of stake has always been participating and honest. 

* Add a new field to `protocol_state` called `min_window`, initally set to `8k`
* Add a new field to `protocol_state` called `current_window_length`, initially set to 0
* `let window_diff = FLOOR(current_protocol_state.global_slot_number/(28)) - FLOOR(previous_protocol_state.global_slot_number/(8k))`
* if `window_diff == 0`
  * set `current_protocol_state.current_window_length` to `previous_protocol_state.current_window_length + 1`
* else if `window_iff == 1`
  * set `current_protocol_state.min_window` to `MIN(current_protocol_state.current_window_length, previous_protocol_state.min_window)`
  * set `current_protocol_state.current_window_length` to `1`
* else
  * set `current_protocol_state.min_window` to `0`
  * set `current_protocol_state.current_window_length` to `1`

Add to the chain select(A,B) function:

* If the previous-epoch checkpoint does not match between current and proposed, choose the chain with the greater `min_`. If its a tie choose the already held chain.

The intuition is each `current_window_length` is a sample from a distribution parameterized by the chain's participation. `min-window` then will asymptote over time to a low percentile of the distruibution, which will always be large enough to differentiate between the honest chain and an adversary's. 

Consider this proof sketch, relying on Ouroboros Genesis. Consider an attacker trying to create a distant fork. Assume they were able to create a long fork with no low participation windows. If true the same attack would be possible in Ouroboros Genesis. However Ouroboros Genesis showed trying to make a distant fork would create a low participation region immediately after the fork was attempted. Therefore its not possible to create such a fork without a participation window significantly lower than the honest chain, and this method of chain selection is secure for distant forks.

### Part 2: Recovery via Reset Hash

If the assumption that [50% + epsilon] of the stake has always been participating and honest is violated, at the point this happens safety will be compromised. The `min_window` will be a low value susceptible to attack.

How susceptible depends on the `min_window`. (see unresolved questions for converting `min_window` to an estimate). For example a `min_window` corresponding to 40% total participation will be susceptible to a 20% attack.

This could happen for a variety of reasons including:

* network outage
* client software outage (via bug or attack)

(Note too that these are because ouroboros requires a synchronous network)

When this happens we can recover in the following way:

* add a new field to `protocol_state` called `reset_hash`, initially set to `0`
* add to client software a field called `expected_reset_hash`, initially set to `0`
* when deciding whether to accept a protocol state, check that `client.expected_reset_hash = protocol_state.reset_hash`
* when creating a new `protocol_state`, if the `client.expected_reset_hash` does not equal the previous protocol states' `reset_hash`, update the `reset_hash` in the new protocol state to `client.expected_reset_hash`.
* Add to the `protocol_state` update logic that if the `reset_hash` has been updated, reset `min_window` to `1`
* Add the `reset_hash` value to the VRF evaluation

If an outage occurs and a recovery is necessary, the community will choose a hash, and clients will have to manually tell their clients the new `expected_reset_hash`.

### Past 3: Recovery via Voting

Recovery via `reset_hash` as mentioned above requires centralized coordination and a manual update. This can be improved by allowing parties to create a `recovery_snark` proving `> 50%` of stake voted for a reset to a new `reset_hash`. That way, once the recovery proof is produced, all clients can update to the new `reset_hash` automatically.

## Drawbacks
[drawbacks]: #drawbacks

This will

* add more constraints to the snark
* new code will add (minor) complexity to consensus

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

Other designs considered were:

* On-chain recovery. This is harder to analyze for correctness, particularly for forks stealing the vote transactions. It also requires referring to the protocol state from within the staged ledger which is not supported yet.

## Prior art
[prior-art]: #prior-art

Prior art:

* [Ouroboros Genesis](https://eprint.iacr.org/2018/378.pdf)
* A writeup I made on the unique stake participation approach mentioned in alternatives
* Work by Vanishree analyzing the security of the unique stake participation approach

## Unresolved questions
[unresolved-questions]: #unresolved-questions

* security proof of `min_window`
* conversion of `window_length` to percent participating for the purpose of calculating when the chain can no longer be trusted and a recovery should occur
* proof adding recovery does not break min-window
* proof that an adversary cannot reuse a recovery to create a fork
* careful analysis recovery under different scenarios where the 51% honesty assumption could be violated, what could play out, and operationally what different parties should plan to do
