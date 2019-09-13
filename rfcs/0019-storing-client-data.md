__NOTE: We refer `external_transitions` or transitions as blocks in this RFC__

# Summary

The Coda protocol contains many different types of objects (blocks, transactions, accounts) and these objects have relationships with each other. A client communicating with the protocol would often make queries involving the relationship of these objects (i.e. Find the 10 most recent transactions that Alice sent after sending transactions, TXN). This RFC will discuss how we can optionally take advantage of these relationships by using relational databases to answer these queries. Note that the proposed architecture does not limit a node to one particular database. On the contrary, it moves the current existing database storages that we have and move them to an architecutre that allows a user to optionally use a database and change the database. Additionally, this architecture will offload many async tasks in the daemon, as it will be delegated to another process.

This will accelerate our process in writing concise and maintainable queries that are extremely performant. We will further more discuss the data flow that connects the daemon to these optional storage components and make efficient queries. This architecture entails ripping out the API and archive related work into separate processes. By keeping the API separate, it can be scaled and load balanced, as can the database, without having to scale the number of nodes that are speaking to the archiver (unless you want higher network consistency). We will also discuss the pros and cons of using this new design.

# Motivation

The primary database that we use to store transactions and blocks is Rocksdb. When we load the Rocksdb databases, we read all of the key-value pairs and load them into an in-memory cache that is designed for making fast in-memory reads and pagination queries. The downside of this is that this design limits us from making complex queries. Namely, we make a pagination query that is sent from or received by a public key, but not strictly one or the other. Additionally, the indexes for the current design is limited to the keys of the database. This enables us to answer queries about which transactions are in an block but not the other way around (i.e. for a given transaction, which blocks have the transaction). We can put this auxiliary information that tells us which blocks contain a certain transaction in the value of the transaction database. However, this results in verbose code and extra invariants to take care of, leading to potential bugs. Relational databases are good at taking care of these type of details. Relational databases can give us more indexes and they can grant us more flexible and fast queries with less code.

We would also want to decouple the database logic from the daemon code. This can give users the ability to optionally run their own databases. This would be helpful to run a slim version of Coda and could allow a user to easily use a distributed cloud database to store data for their archive node.

This RFC will also formally define some APIs that a client would make (in the form of GraphQL queries) as some of them were loosely defined in the past. This would give us more robustness for this RFC's design and less reason to refactor the architecture in the long run.

# Detailed Design

The first section will talk about the requirements and basic primitives that a client should be able to do when interacting with the protocol. This will make a good segway for explaining the proposed design. This will entail the schema of the databases, the data flow of the client storage and how clients can query information from the daemon and the client storage systems via GraphQL. The last section will discuss consistency issues that could occur with this design.

<a href="requirements"></a>

## Requirements

__NOTE: The types presented in OCaml code are disk representations of the types__

In the Coda blockchain, there would be many different transactions sent and received from various people in the network. A client would only be interested in hearing about several transactions involving certain people (i.e. friends). Therefore, the client should only keep a persistent record of transactions involving a white-list of people and they should be able to look up the contents of these transactions from a container. Also, some applications would be interested in hearing everything that comes through the network (i.e. archive nodes, block explorers). Thus, a client should have the ability to record every object that they hear throughout the network. Here are the records for a transaction. Note that transactions could be either `user_commands` or `fee_transfers` for this design:

```ocaml
module User_commands = struct
  type t = {
    id: string;
    is_delegation : bool;
    nonce: Unsigned64.t;
    sender: Public_key.Compressed.t;
    receiver: Public_key.Compressed.t;
    amount: Unsigned64.t;
    fee: Unsigned64.t;
    memo: string;
    first_seen: Time.t
  }
end

module Fee_transfer {
  id: string;
  fee: Int64.t;
  receiver: Public_key.Compressed.t;
  first_seen: Time.t
}
```

Additionally, clients should be able to know which blocks contains a transaction. These blocks can give us useful information about a transaction, like the number of block confirmations that is on top of a certain transaction and the "status" of a transaction. Therefore, a client should be able to store a record of these interested blocks and look them up easily in a container. Here is the type of a block:

