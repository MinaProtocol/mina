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

let common_tests =
  let open Alcotest in
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

(* The fork-canonical-bug repro needs a specific prefork archive dump and
   chain B extensional block fixtures (see
   buildkite/scripts/tests/archive-fork-canonical-bug-test.sh). It is
   registered only when [MINA_TEST_RUN_FORK_CANONICAL_BUG=1] is set, so the
   generic [scripts/tests/archive-node-test.sh] runner that uses the
   [sample_db] fixture leaves it alone. The dedicated [ArchiveForkCanonicalBugTest]
   buildkite job sets the env var. *)
let fork_canonical_bug_tests =
  let open Alcotest in
  match Sys.getenv "MINA_TEST_RUN_FORK_CANONICAL_BUG" with
  | Some v when String.equal v "1" ->
      [ ( "fork_canonical_bug"
        , [ test_case
              "Reproduce update_chain_status branch-2 mis-classification when \
               fork point equals last canonical block"
              `Quick
              (Runner.run_blocking
                 ( module Mina_automation_fixture.Archive
                          .Make_FixtureWithoutBootstrap
                            (Archive_fork_canonical_bug_test) ) )
          ] )
      ]
  | _ ->
      []

let () =
  let open Alcotest in
  run "Test archive node." (common_tests @ fork_canonical_bug_tests)
