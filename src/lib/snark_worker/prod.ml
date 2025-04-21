open Core
open Async
open Mina_base
open Mina_transaction
module Work = Snark_work_lib
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

    type module_with_proof_level = Check | No_check | Full of (module S)

    type t = { m_with_proof_level : module_with_proof_level; cache : Cache.t }

    let create ~constraint_constants ~proof_level () =
      let m_with_proof_level =
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
      Deferred.return { m_with_proof_level; cache = Cache.create () }

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

  let perform_regular ~m:(module M : Transaction_snark.S) ~logger ~regular
      ~sok_digest =
    let open Deferred.Or_error.Let_syntax in
    (* WARN: a smilar copy of this exists in `Work_selector.Work_selector` *)
    match regular with
    | Snark_work_lib.Work.Single.Spec.Transition
        (input, (witness : Transaction_witness.t)) -> (
        match Transaction.read_all_proofs_from_disk witness.transaction with
        | Command (Zkapp_command zkapp_command) -> (
            (* NOTE: we only go down this path if coordinator is
               V2, still this is preserved for compatibility. *)
            let zkapp_command =
              Zkapp_command.write_all_proofs_to_disk zkapp_command
            in
            let%bind witnesses_specs_stmts =
              Work_partitioner.Shared.extract_zkapp_segment_works
                ~m:(module M)
                ~input ~witness ~zkapp_command
            in
            match witnesses_specs_stmts with
            | [] ->
                Deferred.Or_error.error_string "no witnesses generated"
            | (witness, spec, stmt) :: rest as inputs ->
                let%bind (p1 : Ledger_proof.t) =
                  log_zkapp_cmd_base_snark ~logger
                    ~statement:{ stmt with sok_digest } ~spec ~all_inputs:inputs
                    (M.of_zkapp_command_segment_exn ~witness)
                in

                let%bind (p : Ledger_proof.t) =
                  Deferred.List.fold ~init:(Ok p1) rest
                    ~f:(fun acc (witness, spec, stmt) ->
                      let%bind (prev : Ledger_proof.t) = Deferred.return acc in
                      let%bind (curr : Ledger_proof.t) =
                        log_zkapp_cmd_base_snark ~logger
                          ~statement:{ stmt with sok_digest } ~spec
                          ~all_inputs:inputs
                          (M.of_zkapp_command_segment_exn ~witness)
                      in
                      log_zkapp_cmd_merge_snark ~logger ~sok_digest
                        (module M)
                        prev curr )
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
                        , Zkapp_command_inputs.materialize inputs
                          |> Zkapp_command_inputs.Stable.Latest.to_yojson )
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
              match
                Transaction.read_all_proofs_from_disk witness.transaction
              with
              | Command (Signed_command cmd) -> (
                  match Signed_command.check cmd with
                  | Some cmd ->
                      ( Ok (Command (Signed_command cmd))
                        : Transaction.Valid.t Or_error.t )
                  | None ->
                      Or_error.errorf "Command has an invalid signature" )
              | Command (Zkapp_command _) ->
                  failwith "This path should be unreachable"
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
        let proof1 = Ledger_proof.Cached.read_proof_from_disk proof1 in
        let proof2 = Ledger_proof.Cached.read_proof_from_disk proof2 in
        M.merge ~sok_digest proof1 proof2

  let cache_and_time ~logger ~cache ~statement ~spec k =
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
                      (Sexp.to_string
                         Work.Partitioned.Single.Spec.(
                           materialize spec |> Stable.Latest.sexp_of_t) ) )
                ] ;
            Error e
        | Ok res ->
            Cache.add cache ~statement ~proof:res ;

            let total = Time.abs_diff (Time.now ()) start in
            Ok (res, total) )

  let perform_single ({ m_with_proof_level; cache } : Worker_state.t) ~message =
    let sok_digest = Mina_base.Sok_message.digest message in
    let logger = Logger.create () in
    fun (spec : Work.Partitioned.Single.Spec.t) ->
      let statement = Work.Partitioned.Single.Spec.statement spec in
      match m_with_proof_level with
      | Full ((module M) as m) ->
          cache_and_time ~logger ~cache ~statement ~spec (fun () ->
              match spec with
              | Regular (regular, _) ->
                  perform_regular ~m ~logger ~regular ~sok_digest
              | Sub_zkapp_command
                  { spec = Segment { statement; witness; spec }
                  ; pairing_id = _
                  ; job_uuid = _
                  } ->
                  log_zkapp_cmd_base_snark ~logger ~statement ~spec
                    (M.of_zkapp_command_segment_exn ~witness)
              | Sub_zkapp_command
                  { spec = Merge { proof1; proof2 }
                  ; pairing_id = _
                  ; job_uuid = _
                  } ->
                  let proof1 =
                    Ledger_proof.Cached.read_proof_from_disk proof1
                  in
                  let proof2 =
                    Ledger_proof.Cached.read_proof_from_disk proof2
                  in
                  log_zkapp_cmd_merge_snark ~logger ~sok_digest
                    (module M)
                    proof1 proof2 )
      | Check | No_check ->
          Deferred.Or_error.return
          @@ ( Transaction_snark.create
                 ~statement:{ statement with sok_digest }
                 ~proof:(Lazy.force Proof.transaction_dummy)
             , Time.Span.zero )
end
