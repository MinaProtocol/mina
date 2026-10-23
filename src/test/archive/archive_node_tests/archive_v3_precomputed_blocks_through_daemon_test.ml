open Async
open Core
open Mina_automation

(**
 * Test that blocks of version 3 reach the archive through a daemon's GraphQL
 * API, which forwards them as given, and are archived under their Berkeley
 * hashes.
 *)

type t = Mina_automation_fixture.Archive.after_bootstrap

let test_case (test_data : t) =
  let open Deferred.Let_syntax in
  let archive_uri = test_data.archive.config.postgres_uri in
  let archive_port = test_data.archive.config.server_port in
  Archive.Process.start_logging test_data.archive
    ~log_file:
      (test_data.temp_dir ^/ "v3_precomputed_blocks_through_daemon_test.log") ;
  match%bind
    Archive_healthcheck.wait_db_and_server_ready ~postgres_uri:archive_uri
      ~server_port:archive_port ()
  with
  | Error e ->
      Deferred.return (Mina_automation_fixture.Intf.Failed e)
  | Ok () ->
      let daemon = Daemon.default () in
      let%bind () = Daemon.Config.generate_keys daemon.config in
      let%bind process =
        Daemon.start daemon ~archive_address:archive_port
          ~config_files:
            [ Network_data.genesis_ledger_path test_data.network_data ]
      in
      Monitor.protect
        ~finally:(fun () -> Daemon.Client.stop_daemon process.client)
        (fun () ->
          match%bind Daemon.wait_for_node_init process with
          | Error e ->
              Deferred.return (Mina_automation_fixture.Intf.Failed e)
          | Ok () ->
              let%bind output =
                Daemon.archive_blocks_through_daemon daemon.executor
                  ~rest_port:daemon.config.rest_port ~format:`Precomputed
                  (List.map Archive_v3_precomputed_blocks_test.v3_blocks
                     ~f:(fun (file, _, _) -> file) )
                  ()
              in
              Async.printf "mina advanced archive-blocks output:\n%s\n" output ;
              let%map () =
                Deferred.List.iter Archive_v3_precomputed_blocks_test.v3_blocks
                  ~f:(fun (_, state_hash, expected) ->
                    Archive_v3_precomputed_blocks_test
                    .assert_archived_command_hashes ~archive_uri ~state_hash
                      ~expected )
              in
              Mina_automation_fixture.Intf.Passed )
