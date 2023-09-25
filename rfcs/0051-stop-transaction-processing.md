# Stop processing transactions after a certain slot

This PR describes the feature to stop processing transactions after a certain
slot, to be used in the Berkeley hard fork.

## Summary

Transactions come from a client or the gossip network and are processed by BPs
and SNARK workers to be included in blocks.

In this RFC, the procedure to stop processing any new transactions after a
certain slot is described. This is, any blocks produced after that slot will
include no transaction at all, and no fee payments.

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

This feature enables part of this procedure, by allowing users to define a slot
at which the node will stop accepting any new transactions,
produced/validated blocks don't include any transaction, and any fees paid are
0.

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
* The block validator will reject blocks that include any transaction or that
  have any non-zero fee.
* The node should notify the user at each slot when transaction processing halts
  in less than TBD slots.

Each of these procedures will be described in detail in the following sections.

### Compile-time configuration and CLI flag

The configuration parameter `slot_tx_end` will be set at compile-time and will
define the slot at which the node will stop processing transactions. This
configuration parameter will be optional and will default to `None`. If set to
`None`, the node will not stop processing transactions.

There will be two optional CLI flags that will override this configuration.
The first CLI flag `--enable-slot-tx-end <slot>` enables the feature and sets
`<slot>` as the slot at which the node will stop processing transactions. The
second CLI flag `--disable-slot-tx-end` disables the feature and sets the slot
at which the node will stop processing transactions to `None`.

### Client submits transaction

When a client sends a transaction to the node daemon, the node will check if
the stop slot configuration is set. If so, and the current global slot is less than the configured stop slot, the transaction will be accepted by the node and processed
as usual. If the current global slot is equal or greater than the configured
stop slot, the transaction will be rejected. The client will be notified of the
rejection and the reason why the transaction was rejected. This improves user UX
by rejecting transactions that will not be included in the ledger in the
preceding network.

This can be done by adding these checks and subsequent rejection messages to the `mina_commands.ml` functions that handle transactions from the client.

### Block producer

When the block producer is producing a block, it will check if
the stop slot configuration is set. If so, and the current global slot is less
than the configured stop slot the block producer will behave as usual. If the
current global slot is equal or greater than the configured stop slot, the block
producer will produce a block without any transactions and with fees set to 0.

This can be done by adding these checks to block production logic, and returning
an empty staged ledger diff instead of the generated one when the configured
stop slot is defined and the current global slot is equal or greater than it.
This will result in a block produced with no transactions, no internal commands,
no completed snark work, and a coinbase fee of 0.

### Block validator

When the block validator is validating a block, it will check if the stop slot
configuration is set. If so, and the current global slot is less than the
configured stop slot the block validator will validate the block as usual.
If the current global slot is equal or greater than the configured stop slot,
the block validator will reject blocks that define a staged ledger diff
different than the empty one.

## Test plan and functional requirements

Unit tests will be added to test the behavior of the block producer and the
block validator. The following requirements should be tested:

* Block producer
  * The block producer processes transactions and fees as usual when the stop
    slot configuration is set to `None`.
  * The block producer processes transactions and fees as usual when the stop
    slot configuration is set to `<slot>` and the current global slot is less
    than `<slot>`.
  * The block producer produces empty blocks (blocks with an empty staged ledger
    diff) when the stop slot configuration is set to `<slot>` and the current
    global slot is greater or equal to `<slot>`.
* Block validator
  * The block validator validates blocks as usual when the stop slot
    configuration is set to `None`.
  * The block validator validates blocks as usual when the stop slot
    configuration is set to `<slot>` and the current global slot is less than
    `<slot>`.
  * The block validator rejects blocks that define a staged ledger diff
    different than the empty one when the stop slot configuration is set to
    `<slot>` and the current global slot is greater or equal to `<slot>`.
* Node/client
  * The node processes transactions from clients as usual when the stop
    slot configuration is set to `None`.
  * The node processes transactions from clients as usual when the stop
    slot configuration is set to `<slot>` and the current global slot is less
    than `<slot>`.
  * The node rejects transactions from clients when the stop slot configuration
    is set to `<slot>` and the current global slot is greater or equal to
    `<slot>`.

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

## Rationale and alternatives

## Prior art

## Unresolved questions
