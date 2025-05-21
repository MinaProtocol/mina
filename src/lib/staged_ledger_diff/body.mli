[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t = { staged_ledger_diff : Diff.Stable.V2.t } [@@deriving equal, sexp]

    val create : Diff.Stable.V2.t -> t

    val staged_ledger_diff : t -> Diff.Stable.V2.t
  end
end]

type t

val create : Diff.t -> t

val staged_ledger_diff : t -> Diff.t

val to_binio_bigstring : Stable.V1.t -> Core_kernel.Bigstring.t

val compute_reference : tag:int -> Stable.V1.t -> Consensus.Body_reference.t

val write_all_proofs_to_disk :
  proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t

val read_all_proofs_from_disk : t -> Stable.Latest.t
