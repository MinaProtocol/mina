open Core_kernel

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      ( unit
      , unit
      , ( Core.Time.Stable.Span.V1.t
        , Ledger_proof.Stable.V2.t )
        Proof_carrying_data.Stable.V1.t )
      Partitioned_spec.Poly.Stable.V1.t

    val to_latest : t -> t
  end
end]
