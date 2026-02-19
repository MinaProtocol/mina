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
    let%bind result = Daemon.Client.wait_for_bootstrap process.client () in
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
    let%bind () = Daemon.Client.stop_daemon process.client in
    Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
end

module DaemonRecover = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let%bind () = Daemon.Config.generate_keys test.config in
    let ledger_file = test.config.dirs.conf ^/ "daemon.json" in
    let%bind () =
      Mina_automation_fixture.Daemon.generate_random_config daemon ledger_file
    in
    let%bind process = Daemon.start daemon in
    let%bind.Deferred.Result () =
      Daemon.Client.wait_for_bootstrap process.client ()
    in
    let%bind.Deferred.Result _ = Daemon.Process.force_kill process in
    let%bind process = Daemon.start daemon in
    let%bind.Deferred.Result () =
      Daemon.Client.wait_for_bootstrap process.client ()
    in
    let%bind () = Daemon.Client.stop_daemon process.client in
    Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
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
    let%bind hash = Daemon.Client.ledger_hash client ~ledger_file in
    Deferred.Or_error.return
      ( if contain_log_output hash then
        Mina_automation_fixture.Intf.Failed "output contains log"
      else if not (String.is_prefix ~prefix:"j" hash) then
        Failed "invalid ledger hash prefix"
      else if Int.( <> ) (String.length hash) 52 then
        Failed
          (Printf.sprintf "invalid ledger hash length (%d)" (String.length hash))
      else Passed )
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
    let%bind output = Daemon.Client.ledger_currency client ~ledger_file in
    let actual = Scanf.sscanf output "MINA : %f" Fn.id in
    let total_currency_float = float_of_int total_currency /. 1000000000.0 in

    Deferred.Or_error.return
    @@
    if contain_log_output output then
      Mina_automation_fixture.Intf.Failed "output contains log"
    else if not Float.(abs (total_currency_float - actual) < 0.001) then
      Failed
        (Printf.sprintf "invalid mina total count %f vs %f" total_currency_float
           actual )
    else Passed
end

module AdvancedPrintSignatureKind = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let client = Daemon.client daemon in
    let%bind output = Daemon.Client.advanced_print_signature_kind client in
    let expected = "testnet" in

    Deferred.Or_error.return
    @@
    if contain_log_output output then
      Mina_automation_fixture.Intf.Failed "output contains log"
    else if not (String.equal expected (String.strip output)) then
      Failed (Printf.sprintf "invalid signature kind %s vs %s" expected output)
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
    let%bind output =
      Daemon.Client.advanced_compile_time_constants client
        ~config_file:temp_file
    in

    Deferred.Or_error.return
    @@
    if contain_log_output output then
      Mina_automation_fixture.Intf.Failed "output contains log"
    else Passed
end

module AdvancedConstraintSystemDigests = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let daemon = Daemon.of_config test.config in
    let client = Daemon.client daemon in
    let%bind output = Daemon.Client.advanced_constraint_system_digests client in

    Deferred.Or_error.return
    @@
    if contain_log_output output then
      Mina_automation_fixture.Intf.Failed "output contains log"
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
    let%bind result = Daemon.Client.wait_for_bootstrap process.client () in
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
        Deferred.Or_error.return
          (Mina_automation_fixture.Intf.Failed
             "Hardfork config was not generated within timeout" )
    | `Success -> (
        (* Wait for daemon to auto-shutdown after generating hardfork config *)
        match%bind.Deferred
          Async.Clock.with_timeout (Core.Time.Span.of_min 5.)
            (Process.wait process.process)
        with
        | `Timeout ->
            Deferred.Or_error.return
              (Mina_automation_fixture.Intf.Failed
                 "Daemon did not shut down within 5 minutes after generating \
                  hardfork config" )
        | `Result (Ok ()) -> (
            (* Daemon exited cleanly with code 0, validate generated config *)
            match%bind.Deferred
              validate_generated_config ~conf_dir ~old_genesis_timestamp
            with
            | Ok () ->
                Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
            | Error err ->
                Deferred.Or_error.return
                  (Mina_automation_fixture.Intf.Failed (Error.to_string_hum err))
            )
        | `Result (Error (`Exit_non_zero exit_code)) ->
            Deferred.Or_error.return
              (Mina_automation_fixture.Intf.Failed
                 (sprintf "Daemon exited with non-zero status: %d" exit_code) )
        | `Result (Error (`Signal signal)) ->
            Deferred.Or_error.return
              (Mina_automation_fixture.Intf.Failed
                 (sprintf "Daemon terminated by signal: %s"
                    (Core.Signal.to_string signal) ) ) )
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
    ]
