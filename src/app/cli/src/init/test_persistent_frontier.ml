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

let root_hash_deserialization_limit_ms = 2000.0

let main ~frontier_db_path ~no_upgrade_root_clean ~num_of_samples () =
  let logger = Logger.create () in
  [%log info] "Current DB path: %s" frontier_db_path ;
  [%log info] "Loading database" ;
  let db = Database.create ~logger ~directory:frontier_db_path in
  if not no_upgrade_root_clean then (
    (*
      To maintain compatibility, run a deserialization round first,
      to ensure we have `root_hash` and `root_common` inside the DB
      *)
    [%log info] "Updating the database to a clean state" ;
    Database.update_root_clean db
    |> Result.ok
    |> Option.value_exn ~message:"Can't update root to a clean state" ) ;
  assert (Database.is_root_replaced_by_common_and_hash db) ;
  let tests =
    [ Bench.Test.create ~name:"Test Persistent Frontier Root Hash query"
        (fun () -> deserialize_root_hash ~logger ~db)
    ]
  in
  let run_config =
    Bench.Run_config.create ?quota:(Some (Bench.Quota.Num_calls num_of_samples))
      ()
  in
  Bench.bench ~run_config tests ;
  Database.close db

let command =
  let open Command.Let_syntax in
  Command.basic ~summary:"tests for persistent frontier"
    (let%map_open frontier_db_path =
       flag "--frontier-db" ~aliases:[ "-f" ]
         ~doc:"Path to frontier DB this app is testing on" (required string)
     and num_of_samples =
       flag "--samples" ~aliases:[ "-s" ]
         ~doc:"Number of rounds of hash query should we run. (default 5)"
         (optional_with_default 5 int)
     and no_upgrade_root_clean =
       flag "--no-upgrade"
         ~doc:"Do not perform `upgrade_root_clean` on the database" no_arg
     in
     main ~frontier_db_path ~no_upgrade_root_clean ~num_of_samples )
