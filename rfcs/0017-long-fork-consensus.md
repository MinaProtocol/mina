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

### Part 1: min-epoch

This version of the implementation is correct given that [50% + epsilon] of stake has always been participating and honest. 

* Add a new field to `protocol_state` called `min_epoch`, initally set to `24k`
* Add a new field to `protocol_state` called `current_epoch`, initially set to 0
* `let epoch_diff = FLOOR(current_protocol_state.global_slot_number/(24k)) - FLOOR(previous_protocol_state.global_slot_number/(24k))`
* if `epoch_diff == 0`
  * set `current_protocol_state.current_epoch` to `previous_protocol_state.current_epoch + 1`
* else if `epoch_diff == 1`
  * set `current_protocol_state.min_epoch` to `MIN(current_protocol_state.current_epoch, previous_protocol_state.min_epoch)`
  * set `current_protocol_state.current_epoch` to `1`
* else
  * set `current_protocol_state.min_epoch` to `0`
  * set `current_protocol_state.current_epoch` to `1`

Add to the chain select(A,B) function:

* If the previous-epoch checkpoint does not match between current and proposed, choose the chain with the greater `min_epoch`. If its a tie choose the already held chain.

The intuition is each `current_epoch` is a sample from a distribution parameterized by the chain's participation. `min-epoch` then will asymptote over time to a low percentile of the distruibution, which will always be large enough to differentiate between the honest chain and an adversary's. 

Consider this proof sketch, relying on Ouroboros Genesis. Consider an attacker trying to create a distant fork. Assume they were able to create a long fork with no low participation epochs. If true the same attack would be possible in Ouroboros Genesis. However Ouroboros Genesis showed trying to make a distant fork would create a low participation region immediately after the fork was attempted. Therefore its not possible to create such a fork without a participation epoch significantly lower than the honest chain, and this method of chain selection is secure for distant forks.


### Part 2: min-epoch with voting

If the assumption that [50% + epsilon] of the stake has always been participating and honest is violated, at the point this happens safety will be compromised. We can add another feature to consensus to ensure that this temporary compromising will not become permanent.

* define a constant, `min_epochs_length`
* define a constant, `min_epoch_period`
* define a constant, `inflation`
* add the following fields:
  * to each account
    * `vote_hash` initially set to `0`
  * to protocol state
    * `min_epochs`, a ring buffer initially set to `[1]*min_epochs_length`
    * `tail_min_epoch` initially set to `1`
    * `min_epoch` initially set to `1`
    * `current_epoch` initially set to `0`
  * to ledger state
    * `vote_stake` initially set to `0`
    * `vote_hash` initially set to `0`
  * to transactions
    * `vote_hash`

Add to transaction application logic:
```
if transaction.vote_hash == staged_ledger.vote_hash
  staged_leger_.vote_stake += get_ledger_of_hash(staged_ledger.vote_hash).stake_of(transaction.public_key)
else
  staged_leger_.vote_stake = 0
  staged_ledger.vote_hash = transaction.vote_hash
```

Add to the protocol state update logic:

* `let epoch_diff = FLOOR(current_protocol_state.global_slot_number/(24k)) - FLOOR(previous_protocol_state.global_slot_number/(24k))`
* if `epoch_diff == 0`
  * set `current_protocol_state.current_epoch` to `previous_protocol_state.current_epoch + 1`
* if `epoch_diff == 1`
  * set `current_protocol_state.min_epoch` to `MIN(current_protocol_state.current_epoch, previous_protocol_state.min_epoch)`
  * set `current_protocol_state.current_epoch` to `1`
* else
  * set `current_protocol_state.min_epoch` to `0`
  * set `current_protocol_state.current_epoch` to `1`

* `let min_epoch_period_diff = FLOOR(current_protocol_state.global_slot_number/min_epoch_period) - FLOOR(previous_protocol_state.global_slot_number/min_epoch_period)`
* if `min_epoch_period_diff == 0`
  * set most recent `current_protocol_state.min_epochs` to `MIN(most recent current_protocol_state.min_epochs, current_protocol_state.min_epoch)`
* else if `min_epoch_period_diff == 1`
  * push `current_protocol_state.min_epoch` to `current_protocol_state.min_epochs`
  * set `current_protocol_state.tail_min_epochs` to `MIN(pop current_protocol_state.min_epochs, current_protocol_state.tail_min_epochs)`
* else
  * push `0` to `current_protocol_state.min_epochs`
  * set `current_protocol_state.tail_min_epochs` to `MIN(pop current_protocol_state.min_epochs, current_protocol_state.tail_min_epochs)`

* if the `snarked_ledger` is being updated
  * `if new_snarked_ledger.vote_hash == new_protocol_state.last_epoch_locked_checkpoint`
    * set `current_protocol_state.min_epoch` to `MAX(current_protocol_state.min_epoch, new_snarked_ledger.voted_stake/staged_ledger.total_stake)`
* else
  * do nothing

Add to the transaction accepting logic:
* if in the first 2/3 of an epoch
  * only accept a transaction to the staged ledger if its `transaction.vote_hash` matches the previous epoch locked hash

Add to the protocol state accepting logic
  * for updates in the first 2/3 slots of the epoch, only accept a new protocol state if all transactions included follow the above transaction accepting logic

Vote triggering
  * TODO

Incentives discussion
  * TODO

## Drawbacks
[drawbacks]: #drawbacks

This will

* add more constraints to the snark
* new code will add (minor) complexity to consensus

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

Other designs considered were:

* Track unique stake participation each epoch, use recent unique stake participation as the long distance fork strength. This has the upside that its relatively simple, but the downside that it relies on assuming the number of staking parties is significantly less than the number of slots in an epoch. It also relies on annual checkpoints, which this verison does not require.
* min-epoch (Stage 1) with a "reset" mechanism that would generate new checkpoints. Has the upside again that its simple, but the downside that it would require consensus outside the protocol to agree on a checkpoint which would create a point for centralization.

## Prior art
[prior-art]: #prior-art

Prior art:

* [Ouroboros Genesis](https://eprint.iacr.org/2018/378.pdf)
* A writeup I made on the unique stake participation approach mentioned in alternatives
* Work by Vanishree analyzing the security of the unique stake participation approach

## Unresolved questions
[unresolved-questions]: #unresolved-questions

* security proof of min-epoch
* proof adding voting does not break min-epoch
* careful analysis of different scenarior where the 51% honesty assumption could be violated, what could play out, and operationally what different parties should plan to do
