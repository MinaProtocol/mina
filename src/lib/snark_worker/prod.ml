open Async
open Core
open Mina_base
open Mina_transaction
module Work = Snark_work_lib

module Cache = struct
  module T = Hash_heap.Make (Transaction_snark.Statement)

  type t = (Time.t * Transaction_snark.t) T.t

  let max_size = 100

  let create () : t = T.create (fun (t1, _) (t2, _) -> Time.compare t1 t2)

  let add t ~statement ~proof =
    T.push_exn t ~key:statement ~data:(Time.now (), proof) ;
    if Int.( > ) (T.length t) max_size then ignore (T.pop_exn t)

  let find (t : t) statement = Option.map ~f:snd (T.find t statement)
end

module Zkapp_command_inputs =
  Work_partitioner.Snark_worker_shared.Zkapp_command_inputs

module Impl : Intf.Worker = struct
  module Worker_state = struct
    module type S = Transaction_snark.S

    type module_with_proof_level = Check | No_check | Full of (module S)

    type t =
      { m_with_proof_level : module_with_proof_level
      ; cache : Cache.t
      ; proof_cache_db : Proof_cache_tag.cache_db
      ; logger : Logger.t
      }

    let create ~constraint_constants ~proof_level () =
      let proof_cache_db = Proof_cache_tag.create_identity_db () in
      let m_with_proof_level =
        match proof_level with
        | Genesis_constants.Proof_level.Full ->
            Full
              ( module Transaction_snark.Make (struct
                let constraint_constants = constraint_constants

                let proof_level = proof_level
              end) )
        | Check ->
            Check
        | No_check ->
            No_check
      in
      Deferred.return
        { m_with_proof_level
        ; cache = Cache.create ()
        ; proof_cache_db
        ; logger = Logger.create ()
        }

    let worker_wait_time = 5.
  end

  let log_zkapp_cmd_base_snark ~logger ~statement ~spec f () =
    match%map.Deferred
      Deferred.Or_error.try_with ~here:[%here] (fun () -> f ~statement ~spec)
    with
    | Ok p ->
        Ok p
    | Error e ->
        [%log fatal]
          "Transaction snark failed for input $spec $statement. All inputs: \
           $inputs. Error:  $error"
          ~metadata:
            [ ( "spec"
              , Transaction_snark.Zkapp_command_segment.Basic.to_yojson spec )
            ; ( "statement"
              , Transaction_snark.Statement.With_sok.to_yojson statement )
            ; ("error", `String (Error.to_string_hum e))
            ] ;
        Error e

  let log_zkapp_cmd_merge_snark ~m:(module M : Worker_state.S) ~logger
      ~sok_digest prev curr () =
    match%map.Deferred M.merge ~sok_digest prev curr with
    | Ok p ->
        Ok p
    | Error e ->
        [%log fatal]
          "Merge snark failed for $stmt1 $stmt2. All inputs: $inputs. Error:  \
           $error"
          ~metadata:
            [ ( "stmt1"
              , Transaction_snark.Statement.to_yojson
                  (Ledger_proof.statement prev) )
            ; ( "stmt2"
              , Transaction_snark.Statement.to_yojson
                  (Ledger_proof.statement curr) )
            ; ("error", `String (Error.to_string_hum e))
            ] ;
        Error e

  let cache_and_time ~logger ~cache ~statement
      ~(full_spec : Work.Partitioned.Spec.Stable.Latest.t) k =
    match (Cache.find cache) statement with
    | Some proof ->
        Deferred.Or_error.return (proof, Time.Span.zero)
    | None -> (
        let start = Time.now () in
        match%map.Async.Deferred
          Monitor.try_with_join_or_error ~here:[%here] k
        with
        | Error e ->
            [%log error] "SNARK worker failed: $error"
              ~metadata:
                [ ("error", Error_json.error_to_yojson e)
                ; ( "spec"
                    (* the [@sexp.opaque] in Work.Single.Spec.t means we can't derive yojson,
                       so we use the less-desirable sexp here
                    *)
                  , `String
                      ( Work.Partitioned.Spec.Stable.Latest.sexp_of_t full_spec
                      |> Sexp.to_string ) )
                ] ;
            Error e
        | Ok res ->
            Cache.add cache ~statement ~proof:res ;
            let elapsed = Time.abs_diff (Time.now ()) start in
            Ok (res, elapsed) )

  let perform_single_raw ~logger ~(m : (module Worker_state.S)) ~proof_cache_db
      ~(single : Work.Selector.Single.Spec.Stable.Latest.t) ~sok_digest () =
    let open Deferred.Or_error.Let_syntax in
    let (module M) = m in
    match single with
    | Transition (input, (witness : Transaction_witness.Stable.Latest.t)) -> (
        match witness.transaction with
        | Command (Zkapp_command zkapp_command) -> (
            let zkapp_command_cached =
              Zkapp_command.write_all_proofs_to_disk ~proof_cache_db
                zkapp_command
            in
            let%bind witnesses_specs_stmts =
              Work_partitioner.Snark_worker_shared.extract_zkapp_segment_works
                ~m ~input ~witness ~zkapp_command:zkapp_command_cached
            in
            match witnesses_specs_stmts with
            | [] ->
                Deferred.Or_error.error_string "no witnesses generated"
            | (witness, spec, stmt) :: rest as all_inputs ->
                let%bind (p1 : Ledger_proof.t) =
                  log_zkapp_cmd_base_snark ~logger
                    ~statement:{ stmt with sok_digest } ~spec
                    (M.of_zkapp_command_segment_exn ~witness)
                    ()
                in

                let%bind (p : Ledger_proof.t) =
                  Deferred.List.fold ~init:(Ok p1) rest
                    ~f:(fun acc (witness, spec, stmt) ->
                      let%bind (prev : Ledger_proof.t) = Deferred.return acc in
                      let%bind (curr : Ledger_proof.t) =
                        log_zkapp_cmd_base_snark ~logger
                          ~statement:{ stmt with sok_digest } ~spec
                          (M.of_zkapp_command_segment_exn ~witness)
                          ()
                      in
                      log_zkapp_cmd_merge_snark ~m ~logger ~sok_digest prev curr
                        () )
                in
                if
                  Transaction_snark.Statement.equal (Ledger_proof.statement p)
                    input
                then Deferred.return (Ok p)
                else (
                  [%log fatal]
                    "Zkapp_command transaction final statement mismatch \
                     Expected $expected Got $got. All inputs: $inputs"
                    ~metadata:
                      [ ( "got"
                        , Transaction_snark.Statement.to_yojson
                            (Ledger_proof.statement p) )
                      ; ("expected", Transaction_snark.Statement.to_yojson input)
                      ; ( "inputs"
                        , Zkapp_command_inputs.(
                            read_all_proofs_from_disk all_inputs
                            |> Stable.Latest.to_yojson) )
                      ] ;
                  Deferred.return
                    (Or_error.error_string
                       "Zkapp_command transaction final statement mismatch" ) )
            )
        | _ ->
            let%bind t =
              Deferred.return
              @@
              (* Validate the received transaction *)
              match witness.transaction with
              | Command (Signed_command cmd) -> (
                  match Signed_command.check cmd with
                  | Some cmd ->
                      ( Ok (Command (Signed_command cmd))
                        : Transaction.Valid.t Or_error.t )
                  | None ->
                      Or_error.errorf "Command has an invalid signature" )
              | Command (Zkapp_command _) ->
                  assert false
              | Fee_transfer ft ->
                  Ok (Fee_transfer ft)
              | Coinbase cb ->
                  Ok (Coinbase cb)
            in
            Deferred.Or_error.try_with ~here:[%here] (fun () ->
                M.of_non_zkapp_command_transaction
                  ~statement:{ input with sok_digest }
                  { Transaction_protocol_state.Poly.transaction = t
                  ; block_data = witness.protocol_state_body
                  ; global_slot = witness.block_global_slot
                  }
                  ~init_stack:witness.init_stack
                  (unstage
                     (Mina_ledger.Sparse_ledger.handler
                        witness.first_pass_ledger ) ) ) )
    | Merge (_, proof1, proof2) ->
        M.merge ~sok_digest proof1 proof2

  let perform_single_cached ~(logger : Logger.t) ~(cache : Cache.t)
      ~(m : (module Worker_state.S))
      ~(proof_cache_db : Proof_cache_tag.cache_db) ~sok_digest ~full_spec
      ~(single : Work.Selector.Single.Spec.Stable.Latest.t) () =
    let statement = Work.Work.Single.Spec.statement single in
    cache_and_time ~logger ~cache ~statement ~full_spec
      (perform_single_raw ~logger ~m ~proof_cache_db ~single ~sok_digest)

  let perform
      ~state:
        ({ m_with_proof_level; cache; proof_cache_db; logger } : Worker_state.t)
      ~(spec : Work.Partitioned.Spec.Stable.Latest.t)
      ~(sok_digest : Sok_message.Digest.Stable.Latest.t) =
    let open Deferred.Or_error.Let_syntax in
    let open Work.Partitioned in
    match m_with_proof_level with
    | Worker_state.Full ((module M) as m) -> (
        match spec with
        | Spec.Poly.Single { single_spec; pairing; metric = (); common } ->
            let%map proof, elapsed =
              perform_single_cached ~logger ~cache ~m ~proof_cache_db
                ~sok_digest ~single:single_spec ~full_spec:spec ()
            in
            Spec.Poly.Single
              { single_spec
              ; pairing
              ; metric = ({ proof; elapsed } : _ Proof_with_metric.Poly.t)
              ; common
              }
        | Spec.Poly.Sub_zkapp_command
            { spec =
                { spec =
                    Zkapp_command_job.Spec.Poly.Segment
                      { statement; witness; spec = segment_spec; _ } as
                    sub_zkapp_spec
                ; _
                } as sub_zkapp_job
            ; metric = ()
            } ->
            let witness =
              Transaction_witness.Zkapp_command_segment_witness
              .write_all_proofs_to_disk ~proof_cache_db witness
            in

            let statement_without_sok =
              Zkapp_command_job.Spec.Poly.statement sub_zkapp_spec
            in

            let%map proof, elapsed =
              log_zkapp_cmd_base_snark ~logger ~statement ~spec:segment_spec
                (M.of_zkapp_command_segment_exn ~witness)
              |> cache_and_time ~logger ~cache ~statement:statement_without_sok
                   ~full_spec:spec
            in
            Spec.Poly.Sub_zkapp_command
              { spec = sub_zkapp_job
              ; metric = ({ proof; elapsed } : _ Proof_with_metric.Poly.t)
              }
        | Spec.Poly.Sub_zkapp_command
            { spec =
                { spec = Zkapp_command_job.Spec.Poly.Merge { proof1; proof2; _ }
                ; _
                } as sub_zkapp_job
            ; metric = ()
            } ->
            let statement_without_sok =
              Zkapp_command_job.Spec.Poly.statement sub_zkapp_job.spec
            in

            let%map proof, elapsed =
              log_zkapp_cmd_merge_snark ~m ~logger ~sok_digest proof1 proof2
              |> cache_and_time ~logger ~cache ~statement:statement_without_sok
                   ~full_spec:spec
            in
            Spec.Poly.Sub_zkapp_command
              { spec = sub_zkapp_job
              ; metric = ({ proof; elapsed } : _ Proof_with_metric.Poly.t)
              }
        | Spec.Poly.Old { instances; common } ->
            let process
                ~(single_spec : Work.Selector.Single.Spec.Stable.Latest.t) =
              let%map proof, elapsed =
                perform_single_cached ~logger ~cache ~m ~proof_cache_db
                  ~sok_digest ~single:single_spec ~full_spec:spec ()
              in
              ({ proof; elapsed } : _ Proof_with_metric.Poly.t)
            in
            let%map instances =
              match instances with
              | `One (single_spec, ()) ->
                  let%map metric = process ~single_spec in
                  `One (single_spec, metric)
              | `Two ((spec1, ()), (spec2, ())) ->
                  let%bind metric1 = process ~single_spec:spec1 in
                  let%map metric2 = process ~single_spec:spec2 in
                  `Two ((spec1, metric1), (spec2, metric2))
            in

            Spec.Poly.Old { instances; common } )
    | Worker_state.Check | Worker_state.No_check ->
        let elapsed = Time.Span.zero in
        let data =
          Spec.Poly.map_with_statement
            ~f:(fun statement () ->
              Proof_with_metric.Poly.
                { proof =
                    (* NOTE: use a dummy proof *)
                    Transaction_snark.create
                      ~statement:{ statement with sok_digest }
                      ~proof:(Lazy.force Proof.transaction_dummy)
                ; elapsed
                } )
            spec
        in
        Deferred.Or_error.return data
end
