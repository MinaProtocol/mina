# Summary

The Coda protocol contains many different types of objects (external_transitions, transactions, accounts) and these objects have relationships with each other. A client communicating with the protocol would often make queries involving the relationship of these objects (i.e. Find the 10 most recent transactions that Alice sent after sending transaction, TXN). This RFC will discuss how we can take advantage of these relationships by using relational/graph databases. This will accelerate our process in writing concise and maintainable queries that are extremeley performant. We will also discuss further the pros and cons of these databases as well as some slight architectual modifications to the GraphQL server and its dependencies.

# Motivation

The primary database that we store transactions and external_transitions is Rocksdb. When we load the databases, we read all of the key-value pairs and load them into an in-memory cache that is designed for making fast in-memory reads and pagination queries. The downside of this is that this design limits us from making complex queries. Namely, we make a pagination query that is sent from or received by a public key, but not strictly one or the other. Additionally, the indexes for the current design is limited to the keys of the database. This enables to answer queries about which transactions are in an external_transition but not the other way around (i.e. for a given transaction, which external_transitions have the transition). We can put this auxilary information that tells us which external_transitions contain a certain transaction in the value of the transaction database. However, this results in verbose code and extra invariants to take care, leading to potential bugs. Relational/graph databases are good at taking care of these type of details. Relational/graph databases can give us more indexes and they can grant us more flexible and fast queries with less code.

This RFC will also formally define some GraphQL APIs as some of them were losely defined in the past. This would give us more robustness for this RFC's design and less reason to refactor the architecture in the long run.

# Detailed Design

The first section will talk about the requirements and basic primitives that a client should be able to do when interacting with the protocol. This will make a good segueway to explaining the design details of integrating relational databases into our codebase. The next section will discuss about the other option of using graph databases. The last section will discuss consistency issues that could occur with this design.

## Requirements

__NOTE: The types presented in OCaml code are disk-representations of the types__

In the Coda blockchain, there would be many different transactions sent and received from various people in the network. We would only be interested in hearing about several transactions involving certain people (i.e. friends). Therefore, a client should only keep a persistent record of transactions involving a white list of people and they should be able to look up the contents of these transactions from a container. Here are the records for a transaction. Note that transactions could be either user_commands or fee_transfers for this design:

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
    memo: string;
    receipt_chain_hash: string
  }

end

module Fee_transfer {
  id: string;
  fee: Int64.t;
  receiver: Public_key.Compressed.t; 
}
```

You may notice that the user_commands type has the field receipt_chain_hash. This is a reference to a `receipt_chain_hash` which is used to prove the payment of a transaction. The API for proving the existence of a payment, `prove_payment`, would now require `payment_id` as an argument (See Appendix for the API of `prove_payment`). There is also an `addPaymentReceipt` API that allows a client to add an arbitrary transaction along with the date that the client saw the transaction. However, the transaction input itself cannot just be used to prove that a transaction has been sent. To prove a transaction, we need use current receipt_chain_hash of a transaction and its previous receipt_chain_hash. Therefore, inputs for the `addPaymentReceipt` API should be a receipt_chain and its parent.

Below is the type of a `receipt_chain_hash`:

```ocaml
module Receipt_chain_hash = struct
  type t = {
    hash: string
    previous_hash: string
  }
