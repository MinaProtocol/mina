open Async
open Core
open Mina_automation
open Mina_automation_runner
open Mina_automation_fixture.Archive

(**
 * Test the basic functionality of the mina archive with mocked deamon
 *)

(* asserts count of archive blocked (we are skipping genesis block) *)
let assert_archived_blocks ~archive_uri ~expected =
  let connection = Psql.Conn_str archive_uri in
  let%bind actual_blocks_count =
    Psql.run_command ~connection
      "SELECT COUNT(*) FROM blocks WHERE global_slot_since_genesis > 1"
  in
  let actual_blocks_count =
    match actual_blocks_count with
    | Ok count ->
        count |> Int.of_string
    | Error err ->
        failwith ("Failed to query blocks count: " ^ Error.to_string_hum err)
  in
  if Int.( <> ) actual_blocks_count expected then
    failwithf "Invalid number of archive blocks. Actual (%d) vs Expected (%d)"
      actual_blocks_count expected ()
  else Deferred.unit

module ArchivePrecomputedBlocksFromDaemon = struct
  type t = Mina_automation_fixture.Archive.after_bootstrap

  let test_case (test_data : t) =
    let open Deferred.Let_syntax in
    let daemon = Daemon.default in
    let archive_uri = test_data.archive.config.postgres_uri in
    let output = test_data.temp_dir in
    let%bind precomputed_blocks =
      Network_data.untar_precomputed_blocks test_data.network_data output
    in
    let precomputed_blocks =
      List.map precomputed_blocks ~f:(fun file -> output ^ "/" ^ file)
      |> List.filter ~f:(fun file -> String.is_suffix file ~suffix:".json")
    in
    Archive.Process.start_logging test_data.archive ;
    let%bind () =
      Daemon.archive_blocks_from_files daemon
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
        "SELECT state_hash FROM blocks ORDER BY id DESC LIMIT 1"
    in
    let latest_state_hash =
      match latest_state_hash with
      | Ok hash ->
          hash
      | Error err ->
          failwith
            ("Failed to query latest state hash: " ^ Error.to_string_hum err)
    in
    let output_ledger = output ^ "/output_ledger.json" in
    let replayer = Replayer.default in
    let%bind replayer_output =
      Replayer.run replayer ~archive_uri
        ~input_config:
          (Network_data.replayer_input_file_path test_data.network_data)
        ~target_state_hash:latest_state_hash ~interval_checkpoint:10
        ~output_ledger ()
    in
    let () = print_endline replayer_output in
    let output_ledger = Replayer.Output.of_json_file_exn output_ledger in
    assert (
      String.equal output_ledger.target_epoch_ledgers_state_hash
        latest_state_hash ) ;
    Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
end

let () =
  Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true

let () =
  let open Alcotest in
  run "Test archive node."
    [ ( "precomputed blocks"
      , [ test_case "The mina daemon works in background mode" `Quick
            (Runner.run_blocking
               ( module Mina_automation_fixture.Archive.Make_FixtureWithBootstrap
                          (ArchivePrecomputedBlocksFromDaemon) ) )
        ] )
    ]
