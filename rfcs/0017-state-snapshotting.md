## Summary
[summary]: #summary

This RFC provides information on taking snapshots of enough of state such that
we can resume proposer execution after a restart. These snapshots would give us
a mechanism for more quickly reproducing edge cases and errors as they arise.
Snapshots can be broken into three projects: Partial and full-offline snapshots
(covered here in detail), and full-online snapshots which is out-of-scope for
now. Partial snapshotting can be done first and in parallel with implementation
of transition frontier persistance to make the full-offline version much quicker
to implement afterwards.

## Motivation

[motivation]: #motivation

As stated above, snaphotting parts of our application state will give us a
mechanism for more quickly reproducing edge cases and errors as they arive.

There are several stages. Each of which provides a checkpoint that gives us
useful features.

[partial]: #partial
### Partial Snapshotting:

Snapshot enough state to be able to produce the immediate next transition (aka
proposing), and then halt.

Why is this useful? We've wasted a lot of time waiting for the network to reach
a certain failing block. This feature would save us time in the future. We can
also easily make unit tests around edge-cases we fix by saving snapshots of
those cases.

[full-offline]: #full-offline
### Full-offline Snapshotting

Snapshot enough state to recreate a full-node that can continue from the point
of the snapshot to produce more than just one more transition.

Why is this useful? Sometimes we need more context than the exact block that
fails. This would give us that context. For example, maybe we need to reproduce
a few transitions via our proposer before reproducing a bug.

[full-online]: #full-online
### Full-online Snapshotting

Snapshot enough state to recreate a full-node that can continue from the point
of the snapshot and can reconnect to a network of nodes. Sometimes we actually
do need this to reproduce certain classes of errors.

This task would require synchronizing state between nodes in a network and
would require a significant amount of effort until we finish implementing
genesis. This is out-of-scope for the near future, and out-of-scope in this RFC.

In the near term, we should complete both partial and full-offline snapshotting.

## Detailed design

[detailed-design]: #detailed-design

For each component, we need to:

a. Properly marshall/unmarshall/copy each piece of data.

b. Put the node into what is potentially a special state using the unmarshalled
snapshot data instead of the normal happy path of the application.

### Partial Snapshotting:

We can make a record with all the information we need to store called
`Snapshot.t`. The record will contain all the pieces of state called out below
in some form or another which will be determined in implementation or
described below.

Note that for the purposes of this RFC, snapshot efficiency is of no concern.
Optimizing for code-complexity and shorter implementation time is preferred. We
can revisit efficiency at a later point in time.

The following is what is believed to be an exhaustive list of the pieces of
state needed for partial snapshotting support:

1. Breadcrumb (protocol state + staged ledger)
2. Root snarked ledger (the database)
3. Consensus local state
4. The current time
5. `Coda_main`'s `Config.t`
6. Proposal Data
7. Transaction pool
8. Snark pool

When we want to start the node from the snapshot, we need to boot it into a
special state that will execute the proposer to generate the next state and
transition and then stall afterwards.

For marshalling and unmarshalling and copying the data:

* `bin_io`/`yojson` can be trivally used for (1), (3), (6)
* With small changes, `bin_io`/`yojson` can be used for (5), (7), (8)
* Snapshotting the database state (2) will be tricky: We'll want to copy the
folder that the RocksDB database is stored in, but can we do this safely without
closing the database? Will we have to worry about races, or since OCaml is
single-threaded (and our bindings to RocksDB is synchronous) are we safe here?
* To snapshot the current time (4) we can store unix time in millis

Note that the actual marshalling/unmarshalling of the data should be
high-enough up in our dependency graph to see the `Coda_main` config as well as
the particular consensus bits we need.

To load the snapshot record:

1. Check the following invariants:

* Snarked ledger hash is the merkle root of the snarked ledger
* Staged ledger hash is the merkle root of the staged ledger
* Current timestamp > the timestamp captured in the snapshot

