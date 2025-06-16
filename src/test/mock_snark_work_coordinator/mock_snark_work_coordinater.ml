(* NOTE:
   This mock coordinator runs a work partitioner and a verifier under the hood.
   It's expected the test to set up various workers that actively pull from the
   partitioner in separate processes, and generate proofs requested by the
   partitioner.
   Once all proofs are verified, we will exit with exit code 0.
*)
open Core_kernel
open Async
open Mina_base
open Pipe_lib

let read_all_specs_in_folder ~logger dir =
  let spec_queue = Queue.create () in
  let process_spec_file ?assumed_prover file =
    let full_path = dir ^ "/" ^ file in
    (*NOTE: ignoring fees, we'll use 0 for every spec in this test *)
    let Dumped_spec.{ prover; spec; _ } =
      Yojson.Safe.from_file full_path
      |> Dumped_spec.of_yojson |> Result.ok_or_failwith
    in
    match assumed_prover with
    | None ->
        Queue.enqueue spec_queue spec ;
        Deferred.return prover
    | Some assumed_prover ->
        let open Signature_lib.Public_key.Compressed in
        if equal assumed_prover prover then (
          Queue.enqueue spec_queue spec ;
          Deferred.return prover )
        else (
          [%log fatal]
            "Testcase has multiple provers, e.g. $prover1 and $prover2"
            ~metadata:
              [ ("prover1", to_yojson assumed_prover)
              ; ("prover2", to_yojson prover)
              ] ;
          exit 1 )
  in
  let%bind files = Sys.readdir dir in
  let files_seq = Array.to_sequence files in
  match Sequence.next files_seq with
  | None ->
      [%log info] "No spec files provided, exiting" ;
      exit 0
  | Some (first_file, rest_files) ->
      let%bind assumed_prover = process_spec_file first_file in
      let%map () =
        Sequence.iter_m ~bind:Deferred.bind ~return:Deferred.return rest_files
          ~f:(Fn.compose Deferred.ignore_m (process_spec_file ~assumed_prover))
      in
      (assumed_prover, spec_queue)

let start_verifier ~verifier ~num_specs_to_process ~input_sok_message ~logger
    ~(source : Snark_work_lib.Result.Combined.t Strict_pipe.Reader.t) =
  let rec loop remaining_specs =
    if remaining_specs = 0 then (
      [%log info] "Verified all proofs" ;
      Deferred.return () )
    else
      match%bind Strict_pipe.Reader.read source with
      | `Eof ->
          [%log fatal]
            "Remaining $remaining_proofs_to_verify to read, but pipe is closed \
             on mock coordinator's side"
            ~metadata:[ ("remaining_proofs_to_verify", `Int remaining_specs) ] ;
          exit 1
      | `Ok (stmt, { proof; fee = { fee; prover } }) -> (
          let actual_sok_message = Sok_message.create ~fee ~prover in
          if not (Sok_message.equal input_sok_message actual_sok_message) then (
            [%log fatal]
              "Sok_message used to prove is not same as actual sok_message in \
               the resulting proof"
              ~metadata:
                [ ("input_sok_message", Sok_message.to_yojson input_sok_message)
                ; ( "actual_sok_message"
                  , Sok_message.to_yojson actual_sok_message )
                ] ;
            exit 1 )
          else
            let verification_inputs =
              One_or_two.to_list proof
              |> List.map ~f:(fun proof -> (proof, actual_sok_message))
            in
            match%bind
              Verifier.verify_transaction_snarks verifier verification_inputs
            with
            | Ok (Ok ()) ->
                [%log info] "Proof verified"
                  ~metadata:
                    [ ( "proof"
                      , One_or_two.to_yojson Ledger_proof.to_yojson proof )
                    ; ("sok_message", Sok_message.to_yojson input_sok_message)
                    ; ( "statement"
                      , One_or_two.to_yojson
                          Transaction_snark.Statement.to_yojson stmt )
                    ; ("remaining_proofs", `Int (remaining_specs - 1))
                    ] ;
                loop (remaining_specs - 1)
            | Error e | Ok (Error e) ->
                [%log fatal] "Verification of proofs failed"
                  ~metadata:
                    [ ( "proof"
                      , One_or_two.to_yojson Ledger_proof.to_yojson proof )
                    ; ("sok_message", Sok_message.to_yojson input_sok_message)
                    ; ( "statement"
                      , One_or_two.to_yojson
                          Transaction_snark.Statement.to_yojson stmt )
                    ; ("error", `String (Error.to_string_hum e))
                    ] ;
                exit 1 )
  in
  loop num_specs_to_process

let command =
  Command.basic ~summary:"Mock coordinator test"
    (let open Command.Let_syntax in
    let%map_open dumped_spec_path =
      flag "--dumped-spec-path" (required string)
        ~doc:"Path for dumped work selector job specs"
    and coordinator_port =
      flag "--coordinator-port" (required int)
        ~doc:"Port for mock SNARK coordinator"
    and rpc_handshake_timeout =
      flag "--rpc-handshake-timeout"
        (optional_with_default 60.0 float)
        ~doc:"Timeout for RPC handshake (seconds)"
    and rpc_heartbeat_send_every =
      flag "--rpc-heartbeat-send-every"
        (optional_with_default 10.0 float)
        ~doc:"Period for RPC heartbeat (seconds)"
    and rpc_heartbeat_timeout =
      flag "--rpc-heartbeat-timeout"
        (optional_with_default 60.0 float)
        ~doc:"Timeout for RPC heartbeat (seconds)"
    and reassignment_timeout =
      flag "--reassignment-timeout"
        (optional_with_default 10.0 float)
        ~doc:"Timeout for Work partitioner to reassign a job (seconds)"
    in
    fun () ->
      let Genesis_proof.{ constraint_constants; _ } =
        Lazy.force Precomputed_values.for_unit_tests
      in
      let logger = Logger.create () in
      [%log info] "Starting verifier" ;
      (* HACK: this has to run in its own thread to avoid some weird bug *)
      let verifier =
        Async.Thread_safe.block_on_async_exn (fun () ->
            Verifier.For_tests.default ~constraint_constants ~logger
              ~proof_level:Full () )
      in
      [%log info] "Verifier initialized" ;
      let k () =
        let open Deferred.Let_syntax in
        [%log info] "Reading specs from folder"
          ~metadata:[ ("dumped_spec_path", `String dumped_spec_path) ] ;
        let%bind prover, predefined_specs =
          read_all_specs_in_folder ~logger dumped_spec_path
        in
        let num_specs_to_process = Queue.length predefined_specs in
        [%log info] "Read %d specs to generate proof" num_specs_to_process
          ~metadata:[ ("specs_to_process", `Int num_specs_to_process) ] ;
        let proof_cache_db = Proof_cache_tag.create_identity_db () in
        let partitioner =
          Work_partitioner.create
            ~reassignment_timeout:(Time.Span.of_sec reassignment_timeout)
            ~logger ~proof_cache_db
        in
        let completed_snark_work_source, completed_snark_work_sink =
          Strict_pipe.create ~name:"completed snark work"
            (Buffered (`Capacity 50, `Overflow Crash))
        in
        let input_sok_message =
          Sok_message.create ~fee:Currency.Fee.zero ~prover
        in
        Mock_coordinator.start ~predefined_specs ~partitioner ~logger
          ~port:coordinator_port ~rpc_handshake_timeout
          ~rpc_heartbeat_send_every ~rpc_heartbeat_timeout
          ~completed_snark_work_sink ~sok_message:input_sok_message
        |> Deferred.don't_wait_for ;
        start_verifier ~verifier ~num_specs_to_process ~input_sok_message
          ~logger ~source:completed_snark_work_source
      in
      Async.Thread_safe.block_on_async_exn k)

let () = Command_unix.run command
