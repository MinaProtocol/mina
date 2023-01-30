open Core_kernel

val apply_user_command :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_global_slot:Mina_numbers.Global_slot.t
  -> Ledger.t
  -> Signed_command.With_valid_signature.t
  -> Transaction_status.t Or_error.t

val apply_transaction :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_state_view:Snapp_predicate.Protocol_state.View.t
  -> Ledger.t
  -> Transaction.t
  -> Transaction_status.t Or_error.t
