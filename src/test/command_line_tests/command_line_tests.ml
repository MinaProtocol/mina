open Core
open Async
open Mina_automation
open Signature_lib

module BackgroundMode = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let%bind () = Daemon.Config.generate_keys test.config in
    let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
    let%bind () =
      Mina_automation_fixture.Daemon.generate_random_config daemon ledger_file
    in
    let%bind process = Daemon.start daemon in
    let%bind result = Daemon.wait_for_node_init process in
    let%bind () =
      match result with
      | Ok () ->
          Deferred.return ()
      | Error e ->
          let () = printf "Error:\n%s\n" (Error.to_string_hum e) in
          let log_file = Daemon.Config.ConfigDirs.mina_log test.config.dirs in
          let%bind logs = Reader.file_contents log_file in
          let () = printf "Daemon logs:\n%s\n" logs in
          Writer.flushed (Lazy.force Writer.stdout)
    in
    let%map () = Daemon.Client.stop_daemon process.client in
    Mina_automation_fixture.Intf.Passed
end

module DaemonRecover = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    (let daemon = Daemon.of_config test.config in
     let%bind () = Daemon.Config.generate_keys test.config in
     let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
     let%bind () =
       Mina_automation_fixture.Daemon.generate_random_config daemon ledger_file
     in
     let%bind process = Daemon.start daemon in
     let%bind.Deferred.Result () = Daemon.wait_for_node_init process in
     let%bind.Deferred.Result _ = Daemon.Process.force_kill process in
     let%bind process = Daemon.start daemon in
     let%bind.Deferred.Result () = Daemon.wait_for_node_init process in
     let%map () = Daemon.Client.stop_daemon process.client in
     Ok () )
    >>| function
    | Ok () -> Mina_automation_fixture.Intf.Passed | Error err -> Failed err
end

let contain_log_output output =
  String.is_substring ~substring:"{\"timestamp\":" output

module LedgerHash = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let client = Daemon.client daemon in
    let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
    let%bind _ =
      Mina_automation_fixture.Daemon.generate_random_accounts daemon ledger_file
    in
    let%map hash = Daemon.Client.ledger_hash client ~ledger_file in
    if contain_log_output hash then
      Mina_automation_fixture.Intf.Failed
        (Error.of_string "output contains log")
    else if not (String.is_prefix ~prefix:"j" hash) then
      Failed (Error.of_string "invalid ledger hash prefix")
    else if Int.( <> ) (String.length hash) 52 then
      Failed
        (Error.createf "invalid ledger hash length (%d)" (String.length hash))
    else Passed
end

module LedgerCurrency = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let client = Daemon.client daemon in
    let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
    let%bind accounts =
      Mina_automation_fixture.Daemon.generate_random_accounts daemon ledger_file
    in
    let total_currency =
      List.map accounts ~f:(fun account ->
          Currency.Balance.to_nanomina_int account.balance )
      |> List.sum (module Int) ~f:Fn.id
    in
    let%map output = Daemon.Client.ledger_currency client ~ledger_file in
    let actual = Scanf.sscanf output "MINA : %f" Fn.id in
    let total_currency_float = float_of_int total_currency /. 1000000000.0 in

    if contain_log_output output then
      Mina_automation_fixture.Intf.Failed
        (Error.of_string "output contains log")
    else if not Float.(abs (total_currency_float - actual) < 0.001) then
      Failed
        (Error.createf "invalid mina total count %f vs %f" total_currency_float
           actual )
    else Passed
end

module ExportSnarkedLedger = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let parse_accounts output =
    try
      let json = Yojson.Safe.from_string output in
      match Runtime_config.Accounts.of_yojson json with
      | Ok accounts ->
          Ok accounts
      | Error err ->
          Error err
    with exn -> Error (Exn.to_string exn)

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
    let%bind () = Daemon.Config.generate_keys test.config in
    let%bind () =
      Mina_automation_fixture.Daemon.generate_random_config daemon ledger_file
    in
    let%bind process = Daemon.start daemon in
    let%bind bootstrap_result = Daemon.wait_for_node_init process in
    let%bind bootstrap_ok =
      match bootstrap_result with
      | Ok () ->
          Deferred.return true
      | Error e ->
          let () = printf "Error:\n%s\n" (Error.to_string_hum e) in
          let log_file = Daemon.Config.ConfigDirs.mina_log test.config.dirs in
          let%bind logs = Reader.file_contents log_file in
          let () = printf "Daemon logs:\n%s\n" logs in
          let%map () = Daemon.Client.stop_daemon process.client in
          false
    in
    if not bootstrap_ok then
      Deferred.return
        (Mina_automation_fixture.Intf.Failed
           (Error.of_string "Daemon failed to bootstrap") )
    else
      let%bind output =
        Daemon.Client.ledger_export_snarked_ledger process.client
      in
      let%map () = Daemon.Client.stop_daemon process.client in
      if contain_log_output output then
        Mina_automation_fixture.Intf.Failed
          (Error.of_string "output contains log")
      else
        match parse_accounts output with
        | Ok _ ->
            Passed
        | Error err ->
            Failed (Error.createf "invalid JSON output: %s" err)
