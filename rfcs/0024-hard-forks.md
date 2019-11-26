## Summary
[summary]: #summary

This RFC describes a system for planning and enacting hard forks.

## Motivation

[motivation]: #motivation

Whenever we make a change to the protocol that changes the rules of consensus or
the state transition system, the network must switch to the new system
atomically, and on all nodes simultaneously. Changes of this sort include for
example modifying the parameters of the parallel scan, making them dynamic,
adding smart contracts, adding shielded transactions/accounts, modifying or
replacing Codaborous, and many others.

Changes that do *not* require hard forks include changes to the network
protocol but not the underlying state machine, and anything that doesn't affect
other nodes. We may want to do a hard fork anyway in some of these situations to
force users to upgrade, especially if the changes are not backwards compatible
or are very important security improvements.

If a change of the first sort were not implemented atomically and at a
coordinated time, there would an unintentional fork: nodes supporting the new
version would generate and accept blocks with the new specification, and nodes
not supporting it would generate and accept blocks with the old one. To prevent
this we plan the fork in advance, and make sure out of date clients stop working
if they are not updated in time.

## Detailed design

[detailed-design]: #detailed-design

I'll call a period of time where one state machine/consensus system is in force
an *era*, to make clear the distinction between them and protocol versions and
epochs. Era zero is the one that is in force at the launch of a network, era one
follows after the first hard fork, and so on. Transitions between eras occur at
a pre-specified time - all blocks with a global slot that begins at or after the
specified era start time and before the era end time will follow the consensus
rules of that era.

I'll separate the considerations in this RFC into "human" considerations and
"technical" ones. Human considerations refers to how the process should work for
us as we plan, test, and execute the forks. Technical considerations refers to
how the forks will be implemented in the client.

### Human considerations

There are two types of hard forks to consider, with different needs: upgrades,
and emergency fixes. Upgrades can and should be scheduled well in advance, while
emergency fixes may need to be deployed on the scale of days.

Upgrades will happen twice per year, on March 1st 00:00:00 UTC and October 1st
00:00:00 UTC. Clients that do not include support for a scheduled fork will
**halt all progress** at that slot. This ensures out of date clients don't
continue on a mostly dead and therefore vulnerable network. Client that do
support the upgrade will, of course, execute the transition at that time/slot.

Mistakes in hard forks can be very bad, but are not intrinsically more dangerous
than client upgrades. However, they are more dangerous in that nodes that do not
upgrade could end up on a dead fork without realizing it. TODO is an on-chain
signaling mechanism possible so clients can detect this condition?

Because mistakes may be catastrophic and upgrades may involve large changes,
this process is very conservative. The timeline will be as follows:

1. Beginning of previous era:
  * Discussion, design and implementation of features for next era begins. This
    can happen in parallel for different features, and should be mostly done
    before the finalization process begins.
1. Six weeks from era start:
  * A public testnet starts, forked off the mainnet at the current block. At
    this point it has no changes from the previous era, other than being
    segregated. This will be used as a dry-run for the upcoming fork. We may
    need to modify delegations in order to ensure sufficient stake is online.
  * Feature specification lock. All features proposed to go into this hard fork
    have been submitted to the RFC process. Everything submitted must have a
    working, tested implementation.
2. Five weeks from era start:
  * All proposals are accepted or rejected/pushed to the next era.
3. Four weeks from era start:
  * Testnet era advances and the new features begin the final burn-in test.
    Builds should be available implementing everything, at a "release candidate"
    level of quality.
  * The Coda team and general public monitor the testnet, use it, and try to
    break it.
4. Up until one week from era start:
  * For every issue we discover, if fixing it would require another hard fork we
    disable the associated feature unless the change is very simple. Disabling a
    feature requires starting a new era on the testnet. If fixing it is only a
    code change we're a little more lenient: if the fix is minor we make it and
    continue, if it's major we still drop the feature.
5. One week from era start:
  * Mainnet client builds that support the new era are released and all nodes
    are expected to upgrade. If no further intervention occurs the transition
    will proceed as planned.
  * No further changes are allowed. If a bug that should block era transition is
    found we delay the era start by another week, releasing new clients, and
    return to step 4.
6. Era start:
  * All changes are active on the mainnet and the burn-in testnet is retired.
    Pop the confetti.

For emergency fixes the procedure is much shorter. Anything that threatens
security of funds, network liveness, or consistency counts as an emergency. We
could also do emergency forks to revert thefts or loss of funds due to error,
as in Ethereum's [DAO fork](https://eips.ethereum.org/EIPS/eip-779), but whether
and when to do that is outside the scope of this RFC.

Timeline:
1. The underlying issue is discovered and documented. The Coda team decides an
   emergency hard fork is necessary.
2. We schedule the new era, for some time in the near future e.g. 48 hours from
   now. We release new client versions that halt after the scheduled era starts.
   This reduces the chance a client will be stuck on a dead network. If the fix
   is very simple we can skip this.
3. We write and test the fix, then release new builds, with the new era
   programmed in.
4. The new era begins.

### Technical considerations

#### Distinguishing blocks from different eras

#### Feature flags

#### Signaling support for the next era

#### Handling changes in types

##### Blocks + block components

##### Transactions and SNARKs

#### Parallel scan transitions

#### Checking blockchain SNARKs from prior eras


This is the technical portion of the RFC. Explain the design in sufficient detail that:

* Its interaction with other features is clear.
* It is reasonably clear how the feature would be implemented.
* Corner cases are dissected by example.

## Drawbacks
[drawbacks]: #drawbacks

Why should we *not* do this?

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

* Why is this design the best in the space of possible designs?
* What other designs have been considered and what is the rationale for not choosing them?
* What is the impact of not doing this?

## Prior art
[prior-art]: #prior-art

Discuss prior art, both the good and the bad, in relation to this proposal.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

* What parts of the design do you expect to resolve through the RFC process before this gets merged?
  * Is the upgrade process above too conservative? Not conservative enough? This
    depends to some extent on whether a good fork signaling mechanism is
    possible.
  * Do we want to do more than two upgrades per year? Are the dates acceptable?
* What parts of the design do you expect to resolve through the implementation of this feature before merge?
* What related issues do you consider out of scope for this RFC that could be addressed in the future independently of the solution that comes out of this RFC?
