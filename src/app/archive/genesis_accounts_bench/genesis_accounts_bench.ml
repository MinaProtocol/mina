(* genesis_accounts_bench -- how long the archive takes to write a genesis
   ledger into genesis_accounts.

   Loads the ledger of [--config-file] as the archive does at start-up, then,
   for each of [--runs] runs, writes it with [Processor.Genesis_accounts.add]
   into a fresh database created from create_schema.sql, and times only that
   call. genesis_accounts has no foreign keys, so an otherwise empty database
   does not change its cost; the primary key and the lookup index are kept up
   to date as in production.

   Results go to stdout and, with [--influxdb-file], to InfluxDB line protocol
   for buildkite/scripts/bench/send.sh. *)

open Core
open Async
module B = Synthetic_archive
module G = Archive_lib.Processor.Genesis_accounts

let ok_exn ~ctx = function
  | Ok x ->
      x
  | Error e ->
      failwithf "%s: %s" ctx (Error.to_string_hum e) ()

let load_accounts ~logger ~config_file =
  let runtime_config =
    Yojson.Safe.from_file config_file
    |> Runtime_config.of_yojson |> Result.ok_or_failwith
  in
  let (module P) = Genesis_constants.profiled () in
  let%bind precomputed_values =
    Genesis_ledger_helper.init_from_config_file ~logger
      ~proof_level:P.proof_level ~genesis_constants:P.genesis_constants
      ~constraint_constants:P.constraint_constants runtime_config
      ~cli_proof_level:None
    >>| ok_exn ~ctx:"genesis ledger"
  in
  let ledger =
    Precomputed_values.genesis_ledger precomputed_values |> Lazy.force
  in
  Mina_ledger.Ledger.foldi ledger ~init:[] ~f:(fun _ acc account ->
      account :: acc )
  |> List.rev |> return

let time f =
  let start = Time_ns.now () in
  let%map result = f () in
  (result, Time_ns.(diff (now ()) start) |> Time_ns.Span.to_ms)

let write_once ?chunk_size ~server_uri accounts =
  let%bind db =
    B.Db.create ~server_uri ~name:"test_genesis_accounts_bench" ()
    >>| ok_exn ~ctx:"create database"
  in
  let%bind (module Conn : Mina_caqti.CONNECTION) =
    Mina_caqti.connect db.uri
    >>| Result.map_error ~f:(fun e -> Error.of_string (Caqti_error.show e))
    >>| ok_exn ~ctx:"connect"
  in
  let%bind outcome, ms =
    time (fun () ->
        G.add ?chunk_size (module Conn) ~genesis_height:1L accounts )
  in
  let%bind () = Conn.disconnect () in
  let%map () = B.Db.drop db >>| ok_exn ~ctx:"drop database" in
  match outcome with
  | Ok (`Added (rows, _)) ->
      (rows, ms)
  | Ok `No_table ->
      failwith "the database has no genesis_accounts table"
  | Ok `Already_loaded ->
      failwith "the fresh database already had the ledger"
  | Error e ->
      failwith (Caqti_error.show e)

let median xs =
  let xs = List.sort xs ~compare:Float.compare in
  List.nth_exn xs (List.length xs / 2)

(* line-protocol tag values must not contain unescaped spaces/commas/= *)
let sanitize = String.map ~f:(function ' ' | ',' | '=' -> '_' | c -> c)

let main ?chunk_size ~server_uri ~config_file ~runs ~influxdb_file ~measurement
    ~tags () =
  let logger = Logger.null () in
  let%bind accounts, ledger_ms =
    time (fun () -> load_accounts ~logger ~config_file)
  in
  printf "genesis ledger: %d accounts, loaded in %.0f ms\n%!"
    (List.length accounts) ledger_ms ;
  let%bind results =
    Deferred.List.init ~how:`Sequential runs ~f:(fun i ->
        let%map rows, ms = write_once ?chunk_size ~server_uri accounts in
        printf "run %d: %d rows in %.0f ms (%.0f rows/s)\n%!" (i + 1) rows ms
          (Float.of_int rows /. (ms /. 1000.)) ;
        (rows, ms) )
  in
  let rows = fst (List.hd_exn results) in
  let times = List.map results ~f:snd in
  let median_ms = median times in
  let min_ms = List.reduce_exn times ~f:Float.min in
  let max_ms = List.reduce_exn times ~f:Float.max in
  let rows_per_s = Float.of_int rows /. (median_ms /. 1000.) in
  printf
    "genesis_accounts write: %d rows, median %.0f ms (min %.0f, max %.0f), \
     %.0f rows/s\n"
    rows median_ms min_ms max_ms rows_per_s ;
  Option.iter influxdb_file ~f:(fun path ->
      let ts = Time_ns.now () |> Time_ns.to_int_ns_since_epoch in
      let tags =
        List.map tags ~f:(fun (k, v) -> sprintf "%s=%s" k (sanitize v))
        |> String.concat ~sep:","
      in
      Out_channel.write_lines path
        [ sprintf
            "%s,%s \
             rows=%di,median_ms=%.3f,min_ms=%.3f,max_ms=%.3f,rows_per_s=%.1f,ledger_load_ms=%.3f,runs=%di \
             %d"
            measurement tags rows median_ms min_ms max_ms rows_per_s ledger_ms
            runs ts
        ] ;
      printf "wrote 1 point to %s\n" path ) ;
  return ()

let () =
  Command.async
    ~summary:"Time writing a genesis ledger into the archive's genesis_accounts"
    (let%map_open.Command config_file =
       flag "--config-file" (required string)
         ~doc:"PATH runtime config naming the genesis ledger"
     and server_uri =
       flag "--postgres-uri" (required string)
         ~doc:
           "URI PostgreSQL server; each run creates and drops the database \
            test_genesis_accounts_bench on it"
     and runs =
       flag "--runs"
         (optional_with_default 3 int)
         ~doc:"N timed runs (default 3)"
     and chunk_size =
       flag "--chunk-size" (optional int)
         ~doc:"N accounts per statement (default: the archive's)"
     and influxdb_file =
       flag "--influxdb-file" (optional string)
         ~doc:"PATH write InfluxDB line protocol here"
     and measurement =
       flag "--measurement"
         (optional_with_default "archive_genesis_accounts_bench" string)
         ~doc:"NAME InfluxDB measurement"
     and branch = flag "--git-branch" (optional string) ~doc:"B branch tag"
     and commit = flag "--git-commit" (optional string) ~doc:"C commit tag"
     and variant = flag "--variant" (optional string) ~doc:"V variant tag" in
     fun () ->
       let tag k v = (k, Option.value v ~default:"unknown") in
       main ?chunk_size ~server_uri:(Uri.of_string server_uri) ~config_file
         ~runs:(Int.max 1 runs) ~influxdb_file ~measurement
         ~tags:
           [ tag "branch" branch; tag "commit" commit; tag "variant" variant ]
         () )
  |> Command_unix.run
