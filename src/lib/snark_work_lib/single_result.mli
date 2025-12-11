open Core_kernel

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('single_spec, 'proof) t =
        { spec : 'single_spec
        ; proof : 'proof
        ; elapsed : Mina_stdlib.Time.Span.Stable.V1.t
        }
      [@@deriving to_yojson]
    end
  end]

  val map : f_spec:('a -> 'b) -> f_proof:('c -> 'd) -> ('a, 'c) t -> ('b, 'd) t
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      (Single_spec.Stable.V1.t, Ledger_proof.Stable.V2.t) Poly.Stable.V1.t

    val to_latest : t -> t
  end
end]

type t = (Single_spec.t, Ledger_proof.t) Poly.t