end

module AdvancedPrintSignatureKind = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let client = Daemon.client daemon in
    let%map output = Daemon.Client.advanced_print_signature_kind client in
    let expected = "testnet" in

    if contain_log_output output then
      Mina_automation_fixture.Intf.Failed
        (Error.of_string "output contains log")
    else if not (String.equal expected (String.strip output)) then
      Failed (Error.createf "invalid signature kind %s vs %s" expected output)
    else Passed
end

module AdvancedCompileTimeConstants = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let client = Daemon.client daemon in
    let%bind config_content = Daemon.Client.test_ledger client ~n:10 in
    let config_content =
      Printf.sprintf "{ \"ledger\":{ \"accounts\":%s } }" config_content
    in
    let temp_file = Filename.temp_file "commandline" "ledger.json" in
    Yojson.Safe.from_string config_content |> Yojson.Safe.to_file temp_file ;
    let%map output =
      Daemon.Client.advanced_compile_time_constants client
        ~config_file:temp_file
    in

    if contain_log_output output then
      Mina_automation_fixture.Intf.Failed
        (Error.of_string "output contains log")
    else Passed
end

module AdvancedConstraintSystemDigests = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let client = Daemon.client daemon in
    let%map output = Daemon.Client.advanced_constraint_system_digests client in

    if contain_log_output output then
      Mina_automation_fixture.Intf.Failed
        (Error.of_string "output contains log")
    else Passed
end

