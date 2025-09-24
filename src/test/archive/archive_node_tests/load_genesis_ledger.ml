open Async
open Core
open Mina_automation
open Mina_automation_fixture.Archive

(**
  Test file for memory leak detection in archive process.
  
  This test is designed to identify potential memory leaks that occur during
  the archive process, specifically focusing on session cleanup issues with
  PostgreSQL connections. The memory leak manifests as sessions not being
  properly cleaned up, leading to an abrupt increase in PostgreSQL memory
  consumption over time.
  
  The test validates that:
  - Archive operations properly release database sessions
  - PostgreSQL memory usage remains stable during archive cycles
*)

type t = Mina_automation_fixture.Archive.before_bootstrap

let postgres_user_name = "postgres"

let test_case (test_data : t) =
  let config =
    { test_data.config with config_file = "genesis_ledgers/mainnet.json" }
  in
  let logger = Logger.create () in
  let log_file = test_data.temp_dir ^/ "archive.load_genesis_ledger.log" in
  let%bind process = Archive.of_config config |> Archive.start in
  Archive.Process.start_logging process ~log_file ;

  let sleep_duration = Time.Span.of_sec 10.0 in

  let max_archive_memory = 1024.0 in
  let max_postgres_memory = 4096.0 in

  (* Set the duration for the archive process *)
  let expected_duration = Time.Span.of_min 10.0 in

  [%log info] "Max Archive Memory: %s MiB" (Float.to_string max_archive_memory) ;
  [%log info] "Max Postgres Memory: %s MiB"
    (Float.to_string max_postgres_memory) ;
  [%log info] "Sleep Duration: %s" (Time.Span.to_string sleep_duration) ;

  let start_time = Time.now () in
  let rec loop () =
    let executed_duration = Time.(diff (now ()) start_time) in
    if Time.Span.(executed_duration > expected_duration) then
      return Mina_automation_fixture.Intf.Passed
    else
      match Archive.Process.get_memory_usage_mib process with
      | Some mem when Float.( > ) mem max_archive_memory ->
          Mina_automation_fixture.Intf.Failed
            (Error.create "Archive process memory exceeds 1GiB" mem
               Float.sexp_of_t )
          |> return
      | None ->
          Mina_automation_fixture.Intf.Failed
            (Error.createf "Error getting memory usage for archive process")
          |> return
      | Some mem ->
          [%log info] "Archive Memory usage: %s MiB" (Float.to_string mem) ;
          let%bind memory =
            Utils.get_memory_usage_mib_of_user_process postgres_user_name
          in
          if Float.( > ) memory max_postgres_memory then
            Mina_automation_fixture.Intf.Failed
              (Error.create "Postgres memory exceeds 4GiB" memory
                 Float.sexp_of_t )
            |> return
          else (
            [%log info] "Postgres Memory usage: %s MiB" (Float.to_string memory) ;
            let%bind () = Clock.after sleep_duration in
            loop () )
  in
  loop ()
