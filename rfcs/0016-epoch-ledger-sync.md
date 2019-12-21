## Summary
[summary]: #summary

This RFC proposes and compares a number of methodologies for synchronizing and, in some cases, persisting the epoch ledgers for proof of stake consensus participation.

## Motivation
[motivation]: #motivation

When starting a proposer on an active network, we currently have no way to acquire epoch ledgers for the current state of the network. Right now, a proposer must wait 2 full epochs in order to record the necessary epoch ledgers in order to participate in consensus. This is suboptimal and increases our bootstrapping time so significantly that it likely breaks some of the assumptions of the Ouroboros papers and opens up new angles of attack on our network. Therefore, there needs to be someway to at least synchronize this information, acquiring it from other nodes on the network. Local persistence is also good for mitigating the need to synchronize when a node goes offline for a short period of time (< 1 epoch).

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- Is it ok to force non proposers to store the epoch ledgers as well? Snark workers and "lite" clients do not actually *need* this information in order to be active, only proposers. This requirement, in particular, will be cumbersome to "lite" clients running in the browser or on phones.
- Does anything stop nodes from just turning around and requesting this information from another node in the network? It could be foreseeable that someone who does not want to store and serve all of this information would just redispatch the requests to other nodes on the network and proxy those answers, bypassing the "forced participation" mechanism

## Detailed design
[detailed-design]: #detailed-design

There are a number of options for implementing this, ranging from least correct and shortest time to implement, to most correct but longest time to implement. This RFC is layed out this way as there have been some questions as to what the true, mainnet-ready implementation of this system should look like, or if it should even exist internal to the protocol at all. Let's begin by reviewing the problem at a high level, and then jumping into the various levels of implementation.

### General idea
[detailed-design-general-idea]: #detailed-design-general-idea

Epoch ledgers are "snapshot" at the beginning of each epoch. More specifically, the epoch ledger for some epoch `n` is the snarked ledger of the most recent block in epoch `n-1` (TODO: confirm with @evan). Within an epoch `n`, the ledger we want to calculate our VRF threshold from is the epoch ledger of epoch `n-1`. As such, we must keep two epoch ledgers around while participating in the protocol: The epoch ledger for epoch `n`, and the epoch ledger for epoch `n-1`, referred to as the `curr_epoch` and `last_epoch`, respectively. In a local context, the only information we care about from an epoch ledger is the total amount of currency in the ledger and the balance of any accounts our node can propose for (right now, the proposers account + its delegated accounts). However, in order to allow other nodes to synchronize the information they need, nodes will be forced to store the entire epoch ledger at both these points. When a node becomes active (is participating) and it finds that it does not have the necessary epoch ledger information to properly participate, it will request the `curr_epoch` and `last_epoch` epoch ledgers from its peers so that it can participate properly. A node can identify what the correct merkle hashes for these epoch ledgers should be by inspecting any protocol state within the `curr_epoch`.

#### Dumbest implementation (no persistence, high memory usage, high individual network answer size)
[detailed-design-dumbest-implementation]: #detailed-design-dumbest-implementation

The easiest (and dumbest) way to implement this is to just have each ledger be a full, in-memory copy of the ledger at that state in time, have no disk persistence, and request the entire serialized ledger from peers to synchronize. This will have a high memory usage as it will require us to store 2 complete in memory copies of the ledger. Since the entire serialized ledger is served up during synchronization, this method will also require nodes to potentially send large amounts of data over the network when responding to queries. Therefore, this option is not scalable at all. However, this option requires an absolute minimum amount of work and would work fine for small ledgers, it will just break our network when we have lots of accounts in our ledgers.

#### Dumb implementation (no persistence, high memory usage, low individual network answer size)
[detailed-design-dumb-implementation]: #detailed-design-dumb-implementation

A slightly better way to do this would be to keep the same memory model for representing the ledger, but using the sync ledger abstraction in order to synchronize the contents of the ledger. This would have the effect of splitting up the requests between multiple peers, where each individual answer will stay a reasonable size. It will likely take slightly longer to sync using this method on small networks, but on larger networks the sync ledger is likely to be faster since it works more like a torrent system. This has some increased difficulty in implementation, however, as there are no in memory ledger implementations currently hooked into the sync ledger. This option would scale a little better than the last one in the sense that it would still work with large numbers of accounts as long as nodes have enough ram to store the 2 ledger copies in memory. It's also a little more forward thinking as, when we implement the participation logic, the epoch ledger will likely mutate into a rolling target since each account will track an additional bit which needs to be synchronized across proposers, though it is unclear whether or not that would fit directly into the abstraction since different proposers on different forks will have differing views of that information.

