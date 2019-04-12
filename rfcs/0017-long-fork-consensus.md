## Summary
[summary]: #summary

We currently do not support long forks. This means that to join the network you need a recent checkpoint, in other words to have always been online or to trust another party that has always been online.

This adds support for a client to join the network at any point of time, regardless of if its been online recently. It adds this safely under a [50% + epsilon] security assumption. It also includes a mechanism to restore a chain to strength if this assumption was to be temporarily violated.

This mechanism also does not require checkpointing at any time horizon, compared to alternatives.

## Motivation

[motivation]: #motivation

Its not realistic for clients to have always been online, and it is a poor trust model to require clients to find a trusted third party (high friction and not always feasible).

With this feature, clients will be able to join the network from any device at any time.

## Detailed design

[detailed-design]: #detailed-design

### Part 1: min-window

This version of the implementation is correct given that [50% + epsilon] of stake has always been participating and honest. 

* Add a new field to `protocol_state` called `min_window`, initally set to `8k`
* Add a new field to `protocol_state` called `current_window`, initially set to 0
* `let window_diff = FLOOR(current_protocol_state.slot_number/(8k)) - FLOOR(previous_protocol_state.slot_number/(8k))`
* if `window_diff == 0`
  * set `current_protocol_state.current_window` to `previous_protocol_state.current_window + 1`
* else if `window_diff == 1`
  * set `current_protocol_state.min_window` to `MIN(current_protocol_state.current_window, previous_protocol_state.min_window)`
  * set `current_protocol_state.current_window` to `1`
* else
  * set `current_protocol_state.min_window` to `0`
  * set `current_protocol_state.current_window` to `1`

Add to the chain select(A,B) function:

* If no checkpoints match between current and proposed, choose the chain with the greater `min_window`. If its a tie choose the already held chain.

The intuition is each `current_window` is a sample from a distribution parameterized by the chain's participation. `min-window` then will asymptote over time to a low percentile of the distruibution, which will always be large enough to differentiate between the honest chain and an adversary's. 

Consider this proof sketch, relying on Ouroboros Genesis. Consider an attacker trying to create a distant fork. Assume they were able to create a long fork with no low participation windows. If true the same attack would be possible in Ouroboros Genesis. However Ouroboros Genesis showed trying to make a distant fork would create a low participation region immediately after the fork was attempted. Therefore its not possible to create such a fork without a participation window significantly lower than the honest chain, and this method of chain selection is secure for distant forks.


### Part 2: min-window with voting

If the assumption that [50% + epsilon] of the stake has always been participating and honest is violated, at the point this happens safety will be compromised. We can add another feature to consensus to ensure that this temporary compromising will not become permanent.

* define a constant, `min_windows_length`
* define a constant, `min_window_period`
* define a constant, `inflation`
* add a new field to each account called `vote_hash`, initially set to `0`
* add a ring buffer to protocol state called `min_windows` initially set to `[1]*min_windows_length`
* add a new field to `protocol_state` called `tail_min_window` initially set to `1`
* add a new field to `protocol_state` called `min_window` initially set to `1`
* add a new field to `protocol_state` called `current_window` initially set to `0`
* add a new field to the staged ledger called `vote_stake` initially set to `0`
* add a new field to the staged ledger called `vote_hash` initially set to `0`

Add to transaction application logic:
* TODO

Add to the protocol state update logic:

* `let window_diff = FLOOR(current_protocol_state.slot_number/(8k)) - FLOOR(previous_protocol_state.slot_number/(8k))`
* if `window_diff == 0`
  * TODO
* if `window_diff == 1`
  * TODO
* else
  * TODO

* `let min_window_period_diff = FLOOR(current_protocol_state.slot_number/min_window_period) - FLOOR(previous_protocol_state.slot_number/min_window_period)`
* if `min_window_period_diff == 0`
  * TODO
* else if `min_window_period_diff == 1`
  * TODO
* else
  * TODO

* if the `snarked_ledger` is being updated
  * set `current_protocol_state.min_window` to `MAX(current_protocol_state.min_window, new_snarked_ledger.voted_stake/staged_ledger.total_stake)`
* else
  * do nothing

Add to the transaction accepting logic:

TODO vote triggering
Incentives discussion

## Drawbacks
[drawbacks]: #drawbacks

This will

* add more constraints to the snark
* new code will add (minor) complexity to consensus

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

Other designs considered were:

* Track unique stake participation each epoch, use recent unique stake participation as the long distance fork strength. This has the upside that its relatively simple, but the downside that it relies on assuming the number of staking parties is significantly less than the number of slots in an epoch. It also relies on annual checkpoints, which this verison does not require.
* min-window (Stage 1) with a "reset" mechanism that would generate new checkpoints. Has the upside again that its simple, but the downside that it would require consensus outside the protocol to agree on a checkpoint which would create a point for centralization.

## Prior art
[prior-art]: #prior-art

Prior art:

* [Ouroboros Genesis](https://eprint.iacr.org/2018/378.pdf)
* A writeup I made on the unique stake participation approach mentioned in alternatives
* Work by Vanishree analyzing the security of the unique stake participation approach

## Unresolved questions
[unresolved-questions]: #unresolved-questions

* security proof of min-window
* proof adding voting does not break min-window
* careful analysis of different scenarior where the 51% honesty assumption could be violated, what could play out, and operationally what different parties should plan to do
