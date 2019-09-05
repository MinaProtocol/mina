__NOTE: We refer `external_transitions` or transitions as blocks in this RFC__

# Summary

The Coda protocol contains many different types of objects (blocks, transactions, accounts) and these objects have relationships with each other. A client communicating with the protocol would often make queries involving the relationship of these objects (i.e. Find the 10 most recent transactions that Alice sent after sending transactions, TXN). This RFC will discuss how we can take advantage of these relationships by using relational databases. This will accelerate our process in writing concise and maintainable queries that are extremely performant. We will further more discuss the data flow that connects the daemon to these storage components and make efficient queries. We will also discuss the pros and cons of using this new design.

# Motivation

The primary database that we use to store transactions and blocks is Rocksdb. When we load the Rocksdb databases, we read all of the key-value pairs and load them into an in-memory cache that is designed for making fast in-memory reads and pagination queries. The downside of this is that this design limits us from making complex queries. Namely, we make a pagination query that is sent from or received by a public key, but not strictly one or the other. Additionally, the indexes for the current design is limited to the keys of the database. This enables to answer queries about which transactions are in an block but not the other way around (i.e. for a given transaction, which blocks have the transaction). We can put this auxiliary information that tells us which blocks contain a certain transaction in the value of the transaction database. However, this results in verbose code and extra invariants to take care, leading to potential bugs. Relational databases are good at taking care of these type of details. Relational databases can give us more indexes and they can grant us more flexible and fast queries with less code.

This RFC will also formally define some APIs that a client would make (in the form of GraphQL queries) as some of them were loosely defined in the past. This would give us more robustness for this RFC's design and less reason to refactor the architecture in the long run.

# Detailed Design

The first section will talk about the requirements and basic primitives that a client should be able to do when interacting with the protocol. This will make a good segway for explaining the proposed design. This will entail the schema of the SQL schemas, the data flow of the client storage and the sample client queries. The last section will discuss consistency issues that could occur with this design.

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
    from: Public_key.Compressed.t;
    to: Public_key.Compressed.t;
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
  time: Time.t
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

Notice that `PENDING` in `consensus_status` is the number of block confirmations for a block. This position has nothing to do with a block being snarked or not, so `Snarked` is not a constructor of this variant.

With the blocks and `consensus_status`, we can compute the status of a transaction. We will denote the status of a transaction as the type `transaction_status`. `transaction_status` is very similar to `consensus_status` with the additional variant of a transaction being `Scheduled`. Below is the variant of the type:

```ocaml
type transaction_status =
  | Failed (* The block has been evicted by the `transaction_pool` but never gotten added to a block OR all of the transitions containing that transaction have the status Failed *)
  | Confirmed (* One of the transitions containing the transaction is confirmed *)
  | Pending of int (* The transaction is in the `transition_frontier` and all of transitions are in the pending state. The block confirmation number of this transaction is minimum of all block confirmation number of all the transitions *)
  | Scheduled (* Is in the `transaction_pool` and not in the `transition_frontier`. *)
  | Unknown
```

We can use `ledger_proof_nonce` to compute if a transaction is snarked. `ledger_proof_nonce` which start at 0 and is incremented every time a ledger proof is included into the blockchain proof. When you add transactions to a block, mark each transaction with an expected ledger nonce of `state.ledger_proof_nonce + m + {0,1}`, where `m` is the depth (and parallelization factor) of the staged ledger, and `{0,1}` is picked based on whether the transaction fits in the current staged ledger layer or rolls over into the next one. You know a transaction has been snarked at some state in the network iff `state.ledger_proof_nonce >= transaction.expected_ledger_proof_nonce`.

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

With each transaction in a block, we should be able to know it’s corresponding produced `receipt_chain_hash`. We need this to help show the clients the receipt_chain_hashes of their transactions so they can prove it any time later.

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
  type t = (Receipt_chain_hash.t, Receipt_chain_hash.t)Key_value_store.t

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

Additionally, we can sort transactions by the minimum `block_compare` of the blocks that they appear in. Typically, a client would expect to receive a transaction at the chain that honest peers are building. This honest chain should have a small `block_compare` to other blocks. If the transactions do not appear in an block, they will not appear in the sorting.

A drawback with sorting blocks and transaction based on the time that they are first seen is that if the client wants to store an arbitrary transaction and block, then they would not have the extra burden of tagging these objects with a timestamp for pagination. `block_compare` alleviates this issue.

