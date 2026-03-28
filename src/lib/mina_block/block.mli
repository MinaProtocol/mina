open Mina_base
open Mina_transaction

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V2 : sig
    type t [@@deriving sexp, equal]

    val header : t -> Header.Stable.V2.t

    val body : t -> Staged_ledger_diff.Body.Stable.V1.t

    val transactions :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> t
      -> Transaction.Stable.V2.t With_status.t list
  end
end]

module Serializable_type : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t

      val header : t -> Header.Stable.V2.t

      val body : t -> Staged_ledger_diff.Body.Serializable_type.t

      val transactions :
           constraint_constants:Genesis_constants.Constraint_constants.t
        -> t
        -> Transaction.Serializable_type.t With_status.t list
    end
  end]
end

type t

val to_logging_yojson : Header.t -> Yojson.Safe.t

type with_hash = t State_hash.With_state_hashes.t

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

val account_ids_accessed :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> t
  -> (Account_id.t * [ `Accessed | `Not_accessed ]) list

val write_all_proofs_to_disk :
     signature_kind:Mina_signature_kind.t
  -> proof_cache_db:Proof_cache_tag.cache_db
  -> Stable.Latest.t
  -> t

val read_all_proofs_from_disk : t -> Stable.Latest.t

val to_serializable_type : t -> Serializable_type.t
