open Async
open Core
open Mina_automation

(**
 * Test the basic functionality of the mina archive with mocked deamon
 *)

(* asserts count of archive blocked (we are skipping genesis block) *)
let assert_archived_blocks ~archive_uri ~expected =
  let connection = Psql.Conn_str archive_uri in
  let%bind actual_blocks_count =
    Psql.run_command ~connection "Select count(*) from blocks where height > 1"
  in
  let actual_blocks_count =
    actual_blocks_count |> String.strip |> Int.of_string
  in
  if Int.( <> ) actual_blocks_count expected then
    failwithf "Invalid number of archive blocks. Actual (%d) vs Expected (%d)"
      actual_blocks_count expected ()
  else Deferred.unit

module ArchivePrecomputedBlocksFromDaemon = struct
  type t = Archive_test_runner.init

  let test_case (test_data : Archive_test_runner.init) =
    let open Deferred.Let_syntax in
    let daemon = Daemon.of_context AutoDetect in
    let archive_uri = test_data.archive.config.postgres_uri in
    let output = Filename.temp_dir "precomputed_blocks" "" in
    let%bind precomputed_blocks =
      Network_data.untar_precomputed_blocks test_data.network_data_folder output
    in
    let precomputed_blocks =
      List.map precomputed_blocks ~f:(fun file -> output ^ "/" ^ file)
    in
    Archive.ArchiveProcess.print_output test_data.archive ;
    let%bind () =
      Daemon.dispatch_blocks daemon
        ~archive_address:test_data.archive.config.server_port
        ~format:Archive_blocks.Precomputed precomputed_blocks
    in

    let%bind () =
      assert_archived_blocks ~archive_uri
        ~expected:(List.length precomputed_blocks)
    in
    let connection = Psql.Conn_str archive_uri in
    let%bind latest_state_hash =
      Psql.run_command ~connection
        "select state_hash from blocks WHERE id=(SELECT max(id) FROM blocks) \
         LIMIT 1"
    in
    let output_ledger = output ^ "/output_ledger.json" in
    let replayer = Replayer.of_context AutoDetect in
    let%bind _ =
      Replayer.run replayer ~archive_uri
        ~input_config:
          (Network_data.replayer_input_file_path test_data.network_data_folder)
        ~target_state_hash:latest_state_hash ~interval_checkpoint:10
        ~output_ledger ()
    in
    let output_ledger = Replayer.Output.of_json_file_exn output_ledger in
    assert (
      String.equal output_ledger.target_epoch_ledgers_state_hash
        latest_state_hash ) ;
    Deferred.Or_error.return ()
end

let () =
  Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true

let () =
  let open Alcotest in
  run "Test archive node."
    [ ( "precomputed blocks"
      , [ test_case "The mina daemon works in background mode" `Quick
            (Test_runner.run_blocking
               ( module Archive_test_runner.Make_DefaultTestCase
                          (ArchivePrecomputedBlocksFromDaemon) ) )
        ] )
    ]
