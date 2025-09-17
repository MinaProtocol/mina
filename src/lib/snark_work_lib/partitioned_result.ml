open Core_kernel

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      ( unit
      , unit
      , ( Mina_stdlib.Time.Span.Stable.V1.t
        , Ledger_proof.Stable.V2.t )
        Proof_carrying_data.Stable.V1.t )
      Partitioned_spec.Poly.Stable.V1.t
    [@@deriving to_yojson]

    let to_latest = Fn.id
  end
end]

type t =
  ( unit
  , unit
  , (Core.Time.Span.t, Ledger_proof.Cached.t) Proof_carrying_data.t )
  Partitioned_spec.Poly.Stable.V1.t