```ocaml
module Blockchain_state = struct
  type t = {
    staged_ledger_hash: string;
    snarked_ledger_hash: string;
    time_stamp: Date.t
  }
end

module Consensus_state = struct
  type t = {
    blockchain_length: int;
    epoch: int;
    slot: int;
  }
end

module Protocol_state = struct
  type t = {
    consensus_state: Consensus_state.t;
    blockchain_state: Blockchain_state.t;
    ledger_proof_nonce: Int64.t; (* Need to implement #3083 *)
  }
end

module Block = struct
  type t = {
    state_hash: string;
    creator: Public_key.Compressed.t; (* Can be retrieved from the staged_ledger_diffs *)
    protocol_state: Protocol_state.t;
    status: consensus_status;
    block_length: int
  }
end
```

The OCaml implementation of an `external_transition` is different from the presented `Block.t` type as it has the field `ledger_proof_nonce` and `status` to make it easy to compute the `transactionStatus` query, which will tell us if a transaction is snarked and its `consensus_status`. `consensus_status` for an block is variant type and is described below:

```ocaml
type consensus_status =
  | Failed (* Frontier removed block and never reached finality *)
  | Confirmed (* block reached finality by passing the root *)
  | Pending of int (* Block is somewhere in the frontier and it indicates the block confirmation number of the block *)
  | Unknown (* Could not compute status of block i.e. This can happen after we bootstrap and we do not have a `transition_frontier` anymore *)
```

Notice that `Pending [num_confirmation_blocks]` in `consensus_status` is the number of block confirmations for a block. This position has nothing to do with a block being snarked or not, so `Snarked` is not a constructor of this variant.

With the blocks and `consensus_status`, we can compute the status of a transaction. The status of a transaction also depends on its membership in the transaction pool and if it was added manually.

We will denote the status of a transaction as the type `transaction_status`. `transaction_status` is very similar to `consensus_status` with the additional variant of a transaction being `Scheduled`. Below is the variant of the type:

```ocaml
type transaction_status =
  | Failed (* The transaction is not in the `transaction_pool` and it has not been added_manually by the user but never gotten added to a block OR all of the transitions containing that transaction have the status Failed *)
  | Confirmed (* One of the blocks containing the transaction is confirmed *)
  | Pending of int (* The transaction is in the `transition_frontier` and all of transitions are in the pending state. The block confirmation number of this transaction is maximum of all block confirmation numbers of all the transitions *)
  | Scheduled (* Transaction is added into the `transaction_pool` and has not left the pool. It's also not in the `transition_frontier`. *)
  | Unknown
```

We can use `ledger_proof_nonce` to compute if a transaction is snarked. `ledger_proof_nonce` starts at 0 and is incremented every time a ledger proof is included into the blockchain proof. When you add transactions to a block, mark each transaction with an expected ledger nonce of `state.ledger_proof_nonce + m + {0,1}`, where `m` is the depth (and parallelization factor) of the staged ledger, and `{0,1}` is picked based on whether the transaction fits in the current staged ledger layer or rolls over into the next one. You know a transaction has been snarked at some state in the network iff `state.ledger_proof_nonce >= transaction.expected_ledger_proof_nonce`.

Additionally, we would also like to know which snark jobs are included in a block. The type of a snark job looks like the following:

```ocaml
module Snark_job = struct
  type t = {
    prover: Public_key.Compressed.t;
    fee: Fee.t;
    workIds: int list
  }
end
```

We also have the `receipt_chain_hash` object and is used to prove a `user_command` has been executed in a block. It does this by forming a Merkle list of `user_command`s from some `proving_receipt` to a `resulting_receipt`. The hash essentially represents a concise footprint of the sequence of user commands that have been executed since genesis to a certain point in time. The `resulting_receipt` is typically the `receipt_chain_hash` of a user's account on the ledger of some block. More info about `receipt_chain_hash` can be found on this [RFC](rfcs/0006-receipt-chain-proving.md) and this [OCaml file](../src/lib/receipt_chain_database_lib/intf.ml).

With each transaction in a block, we should be able to know it’s corresponding produced `receipt_chain_hash`. We need this to help show the clients the `receipt_chain_hash`es of their transactions so they can prove it any time later.

Below is an OCaml API of involving `receipt_chain_hash` type:

