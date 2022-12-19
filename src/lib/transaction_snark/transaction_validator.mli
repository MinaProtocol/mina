open Core_kernel
open Mina_base

module Hashless_ledger : Ledger_intf.S

include module type of Mina_transaction_logic.Make (Hashless_ledger)

val create : Mina_ledger.Ledger.t -> Hashless_ledger.t

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
