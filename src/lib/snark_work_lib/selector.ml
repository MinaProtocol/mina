open Core_kernel

module Single_spec = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        ( Transaction_witness.Stable.V2.t
        , Ledger_proof.Stable.V2.t )
        Work.Single.Spec.Stable.V2.t
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = (Transaction_witness.t, Ledger_proof.Cached.t) Work.Single.Spec.t

  let materialize : t -> Stable.Latest.t =
    Work.Single.Spec.map
      ~f_witness:Transaction_witness.read_all_proofs_from_disk
      ~f_proof:Ledger_proof.Cached.read_proof_from_disk

  let cache ~(proof_cache_db : Proof_cache_tag.cache_db) : Stable.Latest.t -> t
      =
    Work.Single.Spec.map ~f_witness:Transaction_witness.write_all_proofs_to_disk
      ~f_proof:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
end
