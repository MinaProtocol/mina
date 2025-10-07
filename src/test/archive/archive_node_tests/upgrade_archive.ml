open Async
open Core
open Mina_automation
open Mina_automation_fixture.Archive
open Common

(* NOTE:
   To run this test, several preparation is needed
   - ensure we have this test, replayer & archive node build with public_network profile
   - ensure we have a data base instance up
   - Run the following:
     ```
     MINA_TEST_POSTGRES_URI=postgres://postgres:xxxx@localhost:5432 \
     MINA_TEST_NETWORK_DATA=./src/test/archive/sample_db \
     ./_build/default/src/test/archive/archive_node_tests/archive_node_tests.exe \
     test upgrade_archive
     ```
*)

type t = Mina_automation_fixture.Archive.after_bootstrap

let test_case (test_data : t) =
  let open Deferred.Let_syntax in
  let daemon = Daemon.default () in
  let archive_uri = test_data.archive.config.postgres_uri in
  let temp_dir = test_data.temp_dir in
  let%bind precomputed_blocks =
    unpack_precomputed_blocks ~temp_dir test_data.network_data
  in
  let log_file = temp_dir ^ "/upgrade.log" in
  let upgrade_path =
    Archive.Scripts.filepath `Upgrade
    |> Option.value_exn ~message:"Failed to find upgrade script"
  in
  let%bind _ =
    Psql.run_script ~connection:(Psql.Conn_str archive_uri) upgrade_path
  in

  Archive.Process.start_logging test_data.archive ~log_file ;
  let%bind () =
    Daemon.archive_blocks_from_files daemon.executor
      ~archive_address:test_data.archive.config.server_port ~format:`Precomputed
      precomputed_blocks
  in

  let%bind () =
    assert_replayer_run_against_last_block
      ~replayer_input_file_path:
        (Network_data.replayer_input_file_path test_data.network_data)
      archive_uri temp_dir
  in

  Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
