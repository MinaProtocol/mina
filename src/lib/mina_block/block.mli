open Mina_base
open Mina_transaction

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V2 : sig
    type t [@@deriving sexp, to_yojson, equal]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, to_yojson, equal]

type with_hash = t State_hash.With_state_hashes.t [@@deriving sexp]

(* TODO: interface for both unchecked and checked construction of blocks *)
(* check version needs to run following checks:
     - Header.verify (could be separated into header construction)
     - Consensus.Body_reference.verify_reference header.body_reference body
     - Staged_ledger_diff.Body.verify (cannot be put into body construction as we should do the reference check first, but could be separated) *)

val wrap_with_hash : t -> with_hash

val create : header:Header.t -> body:Staged_ledger_diff.Body.t -> t

val header : t -> Header.t

val body : t -> Staged_ledger_diff.Body.t

val timestamp : t -> Block_time.t

val transactions :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> t
  -> Transaction.t With_status.t list

val payments : t -> Signed_command.t With_status.t list

val account_ids_accessed : t -> Account_id.t list
