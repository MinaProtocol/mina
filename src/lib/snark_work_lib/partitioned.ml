(*
   This file tracks the Work distributed by Work Partitioner, hence the name.
   Work Partitioner is a layer above the Work Selector, so types defined in this
   module should be superset of types defined in Work Selector.
 *)

open Core_kernel

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

  (* A Pairing.Single.t identifies one part of a One_or_two work *)
  module Single = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        (* Case `One` indicate no need to pair. *)
        type t = [ `First of ID.Stable.V1.t | `Second of ID.Stable.V1.t | `One ]
        [@@deriving compare, hash, sexp, yojson, equal]

        let to_latest = Fn.id
      end
    end]
  end

  (* A Pairing.Sub_zkapp.t identifies a sub-zkapp level work *)
  module Sub_zkapp = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        (* Case `One` indicate no need to pair. ID is still needed because zkapp command
           might be left in pool of half completion. *)
        type t =
          { which_one : [ `First | `Second | `One ]; id : ID.Stable.V1.t }
        [@@deriving compare, hash, sexp, yojson, equal]

        let to_latest = Fn.id
      end
    end]

    let of_single (id_gen : unit -> ID.t) : Single.t -> t = function
      | `First id ->
          { which_one = `First; id }
      | `Second id ->
          { which_one = `Second; id }
      | `One ->
          { which_one = `One; id = id_gen () }
  end
end

module Spec_common = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { (* When is this spec issued? *)
          issued_since_unix_epoch : Mina_stdlib.Time.Span.Stable.V1.t
              (* The fee of the full command, even if we're issuing a sub_zkapp level spec *)
        ; fee_of_full : Currency.Fee.Stable.V1.t
        }
      [@@deriving sexp, yojson]

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

    let statement : t -> Transaction_snark.Statement.t = function
      | Segment { statement; _ } ->
          Mina_state.Snarked_ledger_state.Poly.drop_sok statement
      | Merge { proof1; proof2; _ } -> (
          let module Statement = Mina_state.Snarked_ledger_state in
          let { Proof_carrying_data.data = t1; _ } = proof1 in
          let { Proof_carrying_data.data = t2; _ } = proof2 in
          let stmt =
            Statement.merge
              ({ t1 with sok_digest = () } : Statement.t)
              { t2 with sok_digest = () }
          in
          match stmt with
          | Ok stmt ->
              stmt
          | Error e ->
              failwithf
                "Failed to construct a statement from  zkapp merge command %s"
                (Error.to_string_hum e) () )
  end

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        { spec : Spec.Stable.V1.t
        ; pairing : Pairing.Sub_zkapp.Stable.V1.t
        ; job_id : ID.Stable.V1.t
        ; common : Spec_common.Stable.V1.t
        }
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t =
    { spec : Spec.t
    ; pairing : Pairing.Sub_zkapp.t
    ; job_id : ID.t
    ; common : Spec_common.t
    }

  let read_all_proofs_from_disk ({ spec; pairing; job_id; common } : t) :
      Stable.Latest.t =
    { spec = Spec.read_all_proofs_from_disk spec; pairing; job_id; common }

