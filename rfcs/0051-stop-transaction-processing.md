# Stop processing transactions / stop the network after a certain slot

This PR describes the feature to stop processing transactions and to stop the
network after a certain slot, to be used in the Berkeley hard fork.

## Summary

Transactions come from a client or the gossip network and are processed by BPs
and SNARK workers to be included in blocks. These blocks are propagated through
the network and validated by other participants.

In this RFC, the procedure to stop processing any new transactions and to
stop the network after a certain slot is described. This is, we define two
slots: the first one is the slot after which any blocks produced will include no
transaction at all and no fee payments, and the second one is the slot after
which no blocks are produced and blocks received are rejected.

## Motivation

In a hard fork scenario, we want to halt the preceding network and produce a new
genesis ledger for the succeeding network. This new genesis ledger should be
produced from a stabilised staged ledger from the preceding network. This is, we
define a point in time (slot) where the network continues to operate but with no
"activity". In detail, after this slot, the network continues to produce blocks
but without including any transactions, and ensuring any fees paid are 0. This
will run for a certain number of slots, after which the network will stop
producing blocks. This will allow the network to stabilise and produce a new
genesis ledger from the last ledger produced by the network.

This feature enables part of this procedure, by adding the definition of the
slots and the mechanisms to stop the node from processing transactions and to
stop the networks after those slots.

## Detailed design

The procedure to stop processing transactions and producing/validating empty
blocks after a certain slot will be as follows:

* There will be a configuration parameter set at compile-time that will define
  the slot at which the node will stop processing transactions.
* The previous configuration should be overridable at runtime by optional CLI
  flags.
* The node (daemon) will stop accepting new transactions from clients after
  the configured slot.
* After the configured slot, the block producer will stop including transactions
  in blocks, and all fees are set to 0.
* The block validator will reject blocks produced after the stop slot that
  contain any transaction or any non-zero fee.
* The node should start notifying the user every 60 slots when transaction
  processing halts in less than 480 slots.

To stop the network after a certain slot, the procedure will be as described
next:

* There will be a configuration parameter set at compile-time that will define
  the slot at which the node will stop the network.
* The previous configuration should be overridable at runtime by optional CLI
  flags.
* After the configured slot, the block producer will stop producing any blocks.
* The block validator will reject any blocks received after the stop network
* slot.
* The node should start notifying the user every 60 slots when block
  production/validation halts in less than 480 slots.

Each of these procedures will be described in detail in the following sections.

### Compile-time configuration and CLI flag

The configuration parameters `slot_tx_end` and `slot_chain_end` will be set at
compile-time and will define the slot at which the node will stop processing
transactions and the slot at which the network stops, respectively. These
configuration parameters will be optional and will default to `None`. If
`slot_tx_end` is set to `None`, the node will not stop processing transactions.
If `slot_chain_end` is set to `None`, the node will not stop producing or
validating blocks.

There will be two optional CLI flags that will override this configuration.

* `--slot-tx-end`: if set to `none`, disables the feature by setting the
  slot at which the node will stop processing transactions to `None`. If set to
  a slot, enables the stop transaction processing feature and sets the value
  passed as the slot at which the node will stop processing transactions.
* `--slot-network-end`: if set to `none`, disables the feature by setting the
  slot at which the node will stop to `None`. If set to a slot, enables the stop
  network feature and sets the value passed as the slot at which the node will
  stop producing/validating blocks.

### Client submits transaction

When a client sends a transaction to the node daemon, the node will check if
the stop transaction slot configuration is set. If so, and the current global
slot is less than the configured stop slot, the transaction will be accepted by
the node and processed as usual. If the current global slot is equal or greater
than the configured stop slot, the transaction will be rejected. The client will
be notified of the rejection and the reason why the transaction was rejected.
This improves user UX by rejecting transactions that will not be included in the
ledger in the preceding network.

This can be done by adding these checks and subsequent rejection messages to the
GraphQL functions that receive and submit user commands.

### Block producer

When the block producer is producing a block, it will check if the stop network
slot configuration is set. If so, and the current global slot is equal or
greater than the configured stop slot the block producer will not produce a
block. If the configured stop slot is not set or it's greater than the current
global slot, the block producer will then check if the stop transaction slot
configuration is set. If so, and the current global slot is equal or greater
than the configured stop slot the block producer will produce a block without
any transactions and with fees set to 0. If the configured stop slot is not set
or is greater than the current global slot, the block producer will produce
blocks as usual.

