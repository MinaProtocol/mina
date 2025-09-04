open Core
open Async
open Snark_work_lib

let command_name = "snark-worker"

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

let main ~logger ~proof_level ~constraint_constants ~signature_kind
    (module Rpcs_versioned : Intf.Rpcs_versioned_S) daemon_address
    shutdown_on_disconnect =
  let%bind state =
    Prod.Impl.Worker_state.create ~constraint_constants ~proof_level
      ~signature_kind ()
  in
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
      dispatch Rpcs_versioned.Get_work.Latest.rpc shutdown_on_disconnect ()
        daemon_address
    with
    | Error e ->
        log_and_retry "getting work" e (retry_pause 10.) go
    | Ok None ->
        let random_delay =
          Prod.Impl.Worker_state.worker_wait_time
          +. (0.5 *. Random.float Prod.Impl.Worker_state.worker_wait_time)
        in
        (* No work to be done -- quietly take a brief nap *)
        [%log info] "No jobs available. Napping for $time seconds"
          ~metadata:[ ("time", `Float random_delay) ] ;
        let%bind () = wait ~sec:random_delay () in
        go ()
    | Ok (Some (work, public_key)) -> (
        [%log info]
          "SNARK work $work_ids received from $address. Starting proof \
           generation"
          ~metadata:
            [ ("address", `String (Host_and_port.to_string daemon_address))
            ; ( "work_ids"
              , Transaction_snark_work.Statement.compact_json
                  (One_or_two.map (Work.Spec.instances work)
                     ~f:Work.Single.Spec.statement ) )
            ] ;
        let%bind () = wait () in
        (* Pause to wait for stdout to flush *)
        match%bind Prod.Impl.perform state public_key work with
        | Error e ->
            let%bind () =
              match%map
                dispatch Rpcs_versioned.Failed_to_generate_snark.Latest.rpc
                  shutdown_on_disconnect (e, work, public_key) daemon_address
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
            One_or_two.zip_exn work.instances result.metrics
            |> One_or_two.iter ~f:(fun (single_spec, (elapsed, _tag)) ->
                   (* [_tag]'s purpose is replaced by the whole single spec *)
                   Metrics.emit_single_metrics ~logger ~single_spec
                     ~data:{ data = elapsed; proof = () }
                     () ) ;
            [%log info] "Submitted completed SNARK work $work_ids to $address"
              ~metadata:
                [ ("address", `String (Host_and_port.to_string daemon_address))
                ; ( "work_ids"
                  , Transaction_snark_work.Statement.compact_json
                      (One_or_two.map (Work.Spec.instances work)
                         ~f:Work.Single.Spec.statement ) )
                ] ;
            let rec submit_work () =
              match%bind
                dispatch Rpcs_versioned.Submit_work.Latest.rpc
                  shutdown_on_disconnect result daemon_address
              with
              | Error e ->
                  log_and_retry "submitting work" e (retry_pause 10.)
                    submit_work
              | Ok () ->
                  go ()
            in
            submit_work () )
  in
  go ()

let command_from_rpcs ~commit_id ~proof_level:default_proof_level
    ~constraint_constants ~signature_kind
    (module Rpcs_versioned : Intf.Rpcs_versioned_S) =
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
    and log_json = Cli_lib.Flag.Log.json
    and log_level = Cli_lib.Flag.Log.level
    and file_log_level = Cli_lib.Flag.Log.file_log_level
    and conf_dir = Cli_lib.Flag.conf_dir in
    fun () ->
      let logger =
        Logger.create () ~metadata:[ ("process", `String "Snark Worker") ]
      in
      let proof_level = Option.value ~default:default_proof_level proof_level in
      Cli_lib.Stdout_log.setup log_json log_level ;
      Option.value_map ~default:() conf_dir ~f:(fun conf_dir ->
          let logrotate_max_size = 1024 * 10 in
          let logrotate_num_rotate = 1 in
          Logger.Consumer_registry.register ~commit_id
            ~id:Logger.Logger_id.snark_worker
            ~processor:(Logger.Processor.raw ~log_level:file_log_level ())
            ~transport:
              (Logger_file_system.dumb_logrotate ~directory:conf_dir
                 ~log_filename:"mina-snark-worker.log"
                 ~max_size:logrotate_max_size ~num_rotate:logrotate_num_rotate )
            () ) ;
      Signal.handle [ Signal.term ] ~f:(fun _signal ->
          [%log info]
            !"Received signal to terminate. Aborting snark worker process" ;
          Core.exit 0 ) ;
      main ~logger ~proof_level ~constraint_constants ~signature_kind
        (module Rpcs_versioned)
        daemon_port
        (Option.value ~default:true shutdown_on_disconnect))

let arguments ~proof_level ~daemon_address ~shutdown_on_disconnect ~conf_dir
    ~log_json ~log_level ~file_log_level =
  [ "--daemon-address"
  ; Host_and_port.to_string daemon_address
  ; "--proof-level"
  ; Genesis_constants.Proof_level.to_string proof_level
  ; "--shutdown-on-disconnect"
  ; Bool.to_string shutdown_on_disconnect
  ; "--config-directory"
  ; conf_dir
  ; "--file-log-level"
  ; Logger.Level.show file_log_level
  ; "--log-level"
  ; Logger.Level.show log_level
  ]
  @ if log_json then [ "--log-json" ] else []
