open Core_kernel
open Snark_params.Tick

[%%versioned:
module Stable : sig
  module V2 : sig
    type t =
      ( Ledger_hash.Stable.V1.t
      , Account_id.Stable.V2.t
      , Account.Stable.V2.t )
      Sparse_ledger_lib.Sparse_ledger.T.Stable.V2.t
    [@@deriving sexp, to_yojson]

    val to_latest : t -> t
  end
end]

type sparse_ledger = t

module Global_state : sig
  type t =
    { first_pass_ledger : sparse_ledger
    ; second_pass_ledger : sparse_ledger
    ; fee_excess : Currency.Amount.Signed.t
    ; protocol_state : Zkapp_precondition.Protocol_state.View.t
    }
  [@@deriving sexp, to_yojson]
end

module L : Ledger_intf.S with type t = t ref and type location = int

val merkle_root : t -> Ledger_hash.t

val depth : t -> int

val get_exn : t -> int -> Account.t

val set_exn : t -> int -> Account.t -> t

val path_exn :
  t -> int -> [ `Left of Ledger_hash.t | `Right of Ledger_hash.t ] list

val find_index_exn : t -> Account_id.t -> int

val of_root : depth:int -> Ledger_hash.t -> t

(** Create a new 'empty' ledger.
    This ledger has an invalid root hash, and cannot be used except as a
    placeholder.
*)
val empty : depth:int -> unit -> t

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
