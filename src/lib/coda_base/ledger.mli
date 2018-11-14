open Core
open Import

include
  Merkle_ledger.Merkle_ledger_intf.S
  with type root_hash := Ledger_hash.t
   and type hash := Merkle_hash.t
   and type account := Account.t
   and type key := Public_key.Compressed.t

module Undo : sig
  type user_command =
    { user_command: User_command.t
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
    | User_command of user_command
    | Fee_transfer of fee_transfer
    | Coinbase of coinbase
  [@@deriving sexp, bin_io]

  type t = {previous_hash: Ledger_hash.t; varying: varying}
  [@@deriving sexp, bin_io]

  val transaction : t -> Transaction.t Or_error.t
end

val create_new_account_exn : t -> Public_key.Compressed.t -> Account.t -> unit

val apply_user_command :
  t -> User_command.With_valid_signature.t -> Undo.user_command Or_error.t

val apply_transaction : t -> Transaction.t -> Undo.t Or_error.t

val undo : t -> Undo.t -> unit Or_error.t

val merkle_root_after_user_command_exn :
  t -> User_command.With_valid_signature.t -> Ledger_hash.t

val create_empty : t -> Public_key.Compressed.t -> Path.t * Account.t
