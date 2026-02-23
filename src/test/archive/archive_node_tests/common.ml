open Async
open Core
open Mina_automation

(** Assert that the replayer runs successfully against the latest block in the archive.

  This function queries the archive database to find the latest state hash,
  then runs the replayer with the specified input configuration file against
  that target state hash. It verifies that the output ledger's target epoch
  ledgers state hash matches the latest state hash from the database.

  @param replayer_input_file_path Path to the replayer input configuration file
  @param archive_uri URI connection string for the archive database
  @param output Output directory path where the ledger will be written
  @return Unit deferred that completes when assertion passes *)
let assert_replayer_run_against_last_block ~replayer_input_file_path archive_uri
    output =
  let open Deferred.Let_syntax in
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
    Replayer.run replayer ~archive_uri ~input_config:replayer_input_file_path
      ~target_state_hash:latest_state_hash ~interval_checkpoint:10
      ~output_ledger ()
  in
  let () = print_endline replayer_output in
  let output_ledger = Replayer.Output.of_json_file_exn output_ledger in
  assert (
    String.equal output_ledger.target_epoch_ledgers_state_hash latest_state_hash ) ;
  Deferred.unit

(** Unpack precomputed blocks from a source archive to a temporary directory.

  This function extracts precomputed blocks from a tar archive into the specified
  temporary directory and filters the results to only include JSON files.

  @param temp_dir Temporary directory path where blocks will be extracted
  @param source Source path of the tar archive containing precomputed blocks
  @return Deferred list of file paths to extracted JSON block files *)
let unpack_precomputed_blocks ~temp_dir source =
  let open Deferred.Let_syntax in
  let%bind precomputed_blocks =
    Network_data.untar_precomputed_blocks source temp_dir
  in
  List.map precomputed_blocks ~f:(fun file -> temp_dir ^ "/" ^ file)
  |> List.filter ~f:(fun file -> String.is_suffix file ~suffix:".json")
  |> Deferred.return
