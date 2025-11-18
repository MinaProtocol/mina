open Core
open Async
open Mina_automation

module HardforkAndSendTx = struct
  type t = Integration_test_lib.Test_config.t

  let logger = Logger.create ()

  let setup () : t =
    let open Integration_test_lib.Test_config in
    { (default ~constants:default_constants) with
      genesis_ledger =
        (let open Test_account in
        [ create ~account_name:"bp" ~balance:"400000" ()
        ; create ~account_name:"sender" ~balance:"300" ()
        ; create ~account_name:"receiver" ~balance:"1" ()
        ])
    ; block_producers = [ { node_name = "node"; account_name = "bp" } ]
    }

  let test_case (config : t) =
    let hf_config_folder = Filename.temp_dir "hardfork_config" "" in
    [%log info] "Hardfork config directory: %s\n" hf_config_folder;
    let daemon = Daemon.of_test_config config in
    let sender =
      Core.Map.find_exn daemon.config.genesis_ledger.keypairs "sender"
    in
    let receiver =
      Core.Map.find_exn daemon.config.genesis_ledger.keypairs "receiver"
    in
    let%bind process = Daemon.start daemon in
    let%bind.Deferred.Result () =
      Daemon.Client.wait_for_bootstrap process.client ()
    in

    let%bind.Deferred.Result () =
      Daemon.Client.generate_hardfork_config process.client ~output_folder:
        hf_config_folder
    in

    let%bind () = Daemon.Client.stop_daemon process.client in

    Deferred.Or_error.return @@ Mina_automation_fixture.Intf.Passed
end


let () =
  let open Alcotest in
  run "Test commadline."
    [ ( "hardfork and send tx"
      , [ test_case "The mina daemon perform hardfork and receives transaction on new network" `Quick
            (Mina_automation_runner.Runner.run_blocking
               ( module Mina_automation_fixture.Daemon
                        .Make_FixtureWithoutBootstrap
                          (HardforkAndSendTx) ) )
        ] )
    ]
