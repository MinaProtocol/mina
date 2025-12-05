open Core_kernel

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      { id : Id.Any.Stable.V1.t
      ; data :
          ( Mina_stdlib.Time.Span.Stable.V1.t
          , Ledger_proof.Stable.V2.t )
          Proof_carrying_data.Stable.V1.t
      }
    [@@deriving to_yojson]

    val to_latest : t -> t
  end
end]

type t =
  { id : Id.Any.t
  ; data : (Core.Time.Span.t, Ledger_proof.Cached.t) Proof_carrying_data.t
  }