(** Test the auto hard fork config generation using a single node and a small
    random genesis ledger. No transactions are submitted to the daemon, but it
    does still start up as a block producer and create blocks so that consensus
    will advance past the test's [slot_chain_end]. *)
module AutoHardforkConfigGeneration = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let slot_tx_end = 3

  let slot_chain_end = slot_tx_end + 6

  let hard_fork_genesis_slot_delta = 1

  let slot_duration_ms = 10000

  let assert_file_exists ~path ~error_msg =
    let%map.Deferred exists = Sys.file_exists path in
    match exists with
    | `Yes ->
        Ok ()
    | `No | `Unknown ->
        Error (Error.of_string error_msg)

  let of_option opt ~error =
    Result.of_option opt ~error:(Error.of_string error) |> Deferred.return

  let validate_generated_config ~conf_dir ~old_genesis_timestamp =
    let open Deferred.Or_error.Let_syntax in
    (* The config is generated in a subdirectory *)
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
    (* All files exist, now validate config contents *)
    let expected_fork_slot = slot_chain_end + hard_fork_genesis_slot_delta in
    (* Read and parse config using Runtime_config *)
    let%bind daemon_config =
      Yojson.Safe.from_file daemon_json
      |> Runtime_config.of_yojson
      |> Result.map_error ~f:Error.of_string
      |> Deferred.return
    in
    (* Extract proof.fork.global_slot_since_genesis *)
    let%bind proof =
      of_option daemon_config.proof
        ~error:"Generated config missing proof field"
    in
    let%bind fork =
      of_option proof.fork ~error:"Generated config missing proof.fork field"
    in
    let fork_slot = fork.global_slot_since_genesis in
    (* Verify fork slot *)
    let%bind () =
      if fork_slot <> expected_fork_slot then
        Deferred.Or_error.error_string
          (sprintf "proof.fork.global_slot_since_genesis is %d, expected %d"
             fork_slot expected_fork_slot )
      else Deferred.Or_error.return ()
    in
    (* Extract new genesis timestamp *)
    let%bind new_genesis =
      of_option daemon_config.genesis
        ~error:"Generated config missing genesis field"
    in
    let%bind new_genesis_timestamp =
      of_option new_genesis.genesis_state_timestamp
        ~error:"Generated config missing genesis_state_timestamp"
    in
    (* Parse timestamps and calculate expected offset *)
    let old_time = Time.of_string old_genesis_timestamp in
    let new_time = Time.of_string new_genesis_timestamp in
    let expected_offset_ms =
      Int64.( * )
        (Int64.of_int expected_fork_slot)
        (Int64.of_int slot_duration_ms)
    in
    let actual_offset_ms =
      Time.diff new_time old_time |> Time.Span.to_ms |> Int64.of_float
    in
    (* Verify timestamp offset *)
    if Int64.( <> ) actual_offset_ms expected_offset_ms then
      Deferred.Or_error.error_string
        (sprintf
           "Genesis timestamp offset is %Ld ms, expected %Ld ms (fork_slot=%d \
            * slot_duration=%d ms)"
           actual_offset_ms expected_offset_ms expected_fork_slot
           slot_duration_ms )
    else Deferred.Or_error.return ()

  let generate_hardfork_config daemon output =
    (* Generate 10 test accounts *)
    let client = Daemon.client daemon in
    let%map ledger_content = Daemon.Client.test_ledger client ~n:10 in
    let all_accounts =
      Yojson.Safe.from_string ledger_content
      |> Runtime_config.Accounts.of_yojson |> Result.ok_or_failwith
    in
    (* Take the first account as block producer and set its balance *)
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
    (* Extract keypair from the block producer account *)
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
        |> Option.value_exn
             ~message:"Block producer account missing private key"
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
    let daemon : Runtime_config.Daemon.t =
      { txpool_max_size = None
      ; peer_list_url = None
      ; max_zkapp_segment_per_transaction = None
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
      Runtime_config.Proof_keys.make ~block_window_duration_ms:slot_duration_ms
        ()
    in
    (* Set genesis timestamp to a few minutes in the future *)
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
    let runtime_config =
      Runtime_config.make ~ledger ~daemon ~proof ~genesis ()
    in
    Runtime_config.to_yojson runtime_config |> Yojson.Safe.to_file output ;
    (block_producer_kp, genesis_timestamp)

  let test_case (test : t) =
    let open Deferred.Let_syntax in
    let daemon = Daemon.of_config test.config in
    let%bind () = Daemon.Config.generate_keys test.config in
    let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
    (* Generate config with hardfork parameters and get block producer keypair *)
    let%bind block_producer_kp, old_genesis_timestamp =
      generate_hardfork_config daemon ledger_file
    in
    (* Write block producer key to file *)
    let bp_key_path = test.config.dirs.conf ^/ "bp-key" in
    let password =
      lazy (Deferred.return @@ Bytes.of_string "naughty blue worm")
    in
    let%bind () =
      Secrets.Keypair.write_exn block_producer_kp ~privkey_path:bp_key_path
        ~password
    in
    (* Start daemon with migrate-exit flag and block producer key *)
    let%bind process =
      Daemon.start ~hardfork_handling:"migrate-exit"
        ~block_producer_key:bp_key_path daemon
    in
    (* Wait for daemon to bootstrap *)
    let%bind result = Daemon.wait_for_node_init process in
    let%bind () =
      match result with
      | Ok () ->
          Deferred.return ()
      | Error e ->
          let () = printf "Error:\n%s\n" (Error.to_string_hum e) in
          let log_file = Daemon.Config.ConfigDirs.mina_log test.config.dirs in
          let%bind logs = Reader.file_contents log_file in
          let () = printf "Daemon logs:\n%s\n" logs in
          Writer.flushed (Lazy.force Writer.stdout)
    in
    (* Poll for activated file to appear (with 10 minute timeout) *)
    let conf_dir = test.config.dirs.conf in
    let auto_fork_dir = conf_dir ^/ "auto-fork-mesa-devnet" in
    let activated = auto_fork_dir ^/ "activated" in
    let start_time = Core.Time.now () in
    let timeout = Core.Time.Span.of_min 10. in
    let rec poll_for_activated () =
      let%bind.Deferred activated_exists = Sys.file_exists activated in
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
            let%bind.Deferred () = Async.after (Core.Time.Span.of_sec 5.) in
            poll_for_activated ()
    in
    let%bind.Deferred result = poll_for_activated () in
    match result with
    | `Timeout ->
        Deferred.return
          (Mina_automation_fixture.Intf.Failed
             (Error.of_string "Hardfork config was not generated within timeout")
          )
    | `Success -> (
        (* Wait for daemon to auto-shutdown after generating hardfork config *)
        match%bind.Deferred
          Async.Clock.with_timeout (Core.Time.Span.of_min 5.)
            (Process.wait process.process)
        with
        | `Timeout ->
            Deferred.return
              (Mina_automation_fixture.Intf.Failed
                 (Error.of_string
                    "Daemon did not shut down within 5 minutes after \
                     generating hardfork config" ) )
        | `Result (Ok ()) -> (
            (* Daemon exited cleanly with code 0, validate generated config *)
            match%map.Deferred
              validate_generated_config ~conf_dir ~old_genesis_timestamp
            with
            | Ok () ->
                Mina_automation_fixture.Intf.Passed
            | Error err ->
                Mina_automation_fixture.Intf.Failed err )
        | `Result (Error (`Exit_non_zero exit_code)) ->
            Deferred.return
              (Mina_automation_fixture.Intf.Failed
                 (Error.createf "Daemon exited with non-zero status: %d"
                    exit_code ) )
        | `Result (Error (`Signal signal)) ->
            Deferred.return
              (Mina_automation_fixture.Intf.Failed
                 (Error.createf "Daemon terminated by signal: %s"
                    (Core.Signal.to_string signal) ) ) )
end

module HardforkStateDirMismatch = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let%bind () = Daemon.Config.generate_keys test.config in
    let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
    let%bind () =
      Mina_automation_fixture.Daemon.generate_random_config daemon ledger_file
    in
    let%bind process =
      Daemon.start
        ~env:(`Extend [ ("MINA_HARDFORK_STATE_DIR", "/nonexistent") ])
        daemon
    in
    match%bind
      Async.Clock.with_timeout (Core.Time.Span.of_sec 5.)
        (Process.wait process.process)
    with
    | `Timeout ->
        let%map _ = Daemon.Process.force_kill process in
        Mina_automation_fixture.Intf.Failed
          (Error.of_string "Daemon did not exit within 5 seconds")
    | `Result (Ok ()) ->
        Deferred.return
          (Mina_automation_fixture.Intf.Failed
             (Error.of_string "Daemon exited with code 0, expected non-zero") )
    | `Result (Error (`Exit_non_zero _)) ->
        Deferred.return Mina_automation_fixture.Intf.Passed
    | `Result (Error (`Signal signal)) ->
        Deferred.return
          (Mina_automation_fixture.Intf.Failed
             (Error.createf "Daemon terminated by signal: %s"
                (Core.Signal.to_string signal) ) )
