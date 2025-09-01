open Async
open Mina_automation
open Core

module BackgroundMode = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let open Deferred.Let_syntax in
    let daemon = Daemon.of_config test.config in
    let%bind () = Daemon.Config.generate_keys test.config in
    let ledger_file = test.config.dirs.conf ^ "/" ^ "daemon.json" in
    let%bind _ =
      Mina_automation_fixture.Daemon.generate_random_ledger daemon ledger_file
    in
    let%bind process = Daemon.start daemon in
    let%bind result =
      Daemon.Client.wait_for_bootstrap process.client ()
    in
    let%bind () =
      match result with
      | Ok () -> Deferred.return ()
      | Error _ ->
      let%bind logs =
        let log_file = Daemon.Config.ConfigDirs.mina_log test.config.dirs in
        Reader.file_contents log_file
      in
      let () = Printf.printf "Daemon logs:\n%s\n" logs in
      Deferred.return ()
    in
    let%bind () = Daemon.Client.stop_daemon process.client in
    Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
end

module DaemonRecover = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let open Deferred.Let_syntax in
    let daemon = Daemon.of_config test.config in
    let%bind () = Daemon.Config.generate_keys test.config in
    let ledger_file = test.config.dirs.conf ^ "/" ^ "daemon.json" in
    let%bind _ =
      Mina_automation_fixture.Daemon.generate_random_ledger daemon ledger_file
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
    let open Deferred.Let_syntax in
    let daemon = Daemon.of_config test.config in
    let client = Daemon.client daemon in
    let ledger_file = test.config.dirs.conf ^ "/" ^ "daemon.json" in
    let%bind _ =
      Mina_automation_fixture.Daemon.generate_random_ledger daemon ledger_file
    in
    let%bind hash = Daemon.Client.ledger_hash client ~ledger_file in

    if contain_log_output hash then
      Deferred.Or_error.return
      @@ Mina_automation_fixture.Intf.Failed "output contains log"
    else if not (String.is_prefix ~prefix:"j" hash) then
      Deferred.Or_error.return
      @@ Mina_automation_fixture.Intf.Failed "invalid ledger hash prefix"
    else if Int.( <> ) (String.length hash) 52 then
      Deferred.Or_error.return
      @@ Mina_automation_fixture.Intf.Failed
           (Printf.sprintf "invalid ledger hash length (%d)"
              (String.length hash) )
    else Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
end

module LedgerCurrency = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let open Deferred.Let_syntax in
    let daemon = Daemon.of_config test.config in
    let client = Daemon.client daemon in
    let ledger_file = test.config.dirs.conf ^ "/" ^ "daemon.json" in
    let%bind accounts =
      Mina_automation_fixture.Daemon.generate_random_ledger daemon ledger_file
    in
    let total_currency =
      List.map accounts ~f:(fun account ->
          Currency.Balance.to_nanomina_int account.balance )
      |> List.sum (module Int) ~f:Fn.id
    in
    let%bind output = Daemon.Client.ledger_currency client ~ledger_file in
    let actual = Scanf.sscanf output "MINA : %f" (fun actual -> actual) in
    let total_currency_float = float_of_int total_currency /. 1000000000.0 in

    if contain_log_output output then
      Deferred.Or_error.return
        (Mina_automation_fixture.Intf.Failed "output contains log")
    else if not Float.(abs (total_currency_float - actual) < 0.001) then
      Deferred.Or_error.return
        (Mina_automation_fixture.Intf.Failed
           (Printf.sprintf "invalid mina total count %f vs %f"
              total_currency_float actual ) )
    else Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
end

module AdvancedPrintSignatureKind = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let open Deferred.Let_syntax in
    let daemon = Daemon.of_config test.config in
    let client = Daemon.client daemon in
    let%bind output = Daemon.Client.advanced_print_signature_kind client in
    let expected = "testnet" in

    if contain_log_output output then
      Deferred.Or_error.return
        (Mina_automation_fixture.Intf.Failed "output contains log")
    else if not (String.equal expected (String.strip output)) then
      Deferred.Or_error.return
        (Mina_automation_fixture.Intf.Failed
           (Printf.sprintf "invalid signature kind %s vs %s" expected output) )
    else Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
end

module AdvancedCompileTimeConstants = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let open Deferred.Let_syntax in
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

    if contain_log_output output then
      Deferred.Or_error.return
        (Mina_automation_fixture.Intf.Failed "output contains log")
    else Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
end

module AdvancedConstraintSystemDigests = struct
  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let open Deferred.Let_syntax in
    let daemon = Daemon.of_config test.config in
    let client = Daemon.client daemon in
    let%bind output = Daemon.Client.advanced_constraint_system_digests client in

    if contain_log_output output then
      Deferred.Or_error.return
        (Mina_automation_fixture.Intf.Failed "output contains log")
    else Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
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
    ]