  let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db)
      ({ spec; pairing; job_id; common } : Stable.Latest.t) : t =
    { spec = Spec.write_all_proofs_to_disk ~proof_cache_db spec
    ; pairing
    ; job_id
    ; common
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
              ; pairing : Pairing.Single.Stable.V1.t
              ; metric : 'metric
              ; common : Spec_common.Stable.V1.t
              }
          | Sub_zkapp_command of
              { spec : Zkapp_command_job.Stable.V1.t; metric : 'metric }
          | Old of
              { instances :
                  (Selector.Single.Spec.Stable.V1.t * 'metric)
                  One_or_two.Stable.V1.t
              ; common : Spec_common.Stable.V1.t
              }
        [@@deriving sexp, yojson]

        let to_latest = Fn.id
      end
    end]

    type 'metric t =
      | Single of
          { single_spec : Selector.Single.Spec.t
          ; pairing : Pairing.Single.t
          ; metric : 'metric
          ; common : Spec_common.Stable.V1.t
          }
      | Sub_zkapp_command of { spec : Zkapp_command_job.t; metric : 'metric }
      | Old of
          { instances : (Selector.Single.Spec.t * 'metric) One_or_two.t
          ; common : Spec_common.t
          }

    let map (t : 'm t) ~(f : 'm -> 'n) : 'n t =
      match t with
      | Single { single_spec; pairing; metric; common } ->
          Single { single_spec; pairing; metric = f metric; common }
      | Old { instances; common } ->
          Old
            { instances = One_or_two.map ~f:(Tuple2.map_snd ~f) instances
            ; common
            }
      | Sub_zkapp_command { spec; metric } ->
          Sub_zkapp_command { spec; metric = f metric }

    let statements : 'metric t -> Transaction_snark.Statement.t One_or_two.t =
      function
      | Single { single_spec; _ } ->
          let stmt = Work.Single.Spec.statement single_spec in
          `One stmt
      | Sub_zkapp_command { spec = { spec; _ }; _ } ->
          `One (Zkapp_command_job.Spec.statement spec)
      | Old { instances; _ } ->
          One_or_two.map
            ~f:(fun (i, _) -> Work.Single.Spec.statement i)
            instances

    let map_with_statement (t : 'm t)
        ~(f : Transaction_snark.Statement.t -> 'm -> 'n) : 'n t =
      match t with
      | Single { single_spec; pairing; metric; common } ->
          let stmt = Work.Single.Spec.statement single_spec in
          Single { single_spec; pairing; metric = f stmt metric; common }
      | Old { instances; common } ->
          Old
            { instances =
                One_or_two.map
                  ~f:(fun (single_spec, metric) ->
                    let stmt = Work.Single.Spec.statement single_spec in
                    (single_spec, f stmt metric) )
                  instances
            ; common
            }
      | Sub_zkapp_command { spec = { spec; _ } as job_spec; metric } ->
          Sub_zkapp_command
            { spec = job_spec
            ; metric = f (Zkapp_command_job.Spec.statement spec) metric
            }

    let read_all_proofs_from_disk : 'metric t -> 'metric Stable.Latest.t =
      function
      | Single { single_spec; pairing; metric; common } ->
          let single_spec =
            Selector.Single.Spec.read_all_proofs_from_disk single_spec
          in
          Single { single_spec; pairing; metric; common }
      | Sub_zkapp_command { spec; metric } ->
          let spec = Zkapp_command_job.read_all_proofs_from_disk spec in
          Sub_zkapp_command { spec; metric }
      | Old { instances; common } ->
          Old
            { instances =
                One_or_two.map
                  ~f:
                    (Tuple2.map_fst
                       ~f:Selector.Single.Spec.read_all_proofs_from_disk )
                  instances
            ; common
            }

    let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
        'metric Stable.Latest.t -> 'metric t = function
      | Single { single_spec; pairing; metric; common } ->
          let single_spec =
            Selector.Single.Spec.write_all_proofs_to_disk ~proof_cache_db
              single_spec
          in
          Single { single_spec; pairing; metric; common }
      | Sub_zkapp_command { spec; metric } ->
          let spec =
            Zkapp_command_job.write_all_proofs_to_disk ~proof_cache_db spec
          in
          Sub_zkapp_command { spec; metric }
      | Old { instances; common } ->
          Old
            { instances =
                One_or_two.map
                  ~f:
                    (Tuple2.map_fst
                       ~f:
                         (Selector.Single.Spec.write_all_proofs_to_disk
                            ~proof_cache_db ) )
                  instances
            ; common
            }

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

    let fee_of_full : 'm t -> Currency.Fee.t = function
      | Single { common; _ }
      | Sub_zkapp_command { spec = { common; _ }; _ }
      | Old { common; _ } ->
          common.fee_of_full
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

  let of_selector_spec ~issued_since_unix_epoch (spec : Selector.Spec.t) : t =
    Old
      { instances = One_or_two.map ~f:(fun spec -> (spec, ())) spec.instances
      ; common = { fee_of_full = spec.fee; issued_since_unix_epoch }
      }

  let to_selector_spec : t -> Selector.Spec.t option = function
    | Old spec ->
        let instances =
          One_or_two.map ~f:(fun (spec, ()) -> spec) spec.instances
        in
        Some { instances; fee = spec.common.fee_of_full }
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

let construct_selector_result
    ~(instances : (Selector.Single.Spec.t * Proof_with_metric.t) One_or_two.t)
    ~fee ~prover =
  let proofs = One_or_two.map ~f:(fun (_, { proof; _ }) -> proof) instances in
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

  let instances = One_or_two.map ~f:(fun (single, _) -> single) instances in
  ({ proofs; metrics; spec = { instances; fee }; prover } : Selector.Result.t)

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
        map ~f:Proof_with_metric.read_all_proofs_from_disk data
        |> read_all_proofs_from_disk)
    in

    { data; prover }

  let write_all_proofs_to_disk ~proof_cache_db
      ({ data; prover } : Stable.Latest.t) : t =
    let data =
      Spec.Poly.(
        write_all_proofs_to_disk ~proof_cache_db data
        |> map ~f:(Proof_with_metric.write_all_proofs_to_disk ~proof_cache_db))
    in
    { data; prover }

  let to_spec ({ data; _ } : t) : Spec.t =
    match data with
    | Spec.Poly.Single { single_spec; pairing; common; _ } ->
        Spec.Poly.Single { single_spec; pairing; common; metric = () }
    | Spec.Poly.Sub_zkapp_command { spec; _ } ->
        Spec.Poly.Sub_zkapp_command { spec; metric = () }
    | Spec.Poly.Old { instances; common } ->
        Spec.Poly.Old
          { instances =
              One_or_two.map ~f:(fun (spec, _) -> (spec, ())) instances
          ; common
          }

  let of_selector_result ~issued_since_unix_epoch
      ({ proofs; metrics; spec = { instances; fee }; prover } :
        Selector.Result.t ) : t Or_error.t =
    let%bind.Result zipped = One_or_two.zip proofs metrics in
    let%map.Result zipped = One_or_two.zip zipped instances in

    let with_metric ((proof, (elapsed, _)), single_spec) =
      (single_spec, Proof_with_metric.{ proof; elapsed })
    in
    let instances = One_or_two.map ~f:with_metric zipped in
    let data =
      Spec.Poly.Old
        { instances; common = { issued_since_unix_epoch; fee_of_full = fee } }
    in
    { data; prover }

  let to_selector_result ({ data; prover } : t) : Selector.Result.t option =
    match data with
    | Old { instances; common = { fee_of_full = fee; _ } } ->
        Some (construct_selector_result ~instances ~fee ~prover)
    | _ ->
        None
end
