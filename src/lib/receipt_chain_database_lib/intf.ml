open Core_kernel

(** Receipt_chain_database is a data structure that stores a client's 
    payments and their corresponding receipt_chain_hash. A client 
    uses this database to prove that they sent a payment by showing 
    a verifier a Merkle list of their payment from their latest 
    payment to the payment that they are trying to prove.
    
    Each account has a receipt_chain_hash field, which is a certificate 
    of all the payments that an account has send. If an account has 
    send payments p_n ... p_1 and h_n ... h_1 is the hash of the 
    payload of these payments, then the receipt_chain_hash, $r_n$, 
    is equal to the following:
    
    $$ r_n = H(h_n, H(h_{n - 1}, ...)) $$
    
    where H is the hash function that determines the receipt_chain_hash 
    that takes as input the hash of a payment payload and it's 
    preceding receipt_chain_hash.
  
    The key of the database is a receipt_chain_hash. 
    The value of the database is the payment corresponding to the
    receipt_chain_hash *)
module type Database = sig
  type t

  type receipt_chain_hash

  type payment

  val create : directory:string -> t

  val prove :
       t
    -> proving_receipt:receipt_chain_hash
    -> resulting_receipt:receipt_chain_hash
    -> (receipt_chain_hash, payment) Payment_proof.t Or_error.t
  (** Prove will provide a proof of a proving_receipt hash up to an underlying 
      resulting_receipt hash. The proof will consist of a initial_receipt as
      proving_receipt and a list of payments leading to resulting_receipt *)

  val get_payment : t -> receipt:receipt_chain_hash -> payment option

  val add :
       t
    -> previous:receipt_chain_hash
    -> payment
    -> [ `Ok of receipt_chain_hash
       | `Duplicate of receipt_chain_hash
       | `Error_multiple_previous_receipts of receipt_chain_hash ]
  (** Add stores a payment into a client's database as a value.
      The key is computed by using the payment payload and the previous receipt_chain_hash.
      This receipt_chain_hash is computed within the `add` function. As a result, 
      the computed receipt_chain_hash is returned *)
end

module type Verifier = sig
  type receipt_chain_hash

  type payment

  val verify :
       resulting_receipt:receipt_chain_hash
    -> (receipt_chain_hash, payment) Payment_proof.t
    -> unit Or_error.t
end

module Test = struct
  module type S = sig
    include Database

    type database

    val database : t -> database
  end
end

module type Receipt_chain_hash = sig
  type t [@@deriving hash, bin_io, eq, sexp, compare]

  type payment_payload

  val empty : t

  val cons : payment_payload -> t -> t
end

module type Payment = sig
  type t

  module Payload : sig
    type t
  end

  val payload : t -> Payload.t
end
