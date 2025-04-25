(*
   This file tracks the Work distributed by Selector, hence the name.
   Originally, these types are defined around the codebase, and versioning them
   is a mess. Also, some helpers that could be reused are redefined in different
   modules. We put it here, so it's easier to either extend/verision them.

   Some functions here might be moved to `Snark_work_lib.Work`, but we could do
   the move fairly easily when needed since they're all tracked together.

   All types are versioned, because Works distributed by the Selector would need
   to be passed around the network between Coordinater and Snark Worker.
 *)
open Core_kernel

module Single = struct
  module Spec = struct
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

    let read_all_proofs_from_disk : t -> Stable.Latest.t =
      Work.Single.Spec.map
        ~f_witness:Transaction_witness.read_all_proofs_from_disk
        ~f_proof:Ledger_proof.Cached.read_proof_from_disk

    let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
        Stable.Latest.t -> t =
      Work.Single.Spec.map
        ~f_witness:Transaction_witness.write_all_proofs_to_disk
        ~f_proof:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
  end
end

module Spec = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = Single.Spec.Stable.V1.t Work.Spec.Stable.V1.t
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Single.Spec.t Work.Spec.t

  let read_all_proofs_from_disk : t -> Stable.Latest.t =
    Work.Spec.map ~f:Single.Spec.read_all_proofs_from_disk

  let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
      Stable.Latest.t -> t =
    Work.Spec.map ~f:(Single.Spec.write_all_proofs_to_disk ~proof_cache_db)
end

module Result = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        (Spec.Stable.V1.t, Ledger_proof.Stable.V2.t) Work.Result.Stable.V1.t

      let to_latest = Fn.id
    end
  end]

  type t = (Spec.t, Ledger_proof.Cached.t) Work.Result.Stable.V1.t

  let read_all_proofs_from_disk : t -> Stable.Latest.t =
    Work.Result.map ~f_spec:Spec.read_all_proofs_from_disk
      ~f_single:Ledger_proof.Cached.read_proof_from_disk

  let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
      Stable.Latest.t -> t =
    Work.Result.map
      ~f_spec:(Spec.write_all_proofs_to_disk ~proof_cache_db)
      ~f_single:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
end
