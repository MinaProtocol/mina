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

(* val test_case : t -> test_result Deferred.Or_error.t *)
let test_case (test_data : t) =
  let config =
    { test_data.config with config_file = "genesis_ledgers/mainnet.json" }
  in
  let logger = Logger.create () in
  let log_file = test_data.temp_dir ^ "/archive.load_genesis_ledger.log" in
  let%bind process = Archive.of_config config |> Archive.start in
  Archive.Process.start_logging process ~log_file ;

  let max_postgres_memory = 4000.0 in
  let sleep_duration = Time.Span.of_sec 10.0 in
  let max_archive_memory = 1000.0 in

  (* Set the duration for the archive process *)
  let duration = Time.Span.of_min 10.0 in

  [%log info] "Max Archive Memory: %s MiB" (Float.to_string max_archive_memory) ;
  [%log info] "Max Postgres Memory: %s MiB"
    (Float.to_string max_postgres_memory) ;
  [%log info] "Sleep Duration: %s" (Time.Span.to_string sleep_duration) ;

  let end_time = Time.add (Time.now ()) duration in
  let rec loop () =
    if Time.is_later (Time.now ()) ~than:end_time then Deferred.return ()
    else
      let memory = Archive.Process.get_memory_usage_mib process in
      let%bind () =
        match memory with
        | Some mem ->
            [%log info] "Archive Memory usage: %s MiB" (Float.to_string mem) ;
            if Float.( > ) mem max_archive_memory then
              failwith "Archive process memory exceeds 1GB"
            else Deferred.return ()
        | None ->
            failwith "Error getting memory usage for archive process"
      in
      let%bind memory =
        Utils.get_memory_usage_mib_of_user_process postgres_user_name
      in
      [%log info] "Postgres Memory usage: %s MiB" (Float.to_string memory) ;
      if Float.( > ) memory max_postgres_memory then
        failwith "Postgres memory exceeds 4GB" ;
      let%bind () = Clock.after sleep_duration in
      loop ()
  in
  match%map Monitor.try_with loop with
  | Ok () ->
      Mina_automation_fixture.Intf.Passed
  | Error exn ->
      Failed (Error.of_exn exn)
