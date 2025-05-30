open Core
open Async
module Graphql_cohttp_async =
  Graphql_internal.Make (Graphql_async.Schema) (Cohttp_async.Io)
    (Cohttp_async.Body)

let snark_job_list_json t =
  let open Participating_state.Let_syntax in
  let%map sl = Mina_lib.best_staged_ledger t in
  Staged_ledger.Scan_state.snark_job_list_json (Staged_ledger.scan_state sl)

let snark_pool_list t =
  Mina_lib.snark_pool t |> Network_pool.Snark_pool.resource_pool
  |> Network_pool.Snark_pool.Resource_pool.snark_pool_json
  |> Yojson.Safe.to_string

(* create reader, writer for protocol versions, but really for any one-line item in conf_dir *)
let make_conf_dir_item_io ~conf_dir ~filename =
  let item_file = conf_dir ^/ filename in
  let read_item () =
    let open Stdlib in
    let inp = open_in item_file in
    let res = input_line inp in
    close_in inp ; res
  in
  let write_item item =
    let open Stdlib in
    let outp = open_out item_file in
    output_string outp (item ^ "\n") ;
    close_out outp
  in
  (read_item, write_item)

let get_proposed_protocol_version_opt ~conf_dir ~logger =
  let read_protocol_version, write_protocol_version =
    make_conf_dir_item_io ~conf_dir ~filename:"proposed_protocol_version"
  in
  function
  | None -> (
      try
        (* not provided on command line, try to read from config dir *)
        let protocol_version = read_protocol_version () in
        [%log info]
          "Setting proposed protocol version to $protocol_version from config"
          ~metadata:[ ("protocol_version", `String protocol_version) ] ;
        Some (Protocol_version.of_string_exn protocol_version)
      with Sys_error _ ->
        (* not on command-line, not in config dir, there's no proposed protocol version *)
        None )
  | Some protocol_version -> (
      let validate_cli_protocol_version protocol_version =
        if Option.is_none (Protocol_version.of_string_opt protocol_version) then (
          [%log fatal]
            "Proposed protocol version provided on command line is invalid"
            ~metadata:
              [ ("proposed_protocol_version", `String protocol_version) ] ;
          failwith "Proposed protocol version from command line is invalid" )
      in
      try
        (* overwrite if the command line value disagrees with the value in the config *)
        let config_protocol_version = read_protocol_version () in
        if String.equal config_protocol_version protocol_version then (
          [%log info]
            "Using proposed protocol version $protocol_version from command \
             line, which matches the one in the config"
            ~metadata:[ ("protocol_version", `String protocol_version) ] ;
          Some (Protocol_version.of_string_exn config_protocol_version) )
        else (
          validate_cli_protocol_version protocol_version ;
          write_protocol_version protocol_version ;
          [%log info]
            "Overwriting Mina config proposed protocol version \
             $config_proposed_protocol_version with proposed protocol version \
             $protocol_version from the command line"
            ~metadata:
              [ ( "config_proposed_protocol_version"
                , `String config_protocol_version )
              ; ("proposed_protocol_version", `String protocol_version)
              ] ;
          Some (Protocol_version.of_string_exn protocol_version) )
      with Sys_error _ ->
        (* use value provided on command line, write to config dir *)
        validate_cli_protocol_version protocol_version ;
        write_protocol_version protocol_version ;
        [%log info]
          "Using proposed protocol version from command line, writing to config"
          ~metadata:[ ("protocol_version", `String protocol_version) ] ;
        Some (Protocol_version.of_string_exn protocol_version) )

