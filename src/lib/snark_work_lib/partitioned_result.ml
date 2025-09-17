open Core_kernel

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      { id : Id.Any.Stable.V1.t
      ; data :
          (* NOTE: the time here correspond to time elapsed for creating the
             proof by a worker *)
          ( Mina_stdlib.Time.Span.Stable.V1.t
          , Ledger_proof.Stable.V2.t )
          Proof_carrying_data.Stable.V1.t
      }
    [@@deriving to_yojson]

    let to_latest = Fn.id
  end
end]

type t =
  { id : Id.Any.t
  ; data : (Core.Time.Span.t, Ledger_proof.Cached.t) Proof_carrying_data.t
  }

let read_all_proofs_from_disk : t -> Stable.Latest.t = function
  | { id; data } ->
      { id
      ; data =
          Proof_carrying_data.map_proof
            ~f:Ledger_proof.Cached.read_proof_from_disk data
      }

let write_all_proofs_to_disk ~proof_cache_db : Stable.Latest.t -> t = function
  | { id; data } ->
      { id
      ; data =
          Proof_carrying_data.map_proof
            ~f:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
            data
      }
