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

(** retry interval with jitter *)
let retry_pause sec = Random.float_range (sec -. 2.0) (sec +. 2.0)

let submit_work ~logger ~metadata ~shutdown_on_disconnect ~daemon_address
    result_without_spec () =
  let log_result msg =
    [%log info] msg ~metadata ;
    Deferred.Or_error.return ()
  in
  match%bind
    dispatch Rpc_submit_work.Stable.Latest.rpc shutdown_on_disconnect
      result_without_spec daemon_address
  with
  | Error e ->
      Deferred.Or_error.fail e
  | Ok `Ok ->
      log_result "Submitted completed SNARK work $work_ids to $address"
  | Ok `Removed ->
      log_result "Result $work_ids slashed by $address"
  | Ok `SpecUnmatched ->
      log_result
        "Result $work_ids rejected by $address since it has wrong shape"

(** Reads daemon address from a local coordinator file or uses a default.

    Looks for snark_coordinator file; if present parses as host:port.
    Falls back to default on parse failure or missing/unknown file.  *)
let get_daemon_address default =
  let path = "snark_coordinator" in
  match%bind Sys.file_exists path with
  | `Yes -> (
      let%map s = Reader.file_contents path in
      try Host_and_port.of_string (String.strip s) with _ -> default )
  | `No | `Unknown ->
      return default

let emit_metrics ~elapsed ~logger = function
  | Spec.Partitioned.Poly.Single { spec = single_spec; _ } ->
      Metrics.emit_single_metrics_stable ~logger ~single_spec ~elapsed
  | Spec.Partitioned.Poly.Sub_zkapp_command { spec = sub_zkapp_spec; _ } ->
      Metrics.emit_subzkapp_metrics ~logger ~sub_zkapp_spec ~elapsed

