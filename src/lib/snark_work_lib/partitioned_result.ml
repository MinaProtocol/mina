open Core_kernel

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      ( unit
      , unit
      , ( Core.Time.Stable.Span.V1.t
        , Ledger_proof.Stable.V2.t )
        Proof_carrying_data.Stable.V1.t )
      Partitioned_spec.Poly.Stable.V1.t

    let to_latest = Fn.id
  end
end]
