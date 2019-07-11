## Summary

The origin transition catchup design has performance issues. In
current implementation, we would always downloading a path/list of transitions
from peer's oldest transition[1] to the request transition.
If the request transition is in peer's frontier, then the minimum number of
transitions that transition catchup would request is k + 1 under current
implementation. This is not very efficient in a realistic setting where k is
~3000. The new design features
1) avoids requesting unnecessary transitions;
2) instead of having a monolithic request to download everything; try to
   download small pieces from different peers at the same time.

## Motivation

The new design would improve the efficiency of doing ledger catchup.

## Detailed design

Split ledger catchup into 2 phases:

1) * Instead of
       - requesting a path/list of transitions from peer's oldest transition to the requested transition,
       - requesting a merkle path/list from peer's oldest transition to the requested transition together with that oldest transition.
   
   * The merkle path/list contains a list of *state_body_hash*es as its
*proof_elem*s. Upon received the merkle_path/list, we could verify that the merkle path by first trying
to find the oldest transition in our frontier or root_history and then call
*Merkle_list.verify* on that merkle path. This would guarantee that the
peer didn't send us a list of garbage and it also guarantees that the
order is correct. And we could then reconstruct a list of *state_hash*es
from the list of *state_body_hash*es.[2] Using this list of *state_hash*es we
can find the missing transitions by repeated searching *state_hash*es until
we find one (the one we find is the closest ancestor in our transition
frontier).
   
2) Depending on the size of the list of the missing transitions, spawn one or
more parallel requests to get the missing transitions from peers. We could
verify the list of transitions that send by peer against the list of
state_hashes.

For trust system, I would describe different actions for the 2 phases described
above:
1) * If a peer isn't able to handle the request, we shouldn't decrease their
     trust score.
   * If the peer send us the a merkle path that doesn't pass verification we
     should flag the peer as **Violated_protocol**.
   
2) * If a peer isn't able to handle the request, we shouldn't decrease their
     trust score.
   * If a peer returns a list of transitions whose state_hashes are different
     from what we have, we should flag the peer as **Violate_protocol**.
   * If transitions returned by the peer don't pass verification or their
     proofs are invalid, we should decrease the peer's trust score accordingly.

## Drawbacks

The new design has the overhead of first downloading a merkle path. But this
overhead is negligible comparing to the overhead of downloading unnecessary
transitions.

## Unsolved questions

It's not very clear to me what's a reasonable size of the list of transition
that we should download in 1 request.

## Rationale

We currently have an almost stable testnet which is quite small. We are
moving toward the direction of solving the known performance issues that would
hinder us from scaling up to a more realistic setting.

The proposed design would do much better than the current in average case. Let's see some examples first:

In all of the following examples, let's assume **k** = 3000, **size of transition** = 1 kB, **size of state_body_hash** = 5 bytes, 

### Example 1

With block_window_duration to be 5 min and if a node is offline for 5 hours, assuming at least half of the slots are filled, we could safely say that it missed about 40 transitions.

After realizing it's disconnected with the network, it sends a ledger-catchup
request to some random peers.

* In current implementation, the peer would respond with ~2k=6000 transitions (could be off by 1 to 2 if new blocks are created during the same time), while we only need 40 transitions to do the catchup, the other 5960 transitions sent by peer are unnecessary. We would download 2k * **size of transition** = 6MB data in total.

* In proposed design, the peer would respond with 2k state_body_hash. By
looking at the hashes, we would realize that we only need 40 transitions, so
we send another request to download those 40 transitions. In this scenario we
would download 2k * **size of state_body_hash** + 40 * **size of transition** = 70kB
data in total.

### Example 2

let's assume this time the node is missing k transitions.

* In current implementation, we would download 6MB of data.
* In proposed design, we would download 3.04MB of data

### Example 3

let's assume a node is offline for a long time, and it's missing 2k-1 transitions (which
is the edger case between ledger-catchup and bootstrap).

* In current implementation, we would download 6MB of data.
* In proposed design, we would download 6.04 MB of data.

We can see that in this case, the proposed design would behave slightly worse than the current implementation.

### Analysis

In general, small number of missing transitions would cause huge performance improvement in the proposed design;
As the number of missing transitions grows larger, the performance of the proposed design would converge to the
performance of the current implementation.

In the above examples, I always set the transition size to 1kB, but in reality its size depends on how much
transactions are included in it. Larger transition size would make performance of current impelementation worse.

[1] Since transition frontier also store a list of past roots which is known
as root history, oldest transition could be the oldest transition in
root_history if root_history is not empty or oldest transition just refers to
the root if root history is empty.

[2] state_hash = H(previous_state_hash, state_body_hash), thus giving a root
transition and a list of state_body_hash we can compute a list of state_hash.
