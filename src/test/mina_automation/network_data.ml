open Async

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