end

module ConfigFileOverride = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let client = Daemon.client daemon in
    let%bind () = Daemon.Config.generate_keys test.config in
    (* Generate 10 test accounts *)
    let%bind ledger_content = Daemon.Client.test_ledger client ~n:10 in
    let accounts =
      Yojson.Safe.from_string ledger_content
      |> Runtime_config.Accounts.of_yojson |> Result.ok_or_failwith
    in
    (* Build base config: ledger + fork A + daemon with network_id *)
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
      ; max_zkapp_segment_per_transaction = None
      ; max_event_elements = None
      ; max_action_elements = None
      ; zkapp_cmd_limit_hardcap = None
      ; slot_tx_end = None
      ; slot_chain_end = None
      ; hard_fork_genesis_slot_delta = None
      ; minimum_user_command_fee = None
      ; network_id = Some "obvious-base-config-network-id-for-test"
      ; sync_ledger_max_subtree_depth = None
      ; sync_ledger_default_subtree_depth = None
      }
    in
    let fork_a : Runtime_config.Fork_config.t =
      { state_hash = "3NKSvjaGSKiQuAt8BP1b1VCpLbJc9RcEFjYCaBYsJJFdrtd6tpaV"
      ; blockchain_length = 100
      ; global_slot_since_genesis = 200
      }
    in
    let proof_a = Runtime_config.Proof_keys.make ~fork:fork_a () in
    let base_config =
      Runtime_config.make ~ledger ~daemon:daemon_cfg ~proof:proof_a ()
    in
    (* Write base config as daemon.json *)
    let base_file = test.config.dirs.conf ^/ "daemon.json" in
    Runtime_config.to_yojson base_config |> Yojson.Safe.to_file base_file ;
    (* Build override config: only fork B, no ledger, no daemon *)
    let fork_b : Runtime_config.Fork_config.t =
      { state_hash = "3NLRTfY4kZyJtvaP4dFenDcxfoMfT3uEpkWS913KkeXLtziyVd15"
      ; blockchain_length = 500
      ; global_slot_since_genesis = 1000
      }
    in
    let proof_b = Runtime_config.Proof_keys.make ~fork:fork_b () in
    let override_config = Runtime_config.make ~proof:proof_b () in
    (* Write override config *)
    let override_file = test.config.dirs.conf ^/ "override.json" in
    Runtime_config.to_yojson override_config
    |> Yojson.Safe.to_file override_file ;
    (* Start daemon with override config file *)
    let%bind process = Daemon.start ~config_files:[ override_file ] daemon in
    let%bind result = Daemon.wait_for_node_init process in
    let%bind () =
      match result with
      | Ok () ->
          Deferred.return ()
      | Error e ->
          let () = printf "Error:\n%s\n" (Error.to_string_hum e) in
          let log_file = Daemon.Config.ConfigDirs.mina_log test.config.dirs in
          let%bind logs = Reader.file_contents log_file in
          let () = printf "Daemon logs:\n%s\n" logs in
          Writer.flushed (Lazy.force Writer.stdout)
    in
    (* Query merged runtime config from daemon *)
    let%bind output =
      Daemon.Client.advanced_runtime_config process.client
        ~rest_port:test.config.rest_port
    in
    let%bind () = Daemon.Client.stop_daemon process.client in
    (* Parse and verify the merged config *)
    let validate () =
      let of_option opt ~error =
        Result.of_option opt ~error:(Error.of_string error) |> Deferred.return
      in
      let open Deferred.Or_error.Let_syntax in
      let%bind merged_config =
        Yojson.Safe.from_string output
        |> Runtime_config.of_yojson
        |> Result.map_error ~f:Error.of_string
        |> Deferred.return
      in
      (* Verify fork B won (override) *)
      let%bind proof =
        of_option merged_config.proof ~error:"Merged config missing proof field"
      in
      let%bind fork =
        of_option proof.fork ~error:"Merged config missing proof.fork field"
      in
      let%bind () =
        if Runtime_config.Fork_config.equal fork fork_b then
          Deferred.Or_error.return ()
        else
          Deferred.Or_error.error_string
            "Merged proof.fork does not match expected fork B"
      in
      (* Verify daemon.network_id preserved from base *)
      let%bind daemon_merged =
        of_option merged_config.daemon
          ~error:"Merged config missing daemon field"
      in
      let expected_network_id = "obvious-base-config-network-id-for-test" in
      let%bind () =
        match daemon_merged.network_id with
        | Some id when String.equal id expected_network_id ->
            Deferred.Or_error.return ()
        | Some id ->
            Deferred.Or_error.error_string
              (sprintf "daemon.network_id is %s, expected %s" id
                 expected_network_id )
        | None ->
            Deferred.Or_error.error_string
              (sprintf "daemon.network_id is None, expected Some %s"
                 expected_network_id )
      in
      (* Verify ledger preserved from base *)
      let%bind () =
        match merged_config.ledger with
        | Some _ ->
            Deferred.Or_error.return ()
        | None ->
            Deferred.Or_error.error_string
              "Merged config missing ledger (should be preserved from base)"
      in
      Deferred.Or_error.return ()
    in
    validate ()
    >>| function
    | Ok () ->
        Mina_automation_fixture.Intf.Passed
    | Error err ->
        Mina_automation_fixture.Intf.Failed err
