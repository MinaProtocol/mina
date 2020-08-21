open Core_kernel

module Hashless_ledger : Transaction_logic.Ledger_intf

val create : Ledger.t -> Hashless_ledger.t

val apply_user_command :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_global_slot:Coda_numbers.Global_slot.t
  -> Hashless_ledger.t
  -> User_command.With_valid_signature.t
  -> User_command_status.t Or_error.t

val apply_transaction :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_global_slot:Coda_numbers.Global_slot.t
  -> Hashless_ledger.t
  -> Transaction.t
  -> User_command_status.t Or_error.t

module For_tests : sig
  open Currency
  open Coda_numbers

  val validate_timing :
       account:Account.t
    -> txn_amount:Amount.t
    -> txn_global_slot:Global_slot.t
    -> Account.Timing.t Or_error.t
end
