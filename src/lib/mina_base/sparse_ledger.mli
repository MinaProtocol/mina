open Core
open Snark_params.Tick

[%%versioned:
module Stable : sig
  module V1 : sig
    type t =
      ( Ledger_hash.Stable.V1.t
      , Account_id.Stable.V1.t
      , Account.Stable.V1.t
      , Token_id.Stable.V1.t )
      Sparse_ledger_lib.Sparse_ledger.T.Stable.V1.t
    [@@deriving sexp, yojson]
  end
end]

module L :
  Transaction_logic.Ledger_intf with type t = t ref and type location = int

val merkle_root : t -> Ledger_hash.t

val depth : t -> int

val next_available_token : t -> Token_id.t

val get_exn : t -> int -> Account.t

val path_exn :
  t -> int -> [ `Left of Ledger_hash.t | `Right of Ledger_hash.t ] list

val find_index_exn : t -> Account_id.t -> int

val of_root :
     depth:int
  -> next_available_token:Token_id.t
  -> next_available_index:int option
  -> Ledger_hash.t
  -> t

val has_locked_tokens_exn :
  global_slot:Mina_numbers.Global_slot.t -> account_id:Account_id.t -> t -> bool

val apply_user_command :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_global_slot:Mina_numbers.Global_slot.t
  -> t
  -> Signed_command.With_valid_signature.t
  -> (t * Transaction_logic.Transaction_applied.Signed_command_applied.t)
     Or_error.t

val apply_transaction' :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_state_view:Snapp_predicate.Protocol_state.View.t
  -> t ref
  -> Transaction.t
  -> Transaction_logic.Transaction_applied.t Or_error.t

val apply_transaction :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_state_view:Snapp_predicate.Protocol_state.View.t
  -> t
  -> Transaction.t
  -> (t * Transaction_logic.Transaction_applied.t) Or_error.t

val of_any_ledger : Ledger.Any_ledger.M.t -> t

val of_ledger_subset_exn : Ledger.t -> Account_id.t list -> t

val of_ledger_index_subset_exn : Ledger.Any_ledger.witness -> int list -> t

val of_sparse_ledger_subset_exn : t -> Account_id.t list -> t

(* TODO: erase Account_id.t from here (doesn't make sense to have it) *)
val data : t -> (int * Account.t) list

val iteri : t -> f:(Account.Index.t -> Account.t -> unit) -> unit

val handler : t -> Handler.t Staged.t

val snapp_accounts :
  t -> Transaction.t -> Snapp_account.t option * Snapp_account.t option
