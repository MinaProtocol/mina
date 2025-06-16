open Core
open Async
open Events
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

let emit_proof_metrics metrics instances logger =
  One_or_two.iter (One_or_two.zip_exn metrics instances)
    ~f:(fun ((time, tag), single) ->
      match tag with
      | `Merge ->
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
  let%bind state =
    Prod.Impl.Worker_state.create ~constraint_constants ~proof_level ()
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
      dispatch Rpc_get_work.Stable.Latest.rpc shutdown_on_disconnect `V3
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
    | Ok (Some partitioned_spec) -> (
        let address_json =
          ("address", `String (Host_and_port.to_string daemon_address))
        in
        let work_ids_json =
          ( "work_ids"
          , Spec.Partitioned.Stable.Latest.statement partitioned_spec
            |> Mina_state.Snarked_ledger_state.to_yojson )
        in
        [%log info]
          "SNARK work $work_ids received from $address. Starting proof \
           generation"
          ~metadata:[ address_json; work_ids_json ] ;
        let%bind () = wait () in
        (* Pause to wait for stdout to flush *)
        match%bind
          Prod.Impl.perform_partitioned ~state ~spec:partitioned_spec
        with
        | Error e ->
            let partitioned_id =
              Spec.Partitioned.Poly.map ~f_single_spec:(const ())
                ~f_subzkapp_spec:(const ()) ~f_data:(const ()) partitioned_spec
            in
            let%bind () =
              match%map
                dispatch Rpc_failed_to_generate_snark.Stable.Latest.rpc
                  shutdown_on_disconnect (e, partitioned_id) daemon_address
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
            (* TODO: bring back metrics in subsequent PRs *)
            (* emit_proof_metrics result.metrics *)
            (*   (Selector.Result.Stable.Latest.transactions result) *)
            (*   logger ; *)
            [%log info] "Submitted completed SNARK work $work_ids to $address"
              ~metadata:[ address_json; work_ids_json ] ;
            let rec submit_work () =
              match%bind
                dispatch Rpc_submit_work.Stable.Latest.rpc
                  shutdown_on_disconnect result daemon_address
              with
              | Error e ->
                  log_and_retry "submitting work" e (retry_pause 10.)
                    submit_work
              | Ok `Ok ->
                  go ()
              | Ok `Removed ->
                  [%log info] "Result $work_ids slashed by $address"
                    ~metadata:[ address_json; work_ids_json ] ;
                  go ()
              | Ok `SpecUnmatched ->
                  [%log info]
                    "Result $work_ids rejected by $address since it has wrong \
                     shape"
                    ~metadata:[ address_json; work_ids_json ] ;
                  go ()
            in
            submit_work () )
  in
  go ()

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
      main ~logger ~proof_level ~constraint_constants daemon_port
        (Option.value ~default:true shutdown_on_disconnect))

let arguments ~proof_level ~daemon_address ~shutdown_on_disconnect =
  [ "-daemon-address"
  ; Host_and_port.to_string daemon_address
  ; "-proof-level"
  ; Genesis_constants.Proof_level.to_string proof_level
  ; "-shutdown-on-disconnect"
  ; Bool.to_string shutdown_on_disconnect
  ]
