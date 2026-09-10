open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('single_spec, 'proof) t =
        { spec : 'single_spec
        ; proof : 'proof
              (* This elapsed time is the work time taken to prove everything in the spec, assuming we have only a single CPU. *)
        ; elapsed : Mina_stdlib.Time.Span.Stable.V1.t
        }
      [@@deriving to_yojson]
    end
  end]

  let map ~f_spec ~f_proof { spec; proof; elapsed } =
    { spec = f_spec spec; proof = f_proof proof; elapsed }
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      (Single_spec.Stable.V2.t, Ledger_proof.Stable.V2.t) Poly.Stable.V1.t

    let to_latest = Fn.id
  end
end]

type t = (Single_spec.t, Ledger_proof.Cached.t) Poly.t
