open Core_kernel

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

  val get_transaction : t -> receipt:receipt_chain_hash -> transaction option

  val add :
       t
    -> previous:receipt_chain_hash
    -> transaction
    -> [ `Ok of receipt_chain_hash
       | `Duplicate of receipt_chain_hash
       | `Error_multiple_previous_receipts of receipt_chain_hash ]
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
