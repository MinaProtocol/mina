open Core
open Async

module Time_span_with_json = struct
  type t = Time.Span.t

  let to_yojson total = `String (Time.Span.to_string_hum total)

  let of_yojson = function
    | `String time ->
        Ok (Time.Span.of_string time)
    | _ ->
        Error "Snark_worker.Functor: Could not parse timespan"
end

(*FIX: register_event fails when adding base types to the constructors*)
module String_with_json = struct
  type t = string

  let to_yojson s = `String s

  let of_yojson = function
    | `String s ->
        Ok s
    | _ ->
        Error "Snark_worker.Functor: Could not parse string"
end

module Int_with_json = struct
  type t = int

  let to_yojson s = `Int s

  let of_yojson = function
    | `Int s ->
        Ok s
    | _ ->
        Error "Snark_worker.Functor: Could not parse int"
end

type Structured_log_events.t +=
  | Merge_snark_generated of { time : Time_span_with_json.t }
  [@@deriving register_event { msg = "Merge SNARK generated in $time" }]

type Structured_log_events.t +=
  | Base_snark_generated of
      { time : Time_span_with_json.t
      ; transaction_type : String_with_json.t
      ; zkapp_command_count : Int_with_json.t
      ; proof_zkapp_command_count : Int_with_json.t
      }
  [@@deriving
    register_event
      { msg =
          "Base SNARK generated in $time for $transaction_type transaction \
           with $zkapp_command_count zkapp_command and \
           $proof_zkapp_command_count proof zkapp_command"
      }]

(* NOTE: could swap with Debug.Impl, untested though *)
module Impl : Worker_impl.S = Prod.Impl

include Impl
module Work = Snark_work_lib

let perform (s : Worker_state.t) prover
    ({ instances; fee } as spec : Work.Partitioned.Spec.t) =
  One_or_two.Deferred_result.map instances ~f:(fun single_work ->
      let open Deferred.Or_error.Let_syntax in
      let%map proof, time =
        perform_single s
          ~message:(Mina_base.Sok_message.create ~fee ~prover)
          single_work
      in
      let work_tag =
        match single_work with
        | Regular (Transition _, _) ->
            `Transition
        | Regular (Merge _, _) ->
            `Merge
        | Sub_zkapp_command { spec = Segment _; _ } ->
            `Sub_zkapp_command `Segment
        | Sub_zkapp_command { spec = Merge _; _ } ->
            `Sub_zkapp_command `Merge
      in

      let proof_cached =
        Ledger_proof.Cached.write_proof_to_disk
          ~proof_cache_db:Proof_cache.cache_db proof
      in

      (proof_cached, (time, work_tag)) )
  |> Deferred.Or_error.map ~f:(function
       | `One (proof1, metrics1) ->
           { Work.Partitioned.Result.proofs = `One proof1
           ; metrics = `One metrics1
           ; spec
           ; prover
           }
       | `Two ((proof1, metrics1), (proof2, metrics2)) ->
           { Work.Partitioned.Result.proofs = `Two (proof1, proof2)
           ; metrics = `Two (metrics1, metrics2)
           ; spec
           ; prover
           } )

let dispatch rpc shutdown_on_disconnect query address =
  let%map res =
    Rpc.Connection.with_client
      ~handshake_timeout:
        (Time.Span.of_sec
           Node_config_unconfigurable_constants.rpc_handshake_timeout_sec )
      ~heartbeat_config:
        (Rpc.Connection.Heartbeat_config.create
           ~timeout:
             (Time_ns.Span.of_sec
                Node_config_unconfigurable_constants.rpc_heartbeat_timeout_sec )
           ~send_every:
             (Time_ns.Span.of_sec
                Node_config_unconfigurable_constants
                .rpc_heartbeat_send_every_sec )
           () )
      (Tcp.Where_to_connect.of_host_and_port address)
      (fun conn -> Rpc.Rpc.dispatch rpc conn query)
  in
  match res with
  | Error exn ->
      if shutdown_on_disconnect then
        failwithf
          !"Shutting down. Error using the RPC call, %s,: %s"
          (Rpc.Rpc.name rpc) (Exn.to_string_mach exn) ()
      else
        Error
          ( Error.createf !"Error using the RPC call, %s: %s" (Rpc.Rpc.name rpc)
          @@ Exn.to_string_mach exn )
  | Ok res ->
      res

