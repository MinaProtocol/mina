open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'proof t = { proof : 'proof; elapsed : Core.Time.Stable.Span.V1.t }
    end
  end]
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t = Ledger_proof.Stable.V2.t Poly.Stable.V1.t

    let to_latest = Fn.id
  end
end]

type t = Ledger_proof.Cached.t Poly.t

let read_all_proofs_from_disk ({ proof; elapsed } : t) : Stable.Latest.t =
  let proof = Ledger_proof.Cached.read_proof_from_disk proof in
  { proof; elapsed }

let write_all_proofs_to_disk ~proof_cache_db
    ({ proof; elapsed } : Stable.Latest.t) : t =
  let proof = Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof in
  { proof; elapsed }
