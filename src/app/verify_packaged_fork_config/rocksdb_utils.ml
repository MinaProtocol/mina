(** RocksDB database utilities for ledger verification.

    This module provides functions to scan RocksDB databases and compare
    their contents for ledger verification purposes.
*)

open Core
open Async

(** Convert a byte to its two-digit hex representation.

    @param c The character (byte) to convert
    @return Two-character hex string
*)
let byte_to_hex c = sprintf "%02x" (Char.to_int c)

(** Convert a bigstring to hex string representation.

    @param bs The bigstring to convert
    @return Hex string representation
*)
let bigstring_to_hex bs =
  Bigstring.to_string bs |> String.to_list |> List.map ~f:byte_to_hex
  |> String.concat ~sep:""

(** Scan a RocksDB database and write all key-value pairs as hex to a file.

    Each line in the output file has the format: "key_hex : value_hex"

    This is used to create deterministic text representations of RocksDB
    databases for comparison purposes.

    @param db_path Path to the RocksDB database directory
    @param output_file Path where hex dump should be written
    @return Ok () on success, Error with message on failure
*)
let scan_rocksdb_to_hex db_path output_file =
  Log.Global.info "Scanning RocksDB at: %s" db_path ;
  Log.Global.info "Output file: %s" output_file ;
  let open Rocksdb.Database in
  try
    let db = create db_path in
    let alist = to_alist db in
    Log.Global.debug "Found %d key-value pairs in database" (List.length alist) ;
    let%bind oc = Writer.open_file output_file in
    List.iter alist ~f:(fun (key, value) ->
        let key_hex = bigstring_to_hex key in
        let value_hex = bigstring_to_hex value in
        Writer.write oc (sprintf "%s : %s\n" key_hex value_hex) ) ;
    close db ;
    let%bind () = Writer.close oc in
    Log.Global.info "Successfully scanned RocksDB to hex file" ;
    return (Ok ())
  with exn ->
    let err_msg = Exn.to_string exn in
    Log.Global.error "Failed to scan RocksDB at %s: %s" db_path err_msg ;
    return (Error err_msg)

(** Compare two RocksDB databases by comparing their hex dumps.

    This extracts both databases to hex files and then compares those files.

    @param db1_path Path to first RocksDB database
    @param db2_path Path to second RocksDB database
    @param workdir Working directory for temporary hex dump files
    @return Deferred boolean indicating if databases have identical contents
*)
let compare_rocksdb_databases ~db1_path ~db2_path ~workdir =
  Log.Global.info "Comparing RocksDB databases:\n  %s\n  %s" db1_path db2_path ;
  let scan1_file = Filename.concat workdir "db1.scan" in
  let scan2_file = Filename.concat workdir "db2.scan" in
  let%bind scan1_result = scan_rocksdb_to_hex db1_path scan1_file in
  let%bind scan2_result = scan_rocksdb_to_hex db2_path scan2_file in
  match (scan1_result, scan2_result) with
  | Ok (), Ok () ->
      File_operations.files_equal scan1_file scan2_file
  | _ ->
      Log.Global.error "Failed to scan one or both databases" ;
      return false

(** Extract and compare ledger tarball databases.

    This function:
    1. Extracts tarball to a temporary directory
    2. Scans the RocksDB database inside
    3. Compares with reference database

    @param tarball_path Path to the tarball containing RocksDB database
    @param reference_db_path Path to reference RocksDB database
    @param workdir Working directory for extraction and comparison
    @return Deferred boolean indicating if databases match
*)
let verify_ledger_tarball ~tarball_path ~reference_db_path ~workdir =
  Log.Global.info "Verifying ledger tarball: %s" tarball_path ;
  let extract_dir = Filename.concat workdir "extracted" in
  let%bind () = File_operations.mkdir_p extract_dir in
  let extract_cmd =
    sprintf "tar -xzf %s -C %s"
      (Filename.quote tarball_path)
      (Filename.quote extract_dir)
  in
  match%bind Shell_operations.run_command extract_cmd with
  | Ok () ->
      compare_rocksdb_databases ~db1_path:extract_dir
        ~db2_path:reference_db_path ~workdir
  | Error err ->
      Log.Global.error "Failed to extract tarball: %s" err ;
      return false
