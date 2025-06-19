(* NOTE:
   This mock coordinator runs a work partitioner backed by predefined specs from
   disk. It's expected by tester to set up various workers that pull from the
   partitioner in separate processes, and generate proofs requested by the
   partitioner.
   Once all proofs are generated, mock coordinator would dump them to specified
   folder and exit.
*)
open Core_kernel
open Async
open Mina_base
open Pipe_lib

open struct
  module Work = Snark_work_lib
end

let read_all_specs_in_folder ~logger dir =
  let spec_queue = Queue.create () in
  let process_spec_file ?assumed_prover file =
    let full_path = dir ^ "/" ^ file in
    (*NOTE: ignoring fees, we'll use 0 for every spec in this test *)
    let Work.Spec.Dumped.{ prover; spec; _ } =
      Yojson.Safe.from_file full_path
      |> Work.Spec.Dumped.of_yojson |> Result.ok_or_failwith
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
      [%log info] "Prover key for all snark workers"
        ~metadata:
          [ ( "prover"
            , Signature_lib.Public_key.Compressed.to_yojson assumed_prover )
          ] ;
      (assumed_prover, spec_queue)

let dump_proofs ~num_proofs_to_process ~input_sok_message ~logger ~output_folder
    ~source =
  let rec loop proof_index =
    if proof_index = num_proofs_to_process then (
      [%log info] "Dumped all $num_proofs_processed proofs"
        ~metadata:[ ("num_proofs_processed", `Int num_proofs_to_process) ] ;
      exit 0 )
    else
      match%bind Strict_pipe.Reader.read source with
      | `Eof ->
          [%log fatal]
            "Remaining $remaining_proofs to read, but pipe is closed on mock \
             coordinator's side"
            ~metadata:
              [ ("remaining_proofs", `Int (num_proofs_to_process - proof_index))
              ] ;
          exit 1
      | `Ok ((stmt, { proof; fee = { fee; prover } }) : Work.Result.Combined.t)
        ->
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
            (* WARN: the order of these proofs are not guaranteed to match up input! *)
            let output_file =
              Printf.sprintf "%s/proof_%d.json" output_folder proof_index
            in
            One_or_two.to_list proof
            |> List.map ~f:(fun proof -> (proof, actual_sok_message))
            |> [%derive.to_yojson: (Ledger_proof.t * Sok_message.t) list]
            |> Yojson.Safe.to_file output_file ;
            [%log info] "Saved proof for $stmt in $output_file"
              ~metadata:
                [ ("stmt", Transaction_snark_work.Statement.to_yojson stmt)
                ; ("output_file", `String output_file)
                ] ;
            loop (proof_index + 1)
  in
  loop 0

let command =
  Command.async ~summary:"Mock coordinator test"
    (let open Command.Let_syntax in
    let%map_open dumped_spec_path =
      flag "--dumped-spec-path" (required string)
        ~doc:"Path for dumped work selector job specs"
    and coordinator_port =
      flag "--coordinator-port" (required int)
        ~doc:"Port for mock SNARK coordinator"
    and output_folder =
      flag "--output-folder" (required string)
        ~doc:"Folder to store proofs generated combined by mock coordinator"
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
      let logger = Logger.create () in
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
      Deferred.all_unit
        [ Mock_coordinator.start ~predefined_specs ~partitioner ~logger
            ~port:coordinator_port ~rpc_handshake_timeout
            ~rpc_heartbeat_send_every ~rpc_heartbeat_timeout
            ~completed_snark_work_sink ~sok_message:input_sok_message
        ; dump_proofs ~num_proofs_to_process:num_specs_to_process
            ~input_sok_message ~logger ~source:completed_snark_work_source
            ~output_folder
        ])

let () = Command_unix.run command
