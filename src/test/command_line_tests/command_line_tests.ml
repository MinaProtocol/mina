open Async
open Mina_bootstrapper
open Mina_cli
open Mina_daemon
open Runner
open Core

(**
 * Test the basic functionality of the mina daemon and client through the CLI
 *)

module CliTests = struct
  let run test_case mina_path =
    Async.Thread_safe.block_on_async_exn (fun () ->
        TestRunner.run test_case mina_path )

  let test_background_daemon mina_path =
    let test_case config =
      let open Deferred.Or_error.Let_syntax in
      let bootstrapper = MinaBootstrapper.create config in
      let%bind _ = MinaBootstrapper.start bootstrapper in
      let%bind _ = MinaBootstrapper.wait_for_bootstrap bootstrapper in
      let mina_cli = MinaCli.create ~port:config.port config.mina_exe in
      let%map _ = MinaCli.stop_daemon mina_cli in
      ()
    in
    run test_case mina_path

  let test_daemon_recover mina_path =
    let test_case config =
      let open Deferred.Or_error.Let_syntax in
      let bootstrapper = MinaBootstrapper.create config in
      let%bind process = MinaBootstrapper.start bootstrapper in
      let daemon = MinaDaemon.create process config in
      let%bind _ = MinaBootstrapper.wait_for_bootstrap bootstrapper in
      let%bind _ = MinaDaemon.force_kill daemon in
      let%bind _ = MinaBootstrapper.start bootstrapper in
      let%bind _ = MinaBootstrapper.wait_for_bootstrap bootstrapper in
      let mina_cli = MinaCli.create ~port:config.port config.mina_exe in
      let%map _ = MinaCli.stop_daemon mina_cli in
      ()
    in
    run test_case mina_path

  let generate_random_ledger mina_cli =
    let open Deferred.Or_error.Let_syntax in
    let temp_file = Filename.temp_file "commandline" "ledger.json" in
    let%bind ledger_content = MinaCli.test_ledger mina_cli ~n:10 in
    let accounts =
      Yojson.Safe.from_string ledger_content
      |> Runtime_config.Accounts.of_yojson |> Result.ok_or_failwith
    in
    Runtime_config.Accounts.to_yojson accounts |> Yojson.Safe.to_file temp_file ;
    return (accounts, temp_file)

  let assert_don't_contain_log_output output =
    if String.is_substring ~substring:"{\"timestamp\":" output then
      failwith "logger output detected"
    else ()

  let test_ledger_hash mina_path =
    let test_case (config : Config.Config.t) =
      let open Deferred.Or_error.Let_syntax in
      let mina_cli = MinaCli.create config.mina_exe in
      let%bind _, ledger_file = generate_random_ledger mina_cli in
      let%bind hash = MinaCli.ledger_hash mina_cli ~ledger_file in
      assert_don't_contain_log_output hash ;
      if not (String.is_prefix ~prefix:"j" hash) then
        failwith "invalid ledger hash prefix" ;

      if Int.( <> ) (String.length hash) 52 then
        failwithf "invalid ledger hash length (%d)" (String.length hash) () ;

      return ()
    in
    run test_case mina_path

  let test_ledger_currency mina_path =
    let test_case (config : Config.Config.t) =
      let open Deferred.Or_error.Let_syntax in
      let mina_cli = MinaCli.create config.mina_exe in
      let%bind accounts, ledger_file = generate_random_ledger mina_cli in
      let total_currency =
        List.map accounts ~f:(fun account ->
            Currency.Balance.to_nanomina_int account.balance )
        |> List.sum (module Int) ~f:Fn.id
      in
      let%bind output = MinaCli.ledger_currency mina_cli ~ledger_file in
      let actual = Scanf.sscanf output "MINA : %f" (fun actual -> actual) in
      let total_currency_float = float_of_int total_currency /. 1000000000.0 in
      assert_don't_contain_log_output output ;
      if not Float.(abs (total_currency_float - actual) < 0.001) then
        failwithf "invalid mina total count %f vs %f" total_currency_float
          actual () ;
      return ()
    in
    run test_case mina_path

  let test_advanced_print_signature_kind mina_path =
    let test_case (config : Config.Config.t) =
      let open Deferred.Or_error.Let_syntax in
      let mina_cli = MinaCli.create config.mina_exe in
      let%bind output = MinaCli.advanced_print_signature_kind mina_cli in
      let expected = "testnet" in
      assert_don't_contain_log_output output ;
      if not (String.equal expected (String.strip output)) then
        failwithf "invalid signature kind %s vs %s" expected output () ;
      return ()
    in
    run test_case mina_path

  let test_advanced_compile_time_constants mina_path =
    let test_case (config : Config.Config.t) =
      let open Deferred.Or_error.Let_syntax in
      let mina_cli = MinaCli.create config.mina_exe in
      let%bind config_content = MinaCli.test_ledger mina_cli ~n:10 in
      let config_content =
        Printf.sprintf "{ \"ledger\":{ \"accounts\":%s } }" config_content
      in
      let temp_file = Filename.temp_file "commandline" "ledger.json" in
      Yojson.Safe.from_string config_content |> Yojson.Safe.to_file temp_file ;
      let%bind output =
        MinaCli.advanced_compile_time_constants mina_cli ~config_file:temp_file
      in
      assert_don't_contain_log_output output ;
      return ()
    in
    run test_case mina_path

  let test_advanced_constraint_system_digests mina_path =
    let test_case (config : Config.Config.t) =
      let open Deferred.Or_error.Let_syntax in
      let mina_cli = MinaCli.create config.mina_exe in
      let%bind output = MinaCli.advanced_constraint_system_digests mina_cli in
      assert_don't_contain_log_output output ;
      return ()
    in
    run test_case mina_path
end

let mina_path =
  let doc = "Path Path to mina daemon executable" in
  Cmdliner.Arg.(
    required
    & opt (some string) None
    & info [ "mina-path" ] ~doc ~docv:"MINA_PATH")

let () =
  let open Alcotest in
  run_with_args "Test commadline." mina_path
    [ ( "background"
      , [ test_case "The mina daemon works in background mode" `Quick
            CliTests.test_background_daemon
        ] )
    ; ( "restart"
      , [ test_case "The mina daemon recovers from crash" `Quick
            CliTests.test_daemon_recover
        ] )
    ; ( "ledger-hash"
      , [ test_case "The mina ledger hash evaluates correctly" `Quick
            CliTests.test_ledger_hash
        ] )
    ; ( "ledger-currency"
      , [ test_case "The mina ledger currency evaluates correctly" `Quick
            CliTests.test_ledger_currency
        ] )
    ; ( "advanced-print-signature-kind"
      , [ test_case "The mina cli prints correct signature kind" `Quick
            CliTests.test_advanced_print_signature_kind
        ] )
    ; ( "advanced-compile-time-constants"
      , [ test_case
            "The mina cli does not print log when printing compile time \
             constants"
            `Quick CliTests.test_advanced_compile_time_constants
        ] )
    ; ( "advanced-constraint-system-digests"
      , [ test_case
            "The mina cli does not print log when printing constrain system \
             digests"
            `Quick CliTests.test_advanced_constraint_system_digests
        ] )
    ]