```ocaml
module Receipt_chain_hash = struct
  type t = {
    hash: string
    previous_hash: string
  }

  val compute_receipt : ~prev:t -> User_command.t -> t
end

module Receipt_chain_database = struct
  type t = (Receipt_chain_hash.t, Receipt_chain_hash.t) Key_value_store.t

  val add : previous:Receipt_chain_hash.t -> t -> User_command.t -> unit

  val prove : t -> proving_receipt:Receipt_chain_hash.t -> resulting_receipt:Receipt_chain_hash.t ->
(Receipt_chain_hash.t, User_command.t) Payment_proof.t Base.Or_error.t

  val verify : t -> resulting_receipt:Receipt_chain_hash.t ->
(Receipt_chain_hash.t, User_command.t) Payment_proof.t ->
(unit, Error.t) Pervasives.result
end
```

These containers should also have performant pagination queries, which is essentially a single contiguous range of sorted elements. Namely, we order blocks and transactions by some notion of time. These metrics of time vary based on a client's needs.

Blocks and transactions can be ordered by the time it is first seen. The first time we see a block is considered to be the time it gets added to the `transition_frontier`. The first time we see a transaction would be the first time we see it in the `transaction_pool` or when it gets added into a block in the `transition_frontier`.

We can also order these objects by the lexicographic ordering of block length, epoch and slot. We will denote this ordering as `block_compare`. `block_compare` length can arguably be a better ordering for blocks because clients can receive blocks at different times, but what remains constant is the `block_compare` that the block appears in the blockchain.

The ocaml code to sort blocks can be seen as the following:

```ocaml
val block_compare = lexicographic [
  Comparable.lift Length.compare ~f:Block.block_length;
  Comparable.lift Epoch.compare ~f:Block.epoch;
  Comparable.left Epoch.Slot.compare ~f:Block.epoch_slot
]
```

Additionally, we can order transactions by the minimum `block_compare` of the blocks that they appear in. Typically, a client would expect to receive a transaction at the chain that honest peers are building. This honest chain should have a small `block_compare` to other blocks. If the transactions do not appear in an block, they will not appear in the sorting.

A drawback with sorting blocks and transaction based on the time that they are first seen is that if the client wants to store an arbitrary transaction and block, then they would not have the extra burden of tagging these objects with a timestamp for pagination. `block_compare` alleviates this issue.

## SQL Database

This architecture supports many SQL databases and it can even exclude a database entirely to make the architecture modular. When it is included, there are different use cases for using a light database, such as SQLite, and heavier database, such as Postgres. Postgres or even a distributed cloud database, such as AppSync, should be used when we have an archive node or a block explorer trying to make efficient writes to store everything that it hears from the network. These databases also support built-in subscriptions that would be convinient for clients to listen to.

For the objects discussed in the previous section, we can embed them as tables in one global SQL database. Below are the schemas of the tables:

