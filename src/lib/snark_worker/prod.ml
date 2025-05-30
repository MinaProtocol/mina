open Core
open Async
open Mina_base
open Mina_transaction

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

module Inputs = struct
  module Ledger_proof = Ledger_proof

  module Worker_state = struct
    module type S = Transaction_snark.S

    type proof_level_snark = Full of (module S) | Check | No_check

    type t =
      { proof_level_snark : proof_level_snark
      ; cache : Cache.t
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
        { proof_level_snark
        ; cache = Cache.create ()
        ; proof_cache_db
        ; logger = Logger.create ()
        }

    let worker_wait_time = 5.
  end

  let zkapp_command_inputs_to_yojson =
    let convert =
      List.map
        ~f:(fun
             ( (witness : Transaction_witness.Zkapp_command_segment_witness.t)
             , segment
             , statement )
           ->
          ( Transaction_witness.Zkapp_command_segment_witness
            .read_all_proofs_from_disk witness
          , segment
          , statement ) )
    in
    let impl =
      [%to_yojson:
        ( Transaction_witness.Zkapp_command_segment_witness.Stable.Latest.t
        * Transaction_snark.Zkapp_command_segment.Basic.t
        * Transaction_snark.Statement.With_sok.t )
        list]
    in
    Fn.compose impl convert

  let perform_single
      ({ cache; proof_level_snark; proof_cache_db; logger } : Worker_state.t)
      ~message (single : Snark_work_lib.Selector.Single.Spec.Stable.Latest.t) =
    let open Deferred.Or_error.Let_syntax in
    let open Snark_work_lib in
    let sok_digest = Mina_base.Sok_message.digest message in
    match proof_level_snark with
    | Full (module M) -> (
        let statement = Work.Single.Spec.statement single in
        let process k =
          let start = Time.now () in
          match%map.Async.Deferred
            Monitor.try_with_join_or_error ~here:[%here] k
          with
          | Error e ->
              [%log error] "SNARK worker failed: $error"
                ~metadata:
                  [ ("error", Error_json.error_to_yojson e)
                  ; ( "spec"
                    , Snark_work_lib.Selector.Single.Spec.Stable.Latest
                      .to_yojson single )
                  ] ;
              Error e
          | Ok res ->
              Cache.add cache ~statement ~proof:res ;
              let total = Time.abs_diff (Time.now ()) start in
              Ok (res, total)
        in
        match Cache.find cache statement with
        | Some proof ->
            Deferred.Or_error.return (proof, Time.Span.zero)
        | None -> (
            match single with
            | Work.Single.Spec.Transition
                (input, (w : Transaction_witness.Stable.Latest.t)) ->
                process (fun () ->
                    match w.transaction with
                    | Command (Zkapp_command zkapp_command) -> (
                        let%bind witnesses_specs_stmts =
                          Or_error.try_with (fun () ->
                              Transaction_snark.zkapp_command_witnesses_exn
                                ~constraint_constants:M.constraint_constants
                                ~global_slot:w.block_global_slot
                                ~state_body:w.protocol_state_body
                                ~fee_excess:Currency.Amount.Signed.zero
                                [ ( `Pending_coinbase_init_stack w.init_stack
                                  , `Pending_coinbase_of_statement
                                      { Transaction_snark
                                        .Pending_coinbase_stack_state
                                        .source =
                                          input.source.pending_coinbase_stack
                                      ; target =
                                          input.target.pending_coinbase_stack
                                      }
                                  , `Sparse_ledger w.first_pass_ledger
                                  , `Sparse_ledger w.second_pass_ledger
                                  , `Connecting_ledger_hash
                                      input.connecting_ledger_left
                                  , Zkapp_command.write_all_proofs_to_disk
                                      ~proof_cache_db zkapp_command )
                                ]
                              |> List.rev )
                          |> Result.map_error ~f:(fun e ->
                                 Error.createf
                                   !"Failed to generate inputs for \
                                     zkapp_command : %s: %s"
                                   ( Zkapp_command.Stable.Latest.to_yojson
                                       zkapp_command
                                   |> Yojson.Safe.to_string )
                                   (Error.to_string_hum e) )
                          |> Deferred.return
                        in
                        let log_base_snark f ~statement ~spec ~all_inputs =
                          match%map.Deferred
                            Deferred.Or_error.try_with ~here:[%here] (fun () ->
                                f ~statement ~spec )
                          with
                          | Ok p ->
                              Ok p
                          | Error e ->
                              [%log fatal]
                                "Transaction snark failed for input $spec \
                                 $statement. All inputs: $inputs. Error:  \
                                 $error"
                                ~metadata:
                                  [ ( "spec"
                                    , Transaction_snark.Zkapp_command_segment
                                      .Basic
                                      .to_yojson spec )
                                  ; ( "statement"
                                    , Transaction_snark.Statement.With_sok
                                      .to_yojson statement )
                                  ; ("error", `String (Error.to_string_hum e))
                                  ; ( "inputs"
                                    , zkapp_command_inputs_to_yojson all_inputs
                                    )
                                  ] ;
                              Error e
                        in
                        let log_merge_snark ~sok_digest prev curr ~all_inputs =
                          match%map.Deferred M.merge ~sok_digest prev curr with
                          | Ok p ->
                              Ok p
                          | Error e ->
                              [%log fatal]
                                "Merge snark failed for $stmt1 $stmt2. All \
                                 inputs: $inputs. Error:  $error"
                                ~metadata:
                                  [ ( "stmt1"
                                    , Transaction_snark.Statement.to_yojson
                                        (Ledger_proof.statement prev) )
                                  ; ( "stmt2"
                                    , Transaction_snark.Statement.to_yojson
                                        (Ledger_proof.statement curr) )
                                  ; ("error", `String (Error.to_string_hum e))
                                  ; ( "inputs"
                                    , zkapp_command_inputs_to_yojson all_inputs
                                    )
                                  ] ;
                              Error e
                        in
                        match witnesses_specs_stmts with
                        | [] ->
                            Deferred.Or_error.error_string
                              "no witnesses generated"
                        | (witness, spec, stmt) :: rest as inputs ->
                            let%bind (p1 : Ledger_proof.t) =
                              log_base_snark ~statement:{ stmt with sok_digest }
                                ~spec ~all_inputs:inputs
                                (M.of_zkapp_command_segment_exn ~witness)
                            in

                            let%bind (p : Ledger_proof.t) =
                              Deferred.List.fold ~init:(Ok p1) rest
                                ~f:(fun acc (witness, spec, stmt) ->
                                  let%bind (prev : Ledger_proof.t) =
                                    Deferred.return acc
                                  in
                                  let%bind (curr : Ledger_proof.t) =
                                    log_base_snark
                                      ~statement:{ stmt with sok_digest } ~spec
                                      ~all_inputs:inputs
                                      (M.of_zkapp_command_segment_exn ~witness)
                                  in
                                  log_merge_snark ~sok_digest prev curr
                                    ~all_inputs:inputs )
                            in
                            if
                              Transaction_snark.Statement.equal
                                (Ledger_proof.statement p) input
                            then Deferred.return (Ok p)
                            else (
                              [%log fatal]
                                "Zkapp_command transaction final statement \
                                 mismatch Expected $expected Got $got. All \
                                 inputs: $inputs"
                                ~metadata:
                                  [ ( "got"
                                    , Transaction_snark.Statement.to_yojson
                                        (Ledger_proof.statement p) )
                                  ; ( "expected"
                                    , Transaction_snark.Statement.to_yojson
                                        input )
                                  ; ( "inputs"
                                    , zkapp_command_inputs_to_yojson inputs )
                                  ] ;
                              Deferred.return
                                (Or_error.error_string
                                   "Zkapp_command transaction final statement \
                                    mismatch" ) ) )
                    | _ ->
                        let%bind t =
                          Deferred.return
                          @@
                          (* Validate the received transaction *)
                          match w.transaction with
                          | Command (Signed_command cmd) -> (
                              let signature_kind =
                                Mina_signature_kind.t_DEPRECATED
                              in
                              match
                                Signed_command.check ~signature_kind cmd
                              with
                              | Some cmd ->
                                  ( Ok (Command (Signed_command cmd))
                                    : Transaction.Valid.t Or_error.t )
                              | None ->
                                  Or_error.errorf
                                    "Command has an invalid signature" )
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
                                 (Mina_ledger.Sparse_ledger.handler
                                    w.first_pass_ledger ) ) ) )
            | Merge (_, proof1, proof2) ->
                process (fun () -> M.merge ~sok_digest proof1 proof2) ) )
    | Check | No_check ->
        (* Use a dummy proof. *)
        let stmt =
          match single with
          | Work.Single.Spec.Transition (stmt, _) ->
              stmt
          | Merge (stmt, _, _) ->
              stmt
        in
        Deferred.Or_error.return
        @@ ( Transaction_snark.create ~statement:{ stmt with sok_digest }
               ~proof:(Lazy.force Proof.transaction_dummy)
           , Time.Span.zero )

  let perform (s : Worker_state.t) public_key
      ({ instances; fee } as spec : Snark_work_lib.Selector.Spec.Stable.Latest.t)
      =
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
             { Snark_work_lib.Work.Result.proofs = `One proof1
             ; metrics = `One metrics1
             ; spec
             ; prover = public_key
             }
         | `Two ((proof1, metrics1), (proof2, metrics2)) ->
             { Snark_work_lib.Work.Result.proofs = `Two (proof1, proof2)
             ; metrics = `Two (metrics1, metrics2)
             ; spec
             ; prover = public_key
             } )
end