end
```

Additionally, clients should be able to know which external_transitions contains a transaction. These blocks can gives us useful information of a transaction, like the number of block confirmations that is on top of a certain transaction and the "status" of a transaction. Therefore, a client should be able to store a record of these interested external_transitions and look them up easily in a container. Here is the type of an external_transition:

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

The OCaml implementation of `External_transition` is different from the presented `external_transition` type as it has the field `is_snarked` and `status` to make it easy to compute the `transactionStatus` query, which will tell us if a transaction is snarked and it's `consensus_status`. `consensus_status` is variant type and is described below:

```ocaml
type consensus_status =
  | Failed (* frontier removed transition and never reached finality *)
  | Confirmed (* Transition reached finality by passing the root *)
  | Pending of int (* Transition is somewhere in the frontier and has a block confirmation number *)
  | Unknown (* Could not compute status of transaction i.e. We don't have a record of it *)
```

Notice that `consensus_status` is a block's position in Nakamoto consensus. This position has nothing to do with a block being snarked or not, so `Snarked` is not a constructor of this variant. 

With the `external_transitions` and `conseus_status`, we can compute the status of a transaction. We will denote the status of transaction as the type `transaction_status` and below is the type:

```ocaml
type transaction_status =
  | Failed (* All of the external_transitions have the status Failed, so the transaction failed *)
  | Confirmed (* One of the transitions is confirmed *)
  | Pending of int (* The transaction is in the transition_frontier and all of transitions are in the pending state. The block confirmation number of this transaction is minimum of all block confirmation number of all the transitions *)
  | Scheduled (* Is in the transaction_pool and not in the transition_frontier. *)
  | Unknown
```

These containers should also have performant pagination queries, which is essentially a single contiguous range of sorted elements. `External_transitions` should be ordered date, which is the time a node aded the `external_transition` to its `transition_frontier`. Transactions should also be sorted by the time that the client first receives it. It should be noted that the `external_transitions` can be sorted by block length. Block length can arguably be a better ordering for transitions because clients can receive transitions at different times, but what remains constant is the block length that the transition appears in the block chain. Additionally, we can sort transactions by the minimum block length of the `external_transition`s that they appear in. Typically, a client would expect to recieve a transaction at the soonest block, which is the block with the smallest block length. If they do not appear in an `external_transition` they will not appear in the sorting. If we plan to let the client add arbitrary `transactions` and `external_transition` and persist them, then they would not have the extra burden of tagging these objects with a timestamp for pagination. They can just use block length. 

## Relational Database Implementation

`SQLite` would be the best relational database for our use case because it has an Apache 2 liscense and its a very small binary (3.7MB on my Macbook). `SQLite` has a considerably good amount of support for OCaml compared to the other databases that will be discussed and it would be relatively easy to get `SQLite` working off. There is even a nice OCaml library called [ocaml-sqlexpr](https://github.com/mfp/ocaml-sqlexpr) that enables us to embed type-safe `SQLite` queries onto our OCaml code.

For the objects discussed in the previous section, we can embed them as tables in one global SQL database. Below are the schemas of the tables:

```
Enum consensus_status {
  confirmed [note: "The transitions has reached finality by passing the root"]
  pending [note: "Still in the transition frontier. There is no annotation "]
  failure [note: "Got removed from the transition frontier"]
}

Table external_transition {
  state_hash string [pk]
  creator string [not null]
  protocol_state string [not null]
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
  receipt_chain_hash string [not null]
}

Table fee_transfers {
  id string [pk]
  fee int64 [not null]
  receiver string [not null]
}

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

Here is a picture of the database:

![](../docs/res/coda_sqlite.png)

Here is a link to an interactive version of the image:
https://dbdiagram.io/d/5d30b14cced98361d6dccbc8

These tables are assumed to be purely on-disk files, except for the table `receipt_chain_hashes`. When are trying to prove the existence of a payment, we would do many reads to the `receipt_chain_hashes` table. We can prevent this by having `receipt_chain_hashes` be an in-memory database and back it up to disk files whenever we make a write. The API for backing up an in-memory database can be seen [here](https://www.sqlite.org/backup.html).

Notice that all the possible joins that we have to run is through the `transition_to_transactions` table. The `transaction_id` and `state_hash` columns are indexed to make it fast to compute which transactions are in an `external_transition` and which external_transitions  have a certain transaction for the `transactionStatus` query. We have multicolumns indexes for `(receiver, date)` and `(sender, date)` to boost the performance of pagination queries.

The client will persist a transaction involving public keys in their white list whenever they see the transaction gets gossipped to them or they schedule a sent transaction. Below is psuedocode for persisting a transaction:

```ocaml
let write_transaction_with_no_commit sqlite txn account_before_sending_txn external_transition_opt =
  Sqlite.write sqlite['transaction'] txn;
  let (state_hash, block_length) = 
    match external_transition_opt with
    | None -> (None, None)
    | Some (With_hash.{data; hash}) -> 
      (hash, Consensus_status.block_length @@ External_transition.consensus_state data)
  in
  Sqlite.write sqlite['transition_to_transactions'] 
    {transaction_id=Transaction.hash_id(txn); state_hash = None; sender= Some (txn.sender); receiver = txn.receiver; block_length = None  }
  let new_receipt_chain_hash = Receipt.Chain_hash.hash account_before_sending_txn.receipt_chain_hash txn in
  
  Sqlite.write sqlite['state_hash'] 
  {hash=new_receipt_chain_hash; previous_hash=account_before_sending_txn.receipt_chain_hash}

let write_transaction sqlite txn account_before_sending_txn =
  write_transaction_with_no_commit sqlite txn account_before_sending_txn None
  Sqlite.commit sqlite
```

The client will similarly persist an external_transition along with its transactions involving public keys in their white list when it gets added to the transition_frontier. Below is psuedocode for persisting an external_transition:

```ocaml
let write_transition sqlite breadcrumb previous_ledger = 
  let ({With_hash.data=external_transition; hash=state_hash} as transition_with_hash) = breadcrumb.transition_with_hash in
  let transactions = Staged_ledger_diff.transactions External_transition.staged_ledger_diff in
  let saved_external_transition = {
    state_hash = State_hash.to_string state_hash;
    creator = Staged_ledger_diff.proposer (External_transition.staged_ledger_diff)
    is_snarked=breadcrumb.just_emitted_a_proof
    status=Pending
    ...
  } in
  
  Sqlite.write sqlite['external_transition']  saved_external_transition;
  
  if breadcrumb.just_emitted_a_proof then mark_all_subsequent_transitions_as_snarked sqlite state_hash;
  
  List.iter transactions ~f:(fun transaction -> 
    let location = Option.value_exn (Ledger.get_account_location ledger transaction.sender) in
    let previous_sender_account = Option.value_exn (Ledger.get_account ledger location) in
    write_transaction_with_no_commit sqlite transaction previous_sender_account transition_with_hash
  )
  Sqlite.commit sqlite
```

When a transition reaches finality or gets removed, the transition status will get updated in the database.

For this design, we are assuming that objects will never get deleted because the client will only be following transactions involving a small number of public keys. These transactions cannot be deleted because they a components used to prove the existence of transaction. We could delete external_transitions that failed to reach finality and the transaction involving them. However, it outside of the scope of this RFC.

We can create another Transition_frontier extension to make these database updates. They will essentially listen to diffs that add external_transitions and remove external_transitions and we will make the database updates accordingly. 

Below are SQL queries that will assist us in implementing several GraphQL services:

### Queries

#### Transaction_status

This service can tell us the consensus status of transaction as well as if it is snarked or not. These values is based on which external_transitions that they are in. Below is the SQL query that can help us compute the status of a transaction. 

```SQL
-- transaction_status
SELECT state_hash, is_snarked, status FROM 
external_transitions
INNER JOIN transition_to_transactions on 
  transition_to_transactions.transaction_id = $TRANSACTION_ID
```

We can use this query in psuedocode as the following:

```ocaml

val compute_block_confirmations Transition_frontier.t -> State_hash.t list -> (State_hash.t * int) list 
let compute_block_confirmations frontier state_hashes = 
  failwith("Need to implement: For a given set of state_hashes, compute their block confirmation number in a memorized manner")


let get_transaction_status ~frontier ~sql ~txn_pool txn : (bool * transaction_status) =
  let sql_result = transaction_status_sql_query sql txn_id in
  match sql_result with
  | [] -> if Transaction_pool.member txn_pool txn then 
    (false, Scheduled) else (false, Unknown)
  | xs -> 
      let state_hashes, snarked_statuses, consensus_statuses = List.unzip3 xs in 
      let transaction_status = 
        if List.for_all consensus_statuses ~f:(Consensus_status.equal Failed) then
          Transaction_status.Failed
        else if List.exists consensus_statuses ~f:(Consensus_status.equal Confirmed) then
          Transaction_status.Confirmed
        else (* Transaction is in the transition_frontier *)
          let block_confirmations = compute_block_confirmations frontier state_hashes in 
          let block_confirmation = List.fold block_confirmations ~f:(fun acc (_, confirmations) -> Int.max acc confirmations  ) in
          Transaction_status.Pending block_confirmation 
      in
      let snarked_status = List.exists snarked_statuses ~f:(Fn.id) in
      (snarked_status, transaction_status)
```

### Pagination Queries

We make the pagination `blocks` query using the following SQL query

```SQL
-- blocks

SELECT state_hash, transaction_ids, date, creator, ....FROM 
(
SELECT state_hash, CONCAT(transition_to_transactions.transaction_id) as transaction_ids, MIN (transition_to_transactions.block_length) as block_length
FROM transition_to_transactions 
GROUPBY transition_to_transactions.state_hash
HAVING ((transition_to_transactions.sender IN $SENDERS) OR (transition_to_transactions.receiver IN $RECEIVERS))
) as group_by
INNER JOIN 
external_transitions
ON group_by.state_hash = external_transitions.state_hash
WHERE group_by.block_length > $BLOCK_LENGTH
ORDER BY block_length
LIMIT 10
-- Would need to use a groupby query to make query the transactions as well
```

From this command, we can further query the actual transactions in a block using the following lookup:

```SQL
SELECT id, nonce, amount, ... FROM
user_commands
WHERE id IN $TRANSACTION_IDS
```

### Disadvantages

The cons of using `SQLite` is that we have to make expensive join queries particularly for pagination queries and the `transactionStatus` query. Also, theres extra bloat having the `transition_to_transactions` table. Writing to the databases maybe slow because of the multiple indexes from the `transition_to_transactions` table.


## Graph databases

To address the join issues with `SQLite`, we can also consider using Graph Databases. particularly, Dgraph and Janus graph, which Apache 2 licensed. Ideally, we would have different types of vertices which are the tables described in the subsection, `Schema`. The edges of the graph are the following:

External Transitions <--> User_commands

User_commands <[receipt_chain_id:id]> Receipt_chain_hash

Receipt_chain_hash <[previous_id:id]> Receipt_chain_hash

Account <Receipt_chain_hash> transaction

An additional advantage of using a graph database is that they often have a visual showing how nodes and edges are connected in the graph database. This can serve as a useful tool for debugging the entire blockchain and as a block explorer.

The disadvantage of these graph databasess is that there isn't much support for both of these databases. Namely, the DSL queries are not strongly typed and we would have to make our own custom OCaml bindings to call these databases.

Dgraph seems to work nicely with graphql. It doesn't require serializing and deserializing the data. The output is just pure JSON and we can easily return that to the client. The main disadvantage is that vertices cannot have fields so all the fields of a vertex are actual vertices.

JanusGraph is another graph database to consider. We can explicitly mention the relationship of each type of vertex (i.e. 1-to-1, Many-to-many). We can also indicate how each vertex can index their edges, which is useful for optimizing different relationship queries. JanusGraph has its own "functional" graph query language called Gremlin and it has good interoperability with common languages, such as Java, Python and Javascript. However, there are no bindings with OCaml, but we can lauch a Gremlin server and we can communicate with the server using HTTP requests, Graphson, or use it's own untyped DSL written in Groovy.

## Consistency Issues

This design does not address consistency issues that can arise. For example, a client can be offline during sometime and then come online and bootsrap. As a result, we would not be able to fully determine the consensus status of the external_transitions that were in the transition_frontier. Worse, we would not be able to determine which external_transtions became snarked. 

We can have a third-party archived node tell a client the consensus_state of the external_transitions. Another option that we have is that we can create a P2P RPC call where we peers can give us a merkle list proof of a state_hash and all the state_hashes of the blocks on top of the state_hash. The merkle list will be bounded by length K. If the merkle list proof is size K, then the external_transition should be fully confirmed. Otherwise, the external_transition failed. 

We can also have a third-part achrived node tell a client the snarked status of an external_transition. We can also create a heuristic that gives us a probability that an `external_transition` has been snarked. We can introduce a new nonce that indicates how many ledger proofs have been emitted from genesis to a certain external_transition. If the root external_transition emitted `N` ledger proofs, then all the external_transitions that have emitted less than `N` ledgers should have been snarked.

## Making Client Queries on another Process

Previously, we discussed about making queries in the same process and the queries do not fully take advantage of the in-memory datastructures of the daemon. In this section, we will discuss about t

# Rationale and Alternatives

- Makes it easy to perform difficult queries for our protocol
- Current implementation takes a lot of work and it is quite limited for a certain use case.
- We can migrate to SQLite which has more support (and its less likely to encounter a bug).
  - If we use SQLite we can have many different tables. 
    - Have to worry about updating multiple tables and have to use primitives such as 2 phase commit
    - Join queries would be not be too performant
    - Writes might be slow because of many indexes.
- We can also stick with the same implementation we have, which is a bit limiting
- We can use a counter cache to decrease the number of calls that we have to the SQL database


# Prior Art

Ethereum is representing their data as patricia tries and are storing them in LevelDB. 

Coinbase also uses MongoDB to store all of the data in a blockchain.

# Unresolved questions

- Can we use the transition frontier and transaction pool as a cache layer to reduce the number of queries that hit the database? (I've thought about this deeply and have made a design solution extending the solution discussed in this RFC. I have not written out the full details of this solution.)
- How can we extend this design so that a client has multiple devices (i.e. Desktop application, mobile, etc...).
- There is a possibility for inconsistent queries for `snarked` and reach root. 
  Maybe we can have a notification telling us about that and then there would be a service that recomputes the status of these queries.

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