## SQL Database

The relational databases that we should use should be agnostic. There are different use cases for using a light database, such as SQLite, and heavier database, such as Postgres. Postgres should be used when we have an archive node or a block explorer trying to make efficient writes to store everything that it hears from the network. It also supports built-in subscriptions that would be convient for clients to listen to.

We would use SQLite when a user is downloading a wallet for the first time and only stores information about their wallets and their friends. SQLite would also be good to use if we are running a light version of Coda and they would only want to store a small amount of data. The downside of using SQLite is that subscriptions are not offered. To circumvent this issue, we can use a polling system that gets data in a short amount of time (about 5 seconds). We can also create a wrapper process that enables clients to write subscriptions on mutations in SQLite.

If a client wants to upgrade the database from SQLite to Postgres, then a migration tool would support this.

A client can also use AWS Appsync if they want to store their data in a distributed manner for multiple devices or if they want to store their data in the code.

For the objects discussed in the previous section, we can embed them as tables in one global SQL database. Below are the schemas of the tables:

```
Table block {
  state_hash string [pk]
  creator string [not null]
  staged_ledger_hash string [not null]
  ledger_hash string [not null]
  epoch int [not null]
  slot int [not null]
  ledger_proof_nonce int [not null]
  status int [not null]
  block_length int [not null]
}

  // Consensus_status is an ADT, but with a small amount of state spaces, it can be coerced into an integer to make it easy to store it in a database. Here are the following states:
  // - pending : The block is still in the transition frontier. Value[0, (k-1)]
  // - confirmed : The block has reached finality by passing the root. Value=-1
  // - failure: The block got removed from the transition frontier. Value=-2
  // - unknown: After becoming online and bootstrapping, we may not know what will happen to the block. Value=-3
  
Enum transaction_pool_status {
  Unknown
  Member
  Dropped
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
  time_first_seen date
  status transaction_pool_status [not null]
  Indexes {
    (status, from) [name: "fast_pooled_user_command_sender"]
    (status, to) [name: "fast_pooled_user_command_receiver"]
  }
}

Table fee_transfers {
  id string [pk]
  fee int64 [not null]
  receiver string [not null]
  time_first_seen date
}

Table block_to_transactions {
  state_hash string [not null, ref: > block.state_hash]
  transaction_id int [not null, ref: > user_commands.id, ref: > fee_transfers.id]
  time_seen_transaction date [ref: > user_commands.time_first_seen, ref: > fee_transfers.time_first_seen]
  sender string
  receiver string [not null]
  block_length int [not null, ref: > block.block_length]
  epoch int [not null, ref: > block.epoch]
  slot int [not null, ref: > block.slot]
    Indexes {
    state_hash [name:"block"]
    transaction_id [name: "transaction"]
    (receiver, block_length, epoch, slot) [name: "fast_receiver_block_compare_pagination"]
    (sender, block_length, epoch, slot) [name: "fast_sender_block_compare_pagination"]
    (receiver, time_seen_transaction) [name: "fast_receiver_time_seen_transaction_pagination"]
    (sender, time_seen_transaction) [name: "fast_sender_time_seen_transaction_pagination"]
  }
  // Rows are uniquely identified by `state_hash` and `transaction_id`
}

Table block_to_snark_job {
  state_hash string [ref: > block.state_hash]
  work_id int64 [ref: > snark_job.work_id]
}

Table snark_job {
  prover int
  fee int
  work_id int64 // the list of work_ids are coerced to a single int64 work_id because the list will hold at most two jobs
}

Table receipt_chain_hashes {
  hash string [pk]
  previous_hash string
  user_command_id string [not null, ref: > user_commands.id]
  Indexes {
    user_command_id
  }
}
```

Below is an image of the relationships of the schemas:

![Client process](../docs/res/coda_sql.png)

Here is a link of an interactive version of the schema: https://dbdiagram.io/d/5d30b14cced98361d6dccbc8

Notice that all the possible joins that we have to run through the `block_to_transactions` table. The `transaction_id` and `state_hash` columns are indexed to make it fast to compute which transactions are in an block and which blocks have a certain transaction for the `transactionStatus` query. We have multicolumn indexes for `(receiver, block_length, epoch, slot)` and `(sender, block_length, epoch, slot)` to boost the performance of pagination queries where are sorting based on `block_compare`.