(** Handle the `Result case - submits completed SNARK work to the daemon with retry logic.
    
    This handler processes successfully generated SNARK proofs by:
    1. Submitting the work result to the daemon via RPC
    2. On success: transitions to `No_spec state to request new work
    3. On failure: retries a limited number of times with exponential backoff (1.5x factor)
    4. After exhausting retries: logs rejection and transitions to `No_spec
    
    @param result_without_spec The completed SNARK work result
    @param retry_count Number of retries remaining
    @return Next state, either `No_spec or `Result with decremented retry count *)
let handle_result ~logger ~shutdown_on_disconnect daemon_address
    result_without_spec metadata retry_count retry_delay =
  match%bind
    submit_work ~logger ~metadata ~shutdown_on_disconnect ~daemon_address
      result_without_spec ()
  with
  | Error e when retry_count <= 0 ->
      [%log error]
        !"Work submission failed after all retries. Work rejected: \
          %{sexp:Error.t}"
        e ;
      return `No_spec
  | Error e ->
      [%log error]
        !"Error submitting work (retries remaining: %d): %{sexp:Error.t}"
        retry_count e ;
      let%map () = after @@ Time.Span.of_sec @@ retry_pause retry_delay in
      let retry_delay = retry_delay *. 1.5 in
      `Result
        ( daemon_address
        , result_without_spec
        , metadata
        , retry_count - 1
        , retry_delay )
  | Ok () ->
      return `No_spec

(** Handle the `Failed case - reports SNARK work generation failures to the daemon.
    
    This handler processes failed SNARK work generation by:
    1. Notifying the daemon about the failure via RPC
    2. Logging the error details for debugging
    3. Transitioning to `No_spec state after a retry delay
    
    @param e The error that caused the work generation to fail
    @param partitioned_id Identifier of the failed work partition
    @return Next state, `No_spec *)
let handle_failed ~logger ~shutdown_on_disconnect daemon_address e
    partitioned_id =
  let%bind () =
    match%map
      dispatch Rpc_failed_to_generate_snark.Stable.Latest.rpc
        shutdown_on_disconnect (e, partitioned_id) daemon_address
    with
    | Error e ->
        [%log error] "Couldn't inform the daemon about the snark work failure"
          ~metadata:[ ("error", Error_json.error_to_yojson e) ]
    | Ok () ->
        ()
  in
  [%log error] !"Error performing work: %{sexp:Error.t}" e ;
  after @@ Time.Span.of_sec @@ retry_pause 10. >>| const `No_spec

(** Handle the `Spec case - processes new SNARK work specifications.
    
    This handler performs the actual SNARK proof generation by:
    1. Logging the received work specification
    2. Executing the partitioned SNARK work using the worker state
    3. On success: emits metrics and transitions to `Result state
    4. On failure: transitions to `Failed state with error details
    
    @param state SNARK worker state
    @param partitioned_spec The SNARK work specification to process
    @return Next state, either `Result or `Failed *)
let handle_spec ~logger ~state daemon_address partitioned_spec =
  let metadata =
    [ ("address", `String (Host_and_port.to_string daemon_address))
    ; ( "work_ids"
      , Spec.Partitioned.Stable.Latest.statement partitioned_spec
        |> Mina_state.Snarked_ledger_state.to_yojson )
    ]
  in
  [%log info]
    "SNARK work $work_ids received from $address. Starting proof generation"
    ~metadata ;

  let id = Spec.Partitioned.Poly.get_id partitioned_spec in
  match%bind Prod.Impl.perform_partitioned ~state ~spec:partitioned_spec with
  | Error e ->
      return (`Failed (daemon_address, e, id))
  | Ok ({ data = elapsed; _ } as data) ->
      let wire_result = Result.Partitioned.Stable.Latest.{ id; data } in
      emit_metrics ~elapsed ~logger partitioned_spec ;
      return (`Result (daemon_address, wire_result, metadata, 3, 10.))

(** Handle the `No_spec case - requests new SNARK work from the daemon.
    
    This handler manages the work request cycle by:
    1. Determining the daemon address (from file or default)
    2. Requesting available work from the daemon via RPC
    3. On work available: transitions to `Spec state with the work
    4. On no work: sleeps with jitter and stays in `No_spec state
    5. On error: retries after delay, staying in `No_spec state
    
    @param default_daemon_address Default daemon address if no coordinator file
    @return Next state, either `Spec or `No_spec *)
let handle_no_spec ~logger ~shutdown_on_disconnect default_daemon_address =
  let%bind daemon_address = get_daemon_address default_daemon_address in
  [%log debug]
    !"Snark worker using daemon $addr"
    ~metadata:[ ("addr", `String (Host_and_port.to_string daemon_address)) ] ;
  match%bind
    dispatch Rpc_get_work.Stable.Latest.rpc shutdown_on_disconnect ()
      daemon_address
  with
  | Error e ->
      [%log error] !"Error getting work: %{sexp:Error.t}" e ;
      after @@ Time.Span.of_sec @@ retry_pause 10. >>| const `No_spec
  | Ok None ->
      let random_delay =
        Prod.Impl.Worker_state.worker_wait_time
        +. (0.5 *. Random.float Prod.Impl.Worker_state.worker_wait_time)
      in
      (* No work to be done -- quietly take a brief nap *)
      [%log info] "No jobs available. Napping for $time seconds"
        ~metadata:[ ("time", `Float random_delay) ] ;
      after (Time.Span.of_sec random_delay) >>| const `No_spec
  | Ok (Some partitioned_spec) ->
      return (`Spec (daemon_address, partitioned_spec))

(** Main SNARK worker event loop implementing a state machine for work processing.
    
    The worker operates as a finite state machine with four states, continuously
    cycling through work request, processing, and submission phases:
    
    Flow Diagram:
    ┌─────────────┐    get_work RPC     ┌──────────────┐
    │   No_spec   │ ──────────────────> │     Spec     │
    │ (idle/wait) │                     │ (processing) │
    └─────────────┘                     └──────────────┘
           ^                                     │
           │                                     │ perform_partitioned
           │ retry_delay                         │
           │                                     v
    ┌─────────────┐                     ┌──────────────┐
    │   Failed    │                     │    Result    │
    │ (error rpt) │ <─────────────────  │ (completed)  │
    └─────────────┘    on failure       └──────────────┘
           │                                     │
           │ report_failure RPC                  │ submit_work RPC
           │                                     │
           └─────────────────────────────────────┘
                         │
                         v
                   ┌─────────────┐
                   │   No_spec   │
                   │ (next cycle)│
                   └─────────────┘
    
    State Transitions:
    • No_spec → Spec: When work is available from daemon
    • No_spec → No_spec: When no work available (with sleep)
    • Spec → Result: When SNARK proof generation succeeds
    • Spec → Failed: When SNARK proof generation fails
    • Result → No_spec: When work submission succeeds
    • Result → Result: When work submission fails (infinite retry)
    • Failed → No_spec: After reporting failure to daemon (no retry on failure to report)
    
    Error Handling:
    • Network failures: Retry for get_work and submit_work RPCs
    • Work generation failures: Report to daemon and continue
    
    Worker loop runs indefinitely. *)
let main ~logger ~proof_level ~constraint_constants ~signature_kind
    default_daemon_address shutdown_on_disconnect =
  let%bind state =
    Prod.Impl.Worker_state.create ~constraint_constants ~proof_level
      ~signature_kind ()
  in
  let%map cwd = Sys.getcwd () in
  [%log debug]
    !"Snark worker working directory $dir"
    ~metadata:[ ("dir", `String cwd) ] ;
  Deferred.forever `No_spec
  @@ function
  | `Result
      (daemon_address, result_without_spec, metadata, retry_count, retry_delay)
    ->
      handle_result ~logger ~shutdown_on_disconnect daemon_address
        result_without_spec metadata retry_count retry_delay
  | `Failed (daemon_address, e, partitioned_id) ->
      handle_failed ~logger ~shutdown_on_disconnect daemon_address e
        partitioned_id
  | `Spec (daemon_address, partitioned_spec) ->
      handle_spec ~logger ~state daemon_address partitioned_spec
  | `No_spec ->
      handle_no_spec ~logger ~shutdown_on_disconnect default_daemon_address

let command_from_rpcs ~commit_id ~proof_level:default_proof_level
    ~constraint_constants =
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
      let signature_kind = Mina_signature_kind.t_DEPRECATED in
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
