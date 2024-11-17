open Async
open Core
open Mina_automation

(**
 * Test the basic functionality of the mina daemon and client through the CLI
 *)

module CliTests = struct
  module TestBackgroundDaemon = struct
    type t = Mina_automation.Daemon.DaemonProcess.t

    let test_case (daemon : Mina_automation.Daemon.DaemonProcess.t) =
      let open Deferred.Or_error.Let_syntax in
      let client = daemon.client in
      let%bind _ = Daemon.Client.wait_for_bootstrap client () in
      Deferred.Or_error.return (Daemon.Client.stop_daemon client) >>| ignore
  end

  module TestDaemonRecover = struct
    type t = Mina_automation.Daemon.DaemonProcess.t

    let test_case (daemon : Mina_automation.Daemon.DaemonProcess.t) =
      let open Deferred.Or_error.Let_syntax in
      let client = daemon.client in
      let%bind _ = Daemon.Client.wait_for_bootstrap client () in
      let%bind _ = Daemon.DaemonProcess.force_kill daemon in
      let executor = Daemon.of_context AutoDetect in
      let%bind _ =
        Deferred.Or_error.return (Daemon.start executor daemon.config)
      in
      let%bind _ = Daemon.Client.wait_for_bootstrap client () in
      Deferred.Or_error.return (Daemon.Client.stop_daemon client) >>| ignore
  end
end

let () =
  Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true

let () =
  let open Alcotest in
  run "Test commadline."
    [ ( "background"
      , [ test_case "The mina daemon works in background mode" `Quick
            (Test_runner.run_blocking
               ( module Daemon_test_runner.Make_DefaultTestCase
                          (CliTests.TestBackgroundDaemon) ) )
        ] )
    ; ( "restart"
      , [ test_case "The mina daemon recovers from crash" `Quick
            (Test_runner.run_blocking
               ( module Daemon_test_runner.Make_DefaultTestCase
                          (CliTests.TestDaemonRecover) ) )
        ] )
    ]
