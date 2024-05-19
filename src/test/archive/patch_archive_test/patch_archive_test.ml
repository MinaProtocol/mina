(* patch_archive_test.ml *)

(* test patching of archive databases

   test structure:
    - import reference database for comparision (for example with 100 blocks)
    - create new schema and export blocks from reference db with some missing ones
    - patch the database with missing precomputed blocks
    - compare original and copy
*)

module Network_Data = struct
  
  type t = { init_script: String.t 
    ; precomputed_blocks_zip: String.t
    ; genesis_ledger_file: String.t
    ; folder: String.t
  }

  let create folder = 
    {
      init_script = "archive_db.sql"
      ; genesis_ledger_file = "input.json"
      ; precomputed_blocks_zip = "precomputeb_blocks.zip"
      ; folder 
    }

end 

open Core_kernel
open Async

let main ~db_uri ~network_data_folder () =
  let open Deferred.Let_syntax in
  let logger = Logger.create () in
  let db_uri = Uri.of_string db_uri in
  
  let network_data = Network_Data.create network_data_folder in 

  let%bind () = Integration_test_lib.Util.run_cmd_exn 
    (Printf.sprintf "unzip %s/%s -d %s" network_data_folder network_data.precomputed_blocks_zip network_data_folder )
  in
  
  let precomputed_blocks = Precomputed_block.list_directory ~network:"mainnet" ~path:network_data_folder in

  

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
               "Path Path to folder containing network data. Usually it's sql for db import, \
               genesis ledger and zipped precomputed blocks archive"
         in
         main ~db_uri ~network_data_folder
        )
      )
    )
