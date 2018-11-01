open Core_kernel

(** Receipt_chain_database is a data structure that stores a client's 
    transactions and their corresponding receipt_chain_hash. A client 
    uses this database to prove that they sent a transaction by showing 
    a verifier a Merkle list of their receipt chain from their latest 
    transaction to the transaction that they are trying to prove.
    
    Each account has a receipt_chain_hash field, which is a certificate 
    of all the transactions that an account has send. If an account has 
    send transactions t_n ... t_1 and p_n ... p_1 is the hash of the 
    payload of these transactions, then the receipt_chain_hash, $r_n$, 
    is equal to the following:
    
    $$ r_n = h(p_n, h(p_{n - 1}, ...)) $$
    
    where h is the hash function that determines the receipt_chain_hash 
    that takes as input the hash of a transaction payload and it's 
    preceding receipt_chain_hash.
  
    The key of the database is a receipt_chain_hash. 
    The value of the database is the transaction corresponding to the
    receipt_chain_hash *)
module type S = sig
  type t

  type receipt_chain_hash

  type transaction

  val create : directory:string -> t

  val prove :
       t
    -> proving_receipt:receipt_chain_hash
    -> resulting_receipt:receipt_chain_hash
    -> (receipt_chain_hash * transaction) list Or_error.t
  (** Prove will provide a merkle list of a proving receipt h_1 and 
      it's corresponding transaction t_1 to a resulting_receipt r_k 
      and it's corresponding transaction r_k, inclusively. Therefore, 
      the output will be in the form of [(t_1, r_1), ... (t_k, r_k)],
      where r_i = h(r_{i-1}, i_k) for i = 2...k *)

  val get_transaction : t -> receipt:receipt_chain_hash -> transaction option

  val add :
       t
    -> previous:receipt_chain_hash
    -> transaction
    -> [ `Ok of receipt_chain_hash
       | `Duplicate of receipt_chain_hash
       | `Error_multiple_previous_receipts of receipt_chain_hash ]
  (** Add stores a transaction into a client's database as a value.
      The key is computed by using the transaction payload and the previous receipt_chain_hash.
      This receipt_chain_hash is computed within the `add` function. As a result, 
      the computed receipt_chain_hash is returned *)
end

module Test = struct
  module type S = sig
    include S

    type database

    val database : t -> database
  end
end

module type Receipt_chain_hash = sig
  type t [@@deriving hash, bin_io, eq, sexp, compare]

  type transaction_payload

  val empty : t

  val cons : transaction_payload -> t -> t
end

module type Transaction = sig
  type t [@@deriving bin_io]

  type payload [@@deriving bin_io]

  val payload : t -> payload
end
