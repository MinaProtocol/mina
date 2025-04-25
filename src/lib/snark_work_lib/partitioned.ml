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
            .write_all_proofs_to_disk witness
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
          | Regular of
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
      | Regular of
          { single_spec : Selector.Single.Spec.t
          ; pairing : Pairing.t
          ; metric : 'metric
          }
      | Sub_zkapp_command of { spec : Zkapp_command_job.t; metric : 'metric }
      | Old of (Selector.Single.Spec.t * 'metric) Work.Spec.t

    let read_all_proofs_from_disk : 'metric t -> 'metric Stable.Latest.t =
      function
      | Regular { single_spec; pairing; metric } ->
          let single_spec =
            Selector.Single.Spec.read_all_proofs_from_disk single_spec
          in
          Regular { single_spec; pairing; metric }
      | Old spec ->
          Old
            (Work.Spec.map
               ~f:
                 (Tuple2.map_fst
                    ~f:Selector.Single.Spec.read_all_proofs_from_disk )
               spec )
      | Sub_zkapp_command { spec; metric } ->
          let spec = Zkapp_command_job.read_all_proofs_from_disk spec in
          Sub_zkapp_command { spec; metric }

    let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
        'metric Stable.Latest.t -> 'metric t = function
      | Regular { single_spec; pairing; metric } ->
          let single_spec =
            Selector.Single.Spec.write_all_proofs_to_disk ~proof_cache_db
              single_spec
          in
          Regular { single_spec; pairing; metric }
      | Old spec ->
          Old
            (Work.Spec.map
               ~f:
                 (Tuple2.map_fst
                    ~f:
                      (Selector.Single.Spec.write_all_proofs_to_disk
                         ~proof_cache_db ) )
               spec )
      | Sub_zkapp_command { spec; metric } ->
          let spec =
            Zkapp_command_job.write_all_proofs_to_disk ~proof_cache_db spec
          in
          Sub_zkapp_command { spec; metric }

    let transaction = function
      | Regular { single_spec; _ } ->
          let txn = Selector.Single.Spec.transaction single_spec in
          `Regular txn
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

module Result = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        { proofs : Ledger_proof.Stable.V2.t One_or_two.Stable.V1.t
        ; metrics :
            ( Core.Time.Stable.Span.V1.t
            * [ `Transition
              | `Merge
              | `Sub_zkapp_command of [ `Segment | `Merge ] ] )
            One_or_two.Stable.V1.t
        ; spec : Spec.Stable.V1.t
        ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
        }

      let to_latest = Fn.id
    end
  end]

  type t =
    { proofs : Ledger_proof.Cached.t One_or_two.t
    ; metrics :
        ( Core.Time.Span.t
        * [ `Transition | `Merge | `Sub_zkapp_command of [ `Segment | `Merge ] ]
        )
        One_or_two.t
    ; spec : Spec.t
    ; prover : Signature_lib.Public_key.Compressed.t
    }

  let read_all_proofs_from_disk ({ proofs; metrics; spec; prover } : t) :
      Stable.Latest.t =
    { proofs = One_or_two.map ~f:Ledger_proof.Cached.read_proof_from_disk proofs
    ; metrics
    ; spec = Spec.read_all_proofs_from_disk spec
    ; prover
    }

  let write_all_proofs_to_disk ~proof_cache_db
      ({ proofs; metrics; spec; prover } : Stable.Latest.t) : t =
    { proofs =
        One_or_two.map
          ~f:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
          proofs
    ; metrics
    ; spec = Spec.write_all_proofs_to_disk ~proof_cache_db spec
    ; prover
    }

  let of_selector_result ({ proofs; metrics; spec; prover } : Selector.Result.t)
      : t =
    let spec = Spec.of_selector_spec spec in
    let fix_metric_tag tag =
      match tag with `Transition -> `Transition | `Merge -> `Merge
    in
    let metrics =
      One_or_two.map ~f:(Tuple2.map_snd ~f:fix_metric_tag) metrics
    in
    { proofs; metrics; spec; prover }

  let to_selector_result ({ proofs; metrics; spec; prover } : t) :
      Selector.Result.t option =
    let fix_metric_tag (span, tag) =
      match tag with
      | (`Transition | `Merge) as tag ->
          Some (span, tag)
      | `Sub_zkapp_command _ ->
          None
    in
    let%bind.Option spec = Spec.to_selector_spec spec in
    let%map.Option metrics = One_or_two.Option.map ~f:fix_metric_tag metrics in
    ({ proofs; metrics; spec; prover } : Selector.Result.t)
end