(* WARN: This is largely identical to Init.Mina_run.log_snark_work_metrics, we should refactor this out *)
let emit_proof_metrics metrics instances logger =
  One_or_two.iter (One_or_two.zip_exn metrics instances)
    ~f:(fun ((time, tag), single) ->
      match tag with
      | `Sub_zkapp_command `Segment ->
          (* WARN:
             I don't know if this is the desired behavior, we need CI engineers to decide
          *)
          Perf_histograms.add_span
            ~name:"snark_worker_sub_zkapp_command_segment_time" time
      | `Sub_zkapp_command `Merge ->
          (* WARN:
             I don't know if this is the desired behavior, we need CI engineers to decide
          *)
          Perf_histograms.add_span
            ~name:"snark_worker_sub_zkapp_command_merge_time" time
      | `Merge ->
          (* WARN: This statement is just noop, not sure why it's here *)
          Mina_metrics.(
            Cryptography.Snark_work_histogram.observe
              Cryptography.snark_work_merge_time_sec (Time.Span.to_sec time)) ;
          [%str_log info] (Merge_snark_generated { time })
      | `Transition ->
          let transaction_type, zkapp_command_count, proof_zkapp_command_count =
            (*should be Some in the case of `Transition*)
            match Option.value_exn single with
            | Mina_transaction.Transaction.Command
                (Mina_base.User_command.Zkapp_command zkapp_command) ->
                (* WARN: now this is dead code, if we're using new
                   protocol between snark coordinator and workers *)
                let init =
                  match
                    (Mina_base.Account_update.of_fee_payer
                       zkapp_command.Mina_base.Zkapp_command.Poly.fee_payer )
                      .authorization
                  with
                  | Proof _ ->
                      (1, 1)
                  | _ ->
                      (1, 0)
                in
                let c, p =
                  Mina_base.Zkapp_command.Call_forest.fold
                    zkapp_command.account_updates ~init
                    ~f:(fun (count, proof_updates_count) account_update ->
                      ( count + 1
                      , if
                          Mina_base.Control.(
                            Tag.equal Proof
                              (tag
                                 account_update
                                   .Mina_base.Account_update.Poly.authorization ))
                        then proof_updates_count + 1
                        else proof_updates_count ) )
                in
                Mina_metrics.(
                  Cryptography.(
                    Counter.inc snark_work_zkapp_base_time_sec
                      (Time.Span.to_sec time) ;
                    Counter.inc_one snark_work_zkapp_base_submissions ;
                    Counter.inc zkapp_transaction_length (Float.of_int c) ;
                    Counter.inc zkapp_proof_updates (Float.of_int p))) ;
                ("zkapp_command", c, p)
            | Command (Signed_command _) ->
                Mina_metrics.(
                  Counter.inc Cryptography.snark_work_base_time_sec
                    (Time.Span.to_sec time)) ;
                ("signed command", 1, 0)
            | Coinbase _ ->
                Mina_metrics.(
                  Counter.inc Cryptography.snark_work_base_time_sec
                    (Time.Span.to_sec time)) ;
                ("coinbase", 1, 0)
            | Fee_transfer _ ->
                Mina_metrics.(
                  Counter.inc Cryptography.snark_work_base_time_sec
                    (Time.Span.to_sec time)) ;
                ("fee_transfer", 1, 0)
          in
          [%str_log info]
            (Base_snark_generated
               { time
               ; transaction_type
               ; zkapp_command_count
               ; proof_zkapp_command_count
               } ) )

let main ~logger ~proof_level ~constraint_constants daemon_address
    shutdown_on_disconnect =
  let%bind state = Worker_state.create ~constraint_constants ~proof_level () in
  let wait ?(sec = 0.5) () = after (Time.Span.of_sec sec) in
  (* retry interval with jitter *)
  let retry_pause sec = Random.float_range (sec -. 2.0) (sec +. 2.0) in
  let log_and_retry label error sec k =
    let error_str = Error.to_string_hum error in
    (* HACK: the bind before the call to go () produces an evergrowing
         backtrace history which takes forever to print and fills our disks.
         If the string becomes too long, chop off the first 10 lines and include
         only that *)
    ( if String.length error_str < 4096 then
      [%log error] !"Error %s: %{sexp:Error.t}" label error
    else
      let lines = String.split ~on:'\n' error_str in
      [%log error] !"Error %s: %s" label
        (String.concat ~sep:"\\n" (List.take lines 10)) ) ;
    let%bind () = wait ~sec () in
    (* FIXME: Use a backoff algo here *)
    k ()
  in
  let rec go () =
    let%bind daemon_address =
      let%bind cwd = Sys.getcwd () in
      [%log debug]
        !"Snark worker working directory $dir"
        ~metadata:[ ("dir", `String cwd) ] ;
      let path = "snark_coordinator" in
      match%bind Sys.file_exists path with
      | `Yes -> (
          let%map s = Reader.file_contents path in
          try Host_and_port.of_string (String.strip s)
          with _ -> daemon_address )
      | `No | `Unknown ->
          return daemon_address
    in
    [%log debug]
      !"Snark worker using daemon $addr"
      ~metadata:[ ("addr", `String (Host_and_port.to_string daemon_address)) ] ;
    match%bind
      dispatch Get_work.Stable.Latest.rpc shutdown_on_disconnect `V3
        daemon_address
    with
    | Error e ->
        log_and_retry "getting work" e (retry_pause 10.) go
    | Ok None ->
        let random_delay =
          Worker_state.worker_wait_time
          +. (0.5 *. Random.float Worker_state.worker_wait_time)
        in
        (* No work to be done -- quietly take a brief nap *)
        [%log info] "No jobs available. Napping for $time seconds"
          ~metadata:[ ("time", `Float random_delay) ] ;
        let%bind () = wait ~sec:random_delay () in
        go ()
    | Ok (Some (work_spec, public_key)) -> (
        let work_spec =
          Work.Partitioned.Spec.cache ~proof_cache_db:Proof_cache.cache_db
            work_spec
        in
        let serialize_wire_work_spec (work : Work.Partitioned.Single.Spec.t) =
          match work with
          | Regular (regular, _) ->
              let inner =
                Transaction_snark_work.Statement.compact_json_one
                  (Work.Work.Single.Spec.statement regular)
              in
              `Assoc [ ("regular", inner) ]
          | Sub_zkapp_command
              (zkapp_command : Work.Partitioned.Zkapp_command_job.t) ->
              `Assoc
                [ ( "sub_zkapp_command"
                  , Work.Partitioned.Zkapp_command_job.materialize zkapp_command
                    |> Work.Partitioned.Zkapp_command_job.Stable.Latest
                       .to_yojson )
                ]
        in
        (* Wire_work.Single.Spec. *)
        [%log info]
          "SNARK work $work_ids received from $address. Starting proof \
           generation"
          ~metadata:
            [ ("address", `String (Host_and_port.to_string daemon_address))
            ; ( "work_ids"
              , One_or_two.to_yojson serialize_wire_work_spec
                  work_spec.instances )
            ] ;
        let%bind () = wait () in
        (* Pause to wait for stdout to flush *)
        match%bind perform state public_key work_spec with
        | Error e ->
            let work_spec = Work.Partitioned.Spec.materialize work_spec in
            let%bind () =
              match%map
                dispatch Failed_to_generate_snark.Stable.Latest.rpc
                  shutdown_on_disconnect (e, work_spec, public_key)
                  daemon_address
              with
              | Error e ->
                  [%log error]
                    "Couldn't inform the daemon about the snark work failure"
                    ~metadata:[ ("error", Error_json.error_to_yojson e) ]
              | Ok () ->
                  ()
            in
            log_and_retry "performing work" e (retry_pause 10.) go
        | Ok result ->
            emit_proof_metrics result.metrics
              (Work.Partitioned.Result.transactions
                 (result : Work.Partitioned.Result.t) )
              logger ;
            [%log info] "Submitted completed SNARK work $work_ids to $address"
              ~metadata:
                [ ("address", `String (Host_and_port.to_string daemon_address))
                ; ( "work_ids"
                  , One_or_two.to_yojson serialize_wire_work_spec
                      work_spec.instances )
                ] ;
            let rec submit_work () =
              let result = Work.Partitioned.Result.materialize result in
              match%bind
                dispatch Submit_work.Stable.Latest.rpc shutdown_on_disconnect
                  result daemon_address
              with
              | Error e ->
                  log_and_retry "submitting work" e (retry_pause 10.)
                    submit_work
              | Ok message_from_server ->
                  ( match message_from_server with
                  | `Finished_by_others when_done ->
                      [%log info] "Work is finished by another worker at %s"
                        (Time.to_string when_done)
                  | `Timeout ->
                      [%log info]
                        "The submission is timeout, this means the worker take \
                         too long to complete the job, the coordinator rejects"
                  | `Ok ->
                      () ) ;
                  go ()
            in
            submit_work () )
  in
  go ()

let command_from_rpcs ~commit_id ~proof_level:default_proof_level
    ~constraint_constants
    (module Rpcs_versioned : Intf.Rpcs_versioned_S
      with type Work.ledger_proof = Inputs.Ledger_proof.t ) =
  Command.async ~summary:"Snark worker"
    (let open Command.Let_syntax in
    let%map_open daemon_port =
      flag "--daemon-address" ~aliases:[ "daemon-address" ]
        (required (Arg_type.create Host_and_port.of_string))
        ~doc:"HOST-AND-PORT address daemon is listening on"
    and proof_level =
      flag "--proof-level" ~aliases:[ "proof-level" ]
        (optional (Arg_type.create Genesis_constants.Proof_level.of_string))
        ~doc:"full|check|none"
    and shutdown_on_disconnect =
      flag "--shutdown-on-disconnect"
        ~aliases:[ "shutdown-on-disconnect" ]
        (optional bool)
        ~doc:"true|false Shutdown when disconnected from daemon (default:true)"
    and conf_dir = Cli_lib.Flag.conf_dir in
    fun () ->
      let logger =
        Logger.create () ~metadata:[ ("process", `String "Snark Worker") ]
      in
      let proof_level = Option.value ~default:default_proof_level proof_level in
      Option.value_map ~default:() conf_dir ~f:(fun conf_dir ->
          let logrotate_max_size = 1024 * 10 in
          let logrotate_num_rotate = 1 in
          Logger.Consumer_registry.register ~commit_id
            ~id:Logger.Logger_id.snark_worker
            ~processor:(Logger.Processor.raw ())
            ~transport:
              (Logger_file_system.dumb_logrotate ~directory:conf_dir
                 ~log_filename:"mina-snark-worker.log"
                 ~max_size:logrotate_max_size ~num_rotate:logrotate_num_rotate )
            () ) ;
      Signal.handle [ Signal.term ] ~f:(fun _signal ->
          [%log info]
            !"Received signal to terminate. Aborting snark worker process" ;
          Core.exit 0 ) ;
      main
        (module Rpcs_versioned)
        ~logger ~proof_level ~constraint_constants daemon_port
        (Option.value ~default:true shutdown_on_disconnect))

let arguments ~proof_level ~daemon_address ~shutdown_on_disconnect =
  [ "-daemon-address"
  ; Host_and_port.to_string daemon_address
  ; "-proof-level"
  ; Genesis_constants.Proof_level.to_string proof_level
  ; "-shutdown-on-disconnect"
  ; Bool.to_string shutdown_on_disconnect
  ]
