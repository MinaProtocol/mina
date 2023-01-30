open Core_kernel
open Mina_base
open Mina_transaction

val apply_user_command :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_global_slot:Mina_numbers.Global_slot.t
  -> Mina_ledger.Ledger.t
  -> Signed_command.With_valid_signature.t
  -> Transaction_status.t Or_error.t

val apply_transaction :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> global_slot:Mina_numbers.Global_slot.t
  -> txn_state_view:Zkapp_precondition.Protocol_state.View.t
  -> Mina_ledger.Ledger.t
  -> Transaction.t
  -> Transaction_status.t Or_error.t