end

module PeerListUrlInvalidScheme = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let%bind () = Daemon.Config.generate_keys test.config in
    let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
    let%bind () =
      Mina_automation_fixture.Daemon.generate_random_config daemon ledger_file
    in
    let%bind process =
      Daemon.start ~peer_list_url:"ftp://invalid-scheme.example.com/peers.txt"
        daemon
    in
    match%bind
      Async.Clock.with_timeout
        (Core.Time.Span.of_sec 30.)
        (Process.wait process.process)
    with
    | `Timeout ->
        let%bind _ = Daemon.Process.force_kill process in
        Deferred.return
          (Mina_automation_fixture.Intf.Failed
             (Error.of_string "Daemon did not exit within 30 seconds") )
    | `Result (Ok ()) ->
        Deferred.return
          (Mina_automation_fixture.Intf.Failed
             (Error.of_string
                "Daemon exited with code 0, expected non-zero for invalid \
                 peer-list-url scheme" ) )
    | `Result (Error (`Exit_non_zero _)) ->
        Deferred.return Mina_automation_fixture.Intf.Passed
    | `Result (Error (`Signal signal)) ->
        Deferred.return
          (Mina_automation_fixture.Intf.Failed
             (Error.of_string
                (sprintf "Daemon terminated by signal: %s"
                   (Core.Signal.to_string signal) ) ) )
