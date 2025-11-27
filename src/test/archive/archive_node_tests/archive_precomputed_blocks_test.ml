open Async
open Core
open Mina_automation
open Mina_automation_fixture.Archive
open Common

(**
 * Test the basic functionality of the mina archive with mocked deamon
 *)

(* asserts count of archive blocked (we are skipping genesis block) *)
(* NOTE: first assertion is failing occasionally due to race condition issue,
   where we are asserting count of precomputed blocks in database.
   From time to time not all blocks are processed before running assertion,
   as a result we are receiving false failures. That's why a retry mechanism is implemented.
*)
let assert_archived_blocks ~archive_uri ~expected =
  let connection = Psql.Conn_str archive_uri in
  let rec check_blocks_count ~attempts_left =
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
    if Int.( = ) actual_blocks_count expected then Deferred.unit
    else if attempts_left <= 1 then
      failwithf
        "Invalid number of archive blocks after 10 attempts. Actual (%d) vs \
         Expected (%d)"
        actual_blocks_count expected ()
    else
      let%bind () = after (sec 3.0) in
      check_blocks_count ~attempts_left:(attempts_left - 1)
  in
  check_blocks_count ~attempts_left:10

(* Convert performance metrics to a JSON format suitable for output *)
(* The metrics are expected to be a list of tuples (operation, avg_time) *)
(* where operation is a string and avg_time is a float representing the average time in milliseconds *)
let perf_metrics_to_yojson metrics =
  let json_list =
    List.map metrics ~f:(fun (operation, avg_time) ->
        `Assoc
          [ ("operation", `String operation); ("avg_time_ms", `Float avg_time) ] )
  in
  `List json_list

(** Extract performance metrics from a log file and calculate average execution times.

  This function reads a log file line by line, parses each line as a JSON log entry,
  and extracts performance metrics identified by the "is_perf_metric" metadata field.
  For each performance metric entry, it extracts the "elapsed" time and "label" fields.

  @param log_file Path to the log file to process
  @return A deferred list of tuples containing (operation_label, average_time_in_ms)

  The function performs the following steps:
  1. Reads all lines from the specified log file
  2. Filters and parses lines containing performance metrics
  3. Groups metrics by operation label
  4. Calculates the average execution time for each operation

  @raises Failure if a log line cannot be parsed as valid JSON
  @raises exn if required metadata fields ("elapsed" or "label") are missing *)
let extract_perf_metrics log_file =
  let open Deferred.Let_syntax in
  let%bind lines = Reader.file_lines log_file in
  let perf_metrics =
    List.filter_map lines ~f:(fun line ->
        if String.is_empty line then None
        else
          match Logger.Message.of_yojson (Yojson.Safe.from_string line) with
          | Ok entry ->
              if String.Map.mem entry.metadata "is_perf_metric" then
                let time_in_ms =
                  String.Map.find entry.metadata "elapsed"
                  |> Option.value_exn ~here:[%here]
                       ~message:
                         ("Missing elapsed in log entry in log line: " ^ line)
                  |> Yojson.Safe.Util.to_float
                in
                let label =
                  String.Map.find entry.metadata "label"
                  |> Option.value_exn ~here:[%here]
                       ~message:
                         ("Missing label in log entry in log line: " ^ line)
                  |> Yojson.Safe.Util.to_string
                in
                Some (label, time_in_ms)
              else None
          | Error err ->
              failwithf "Invalid log line: %s. Error: %s" line err () )
  in
  (* Calculate the average time for each operation *)
  (* Group by operation and calculate the average time *)
  let averaged_metrics =
    String.Map.of_alist_multi perf_metrics
    |> Map.to_alist
    |> List.map ~f:(fun (operation, times) ->
           let avg_time =
             List.fold times ~init:0.0 ~f:( +. )
             /. Float.of_int (List.length times)
           in
           (operation, avg_time) )
  in
  Deferred.return averaged_metrics

type t = Mina_automation_fixture.Archive.after_bootstrap

let test_case (test_data : t) =
  let open Deferred.Let_syntax in
  let daemon = Daemon.default () in
  let archive_uri = test_data.archive.config.postgres_uri in
  let output = test_data.temp_dir in
  let%bind precomputed_blocks =
    unpack_precomputed_blocks test_data.network_data
      ~temp_dir:test_data.temp_dir
  in
  let log_file = output ^ "/precomputed_blocks_test.log" in
  Archive.Process.start_logging test_data.archive ~log_file ;
  let%bind () = Archive.wait_for ~log:log_file in
  let%bind () =
    Daemon.archive_blocks_from_files daemon.executor
      ~archive_address:test_data.archive.config.server_port ~format:`Precomputed
      precomputed_blocks
  in

  let%bind () =
    assert_archived_blocks ~archive_uri
      ~expected:(List.length precomputed_blocks)
  in

  let%bind () =
    assert_replayer_run_against_last_block
      ~replayer_input_file_path:
        (Network_data.replayer_input_file_path test_data.network_data)
      archive_uri test_data.temp_dir
  in

  let%bind perf_data = extract_perf_metrics log_file in
  perf_metrics_to_yojson perf_data |> Yojson.to_file "archive.perf" ;

  Deferred.Or_error.return Mina_automation_fixture.Intf.Passed
