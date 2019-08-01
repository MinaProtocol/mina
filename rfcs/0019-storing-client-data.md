# Summary

The Coda protocol contains many different types of objects (`external_transition`s, transactions, accounts) and these objects have relationships with each other. A client communicating with the protocol would often make queries involving the relationship of these objects (i.e. Find the 10 most recent transactions that Alice sent after sending transactions, TXN). This RFC will discuss how we can take advantage of these relationships by using relational databases. This will accelerate our process in writing concise and maintainable queries that are extremely performant. Additionally, there are extra tasks that the daemon has to make these client operations performant. This in hand can slow down the performance of the daemon and can be remedied by offloading these operations into another process. We will also discuss further the pros and cons of this design as well as some slight architectural modifications to the GraphQL server and its dependencies.

.

# Motivation

The primary database that we store transactions and `external_transition`s is Rocksdb. When we load the databases, we read all of the key-value pairs and load them into an in-memory cache that is designed for making fast in-memory reads and pagination queries. The downside of this is that this design limits us from making complex queries. Namely, we make a pagination query that is sent from or received by a public key, but not strictly one or the other. Additionally, the indexes for the current design is limited to the keys of the database. This enables to answer queries about which transactions are in an `external_transition` but not the other way around (i.e. for a given transaction, which external_transitions have the transition). We can put this auxiliary information that tells us which `external_transition`s contain a certain transaction in the value of the transaction database. However, this results in verbose code and extra invariants to take care, leading to potential bugs. Relational databases are good at taking care of these type of details. Relational databases can give us more indexes and they can grant us more flexible and fast queries with less code.

This RFC will also formally define some GraphQL APIs as some of them were loosely defined in the past. This would give us more robustness for this RFC's design and less reason to refactor the architecture in the long run.

# Detailed Design

The first section will talk about the requirements and basic primitives that a client should be able to do when interacting with the protocol. This will make a good segway for explaining the proposed design. The last section will discuss consistency issues that could occur with this design.

<a href="requirements"></a>

## Requirements

__NOTE: The types presented in OCaml code are disk representations of the types__

In the Coda blockchain, there would be many different transactions sent and received from various people in the network. We would only be interested in hearing about several transactions involving certain people (i.e. friends). Therefore, a client should only keep a persistent record of transactions involving a white list of people and they should be able to look up the contents of these transactions from a container. Here are the records for a transaction. Note that transactions could be either `user_commands` or `fee_transfers` for this design:

```ocaml
module User_commands = struct
  type t = {
    id: string;
    is_delegation : bool;
    nonce: Unsigned64.t;
    from: Public_key.Compressed.t;
    to: Public_key.Compressed.t;
    amount: Unsigned64.t;
    fee: Unsigned64.t;
    memo: string
  }
end

module Fee_transfer {
  id: string;
  fee: Int64.t;
  receiver: Public_key.Compressed.t;
}
```

Additionally, clients should be able to know which `external_transition`s contains a transaction. These transitions can give us useful information about a transaction, like the number of block confirmations that is on top of a certain transaction and the "status" of a transaction. Therefore, a client should be able to store a record of these interested external_transitions and look them up easily in a container. Here is the type of an external_transition:

```ocaml
module Protocol_state = struct
  type t = {
    previousStateHash: string;
    blockchainState: BlockchainState;
    length: Int64!
  }
end


module External_transition = struct
  state_hash: string;
  creator: Public_key.Compressed.t
  protocol_state: Protocol_state.t [not null]
  is_snarked bool [not null]
  status consensus_status [not null]
  time time [not null]
end
```

The OCaml implementation of an `external_transition` is different from the presented `external_transition` type as it has the field `is_snarked` and `status` to make it easy to compute the `transactionStatus` query, which will tell us if a transaction is snarked and its `consensus_status`. `consensus_status` for an `external_transition` is variant type and is described below:

```ocaml
type consensus_status =
  | Failed (* frontier removed transition and never reached finality *)
  | Confirmed (* Transition reached finality by passing the root *)
  | Pending of int (* Transition is somewhere in the frontier and has a block confirmation number *)
  | Unknown (* Could not compute status of transaction i.e. We don't have a record of it *)
```

