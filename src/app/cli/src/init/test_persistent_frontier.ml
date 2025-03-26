open Persistent_frontier
open Core
open Core_bench

let deserialize_root_hash ~logger ~db =
  [%log info] "Querying root hash from database and attempt to deserialize it" ;
  match Database.get_root_hash db with
  | Ok hash ->
      [%log info] "Got hash %s" (Pasta_bindings.Fp.to_string hash)
  | Error _ ->
      [%log error] "No root hash found"

let command =
  Bench.make_command
    [ Bench.Test.create_with_initialization
        ~name:"Test Persistent Frontier Root Hash query" (fun `init ->
          let frontier_db_path =
            Sys.getenv_exn "TEST_PERSISTENT_FRONTIER_DB_PATH"
          in
          let logger = Logger.create () in
          [%log info] "Current DB path: %s" frontier_db_path ;
          [%log info] "Loading database" ;
          let db = Database.create ~logger ~directory:frontier_db_path in
          (* To maintain compatibility, call `update_root_clean` first *)
          [%log info] "Updating the database to a clean state" ;
          Database.update_root_clean db
          |> Result.ok
          |> Option.value_exn ~message:"Can't update root to a clean state" ;
          assert (Database.is_root_replaced_by_common_and_hash db) ;
          [%log info] "Initialization done" ;
          fun () -> deserialize_root_hash ~logger ~db )
    ]
