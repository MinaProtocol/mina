## Summary

This RFC describes the procedure to generate a genesis ledger from a
running network, using a node connected to that network.

## Motivation

The procedure described here is a part of the hard fork procedure,
which aims at spawning a new network, being a direct continuation of
the mainnet (or any other Mina network for that matter). To enable
this, the ledger of the old network must be exported in some form and
then fed into the newly created network. Because the new network's
initial state can be fed into nodes in a configuration file, it makes
sense to generate that file directly from the old node. Then necessary
updates can be made to it manually to update various protocol
constants, and then the new configuration file can be handed over to
node operators.

## Detailed design

The genesis ledger export is achieved using a GraphQL field named
`fork_config`. Asking for this field requires providing a slot or a
state hash of the block that we want to base the exported ledger on.
This field, if asked for, contains a new runtime configuration,
automatically updated with:

* the dump of the **staged ledger** as it was after the last block
before the slot where no more transactions were accepted
(transaction-stop slot). This ledger becomes the genesis ledger for
the new network
* updated values of `Fork_config`, i.e. previous state hash, previous
blockchain length and previous global slot.
* updated epoch data, in particular current and next epoch ledger and seed.

**IMPORTANT**: as of now the `genesis_ledger_timestamp` is **not**
being updated and must be manually set to the right value (which is at
the moment unknown).

Thus generated configuration can be saved to a file, modified if
needed and fed directly into a new node, running a different protocol
version, using `--config-file` flag. As of the moment of writing this,
`compatible` and `berkeley` branches' configuration files are
compatible with each other (see: [PR #13768](https://github.com/MinaProtocol/mina/pull/13768)).
Sadly since then that compatibility has been broken by [PR #14014](https://github.com/MinaProtocol/mina/pull/14014).
We need to either port this change back to `compatible` or create a
migration script which will adapt a `mainnet` config file to the
format required by `berkeley`. The former solution would probably
be better.

The `fork_config` field has been added to GraphQL in [PR
#13787](https://github.com/MinaProtocol/mina/pull/13787). It needs to
be extended to return the blockchain state for a given block (height
or state hash) so that we can export the desired ledger after the
blockchain has moved on.

## Drawbacks

This RFC provides a simple enough procedure to generate the genesis
ledger for the new network. However, it's not without its problems.

### File size

At the moment the mainnet has more than 100 000 accounts created.
Each account takes at least 4 lines in the configuration, which adds
up to around 600kB of JSON data. The daemon can take considerable time
at startup to parse it and load its contents into memory. If we move
on with this approach, it might be desirable to make a dedicated
effort to improving the configuration parsing speed, as these files
will only grow larger in subsequent hard forks. Alternatively, we
might want to devise a better (less verbose) storage mechanism for the
genesis ledger.

### Security concerns

The generated genesis ledger is prone to malevolent manual
modifications. Beyond containing the hash of the previous ledger, it's
unprotected from tampering with.

One way to improve this is to provide an external program, capable of
computing hash of the ledger as it will be after the config is loaded
into a node. Users will be able to obtain a raw fork config file from
their nodes. Later, given the official config for the new network,
they will be able to run the program against both files and compute
ledger hashes. The reason why this is needed is that the configuration
file will likely contain some manual updates. For instance the genesis
ledger timestamp will need to be updated manually when the start time
of the new network is known. Further changes may concern genesis
constants and other network configuration. All these changes should be
ignored during the hash computation and only the genesis ledger itself
should be taken into consideration. This way a user seeing that the
configuration file is not identical to the one they computed, still
does not contain any changes to the genesis ledger.

Further protection against tampering with the ledger we gain from the
fact that all the nodes must use the same one, or they'll be kicked
out from the network.

## Rationale and alternatives

The presented way of handling the ledger export is the simplest one
and the easiest to implement. The security concern indicated above
cannot be mitigated with any method currently available. In order to
overcome it, we would have to re-think the whole procedure and somehow
continue the existing network with the changed protocol instead of
creating a new one.

It seems reasonable to export the ledger in binary form instead, but
currently the node does not persist the staged ledger in any way that
could survive the existing node and could be loaded by another one.
Even if we had such a process, the encoding of the ledger would have
to be compatible between `compatible` and `berkeley`, which could be
difficult to maintain in any binary format.

Otherwise there's no reasonable alternative to the process described.

## Prior art

Some of the existing blockchains, like Tezos, deal with the protocol
upgrade problem, avoiding hard-forking entirely, and therefore
avoiding the ledger export in particular. They achieve it by careful
software design in which the protocol (containing in particular the
consensus mechanism and transaction logic) consists in a plugin to the
daemon, which can be loaded and unloaded at runtime. Thus the protocol
update is as simple as loading another plugin at runtime and does not
even require a node restart.

It would certainly be beneficial to Mina to implement a similar
solution, but this is obviously a huge amount of work (involving
redesigning the whole code base), which makes it infeasible for the
moment.

## Unresolved questions

The genesis timestamp of the new network needs to be specified in the
runtime configuration, but it is as of now (and will probably remain
for some time still) unknown. This makes it hard to put it into the
configuration in any automated fashion. Relying on personnel
performing the hard fork to update it is far from ideal, but there
seems to be no better solution available at the moment.

Also epoch seeds from mainnet are incompatible with those on berkeley.
When epoch ledgers are being exported from a compatible node and
transferred into a berkeley node, the latter cannot load them, because
Base58check fails to decode them. This is a problem we need to overcome
or decide that we won't export the epoch ledgers and assume they're
the same as the genesis ledger for the purpose of hard fork.
