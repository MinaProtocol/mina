open Core
open Mina_automation_runner

let logger = Logger.create ()

let () =
  Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true ;
  let random_seed =
    Time.(now () |> to_span_since_epoch |> Span.to_ms) |> Int.of_float
  in
  [%log info] "Initializing random with seed"
    ~metadata:[ ("seed", `Int random_seed) ] ;
  Random.init random_seed

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
    ; ( "live_upgrade_archive"
      , [ test_case
            "Recreate database from precomputed blocks. Meanwhile run upgrade \
             script randomly at some time"
            `Quick
            (Runner.run_blocking
               ( module Mina_automation_fixture.Archive.Make_FixtureWithBootstrap
                          (Live_upgrade_archive) ) )
        ] )
    ]
