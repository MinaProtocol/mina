(* WARN:
   This file would be rewritten finally
*)
(*
   This file tracks the Work distributed by Work_selector, hence the name.
   A Work_selector is responsible for selecting works from a work pool, and send
   them across RPC. That's no longer true in the current architecture, where a
   Work Partitioner sits between Snark Worker RPC endpoints and the Work Selector,
   it partitioned the works received from the Work Selector before sending them
   to the Snark Worker, hence more parallelism could be abused

   All types are versioned, because Works distributed by the Selector would need
   to be passed around the network between Coordinater and Snark Worker.
 *)
open Core_kernel

module Single = struct
  module Spec = Single_spec
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

      let transactions (t : t) =
        One_or_two.map t.spec.instances ~f:(fun i ->
            Single_spec.Stable.Latest.transaction i )
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