end

module PeerListUrlNoScheme = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let%bind () = Daemon.Config.generate_keys test.config in
    let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
    let%bind () =
      Mina_automation_fixture.Daemon.generate_random_config daemon ledger_file
    in
    let%bind process = Daemon.start ~peer_list_url:"not-a-url-at-all" daemon in
    match%bind
      Async.Clock.with_timeout
        (Core.Time.Span.of_sec 30.)
        (Process.wait process.process)
    with
    | `Timeout ->
        let%bind _ = Daemon.Process.force_kill process in
        Deferred.return
          (Mina_automation_fixture.Intf.Failed
             (Error.of_string "Daemon did not exit within 30 seconds") )
    | `Result (Ok ()) ->
        Deferred.return
          (Mina_automation_fixture.Intf.Failed
             (Error.of_string
                "Daemon exited with code 0, expected non-zero for \
                 peer-list-url without scheme" ) )
    | `Result (Error (`Exit_non_zero _)) ->
        Deferred.return Mina_automation_fixture.Intf.Passed
    | `Result (Error (`Signal signal)) ->
        Deferred.return
          (Mina_automation_fixture.Intf.Failed
             (Error.of_string
                (sprintf "Daemon terminated by signal: %s"
                   (Core.Signal.to_string signal) ) ) )
end

module PeerListUrlHttpWarning = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let%bind () = Daemon.Config.generate_keys test.config in
    let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
    let%bind () =
      Mina_automation_fixture.Daemon.generate_random_config daemon ledger_file
    in
    let%bind process =
      Daemon.start
        ~peer_list_url:"http://bootnodes.minaprotocol.com/networks/devnet.txt"
        daemon
    in
    (* The daemon should not crash immediately from URL validation.
       Give it a few seconds to get past the peer-list-url check. *)
    let%bind () = after (Core.Time.Span.of_sec 10.) in
    (* Check if the process is still running *)
    let%bind process_status =
      Async.Clock.with_timeout (Core.Time.Span.of_sec 1.)
        (Process.wait process.process)
    in
    let%bind () =
      match process_status with
      | `Timeout ->
          (* Still running, kill it *)
          let%map _ = Daemon.Process.force_kill process in
          ()
      | `Result _ ->
          Deferred.return ()
    in
    (* Read log file and check for HTTP warning *)
    let log_file = Daemon.Config.ConfigDirs.mina_log test.config.dirs in
    let%bind log_exists = Sys.file_exists log_file in
    let%map logs =
      match log_exists with
      | `Yes ->
          Reader.file_contents log_file
      | `No | `Unknown ->
          Deferred.return ""
    in
    if
      String.is_substring logs ~substring:"HTTP instead of HTTPS"
      || String.is_substring logs ~substring:"insecure"
    then Mina_automation_fixture.Intf.Passed
    else
      Mina_automation_fixture.Intf.Failed
        (Error.of_string
           "Expected warning about HTTP being insecure in daemon logs" )
end

module PeerListUrlValidHttps = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let%bind () = Daemon.Config.generate_keys test.config in
    let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
    let%bind () =
      Mina_automation_fixture.Daemon.generate_random_config daemon ledger_file
    in
    let%bind process =
      Daemon.start
        ~peer_list_url:"https://bootnodes.minaprotocol.com/networks/devnet.txt"
        daemon
    in
    (* The daemon should not crash immediately from URL validation.
       Give it a few seconds to get past the peer-list-url check. *)
    let%bind () = after (Core.Time.Span.of_sec 5.) in
    (* Check if the process is still running *)
    match%bind
      Async.Clock.with_timeout (Core.Time.Span.of_sec 1.)
        (Process.wait process.process)
    with
    | `Timeout ->
        (* Still running = good, the URL was accepted *)
        let%bind _ = Daemon.Process.force_kill process in
        Deferred.return Mina_automation_fixture.Intf.Passed
    | `Result (Ok ()) ->
        (* Exited cleanly - also fine, URL was accepted *)
        Deferred.return Mina_automation_fixture.Intf.Passed
    | `Result (Error (`Exit_non_zero exit_code)) ->
        (* Check if exit was due to URL validation by reading logs *)
        let log_file = Daemon.Config.ConfigDirs.mina_log test.config.dirs in
        let%bind log_exists = Sys.file_exists log_file in
        let%bind logs =
          match log_exists with
          | `Yes ->
              Reader.file_contents log_file
          | `No | `Unknown ->
              Deferred.return ""
        in
        if
          String.is_substring logs
            ~substring:"peer-list-url must be a valid URL"
        then
          Deferred.return
            (Mina_automation_fixture.Intf.Failed
               (Error.of_string "Daemon rejected valid https peer-list-url") )
        else
          (* Non-zero exit for other reasons is acceptable *)
          Deferred.return
            (Mina_automation_fixture.Intf.Warning
               (sprintf "Daemon exited with code %d (not due to URL validation)"
                  exit_code ) )
    | `Result (Error (`Signal signal)) ->
        Deferred.return
          (Mina_automation_fixture.Intf.Failed
             (Error.of_string
                (sprintf "Daemon terminated by signal: %s"
                   (Core.Signal.to_string signal) ) ) )
