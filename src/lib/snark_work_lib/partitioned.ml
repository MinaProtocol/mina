open Core_kernel

(* A `Pairing.t` identifies a single work in Work_selector's perspective *)
module Pairing = struct
  module ID = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        (* this identifies a One_or_two work from Work_selector's perspective *)
        type t = Pairing_ID of int
        [@@deriving compare, hash, sexp, yojson, equal]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      (* Case `One` indicate no need to pair. This is needed because zkapp command
         might be left in pool of half completion. *)
      type t = [ `First of ID.Stable.V1.t | `Second of ID.Stable.V1.t | `One ]
      [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]
end

module Zkapp_command_job = struct
  (* This identifies a single `Zkapp_command_job.t` *)
  module ID = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Job_ID of int [@@deriving compare, hash, sexp, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Spec = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type t =
          | Segment of
              { statement : Transaction_snark.Statement.With_sok.Stable.V2.t
              ; witness :
                  Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
              ; spec : Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
              }
          | Merge of
              { proof1 : Ledger_proof.Stable.V2.t
              ; proof2 : Ledger_proof.Stable.V2.t
              }
        [@@deriving sexp, yojson]

        let to_latest = Fn.id
      end
    end]

    type t =
      | Segment of
          { statement : Transaction_snark.Statement.With_sok.t
          ; witness : Transaction_snark.Zkapp_command_segment.Witness.t
          ; spec : Transaction_snark.Zkapp_command_segment.Basic.t
          }
      | Merge of
          { proof1 : Ledger_proof.Cached.t; proof2 : Ledger_proof.Cached.t }

    let read_all_proofs_from_disk : t -> Stable.Latest.t = function
      | Segment { statement; witness; spec } ->
          let witness =
            Transaction_snark.Zkapp_command_segment.Witness
            .read_all_proofs_from_disk witness
          in

          Segment { statement; witness; spec }
      | Merge { proof1; proof2 } ->
          let proof1 = Ledger_proof.Cached.read_proof_from_disk proof1 in
          let proof2 = Ledger_proof.Cached.read_proof_from_disk proof2 in
          Merge { proof1; proof2 }

    let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
        Stable.Latest.t -> t = function
      | Segment { statement; witness; spec } ->
          let witness =
            Transaction_snark.Zkapp_command_segment.Witness
            .write_all_proofs_to_disk ~proof_cache_db witness
          in
          Segment { statement; witness; spec }
      | Merge { proof1; proof2 } ->
          let proof1 =
            Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof1
          in
          let proof2 =
            Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof2
          in
          Merge { proof1; proof2 }
  end

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        { spec : Spec.Stable.V1.t
        ; pairing : Pairing.Stable.V1.t
        ; job_id : ID.Stable.V1.t
        }
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = { spec : Spec.t; pairing : Pairing.Stable.V1.t; job_id : ID.t }

  let read_all_proofs_from_disk ({ spec; pairing; job_id } : t) :
      Stable.Latest.t =
    { spec = Spec.read_all_proofs_from_disk spec; pairing; job_id }

  let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db)
      ({ spec; pairing; job_id } : Stable.Latest.t) : t =
    { spec = Spec.write_all_proofs_to_disk ~proof_cache_db spec
    ; pairing
    ; job_id
    }
end

module Spec = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type 'metric t =
          | Single of
              { single_spec : Selector.Single.Spec.Stable.V1.t
              ; pairing : Pairing.Stable.V1.t
              ; metric : 'metric
              }
          | Sub_zkapp_command of
              { spec : Zkapp_command_job.Stable.V1.t; metric : 'metric }
          | Old of
              (Selector.Single.Spec.Stable.V1.t * 'metric) Work.Spec.Stable.V1.t
        [@@deriving sexp, yojson]

        let to_latest = Fn.id
      end
    end]

    type 'metric t =
      | Single of
          { single_spec : Selector.Single.Spec.t
          ; pairing : Pairing.t
          ; metric : 'metric
          }
      | Sub_zkapp_command of { spec : Zkapp_command_job.t; metric : 'metric }
      | Old of (Selector.Single.Spec.t * 'metric) Work.Spec.t

    let map_metric (t : 'm t) ~(f : 'm -> 'n) : 'n t =
      match t with
      | Single { single_spec; pairing; metric } ->
          Single { single_spec; pairing; metric = f metric }
      | Old spec ->
          Old (Work.Spec.map ~f:(Tuple2.map_snd ~f) spec)
      | Sub_zkapp_command { spec; metric } ->
          Sub_zkapp_command { spec; metric = f metric }

    let read_all_proofs_from_disk : 'metric t -> 'metric Stable.Latest.t =
      function
      | Single { single_spec; pairing; metric } ->
          let single_spec =
            Selector.Single.Spec.read_all_proofs_from_disk single_spec
          in
          Single { single_spec; pairing; metric }
      | Sub_zkapp_command { spec; metric } ->
          let spec = Zkapp_command_job.read_all_proofs_from_disk spec in
          Sub_zkapp_command { spec; metric }
      | Old spec ->
          Old
            (Work.Spec.map
               ~f:
                 (Tuple2.map_fst
                    ~f:Selector.Single.Spec.read_all_proofs_from_disk )
               spec )

    let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
        'metric Stable.Latest.t -> 'metric t = function
      | Single { single_spec; pairing; metric } ->
          let single_spec =
            Selector.Single.Spec.write_all_proofs_to_disk ~proof_cache_db
              single_spec
          in
          Single { single_spec; pairing; metric }
      | Sub_zkapp_command { spec; metric } ->
          let spec =
            Zkapp_command_job.write_all_proofs_to_disk ~proof_cache_db spec
          in
          Sub_zkapp_command { spec; metric }
      | Old spec ->
          Old
            (Work.Spec.map
               ~f:
                 (Tuple2.map_fst
                    ~f:
                      (Selector.Single.Spec.write_all_proofs_to_disk
                         ~proof_cache_db ) )
               spec )

    let transaction = function
      | Single { single_spec; _ } ->
          let txn = Selector.Single.Spec.transaction single_spec in
          `Single txn
      | Sub_zkapp_command _ ->
          `Sub_zkapp_command
      | Old spec ->
          `Old
            (One_or_two.map spec.instances ~f:(fun (single, ()) ->
                 Selector.Single.Spec.transaction single ) )
  end

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = unit Poly.Stable.V1.t [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = unit Poly.t

  let of_selector_spec (spec : Selector.Spec.t) : t =
    Old (Work.Spec.map ~f:(fun spec -> (spec, ())) spec)

  let to_selector_spec : t -> Selector.Spec.t option = function
    | Old spec ->
        let spec = Work.Spec.map ~f:(fun (spec, ()) -> spec) spec in
        Some spec
    | _ ->
        None
end

module Proof_with_metric = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        { proof : Ledger_proof.Stable.V2.t
        ; elapsed : Core.Time.Stable.Span.V1.t
        }

      let to_latest = Fn.id
    end
  end]

  type t = { proof : Ledger_proof.Cached.t; elapsed : Core.Time.Span.t }

  let read_all_proofs_from_disk ({ proof; elapsed } : t) : Stable.Latest.t =
    let proof = Ledger_proof.Cached.read_proof_from_disk proof in
    { proof; elapsed }

  let write_all_proofs_to_disk ~proof_cache_db
      ({ proof; elapsed } : Stable.Latest.t) : t =
    let proof = Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof in
    { proof; elapsed }
end

module Result = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        { (* Throw everything inside the spec to ensure proofs, metrics have correct shape *)
          data : Proof_with_metric.Stable.V1.t Spec.Poly.Stable.V1.t
        ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
        }

      let to_latest = Fn.id
    end
  end]

  type t =
    { data : Proof_with_metric.t Spec.Poly.t
    ; prover : Signature_lib.Public_key.Compressed.t
    }

  let read_all_proofs_from_disk ({ data; prover } : t) : Stable.Latest.t =
    let data =
      Spec.Poly.(
        map_metric ~f:Proof_with_metric.read_all_proofs_from_disk data
        |> read_all_proofs_from_disk)
    in

    { data; prover }

  let write_all_proofs_to_disk ~proof_cache_db
      ({ data; prover } : Stable.Latest.t) : t =
    let data =
      Spec.Poly.(
        write_all_proofs_to_disk ~proof_cache_db data
        |> map_metric
             ~f:(Proof_with_metric.write_all_proofs_to_disk ~proof_cache_db))
    in
    { data; prover }

  let of_selector_result
      ({ proofs; metrics; spec = { instances; fee }; prover } :
        Selector.Result.t ) : t Or_error.t =
    let%bind.Result zipped = One_or_two.zip proofs metrics in
    let%map.Result zipped = One_or_two.zip zipped instances in

    let with_metric ((proof, (elapsed, _)), single_spec) =
      (single_spec, Proof_with_metric.{ proof; elapsed })
    in
    let instances = One_or_two.map ~f:with_metric zipped in
    let data = Spec.Poly.Old { instances; fee } in
    { data; prover }

  let to_selector_result ({ data; prover } : t) : Selector.Result.t option =
    match data with
    | Old { instances; fee } ->
        let proofs =
          One_or_two.map ~f:(fun (_, { proof; _ }) -> proof) instances
        in
        let metrics =
          One_or_two.map
            ~f:(fun (single, { elapsed; _ }) ->
              let tag =
                match single with
                | Work.Single.Spec.Transition (_, _) ->
                    `Transition
                | Work.Single.Spec.Merge (_, _, _) ->
                    `Merge
              in
              (elapsed, tag) )
            instances
        in

        let instances =
          One_or_two.map ~f:(fun (single, _) -> single) instances
        in
        Some { proofs; metrics; spec = { instances; fee }; prover }
    | _ ->
        None
end
