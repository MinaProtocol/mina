open Core
open Async
open Mina_base
open Mina_transaction
open Work_partitioner.Snark_worker_shared

open struct
  module Work = Snark_work_lib
end

module Impl = struct
  module Worker_state = struct
    module type S = Transaction_snark.S

    type proof_level_snark = Full of (module S) | Check | No_check

    type t =
      { proof_level_snark : proof_level_snark
      ; proof_cache_db : Proof_cache_tag.cache_db
      ; logger : Logger.t
      }

    let create ~constraint_constants ~proof_level () =
      let proof_cache_db = Proof_cache_tag.create_identity_db () in
      let proof_level_snark =
        match proof_level with
        | Genesis_constants.Proof_level.Full ->
            Full
              ( module Transaction_snark.Make (struct
                let constraint_constants = constraint_constants

                let proof_level = proof_level
              end) : S )
        | Check ->
            Check
        | No_check ->
            No_check
      in
      Deferred.return
        { proof_level_snark; proof_cache_db; logger = Logger.create () }

    let worker_wait_time = 5.
  end

  (* NOTE: the reason witnesses_specs_stmts is optional in
     [log_subzkapp_base_snark] and [log_subzkapp_merge_snark] is that when
     receiving a partitioned spec holding a subzkapp merge/segment, we don't
     know all of [witnesses_specs_stmts]. *)
  let log_subzkapp_base_snark ?witnesses_specs_stmts ~logger ~statement ~spec f
      () =
    match%map.Deferred
      Deferred.Or_error.try_with ~here:[%here] (fun () -> f ~statement ~spec)
    with
    | Ok p ->
        Ok p
    | Error e ->
        let metadata_without_all_inputs =
          [ ( "spec"
            , Transaction_snark.Zkapp_command_segment.Basic.to_yojson spec )
          ; ( "statement"
            , Transaction_snark.Statement.With_sok.to_yojson statement )
          ; ("error", `String (Error.to_string_hum e))
          ]
        in
        let metadata =
          match witnesses_specs_stmts with
          | None ->
              metadata_without_all_inputs
          | Some all_inputs ->
              ( "all_inputs"
              , Zkapp_command_inputs.(
                  read_all_proofs_from_disk all_inputs
                  |> Stable.Latest.to_yojson) )
              :: metadata_without_all_inputs
        in
        [%log fatal]
          "Transaction snark failed for input $spec $statement. Error: $error"
          ~metadata ;
        Error e

  let log_subzkapp_merge_snark ?witnesses_specs_stmts
      ~m:(module M : Worker_state.S) ~logger ~sok_digest prev curr () =
    match%map.Deferred M.merge ~sok_digest prev curr with
    | Ok p ->
        Ok p
    | Error e ->
        let metadata_without_all_inputs =
          [ ( "stmt1"
            , Transaction_snark.Statement.to_yojson
                (Ledger_proof.statement prev) )
          ; ( "stmt2"
            , Transaction_snark.Statement.to_yojson
                (Ledger_proof.statement curr) )
          ; ("error", `String (Error.to_string_hum e))
          ]
        in
        let metadata =
          match witnesses_specs_stmts with
          | None ->
              metadata_without_all_inputs
          | Some all_inputs ->
              ( "all_inputs"
              , Zkapp_command_inputs.(
                  read_all_proofs_from_disk all_inputs
                  |> Stable.Latest.to_yojson) )
              :: metadata_without_all_inputs
        in

        [%log fatal] "Merge snark failed for $stmt1 $stmt2. Error: $error"
          ~metadata ;
        Error e

  let measure_runtime ~logger ~(spec_json : string * Yojson.Safe.t) k =
    let start = Time.now () in
    match%map.Async.Deferred Monitor.try_with_join_or_error ~here:[%here] k with
    | Error e ->
        [%log error] "SNARK worker failed: $error"
          ~metadata:[ ("error", Error_json.error_to_yojson e); spec_json ] ;
        Error e
    | Ok res ->
        let elapsed = Time.abs_diff (Time.now ()) start in
        Ok (res, elapsed)

  let perform_single_untimed ~(m : (module Worker_state.S)) ~logger
      ~proof_cache_db ~single_spec ~signature_kind ~sok_digest () =
    let open Deferred.Or_error.Let_syntax in
    let (module M) = m in
    match single_spec with
    | Work.Work.Single.Spec.Transition
        (input, (w : Transaction_witness.Stable.Latest.t)) -> (
        match w.transaction with
        | Command (Zkapp_command zkapp_command) -> (
            let%bind witnesses_specs_stmts =
              extract_zkapp_segment_works ~m ~input ~witness:w
                ~zkapp_command:
                  (Zkapp_command.write_all_proofs_to_disk ~signature_kind
                     ~proof_cache_db zkapp_command )
              |> Deferred.return
            in
            match Mina_stdlib.Nonempty_list.uncons witnesses_specs_stmts with
            | (witness, spec, stmt), rest ->
                let%bind (p1 : Ledger_proof.t) =
                  log_subzkapp_base_snark ~witnesses_specs_stmts ~logger
                    ~statement:{ stmt with sok_digest } ~spec
                    (M.of_zkapp_command_segment_exn ~witness)
                    ()
                in

                let%bind (p : Ledger_proof.t) =
                  Deferred.List.fold ~init:(Ok p1) rest
                    ~f:(fun acc (witness, spec, stmt) ->
                      let%bind (prev : Ledger_proof.t) = Deferred.return acc in
                      let%bind (curr : Ledger_proof.t) =
                        log_subzkapp_base_snark ~witnesses_specs_stmts ~logger
                          ~statement:{ stmt with sok_digest } ~spec
                          (M.of_zkapp_command_segment_exn ~witness)
                          ()
                      in
                      log_subzkapp_merge_snark ~witnesses_specs_stmts ~m ~logger
                        ~sok_digest prev curr () )
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
                            witnesses_specs_stmts |> read_all_proofs_from_disk
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
              match w.transaction with
              | Command (Signed_command cmd) -> (
                  let signature_kind = Mina_signature_kind.t_DEPRECATED in
                  match Signed_command.check ~signature_kind cmd with
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
                  ; block_data = w.protocol_state_body
                  ; global_slot = w.block_global_slot
                  }
                  ~init_stack:w.init_stack
                  (unstage
                     (Mina_ledger.Sparse_ledger.handler w.first_pass_ledger) ) )
        )
    | Merge (_, proof1, proof2) ->
        M.merge ~sok_digest proof1 proof2

  let perform_single
      ({ proof_level_snark; proof_cache_db; logger } : Worker_state.t) ~message
      (single_spec : Work.Selector.Single.Spec.Stable.Latest.t) =
    let signature_kind = Mina_signature_kind.t_DEPRECATED in
    let sok_digest = Mina_base.Sok_message.digest message in
    match proof_level_snark with
    | Full ((module M) as m) ->
        measure_runtime ~logger
          ~spec_json:
            ("single_spec", Work.Spec.Single.Stable.Latest.to_yojson single_spec)
          (perform_single_untimed ~m ~logger ~proof_cache_db ~single_spec
             ~sok_digest ~signature_kind )
    | Check | No_check ->
        (* Use a dummy proof. *)
        let stmt =
          match single_spec with
          | Work.Work.Single.Spec.Transition (stmt, _) ->
              stmt
          | Merge (stmt, _, _) ->
              stmt
        in
        Deferred.Or_error.return
        @@ ( Transaction_snark.create ~statement:{ stmt with sok_digest }
               ~proof:(Lazy.force Proof.transaction_dummy)
           , Time.Span.zero )

  (* TODO: remove this after whole snark worker PR series had been merged *)
  let perform (s : Worker_state.t) public_key
      ({ instances; fee } as spec : Work.Selector.Spec.Stable.Latest.t) =
    One_or_two.Deferred_result.map instances ~f:(fun w ->
        let open Deferred.Or_error.Let_syntax in
        let%map proof, time =
          perform_single s
            ~message:(Mina_base.Sok_message.create ~fee ~prover:public_key)
            w
        in
        ( proof
        , (time, match w with Transition _ -> `Transition | Merge _ -> `Merge)
        ) )
    |> Deferred.Or_error.map ~f:(function
         | `One (proof1, metrics1) ->
             { Work.Work.Result.proofs = `One proof1
             ; metrics = `One metrics1
             ; spec
             ; prover = public_key
             }
         | `Two ((proof1, metrics1), (proof2, metrics2)) ->
             { Work.Work.Result.proofs = `Two (proof1, proof2)
             ; metrics = `Two (metrics1, metrics2)
             ; spec
             ; prover = public_key
             } )

  let perform_partitioned
      ~state:({ proof_level_snark; proof_cache_db; logger } : Worker_state.t)
      ~spec:(partitioned_spec : Work.Spec.Partitioned.Stable.Latest.t) :
      Work.Result.Partitioned.Stable.Latest.t Deferred.Or_error.t =
    let open Deferred.Or_error.Let_syntax in
    let sok_digest =
      Work.Spec.Partitioned.Poly.sok_message partitioned_spec
      |> Sok_message.digest
    in
    let signature_kind = Mina_signature_kind.t_DEPRECATED in
    match proof_level_snark with
    | Worker_state.Full ((module M) as m) -> (
        match partitioned_spec with
        | Work.Spec.Partitioned.Poly.Single
            { job = { spec = single_spec; _ } as job; data = () } ->
            let%map proof, elapsed =
              measure_runtime ~logger
                ~spec_json:
                  ( "single_spec"
                  , Work.Spec.Single.Stable.Latest.to_yojson single_spec )
                (perform_single_untimed ~m ~logger ~proof_cache_db ~single_spec
                   ~sok_digest ~signature_kind )
            in
            Work.Spec.Partitioned.Poly.Single
              { job = { job with spec = () }
              ; data = { Proof_carrying_data.data = elapsed; proof }
              }
        | Work.Spec.Partitioned.Poly.Sub_zkapp_command
            { job =
                { spec =
                    Work.Spec.Sub_zkapp.Stable.Latest.Segment
                      { statement; witness; spec = segment_spec; _ } as
                    sub_zkapp_spec
                ; _
                } as job
            ; data = ()
            } ->
            let witness =
              Transaction_witness.Zkapp_command_segment_witness
              .write_all_proofs_to_disk ~proof_cache_db witness
            in

            let%map proof, elapsed =
              log_subzkapp_base_snark ~logger ~statement ~spec:segment_spec
                (M.of_zkapp_command_segment_exn ~witness)
              |> measure_runtime ~logger
                   ~spec_json:
                     ( "subzkapp_spec"
                     , Work.Spec.Sub_zkapp.Stable.Latest.to_yojson
                         sub_zkapp_spec )
            in

            Work.Spec.Partitioned.Poly.Sub_zkapp_command
              { job = { job with spec = () }
              ; data = { Proof_carrying_data.data = elapsed; proof }
              }
        | Work.Spec.Partitioned.Poly.Sub_zkapp_command
            { job =
                { spec =
                    Work.Spec.Sub_zkapp.Stable.Latest.Merge { proof1; proof2 }
                    as sub_zkapp_spec
                ; _
                } as job
            ; data = ()
            } ->
            let%map proof, elapsed =
              log_subzkapp_merge_snark ~m ~logger ~sok_digest proof1 proof2
              |> measure_runtime ~logger
                   ~spec_json:
                     ( "subzkapp_spec"
                     , Work.Spec.Sub_zkapp.Stable.Latest.to_yojson
                         sub_zkapp_spec )
            in
            Work.Spec.Partitioned.Poly.Sub_zkapp_command
              { job = { job with spec = () }
              ; data = { Proof_carrying_data.data = elapsed; proof }
              } )
    | Worker_state.Check | Worker_state.No_check ->
        let elapsed = Time.Span.zero in
        let statement =
          Work.Spec.Partitioned.Stable.Latest.statement partitioned_spec
        in
        (* NOTE: use a dummy proof *)
        let proof =
          Transaction_snark.create
            ~statement:{ statement with sok_digest }
            ~proof:(Lazy.force Proof.transaction_dummy)
        in
        let data = { Proof_carrying_data.data = elapsed; proof } in
        let result =
          match partitioned_spec with
          | Work.Spec.Partitioned.Poly.Single { job; _ } ->
              Work.Spec.Partitioned.Poly.Single
                { job = { job with spec = () }; data }
          | Work.Spec.Partitioned.Poly.Sub_zkapp_command { job; _ } ->
              Work.Spec.Partitioned.Poly.Sub_zkapp_command
                { job = { job with spec = () }; data }
        in
        Deferred.Or_error.return result
end
