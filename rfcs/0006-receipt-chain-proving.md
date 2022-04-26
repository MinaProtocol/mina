# Summary
[summary]: #summary

A method for a client to prove that they sent a transaction by showing a verifier a Merkle list of their receipt chain from their latest transaction to the transaction that they are trying to prove. For this RFC, a Merkle list contains a list of hashes such that the property that for an arbitrary hash in the list, `h`, there exists a value x, such that $h = hash(x, h.prev) $

# Motivation
[motivation]: #motivation

We are constructing a cryptocurrency protocol and verifying the state of our succinct blockchain takes constant time. As a consequence of achieving this constant-time lookup, we do not keep a record of the transactions that occur throughout the history of the protocol.

In some cases, it would be helpful to have a client prove that their transaction made it into the blockchain. This is particularly useful if a client wants to prove that they sent a large sum of money to a receiver.

# Design
[detailed-design]: #detailed-design

Each account has a `receipt_chain_hash` field, which is a certificate of all the transactions that an account has send. If an account has send transactions `t_n ... t_1` and `p_n ... p_1` is the hash of the payload of these transactions, then the `receipt_chain_hash`, $r_n$, is equal to the following:

  $$ r_n = h(p_n, h(p_{n - 1}, ...)) $$

where `h` is the hash function that determines the `receipt_chain_hash` that takes as input the hash of a transaction payload and it's preceding `receipt_chain_hash`.

For the base case, $ r_0 $ equals to the empty hash for `receipt_chain_hash`.

A client can prove that they sent transaction `t_k` if they store the Merkle list of `r_k` to their most recent `receipt_chain_hash`, `r_n`. We do this because any verifier can look up the current state of the blockchain and see that their `receipt_chain_hash` is `r_n`. Then, they can recursively show that $r_i = h (t_{i}, r_{i-1})$ until $r_{k}$.

The client needs to store these transactions and receipt hashes and the data should be persisted after the client disconnects from the network. At the same time, the client needs to easily traverse the transactions and receipt chain hashes that lead to the current state of the blockchain. A client can easily achieve this by using a key-value database. The keys of the database are the receipt hash and the value has the following fields:

```ocaml
type value = Root | Child of {parent: receipt_chain_hash; value: transaction}
```

The value entry can be seen as a tree node structure that refers to the previous receipt hash that use the key. Note that transactions can fork from other transactions and the key-value entries can simulate this since multiple tree nodes can refer to the same `prev_node`. The node also holds the transaction that was last hashed to produce the key hash. From the hash that we are trying to prove, `resulting_receipt`, we can iteratively traverse down to `parent` to find the `receipt` that are trying to prove. Note that these nodes form an acyclic structure since a hashing function should be collision-free.

The signature for this structure can look like the following:

```ocaml
module type Receipt_chain_database_intf = sig
  type receipt_chain_hash [@@deriving bin_io, hash]

  type transaction [@@deriving bin_io]

  val prove :  proving_receipt:receipt_chain -> resulting_receipt:receipt_chain -> (receipt_chain * transaction) list Or_error.t

  val add : previous:receipt_chain
  -> transaction
  -> [ `Ok of receipt_chain_hash
     | `Duplicate of receipt_chain_hash
     | `Error_multiple_previous_receipts of receipt_chain_hash ]
end
```

`prove` will provide a merkle list of a proving receipt `h_1` and its corresponding transaction `t_1` to a resulting_receipt `r_k` and its corresponding transaction `t_k`, inclusively. Therefore, the output will be in the form of [(t_1, r_1), ... (t_k, r_k)], where $r_i = h(t_{i}, r_{i-1})$ for $i = 2...k$

`add` stores a transaction into a client's database as a value. The key is computed by using the transaction payload and the previous receipt_chain_hash. This receipt_chain_hash is computed within the `add` function. As a result, the computed `receipt_chain_hash` is returned


# Drawbacks
[drawbacks]: #drawbacks

The issue with this design is that a client has to keep a record of all the transactions that they have sent to prove that they sent a certain transaction. This can be infeasible if the user sends many transactions. On top of this, they have to show a Merkle list of the transaction that they are interested in proving to the latest transaction. This can take O(n), where `n` is the number of transactions a sender has sent.

Another drawback of this is that it assumes that a peer will send transactions from one machine. Whenever a node sends transactions on multiple machines, they can sync up together their machines and share which transactions they have sent.

The simplest solution to achieve this sync for users is to store their data in a cloud database, such as Amazon's [RDS](https://aws.amazon.com/rds/) and [AppSync](https://aws.amazon.com/appsync/). We can create a wrapper for querying and writing to the database that conforms to the schema of our database requirements and the user hooks up their cloud database to our wrapper. A user can also store their data locally as a cache so that they can make fewer calls to their cloud database.

# Prior Art
[prior-art]: #prior-art

In Bitcoin, a sender can prove that their transaction is in a block. This can be a confirmation. Once a block is mined on top of another block, there will be 2 confirmations that this transaction is valid. If there is another block on top of that block, there will be 3 confirmations for that block. Typically, if a transaction has 6 confirmation, there is an extremely low chance that the bitcoin network will fork and ignore the existence of the transaction.

# Unresolved Questions
[unresolved-questions]: #unresolved-questions

What are some other protocols that we can use to sync receipt chain database from multiple servers?

How do we prune forked transaction paths?

