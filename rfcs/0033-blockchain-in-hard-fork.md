## Summary
[summary]: #summary

We present alternatives for handling the blockchain in a hard fork. The focus is
on hard forks in response to a network failure, though the mechanisms may be
applicable in more general scenarios.

This RFC does not consider how the transaction SNARK and scan state are handled
in hard forks. There will be another RFC for those, and an RFC to describe
the entire hard fork plan.

## Motivation
[motivation]: #motivation

For the launch of the Coda main net, we wish to have a hard fork plan and implementation
in place, in case there's a network failure. One of the parts of such a plan
is how to update the blockchain.

## Summary description of alternatives
[summary-descriptions]: #summary-descriptions

After the fork, do one of these:

1. New genesis timestamp and genesis ledger; assert a new starting epoch and slot

2. Retain the original genesis timestamp, with no time offset, with rules to
    maintain chain strength

3. Retain the original genesis timestamp, use a time offset for new blocks

## Detailed description of alternatives
[detailed-descriptions]: #detailed-descriptions

Terminology:

 - pause point: the time of the last good block before a network failure;
    it's a chosen time

Alternative 1
=============

- choose a root and ledger at the pause point

- the initial epoch, slot are the special case of 0,0
   - otherwise, increment the slot from the pause point
   - provide as a compile-time parameter

- if we have a proof of the protocol state, provide that

- subsequent blocks may use different proof, verification keys

- force a software upgrade by bumping the protocol major version

Notes
-----

- nodes will bootstrap from the new genesis state

- time-locked accounts and transactions with expiration should continue
   to work, because they rely on global slot numbers, and the
   slot is incremented from the pause point

Issues
------

- what is the source of randomness (epoch seed) for the post-fork chain?

- is it acceptable to erase history (but we already have a succinct blockchain)

- specifically, is there unfairness to the chains discarded past the pause point

- what is allowed to change after the fork, with what effect:
   - protocol state structure
   - ledger structure/depth,
   - account structure
   - consensus constants

- do we have to maintain pre-, post-fork code/data structures to verify the new genesis state,
   ledger, and new blocks

- if there's no proof of the ledger, how to convince the world that the new genesis ledger and
   ledger are valid

Alternative 2
=============

- choose a root and ledger at a pause point

- nodes have a notion of "last fork time", an epoch-and-slot

- upon a fork, gossip a special block to update the last fork time is issued, also referring to the
   protocol state and proof at the pause point, and resetting the chain strength

- if items affecting keys, ledger hashes, and proofs haven't changed, a software upgrade may not be required;
   otherwise, force an upgrade

Issues
------

- there may be empty slots or even empty epochs between the pause point and the restart; the reset
   of the chain strength may be sufficient to handle the consequences

- could we provide a new genesis block and proof, instead of the special block

- As in Alternative (1), items may change after the fork, so there may be pre-, post-fork proofs, coda, data structures;
   each additional fork may introduce more complexity

- If the ledger/account structure changes, we won't have a proof for the post-fork state, also mentioned as
   an issue for Alternative (1)

- If the epoch, slot widths change, computations for epochs or slots may become more complex; subsequent forks may introduce
   more complexity
    - possible solution: a most-recent-fork timestamp (an earthly time, not the "last fork time") might be
       used for epoch and slot calculations

Alternative 3
=============

- as Alternative (2), except that a time offset is added to the special block
   - eliminates the empty slot/epoch issue

Issues
-----

- as in Alternative (2), except that the chain strength issue is resolved

Resolution
==========

After discussion in the PR associated with this RFC (#5019), there was
agreement of the acceptability of Alternative 2. There remains some concern
about the weakening of chain strength, but attacks based on that
weakening don't seem to open a plausible attack to an adversary.

In addition to the above description of Alternative 2, the discussion
proposed and accepted another feature, unsafety bits contained in the
protocol state, to indicate which parts of the protocol state may have
changed.

If no unsafe bits are set, the fork is safe, in the sense that the protocol
state may be proved with blockchain SNARKs in effect at the pause point.

If an unsafe bit is set, some component of the protocol state has changed,
so the protocol state cannot be proved. For example, the protocol state
contains a blockchain state, which includes a hash of a SNARKed ledger and
a hash of a staged ledger. If the structure of accounts changes, that will
affect both ledger hashes. Therefore, the protocol state might have
unsafe bits specifically for ledger hashes.

Unsafety bits indicate unsafety relative to the previous block on the chain.
Blocks produced after a block with some unsafety bits set will not have any
unsafety bits set, at least, not until the next hard fork.

## Drawbacks
[drawbacks]: #drawbacks

There's no compelling reason not to do this. We need to be prepared to
perform a hard fork if the main net fails.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

Unlike most RFCs, this RFC provides design alternatives, rather than proposing a particular
design.

## Prior art
[prior-art]: #prior-art

Echo Nolan created a branch, `rfc/hard-forks`, that was not merged
into the code base.  There is a section in the RFC there, "Technical
considerations", that mentions issues related to the blockchain.

The core technical idea for the blockchain in that RFC was to add `era
ids` in blocks corresponding to slot ranges. An era id denotes some
set of features, and the type system verifies feature flags for code
using such features. The blockchain SNARK verifies the era id in
blocks.

The alternatives presented here don't mention feature flags, but do
raise the possibility of pre- and post-fork code.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

See the issues for the alternatives presented in this
RFC. Undoubtedly, new issues will become apparent through
implementation and testing of any of the alternatives.
