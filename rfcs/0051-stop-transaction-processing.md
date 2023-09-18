# Stop processing transactions after a certain slot

This PR describes the feature to stop processing transactions after a certain
slot, to be used in the Berkeley hard fork.

## Summary

Transactions come from a client or the gossip network and are processed by BPs
and SNARK workers to be included in blocks.

In this RFC, the procedure to stop processing any new transactions after a
certain slot is described. This is, any blocks produced after that slot will
include no transaction at all.

## Motivation

In a hard fork scenario, we want to halt the preceding network and produce a new
genesis ledger for the succeeding network. We want this to happen by defining a
point in time (slot) where the network stops accepting transactions a keeps
producing blocks free of transactions until it reaches a consensus state.

This feature enables part of this procedure, by allowing users to define a slot
at which the node will stop accepting any new transactions or including them in
blocks (in case it is a BP node).

## Detailed design

The procedure to stop processing transactions after a certain slot will act on
different components of the node, namely, the CLI, the transaction pool, the
snark pool, and the block producer.
and the CLI. The procedure will be as follows:

* The CLI will allow a slot at which the node will stop processing transactions
  to be set. This will be done by setting a new optional flag `--slot-tx-end`
  that will be used by the transaction pool, snark pool, and the block producer
  to stop processing transactions after a certain slot. If the flag is not set,
  the node will continue processing transactions as usual.
* The node will stop accepting new transactions from the client after the slot
  set by the CLI flag.
* The transaction pool will stop accepting new transactions after the slot set
  by the CLI flag.
* The transaction pool will drop all transactions from the pool after the slot
  set by the CLI flag.
* The snark pool will stop accepting new snark works after the slot set by the
  CLI flag.
* The snark pool will drop all snark works from the pool after the slot set by
  the CLI flag.
* The block producer will stop including transactions in blocks after the slot
  set by the CLI flag.

Each of these procedures will be described in detail in the following sections.

### Client submits transaction

When a client sends a transaction to the node, the node will check if the
current global slot is less than the slot set by the CLI flag `--slot-tx-end`.
If the transaction is valid and the slot is less than the slot set by the CLI
flag, the transaction will be added to the transaction pool. If the current
global slot is equal or greater than the slot set by the CLI flag, the
transaction will be rejected. The client will be notified of the rejection and
the reason why the transaction was rejected.

### Transaction pool

When a transaction is received by the transaction pool from any source, the
transaction pool will check if the current global slot is less than the slot set
by the CLI flag. If the transaction is valid and the slot is less than the slot
set by the CLI flag, the transaction will be added to the transaction pool. If
the current global slot is equal or greater than the slot set by the CLI flag,
the transaction will be rejected. The transaction pool will notify the source of
the transaction of the rejection and the reason why the transaction was
rejected.

When the transaction pool handles the transition frontier, it will check if the
current global slot is less than the slot set by the CLI flag. If the current
global slot is equal or greater than the slot set by the CLI flag, the pool will
drop all transactions. This includes transactions that were added to the pool
before the slot set by the CLI flag.

### Snark pool

For the snark pool, the procedure is analogous to the transaction pool but with
snark works instead of transactions.

### Block producer

When the block producer is producing a block, it will check if the current slot
is less than the slot set by the CLI flag. If the current slot is less than the
slot set by the CLI flag, the block producer will query the transaction pool for
transactions to include in the block as usual. If the current slot is equal or
greater than the slot set by the CLI flag, the block producer will produce a
block without any transactions.

## Test plan and functional requirements

Unit tests will be added to test the behavior of the transaction pool, the snark pool, and the block producer before the slot set by the CLI flag is reached, when it's reached,
and when it's not set.

* Transaction pool
  * The transaction pool accepts valid transactions before the slot set by the
    CLI flag is reached.
  * The transaction pool rejects transactions after the slot set by the CLI
    flag is reached.
  * The transaction pool drops all transactions after the slot set by the CLI
    flag is reached.
  * The transaction pool accepts valid transactions when the slot set by the CLI
    flag is not set.
* Snark pool
  * The snark pool accepts valid snark works before the slot set by the CLI flag
    is reached.
  * The snark pool rejects snark works after the slot set by the CLI flag is
    reached.
  * The snark pool drops all snark works after the slot set by the CLI flag is
    reached.
  * The snark pool accepts valid snark works when the slot set by the CLI flag
    is not set.
* Block producer
  * The block producer includes valid transactions in blocks before the slot set
    by the CLI flag is reached.
  * The block producer produces blocks without transactions after the slot set
    by the CLI flag is reached.
    * The block producer includes valid transactions in blocks when the slot set
      by the CLI flag is not set.
* Node/client
    * The node accepts valid transactions from the client before the slot set by
      the CLI flag is reached.
    * The node rejects transactions from the client after the slot set by the
      CLI flag is reached.
    * The node accepts valid transactions from the client when the slot set by
      the CLI flag is not set.

## Drawbacks



## Rationale and alternatives



## Prior art



## Unresolved questions