We also have multicolumn indexes for `(receiver, time_seen_transaction)` and `(sender, time_seen_transaction)` to boost the performance of pagination queries where we are sorting based on the time we first see a transaction. The join table has quite a bit of indexes, which will impact the performance of the table when performing write updates. If the writes are too slow, then the join table should have only one type of pagination comparison. It is hard to predict the performance of these writes with these indexes. We should write benchmark performance tests to see how fast writes are with these indices. If the writes are too slow, we should prefer `block_compare` over `time_seen_transaction` since `time_seen_transaction` is a mutable field and the change to this field would cause more index updates to `time_seen_transaction`.

### Deleting data

For this design, we are assuming that objects will never get deleted because the client will only be following transactions involving a small number of public keys. These transactions cannot be deleted because they are components used to prove the existence of transaction. We could delete blocks that failed to reach finality and the transaction involving them. However, the concept is outside of the scope of this RFC.

### Adding Arbitrary Data

Since a node can go offline, it can miss gossipped objects. If this happens, a client would be interested in manually adding these objects into the client storage system. This storage system has the flexibility to do this.

For adding arbitrary transactions, the client could simply add it to the `transactions` database. We can also include the previous receipt chain hashes involving that transaction and use these components and add them to the `receipt_chain` database. The user can add arbitrary blocks along with their transactions into the `blocks_to_transactions` table, `block` and `transactions` database. When we add a block whose block length is greater than root length, the block will be added through the `transition_frontier_controller`. Namely, the block will be added to the `network_transition_writer` pipe in `Coda_networking.ml`.

<a href="bootstrap"></a>

### Running Bootstrap

If a client is offline for long time and they have to bootstrap, then they would not have a `transition_frontier`. Therefore, all the transitions in the `transition_frontier` would have their `consensus_status` be considered to `UNKNOWN`. Also, the transactions would not be in an `transaction_pool` anymore, so all the transaction's in `User_command.mem` would be `false`.

## Data Flow

This section will discuss how data flows between the daemon and the databases.

Below is a diagram of how the components in this RFC will depend on each other:

![Client storage](../docs/res/client_storage.dot.png)

### Archive Process

To offload many database writes that has to be conducted by the daemon, we are going to delegate the writes to another process, which will be called an Archive Process. Whenever the `transition_frontier` and the `transaction_pool` makes an update, they will send the diff representing the update to the process. The diffs of the `transition_frontier` that the archive process will receive will be similar to `Transition_frontier` extension diffs. Currently, these diffs contain breadcrumbs and we cannot serialize breadcrumbs, so the diffs that clients will be receiving will be the following:

```ocaml
module Transition_frontier_diff = struct
  type t =
    | Breadcrumb_added of {block:  (block, State_hash.t) With_hash.t; sender_receipt_chains_from_parent_ledger: Receipt_chain_hash.t Public_key.Compressed.Map.t}
    | Root_transitioned: of {new_: state_hash; garbage: state_hash.t list}
end
```

`Breadcrumb_added` has the field `sender_receipt_chains_from_parent_ledger` because we will use the previous `receipt_chain_hashes` from senders involved in sending a `user_command` in the new added breadcrumb to compute the `receipt_chain_hashes` of the transactions that appear in the breadcrumb. More of this will be discussed later.

The `transaction_pool` diffs will essentially list the transactions that got added and removed from the `transaction_pool` after an operation has been done onto it

```ocaml
module Transaction_pool_diff = struct
  type t = {added: User_command.t Set.t ; removed: User_command.t Set.t}
end
```

Whenever the daemon produces a new `Transition_frontier_diff`, it will batch the transactions into the buffer, `transition_frontier_diff_pipe`. The buffer will have a max size. Once the size of the buffer exceeds the max size, it will flush the diffs to the archive process. To make sure that the archive process applies the diff with a low amount of latency, the buffer will flush the diffs in a short interval (like every 5 seconds). There will be a similar buffering process for the `transaction_pool`. The `transaction_pool` diffs can be seen as a monoid and it would be trivial to concate them into one diff. This would send less memory to the archive process and ultimately reduce the amount of writes that have to hit to the databases.

It is worthy to note that whenever the archive process makes a write to the databases using deffers. The archive process will write the diffs it receives in a sequential manner and will not context switch to another task. This prevent any weird consistency issues.

The archive process will then filter transactions in the `Transaction_pool_diff` and `Transition_frontier.Breadcrumb_added` based on what a client is interested in following. It will also compute the ids of each of these transactions, which are hashes.

