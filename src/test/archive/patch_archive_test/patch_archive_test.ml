(* patch_archive_test.ml *)

(* test patching of archive databases

   test structure:
    - import reference database for comparision (for example with 100 blocks)
    - create new schema and export blocks from reference db with some missing ones
    - patch the database with missing precomputed blocks
    - compare original and copy
*)

module Network_Data = struct
  type t =
    { init_script : String.t
    ; precomputed_blocks_zip : String.t
    ; genesis_ledger_file : String.t
    ; replayer_input_file : String.t
    ; folder : String.t
    }

  let create folder =
    { init_script = "archive_db.sql"
    ; genesis_ledger_file = "input.json"
    ; precomputed_blocks_zip = "precomputed_blocks.zip"
    ; replayer_input_file = "replayer_input_file.json"
    ; folder
    }
end

open Core_kernel
open Async
open Mina_automation

let main ~db_uri ~network_data_folder () =
  let open Deferred.Let_syntax in
  let missing_blocks_count = 3 in
  let network_name = "dummy" in

  let network_data = Network_Data.create network_data_folder in

  let output_folder = Filename.temp_dir_name ^ "/output" in

  let%bind output_folder = Unix.mkdtemp output_folder in

  let connection = Psql.Conn_str db_uri in

  let source_db_name = "patch_archive_test_source" in
  let target_db_name = "patch_archive_test_target" in
  let%bind _ = Psql.create_empty_db ~connection ~db:source_db_name in
  let%bind _ =
    Psql.run_script ~connection ~db:source_db_name
      (network_data.folder ^ "/" ^ network_data.init_script)
  in
  let%bind () = Psql.create_mina_db ~connection ~db:target_db_name in

  let source_db = db_uri ^ "/" ^ source_db_name in
  let target_db = db_uri ^ "/" ^ target_db_name in

  let extract_blocks = Extract_blocks.of_context Executor.AutoDetect in
  let config =
    { Extract_blocks.Config.archive_uri = source_db
    ; range = Extract_blocks.Config.AllBlocks
    ; output_folder = Some output_folder
    ; network = Some network_name
    ; include_block_height_in_name = true
    }
  in
  let%bind _ = Extract_blocks.run extract_blocks ~config in

  let archive_blocks = Archive_blocks.of_context Executor.AutoDetect in

  let%bind extensional_files =
    Sys.ls_dir output_folder
    >>= Deferred.List.map ~f:(fun e ->
            Deferred.return (output_folder ^ "/" ^ e) )
  in

  let n =
    List.init missing_blocks_count ~f:(fun _ ->
        (* never remove last block as missing-block-guardian can have issues when patching it
           as it patching only gaps
        *)
        Random.int (List.length extensional_files - 1) )
  in

  let unpatched_extensional_files =
    List.filteri extensional_files ~f:(fun i _ ->
        not (List.mem n i ~equal:Int.equal) )
    |> List.dedup_and_sort ~compare:(fun left right ->
           let scan_height item =
             let item =
               Filename.basename item |> Str.global_replace (Str.regexp "-") " "
             in
             Scanf.sscanf item "%s %d %s" (fun _ height _ -> height)
           in

           let left_height = scan_height left in
           let right_height = scan_height right in

           Int.compare left_height right_height )
  in

  let%bind _ =
    Archive_blocks.run archive_blocks ~blocks:unpatched_extensional_files
      ~archive_uri:target_db ~format:Extensional
  in

  let%bind missing_blocks_auditor_path =
    Missing_blocks_auditor.of_context Executor.AutoDetect
    |> Missing_blocks_auditor.path
  in

  let%bind archive_blocks_path = Archive_blocks.path archive_blocks in

  let config =
    { Missing_blocks_guardian.Config.archive_uri = Uri.of_string target_db
    ; precomputed_blocks = Uri.make ~scheme:"file" ~path:output_folder ()
    ; network = network_name
    ; run_mode = Run
    ; missing_blocks_auditor = missing_blocks_auditor_path
    ; archive_blocks = archive_blocks_path
    ; block_format = Extensional
    }
  in

  let missing_blocks_guardian =
    Missing_blocks_guardian.of_context Executor.AutoDetect
  in

  let%bind _ = Missing_blocks_guardian.run missing_blocks_guardian ~config in

  let replayer = Replayer.of_context Executor.AutoDetect in

  let%bind _ =
    Replayer.run replayer ~archive_uri:target_db
      ~input_config:
        (network_data.folder ^ "/" ^ network_data.replayer_input_file)
      ~interval_checkpoint:10 ~output_ledger:"./output_ledger" ()
  in

  Deferred.unit

let () =
  Command.(
    run
      (let open Let_syntax in
      async ~summary:"Test patching of blocks in an archive database"
        (let%map db_uri =
           Param.flag "--source-uri"
             ~doc:
               "URI URI for connecting to the database (e.g., \
                postgres://$USER@localhost:5432)"
             Param.(required string)
         and network_data_folder =
           Param.(
             flag "--network-data-folder" ~aliases:[ "network-data-folder" ]
               Param.(required string))
             ~doc:
               "Path Path to folder containing network data. Usually it's sql \
                for db import, genesis ledger and zipped precomputed blocks \
                archive"
         in
         main ~db_uri ~network_data_folder )))
