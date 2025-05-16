open Core_kernel

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      ( Transaction_witness.Stable.V2.t
      , Ledger_proof.Stable.V2.t
      , Sub_zkapp_spec.Stable.V1.t
      , ( Core.Time.Stable.Span.V1.t
        , Ledger_proof.Stable.V2.t )
        Proof_carrying_data.Stable.V1.t )
      Partitioned_spec.Poly.Stable.V1.t

    let to_latest = Fn.id
  end
end]

type t =
  ( Transaction_witness.t
  , Ledger_proof.Cached.t
  , Sub_zkapp_spec.t
  , (Core.Time.Span.t, Ledger_proof.Cached.t) Proof_carrying_data.t )
  Partitioned_spec.Poly.Stable.V1.t

let read_all_proofs_from_disk : t -> Stable.Latest.t =
  Partitioned_spec.Poly.map
    ~f_witness:Transaction_witness.read_all_proofs_from_disk
    ~f_subzkapp_spec:Sub_zkapp_spec.read_all_proofs_from_disk
    ~f_proof:Ledger_proof.Cached.read_proof_from_disk
    ~f_data:
      (Proof_carrying_data.map_proof ~f:Ledger_proof.Cached.read_proof_from_disk)

let write_all_proofs_to_disk ~proof_cache_db : Stable.Latest.t -> t =
  Partitioned_spec.Poly.map
    ~f_witness:(Transaction_witness.write_all_proofs_to_disk ~proof_cache_db)
    ~f_subzkapp_spec:(Sub_zkapp_spec.write_all_proofs_to_disk ~proof_cache_db)
    ~f_proof:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
    ~f_data:
      (Proof_carrying_data.map_proof
         ~f:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db) )
