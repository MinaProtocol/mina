open Core
open Import

include
  Merkle_ledger.Merkle_ledger_intf.S
  with type root_hash := Ledger_hash.t
   and type hash := Merkle_hash.t
   and type account := Account.t
   and type key := Public_key.Compressed.t

module Undo : sig
  type transaction =
    { transaction: Transaction.t
    ; previous_empty_accounts: Public_key.Compressed.t list
    ; previous_receipt_chain_hash: Receipt.Chain_hash.t }
  [@@deriving sexp, bin_io]

  type fee_transfer =
    { fee_transfer: Fee_transfer.t
    ; previous_empty_accounts: Public_key.Compressed.t list }
  [@@deriving sexp, bin_io]

  type coinbase =
    { coinbase: Coinbase.t
    ; previous_empty_accounts: Public_key.Compressed.t list }
  [@@deriving sexp, bin_io]

  type varying =
    | Transaction of transaction
    | Fee_transfer of fee_transfer
    | Coinbase of coinbase
  [@@deriving sexp, bin_io]

  type t = {previous_hash: Ledger_hash.t; varying: varying}
  [@@deriving sexp, bin_io]

  val super_transaction : t -> Super_transaction.t Or_error.t
end

val create_new_account_exn : t -> Public_key.Compressed.t -> Account.t -> unit

val apply_transaction :
  t -> Super_transaction.transaction -> Undo.transaction Or_error.t

val apply_super_transaction : t -> Super_transaction.t -> Undo.t Or_error.t

val undo : t -> Undo.t -> unit Or_error.t

val merkle_root_after_transaction_exn :
  t -> Super_transaction.transaction -> Ledger_hash.t

val create_empty : t -> Public_key.Compressed.t -> Path.t * Account.t