Notice that `PENDING` in `consensus_status` is the number of block confirmations for a block. This position has nothing to do with a block being snarked or not, so `Snarked` is not a constructor of this variant.

With the `external_transitions` and `consensus_status`, we can compute the status of a transaction. We will denote the status of a transaction as the type `transaction_status` and below is the type:

```ocaml
type transaction_status =
  | Failed (* The transaction has been evicted by the `transaction_pool` but never gotten added to a block OR all of the transitions containing that transaction have the status Failed *)
  | Confirmed (* One of the transitions containing the transaction is confirmed *)
  | Pending of int (* The transaction is in the `transition_frontier` and all of transitions are in the pending state. The block confirmation number of this transaction is minimum of all block confirmation number of all the transitions *)
  | Scheduled (* Is in the `transaction_pool` and not in the `transition_frontier`. *)
  | Unknown
```

We also have the `receipt_chain_hash` object and is used to prove a `user_command` made it into a block. It does this by forming a Merkle list of `user_command`s from some `proving_receipt` to a `resulting_receipt`. The `resulting_receipt` is typically the `receipt_chain_hash` of a user's account on the best tip ledger. More info about `receipt_chain_hash` can be found on this [RFC](rfcs/0006-receipt-chain-proving.md) and this [OCaml file](../src/lib/receipt_chain_database_lib/intf.ml).

Below is an OCaml API of involving `receipt_chain_hash` type:

```ocaml
module Receipt_chain_hash = struct
  type t = {
    hash: string
    previous_hash: string
  }

  val compute_receipt : ~prev:t -> User_command.t -> t
end
```

These containers should also have performant pagination queries, which is essentially a single contiguous range of sorted elements. `external_transitions` and `transactions` should be ordered by block length. Previously, we sorted these objects by time. Block length can arguably be a better ordering for transitions because clients can receive transitions at different times, but what remains constant is the block length that the transition appears in the blockchain. Additionally, we can sort transactions by the minimum block length of the `external_transition`s that they appear in. Typically, a client would expect to receive a transaction at the soonest block, which is the block with the smallest block length. If they do not appear in an `external_transition`, they will not appear in the sorting. A drawback with sorting `external_transitions` and transaction based on date is that if the client wants to add an arbitrary transaction and `external_transition` and persist them, then they would not have the extra burden of tagging these objects with a timestamp for pagination. Block length alleviates this use.

## Implementation

This section will discuss a proposal to make the querying done on a different process, which will be called the client process, and it will take advantage of in-memory data structures as well as persistent databases.

