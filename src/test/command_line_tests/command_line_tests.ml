open Async
open Mina_automation


module New_Test = struct

  type t = Mina_automation_fixture.Daemon.before_bootstrap

  let test_case (test : t) =
    let open Deferred.Let_syntax in
    let daemon = Daemon.of_config test.config in
    let%bind () = Daemon.Config.generate_keys test.config in
    let%bind process = Daemon.start daemon in
    let%bind.Deferred.Result () = Daemon.Client.wait_for_bootstrap process.client () in
    let %bind () = Daemon.Client.stop_daemon process.client in
    Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
end



let () =
  let open Alcotest in
  run "Test commadline."
    [( "new-background"
      , [ test_case "The mina daemon works in background mode" `Quick
             (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon.Make_FixtureWithoutBootstrap
                          (New_Test) ) )
        ] )
    ]
