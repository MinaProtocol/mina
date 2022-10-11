open Core_kernel
open Mina_base
open Mina_transaction

module Hashless_ledger : Ledger_intf.S

val create : Mina_ledger.Ledger.t -> Hashless_ledger.t

val apply_user_command :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_global_slot:Mina_numbers.Global_slot.t
  -> Hashless_ledger.t
  -> Signed_command.With_valid_signature.t
  -> Transaction_status.t Or_error.t

val apply_transaction :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_state_view:Zkapp_precondition.Protocol_state.View.t
  -> Hashless_ledger.t
  -> Transaction.t
  -> Transaction_status.t Or_error.t

val apply_zkapp_fee_payer :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_state_view:Zkapp_precondition.Protocol_state.View.t
  -> Hashless_ledger.t
  -> Zkapp_command.t
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
    -> (Account.Timing.t * [> `Min_balance of Balance.t ]) Or_error.t

  val validate_timing :
       account:Account.t
    -> txn_amount:Amount.t
    -> txn_global_slot:Global_slot.t
    -> Account.Timing.t Or_error.t
end
