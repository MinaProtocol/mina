open Core_kernel

module Hashless_ledger : Transaction_logic.Ledger_intf

val create : Ledger.t -> Hashless_ledger.t

val apply_user_command :
  Hashless_ledger.t -> User_command.With_valid_signature.t -> unit Or_error.t

val apply_transaction : Hashless_ledger.t -> Transaction.t -> unit Or_error.t