```
Table public_keys {
  id int [pk]
  value text [not null]
  Indexes {
    value [name: "public_key"]
  }
}

Table blocks {
  id int [pk]
  state_hash string [not null]
  coinbase int [not null]
  creator string [not null]
  staged_ledger_hash string [not null]
  ledger_hash string [not null]
  global_slot int [not null] // encompasses (epoch, slot)
  ledger_proof_nonce int [not null]
  status int [not null]
  block_length int [not null]
  time_received bit(64) [not null]
  Indexes {
    state_hash [name: "state_hash"]
    (block_length, global_slot) [name: "block_compare"]
    time_received [name: "block_compare"]
  }
}

  // Consensus_status is an ADT, but with its small state spaces, it can be coerced into an integer to make it easy to store it in a database. Here are the following states:
  // - pending : The block is in the transition frontier and its value is its block confirmation number. Value[0, (k-1)]
  // - confirmed : The block has reached finality by passing the root. Value=-1
  // - failure: The block got removed from the transition frontier. Value=-2
  // - unknown: After becoming online and bootstrapping, we may not know what will happen to the block. Value=-3

Enum user_command_type {
  payment
  delegation
}

Table user_commands {
  id int [pk]
  hash string [not null, unique]
  type user_command_type [not null]
  nonce bit(64) [not null]
  sender int [not null, ref: > public_keys.id]
  receiver int [not null, ref: > public_keys.id]
  amount bit(64) [not null]
  fee bit(64) [not null]
  memo string [not null]
  first_seen bit(64)
  transaction_pool_membership bool [not null]
  is_added_manually bool [not null]
  Indexes {
    hash [name: "user_command_hash"]
    sender [name: "user_command_sender"]
    receiver [name: "user_command_receiver"]
    (transaction_pool_membership, sender) [name: "fast_pooled_user_command_sender"]
    (transaction_pool_membership, receiver) [name: "fast_pooled_user_command_receiver"]
    (sender, first_seen) [name: "fast_sender_pagination"]
    (receiver, first_seen) [name: "fast_receiver_pagination"]
  }
}

Table fee_transfers {
  id int [pk]
  hash string [not null, unique]
  fee bit(64) [not null]
  receiver int [not null, ref: > public_keys.id]
  first_seen bit(64)
  Indexes {
    hash [name: "fee_transfers_hash"]
    receiver [name:"fee_transfer_receiver"]
  }
}

Table receipt_chain_hashes {
  id int [pk]
  hash string [not null, unique]
  previous_hash string
  user_command_id string [not null, ref: > user_commands.id]
  Indexes {
    user_command_id
  }
}

Table block_to_user_commands {
  block_id int [not null, ref: > blocks.id]
  transaction_id int [not null, ref: > user_commands.id]
  receipt_chain_id int [ref: > receipt_chain_hashes.id]
  Indexes {
    block_id [name:"block_to_user_command.block"]
    transaction_id [name: "block_to_user_command.transaction"]
  }
  // Rows are uniquely identified by `state_hash` and `transaction_id`
}

Table block_to_fee_transfers {
  block_id int [not null, ref: > blocks.id]
  transaction_id int [not null, ref: > fee_transfers.id]
  Indexes {
    block_id [name:"block_to_fee_transfer.block"]
    transaction_id [name: "block_to_fee_transfer.transaction"]
    receiver [name: "block_to_user_command.receiver"]
  }
  // Rows are uniquely identified by `state_hash` and `transaction_id`
}

Table snark_job {
  id int [pk]
  prover int [not null]
  fee int [not null]
  job1 int // if a job is null, that it means it does not exist
  job2 int
  // Rows are uniquely identified by `job1` and `job2`
}

Table block_to_snark_job {
  block_id int [ref: > blocks.id]
  snark_job_id bit(64) [ref: > snark_job.id]
  Indexes {
    block_id
    snark_job_id
  }
  // Rows are uniquely identified by `block_id` and `snark_job_id`
}
```

Below is an image of the relationships of the schemas:

![Client process](../docs/res/coda_sql.png)

Here is a link of an interactive version of the schema: https://dbdiagram.io/d/5d30b14cced98361d6dccbc8

In this RFC, we are assuming that the datastructures for all Indexes and Multi-column Indexes are btrees. So Multi-column Indexes are technically sorted in lexigraphical order.

notice that `block` has the indexes `(block_length, epoch, slot)` and `time_received` for paginating blocks fast. Likewise, `user_commands` have the indexes on both (`sender`, `first_seen`) and (`receiver`, `first_seen`) to make paginating on `user_commands` fast. If we would like to order transactions based on `block_compare`, we would have to do a join on the `block_to_transaction` table and then another join on the `block` table. We could have added extra fields, such as `block_length`, `epoch` and `slot`, to the `block_to_transaction` to have less joins. However, we believe that this would making inserts more expensive and it complicates the table more.

### Deleting data

For this general architecture (which encompaness many application, such as the storage system for the wallet), we are assuming that objects will never get deleted because the client will only be following transactions involving a small number of public keys. These transactions cannot be deleted because they are ingredients necessary to prove the existence of other transaction using the `receipt_chain` proving mechanism. We could periodically delete blocks that failed to reach finality and the transaction involving them as well as blocks that have unknown status. However, the concept is outside of the scope of this RFC.

### Adding Arbitrary Data

Since a node can go offline, it can miss gossipped objects. If this happens, a client would be interested in manually adding these objects into the client storage system. This storage system has the flexibility to do this.

