open Core_kernel

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      ( Transaction_witness.Stable.V2.t
      , Ledger_proof.Stable.V2.t
      , Sub_zkapp_spec.Stable.V1.t
      , ( Core.Time.Stable.Span.V1.t
        , Ledger_proof.Stable.V2.t )
        Proof_carrying_data.Stable.V1.t )
      Partitioned_spec.Poly.Stable.V1.t

    val to_latest : t -> t
  end
end]

type t =
  ( Transaction_witness.t
  , Ledger_proof.Cached.t
  , Sub_zkapp_spec.t
  , (Core.Time.Span.t, Ledger_proof.Cached.t) Proof_carrying_data.t )
  Partitioned_spec.Poly.Stable.V1.t

val read_all_proofs_from_disk : t -> Stable.Latest.t

val write_all_proofs_to_disk :
  proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t
