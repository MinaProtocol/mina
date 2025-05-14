open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('witness, 'zkapp_command_segment_witness, 'ledger_proof, 'metric) t =
        { (* Throw everything inside the spec to ensure proofs, metrics have correct shape *)
          data :
            ( 'witness
            , 'zkapp_command_segment_witness
            , 'ledger_proof
            , 'metric )
            Full_spec.Poly.Stable.V1.t
        ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
        }
    end
  end]

  let to_spec ({ data; _ } : _ t) : _ Full_spec.Poly.t =
    match data with
    | Full_spec.Poly.Single { job; _ } ->
        Full_spec.Poly.Single { job; data = () }
    | Full_spec.Poly.Sub_zkapp_command { job; _ } ->
        Full_spec.Poly.Sub_zkapp_command { job; data = () }

  let map ~f_witness ~f_zkapp_command_segment_witness ~f_proof ~f_data
      ({ data; prover } : _ t) =
    { data =
        Full_spec.Poly.map ~f_witness ~f_zkapp_command_segment_witness ~f_proof
          ~f_data data
    ; prover
    }
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      ( Transaction_witness.Stable.V2.t
      , Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
      , Ledger_proof.Stable.V2.t
      , ( Core.Time.Stable.Span.V1.t
        , Ledger_proof.Stable.V2.t )
        Proof_carrying_data.Stable.V1.t )
      Poly.Stable.V1.t

    let to_latest = Fn.id
  end
end]

type t =
  ( Transaction_witness.t
  , Transaction_snark.Zkapp_command_segment.Witness.t
  , Ledger_proof.Cached.t
  , (Core.Time.Span.t, Ledger_proof.Cached.t) Proof_carrying_data.t )
  Poly.t

let read_all_proofs_from_disk : t -> Stable.Latest.t =
  Poly.map ~f_witness:Transaction_witness.read_all_proofs_from_disk
    ~f_zkapp_command_segment_witness:
      Transaction_witness.Zkapp_command_segment_witness
      .read_all_proofs_from_disk
    ~f_proof:Ledger_proof.Cached.read_proof_from_disk
    ~f_data:
      (Proof_carrying_data.map_proof ~f:Ledger_proof.Cached.read_proof_from_disk)

let write_all_proofs_to_disk ~proof_cache_db : Stable.Latest.t -> t =
  Poly.map
    ~f_witness:(Transaction_witness.write_all_proofs_to_disk ~proof_cache_db)
    ~f_zkapp_command_segment_witness:
      (Transaction_witness.Zkapp_command_segment_witness
       .write_all_proofs_to_disk ~proof_cache_db )
    ~f_proof:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
    ~f_data:
      (Proof_carrying_data.map_proof
         ~f:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db) )
