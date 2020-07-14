## Summary
[summary]: #summary

This RFC explains how to a create a hard fork in response to a severe
failure in the Coda network. It draws on the strategies described
in earlier RFCs that describe handling of the blockchain
and scan state for hard forks.

## Motivation
[motivation]: #motivation

The Coda network may get to a state where the blockchain can no longer
make progress. Symptoms might include many blockchain forks, or
blocks not being added at all, or repeated crashes of nodes. To
continue, a hard fork of the blockchain can be created, using an
updated version of the Coda software.

## Detailed design
[detailed-design]: #detailed-design

When it becomes evident that the network is failing, the Coda
developers will perform the following tasks:

 - on some node, run a CLI command to persist enough state to re-start the
    network

 - run a tool to transform the persisted state into data needed for the
    Coda binary

 - create a new Coda binary with a new protocol version

 - notify node operators of the change, in a manner to be determined,
    and provide access to the new binary

To remedy the problems that led to a failure, the Coda software will
likely change in some significant way when the network is
restarted. Using a new protocol version, with a new major/minor or minor
version, will require node operators to upgrade their software.

CLI command to save state
-------------------------

The Coda developers will choose a node with a root to represent the
starting point of the hard fork. The choice of node is beyond the scope of
this RFC.

The CLI command can be in the `internal` group of commands, since
it's meant for use in extraordinary circumstances. A suggested
name is `save-hard-fork-data`. That command communicates with the
running node daemon via the daemon-RPC mechanism used in other
client commands.

Let `frontier` be the current transition frontier. When the CLI command
is run, the daemon saves the following data:

 - its root

   this is an instance of `Protocol_state.value`, retrievable via

	 ```ocaml
      let full = Transition_frontier.full_frontier frontier in
      let root = full.root in
	  root |> find_protocol_state
     ```

 - the SNARK proof for that root

   this is an instance of `Proof.t`, retrievable via

   ```ocaml
      let full = Transition_frontier.full_frontier frontier in
      let transition_with_hash,_ = Full_frontier.(root_data full).transition in
	  let transition = With_hash.data transition_with_hash in
	  transition.protocol_state_proof
   ```

 - the SNARKed ledger corresponding to the root

   this is an instance of `Coda_base.Ledger.Any_ledger.witness`, retrievable
    via

   ```ocaml
    let full = Transition_frontier.full_frontier frontier in
    full.root_ledger
   ```
   Note: There appears to be a mechanism in `Persistent_root` for saving the
   root ledger, but it appears only to store a ledger hash, and not the ledger itself.

 - two epoch ledgers

   there is pending PR #4115 which allows saving epoch ledgers to RocksDB databases

   which two epoch ledgers needed depends on whether the root is in the epoch current
     at the time of the network pause, or in the previous one:

	 - if the root is in the current epoch, the two ledgers needed are
	    `staking_epoch_snapshot` and `next_epoch_snapshot`, as in the PR
     - if the root is in the previous epoch, the two ledger needed are
        `staking_epoch_snapshot` and `previous_epoch_snapshot` (not implemented
	    in the PR)

 - the breadcrumb at the root

   this is an instance of `Breadcrumb.t`, retrievable via

   ```ocaml
     let full = Transition_frontier.full_frontier frontier in
	 let root = full.root in
     Full_frontier.find_exn full root
   ```
   The breadcrumb contains a validated block, and a staged ledger,
   which contains a scan state.

   As of this writing, there's no serialization code to fully capture a
   breadcrumb; that would have to be written.

 - optionally, a chain of breadcrumbs between the root and best tip

   over some reachable nodes, find the common prefix of breadcrumbs
   because the scan states contained in breadcrumbs can be large, do this
    computation lazily:
    - find a common prefix of breadcrumb hashes
	- obtain the breadcrumbs corresponding to those hashes from a
	   representative node
   N.B.: it is possible that there is no common prefix beyond the root breadcrumb

The in-memory values (that is, those other than the epoch ledgers) can
be serialized as JSON or S-expressions to some particular location,
say `recovery_data` in the Coda configuration directory. The epoch
ledgers can be copied to that same location.

Preparing the data for inclusion in a binary
--------------------------------------------

Operators should be able to install a new package containing a binary and
all data needed to join the resumed network.

The SNARKed ledger can be stored in serialized format, stored as a value
in a generated OCaml module, which can be loaded when creating the
full transition frontier:
```ocaml
 module Forked_ledger = struct
   let ledger = ... (* Bin_prot serialization *)
 end
```
The ledger can be passed as the `~root_ledger` argument to `Full_frontier.create`.

The epoch ledgers can be compiled into the binary, or, if epoch ledger
persistence is available, included as files from the install package.
In the latter case, the operator may need to copy the installed epoch
ledgers to the Coda config directory.

If the fork is safe, then like the SNARKed ledger, we can compile
the saved root breadcrumb into the binary. The breadcrumb data would be
passed in the `~root_data` argument to `Full_frontier.create`.

If provided, the breadcrumb chain can also be saved into the binary.
We'd use the chain it to populate the `table` part of the full frontier
(`Full_frontier.create` could be modified to accept a `table` argument).

It might be that the SNARKed ledger and breadcrumbs are too large to
include in the binary. In that case, we could provide serialized
versions of them, to be loaded on daemon startup.

Gossipping a hard fork block
----------------------------

When the hard fork occurs, a restarted daemon gossips a special block
containing a new hard fork time, an epoch and slot. The type
`Gossip_net.Latest.T.msg` can be updated with a new alternative, say
`Last_fork_time`. Like an ordinary block, the special block contains a
protocol state, to be verified by the blockchain SNARK. The unsafe
bits in an ordinary block are always `false`. In the special block,
some of those bits may be `true`.

In the case of a "safe" hard fork, where no unsafe bits are set, the
hard fork block contains the root protocol state we saved and its
proof. In the case of an unsafe hard fork, there can be a dummy proof.

Like an ordinary block, the special block contains a current protocol
version. In the safe case, the patch version may be updated. In the
unsafe case, the major version or minor versions must be updated,
forcing a software upgrade.

Currently, verifying the blockchain for ordinary blocks is done using `update`
in the functor `Blockchain_snark.Blockchain_snark_state.Make`,
which relies on a `Snark_transition.t` input derived from a block.
For a hard fork, we'd write a new function that verifies that
the protocol state is the same as the old state, except for
those pieces denoted by unsafe bits.

Nodes running the new software won't accept other blocks until
they've received the special block, and time has reached the
designated epoch and slot.

## Drawbacks
[drawbacks]: #drawbacks

In the best case, the network will run smoothly, making preparations
for a hard fork gratuitious, and the software unnecessarily
complex. That said, the cost of forgoing those preparations is high.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

This design is for hard forks made necessary by a network failure.

Other designs may be needed for planned hard forks, if we change
features of the protocol. For example, we can save a breadcrumb,
as in the safe fork case, but drain the scan state online after the fork,
so that existing proofs are used, before switching to a new transaction
SNARK. See the unmerged branch `rfc/hard-forks` for details. That way,
SNARK workers who may be aware of the planned fork will continue
to produce SNARKs, without risking lost fees when the planned fork occurs.

## Prior art
[prior-art]: #prior-art

See RFCs 0032 and 0033 for how to handle the blockchain and scan state across
hard forks.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

What unsafe bits are there in the protocol state, and what do
they denote?

Is saving and restoring a transition frontier best tip?

For the best tip, is it practical to download breadcrumbs, is there
too much data?

Will the network actually resume, if this plan is followed?

Will users trust the network after an unsafe fork?
