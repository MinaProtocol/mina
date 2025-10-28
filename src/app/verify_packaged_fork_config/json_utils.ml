(** JSON parsing and extraction utilities.

    This module provides safe JSON operations with proper error handling,
    including field extraction, hash comparison, and validation operations.
*)

open Core
open Async
open Yojson.Safe

(** Extract a string value from a JSON object using dot-notation path.

    Supports nested field access using dots (e.g., "parent.child.field").
    Returns empty string if field is not found or is null.

    @param json The JSON object to query
    @param path Dot-separated path to the field (e.g., "data.hash")
    @return The string value, or empty string if not found

    @example
    {[
      let json = `Assoc [("user", `Assoc [("name", `String "Alice")])] in
      get_string json "user.name"  (* Returns "Alice" *)
    ]}
*)
let get_string json path =
  let parts =
    String.split path ~on:'.'
    |> List.filter ~f:(fun s -> not (String.is_empty s))
  in
  let rec traverse json = function
    | [] ->
        json
    | part :: rest -> (
        match json with
        | `Assoc fields -> (
            match List.Assoc.find fields part ~equal:String.equal with
            | Some value ->
                traverse value rest
            | None ->
                `Null )
        | _ ->
            `Null )
  in
  match traverse json parts with
  | `String s ->
      s
  | `Int i ->
      Int.to_string i
  | `Float f ->
      Float.to_string f
  | `Bool b ->
      Bool.to_string b
  | `Null ->
      ""
  | json ->
      (* For complex types, return JSON string representation *)
      to_string json

(** Extract a JSON field from a file using a dot-notation query path.

    This is a higher-level function that reads a JSON file and extracts
    a specific field value.

    @param file_path Path to the JSON file
    @param query Dot-separated path to the field
    @return The extracted value as a string
    @raise Exit if JSON parsing fails or file cannot be read
*)
let jq_extract file_path query =
  Log.Global.debug "Extracting JSON field '%s' from: %s" query file_path ;
  let%bind json_content = Reader.file_contents file_path in
  try
    let json = from_string json_content in
    let result = get_string json query in
    Log.Global.debug "JSON extraction successful, value: %s" result ;
    return result
  with
  | Yojson.Json_error msg ->
      let err_msg = sprintf "JSON parsing error: %s" msg in
      Log.Global.error "JSON extraction failed for %s: %s" file_path err_msg ;
      eprintf "Error extracting JSON from %s: %s\n%!" file_path err_msg ;
      exit 1
  | exn ->
      let err_msg = Exn.to_string exn in
      Log.Global.error "JSON extraction failed for %s: %s" file_path err_msg ;
      eprintf "Error extracting JSON from %s: %s\n%!" file_path err_msg ;
      exit 1

(** Extract ledger hashes from a JSON object using predefined paths.

    @param json The JSON object containing hash fields
    @param staking_path Path to staking hash field
    @param next_path Path to next epoch hash field
    @param ledger_path Path to ledger hash field
    @return Record containing all three hashes
*)
let extract_ledger_hashes json ~staking_path ~next_path ~ledger_path =
  Types.
    { staking_hash = get_string json staking_path
    ; next_hash = get_string json next_path
    ; ledger_hash = get_string json ledger_path
    }

(** Compare two sets of ledger hashes.

    @param hashes1 First set of hashes
    @param hashes2 Second set of hashes
    @return true if all hashes match, false otherwise
*)
let compare_ledger_hashes hashes1 hashes2 =
  Types.equal_ledger_hashes hashes1 hashes2

(** Extract ledger hashes from legacy hashes JSON file.

    @param json JSON object from legacy hashes file
    @return Ledger hashes record
*)
let extract_legacy_hashes json =
  extract_ledger_hashes json
    ~staking_path:Constants.JsonPaths.LegacyHashes.staking_hash
    ~next_path:Constants.JsonPaths.LegacyHashes.next_hash
    ~ledger_path:Constants.JsonPaths.LegacyHashes.ledger_hash

(** Extract ledger hashes from precomputed block JSON.

    @param json JSON object from precomputed block file
    @return Ledger hashes record
*)
let extract_precomputed_block_hashes json =
  extract_ledger_hashes json
    ~staking_path:Constants.JsonPaths.PrecomputedBlock.staking_hash
    ~next_path:Constants.JsonPaths.PrecomputedBlock.next_hash
    ~ledger_path:Constants.JsonPaths.PrecomputedBlock.ledger_hash

(** Extract ledger hashes from daemon config JSON.

    @param json JSON object from daemon config file
    @return Ledger hashes record
*)
let extract_daemon_config_hashes json =
  extract_ledger_hashes json
    ~staking_path:Constants.JsonPaths.DaemonConfig.staking_hash
    ~next_path:Constants.JsonPaths.DaemonConfig.next_hash
    ~ledger_path:Constants.JsonPaths.DaemonConfig.ledger_hash

(** Verify that legacy hashes match precomputed block hashes.

    Reads both JSON files, extracts hashes, and compares them.

    @param legacy_hashes_file Path to legacy hashes JSON file
    @param precomputed_block_file Path to precomputed block JSON file
    @return Deferred boolean indicating if hashes match
    @raise Exit if JSON parsing fails
*)
let verify_legacy_hashes_match ~legacy_hashes_file ~precomputed_block_file =
  Log.Global.info "Verifying legacy hashes match precomputed block" ;
  let%bind legacy_content = Reader.file_contents legacy_hashes_file in
  let%bind precomputed_content = Reader.file_contents precomputed_block_file in
  try
    let legacy_json = from_string legacy_content in
    let precomputed_json = from_string precomputed_content in
    let legacy_hashes = extract_legacy_hashes legacy_json in
    let block_hashes = extract_precomputed_block_hashes precomputed_json in
    let matches = compare_ledger_hashes legacy_hashes block_hashes in
    if matches then
      Log.Global.info "Legacy hashes verification successful - all hashes match"
    else (
      Log.Global.error "Legacy hashes verification failed - hashes don't match" ;
      Log.Global.error "Legacy: %s"
        (Sexp.to_string_hum (Types.sexp_of_ledger_hashes legacy_hashes)) ;
      Log.Global.error "Block: %s"
        (Sexp.to_string_hum (Types.sexp_of_ledger_hashes block_hashes)) ) ;
    return matches
  with
  | Yojson.Json_error msg ->
      let err_msg = sprintf "JSON parsing error: %s" msg in
      Log.Global.error "Hash verification failed: %s" err_msg ;
      return false
  | exn ->
      let err_msg = Exn.to_string exn in
      Log.Global.error "Hash verification failed: %s" err_msg ;
      return false

(** Verify that config hashes match between two config files.

    @param config1_file Path to first config file
    @param config2_file Path to second config file
    @return Deferred boolean indicating if hashes match
*)
let verify_config_hashes_match ~config1_file ~config2_file =
  Log.Global.info "Verifying config hashes match between:\n  %s\n  %s"
    config1_file config2_file ;
  let%bind config1_content = Reader.file_contents config1_file in
  let%bind config2_content = Reader.file_contents config2_file in
  try
    let config1_json = from_string config1_content in
    let config2_json = from_string config2_content in
    let hashes1 = extract_daemon_config_hashes config1_json in
    let hashes2 = extract_daemon_config_hashes config2_json in
    let matches = compare_ledger_hashes hashes1 hashes2 in
    if matches then
      Log.Global.info "Config hashes verification successful - all hashes match"
    else (
      Log.Global.error "Config hashes verification failed - hashes don't match" ;
      Log.Global.error "Config1: %s"
        (Sexp.to_string_hum (Types.sexp_of_ledger_hashes hashes1)) ;
      Log.Global.error "Config2: %s"
        (Sexp.to_string_hum (Types.sexp_of_ledger_hashes hashes2)) ) ;
    return matches
  with
  | Yojson.Json_error msg ->
      let err_msg = sprintf "JSON parsing error: %s" msg in
      Log.Global.error "Config hash verification failed: %s" err_msg ;
      return false
  | exn ->
      let err_msg = Exn.to_string exn in
      Log.Global.error "Config hash verification failed: %s" err_msg ;
      return false

(** Create a JSON object with current timestamp for genesis override.

    @return Deferred string containing JSON with current UTC timestamp
*)
let create_genesis_timestamp_override () =
  let now = Time_ns.now () in
  let utc_time = Time_ns.to_time_float_round_nearest now in
  let timestamp =
    Time.format utc_time "%Y-%m-%dT%H:%M:%SZ" ~zone:Time.Zone.utc
  in
  let override_json =
    `Assoc
      [ ("genesis", `Assoc [ ("genesis_state_timestamp", `String timestamp) ]) ]
  in
  return (pretty_to_string override_json)
