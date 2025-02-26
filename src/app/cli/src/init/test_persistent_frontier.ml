open Persistent_frontier
open Core

let deserialize_root_hash ~logger ~db =
  [%log info] "Querying root hash from database and attempt to deserialize it" ;
  match Database.get_root_hash db with
  | Ok hash ->
      [%log info] "Got hash %s" (Pasta_bindings.Fp.to_string hash)
  | Error _ ->
      [%log error] "No root hash found"

let root_hash_deserialization_limit_ms = 2000.0

let main ~frontier_db_path ~no_root_compatible ~num_of_samples () =
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
  assert (Database.is_root_replaced_by_common_and_hash db) ;
  let rec sample cnt =
    match cnt with
    | 0 ->
        []
    | _ ->
        let start_time = Time_ns.now () in
        deserialize_root_hash ~logger ~db ;
        let end_time = Time_ns.now () in
        let duration = Time_ns.diff end_time start_time in
        Time_ns.Span.to_ms duration :: sample (cnt - 1)
  in
  assert (num_of_samples >= 1) ;
  let duration_ms_samples = sample num_of_samples in
  let max_duration_ms =
    List.max_elt duration_ms_samples ~compare:Float.compare |> Option.value_exn
  in
  let min_duration_ms =
    List.min_elt duration_ms_samples ~compare:Float.compare |> Option.value_exn
  in
  let avg_duration_ms =
    List.sum (module Float) duration_ms_samples ~f:ident
    /. Float.of_int (List.length duration_ms_samples)
  in

  [%log info] "Querying root hash on patched persistence frontier database"
    ~metadata:
      [ ("min_duration_ms", `Float min_duration_ms)
      ; ("max_duration_ms", `Float max_duration_ms)
      ; ("avg_duration_ms", `Float avg_duration_ms)
      ] ;
  Database.close db ;
  assert (Float.compare max_duration_ms root_hash_deserialization_limit_ms < 0)

let command =
  let open Command.Let_syntax in
  Command.basic ~summary:"tests for persistent frontier"
    (let%map_open frontier_db_path =
       flag "--frontier-db" ~aliases:[ "-f" ]
         ~doc:"Path to frontier DB this app is testing on" (required string)
     and num_of_samples =
       flag "--samples" ~aliases:[ "-s" ]
         ~doc:"Number of rounds of hash query should we run" (required int)
     and no_root_compatible =
       flag "--no-root-compatible" ~aliases:[ "-r" ]
         ~doc:
           "Do not perform hash query once to ensure the compatibility with \
            old frontier database"
         no_arg
     in
     main ~frontier_db_path ~no_root_compatible ~num_of_samples )
