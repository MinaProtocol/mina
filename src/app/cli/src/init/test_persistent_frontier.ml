open Persistent_frontier
open Core

let deserialize_root_hash ~logger ~db =
  [%log info] "Querying root hash from database and attempt to deserialize it" ;
  match Database.get_root_hash db with
  | Ok hash ->
      [%log info] "Got hash %s" (Pasta_bindings.Fp.to_string hash)
  | Error _ ->
      [%log error] "No root hash found"

let root_hash_deserialization_limit = Time_ns.Span.of_ms 2000.0

let main ~frontier_db_path ~no_root_compatible () =
  let logger = Logger.create () in
  [%log info] "Current DB path: %s" frontier_db_path ;
  [%log info] "Loading database" ;
  let db = Database.create ~logger ~directory:frontier_db_path in
  if not no_root_compatible then
    (*
      To maintain compatibility, run a deserialization round first,
      to ensure we have `root_hash` and `root_common` inside the DB
      *)
    deserialize_root_hash ~logger ~db ;
  let start_time = Time_ns.now () in
  let () = deserialize_root_hash ~logger ~db in
  let end_time = Time_ns.now () in
  let duration = Time_ns.diff end_time start_time in
  [%log info]
    "Querying root hash on patched persistence frontier database takes %s"
    (Time_ns.Span.to_string duration) ;
  Database.close db ;
  assert (Time_ns.Span.compare duration root_hash_deserialization_limit < 0)

let command =
  let open Command.Let_syntax in
  Command.basic ~summary:"tests for persistent frontier"
    (let%map_open frontier_db_path =
       flag "--frontier-db" ~aliases:[ "-f" ]
         ~doc:"Path to frontier DB this app is testing on" (required string)
     and no_root_compatible =
       flag "--no-root-compatible" ~aliases:[ "-r" ]
         ~doc:
           "Do not perform hash query once to ensure the compatibility with \
            old frontier database"
         no_arg
     in
     main ~frontier_db_path ~no_root_compatible )
