open Mina_base

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t [@@deriving compare, sexp, to_yojson]
  end
end]

type t = Stable.Latest.t [@@deriving compare, sexp, to_yojson]

type with_hash = t State_hash.With_state_hashes.t [@@deriving sexp]

(* TODO: interface for both unchecked and checked construction of blocks *)
(* check version needs to run following checks:
     - Header.verify (could be separated into header construction)
     - Body_reference.verify_reference header.body_reference body
     - Body.verify (cannot be put into body construction as we should do the reference check first, but could be separated) *)

val wrap_with_hash : t -> with_hash

val create : header:Header.t -> body:Body.t -> t

val header : t -> Header.t

val body : t -> Body.t

val timestamp : t -> Block_time.t

val transactions :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> t
  -> Transaction.t With_status.t list

val payments : t -> Signed_command.t With_status.t list

val equal : t -> t -> bool
