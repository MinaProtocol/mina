open Core_kernel
open Snark_params.Tick

[%%versioned:
module Stable : sig
  module V2 : sig
    type t =
      ( Ledger_hash.Stable.V1.t
      , Account_id.Stable.V1.t
      , Account.Stable.V2.t
      , Token_id.Stable.V1.t )
      Sparse_ledger_lib.Sparse_ledger.T.Stable.V1.t
    [@@deriving sexp, to_yojson]

    val to_latest : t -> t
  end

  module V1 : sig
    type t =
      ( Ledger_hash.Stable.V1.t
      , Account_id.Stable.V1.t
      , Account.Stable.V1.t
      , Token_id.Stable.V1.t )
      Sparse_ledger_lib.Sparse_ledger.T.Stable.V1.t
    [@@deriving sexp, to_yojson]

    val to_latest : t -> V2.t
  end
end]

type sparse_ledger = t

module Global_state : sig
  type t =
    { ledger : sparse_ledger
    ; fee_excess : Currency.Amount.Signed.t
    ; protocol_state : Snapp_predicate.Protocol_state.View.t
    }
  [@@deriving sexp, to_yojson]
end

val merkle_root : t -> Ledger_hash.t

val depth : t -> int

val next_available_token : t -> Token_id.t

val get_exn : t -> int -> Account.t

val set_exn : t -> int -> Account.t -> t

val path_exn :
  t -> int -> [ `Left of Ledger_hash.t | `Right of Ledger_hash.t ] list

val find_index_exn : t -> Account_id.t -> int

val of_root : depth:int -> next_available_token:Token_id.t -> Ledger_hash.t -> t

(** Create a new 'empty' ledger.
    This ledger has an invalid root hash, and cannot be used except as a
    placeholder.
*)
val empty : depth:int -> unit -> t

val apply_user_command_exn :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_global_slot:Mina_numbers.Global_slot.t
  -> t
  -> Signed_command.t
  -> t

val apply_transaction_exn :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_state_view:Snapp_predicate.Protocol_state.View.t
  -> t
  -> Transaction.t
  -> t

(** Apply all parties within a parties transaction, accumulating the
    intermediate (global, local) state pairs, in order from first to last
    party.
*)
val apply_parties_unchecked_with_states :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> state_view:Snapp_predicate.Protocol_state.View.t
  -> fee_excess:Currency.Amount.Signed.t
  -> t
  -> Parties.t
  -> ( Transaction_logic.Transaction_applied.Parties_applied.t
     * ( Global_state.t
       * ( (Party.t, unit) Parties.Party_or_stack.t list
         , Token_id.t
         , Currency.Amount.t
         , t
         , bool
         , unit )
         Parties_logic.Local_state.t )
       list )
     Or_error.t

val add_path :
     t
  -> [ `Left of Field.t | `Right of Field.t ] list
  -> Account_id.t
  -> Account.t
  -> t

val iteri : t -> f:(Account.Index.t -> Account.t -> unit) -> unit

val handler : t -> Handler.t Staged.t

val has_locked_tokens_exn :
  global_slot:Mina_numbers.Global_slot.t -> account_id:Account_id.t -> t -> bool

module L :
  Transaction_logic.Ledger_intf
    with type t = Stable.Latest.t ref
     and type location = int