Below is psuedocode for persisting a transaction when the archive process receives a `Transaction_pool_diff`:

```ocaml
let write_transaction_with_no_commit sql txn ?time_first_seen_in_block ?transaction_pool_mem_status external_transition_opt =
  match transaction_pool_mem_status with
  | Some transaction_pool_mem_status ->
    if Sql.mem sql['transaction'] txn then
    Sql.update sql['transaction']
      ~condition:(fun txn_in_database -> txn_in_database.id = txn.id)
      ~key:"status" ~data:transaction_pool_mem_status  else
    Sql.write sql['transaction'] txn transaction_pool_mem_status
  | None ->
    if not Sql.mem sql['transaction'] txn then
      Sql.write sql['transaction']
        txn (Option.value ~default:Unknown transaction_pool_mem_status)
  
  Option.iter external_transition_opt ~f:(fun {hash=state_hash; data=external_transition} ->
    let block_length = external_transition.block_length in
    let slot = external_transition.slot in
    let epoch = external_transition.epoch in
    let time_first_seen = Option.merge
      (get_time_first_seen sql['transaction'] Transaction.hash_id(txn))
      time_first_seen_in_block
    in
    Sql.write sql['block_to_transactions']
      {transaction_id=Transaction.hash_id(txn); state_hash; sender= Some (txn.sender); receiver = txn.receiver; block_length = None; time_first_seen; block_length; slot; epoch }
  
  )

let write_transaction sql txn account_before_sending_txn =
  write_transaction_with_no_commit sql txn account_before_sending_txn None
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
    write_transaction_with_no_commit ~time_first_seen_in_block:date sql transaction previous_sender_account transition_with_hash
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

We can also use `RPC_parallel` to ensure that the daemon will die if the archive process will die and vice versa using RPC parallel.

### API Process

When a client wants to make a query, it will communicate with another process, the API process. Having the API process would offload many asynchronous tasks that the daemon has to perform since it will mainly make queries to the the database. We are confident that a large bottleneck for performance improvements in Coda would be the number of async tasks. As a result, we cannot afford to make a lot of queries to the dademon process. This means that the tasks be delegated to another process, namely the SQL server.

The positive effect of having an API process is that it allows other developers to make modifications to queries without having to change the inner works of the daemon or the archive process. For example,this modification would enable users to query data using RPC serialization or Haxl rather than using GraphQL. This also gives us the opprotunity to use services such as Hasura that converts SQL schemas to Graphql schemas to make writing API commands very concise.

The API process will also make subscription to changes in the daemon and changes in the database. The various subscriptions will be discussed in a later part of this RFC.

The following section will describe SQL queries to make complicated queries.

## Queries

### Transaction_status

This service can tell us the consensus status of transaction as well as if it is snarked or not. The consensus status is based on which blocks that they are in. The snarked status is based on the `ledger_proof_nonce` of the blocks that they are in as well as the `ledger_proof_nonce` of the best tip. Below is the SQL query that can help us compute the status of a transaction:

```SQL
--- query_transaction_status
SELECT state_hash, ledger_proof_nonce, status FROM
blocks
INNER JOIN block_to_transactions on
  block_to_transactions.transaction_id = $TRANSACTION_ID

--- transaction_pool_status
SELECT status FROM
transactions
WHERE id = $TXN_ID
```

We can use this query in psuedocode as the following:

```ocaml
val compute_block_confirmations Transition_frontier.t -> State_hash.t list -> (State_hash.t * int) list

let is_transaction_snarked = failwith("Need to implement")

