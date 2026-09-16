open Async

(** 
  This module defines a type [t] representing test network data and provides functions to manipulate and access this data.

  {1 Type Definitions}

  - [t]: A record type containing the following fields:
    - [init_script]: The initialization script file name.
    - [precomputed_blocks_zip]: The precomputed blocks archive file name.
    - [genesis_ledger_file]: The genesis ledger file name.
    - [replayer_input_file]: The replayer input file name.
    - [folder]: The folder containing the files.

  {1 Functions}

  - [create folder]: Creates a new [t] record with default file names and the specified folder.
  - [init_script_path t]: Returns the full path to the initialization script file.
  - [replayer_input_file_path t]: Returns the full path to the replayer input file.
  - [precomputed_blocks_zip t]: Returns the full path to the precomputed blocks archive file.
  - [genesis_ledger_path t]: Returns the full path to the genesis ledger file.
  - [untar_precomputed_blocks t output]: Extracts the precomputed blocks archive to the specified output directory and returns a sorted list of the extracted files.
*)
type t =
  { init_script : String.t
  ; precomputed_blocks_zip : String.t
  ; genesis_ledger_file : String.t
  ; replayer_input_file : String.t
  ; folder : String.t
  }

let create folder =
  { init_script = "archive_db.sql"
  ; genesis_ledger_file = "genesis.json"
  ; precomputed_blocks_zip = "precomputed_blocks.tar.xz"
  ; replayer_input_file = "replayer_input_file.json"
  ; folder
  }

let init_script_path t = t.folder ^ "/" ^ t.init_script

let replayer_input_file_path t = t.folder ^ "/" ^ t.replayer_input_file

let precomputed_blocks_zip t = t.folder ^ "/" ^ t.precomputed_blocks_zip

let genesis_ledger_path t = t.folder ^ "/" ^ t.genesis_ledger_file

let untar_precomputed_blocks t output =
  let open Deferred.Let_syntax in
  let%bind () = Unix.mkdir ~p:() output in
  let precomputed_blocks_zip = precomputed_blocks_zip t in
  let%bind _ = Utils.untar ~archive:precomputed_blocks_zip ~output in
  let%bind array = Sys.readdir output in
  Deferred.return (Array.to_list array |> Utils.sort_archive_files)
