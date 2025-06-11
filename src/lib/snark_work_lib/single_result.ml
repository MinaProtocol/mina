open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('single_spec, 'proof) t =
        { spec : 'single_spec
        ; proof : 'proof
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

  module V1 = struct
    type t =
      (Single_spec.Stable.V1.t, Ledger_proof.Stable.V2.t) Poly.Stable.V1.t

    let to_latest = Fn.id
  end
end]

type t = (Single_spec.t, Ledger_proof.Cached.t) Poly.t

let read_all_proofs_from_disk : t -> Stable.Latest.t =
  Poly.map ~f_spec:Single_spec.read_all_proofs_from_disk
    ~f_proof:Ledger_proof.Cached.read_proof_from_disk

let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
    Stable.Latest.t -> t =
  Poly.map
    ~f_spec:(Single_spec.write_all_proofs_to_disk ~proof_cache_db)
    ~f_proof:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