#### Simple persistent implementation (persistence w/ high disk usage, lowest memory usage, low individual network answer size)
[detailed-design-simple-persistent-implementation]: #detailed-design-simple-persistent-implementation

Instead of keeping the full ledger copy in memory, we could keep on disk copies. Write speed is not a concern on epoch ledgers at all, and lookup speed a fairly unimportant as well since the information required locally from the ledger can be easily cached, so a node really only needs to lookup information in an epoch ledger when serving queries to other nodes on the network. Since the snarked ledger is already stored in RocksDB, it would be simple to just copy the entire database over to another location for the epoch ledger. This would also simplify the synchronization implementation as the persistent ledger is the version we already use with the sync ledger. However, there would be some concerns in ensuring we do this correctly. We need to make sure we can safely copy the ledger while we have an active RocksDB instance (I believe RocksDB already has support for this), and make sure that we write code that won't leak old epoch ledger onto the filesystem. In particular, care needs to be taken when booting up to ensure that you properly invalidate your old epoch ledgers if you need to sync to new ones.

#### Simple mask implementation (no persistence, medium memory usage, low individual network answer size)
[detailed-design-simple-mask-implementation]: #detailed-design-simple-mask-implementation

When storing epoch ledgers in memory, the memory footprint can be greatly reduced by using backwards chained masks. This would mean that we would only store the diff between each epoch ledger and the diff between the `curr_epoch` epoch ledger and the snarked ledger at the point of finality. There are two downsides here from an implementation perspective though: firstly, we will need to add support for backwards chained masks. This shouldn't be hard in theory, but the mask code has been notoriously difficult to modify correctly. Secondly, we will need to make the sync ledger work with a mask. This should be roughly the same amount of effort that is required for other in-memory ledger representations, though.

#### Persistent mask implementation (persistence w/ medium disk usage, (lowest or medium) memory usage, low individual network answer size)
[detailed-design-persistent-mask-implementation]: #detailed-design-persistent-mask-implementation

The most robust solution would be to use masks while persisting to the filesystem. This would require building out a persistent mask layer. If this route is taking, it is optional whether or not we want to even store the masks in memory, and that decision could be made based on whether or not we need the lookup performance (which we likely won't). However, this will mean that we have to perform more disk io whenever we update the root snarked ledger in the transition frontier (about 2-3x disk io per root snarked ledger mutations). This could be mitigated in some ways, but is mostly unavoidable if we choose to persist masks.

### Forced participation
[detailed-design-forced-participation]: #detailed-design-forced-participation

Participation in this mechanism will be enforced by punishing peers who fail to answer queries related to epoch ledger synchronization. This comes with a few potential future issues, which are detailed in the [unresolved questions section](#unresolved-questions).

## Drawbacks
[drawbacks]: #drawbacks

This overall approach has a number of drawbacks. For one, it enforces a hard requirement for nodes to store nearly 3x the data they would otherwise need to, and in that sense, is very wasteful. Furthermore, this information we are forcing all nodes to store has little benefit to each node directly, and therefore feels more like a burden of the protocol design than a necessity to correctness of the consensus mechanism. It also has implications on the scope of what "lite" clients need to store in order to participate, as well as snark workers and other "non-proposer" nodes. Some of the dumber options listed here will certainly need to be rewritten or upgraded in the future, so in that sense, our choice here could be taking an a decent amount of technical debt.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

An alternative to this would be to pull the responsiblity for providing this information out into a 3rd party service outside of the network protocol. If this was done, it would lift the need for every node to store this large amount of data locally and enable them to also synchronize more quickly as they would not need to download the entire epoch ledger but, rather, could just download the accounts and associated merkle proofs they are interested in evaluating VRFs for. However, this comes with a number of other issues, mostly related to high level concerns about the protocol's ability to maintain itself without external 3rd party services, and I cannot speak on those much as I cannot properly weight the implications.
