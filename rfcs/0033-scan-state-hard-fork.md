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
validity and structure of the protocol state remains valid across the
fork, and the "unsafe" case, where that condition does not hold.

For the unsafe case, the proofs in the scan state are not of
consequence to the post-fork chain. Those proofs are for transactions
not yet reflected in SNARKed ledger. There are two ways in which
we might handle the scan state when the chain is resumed.

One way is to simply discard the scan state at the pause point.  The
regrettable consequence is that the proofs are lost, and the fees paid
to create them are for nought. Block producers should be made aware of
this risk.

Discarding proofs in the scan state means also discarding the
fee transfers associated with them. Since these fee transfers have
already been applied to the staged ledger, we will have to discard the
staged ledger at the root, and when the chain resumes, using the
SNARKed ledger at the root as the staged ledger, and an empty scan state.

Discarding the staged ledger means that we're discarding the finalized
transactions reflected in that ledger. Also, the staged ledger hash
at the pause point is no longer valid, and needs to be recomputed
from the SNARKed ledger used as the staged ledger. The total currency in the
consensus data part of the protocol state becomes invalid, and would
need to be recomputed by summing the account balances in that SNARKed
ledger.

Alternatively, we could retain the scan state, and staged ledger,
while retaining the total currency amount, by generating new proofs
to replace the existing proofs. The fee transfers in the scan state
would be retained in that way, so that SNARK workers who generated
the original proofs will still get paid.

For the safe case, we can make use of the information in the scan
state at the pause point. Some nodes in the scan may have proofs,
while others await proofs. We can compute all needed proofs until
there's a proof at the root of the scan state. That proof corresponds
to a new SNARKed ledger that reflects all the transactions in the scan
state.

If the scan state does not have a full complement of leaves, the
leaves can be padded with "dummy" transactions to assure that we
can propagate proofs up to the root.

The blockchain-in-hard-fork RFC mentions a "special block" that gets
gossipped to indicate a fork. That fork can contain a new protocol
state and proof derived from the new SNARKed ledger. We would need
code similar to what's in `Block_producer` for producing an ordinary
block (`External_transition`) to generate the special block, starting
with the chosen root protocol state.  When a node receives a special
block, it creates an empty scan state and empty pending coinbase.
Because the transactions in the scan state come from blocks already
gossipped, the special block does not need to mention them.

We'll likely need to persist the scan state for use by a utility that
can generate the needed proofs, offline.

## Drawbacks
[drawbacks]: #drawbacks

There's no compelling reason not to do this. We need to be prepared to
perform a hard fork if the main net fails.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

The design described has the allure of starting with an empty scan
state for every hard fork. We could instead gossip a saved scan
state, but that can be gigabytes of data.

## Prior art
[prior-art]: #prior-art

Echo Nolan created a hard fork RFC (branch rfc/hard-forks) that
describes an online process to drain the scan state in phases, using
purchased SNARKs.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

How long will it take to produce the needed proofs to drain the scan state?
What's a reasonable time?

Would it be reasonable to pay SNARK workers to produce such proofs,
either exclusively or in tandem with locally-generated proofs?

How much of the current code used to produce a block can be reused to
produce a special block?