For adding arbitrary transactions, the client could simply add it to the `transactions` database with `is_manually_added=true`. We can also include the previous receipt chain hashes involving that transaction and use these components and add them to the `receipt_chain` database. The user can add arbitrary blocks along with their transactions into the `blocks_to_transactions` table, `block` and `transactions` database. When we add a block whose block length is greater than root length, the block will be added through the `transition_frontier_controller`. Namely, the block will be added to the `network_transition_writer` pipe in `Coda_networking.ml`.

<a id="bootstrap"></a>

### Running Bootstrap

If a client is offline for long time and they have to bootstrap, then they would not have a `transition_frontier`. Therefore, all the transitions in the `transition_frontier` would have their `consensus_status` be considered to `UNKNOWN`. Also, the transactions would not be in an `transaction_pool` anymore, so all the transaction's in `User_command.mem` would be `false`.

## Data Flow

This section will discuss how data flows between the daemon and the databases.

Below is a diagram of how the components in this RFC will depend on each other:

![Client storage](../docs/res/client_storage.dot.png)

### Archive Process

To offload many database writes that has to be conducted by the daemon, we are going to delegate the writes to another process, which will be called the Archive Process. This means that some production versions of Coda, such as Codaslim, would not have the binary of this Archive Process. Whenever the `transition_frontier` and the `transaction_pool` makes an update, they will send the diff representing the update to the process. The archive process will receive the diffs from the daemon through GraphQL subscriptions. The diffs of the `transition_frontier` that the archive process will receive would be similar to `Transition_frontier` extension diffs. Currently, these diffs contain breadcrumbs and we cannot serialize breadcrumbs, so the diffs that clients will be receiving will be the following:

```ocaml
module Transition_frontier_diff = struct
  type t =
    | Breadcrumb_added of {block:  (block, State_hash.t) With_hash.t; sender_receipt_chains_from_parent_ledger: Receipt_chain_hash.t Public_key.Compressed.Map.t}
    | Root_transitioned: of {new_: state_hash; garbage: state_hash.t list}
    | Bootstrap of {lost_blocks : state_hash list}
end
```

`Breadcrumb_added` has the field `sender_receipt_chains_from_parent_ledger` because we will use the previous `receipt_chain_hashes` from senders involved in sending a `user_command` in the new added breadcrumb to compute the `receipt_chain_hashes` of the transactions that appear in the breadcrumb. More of this will be discussed later.

Whenever a node is about to shutdown or has been offline time and is about to bootstrap, it will produce a diff containing the `state_hash` of all the blocks it has in its old `transition_frontier`. These blocks would be lost and their consensus state in the database would be labeled as UNKNOWN.

The `transaction_pool` diffs will essentially have a set of transactions that got added and removed from the `transaction_pool` after an operation has been done onto it

```ocaml
module Transaction_pool_diff = struct
  type t = {added: User_command.t Set.t ; removed: User_command.t Set.t}
end
```

Whenever the daemon produces a new `Transition_frontier_diff`, it will batch the transactions into the buffer, `transition_frontier_diff_pipe`. The buffer will have a max size. Once the size of the buffer exceeds the max size, it will flush the diffs to the archive process. To make sure that the archive process applies the diff with a low amount of latency, the buffer will flush the diffs in a short interval (like every 5 seconds). There will be a similar buffering process for the `transaction_pool`. The `transaction_pool` diffs can be seen as a monoid and it would be trivial to concate them into one diff. This would send less memory to the archive process and ultimately reduce the amount of writes that have to hit to the databases.

It is worth noting that the archive process writes to the databases using `Deferred.t`s. The archive process will write the diffs it receives in a sequential manner and will not context switch to another task. This will prevent any consistency issues.

The archive process will then filter transactions in the `Transaction_pool_diff` and `Transition_frontier.Breadcrumb_added` based on what a client is interested in following. A client would have the flexibility to filter transactions in `Transaction_pool_diff` and `Transition_frontier.Breadcrumb_added` based on the senders and receivers that they are interested in following. The client also has the ability to filter snark jobs in blocks. The client can further filter proposers of a block.  The archive process will have this filter rule in memory as the following type:

