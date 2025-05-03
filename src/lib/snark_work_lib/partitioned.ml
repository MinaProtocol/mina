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
    module Poly = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type ('witness, 'proof) t =
            | Segment of
                { statement : Transaction_snark.Statement.With_sok.Stable.V2.t
                ; witness : 'witness
                ; spec :
                    Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
                }
            | Merge of { proof1 : 'proof; proof2 : 'proof }
          [@@deriving sexp, yojson]

          let map ~f_witness ~f_proof = function
            | Segment { statement; witness; spec } ->
                Segment { statement; witness = f_witness witness; spec }
            | Merge { proof1; proof2 } ->
                Merge { proof1 = f_proof proof1; proof2 = f_proof proof2 }

          let statement : _ t -> Transaction_snark.Statement.t = function
            | Segment { statement; _ } ->
                Mina_state.Snarked_ledger_state.Poly.drop_sok statement
            | Merge { proof1; proof2; _ } -> (
                let module Statement = Mina_state.Snarked_ledger_state in
                let stmt1 = Ledger_proof.Poly.statement proof1 in
                let stmt2 = Ledger_proof.Poly.statement proof2 in
                let stmt = Statement.merge stmt1 stmt2 in
                match stmt with
                | Ok stmt ->
                    stmt
                | Error e ->
                    failwithf
                      "Failed to construct a statement from  zkapp merge \
                       command %s"
                      (Error.to_string_hum e) () )
        end
      end]

      [%%define_locally
      Stable.Latest.(t_of_sexp, sexp_of_t, to_yojson, of_yojson, map, statement)]
    end

    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type t =
          ( Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
          , Ledger_proof.Stable.V2.t )
          Poly.Stable.V1.t
        [@@deriving sexp, yojson]

        let statement : t -> Transaction_snark.Statement.t = Poly.statement

        let to_latest = Fn.id
      end
    end]

    type t =
      ( Transaction_snark.Zkapp_command_segment.Witness.t
      , Ledger_proof.Cached.t )
      Poly.t

    let read_all_proofs_from_disk : t -> Stable.Latest.t =
      Poly.map
        ~f_witness:
          Transaction_snark.Zkapp_command_segment.Witness
          .read_all_proofs_from_disk
        ~f_proof:Ledger_proof.Cached.read_proof_from_disk

    let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
        Stable.Latest.t -> t =
      Poly.map
        ~f_witness:
          (Transaction_snark.Zkapp_command_segment.Witness
           .write_all_proofs_to_disk ~proof_cache_db )
        ~f_proof:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
  end

  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'spec t =
          { spec : 'spec
          ; pairing : Pairing.Sub_zkapp.Stable.V1.t
          ; job_id : ID.Stable.V1.t
          ; common : Spec_common.Stable.V1.t
          }
        [@@deriving sexp, yojson]

        let map ~(f_spec : 'a -> 'b) (t : 'a t) : 'b t =
          { t with spec = f_spec t.spec }
      end
    end]

    [%%define_locally
    Stable.Latest.(t_of_sexp, sexp_of_t, to_yojson, of_yojson, map)]
  end

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = Spec.Stable.V1.t Poly.Stable.V1.t [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Spec.t Poly.t

  let read_all_proofs_from_disk : t -> Stable.Latest.t =
    Poly.map ~f_spec:Spec.read_all_proofs_from_disk

  let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
      Stable.Latest.t -> t =
    Poly.map ~f_spec:(Spec.write_all_proofs_to_disk ~proof_cache_db)
end

module Spec = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ( 'witness
             , 'zkapp_command_segment_witness
             , 'ledger_proof
             , 'metric )
             t =
          | Single of
              { single_spec :
                  ('witness, 'ledger_proof) Work.Single.Spec.Stable.V2.t
              ; pairing : Pairing.Single.Stable.V1.t
              ; metric : 'metric
              ; common : Spec_common.Stable.V1.t
              }
          | Sub_zkapp_command of
              { spec :
                  ( 'zkapp_command_segment_witness
                  , 'ledger_proof )
                  Zkapp_command_job.Spec.Poly.Stable.V1.t
                  Zkapp_command_job.Poly.Stable.V1.t
              ; metric : 'metric
              }
          | Old of
              { instances :
                  ( ('witness, 'ledger_proof) Work.Single.Spec.Stable.V2.t
                  * 'metric )
                  One_or_two.Stable.V1.t
              ; common : Spec_common.Stable.V1.t
              }
        [@@deriving sexp, yojson]

        let map ~f_witness ~f_zkapp_command_segment_witness ~f_proof ~f_metric =
          function
          | Single { single_spec; pairing; metric; common } ->
              Single
                { single_spec =
                    Work.Single.Spec.map ~f_witness ~f_proof single_spec
                ; pairing
                ; metric = f_metric metric
                ; common
                }
          | Sub_zkapp_command { spec; metric } ->
              Sub_zkapp_command
                { spec =
                    Zkapp_command_job.Poly.map
                      ~f_spec:
                        (Zkapp_command_job.Spec.Poly.map
                           ~f_witness:f_zkapp_command_segment_witness ~f_proof )
                      spec
                ; metric = f_metric metric
                }
          | Old { instances; common } ->
              let f_instance (single_spec, metric) =
                ( Work.Single.Spec.map ~f_witness ~f_proof single_spec
                , f_metric metric )
              in
              Old { instances = One_or_two.map ~f:f_instance instances; common }

        let statements : _ t -> Transaction_snark.Statement.t One_or_two.t =
          function
          | Single { single_spec; _ } ->
              let stmt = Work.Single.Spec.statement single_spec in
              `One stmt
          | Sub_zkapp_command { spec = { spec; _ }; _ } ->
              `One (Zkapp_command_job.Spec.Poly.statement spec)
          | Old { instances; _ } ->
              One_or_two.map
                ~f:(fun (i, _) -> Work.Single.Spec.statement i)
                instances

        let map_with_statement (t : _ t) ~f : _ t =
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
                ; metric = f (Zkapp_command_job.Spec.Poly.statement spec) metric
                }

        let transaction = function
          | Single { single_spec; _ } ->
              let txn = Work.Single.Spec.transaction single_spec in
              `Single txn
          | Sub_zkapp_command _ ->
              `Sub_zkapp_command
          | Old spec ->
              `Old
                (One_or_two.map spec.instances ~f:(fun (single, ()) ->
                     Work.Single.Spec.transaction single ) )

        let fee_of_full : _ t -> Currency.Fee.t = function
          | Single { common; _ }
          | Sub_zkapp_command { spec = { common; _ }; _ }
          | Old { common; _ } ->
              common.fee_of_full

        let of_selector_spec ~issued_since_unix_epoch (spec : _ Work.Spec.t) :
            _ t =
          Old
            { instances =
                One_or_two.map ~f:(fun spec -> (spec, ())) spec.instances
            ; common = { fee_of_full = spec.fee; issued_since_unix_epoch }
            }

        let to_selector_spec : _ t -> _ Work.Spec.t option = function
          | Old spec ->
              let instances =
                One_or_two.map ~f:(fun (spec, ()) -> spec) spec.instances
              in
              Some { instances; fee = spec.common.fee_of_full }
          | _ ->
              None
      end
    end]

    [%%define_locally
    Stable.Latest.
      ( map
      , statements
      , map_with_statement
      , transaction
      , of_selector_spec
      , to_selector_spec )]
  end

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        ( Transaction_witness.Stable.V2.t
        , Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
        , Ledger_proof.Stable.V2.t
        , unit )
        Poly.Stable.V1.t
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t =
    ( Transaction_witness.t
    , Transaction_snark.Zkapp_command_segment.Witness.t
    , Ledger_proof.Cached.t
    , unit )
    Poly.t

  let read_all_proofs_from_disk : t -> Stable.Latest.t = function
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
      Stable.Latest.t -> t = function
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
end

module Proof_with_metric = struct
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
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ( 'witness
             , 'zkapp_command_segment_witness
             , 'ledger_proof
             , 'metric )
             t =
          { (* Throw everything inside the spec to ensure proofs, metrics have correct shape *)
            data :
              ( 'witness
              , 'zkapp_command_segment_witness
              , 'ledger_proof
              , 'metric )
              Spec.Poly.Stable.V1.t
          ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
          }

        let to_spec ({ data; _ } : _ t) : _ Spec.Poly.t =
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
              ( ('witness, 'ledger_proof) Work.Single.Spec.t Work.Spec.t
              , 'ledger_proof )
              Work.Result.t ) :
            ('witness, 'zkapp_command_segment_witness, 'ledger_proof, 'metric) t
            Or_error.t =
          let%bind.Result zipped = One_or_two.zip proofs metrics in
          let%map.Result zipped = One_or_two.zip zipped instances in

          let with_metric ((proof, (elapsed, _)), single_spec) :
              _ * _ Proof_with_metric.Poly.t =
            (single_spec, { proof; elapsed })
          in
          let instances = One_or_two.map ~f:with_metric zipped in
          let data =
            Spec.Poly.Old
              { instances
              ; common = { issued_since_unix_epoch; fee_of_full = fee }
              }
          in
          { data; prover }

        let to_selector_result ({ data; prover } : _ t) =
          match data with
          | Old { instances; common = { fee_of_full = fee; _ } } ->
              Some (construct_selector_result ~instances ~fee ~prover)
          | _ ->
              None
      end
    end]
  end

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        { data :
            ( Transaction_witness.Stable.V2.t
            , Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
            , Ledger_proof.Stable.V2.t
            , Proof_with_metric.Stable.V1.t )
            Spec.Poly.Stable.V1.t
        ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
        }

      let to_latest = Fn.id
    end
  end]

  type t =
    { data :
        ( Transaction_witness.t
        , Transaction_snark.Zkapp_command_segment.Witness.t
        , Ledger_proof.Cached.t
        , Proof_with_metric.t )
        Spec.Poly.t
    ; prover : Signature_lib.Public_key.Compressed.t
    }

  let read_all_proofs_from_disk ({ data; prover } : t) : Stable.Latest.t =
    let data =
      Spec.Poly.map ~f_witness:Transaction_witness.read_all_proofs_from_disk
        ~f_zkapp_command_segment_witness:
          Transaction_witness.Zkapp_command_segment_witness
          .read_all_proofs_from_disk
        ~f_proof:Ledger_proof.Cached.read_proof_from_disk
        ~f_metric:Proof_with_metric.read_all_proofs_from_disk data
    in

    { data; prover }

  let write_all_proofs_to_disk ~proof_cache_db
      ({ data; prover } : Stable.Latest.t) : t =
    let data =
      Spec.Poly.map
        ~f_witness:
          (Transaction_witness.write_all_proofs_to_disk ~proof_cache_db)
        ~f_zkapp_command_segment_witness:
          (Transaction_witness.Zkapp_command_segment_witness
           .write_all_proofs_to_disk ~proof_cache_db )
        ~f_proof:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
        ~f_metric:(Proof_with_metric.write_all_proofs_to_disk ~proof_cache_db)
        data
    in
    { data; prover }
end
