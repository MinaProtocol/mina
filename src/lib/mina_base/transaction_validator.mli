open Core_kernel

module Hashless_ledger : Transaction_logic.Ledger_intf

val create : Ledger.t -> Hashless_ledger.t

val apply_user_command :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_global_slot:Mina_numbers.Global_slot.t
  -> Hashless_ledger.t
  -> Signed_command.With_valid_signature.t
  -> Transaction_status.t Or_error.t

val apply_transaction :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_state_view:Snapp_predicate.Protocol_state.View.t
  -> Hashless_ledger.t
  -> Transaction.t
  -> Transaction_status.t Or_error.t

val has_locked_tokens :
     global_slot:Mina_numbers.Global_slot.t
  -> account_id:Account_id.t
  -> Hashless_ledger.t
  -> bool Or_error.t

module For_tests : sig
  open Currency
  open Mina_numbers

  val validate_timing_with_min_balance :
       account:Account.t
    -> txn_amount:Amount.t
    -> txn_global_slot:Global_slot.t
    -> (Account.Timing.t * [> `Min_balance of Balance.t]) Or_error.t

  val validate_timing :
       account:Account.t
    -> txn_amount:Amount.t
    -> txn_global_slot:Global_slot.t
    -> Account.Timing.t Or_error.t
end