let get_transaction_status ~sql txn best_tip_breadcrumb : (bool * transaction_status) =
  let sql_result = query_transaction_status sql txn_id in
  match sql_result with
  | [] ->
    match (transaction_pool_status sql["transaction"] txn_id) with
    | Unknown -> (false, Unknown)
    | Added -> (false, Scheduled)
    | Dropped -> (false, Failed)
  | results ->
      let transaction_status =
        if List.for_all results ~f:(fun (_, _, `Cosensus_status consensus_status_id)  ->
        let status = Consensus_status.of_int status in
         Consensus_status.equal status Failed) then
          (false, Failed)
      else
         let confirmed_result = List.find_map results ~f:(fun (_, `Ledger_proof_nonce nonce, `Cosensus_status consensus_status_id)  ->
          let status = Consensus_status.of_int status in
          Option.some_if (Consensus_status.equal status Confirmed) nonce)  |>
        Option.map  
          ~f:(fun ledger_proof_nonce ->
            (is_transaction_snarked best_tip_breadcrumb ledger_proof_nonce, true)
          ) in
        (match confirmed_result ~with
        | Some result -> result
        | None -> (* Transaction is in the transition_frontier *)
          let block_confirmation_with_ledger_proof_nonces = Option.value_exn (List.filter_map results ~f:(fun (_, `Ledger_proof ledger_proof, `Consensus_status consensus_status_id) ->
            match Consensus_status.of_int status with
            | Pending block_confirmation ->  Some (block_confirmation, ledger_proof_nonce)
            | _ -> None))
          in
          let (arg_max_ledger_proof_nonce, max_block_confirmation) = List.fold block_confirmation_with_ledger_proof_nonces ~f:(fun ((curr_max_confirmations, _) as acc) (confirmations, ledger_proof_nonce) ->
          if confirmations > curr_max_confirmations then
            (confirmations, ledger_proof_nonce) else acc
          ) in
          (is_transaction_snarked best_tip_breadcrumb ledger_proof_nonce, Pending confirmations)
      )
```

### Pagination Queries

We can paginate `blocks` (sorting by `time_seen`) query using the following SQL query

```SQL

SELECT state_hash, transaction_ids, time_seen, creator, .... FROM
(
SELECT state_hash, CONCAT(block_to_transactions.transaction_id) as transaction_ids, MIN (block_to_transactions.time_seen_transaction) as time_seen
FROM block_to_transactions
GROUPBY block_to_transactions.state_hash
HAVING ((block_to_transactions.sender IN $SENDERS) OR (block_to_transactions.receiver IN $RECEIVERS))
) as group_by
INNER JOIN
blocks
ON group_by.state_hash = blocks.state_hash
WHERE group_by.time_seen > $TIME_SEEN
ORDER BY time_seen
LIMIT 10
-- Would need to use a groupby query to make query the transactions as well
```

### Pooled_user_command

```SQL
-- querying specific receivers from the transaction pool
SELECT * FROM
transactions
WHERE status = ADDED AND to = $RECEIVER
```

```SQL
-- querying specific senders from the transaction pool
SELECT * FROM
transactions
WHERE status = ADDED AND to = $RECEIVER
```

## Consistency Issues

As mentioned in the [Running Bootstrap section](#bootstrap), we would not be able to fully determine the `consensus_status` of the block that were in the transition_frontier. Worse, we would not be able to determine which blocks became snarked.

We can have a third-party archived node tell a client the consensus_state of the blocks. Another option that we have is that we can create a P2P RPC call where peers can give a client a Merkle list proof of a state_hash and all the state_hashes of the blocks on top of the state_hash. The Merkle list should be length `K`, the number of block confirmations to gaurantee finality with a very high probability. If the Merkle list proof is size `K`, then the block should be fully confirmed. Otherwise, the block failed.

# Rationale and Alternatives

- Makes it easy to perform difficult queries for our protocol
- Makes the client code more module
- The current implementation takes a lot of work and it is quite limited for a certain use case.
- Other alternatives are discussed in the previous commits of this [RFC](https://github.com/CodaProtocol/coda/pull/2901)
- In an ideal world where we have an infinite amount of time, we would implement our own native graph database leverage the `transition_frontier` as an in-memory cache. Namely, we would have all the blocks in the `transition_frontier` to be in the in-memory cache along with nodes that have a 1 to 2 degree of seperation

# Prior Art

Ethereum is representing their data as patricia tries and are storing them in LevelDB.

Coinbase also uses MongoDB to store all of the data in a blockchain.

# Unresolved questions

- How can we extend this design so that a client has multiple devices (i.e. Desktop application, mobile, etc...).

# Appendix

The flexibility of this new design changed some parts of the current schema of the GraphqQL database. [../docs/res/graphql_diff.html](https://raw.githack.com/CodaProtocol/coda/rfc/storing-client-data/docs/res/graphql_diff.html) is a html file that shows the difference between these two graphql schemas. Here is the new proposed schema:

```graphql
# PageInfo object as described by the Relay connections spec
type PageInfo {
  hasPreviousPage: Boolean!
  hasNextPage: Boolean!
  firstCursor: String
  lastCursor: String
}

# Sync status of daemon
enum NetworkInteractionStatus {
  CONNECTING # You are trying to connect to at least one peer
  LISTENING # You are connected to a peer, but you want to listen to
  INTERACTING # You have at least listened to one message from the network
}

enum ActiveStatus {
  BOOTSTRAP
  ONLINE
  OFFLINE
}

type SyncStatus {
  activitiy: ActiveStatus!
  networkIneraction: NetworkInteractionStatus # This would be none if a node is offline
}

type OnlineStatus {
  status: NetworkInteractionStatus!
}

enum FinalizedStatusEnum {
  FAILED
  CONFIRMED
  UNKONWN
}

type FinalizedStatus {
  status: FinalizedStatusEnum!
}

type PendingStatus {
  blockConfirmationNumber: Int!
}

enum ScheduledEnum {
  SCHEDULED
}

type Scheduled {
  status: ScheduledEnum!
}

union ConsensusStatus = FinalizedStatus | PendingStatus

union TransactionConsensusStatus = FinalizedStatus  | PendingStatus | Scheduled

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

  firstTimeSeen: Date

  is_manually_added: Bool!
}

type FeeTransfer {
  # Public key of fee transfer recipient
  recipient: PublicKey!

  # Amount that the recipient is paid in this fee transfer
  fee: UInt64!

  firstTimeSeen: Date

  is_manually_added: Bool!
}

# Useful for a client to know the receiptChainHash of transaction in a block
type UserCommandWithReceiptHash {
  userCommand: UserCommand!
  receiptChainHash: String!
}

# Different types of transactions in a block
type Transactions {
  # List of user commands (payments and stake delegations) included in this block
  userCommands: [UserCommandWithReceiptHash!]!

  # List of fee transfers included in this block
  feeTransfer: [FeeTransfer!]!

  # Amount of coda granted to the producer of this block
  coinbase: UInt64!
}

type BlockchainState {
  # date (stringified Unix time - number of milliseconds since January 1, 1970)
  date: String!

  # Base58Check-encoded hash of the snarked ledger
  snarkedLedgerHash: String!

  # Base58Check-encoded hash of the staged ledger
  stagedLedgerHash: String!
}

type ConsensusState {
  blockchainLength: Int!
  epoch: Int!
  slot: Int!
}

type ProtocolState {
  # Base58Check-encoded hash of the previous state
  previousStateHash: String!

  # State related to the succinct blockchain
  blockchainState: BlockchainState!

  #State related to the block in Ouroborus Genesis
  consensusState: consensusState!
}

type Block {
  # Public key of account that produced this block
  creator: PublicKey!

  # Base58Check-encoded hash of the state after this block
  stateHash: String!
  protocolState: ProtocolState!
  transactions: Transactions!
}


input BlockFilterInput {
  senders: [PublicKey!]!
  receivers: [PublicKey!]!
}

# Connection Edge as described by the Relay connections spec
type BlockEdge {
  # Cursor is the state hash of a block
  cursor: String!
  node: Block!
}

# Connection as described by the Relay connections spec
type BlockConnection {
  edges: [BlockEdge!]!
  nodes: [Block!]!
  totalCount: Int!
  pageInfo: PageInfo!
}
  
type PaymentProof {
  proof: [UserCommand!]! # Inclusive-Exclusive proof of user commands that are used to prove a resuliting receipt
}

type TransactionStatus {
  isSnarked: bool!
  transactionConsensusStatus: TransactionConsensusStatus!
}
  
type query {
  # Network sync status
  syncStatus: SyncStatus!
  
  # Construct a proof of a payment based on the account on the best tip of the transition_frontier
  provePayment (input: String!) : PaymentProof!
  
  # Verify the proof of a payment constructed by `provePayment` based on the best tip of the transition_frontier
  verifyPayment (input: String!, resulting_receipt: String!, proof: PaymentProof!): Bool!

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

input AddUserCommandInput {
  userCommand: UserCommandWithReceipt!
  parentReceiptChainHash: String
}

input AddTransactionsInput {
  userCommands: [AddUserCommandInput!]!

  # List of fee transfers included in this block
  feeTransfer: [FeeTransfer!]!
}

input PublicKeyToReceiptChainHashInput {
  publicKey: String!
  receiptChainHash: String!
}

input AddBlockInput {
  block: Block!
  previousAccounts: [PublicKeyToReceiptChainHashInput!]!
}

input AddBlocksInput {
  blocks: [AddBlockInput!]!
}

type mutation {

  ... # ignoring obvious implemented mutation commands
  
  # Add a user commands into the archive database
  addTransactions(input: AddTransactionsInput!): addTransactionsPayload!

  # Add a block data into the archive database
  addBlocks(input: AddBlocksInput!): addBlocksPayload!
}

type BlockUpdate {
  block: Block!
  consensusStatus: ConsensusStatus!
  isSnarked: Bool!
}

type UserCommandUpdate {
  userCommand: UserCommandWithReceiptHash!
  consensusStatus: TransactionConsensusStatus!
  isSnarked: Bool!
}

type FeeTransferUpdate {
  block: FeeTransfer!
  consensusStatus: TransactionConsensusStatus!
  isSnarked: Bool!
}

union FollowUpdate = BlockUpdate | UserCommandUpdate | FeeTransferUpdate
  
type subscription {
  # Subscribe to sync status of the node
  newSyncUpdate: SyncStatus!
  
  # Subscribe to the blocks that a user was involved and the transactions they sent
  followUser(publicKey :PublicKey!): [FollowUpdate!]!
}
```

Below is the current schema as of 8/20/2019:

```graphql
# PageInfo object as described by the Relay connections spec
type PageInfo {
  hasPreviousPage: Boolean!
  hasNextPage: Boolean!
  firstCursor: String
  lastCursor: String
}

# Sync status of daemon
enum SyncStatus {
  BOOTSTRAP
  SYNCED
  OFFLINE
  CONNECTING
  LISTENING
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

type Transactions {
  # List of user commands (payments and stake delegations) included in this block
  userCommands: [UserCommand!]!

  # List of fee transfers included in this block
  feeTransfer: [FeeTransfer!]!

  # Amount of coda granted to the producer of this block
  coinbase: UInt64!
}

type ProtocolState {
  # Base58Check-encoded hash of the previous state
  previousStateHash: String!

  # State related to the succinct blockchain
  blockchainState: BlockchainState!
}

type Block {
  # Public key of account that produced this block
  creator: PublicKey!

  # Base58Check-encoded hash of the state after this block
  stateHash: String!
  protocolState: ProtocolState!
  transactions: Transactions!
}

input BlockFilterInput {
  # A public key of a user who has their
  #         transaction in the block, or produced the block
  relatedTo: PublicKey!
}

# Connection Edge as described by the Relay connections spec
type BlockEdge {
  # Opaque pagination cursor for a block (base58-encoded janestreet/bin_prot serialization)
  cursor: String!
  node: Block!
}

# Connection as described by the Relay connections spec
type BlockConnection {
  edges: [BlockEdge!]!
  nodes: [Block!]!
  totalCount: Int!
  pageInfo: PageInfo!
}

type PaymentUpdate {
  payment: Payment!
  consensus: ConsensusState!
}

# Status of a transaction
enum TransactionStatus {
  # A transaction that is on the longest chain
  INCLUDED

  # A transaction either in the transition frontier or in transaction pool but is not on the longest chain
  PENDING

  # The transaction has either been snarked, reached finality through consensus or has been dropped
  UNKNOWN
}

type query {
  # Network sync status
  syncStatus: SyncStatus!
  
  # Construct a proof of a payment based on the account on the best tip of the transition_frontier
  provePayment (input: String!) : PaymentProof!
  
  # Verify the proof of a payment constructed by `provePayment` based on the best tip of the transition_frontier
  verifyPayment (input: String!, resulting_receipt: String!, proof: PaymentProof!): Bool!

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

input AddPaymentReceiptInput {
  # Time that a payment gets added to another clients transaction database
  # (stringified Unix time - number of milliseconds since January 1, 1970)
  added_time: String!

  # Serialized payment (base58-encoded janestreet/bin_prot serialization)
  payment: String!
}

type AddPaymentReceiptPayload {
  payment: UserCommand!
}

type mutation {
  # ... Did not include mutations from current design since they are not used in this RFC
  
  # Add payment into transaction database
  addPaymentReceipt(input: AddPaymentReceiptInput!): AddPaymentReceiptPayload

  # ... Did not include mutations from current design since they are not used in this RFC
}

type subscription {
  # Event that triggers when the network sync status changes
  newSyncUpdate: SyncStatus!

  # Event that triggers when a new block is created that either contains a
  # transaction with the specified public key, or was produced by it
  newBlock(
    # Public key that is included in the block
    publicKey: PublicKey!
  ): Block!
}
```