(*TODO check deferred now and copy theose files to the temp directory*)
let log_shutdown ~conf_dir ~top_logger coda_ref =
  let logger =
    Logger.extend top_logger
      [ ("coda_run", `String "Logging state before program ends") ]
  in
  let frontier_file = conf_dir ^/ "frontier.dot" in
  let mask_file = conf_dir ^/ "registered_masks.dot" in
  (* ledger visualization *)
  [%log debug] "%s" (Visualization_message.success "registered masks" mask_file) ;
  Mina_ledger.Ledger.Debug.visualize ~filename:mask_file ;
  match !coda_ref with
  | None ->
      [%log warn]
        "Shutdown before Mina instance was created, not saving a visualization"
  | Some t -> (
      (*Transition frontier visualization*)
      match Mina_lib.visualize_frontier ~filename:frontier_file t with
      | `Active () ->
          [%log debug] "%s"
            (Visualization_message.success "transition frontier" frontier_file)
      | `Bootstrapping ->
          [%log debug] "%s"
            (Visualization_message.bootstrap "transition frontier") )

let remove_prev_crash_reports ~conf_dir =
  Core.Sys.command (sprintf "rm -rf %s/coda_crash_report*" conf_dir)

let summary exn_json =
  let uname = Core.Unix.uname () in
  let daemon_command =
    sprintf !"Command: %{sexp: string array}" (Sys.get_argv ())
  in
  `Assoc
    [ ("OS_type", `String Sys.os_type)
    ; ("Release", `String (Core.Unix.Utsname.release uname))
    ; ("Machine", `String (Core.Unix.Utsname.machine uname))
    ; ("Sys_name", `String (Core.Unix.Utsname.sysname uname))
    ; ("Exception", exn_json)
    ; ("Command", `String daemon_command)
    ; ("Coda_commit", `String Mina_version.commit_id)
    ]

let coda_status coda_ref =
  Option.value_map coda_ref
    ~default:
      (Deferred.return (`String "Shutdown before Mina instance was created"))
    ~f:(fun t ->
      Mina_commands.get_status ~flag:`Performance t
      >>| Daemon_rpcs.Types.Status.to_yojson )

let make_report exn_json ~conf_dir ~top_logger coda_ref =
  (* TEMP MAKE REPORT TRACE *)
  [%log' trace top_logger] "make_report: enter" ;
  ignore (remove_prev_crash_reports ~conf_dir : int) ;
  let crash_time = Time.to_filename_string ~zone:Time.Zone.utc (Time.now ()) in
  let temp_config = conf_dir ^/ "coda_crash_report_" ^ crash_time in
  let () = Core.Unix.mkdir temp_config in
  (*Transition frontier and ledger visualization*)
  log_shutdown ~conf_dir:temp_config ~top_logger coda_ref ;
  let report_file = temp_config ^ ".tar.gz" in
  (*Coda status*)
  let status_file = temp_config ^/ "coda_status.json" in
  let%map status = coda_status !coda_ref in
  Yojson.Safe.to_file status_file status ;
  (* TEMP MAKE REPORT TRACE *)
  [%log' trace top_logger] "make_report: acquired and wrote status" ;
  (*coda logs*)
  let coda_log = conf_dir ^/ "mina.log" in
  let () =
    match Core.Sys.file_exists coda_log with
    | `Yes ->
        let coda_short_log = temp_config ^/ "coda_short.log" in
        (*get the last 4MB of the log*)
        let log_size = 4 * 1024 * 1024 |> Int64.of_int in
        let log =
          In_channel.with_file coda_log ~f:(fun in_chan ->
              let len = In_channel.length in_chan in
              In_channel.seek in_chan
                Int64.(max 0L (Int64.( + ) len (Int64.neg log_size))) ;
              In_channel.input_all in_chan )
        in
        Out_channel.write_all coda_short_log ~data:log
    | _ ->
        ()
  in
  (*System info/crash summary*)
  let summary = summary exn_json in
  Yojson.Safe.to_file (temp_config ^/ "crash_summary.json") summary ;
  (*copy daemon_json to the temp dir *)
  let daemon_config = conf_dir ^/ "daemon.json" in
  let eq = [%equal: [ `Yes | `Unknown | `No ]] in
  let () =
    if eq (Core.Sys.file_exists daemon_config) `Yes then
      ignore
        ( Core.Sys.command
            (sprintf "cp %s %s" daemon_config (temp_config ^/ "daemon.json"))
          : int )
  in
  (*Zip them all up*)
  let tmp_files =
    [ "coda_short.log"
    ; "registered_mask.dot"
    ; "frontier.dot"
    ; "coda_status.json"
    ; "crash_summary.json"
    ; "daemon.json"
    ]
    |> List.filter ~f:(fun f ->
           eq (Core.Sys.file_exists (temp_config ^/ f)) `Yes )
  in
  let files = tmp_files |> String.concat ~sep:" " in
  let tar_command =
    sprintf "tar  -C %s -czf %s %s" temp_config report_file files
  in
  let exit = Core.Sys.command tar_command in
  if exit = 2 then (
    [%log' fatal top_logger] "Error making the crash report. Exit code: %d" exit ;
    None )
  else Some (report_file, temp_config)

(* TODO: handle participation_status more appropriately than doing participate_exn *)
let setup_local_server ?(client_trustlist = []) ?rest_server_port
    ?limited_graphql_port ?itn_graphql_port ?auth_keys
    ?(open_limited_graphql_port = false) ?(insecure_rest_server = false) mina =
  let compile_config = (Mina_lib.config mina).compile_config in
  let itn_features = (Mina_lib.config mina).itn_features in
  let client_trustlist =
    ref
      (Unix.Cidr.Set.of_list
         ( Unix.Cidr.create ~base_address:Unix.Inet_addr.localhost ~bits:8
         :: client_trustlist ) )
  in
  (* Setup RPC server for client interactions *)
  let implement rpc f =
    Rpc.Rpc.implement rpc (fun () input ->
        O1trace.thread ("serve_" ^ Rpc.Rpc.name rpc) (fun () -> f () input) )
  in
  let implement_notrace = Rpc.Rpc.implement in
  let logger =
    Logger.extend
      (Mina_lib.top_level_logger mina)
      [ ("mina_run", `String "Setting up server logs") ]
  in
  let client_impls =
    [ implement Daemon_rpcs.Send_user_commands.rpc (fun () ts ->
          Deferred.map
            ( Mina_commands.setup_and_submit_user_commands mina ts
            |> Participating_state.to_deferred_or_error )
            ~f:Or_error.join )
    ; implement Daemon_rpcs.Send_zkapp_commands.rpc (fun () zkapps ->
          Deferred.map
            ( Mina_commands.setup_and_submit_zkapp_commands mina zkapps
            |> Participating_state.to_deferred_or_error )
            ~f:Or_error.join )
    ; implement Daemon_rpcs.Get_balance.rpc (fun () aid ->
          return
            ( Mina_commands.get_balance mina aid
            |> Participating_state.active_error ) )
    ; implement Daemon_rpcs.Get_trust_status.rpc (fun () ip_address ->
          return (Mina_commands.get_trust_status mina ip_address) )
    ; implement Daemon_rpcs.Get_trust_status_all.rpc (fun () () ->
          return (Mina_commands.get_trust_status_all mina) )
    ; implement Daemon_rpcs.Reset_trust_status.rpc (fun () ip_address ->
          return (Mina_commands.reset_trust_status mina ip_address) )
    ; implement Daemon_rpcs.Chain_id_inputs.rpc (fun () () ->
          return (Mina_commands.chain_id_inputs mina) )
    ; implement Daemon_rpcs.Verify_proof.rpc (fun () (aid, tx, proof) ->
          return
            ( Mina_commands.verify_payment mina aid tx proof
            |> Participating_state.active_error |> Or_error.join ) )
    ; implement Daemon_rpcs.Get_public_keys_with_details.rpc (fun () () ->
          let%map keys = Mina_commands.get_keys_with_details mina in
          Participating_state.active_error keys )
    ; implement Daemon_rpcs.Get_public_keys.rpc (fun () () ->
          let%map keys = Mina_commands.get_public_keys mina in
          Participating_state.active_error keys )
    ; implement Daemon_rpcs.Get_nonce.rpc (fun () aid ->
          return
            ( Mina_commands.get_nonce mina aid
            |> Participating_state.active_error ) )
    ; implement Daemon_rpcs.Get_inferred_nonce.rpc (fun () aid ->
          return
            ( Mina_lib.get_inferred_nonce_from_transaction_pool_and_ledger mina
                aid
            |> Participating_state.active_error ) )
    ; implement_notrace Daemon_rpcs.Get_status.rpc (fun () flag ->
          Mina_commands.get_status ~flag mina )
    ; implement Daemon_rpcs.Clear_hist_status.rpc (fun () flag ->
          Mina_commands.clear_hist_status ~flag mina )
    ; implement Daemon_rpcs.Get_ledger.rpc (fun () lh ->
          Mina_lib.get_ledger mina lh )
    ; implement Daemon_rpcs.Get_snarked_ledger.rpc (fun () lh ->
          Mina_lib.get_snarked_ledger mina lh )
    ; implement Daemon_rpcs.Get_staking_ledger.rpc (fun () which ->
          let ledger_or_error =
            match which with
            | Next ->
                Option.value_map (Mina_lib.next_epoch_ledger mina)
                  ~default:
                    (Or_error.error_string "next staking ledger not available")
                  ~f:(function
                  | `Finalized ledger ->
                      Ok ledger
                  | `Notfinalized ->
                      Or_error.error_string
                        "next staking ledger is not finalized yet" )
            | Current ->
                Option.value_map
                  (Mina_lib.staking_ledger mina)
                  ~default:
                    (Or_error.error_string
                       "current staking ledger not available" )
                  ~f:Or_error.return
          in
          match ledger_or_error with
          | Ok ledger -> (
              match ledger with
              | Genesis_epoch_ledger l ->
                  let%map accts = Mina_ledger.Ledger.to_list l in
                  Ok accts
              | Ledger_db db ->
                  let%map accts = Mina_ledger.Ledger.Db.to_list db in
                  Ok accts )
          | Error err ->
              return (Error err) )
    ; implement Daemon_rpcs.Stop_daemon.rpc (fun () () ->
          Scheduler.yield () >>= (fun () -> exit 0) |> don't_wait_for ;
          Deferred.unit )
    ; implement Daemon_rpcs.Snark_job_list.rpc (fun () () ->
          return (snark_job_list_json mina |> Participating_state.active_error) )
    ; implement Daemon_rpcs.Snark_pool_list.rpc (fun () () ->
          return (snark_pool_list mina) )
    ; implement Daemon_rpcs.Start_tracing.rpc (fun () () ->
          let open Mina_lib.Config in
          Mina_tracing.start (Mina_lib.config mina).conf_dir )
    ; implement Daemon_rpcs.Stop_tracing.rpc (fun () () ->
          Mina_tracing.stop () ; Deferred.unit )
    ; implement Daemon_rpcs.Start_internal_tracing.rpc (fun () () ->
          Internal_tracing.toggle ~commit_id:Mina_version.commit_id ~logger
            `Enabled )
    ; implement Daemon_rpcs.Stop_internal_tracing.rpc (fun () () ->
          Internal_tracing.toggle ~commit_id:Mina_version.commit_id ~logger
            `Disabled )
    ; implement Daemon_rpcs.Visualization.Frontier.rpc (fun () filename ->
          return (Mina_lib.visualize_frontier ~filename mina) )
    ; implement Daemon_rpcs.Visualization.Registered_masks.rpc
        (fun () filename ->
          return (Mina_ledger.Ledger.Debug.visualize ~filename) )
    ; implement Daemon_rpcs.Add_trustlist.rpc (fun () cidr ->
          return
            (let cidr_str = Unix.Cidr.to_string cidr in
             if Unix.Cidr.Set.mem !client_trustlist cidr then
               Or_error.errorf "%s already present in trustlist" cidr_str
             else (
               client_trustlist := Unix.Cidr.Set.add !client_trustlist cidr ;
               Ok () ) ) )
    ; implement Daemon_rpcs.Remove_trustlist.rpc (fun () cidr ->
          return
            (let cidr_str = Unix.Cidr.to_string cidr in
             if not @@ Unix.Cidr.Set.mem !client_trustlist cidr then
               Or_error.errorf "%s not present in trustlist" cidr_str
             else (
               client_trustlist := Unix.Cidr.Set.remove !client_trustlist cidr ;
               Ok () ) ) )
    ; implement Daemon_rpcs.Get_trustlist.rpc (fun () () ->
          return (Set.to_list !client_trustlist) )
    ; implement Daemon_rpcs.Get_node_status.rpc (fun () peers ->
          Mina_networking.get_node_status_from_peers (Mina_lib.net mina) peers )
    ; implement Daemon_rpcs.Get_object_lifetime_statistics.rpc (fun () () ->
          return
            (Yojson.Safe.pretty_to_string @@ Allocation_functor.Table.dump ()) )
    ; implement Daemon_rpcs.Submit_internal_log.rpc
        (fun () { timestamp; message; metadata; process } ->
          let metadata =
            List.map metadata ~f:(fun (s, value) ->
                (s, Yojson.Safe.from_string value) )
          in
          return @@ Itn_logger.log ~process ~timestamp ~message ~metadata () )
    ]
  in
  let log_snark_work_metrics
      (work : Snark_work_lib.Selector.Result.Stable.Latest.t) =
    Mina_metrics.(Counter.inc_one Snark_work.completed_snark_work_received_rpc) ;
    One_or_two.iter
      (One_or_two.zip_exn work.metrics
         (Snark_work_lib.Selector.Result.Stable.Latest.transactions work) )
      ~f:(fun ((total, tag), transaction_opt) ->
        ( match tag with
        | `Merge ->
            Perf_histograms.add_span ~name:"snark_worker_merge_time" total ;
            Mina_metrics.(
              Cryptography.Snark_work_histogram.observe
                Cryptography.snark_work_merge_time_sec (Time.Span.to_sec total))
        | `Transition -> (
            (*should be Some in the case of `Transition*)
            match Option.value_exn transaction_opt with
            | Mina_transaction.Transaction.Command
                (Mina_base.User_command.Zkapp_command parties) ->
                let init =
                  match
                    (Mina_base.Account_update.of_fee_payer parties.fee_payer)
                      .authorization
                  with
                  | Proof _ ->
                      (1, 1)
                  | _ ->
                      (1, 0)
                in
                let parties_count, proof_parties_count =
                  Mina_base.Zkapp_command.Call_forest.fold
                    parties.account_updates ~init
                    ~f:(fun (count, proof_parties_count) party ->
                      ( count + 1
                      , if
                          Mina_base.Control.(
                            Tag.equal Proof
                              (tag
                                 (Mina_base.Account_update.Poly.authorization
                                    party ) ))
                        then proof_parties_count + 1
                        else proof_parties_count ) )
                in
                Mina_metrics.(
                  Cryptography.(
                    Counter.inc snark_work_zkapp_base_time_sec
                      (Time.Span.to_sec total) ;
                    Counter.inc_one snark_work_zkapp_base_submissions ;
                    Counter.inc zkapp_transaction_length
                      (Float.of_int parties_count) ;
                    Counter.inc zkapp_proof_updates
                      (Float.of_int proof_parties_count)))
            | _ ->
                Mina_metrics.(
                  Cryptography.(
                    Counter.inc_one snark_work_base_submissions ;
                    Counter.inc snark_work_base_time_sec
                      (Time.Span.to_sec total))) ) ) ;
        Perf_histograms.add_span ~name:"snark_worker_transition_time" total )
  in
  let snark_worker_impls =
    [ implement Snark_worker.Rpcs_versioned.Get_work.Latest.rpc (fun () () ->
          Deferred.return
            (let open Option.Let_syntax in
            let%bind key =
              Option.merge
                (Mina_lib.snark_worker_key mina)
                (Mina_lib.snark_coordinator_key mina)
                ~f:Fn.const
            in
            let%map work = Mina_lib.request_work mina in
            let work =
              Snark_work_lib.Work.Spec.map work
                ~f:
                  (Snark_work_lib.Work.Single.Spec.map
                     ~f_proof:Ledger_proof.Cached.read_proof_from_disk
                     ~f_witness:Transaction_witness.read_all_proofs_from_disk )
            in
            [%log trace]
              ~metadata:
                [ ( "work_spec"
                  , Snark_work_lib.Selector.Spec.Stable.Latest.to_yojson work )
                ]
              "responding to a Get_work request with some new work" ;
            Mina_metrics.(Counter.inc_one Snark_work.snark_work_assigned_rpc) ;
            (work, key)) )
    ; implement Snark_worker.Rpcs_versioned.Submit_work.Latest.rpc
        (fun () (work : Snark_work_lib.Selector.Result.Stable.Latest.t) ->
          [%log trace] "received completed work from a snark worker"
            ~metadata:
              [ ( "work_spec"
                , Snark_work_lib.Selector.Spec.Stable.Latest.to_yojson work.spec
                )
              ] ;
          log_snark_work_metrics work ;
          Deferred.return @@ Mina_lib.add_work mina work )
    ; implement Snark_worker.Rpcs_versioned.Failed_to_generate_snark.Latest.rpc
        (fun
          ()
          ((error, _work_spec, _prover_public_key) :
            Error.t
            * Snark_work_lib.Selector.Spec.Stable.Latest.t
            * Signature_lib.Public_key.Compressed.t )
        ->
          [%str_log error]
            (Snark_worker.Events.Generating_snark_work_failed
               { error = Error_json.error_to_yojson error } ) ;
          Mina_metrics.(Counter.inc_one Snark_work.snark_work_failed_rpc) ;
          Deferred.unit )
    ]
  in
  let create_graphql_server_with_auth ~mk_context ?auth_keys ~bind_to_address
      ~schema ~server_description ~require_auth port =
    if require_auth && Option.is_none auth_keys then
      failwith
        "Could not create GraphQL server, authentication is required, but no \
         authentication keys were provided" ;
    let auth_keys =
      Option.map auth_keys ~f:(fun s ->
          let pk_strs = String.split_on_chars ~on:[ ',' ] s in
          List.map pk_strs ~f:(fun pk_str ->
              match Itn_crypto.pubkey_of_base64 pk_str with
              | Ok pk ->
                  pk
              | Error _ ->
                  failwithf "Could not decode %s to an Ed25519 public key"
                    pk_str () ) )
    in
    let graphql_callback =
      Graphql_cohttp_async.make_callback ?auth_keys mk_context schema
    in
    Cohttp_async.(
      Server.create_expert
        ~on_handler_error:
          (`Call
            (fun _net exn ->
              [%log error]
                "Exception while handling REST server request: $error"
                ~metadata:
                  [ ("error", `String (Exn.to_string_mach exn))
                  ; ("context", `String "rest_server")
                  ] ) )
        (Tcp.Where_to_listen.bind_to bind_to_address (On_port port))
        (fun ~body _sock req ->
          let uri = Cohttp.Request.uri req in
          let status flag =
            let%bind status = Mina_commands.get_status ~flag mina in
            Server.respond_string
              ( status |> Daemon_rpcs.Types.Status.to_yojson
              |> Yojson.Safe.pretty_to_string )
          in
          let lift x = `Response x in
          match Uri.path uri with
          | "/" ->
              let body =
                "This page is intentionally left blank. The graphql endpoint \
                 can be found at `/graphql`."
              in
              Server.respond_string ~status:`OK body >>| lift
          | "/graphql" ->
              [%log debug] "Received graphql request. Uri: $uri"
                ~metadata:
                  [ ("uri", `String (Uri.to_string uri))
                  ; ("context", `String "rest_server")
                  ] ;
              graphql_callback () req body
          | "/status" ->
              status `None >>| lift
          | "/status/performance" ->
              status `Performance >>| lift
          | _ ->
              Server.respond_string ~status:`Not_found "Route not found"
              >>| lift ))
    |> Deferred.map ~f:(fun _ ->
           [%log info]
             !"Created %s at: http://localhost:%i/graphql"
             server_description port )
  in
  let create_graphql_server =
    create_graphql_server_with_auth
      ~mk_context:(fun ~with_seq_no:_ _req -> mina)
      ?auth_keys:None
  in
  Option.iter rest_server_port ~f:(fun rest_server_port ->
      O1trace.background_thread "serve_graphql" (fun () ->
          create_graphql_server
            ~bind_to_address:
              Tcp.Bind_to_address.(
                if insecure_rest_server then All_addresses else Localhost)
            ~schema:Mina_graphql.schema ~server_description:"GraphQL server"
            ~require_auth:false rest_server_port ) ) ;
  (* Second graphql server with limited queries exposed *)
  Option.iter limited_graphql_port ~f:(fun rest_server_port ->
      O1trace.background_thread "serve_limited_graphql" (fun () ->
          create_graphql_server
            ~bind_to_address:
              Tcp.Bind_to_address.(
                if open_limited_graphql_port then All_addresses else Localhost)
            ~schema:Mina_graphql.schema_limited
            ~server_description:"GraphQL server with limited queries"
            ~require_auth:false rest_server_port ) ) ;
  if itn_features then
    (* Third graphql server with ITN-particular queries exposed *)
    Option.iter itn_graphql_port ~f:(fun rest_server_port ->
        O1trace.background_thread "serve_itn_graphql" (fun () ->
            create_graphql_server_with_auth
              ~mk_context:(fun ~with_seq_no _req -> (with_seq_no, mina))
              ?auth_keys
              ~bind_to_address:
                Tcp.Bind_to_address.(
                  if insecure_rest_server then All_addresses else Localhost)
              ~schema:Mina_graphql.schema_itn
              ~server_description:"GraphQL server for ITN queries"
              ~require_auth:true rest_server_port ) ) ;
  let where_to_listen =
    Tcp.Where_to_listen.bind_to All_addresses
      (On_port (Mina_lib.client_port mina))
  in
  O1trace.background_thread "serve_client_rpcs" (fun () ->
      Deferred.ignore_m
        (Tcp.Server.create
           ~on_handler_error:
             (`Call
               (fun _net exn ->
                 [%log error]
                   "Exception while handling TCP server request: $error"
                   ~metadata:
                     [ ("error", `String (Exn.to_string_mach exn))
                     ; ("context", `String "rpc_tcp_server")
                     ] ) )
           where_to_listen
           (fun address reader writer ->
             let address = Socket.Address.Inet.addr address in
             if
               not
                 (Set.exists !client_trustlist ~f:(fun cidr ->
                      Unix.Cidr.does_match cidr address ) )
             then (
               [%log error]
                 !"Rejecting client connection from $address, it is not \
                   present in the trustlist."
                 ~metadata:
                   [ ("$address", `String (Unix.Inet_addr.to_string address)) ] ;
               Deferred.unit )
             else
               Rpc.Connection.server_with_close
                 ~handshake_timeout:compile_config.rpc_handshake_timeout
                 ~heartbeat_config:
                   (Rpc.Connection.Heartbeat_config.create
                      ~timeout:
                        (Time_ns.Span.of_sec
                           (Time.Span.to_sec
                              compile_config.rpc_heartbeat_timeout ) )
                      ~send_every:
                        (Time_ns.Span.of_sec
                           (Time.Span.to_sec
                              compile_config.rpc_heartbeat_send_every ) )
                      () )
                 reader writer
                 ~implementations:
                   (Rpc.Implementations.create_exn
                      ~implementations:(client_impls @ snark_worker_impls)
                      ~on_unknown_rpc:`Raise )
                 ~connection_state:(fun _ -> ())
                 ~on_handshake_error:
                   (`Call
                     (fun exn ->
                       [%log warn]
                         "Handshake error while handling RPC server request \
                          from $address"
                         ~metadata:
                           [ ("error", `String (Exn.to_string_mach exn))
                           ; ("context", `String "rpc_server")
                           ; ( "address"
                             , `String (Unix.Inet_addr.to_string address) )
                           ] ;
                       Deferred.unit ) ) ) ) )

let coda_crash_message ~log_issue ~action ~error =
  let followup =
    if log_issue then
      sprintf
        !{err| The Mina Protocol developers would like to know why!

    Please:
      Open an issue:
        <https://github.com/MinaProtocol/mina/issues/new>

      Briefly describe what you were doing and %s

    %!|err}
        action
    else action
  in
  sprintf !{err|

  ☠  Mina Daemon %s.
  %s
%!|err} error followup

let no_report exn_json status =
  sprintf
    "include the last 20 lines from .mina-config/mina.log and then paste the \
     following:\n\
     Summary:\n\
     %s\n\
     Status:\n\
     %s\n"
    (Yojson.Safe.to_string status)
    (Yojson.Safe.to_string (summary exn_json))

let handle_crash e ~time_controller ~conf_dir ~child_pids ~top_logger coda_ref =
  (* attempt to free up some memory before handling crash *)
  (* this circumvents using Child_processes.kill, and instead sends SIGKILL to all children *)
  Hashtbl.keys child_pids
  |> List.iter ~f:(fun pid ->
         ignore (Signal.send Signal.kill (`Pid pid) : [ `No_such_process | `Ok ]) ) ;
  let exn_json = Error_json.error_to_yojson (Error.of_exn ~backtrace:`Get e) in
  [%log' fatal top_logger]
    "Unhandled top-level exception: $exn\nGenerating crash report"
    ~metadata:[ ("exn", exn_json) ] ;
  let%bind status = coda_status !coda_ref in
  (* TEMP MAKE REPORT TRACE *)
  [%log' trace top_logger] "handle_crash: acquired coda status" ;
  let%map action_string =
    match%map
      Block_time.Timeout.await
        ~timeout_duration:(Block_time.Span.of_ms 30_000L)
        time_controller
        ( try
            make_report exn_json ~conf_dir coda_ref ~top_logger
            >>| fun k -> Ok k
          with exn -> return (Error (Error.of_exn exn)) )
    with
    | `Ok (Ok (Some (report_file, temp_config))) ->
        ( try ignore (Core.Sys.command (sprintf "rm -rf %s" temp_config) : int)
          with _ -> () ) ;
        sprintf "attach the crash report %s" report_file
    | `Ok (Ok None) ->
        (*TODO: tar failed, should we ask people to zip the temp directory themselves?*)
        no_report exn_json status
    | `Ok (Error e) ->
        [%log' fatal top_logger] "Exception when generating crash report: $exn"
          ~metadata:[ ("exn", Error_json.error_to_yojson e) ] ;
        no_report exn_json status
    | `Timeout ->
        [%log' fatal top_logger] "Timed out while generated crash report" ;
        no_report exn_json status
  in
  let message =
    coda_crash_message ~error:"crashed" ~action:action_string ~log_issue:true
  in
  Core.print_string message

let handle_shutdown ~monitor ~time_controller ~conf_dir ~child_pids ~top_logger
    coda_ref =
  Monitor.detach_and_iter_errors monitor ~f:(fun exn ->
      don't_wait_for
        (let%bind () =
           match Monitor.extract_exn exn with
           | Mina_networking.No_initial_peers ->
               let message =
                 coda_crash_message
                   ~error:"failed to connect to any initial peers"
                   ~action:
                     "You might be trying to connect to a different network \
                      version, or need to troubleshoot your configuration. See \
                      https://codaprotocol.com/docs/troubleshooting/ for \
                      details."
                   ~log_issue:false
               in
               Core.print_string message ; Deferred.unit
           | Genesis_ledger_helper.Genesis_state_initialization_error ->
               let message =
                 coda_crash_message
                   ~error:"failed to initialize the genesis state"
                   ~action:
                     "include the last 50 lines from .mina-config/mina.log"
                   ~log_issue:true
               in
               Core.print_string message ; Deferred.unit
           | Mina_user_error.Mina_user_error { message; where } ->
               Core.print_string "\nFATAL ERROR" ;
               let error =
                 match where with
                 | None ->
                     "encountered a configuration error"
                 | Some where ->
                     sprintf "encountered a configuration error %s" where
               in
               let message =
                 coda_crash_message ~error ~action:("\n" ^ message)
                   ~log_issue:false
               in
               Core.print_string message ; Deferred.unit
           | Mina_lib.Offline_shutdown ->
               Core.print_string
                 "\n\
                  [FATAL] *** Mina daemon has been offline for too long ***\n\
                  *** Shutting down ***\n" ;
               handle_crash Mina_lib.Offline_shutdown ~time_controller ~conf_dir
                 ~child_pids ~top_logger coda_ref
           | Mina_lib.Bootstrap_stuck_shutdown ->
               Core.print_string
                 "\n\
                  [FATAL] *** Mina daemon has been stuck in bootstrap for too \
                  long ***\n\
                  *** Shutting down ***\n" ;
               handle_crash Mina_lib.Bootstrap_stuck_shutdown ~time_controller
                 ~conf_dir ~child_pids ~top_logger coda_ref
           | _exn ->
               let error = Error.of_exn ~backtrace:`Get exn in
               let%bind () =
                 Node_error_service.send_report
                   ~commit_id:Mina_version.commit_id ~logger:top_logger ~error
               in
               handle_crash exn ~time_controller ~conf_dir ~child_pids
                 ~top_logger coda_ref
         in
         Stdlib.exit 1 ) ) ;
  Async_unix.Signal.(
    handle terminating ~f:(fun signal ->
        log_shutdown ~conf_dir ~top_logger coda_ref ;
        let logger =
          Logger.extend top_logger
            [ ("coda_run", `String "Program was killed by signal") ]
        in
        [%log info]
          !"Mina process was interrupted by $signal"
          ~metadata:[ ("signal", `String (to_string signal)) ] ;
        (* causes async shutdown and at_exit handlers to run *)
        Async.shutdown 130 ))
