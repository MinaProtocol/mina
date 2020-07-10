## Summary
[summary]: #summary

We describe how to handle the transaction SNARK scan state across hard forks.

## Motivation
[motivation]: #motivation

For the launch of the Coda main net, we wish to have a hard fork plan
and implementation in place, in case there's a network failure. One of
the parts of such a plan is how to update the transaction SNARK scan
state.

The scan state consists of an in-core binary tree of transactions and
proofs using the transaction SNARK. The work to produce those proofs,
provided by "SNARK workers", is computationally intensive, and paid for
by block producers. Therefore, it's desirable to use the information
in the scan state across forks, if possible.

## Detailed design
[detailed-design]: #detailed-design

For the blockchain, we distinguish between the "safe" case, where the
validity and structure of the protocol state do not change across the
fork, and the "unsafe" case, where that condition does not hold.

For the safe case, we can make use of the information in the scan
state at the pause point. Some nodes in the scan may have proofs,
while others await proofs.

Safe case
=========

Choosing a scan state; what to do with it
-----------------------------------------

Suppose we've chosen a root protocol state from a node at the pause
point. In that node's transition frontier, there is a breadcrumb
associated with that root, which contains a staged ledger with a scan
state. The hash of that staged ledger is contained in the root
protocol state (in the body's blockchain state).

Alternative: completing the scan state
--------------------------------------

Given the root scan state, it's possible to complete the proofs
offline to produce a new protocol state. An advantage would be that
the scan state would be empty after the fork, simpler in engineering
terms, and likely similar to what we'd do in the unsafe case. But the
proofs would be produced outside of the usual SNARK worker mechanism,
and so outside the view of the ordinary consensus mechanism, perhaps
lessening trust in the result. There would also need to be a tool to
complete the proofs, requiring additional engineering work.

If the scan state does not have a full complement of leaves, the
leaves can be padded with "dummy" transactions to assure that we
can propagate proofs up to the root.

The blockchain-in-hard-fork RFC mentions a "special block" that gets
gossipped to indicate a fork. In the case that we complete the scan
state, That block can contain a new protocol state and proof derived
from the new SNARKed ledger. We would need code similar to what's in
`Block_producer` for producing an ordinary block
(`External_transition`) to generate the special block, starting with
the chosen root protocol state.  When a node receives a special block,
it creates an empty scan state and empty pending coinbase.

Alternative: baking in the scan state
-------------------------------------

If we don't complete the scan state, we can persist the root
breadcrumb, and place it in the transition frontier when restarting
the network. This alternative requires some additional engineering to
save the breadcrumb, get it into the new binary, and load it. Those
tasks are relatively simple, though.

Rescuing transactions
---------------------

Both alternatives for the safe case make use of the root breadcrumb
across the fork, but we're explicitly discarding transactions in other
breadcrumbs.  We have transaction SNARK proofs for them, and it's
wasteful, and may be upsetting if those transactions are rolled back.

The other breadcrumbs in this node's transition frontier reflect a
particular view of a best tip; other nodes may have different best
tips. The node can query peers to get their transition frontier
breadcrumbs, and we can make such queries recursively to some or all
reachable nodes. From those breadcrumbs, we can calculate a
longest common prefix, which can be persisted, and placed
in the transition frontier after the fork.

Unsafe case
===========

In this case, the proofs in the scan state are not of consequence to
the post-fork chain. Those proofs are for transactions not yet
reflected in SNARKed ledger.

Alternative: discard the scan state
-----------------------------------

We can simply discard the scan state at the pause point. Both the
transactions and their proofs in the scan state are lost.

Discarding proofs in the scan state means also discarding the fee
transfers associated with them. Since these fee transfers have already
been applied to the staged ledger, we will have to discard the staged
ledger at the root, and when the chain resumes, using the SNARKed
ledger at the root as the staged ledger, and an empty scan state.  The
fees that would have accrued to SNARK workers for proofs, and the fees
for block producers, are not transferred. Operators should be made
aware of this fee-loss risk.

Discarding the staged ledger means that we're discarding the finalized
transactions reflected in that ledger. Also, the staged ledger hash
at the pause point is no longer valid, and needs to be recomputed
from the SNARKed ledger used as the staged ledger.

Although the unsafe case in a disaster should be a rare event,
rolling back otherwise-finalized transactions may be upsetting
to users.

Alternative: re-prove the scan state(s)
---------------------------------------

We could retain the scan state and staged ledger, by discarding the
original proofs, and generating new proofs.

The new proofs could be created online, by carrying over the scan
state, but with the proofs discarded, when the network resumes.

The new proofs could be created offline, to replace the existing
proofs.  This approach introduces some of the same distaste of
"behind-the-scenes" proving mentioned in the scan state completion for
the safe case.

Whether the new transaction proofs are created online or offline, the
fee transfers in the scan state would be retained, so that SNARK
workers who generated the original proofs will still get paid.

With the online approach, the scan state needs to be persisted, so
it can be used by the post-fork binary.

With the offline approach, we could also rescue transactions as described
above, but reprove those transactions contained in them to generate new
breadcrumbs to be saved and loaded to the transition frontier after
the fork.

Choices for mainnet
===================

For mainnet, we're focusing on the unsafe case. And for that case, the
engineering team's choice is to carry over the scan state, with proofs
removed, to the post-fork binary (the `online` case). The new proofs
can be provided without cost by O(1) or other altruistic parties.

## Drawbacks
[drawbacks]: #drawbacks

There's no compelling reason not to do this. We need to be prepared to
perform a hard fork if the main net fails.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

The alternatives and their rationales are described above.

## Prior art
[prior-art]: #prior-art

Echo Nolan created a hard fork RFC (branch `rfc/hard-forks`) that
describes an online process to drain the scan state in phases if
the SNARK changes. This approach may be especially suitable for planned forks.
In that case, we want to maintain suitable incentives as the fork time
approaches, so we'd like to avoid the possibility of discarding
proofs.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

Is it practical to download breadcrumbs, seeing how there's been
concern about the size of scan states?

If we do offline proving:

 - How long will it take to produce the needed proofs to finish off the
   scan state?  What's a reasonable time?

 - Would it be reasonable to pay SNARK workers to produce such proofs,
   either exclusively or in tandem with locally-generated proofs?

 - Will the world accept this approach?

How much of the current code used to produce a block can be reused to
produce a special block?
