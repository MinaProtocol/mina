open Core
open Async
open Mina_automation
open Signature_lib

let assert_file_exists ~path ~error_msg =
  let%map.Deferred exists = Sys.file_exists path in
  match exists with
  | `Yes ->
      Ok ()
  | `No | `Unknown ->
      Error (Error.of_string error_msg)

let of_option opt ~error =
  Result.of_option opt ~error:(Error.of_string error) |> Deferred.return

let get_prefork_commit_hash ~docker_image =
  let%map output =
    Process.run_exn ~prog:"docker"
      ~args:
        [ "run"; "--rm"; docker_image; "/runtimes/berkeley/mina"; "version" ]
      ()
  in
  (* Output is "Commit <full_hash>\nRest..." — extract first 8 chars of hash *)
  let lines = String.split_lines output in
  let commit_line =
    List.find_exn lines ~f:(fun line ->
        String.is_prefix line ~prefix:"Commit " )
  in
  let full_hash =
    String.chop_prefix_exn commit_line ~prefix:"Commit " |> String.strip
  in
  String.prefix full_hash 8

let validate_generated_config ~slot_chain_end ~hard_fork_genesis_slot_delta
    ~block_window_duration_ms ~conf_dir ~old_genesis_timestamp =
  let open Deferred.Or_error.Let_syntax in
  let auto_fork_dir = conf_dir ^/ "auto-fork-mesa-devnet" in
  let daemon_json = auto_fork_dir ^/ "daemon.json" in
  let activated = auto_fork_dir ^/ "activated" in
  let%bind () =
    assert_file_exists ~path:daemon_json
      ~error_msg:"daemon.json was not generated"
  in
  let%bind () =
    assert_file_exists ~path:activated
      ~error_msg:"activated file was not created"
  in
  let expected_fork_slot = slot_chain_end + hard_fork_genesis_slot_delta in
  let%bind daemon_config =
    Yojson.Safe.from_file daemon_json
    |> Runtime_config.of_yojson
    |> Result.map_error ~f:Error.of_string
    |> Deferred.return
  in
  let%bind proof =
    of_option daemon_config.proof ~error:"Generated config missing proof field"
  in
  let%bind fork =
    of_option proof.fork ~error:"Generated config missing proof.fork field"
  in
  let fork_slot = fork.global_slot_since_genesis in
  let%bind () =
    if fork_slot <> expected_fork_slot then
      Deferred.Or_error.error_string
        (sprintf "proof.fork.global_slot_since_genesis is %d, expected %d"
           fork_slot expected_fork_slot )
    else Deferred.Or_error.return ()
  in
  let%bind new_genesis =
    of_option daemon_config.genesis
      ~error:"Generated config missing genesis field"
  in
  let%bind new_genesis_timestamp =
    of_option new_genesis.genesis_state_timestamp
      ~error:"Generated config missing genesis_state_timestamp"
  in
  let old_time = Time.of_string old_genesis_timestamp in
  let new_time = Time.of_string new_genesis_timestamp in
  let expected_offset_ms =
    Int64.( * )
      (Int64.of_int expected_fork_slot)
      (Int64.of_int block_window_duration_ms)
  in
  let actual_offset_ms =
    Time.diff new_time old_time |> Time.Span.to_ms |> Int64.of_float
  in
  if Int64.( <> ) actual_offset_ms expected_offset_ms then
    Deferred.Or_error.error_string
      (sprintf
         "Genesis timestamp offset is %Ld ms, expected %Ld ms (fork_slot=%d * \
          block_window_duration=%d ms)"
         actual_offset_ms expected_offset_ms expected_fork_slot
         block_window_duration_ms )
  else Deferred.Or_error.return ()

let generate_hardfork_config ~slot_tx_end ~slot_chain_end
    ~hard_fork_genesis_slot_delta ~block_window_duration_ms ~proof_level
    ~genesis_config_path ~daemon_json_path daemon =
  let client = Daemon.client daemon in
  let%map ledger_content = Daemon.Client.test_ledger client ~n:10 in
  let all_accounts =
    Yojson.Safe.from_string ledger_content
    |> Runtime_config.Accounts.of_yojson |> Result.ok_or_failwith
  in
  let block_producer_account, other_accounts =
    match all_accounts with
    | first :: rest ->
        let block_producer_balance =
          Currency.Balance.of_mina_int_exn 10000000
        in
        ({ first with balance = block_producer_balance }, rest)
    | [] ->
        failwith "No accounts generated"
  in
  let block_producer_kp =
    let pk_compressed =
      Public_key.Compressed.of_base58_check_exn block_producer_account.pk
    in
    let public_key =
      Public_key.decompress pk_compressed
      |> Option.value_exn
           ~message:"Failed to decompress block producer public key"
    in
    let private_key =
      block_producer_account.sk
      |> Option.value_exn ~message:"Block producer account missing private key"
      |> Private_key.of_base58_check_exn
    in
    { Keypair.public_key; private_key }
  in
  let accounts = block_producer_account :: other_accounts in
  let ledger : Runtime_config.Ledger.t =
    { base = Accounts accounts
    ; num_accounts = None
    ; balances = []
    ; hash = None
    ; s3_data_hash = None
    ; name = None
    ; add_genesis_winner = Some true
    }
  in
  let daemon_cfg : Runtime_config.Daemon.t =
    { txpool_max_size = None
    ; peer_list_url = None
    ; zkapp_proof_update_cost = None
    ; zkapp_signed_single_update_cost = None
    ; zkapp_signed_pair_update_cost = None
    ; zkapp_transaction_cost_limit = None
    ; max_event_elements = None
    ; max_action_elements = None
    ; zkapp_cmd_limit_hardcap = None
    ; slot_tx_end = Some slot_tx_end
    ; slot_chain_end = Some slot_chain_end
    ; hard_fork_genesis_slot_delta = Some hard_fork_genesis_slot_delta
    ; minimum_user_command_fee = None
    ; network_id = None
    ; sync_ledger_max_subtree_depth = None
    ; sync_ledger_default_subtree_depth = None
    }
  in
  let proof =
    Runtime_config.Proof_keys.make ?level:proof_level ~block_window_duration_ms
      ()
  in
  let now_unix_ts = Unix.time () |> Float.to_int in
  let delay_minutes = 2 in
  let genesis_unix_ts =
    now_unix_ts - (now_unix_ts mod 60) + (delay_minutes * 60)
  in
  let genesis_timestamp =
    Time.of_span_since_epoch (Time.Span.of_int_sec genesis_unix_ts)
    |> Time.to_string_iso8601_basic ~zone:Time.Zone.utc
  in
  let genesis : Runtime_config.Genesis.t =
    { k = None
    ; delta = None
    ; slots_per_epoch = None
    ; slots_per_sub_window = None
    ; grace_period_slots = None
    ; genesis_state_timestamp = Some genesis_timestamp
    }
  in
  (* Genesis info config: genesis, ledger, daemon — installed at /var/lib/coda/ *)
  let genesis_config =
    Runtime_config.make ~ledger ~daemon:daemon_cfg ~genesis ()
  in
  Runtime_config.to_yojson genesis_config
  |> Yojson.Safe.to_file genesis_config_path ;
  (* Proof config: proof settings — goes in config_dir/daemon.json *)
  let proof_config = Runtime_config.make ~proof () in
  Runtime_config.to_yojson proof_config |> Yojson.Safe.to_file daemon_json_path ;
  (block_producer_kp, genesis_timestamp)

let graphql_uri ~rest_port =
  Uri.of_string (sprintf "http://localhost:%d/graphql" rest_port)

let query_sync_status ~rest_port =
  let uri = graphql_uri ~rest_port in
  match%map
    Graphql_lib.Client.query
      Graphql_queries.Sync_status.(make @@ makeVariables ())
      uri
  with
  | Ok response ->
      let status_str =
        match response.syncStatus with
        | `BOOTSTRAP ->
            "BOOTSTRAP"
        | `CATCHUP ->
            "CATCHUP"
        | `CONNECTING ->
            "CONNECTING"
        | `LISTENING ->
            "LISTENING"
        | `OFFLINE ->
            "OFFLINE"
        | `SYNCED ->
            "SYNCED"
      in
      Ok status_str
  | Error e ->
      Error (Graphql_lib.Client.Connection_error.to_error e)

let query_genesis_timestamp ~rest_port =
  let uri = graphql_uri ~rest_port in
  match%map
    Graphql_lib.Client.query
      Graphql_queries.Genesis_constants.(make @@ makeVariables ())
      uri
  with
  | Ok response ->
      Ok response.genesisConstants.genesisTimestamp
  | Error e ->
      Error (Graphql_lib.Client.Connection_error.to_error e)

let check_process_alive (process : Daemon.Process.t) =
  match Deferred.peek (Process.wait process.process) with
  | None ->
      Deferred.Or_error.ok_unit
  | Some (Ok ()) ->
      Deferred.Or_error.error_string
        "Daemon process exited unexpectedly (exit code 0)"
  | Some (Error (`Exit_non_zero code)) ->
      Deferred.Or_error.error_string
        (sprintf "Daemon process exited with code %d" code)
  | Some (Error (`Signal signal)) ->
      Deferred.Or_error.error_string
        (sprintf "Daemon process killed by signal %s"
           (Core.Signal.to_string signal) )

let poll_for_sync ~logger ~rest_port ~process ?(initial_delay = 5.)
    ?(retry_delay = 30.) ?(retry_attempts = 40) () =
  [%log info] "Waiting initial $delay s. before connecting via GraphQL"
    ~metadata:[ ("delay", `Int (int_of_float initial_delay)) ] ;
  let%bind () = after (Time.Span.of_sec initial_delay) in
  let rec go retries_remaining =
    let%bind.Deferred.Or_error () = check_process_alive process in
    match%bind query_sync_status ~rest_port with
    | Ok status when String.equal status "SYNCED" ->
        Deferred.Or_error.ok_unit
    | Ok status ->
        if retries_remaining > 0 then (
          [%log info]
            "Daemon not synced (status: $status).. retrying \
             ($attempt/$max_attempts)"
            ~metadata:
              [ ("status", `String status)
              ; ("attempt", `Int (retry_attempts - retries_remaining))
              ; ("max_attempts", `Int retry_attempts)
              ] ;
          let%bind () = after (Time.Span.of_sec retry_delay) in
          go (retries_remaining - 1) )
        else
          Deferred.Or_error.error_s
            [%message
              "Daemon not synced after max attempts"
                ~attempts:(retry_attempts : int)
                ~(status : string)]
    | Error e ->
        if retries_remaining > 0 then (
          [%log warn]
            "GraphQL query failed: $error.. retrying ($attempt/$max_attempts)"
            ~metadata:
              [ ("error", Error_json.error_to_yojson e)
              ; ("attempt", `Int (retry_attempts - retries_remaining))
              ; ("max_attempts", `Int retry_attempts)
              ] ;
          let%bind () = after (Time.Span.of_sec retry_delay) in
          go (retries_remaining - 1) )
        else
          Deferred.Or_error.error_s
            [%message
              "GraphQL query failed after max attempts"
                ~attempts:(retry_attempts : int)
                ~error:(e : Error.t)]
  in
  go retry_attempts

let start_and_sync_daemon ~logger ~phase ~rest_port ~block_window_duration_ms
    ~block_producer_key ~env docker_daemon =
  [%log info] "$phase: Starting daemon in Docker"
    ~metadata:[ ("phase", `String phase) ] ;
  let%bind process =
    Daemon.start ~hardfork_handling:"migrate-exit" ~block_producer_key ~env
      docker_daemon
  in
  let retry_delay =
    Float.min 30. (Float.of_int block_window_duration_ms /. 1000.)
  in
  let total_time = 1200. in
  let retry_attempts =
    Float.to_int (Float.round_up (total_time /. retry_delay))
  in
  let%bind result =
    poll_for_sync ~logger ~rest_port ~process ~retry_delay ~retry_attempts ()
  in
  match result with
  | Ok () ->
      [%log info] "$phase: Daemon synced" ~metadata:[ ("phase", `String phase) ] ;
      Deferred.return process
  | Error e ->
      [%log error] "$phase: Bootstrap failed: $error"
        ~metadata:
          [ ("phase", `String phase); ("error", Error_json.error_to_yojson e) ] ;
      failwithf "%s: Bootstrap failed" phase ()

let run ~docker_image ~slot_tx_end ~slot_chain_end ~hard_fork_genesis_slot_delta
    ~block_window_duration_ms ~proof_level =
  let open Deferred.Let_syntax in
  let logger = Logger.create () in
  let config = Daemon.Config.default () in
  let%bind () = Daemon.Config.generate_keys config in
  let daemon = Daemon.of_config config in
  let root_path = config.dirs.root_path in
  (* Get the pre-fork binary's commit hash to determine the config filename.
     Write to both 7-char and 8-char filenames because mina_version.runtime
     (Nix builds) uses 7 chars while mina_version.normal uses 8. *)
  let%bind commit_hash = get_prefork_commit_hash ~docker_image in
  let config_name_7 = sprintf "config_%s.json" (String.prefix commit_hash 7) in
  let config_name_8 = sprintf "config_%s.json" (String.prefix commit_hash 8) in
  let config_local_7 = root_path ^/ config_name_7 in
  let config_local_8 = root_path ^/ config_name_8 in
  let daemon_json_path = config.dirs.conf ^/ "daemon.json" in
  let%bind block_producer_kp, old_genesis_timestamp =
    generate_hardfork_config ~slot_tx_end ~slot_chain_end
      ~hard_fork_genesis_slot_delta ~block_window_duration_ms ~proof_level
      ~genesis_config_path:config_local_7 ~daemon_json_path daemon
  in
  (* Copy to the 8-char filename as well *)
  let%bind genesis_contents = Reader.file_contents config_local_7 in
  let%bind () = Writer.save config_local_8 ~contents:genesis_contents in
  let bp_key_path = config.dirs.conf ^/ "bp-key" in
  let password =
    lazy (Deferred.return @@ Bytes.of_string "naughty blue worm")
  in
  let%bind () =
    Secrets.Keypair.write_exn block_producer_kp ~privkey_path:bp_key_path
      ~password
  in
  let ctx =
    Mina_automation.Executor.DockerContext.create ~image:docker_image
      ~volumes:
        [ sprintf "%s:%s" root_path root_path
        ; sprintf "%s:%s" config_local_7
            (sprintf "/var/lib/coda/%s" config_name_7)
        ; sprintf "%s:%s" config_local_8
            (sprintf "/var/lib/coda/%s" config_name_8)
        ]
      ~network:"host" ~rm:true ()
  in
  let docker_daemon =
    { (Daemon.of_config config) with executor = Daemon.Executor.(Docker ctx) }
  in
  let env =
    `Extend
      [ ("MINA_HARDFORK_STATE_DIR", config.dirs.conf)
      ; ("MINA_PRIVKEY_PASS", "naughty blue worm")
      ; ("MINA_LIBP2P_PASS", "naughty blue worm")
      ]
  in
  (* Phase 1: Pre-fork run *)
  let%bind process =
    start_and_sync_daemon ~logger ~phase:"Phase 1" ~rest_port:config.rest_port
      ~block_window_duration_ms ~block_producer_key:bp_key_path ~env
      docker_daemon
  in
  let conf_dir = config.dirs.conf in
  let auto_fork_dir = conf_dir ^/ "auto-fork-mesa-devnet" in
  let activated = auto_fork_dir ^/ "activated" in
  let start_time = Core.Time.now () in
  let timeout = Core.Time.Span.of_min 10. in
  let rec poll_for_activated () =
    let%bind activated_exists = Sys.file_exists activated in
    match activated_exists with
    | `Yes ->
        Deferred.return `Success
    | `No | `Unknown ->
        if
          Core.Time.Span.( > )
            (Core.Time.diff (Core.Time.now ()) start_time)
            timeout
        then Deferred.return `Timeout
        else
          let%bind () = after (Core.Time.Span.of_sec 5.) in
          poll_for_activated ()
  in
  let%bind activated_result = poll_for_activated () in
  match activated_result with
  | `Timeout ->
      failwith "Hardfork config was not generated within timeout"
  | `Success -> (
      [%log info] "Phase 1: Activated file detected" ;
      match%bind
        Async.Clock.with_timeout (Core.Time.Span.of_min 5.)
          (Process.wait process.process)
      with
      | `Timeout ->
          failwith "Daemon did not shut down within 5 minutes"
      | `Result (Error (`Exit_non_zero code)) ->
          failwithf "Phase 1: Daemon exited with code %d" code ()
      | `Result (Error (`Signal signal)) ->
          failwithf "Phase 1: Daemon killed by signal %s"
            (Core.Signal.to_string signal)
            ()
      | `Result (Ok ()) -> (
          [%log info] "Phase 1: Daemon exited cleanly" ;
          match%bind
            validate_generated_config ~slot_chain_end
              ~hard_fork_genesis_slot_delta ~block_window_duration_ms ~conf_dir
              ~old_genesis_timestamp
          with
          | Error err ->
              failwithf "Config validation failed: %s" (Error.to_string_hum err)
                ()
          | Ok () ->
              [%log info] "Phase 1: Config validated" ;
              let%bind process2 =
                start_and_sync_daemon ~logger ~phase:"Phase 2"
                  ~rest_port:config.rest_port ~block_window_duration_ms
                  ~block_producer_key:bp_key_path ~env docker_daemon
              in
              let%bind ts_result =
                query_genesis_timestamp ~rest_port:config.rest_port
              in
              let%bind () =
                match ts_result with
                | Error e ->
                    failwithf "Failed to query genesis timestamp: %s"
                      (Error.to_string_hum e) ()
                | Ok actual_genesis_timestamp ->
                    [%log info] "Phase 2: Actual genesis timestamp: $timestamp"
                      ~metadata:
                        [ ("timestamp", `String actual_genesis_timestamp) ] ;
                    let old_time = Time.of_string old_genesis_timestamp in
                    let expected_fork_slot =
                      slot_chain_end + hard_fork_genesis_slot_delta
                    in
                    let expected_offset_ms =
                      expected_fork_slot * block_window_duration_ms
                    in
                    let expected_new_time =
                      Time.add old_time
                        (Time.Span.of_ms (Float.of_int expected_offset_ms))
                    in
                    let actual_new_time =
                      Time.of_string actual_genesis_timestamp
                    in
                    let diff_ms =
                      Time.diff actual_new_time expected_new_time
                      |> Time.Span.to_ms |> Float.abs
                    in
                    if Float.( < ) diff_ms 1000.0 then (
                      [%log info] "PASSED" ;
                      Deferred.return () )
                    else
                      failwithf
                        "Genesis timestamp mismatch: expected %s, got %s"
                        (Time.to_string_iso8601_basic ~zone:Time.Zone.utc
                           expected_new_time )
                        actual_genesis_timestamp ()
              in
              let%bind _ = Daemon.Process.force_kill process2 in
              Deferred.return () ) )

let () =
  Command.run
    (Command.async
       ~summary:
         "Auto hard fork post-fork restart test: validates that a mina daemon \
          restarts with correct genesis after an automatic hard fork"
       (let%map_open.Command docker_image =
          flag "--docker-image" (required string)
            ~doc:"TAG Docker image tag for hard fork packaging build"
        and slot_tx_end =
          flag "--slot-tx-end"
            (optional_with_default 3 int)
            ~doc:"INT Slot at which transactions end (default: 3)"
        and slot_chain_end =
          flag "--slot-chain-end"
            (optional_with_default 9 int)
            ~doc:"INT Slot at which the chain ends (default: 9)"
        and hard_fork_genesis_slot_delta =
          flag "--hard-fork-genesis-slot-delta"
            (optional_with_default 1 int)
            ~doc:"INT Delta added to slot_chain_end for fork slot (default: 1)"
        and block_window_duration_ms =
          flag "--block-window-duration-ms"
            (optional_with_default 120000 int)
            ~doc:"INT Block window duration in milliseconds (default: 120000)"
        and proof_level =
          flag "--proof-level" (optional string)
            ~doc:"full|check|none Proof level for the config (default: not set)"
        in
        let proof_level =
          Option.map proof_level ~f:(fun s ->
              Runtime_config.Proof_keys.Level.of_string s
              |> Result.ok_or_failwith )
        in
        fun () ->
          run ~docker_image ~slot_tx_end ~slot_chain_end
            ~hard_fork_genesis_slot_delta ~block_window_duration_ms ~proof_level
       ) )
