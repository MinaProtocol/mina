open Core
open Mina_automation_runner

let () =
  Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true

let () =
  let open Alcotest in
  run "Test archive node."
    [ ( "precomputed_blocks"
      , [ test_case
            "Recreate database from precomputed blocks sent from mock daemon"
            `Quick
            (Runner.run_blocking
               ( module Mina_automation_fixture.Archive.Make_FixtureWithBootstrap
                          (Archive_precomputed_blocks_test) ) )
        ] )
    ; ( "genesis_load"
      , [ test_case "Load mainnet genesis ledger without memory leak" `Quick
            (Runner.run_blocking
               ( module Mina_automation_fixture.Archive
                        .Make_FixtureWithoutBootstrap
                          (Load_genesis_ledger) ) )
        ] )
    ; ( "upgrade_archive"
      , [ test_case
            "Recreate database from precomputed blocks after upgrade script is \
             applied"
            `Quick
            (Runner.run_blocking
               ( module Mina_automation_fixture.Archive.Make_FixtureWithBootstrap
                          (Upgrade_archive) ) )
        ] )
    ]