A persistent database that we would like to introduce into our codebase is `SQLite`. `SQLite` would be the best relational database for our use case because it has an Apache 2 license and its a very small binary (3.7MB on my Macbook). `SQLite` has a considerably good amount of support for OCaml compared to the other databases that will be discussed and it would be relatively easy to get `SQLite` working off. There is even a nice OCaml library called [ocaml-sqlexpr](https://github.com/mfp/ocaml-sqlexpr) that enables us to embed type-safe `SQLite` queries onto our OCaml code.

Some of these in-memory data structures leverage Redis as an in-memory database. Redis has a BSD license and is a few MBs.

Below is a diagram of the new process and shows how different components from the new process and the existing process communicate with each other:

![Client process](../docs/res/client_process.dot.png)

The black lines represent how a component communicates and update another component.

The purple line represents that the `transition_frontier` data will get updated whenever a transition gets removed from the `transition_frontier`.

Notably, we have an in-memory and disk versions for `transitions_to_transactions`, `transactions` and `receipt_chain_hashes` table. The functionalities and operations of these tables will be discussed later.

For storing objects discussed in the [Requirements section](#requirements) to disk, we can model them with the schemas below:

```
Enum consensus_status {
  confirmed [note: "The transitions has reached finality by passing the root"]
  pending [note: "Still in the transition frontier. There is no annotation "]
  failure [note: "Got removed from the transition frontier"]
  unknown [note: "After becoming online and bootstrapping, we may note know what will happen to a transition"]
}

Table external_transition {
  state_hash string [pk]
  creator string [not null]
  protocol_state string [not null] // we should write out all of the components of protocol_state as columns
  is_snarked bool [not null]
  status consensus_status [not null]
  block_length int [not null]
}

Table user_commands {
  id string [pk]
  is_delegation bool [not null]
  nonce int64 [not null]
  from string [not null]
  to string [not null]
  amount int64 [not null]
  fee int64 [not null]
  memo string [not null]
  is_added_manually bool [not null]
}
Table fee_transfers {
  id string [pk]
  fee int64 [not null]
  receiver string [not null]
}

// Use Rocksdb for this
Table receipt_chain_hashes {
  hash string [pk]
  previous_hash string
}

Table transition_to_transactions {
  state_hash string [ref: > external_transition.state_hash]
  transaction_id int [not null, ref: > user_commands.id, ref: > fee_transfers.id]
  sender string
  receiver string [not null]
  block_length length
    Indexes {
    state_hash [name:"external_transition"]
    transaction_id [name: "transaction"]
    (receiver, block_length) [name: "fast_receiver_pagination"]
    (sender, block_length) [name: "fast_sender_pagination"]
  }
}

// Rows are uniquely identified by `state_hash` and `transaction_id`
```

Notice that all the possible joins that we have to run through the `transition_to_transactions` table. The `transaction_id` and `state_hash` columns are indexed to make it fast to compute which transactions are in an `external_transition` and which `external_transition`s  have a certain transaction for the `transactionStatus` query. We have multicolumn indexes for `(receiver, date)` and `(sender, date)` to boost the performance of pagination queries.

The in-memory cache data structures are also similar to their disk counterparts, but they use the actual OCaml pointers as values or  have extra fields added to them for reducing the number of disk reads that cache has to make. They have the following schemas:

```
// Use OCaml Hashtbl
Table receipt_chain_hashes {
  hash string [pk]
  previous_hash string [not null]
  count int [not null]
}

// Use Redis
Table transition_to_transactions {
  state_hash string [ref: > external_transition.state_hash]
  transaction_id int [not null, ref: > user_commands.id, ref: > fee_transfers.id]
  sender string
  receiver string [not null]
  in_disk bool [not null]
  block_length length
    Indexes {
    state_hash [name:"external_transition"]
    transaction_id [name: "transaction"]
    (receiver, block_length) [name: "fast_receiver_pagination"]
    (sender, block_length) [name: "fast_sender_pagination"]
  }
}

// Use OCaml Hashtbl
Table transaction {
  id: Transaction_id.t -> Transaction.t
}

// Use OCaml Hashtbl
Table transition {
  id: State_hash.t -> external_transition
}
```

### Replicated transition frontier

To offload the client computation from the daemon, we are going to replicate the state of the `transition_frontier`. The replication process will be very similar to the replication process of `transition_frontier_peristence`. In the current implementation of `transition_frontier_persistence`, we gather the diffs and apply them in batches to prevent overflowing async pipes and to prevent the system from slowing down. However, in this design, every time the `transition_frontier` in the daemon produces a diff, it will immediately send that diff to the client along with its mutant diff hash. It should mitigate the issue of slowing down the system because the client process would be in a different core and therefore parallelizing replication and persistence. Currently, the diffs contain breadcrumbs and we cannot serialize breadcrumbs, so the diffs that clients will be receiving will be the following:

```ocaml
module Transition_frontier_diff = struct
  type t =
    | Breadcrumb_added of {just_emitted_a_proof: bool; external_transition: external_transition}
    | Root_transitioned: of {new_: state_hash; garbage: state_hash.t list}
    | Best_tip_changed of state_hash
end
```

The daemon code for sending diffs to the client will look like the following:

```ocaml
Broadcast_pipe.Reader.fold diff_pipe ~init:init_hash ~f:(fun diff_hash diff ->
  let client_diff = to_client_diff diff in
  
  (* This is an asynchronous pipe *)
  let mutant = Diff_mutant.get_mutant transition_frontier diff in
  let new_hash = Diff_mutant.(hash (hash diff_hash mutant) diff) in
  Strict_pipe.Writer.write persistence_pipe (diff_hash, client_diff);
  Deferred.return new_hash
) |> Deferred.ignore |> don't_wait_for
```

Once the client receives the diff, it will apply the diff that it receives from the daemon. If the hash value that the client computed is different from the daemon, then both the daemon and the client will crash because of this inconsistent state. (TODO: Think of better methods for dealing inconsistencies because sending diffs from the daemon to the client can be dropped)

The state of the daemon's `transition_frontier` consists of a tree of breadcrumbs. However, the client does not need to know about the proofs of the breadcrumbs.

Instead, the node for a client's transition frontier can be the following type:

```ocaml
module Client_breadcrumb = struct
  type t = {
    transition_with_hash: (external_transition, State_hash.t) With_hash.t;
    just_emitted_a_proof: bool;
    ledger: merkle_mask_ledger
  }
end
```

This would be useful for making queries about a ledger for a breadcrumb, determining if a transition has been snarked or not, and for computing `receipt_chain_hashes` which is discussed in a later section.

In the `transition_frontier`, we need to make lookups to `transitions` that appear in `external_transitions`. We can simply create a hashtable that can look up `transactions` in the `transition_frontier` based on their `transaction_id`. Thus, the key of the table will be the `transaction_id` and the value will be an OCaml pointer to the actual transaction data. The table will only contain transactions involving participants that a client is interested in following.

We would also need an in-memory `transition_to_transactions` table to find which `external_transitions` contain a transaction. This table will only contain transactions that involve participants that a client is interested in following. The table should leverage an in-memory database like Redis since it offers multiple indices and does not require implementing this. When we want to make a query involving the in-memory and disk versions of the `transition_to_transaction` table, it could involve making reads to both of the versions since the `external_transition`s the transaction that we are searching up could appear in the in disk version, but it did not appear in the in-memory version. We can reduce the number of reads using several optimization tricks.

We can keep an in-memory key-value table where the keys are public keys that a client is interested and the value is the maximum nonce in the disk `transitions_to_transactions` table. This will be denoted as `maxmimum_nonce`. The in-memory `transitions_to_transactions` table would have an extra boolean column called `in_disk` indicating if a transaction is in the current `transition_frontier` or not. When we add a transaction is added to the in-memory `transitions_to_transactions` table, we can also look at the disk `transitions_to_transactions` table to see if there are any transitions referring to the `transaction`. We can limit the number of times that we look at the disk `transitions_to_transactions` table by using the maximum nonce of the sender from `maximum_nonce`. If the sender's nonce is greater than the maximum nonce, then we know that `transaction` would not exist in the disk `transitions_to_transactions` table. Once a transition `B` gets removed from the `transition_frontier` resulting in the transaction `T` to get removed as well, we will set `in_disk=true` to the row with `B.state_hash = state_hash` and `T.id = transaction_id` in the in-memory `transitions_to_transactions` table and get added to the disk `transition_to_transactions` table. If all the rows that have `T.id = transaction_id` have `in_disk=true`, then they are all deleted from the in-memory `transitions_to_transactions` table.

Whenever a `transition` gets evicted from the client `transitition_frontier`, we would write the transitions into the `transition` database and their transactions into the `transaction_database`.

When we add a transition by applying the `Breadcrumb_added` diff and it emitted a `ledger_proof`, we can set the client breadcrumb as `is_snarked` and recursively do this for all ancestor breadcrumbs until the recursion reaches a breadcrumb that has already been snarked. The recursion can refer to transitions outside of the `transition_frontier` and in the `transition` database. We can create a recursive SQL query to the transitions as `is_snarked`.

### Receipt chain hashes

We can use the accounts in the materialized ledgers to correctly compute `receipt_chain_hashes` for the public keys that we are interested in. To optimize in-memory reads, we can use an in-memory`receipt_chain_hash` table to store all the `receipt_chain_hashes` corresponding to the transactions that we are interested in and are in the `transition_frontier`. Specifically, this `receipt_chain_hash` will be added to the table whenever the `New_breadcrumb` diff is applied to the `transition_frontier` to compute the `receipt_chain_hash` of a transaction and will be removed whenever the hashes do not appear again in for any `external_transition`. We can use a hashtable to represent this in-memory `receipt_chain` table. Namely, the keys of the table will be an underlying `receipt_chain_hash` and the values will be the parent of the `receipt_chain_hash` and a counter of the number of times that the `receipt_chain_hash` appear. Also, the disk `receipt_chain` table could be the same Rocksdb key-value storage used in our [current implementation](../src/lib/coda_base/receipt_chain_database.ml).

### Transaction pool

There are also a couple of enhancements to have performant querying and database updates involving the daemon's `transaction_pool`. The queries involving the `transaction_pool` would be `pooled_user_commands` and `transaction_status`. To get the status of a transaction, we need to see if it's in the `transaction_pool`. If it is in the `transaction_pool`, then the transaction would be considered `Scheduled`. However, if the transaction is in the `transaction_database` with the `is_manually_added=false` and does not appear in the `transaction_pool` or is not associated with any transitions in the in-memory or disk `transition_to_transactions_table`, then the transaction pool dropped the transaction and never made it to any blocks and the transaction status is considered to be `Failed`.

We would also want to write transactions from the `transaction_pool` to the `transaction_database`. We should write these transactions into the database only when they get evicted from the `transaction_pool` since we can use the `transaction_pool` to get information about a transaction.

Since the `transaction_database` would be receiving many redundant writes of the same object from the `transaction_pool` and the `transition_frontier`, the `transaction_database` would need an in-memory LRU cache to prevent these writes. Specifically, if the LRU does not have a `transaction`, the `transaction` would get written into the database and into the LRU cache. The `transaction_database` may benefit from leveraging the root history, which is a queue of the most recent transitions, to prevent these redundant writes.

### Adding Arbitrary Data

Since a node can go offline, it can miss gossipped objects. If this happens, a client would be interested in adding manually adding these objects into the client storage system. This storage system has the flexibility to do this.

For adding arbitrary transactions, the client could simply add it to the `transactions` database with `is_manually_added=true`. We can add arbitrary `receipt_chain_hashes` along with its parents to the `receipt_chain` database. The user can arbitrary transitions along with their transactions into the `transitions_to_transactions` table, `external_transitions` and `transactions` database. When we add a transition whose block length is greater than root length, the `transition` will be added through the `transition_frontier_controller`. Namely, the `transition` will be added to the `network_transition_writer` pipe in `Coda_networking.ml`.

<a href="bootstrap"></a>

### Running Bootstrap

If a client is offline for long time and they have to bootstrap, then they would not have a `transition_frontier`. Therefore, we would have to store all the objects in the `transition_frontier` into the databases. Additionally, we would not know the `consensus_state` of the saved `transitions`, so the `consensus_state` would be set to `UNKNOWN`.

## Consistency Issues

As mentioned in the [Running Bootstrap section](#bootstrap), we would not be able to fully determine the consensus status of the external_transitions that were in the transition_frontier. Worse, we would not be able to determine which external_transtions became snarked.

We can have a third-party archived node tell a client the consensus_state of the external_transitions. Another option that we have is that we can create a P2P RPC call where peers can give a client a Merkle list proof of a state_hash and all the state_hashes of the blocks on top of the state_hash. The Merkle list will be bounded by length K, the number of block confirmations to gaurantee finality with a very high probability. If the Merkle list proof is size K, then the external_transition should be fully confirmed. Otherwise, the external_transition failed.

We can also have a third-party archive node tell a client the snarked status of an `external_transition`. We can also create a heuristic that gives us a probability that an `external_transition` has been snarked. We can introduce a new nonce that indicates how many ledger proofs have been emitted from genesis to a certain external_transition. If the root external_transition emitted `N` ledger proofs, then all the external_transitions that have emitted less than `N` ledgers should have been snarked.

# Rationale and Alternatives

- Makes it easy to perform difficult queries for our protocol
- The current implementation takes a lot of work and it is quite limited for a certain use case.
- We can also stick with the same implementation we have, which is a bit limiting
- Other alternatives are discussed in the previous commits of this [RFC](https://github.com/CodaProtocol/coda/pull/2901)
- In an ideal world where we have an infinite amount of time, we would implement our own native graph database leverage the `transition_frontier` as an in-memory cache.

# Prior Art

Ethereum is representing their data as patricia tries and are storing them in LevelDB.

Coinbase also uses MongoDB to store all of the data in a blockchain.

# Unresolved questions

- How can we extend this design so that a client has multiple devices (i.e. Desktop application, mobile, etc...).

# Appendix

The flexibility of this new design changed some parts of the schema of the GraphqQL database. Here is the schema:

```graphql
enum ConsensusStatus {
  FAILED
  CONFIRMED
  PENDING of int
  UNKNOWN
}

enum TransactionConsensusStatus {
  SCHEDULED
  FAILED
  CONFIRMED
  PENDING of int
  UNKNOWN
}

type UserCommand {
  id: ID!

  # If true, this represents a delegation of stake, otherwise it is a payment
  isDelegation: Boolean!

  # Nonce of the transaction
  nonce: Int!

  # Public key of the sender
  from: PublicKey!

  # Public key of the receiver
  to: PublicKey!

  # Amount that sender is sending to receiver - this is 0 for delegations
  amount: UInt64!

  # Fee that sender is willing to pay for making the transaction
  fee: UInt64!

  # Short arbitrary message provided by the sender
  memo: String!
}

type FeeTransfer {
  # Public key of fee transfer recipient
  recipient: PublicKey!

  # Amount that the recipient is paid in this fee transfer
  fee: UInt64!
}

# Different types of transactions in a block
type Transactions {
  # List of user commands (payments and stake delegations) included in this block
  userCommands: [UserCommand!]!

  # List of fee transfers included in this block
  feeTransfer: [FeeTransfer!]!

  # Amount of coda granted to the producer of this block
  coinbase: UInt64!
}

type Block {
  # Public key of account that produced this block
  creator: PublicKey!

  # Base58Check-encoded hash of the state after this block
  stateHash: String!
  protocolState: ProtocolState!
  transactions: Transactions!
}

type BlockUpdate {
  block: Block!
  consensusStatus: ConsensusStatus!
  isSnarked: Bool!
}

type TransactionUpdate {
  block: Transaction!
  consensusStatus: TransactionConsensusStatus!
  isSnarked: Bool!
}


input BlockFilterInput {
  # A public key of a user who has their
  #         transaction in the block, or produced the block
  senders: [PublicKey!]!
  receivers: [PublicKey!]!
}

# Connection as described by the Relay connections spec
type BlockConnection {
  edges: [BlockEdge!]!
  nodes: [Block!]!
  totalCount: Int!
  pageInfo: PageInfo!
}

type BlockConfirmation {
  stateHash: String!
  blocksAhead: Int!
}

type PaymentUpdate {
  payment: Payment!
  consensus: ConsensusState!
}

input AddPaymentReceiptInput {
  hash: [String!]!

  ancestor_hash: String!
}
  
type PaymentProof {
  proof: [String!]!  
}

type TransactionStatus {
  isSnarked: bool!
  transactionConsensusStatus: TransactionConsensusStatus!
}
  
type query {
  # Construct a proof of a payment based on the account on the best tip of the transition_frontier
  provePayment (paymentId: Id!) : PaymentProof
  
  # Verify the proof of a payment constructed by `provePayment` based on the best tip of the transition_frontier
  verifyPayment (paymentId: Id!, resulting_receipt: String!, PaymentProof!): Bool!

  blocks(
    # Returns the elements in the list that come before the specified cursor
    before: String

    # Returns the last _n_ elements from the list
    last: Int

    # Returns the elements in the list that come after the specified cursor
    after: String

    # Returns the first _n_ elements from the list
    first: Int
    filter: BlockFilterInput!
  ): BlockConnection!
  
  # Retrieve all the user commands sent by a public key
  pooledUserCommands(
    # Public key of sender of pooled user commands
    senders: [PublicKey!]!
    receivers: [PublicKey!]!
  ): [UserCommand!]!

  # Get the status of a transaction
  transactionStatus(
    paymentId: ID!
  ): TransactionStatus!
}
  
  
type mutation {
  # Add receipts of payments that a client has missed. Return true if the receipts connect to a payment
  addPaymentReceipt(input: AddPaymentReceiptInput!): Bool!
}

union FollowUpdate = BlockUpdate | TransactionUpdate
  
type subscription {
  # Subscribe to the blocks that a user was involved and the transactions they sent
  followUser(publicKey :PublicKey!): [FollowUpdate!]!
}
```