```ocaml
(* Simple way to get an existential type for GADTs *)
type filter_block_transaction_option =
  E : (`filter_blocks Truth.t * `filter_transactions Truth.t)

type filter_block_snark_option =
  E : (`filter_blocks Truth.t * `filter_snarks Truth.t)

type filter = {
  senders: filter_block_transaction_option Public_key.Compressed.Hashtbl.t;
  receivers: filter_block_transaction_option Public_key.Compressed.Hashtbl.t;
  creators: Public_key.Compressed.t list
  snark_provers: filter_block_snark_option Public_key.Compressed.Hashtbl.t;
}
```

It will also compute the ids of each of these transactions, which are hashes.

Below is psuedocode for persisting a transaction when the archive process receives a `Transaction_pool_diff` after it gets filtered:

```ocaml
let write_transaction_with_no_commit sql txn ?first_seen_in_block ~is_manually_added ?transaction_pool_mem_status external_transition_opt =
  match transaction_pool_mem_status with
  | Some transaction_pool_mem_status ->
    if Sql.mem sql['transaction'] txn then
    Sql.update sql['transaction']
      ~condition:(fun txn_in_database -> txn_in_database.id = txn.id)
      ~key:"transaction_pool_membership" ~data:transaction_pool_mem_status;
    Sql.update sql['transaction']
      ~condition:(fun txn_in_database -> txn_in_database.id = txn.id)
      ~key:"is_manually_added" ~data:is_manually_added
    else
    Sql.write sql['transaction'] txn transaction_pool_mem_status
  | None ->
    if not Sql.mem sql['transaction'] txn then
      Sql.write sql['transaction']
        txn (Option.value ~default:Unknown transaction_pool_mem_status)
  
  Option.iter external_transition_opt ~f:(fun {hash=state_hash; data=external_transition} ->
    let block_length = external_transition.block_length in
    let slot = external_transition.slot in
    let epoch = external_transition.epoch in
    let first_seen = Option.merge
      (get_first_seen sql['transaction'] Transaction.hash_id(txn))
      first_seen_in_block
    in
    Sql.write sql['block_to_transactions']
      {transaction_id=Transaction.hash_id(txn); state_hash; sender= Some (txn.sender); receiver = txn.receiver; block_length = None; first_seen; block_length; slot; epoch; is_manually_added }
  )

let write_transaction sql txn ?first_seen_in_block ~is_manually_added ?transaction_pool_mem_status account_before_sending_txn =
  write_transaction_with_no_commit sql ~first_seen_in_block ~is_manually_added ~transaction_pool_mem_status txn account_before_sending_txn None
  Sql.commit sql
```

The archive process will persist a block along with its transactions whenever it receives filtered `Breadcrumb_added` diff. Additionally, it will compute the `receipt_chain_hash` of each interested `user_command` in the block using `Breadcrumb_added.sender_receipt_chains_from_parent_ledger`. This new computed `receipt_chain_hash` along with its parent `receipt_chain_hash` will be added to the `Receipt_chain_datbase` Below is psuedocode for persisting a block:

```ocaml
(* filtered transition only contains transitions that we are interested in following *)
let write_block (~sender_receipt_chains_from_parent_ledger: Receipt_chain_hash.t Public_key.Compressed.Map.t) ~sql filtered_transition_with_hash previous_ledger date =
  let {With_hash.data=filtered_transition; hash=state_hash} = filtered_transition_with_hash in
  let transactions = Staged_ledger_diff.transactions @@  External_transition.staged_ledger_diff filtered_transition in
  let saved_block = {
    state_hash = State_hash.to_string state_hash;
    creator = Staged_ledger_diff.proposer (External_transition.staged_ledger_diff)
    status=Pending
    ...
  } in
  Sql.write sql['receipt_chain'] saved_block;
  List.iter transactions ~f:(fun transaction ->
    (* Add receipt chain hashes*)
    (match transaction with
    | User_command user_command ->
      let previous = Option.value_exn (Map.get sender_receipt_chains_from_parent_ledger transaction.sender) in
      let receipt = Receipt.Chain.cons previous (User_command.payload transaction) in
      Sql.write sql['receipt_chain'] {previous; user_command_id=Transaction.id transaction; receipt}
    | _ -> ());
    let previous_sender_account = Option.value_exn (Ledger.get_account ledger location) in
    write_transaction_with_no_commit ~first_seen_in_block:date ~is_manually_added:false sql transaction previous_sender_account transition_with_hash
  )
  Sql.commit sql
```

