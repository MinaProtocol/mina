open Async
open Mina_bootstrapper
open Mina_cli
open Mina_daemon
open Runner

(**
 * Test the basic functionality of the mina daemon and client through the CLI
 *)

module CliTests = struct
  let test_background_daemon () =
    let test_case config =
      let open Deferred.Or_error.Let_syntax in
      let bootstrapper = MinaBootstrapper.create config in
      let%bind _ = MinaBootstrapper.start bootstrapper in
      let%bind _ = MinaBootstrapper.wait_for_bootstrap bootstrapper in
      let mina_cli = MinaCli.create config.port config.mina_exe in
      let%map _ = MinaCli.stop_daemon mina_cli in
      ()
    in
    Async.Thread_safe.block_on_async_exn (fun () -> TestRunner.run test_case)

  let test_daemon_recover () =
    let test_case config =
      let open Deferred.Or_error.Let_syntax in
      let bootstrapper = MinaBootstrapper.create config in
      let%bind process = MinaBootstrapper.start bootstrapper in
      let daemon = MinaDaemon.create process config in
      let%bind _ = MinaBootstrapper.wait_for_bootstrap bootstrapper in
      let%bind _ = MinaDaemon.force_kill daemon in
      let%bind _ = MinaBootstrapper.start bootstrapper in
      let%bind _ = MinaBootstrapper.wait_for_bootstrap bootstrapper in
      let mina_cli = MinaCli.create config.port config.mina_exe in
      let%map _ = MinaCli.stop_daemon mina_cli in
      ()
    in
    Async.Thread_safe.block_on_async_exn (fun () -> TestRunner.run test_case)
end

let () =
  let open Alcotest in
  run "Test commadline."
    [ ( "commadnline-tests"
      , [ test_case "The mina daemon works in background mode" `Quick
            CliTests.test_background_daemon
        ; test_case "The mina daemon recovers from crash" `Quick
            CliTests.test_daemon_recover
        ] )
    ]
