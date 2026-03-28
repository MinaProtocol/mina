[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t = { staged_ledger_diff : Diff.Stable.V2.t } [@@deriving equal, sexp]

    val create : Diff.Stable.V2.t -> t

    val staged_ledger_diff : t -> Diff.Stable.V2.t
  end
end]

module Serializable_type : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = { staged_ledger_diff : Diff.Serializable_type.Stable.V2.t }
    end
  end]

  val create : Diff.Serializable_type.t -> t
end

type t

val create : Diff.t -> t

val staged_ledger_diff : t -> Diff.t

val to_binio_bigstring : Stable.V1.t -> Core_kernel.Bigstring.t

val compute_reference :
  tag:int -> Serializable_type.t -> Consensus.Body_reference.t

val write_all_proofs_to_disk :
     signature_kind:Mina_signature_kind.t
  -> proof_cache_db:Proof_cache_tag.cache_db
  -> Stable.Latest.t
  -> t

val read_all_proofs_from_disk : t -> Stable.Latest.t

val to_serializable_type : t -> Serializable_type.t