When the archive process receives the `Root_transitioned` diff, it will mainly update the `consensus_status` of a block. Below is the psuedocode for it:

```ocaml
let update_status sql finalized_transition deleted_transitions =
  Sql.update sql['block'] finalized_transition.hash Confirmed;
  List.iter deleted_transitions ~f:(fun deleted_transition ->
    Sql.update sql['block'] deleted_transition.hash Failed;
  );
  Sql.commit sql
```

We can also use `RPC_parallel` to ensure that the daemon will die if the archive process will die and vice versa.

### API Process

When a client wants to make a query, it will communicate with another process, the API process. Having the API process would offload many asynchronous tasks that the daemon has to perform since it will mainly make queries to the database. These queries should support the query language of the database. Therefore, the API process should know about what database it is writing to.

We are confident that a large bottleneck for performance improvements in Coda would be the number of async tasks. As a result, we cannot afford to make a lot of queries to the dademon process. This means that the tasks be delegated to another process, namely the SQL server.

The positive effect of having an API process is that it allows other developers to make modifications to queries without having to change the inner works of the daemon or the archive process. For example,this modification would enable users to query data using RPC serialization or Haxl rather than using GraphQL. This also gives us the opprotunity to use services such as Hasura that converts SQL schemas to Graphql schemas to make writing API commands very concise.

The API process will also make subscription to changes in the daemon and changes in the database. The various subscriptions will be discussed in a later part of this RFC.

The following section will describe SQL queries to make complicated queries.

## GraphQL commands

The notion document below discusses the GraphQL commands proposed in this new architecture. It succinctly discusses how it will evolve from the current GraphQL commands. It also discusses which components of the new architecture are involved in making these GraphQL queries. It also shows some sample code on complicated queries such as `transaction_status`. The advantage of this architecture is that there are no GraphQL queries that depend on both the daemon and the database simultaneously:

https://www.notion.so/codaprotocol/Proposed-Graphql-Commands-57a434c59bf24b649d8df7b10befa2a0

A HTML rendered version of the notion document can be found [here](../docs/res/graphql_diff.html).

## Consistency Issues

As mentioned in the [Running Bootstrap section](#bootstrap), we would not be able to fully determine the `consensus_status` of the block that were in the transition_frontier. Worse, we would not be able to determine which blocks became snarked.

We can have a third-party archived node tell a client the consensus_state of the blocks. Another option that we have is that we can create a P2P RPC call where peers can give a client a Merkle list proof of a state_hash and all the state_hashes of the blocks on top of the state_hash. The Merkle list should be length `K`, the number of block confirmations to gaurantee finality with a very high probability. If the Merkle list proof is size `K`, then the block should be fully confirmed. Otherwise, the block failed.

# Rationale and Alternatives

- Makes it easy to perform difficult queries for our protocol
- Makes the client code more modular
- The current implementation takes a lot of work and it is quite limited for a certain use case.
- Other alternatives are discussed in the previous commits of this [RFC](https://github.com/CodaProtocol/coda/pull/2901)
- In an ideal world where we have an infinite amount of time, we would implement our own native graph database leverage the `transition_frontier` as an in-memory cache. Namely, we would have all the blocks in the `transition_frontier` to be in the in-memory cache along with nodes that have a 1 to 2 degree of seperation
- Can we integrate the persistence system and the archival system in some way to make queries and stores more efficient?
- For the wallet, for every account that we are interested in, it would be nice to have `Account_state` table. For each account that we are interested in at each block, we will store its balance and nonce. This will reduce the need of having the `transaction_pool_membership` field in `User_command` because we would be able to infer the status of a transaction from the nonce of each account at the best tip.

# Prior Art

Ethereum is representing their data as patricia tries and are storing them in LevelDB.

Coinbase also uses MongoDB to store all of the data in a blockchain.

# Unresolved questions

- How can we extend this design so that a client has multiple devices (i.e. Desktop application, mobile, etc...).
- What happens if the archive node dies, how would we appropriate deal with the diffs?
- What happens if the database is full and writes stop? What are the appriopriate actions to do?
