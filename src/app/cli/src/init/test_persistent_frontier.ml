open Persistent_frontier
open Core

let deserialize_root_hash ~logger ~frontier_db_path =
  [%log info] "Start `deserializae_root_value_from_db`, Current DB path: %s"
    frontier_db_path ;
  [%log info] "Loading database" ;
  let db = Database.create ~logger ~directory:frontier_db_path in
  [%log info] "Querying root hash from database and attempt to deserialize it" ;
  ( match Database.get_root_hash db with
  | Ok hash ->
      [%log info] "Got hash %s" (Pasta_bindings.Fp.to_string hash)
  | Error _ ->
      [%log info] "No root hash found" ) ;
  [%log info] "Done deserialize_root_hash" ;
  Database.close db

let root_hash_deserialization_limit = Time_ns.Span.of_ms 2000.0

let main ~frontier_db_path ~root_compatible () =
  let logger = Logger.create () in
  ( match root_compatible with
  | Some false ->
      ()
  | _ ->
      (*
         To maintain compatibility, run a deserialization round first,
         to ensure we have `root_hash` and `root_common` inside the DB
      *)
      deserialize_root_hash ~logger ~frontier_db_path ) ;
  let start_time = Time_ns.now () in
  let () = deserialize_root_hash ~logger ~frontier_db_path in
  let end_time = Time_ns.now () in
  let duration = Time_ns.diff end_time start_time in
  assert (Time_ns.Span.compare duration root_hash_deserialization_limit < 0)

let command =
  let open Command.Let_syntax in
  Command.basic ~summary:"tests for persistent frontier"
    (let%map_open frontier_db_path =
       flag "--frontier-db" ~aliases:[ "-f" ]
         ~doc:"Path of frontier DB to perform the test on" (required string)
     and root_compatible =
       flag "--root-compatible" ~aliases:[ "-r" ]
         ~doc:"Whether preserving root compatibility, true by default"
         (optional bool)
     in
     main ~frontier_db_path ~root_compatible )