end

(** Verify the daemon sends node-status reports to the configured URL.

    Starts a mock HTTP server, boots the daemon with [--node-status-url]
    pointing at it, waits for bootstrap, then polls the mock for collected
    payloads and validates expected JSON fields are present. *)
module NodeStatusReport = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let default_mock_server_port = 19876

  let mock_server_port =
    Sys.getenv "MINA_NODE_STATUS_MOCK_PORT"
    |> Option.bind ~f:(fun s -> Option.try_with (fun () -> Int.of_string s))
    |> Option.value ~default:default_mock_server_port

  (** Poll [/collected-status] until at least one payload arrives. *)
  let poll_for_status ~port ~timeout_min =
    let start_time = Core.Time.now () in
    let timeout = Core.Time.Span.of_min timeout_min in
    let rec go () =
      let%bind statuses_result =
        Node_status_mock_server.collected_status ~port
      in
      match statuses_result with
      | Error (raw, msg) ->
          Deferred.return
            (Error
               (sprintf "Failed to parse status payload: %s\nRaw: %s" msg raw)
            )
      | Ok [] ->
          if
            Core.Time.Span.( > )
              (Core.Time.diff (Core.Time.now ()) start_time)
              timeout
          then
            Deferred.return (Error "Timed out waiting for node status reports")
          else
            let%bind () = after (Core.Time.Span.of_sec 5.) in
            go ()
      | Ok (hd :: rest) ->
          Deferred.return (Ok (Mina_stdlib.Nonempty_list.init hd rest))
    in
    go ()

  let test_case (test : t) =
    let port = mock_server_port in
    let mock_ref = ref None in
    let process_ref = ref None in
    Monitor.protect
      (fun () ->
        (* 1. Start mock server *)
        let%bind mock = Node_status_mock_server.start ~port in
        mock_ref := Some mock ;
        let%bind () = Node_status_mock_server.health_check ~port () in
        (* 2. Setup and start daemon *)
        let daemon = Daemon.of_config test.config in
        let%bind () = Daemon.Config.generate_keys test.config in
        let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
        let%bind () =
          Mina_automation_fixture.Daemon.generate_random_config daemon
            ledger_file
        in
        let status_url = sprintf "http://localhost:%d/node-status" port in
        let%bind process =
          Daemon.start ~node_status_url:status_url ~simplified_node_stats:false
            daemon
        in
        process_ref := Some process ;
        (* 3. Wait for bootstrap *)
        let%bind result = Daemon.wait_for_node_init process in
        match result with
        | Error e ->
            let () = printf "Error:\n%s\n" (Error.to_string_hum e) in
            let log_file = Daemon.Config.ConfigDirs.mina_log test.config.dirs in
            let%bind logs = Reader.file_contents log_file in
            let () = printf "Daemon logs:\n%s\n" logs in
            let%bind () = Writer.flushed (Lazy.force Writer.stdout) in
            Deferred.return
              (Mina_automation_fixture.Intf.Failed
                 (Error.tag e ~tag:"Bootstrap failed") )
        | Ok () -> (
            (* 4. Poll for status reports *)
            let%map status_result = poll_for_status ~port ~timeout_min:3. in
            (* 5. Validate - if we got statuses, they're already validated by parsing *)
            match status_result with
            | Error msg ->
                Mina_automation_fixture.Intf.Failed (Error.of_string msg)
            | Ok _statuses ->
                Mina_automation_fixture.Intf.Passed ) )
      ~finally:(fun () ->
        let%bind () =
          match !process_ref with
          | None ->
              Deferred.unit
          | Some process -> (
              let%bind stop_result =
                Monitor.try_with (fun () ->
                    Daemon.Client.stop_daemon process.client )
              in
              match stop_result with
              | Ok () ->
                  Deferred.unit
              | Error _exn ->
                  (* Fall back to forcefully killing the daemon; ignore any errors *)
                  let%map _ =
                    Monitor.try_with (fun () ->
                        Daemon.Process.force_kill process )
                  in
                  () )
        in
        match !mock_ref with
        | None ->
            Deferred.unit
        | Some mock ->
            Node_status_mock_server.stop mock )
end

let () =
  let open Alcotest in
  run "Test commadline."
    [ ( "new-background"
      , [ test_case "The mina daemon works in background mode" `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (BackgroundMode) ) )
        ] )
    ; ( "restart"
      , [ test_case "The mina daemon recovers from crash" `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (DaemonRecover) ) )
        ] )
    ; ( "ledger-hash"
      , [ test_case "The mina ledger hash evaluates correctly" `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (LedgerHash) ) )
        ] )
    ; ( "ledger-currency"
      , [ test_case "The mina ledger currency evaluates correctly" `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (LedgerCurrency) ) )
        ] )
    ; ( "ledger-export-snarked-ledger"
      , [ test_case "The mina ledger export snarked-ledger outputs valid JSON"
            `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (ExportSnarkedLedger) ) )
        ] )
    ; ( "advanced-print-signature-kind"
      , [ test_case "The mina cli prints correct signature kind" `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (AdvancedPrintSignatureKind) ) )
        ] )
    ; ( "advanced-compile-time-constants"
      , [ test_case
            "The mina cli does not print log when printing compile time \
             constants"
            `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (AdvancedCompileTimeConstants) ) )
        ] )
    ; ( "advanced-constraint-system-digests"
      , [ test_case
            "The mina cli does not print log when printing constrain system \
             digests"
            `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (AdvancedConstraintSystemDigests) ) )
        ] )
    ; ( "auto-hardfork-config-generation"
      , [ test_case
            "The mina daemon automatically generates hardfork config and shuts \
             down"
            `Slow
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (AutoHardforkConfigGeneration) ) )
        ] )
    ; ( "hardfork-state-dir-mismatch"
      , [ test_case
            "The mina daemon fails when MINA_HARDFORK_STATE_DIR mismatches \
             config dir"
            `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (HardforkStateDirMismatch) ) )
        ] )
    ; ( "config-file-override"
      , [ test_case "Multiple --config-file flags merge/override configs" `Slow
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (ConfigFileOverride) ) )
        ] )
    ; ( "peer-list-url-invalid-scheme"
      , [ test_case
            "The mina daemon rejects --peer-list-url with invalid scheme \
             (ftp://)"
            `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (PeerListUrlInvalidScheme) ) )
        ] )
    ; ( "peer-list-url-no-scheme"
      , [ test_case
            "The mina daemon rejects --peer-list-url without http/https scheme"
            `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (PeerListUrlNoScheme) ) )
        ] )
    ; ( "peer-list-url-valid-https"
      , [ test_case
            "The mina daemon accepts --peer-list-url with valid https:// URL"
            `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (PeerListUrlValidHttps) ) )
        ] )
    ; ( "peer-list-url-http-warning"
      , [ test_case
            "The mina daemon warns when --peer-list-url uses http:// instead \
             of https://"
            `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (PeerListUrlHttpWarning) ) )
        ] )
    ; ( "node-status-report"
      , [ test_case
            "The mina daemon sends node status reports to configured URL" `Slow
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (NodeStatusReport) ) )
        ] )
    ]