This can be done by adding these checks to block production logic. First,
decide whether or not blocks should be produced. If the stop network slot is set
and the current global slot is equal or greater than it don't produce blocks. If
the previous is false, return an empty staged ledger diff instead of the
generated one whenever the stop transaction slot is defined and the current
global slot is equal or greater than it, ultimately resulting in a block
produced with no transactions, no internal commands, no completed snark work,
and no coinbase transaction. When doing these checks, the node will also check
for the conditions to emit the info log messages at the timings and conditions
expressed earlier.

### Block validator

When the block validator is validating a block, it will check if the stop
network slot configuration is set. If so, and the current global slot is equal
or greater than the configured stop slot, the block validator will reject the
block. If the stop network slot is not set or is greater than the current global
slot, the block validator will then check if the stop transaction slot
configuration is set. If so, and the global slot at which the block was produced
is less than the configured stop slot, the block validator will validate the
block as usual. If the stop transaction slot configuration is not set or is
greater than the global slot of the block, the block validator will reject
blocks that define a staged ledger diff different than the empty one.

This can be done by adding these checks to the transition handler logic. First, reject any blocks if the stop network slot value is set and the current global
slot is greater than it. Second, and if the previous is not true, check the
staged ledger diff of the transition against the empty staged ledger diff
instead doing the usual verification process when the configured stop transaction
slot is defined and the global slot for which the block was produced is equal or greater than it. When doing these checks, the node will also check for the
conditions to emit the info log messages at the timings and conditions expressed
earlier.

## Test plan and functional requirements

Integration tests will be added to test the behavior of the block producer and the
block validator. The following requirements should be tested:

* Block producer
  * When the stop network slot configuration is set to `None`, the block
    producer should produce blocks.
  * When the stop network slot configuration is set to `<slot>` and the current
    global slot is less than `<slot>`, the block producer should produce blocks.
  * When the stop network slot configuration is set to `<slot>` and the current
    global slot is greater or equal to `<slot>`, the block producer should not
    produce blocks.
  * When the stop transaction slot configuration is set to `None`, the block
    producer processes transactions and fees as usual.
  * When the stop transaction slot configuration is set to `<slot>` and the
    current global slot is less than `<slot>`, the block producer processes
    transactions and fees as usual.
  * When the stop transaction slot configuration is set to `<slot>` and the
    current global slot is greater or equal to `<slot>`, the block producer
    produces empty blocks (blocks with an empty staged ledger diff).
* Block validator
  * When the stop network slot configuration is set to `None`, the block
    validator validates blocks as usual.
  * When the stop network slot configuration is set to `<slot>` and the current
    global slot is less than `<slot>`, the block validator validates blocks as
    usual.
  * When the stop network slot configuration is set to `<slot>` and the current
    global slot is greater or equal to `<slot>`, the block validator rejects all
    blocks.
  * When the stop transaction slot configuration is set to `None`, the block
    validator validates blocks as usual.
  * When the stop transaction slot configuration is set to `<slot>` and the
    global slot of the block is less than `<slot>`, the block validator
    validates blocks as usual.
  * When the stop transaction slot configuration is set to `<slot>` and the
    global slot of the block is greater or equal to `<slot>`, the block
    validator rejects blocks that define a staged ledger diff differently than
    the empty one.
* Node/client
  * When the stop transaction slot configuration is set to `None`, the node
    processes transactions from clients as usual.
  * When the stop transaction slot configuration is set to `<slot>` and the
    current global slot is less than `<slot>`, the node processes transactions
    from clients as usual.
  * When the stop transaction slot configuration is set to `<slot>` and the
    current global slot is greater or equal to `<slot>`, the node rejects transactions from clients.

## Drawbacks

Non-patched nodes or nodes with the configuration overridden will still be able
to send transactions to the network. These transactions will be included in the
transaction pool but will not be processed by the patched block producers,
alongside other transactions that may have arrived at the transaction pool
before the configured stop slot but haven't been included in a block as of that
slot. This will result in a transaction pool that will not be emptied until the
network stops and those transactions will not be included in the succeeding
network unless there's a mechanism to port them over to the new network to be
processed and included there. This might result in a bad UX, especially for users
who send transactions to the network before the configured stop slot and don't
see them included in the ledger and disappear from the transaction pool when the
network restarts.
Moreover, non-patched nodes will produce and process transactions as usual after
the transaction stop slot, resulting in these nodes constantly attempting to fork.

## Rationale and alternatives

## Prior art

## Unresolved questions