2. Modify `coda_main` (via functors and not optcomp as we want to reuse the same
binary) to load from snapshot. We want to directly start the proposer, disable
the entire transition frontier system, and disable all listeners of the pipe the
proposer writes to.

3. We need to modify the proposing and consensus systems to take a time offset
from current time instead of using system time directly. We need this to ensure
VRFs and slots and epochs are the same each time.

4. We can save the config.mlh used to produce the binary in the
snapshotted data so we don't accidentally start a snapshot on a different build
profile. This seems desirable as we imagine it will be quite easy to make this
mistake and may waste a good amount of time while debugging. This can be done
by modify the `ppx_optcomp` library.

For implementation we can do the following tasks:

A. Root snarked ledger (database) copy

B. Partial snapshot record (binable)

C. Modifying `Coda_main` to load from snapshot

D. Support time offsetting

E. `Ppx_optcomp` change to ensure hash of contents

F. Test to ensure one transition is proposed successfully

Parallelism of tasks with rough approximations of length:

```
person1: A----------
person2: B---
person3:     C--------
person4: D---
person5: E--
person6:              F--
```

### Full-offline Snapshotting

This is an extension of partial snapshotting. In addition to all that is
required above:

The following is what is believed to be an exhaustive list of the pieces of
state needed for full-offline snapshotting:

1. Transition frontier + extensions

For marshalling and unmarshalling of the data:

We can rely on
[Transition Frontier Persistance](https://github.com/CodaProtocol/coda/pull/1779)
(which should be worked on in parallel of partial snapshotting above).

To load the snapshot record (in addition to the above):

1. We start transition router with this particular transition frontier +
extensions and disable all the pipes that trigger changes to the transition
frontier system.

2. We ensure that transaction snark work and transactions can be generated and
sent to this node (despite all network activity being disable).

For implementation we can do the following tasks:

A. All of partial snapshotting

B. Transition frontier persistance

C. Modifying transition router and other parts of the code to properly load
from snapshot

D. Test to ensure multiple transitions are proposed successfully with new txns
and snark works/proofs

Parallelism of tasks with rough approximations of length:

```
group1:  A----------
group2:  B----------
person1:            C-----
person2:                  D--
```

## Drawbacks
[drawbacks]: #drawbacks

* These tasks would take quite a bit of effort to complete
* The snapshotting system itself will be complex enough to have its own bugs

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

Alternatively, we could do something more quickly, but in a way that is much
less flexible by doing something like taking a heap snapshot at a certain time
and resuming from that point. We could even do this by snapshotting virtual
machine memory. Such an approach, is not too useful; however, as we can't easily
iterate on versions of the coda daemon while reusing the same snapshot, nor is
it easy to resume such a snapshot that is taken on a larger testnet.

The impact of not implementing this, is twofold (1) it takes us longer to
reproduce errors we run into while testing and (2) longer to iterate on those
error cases when we're actually fishing for a bug.

## Prior art
[prior-art]: #prior-art

I could not find any prior art in the Bitcoin space. It seems like pyethereum
and parity both support some form of state snapshotting to JSON. It's not clear
to me that this state captures enough of the information necessary to resume a
network from that point (and we can't dig through the source due to licensing
issues), but if it does, it's nice that they managed to use JSON for their
output format as it's cross-client compatible and easily consumable by other
tooling.

Some of the data we need to serialize would be a bit hard and slow if we put it
in JSON form -- but we can still build such other tooling in OCaml (maybe some
sort of visualization on the state if it becomes necessary while debugging).

## Unresolved questions
[unresolved-questions]: #unresolved-questions

We should implement [partial](#partial) and [full-offline](#full-offline)
snapshotting before merging this RFC and update the RFC as necessary if we hit
any edge cases we missed in the initial design discussion.

As stated above, [full-online](#full-online) snapshotting is out-of-scope.

In the future, we may want to build other tools as mentioned above that consume
this snapshot state, but we'll do that on an as-needed basis while debugging.

In the future, we may want to investigate a mechanism for quickly and
efficiently snapshotting so that we can pessimistically snapshot everywhere.

