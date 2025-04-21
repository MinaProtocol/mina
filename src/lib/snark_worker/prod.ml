open Core
open Async
open Mina_base
open Mina_transaction
module Zkapp_command_inputs = Work_partitioner.Shared.Zkapp_command_inputs

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

module Impl : Worker_impl.S = struct
  module Worker_state = struct
    module type S = Transaction_snark.S

    type t =
      { m : (module S) option
      ; cache : Cache.t
      ; proof_level : Genesis_constants.Proof_level.t
      }

    let create ~constraint_constants ~proof_level () =
      let m =
        match proof_level with
        | Genesis_constants.Proof_level.Full ->
            Some
              ( module Transaction_snark.Make (struct
                let constraint_constants = constraint_constants

                let proof_level = proof_level
              end) : S )
        | Check | No_check ->
            None
      in
      Deferred.return { m; cache = Cache.create (); proof_level }

    let worker_wait_time = 5.
  end

  let log_zkapp_cmd_base_snark ~logger ~statement ~spec ?all_inputs f =
    match%map.Deferred
      Deferred.Or_error.try_with ~here:[%here] (fun () -> f ~statement ~spec)
    with
    | Ok p ->
        Ok p
    | Error e ->
        let all_inputs_meta_data =
          match all_inputs with
          | None ->
              (* WARN: we may be missing inputs, as zkapp segment work doesn't pass
                          this over the network! *)
              []
          | Some all_inputs ->
              [ ( "inputs"
                , Zkapp_command_inputs.materialize all_inputs
                  |> Zkapp_command_inputs.Stable.Latest.to_yojson )
              ]
        in
        [%log fatal]
          "Transaction snark failed for input $spec $statement. All inputs: \
           $inputs. Error:  $error"
          ~metadata:
            ( [ ( "spec"
                , Transaction_snark.Zkapp_command_segment.Basic.to_yojson spec
                )
              ; ( "statement"
                , Transaction_snark.Statement.With_sok.to_yojson statement )
              ; ("error", `String (Error.to_string_hum e))
              ]
            @ all_inputs_meta_data ) ;
        Error e

  let log_zkapp_cmd_merge_snark ~logger ~sok_digest
      (module M : Transaction_snark.S) prev curr =
    match%map.Deferred M.merge ~sok_digest prev curr with
    | Ok p ->
        Ok p
    | Error e ->
        [%log fatal] "Merge snark failed for $stmt1 $stmt2. Error:  $error"
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

  let perform_single ({ m; cache; proof_level } : Worker_state.t) ~message =
    let open Deferred.Or_error.Let_syntax in
    let open Snark_work_lib in
    let sok_digest = Mina_base.Sok_message.digest message in
    let logger = Logger.create () in
    fun (single : single_spec) ->
      match proof_level with
      | Genesis_constants.Proof_level.Full -> (
          let (module M) = Option.value_exn m in
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
                        (* the [@sexp.opaque] in Work.Single.Spec.t means we can't derive yojson,
                           so we use the less-desirable sexp here
                        *)
                      , `String (Sexp.to_string (sexp_of_single_spec single)) )
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
                          (* WARN: we're forced to write proofs to disk to do the conversion here *)
                          let%bind witnesses_specs_stmts =
                            Work_partitioner.Shared.extract_zkapp_segment_works
                              ~m:(module M)
                              ~input
                              ~witness:
                                (Transaction_witness.write_all_proofs_to_disk w)
                              ~zkapp_command:
                                (Zkapp_command.write_all_proofs_to_disk
                                   zkapp_command )
                          in

                          match witnesses_specs_stmts with
                          | [] ->
                              Deferred.Or_error.error_string
                                "no witnesses generated"
                          | (witness, spec, stmt) :: rest as inputs ->
                              let%bind (p1 : Ledger_proof.t) =
                                log_zkapp_cmd_base_snark ~logger
                                  ~statement:{ stmt with sok_digest } ~spec
                                  ~all_inputs:inputs
                                  (M.of_zkapp_command_segment_exn ~witness)
                              in

                              let%bind (p : Ledger_proof.t) =
                                Deferred.List.fold ~init:(Ok p1) rest
                                  ~f:(fun acc (witness, spec, stmt) ->
                                    let%bind (prev : Ledger_proof.t) =
                                      Deferred.return acc
                                    in

                                    (* let log_zkapp_cmd_base_snark ~logger ~statement ~spec ?all_inputs f = *)
                                    let%bind (curr : Ledger_proof.t) =
                                      log_zkapp_cmd_base_snark ~logger
                                        ~statement:{ stmt with sok_digest }
                                        ~spec ~all_inputs:inputs
                                        (M.of_zkapp_command_segment_exn ~witness)
                                    in
                                    log_zkapp_cmd_merge_snark ~logger
                                      ~sok_digest
                                      (module M)
                                      prev curr )
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
                                      , Zkapp_command_inputs.materialize inputs
                                        |> Zkapp_command_inputs.Stable.Latest
                                           .to_yojson )
                                    ] ;
                                Deferred.return
                                  (Or_error.error_string
                                     "Zkapp_command transaction final \
                                      statement mismatch" ) ) )
                      | _ ->
                          let%bind t =
                            Deferred.return
                            @@
                            (* Validate the received transaction *)
                            match w.transaction with
                            | Command (Signed_command cmd) -> (
                                match Signed_command.check cmd with
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
                                { Transaction_protocol_state.Poly.transaction =
                                    t
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
end
