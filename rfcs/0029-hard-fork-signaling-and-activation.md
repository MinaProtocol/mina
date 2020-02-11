## Summary
[summary]: #summary

This RFC summarizes the technical aspects of supporting hard forks on the protocol. Another RFC will be created for the governance aspects of performing hard forks. Prior to this RFC, there existed another RFC with a lengthy discussion attached to it (both in-person and online) which can be viewed [here](https://github.com/CodaProtocol/coda/pull/3990). Some content in this RFC is copied directly from this previous RFC word for word, so this RFC should be thought of as a re-adaptation of that RFC with a smaller scope and updates from offline discussions. The scope of this RFC is generally fixed to fully defining the work that must be done before mainnet in order to support hard forks in the future. Some definitions of further work on top of this are elided here (minifying the mainnet implementation), with a rationale included for the division of this work.

## Motivation
[motivation]: #motivation

Whenever we make a change to the protocol that changes the rules of consensus or the state transition system, the network must switch to the new system atomically, and on all nodes simultaneously. Changes of this sort include for example modifying the parameters of the parallel scan, making them dynamic, adding smart contracts, adding shielded transactions/accounts, modifying or replacing Codaborous, and many others.

Changes that do *not* require hard forks include changes to the network protocol but not the underlying state machine, and anything that doesn't affect other nodes. We may want to do a hard fork anyway in some of these situations to force users to upgrade, especially if the changes are not backwards compatible or are very important security improvements.

If a change of the first sort were not implemented atomically, there would an unintentional fork: nodes supporting the new version would generate and accept blocks with the new specification, and nodes not supporting it would generate and accept blocks with the old one. To prevent this, we need a mechanism to synchronize the protocol's collective decision to switch to a new fork, along with rules that prevent out of date clients from continuing to work on the newly forked blockchain.

## Detailed design
[detailed-design]: #detailed-design

# NOTE: This RFC is WIP, so the detailed design section is mostly just notes that need to be fleshed out. These notes are all artifacts of in-person discussions.

- we should mostly consider hard forks that transition within fairly compatible consensus mechanisms as special cases will always be needed for incompatible consensus mechanisms and will be different on a per case basis
- we will only implement the signaling and activation boilerplate before mainnet
  - we will add the internal mechanisms for migrating data structures and state as we need to
    - much of the code that is necessary to do this can be included in a soft fork
    - the mechanism needs tested before mainnet still
- we will maintain old accounts in the ledger and continue to support old transaction versions for as long as possible
  - an "upgrade" transaction can be made to move between account versions
    - these transactions would include snarks proving the upgrade transition
    - 1 transaction can represent multiple state transitions in upgrading
    - these transactions support the ability for the upgrade to be payed by a different account than the one being upgraded, thus preventing account deadlocks
- we will drain the scan state when snarks change
  - the old scan states can be filled with empty work in this special case to help more quickly drain the old snark work
  - we can asynchronously add new trees to the scan state which include the new snark alongside the old snark to avoid transaction downtime
    - the old blokchain snark would continue to be used for blocks until the final old scan state tree emits a proof, at which point the actual snark transition would occur
- having 1 frontier that spans 2 eras is fine, so long as the consensus mechanisms in the new era has a compatible view of finality
- changes to consensus selection across eras requires 3 different selection functions to be available during the era transition: selecting between two old blocks, selecting between two new blocks, and selecting between an old block and a new block

## Drawbacks
[drawbacks]: #drawbacks

TODO

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

TODO

in addition to arguments related to this RFC's decisions, this should also argue for why the work is split up the way it is

## Prior art
[prior-art]: #prior-art

As mentioned in the description of this RFC, [there was a previous RFC this is based off of](https://github.com/CodaProtocol/coda/pull/3990).

TODO: write some direct details about bitcoins implementation

ZCash implements hard forks without on-chain signaling by coupling binaries with unique CHAIN\_ID values which have associated expirations. Nodes will not continue operating after the expiration, and will only accept and work off of blocks which share the current CHAIN\_ID as is written into its binary. The governance and synchronization of performing a hard fork is done in a fairly centralized, off chain manner (in that the ZCash devs make a new binary available and send out notifications to their users to switch). ZCash also pauses transactions on the network 24 hours before the hard fork occurs. This is simple, but comes with issues related to centralization of governance and potential difficulties with rolling out emergency hard forks.
- [zcash/zcash#2286 (comment)](https://github.com/zcash/zcash/issues/2286#issuecomment-301625612)
- [zcash.readthedocs.io/en/latest/rtd\_pages/nu\_dev\_guide.html](zcash.readthedocs.io/en/latest/rtd_pages/nu_dev_guide.html)

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- what does ETH do for hard fork signaling?
  - if ETH does not check for a threshold of blocks hard fork signals before performing upgrades, perhaps we should not as well
