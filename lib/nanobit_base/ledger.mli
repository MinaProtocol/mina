open Core
open Import

include Merkle_ledger.Merkle_ledger_intf.S
        with type root_hash := Ledger_hash.t
         and type hash := Merkle_hash.t
         and type account := Account.t
         and type key := Public_key.Compressed.t

module Undo : sig
  type transaction =
    { transaction: Transaction.t
    ; previous_receipt_chain_hash: Receipt.Chain_hash.t }
  [@@deriving sexp]

  type t =
    | Transaction of transaction
    | Fee_transfer of Fee_transfer.t
    | Coinbase of Coinbase.t
  [@@deriving sexp]
end

val create_new_account_exn : t -> Public_key.Compressed.t -> Account.t -> unit

val apply_super_transaction : t -> Super_transaction.t -> Undo.t Or_error.t

val undo : t -> Undo.t -> unit Or_error.t

val merkle_root_after_transaction_exn :
  t -> Super_transaction.transaction -> Ledger_hash.t
