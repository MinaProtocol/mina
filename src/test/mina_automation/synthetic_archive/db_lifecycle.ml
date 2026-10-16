(* Creating, recreating and refusing databases, and writing a scenario once. *)

open Core
open Async
module B = Synthetic_archive
module Psql = Mina_automation.Psql

let admin server_uri =
  Psql.Conn_str (Uri.to_string (Uri.with_path server_uri "/postgres"))

let exists ~connection name =
  Psql.run_command ~connection
    (sprintf "SELECT 1 FROM pg_database WHERE datname = '%s'" name)
  >>| Or_error.map ~f:(String.equal "1")

(* a database left by an earlier run must not break the next one *)
let test_recreate server_uri () =
  let open Deferred.Or_error.Let_syntax in
  let name = "test_synthetic_archive_recreate" in
  let%bind (_ : B.Db.t) = B.Db.create ~server_uri ~name () in
  let%bind db = B.Db.create ~upgrade:true ~server_uri ~name () in
  let%bind.Deferred latest =
    B.Db.with_connection db (fun conn ->
        Read_back.ok ~ctx:"migration history"
          (Archive_hardfork_toolbox_lib.Sql.fetch_latest_migration_history conn) )
  in
  Alcotest.(check bool)
    "upgrade.sql recorded its run" true (Option.is_some latest) ;
  B.Db.drop db

(* Db.create drops a same-named database first, so it must refuse any name
   that is not obviously a test's: here a real-looking database survives. *)
let test_refuses_non_test_name server_uri () =
  let open Deferred.Or_error.Let_syntax in
  let precious = "synthetic_archive_precious" in
  let connection = admin server_uri in
  let%bind (_ : string) = Psql.drop_db_if_exists ~connection ~db:precious in
  let%bind (_ : string) = Psql.create_empty_db ~connection ~db:precious in
  let%bind.Deferred result = B.Db.create ~server_uri ~name:precious () in
  Alcotest.(check bool)
    "create refuses a name without the test_ prefix" true
    (Result.is_error result) ;
  let%bind still_there = exists ~connection precious in
  Alcotest.(check bool)
    "the database of that name is untouched" true still_there ;
  Psql.drop_db_if_exists ~connection ~db:precious >>| ignore

let one_block_scenario name =
  let s = B.create () in
  let (_ : B.block) = B.block s ~name ~height:1 Canonical in
  s

let test_materialize_once server_uri () =
  B.Db.with_fresh ~server_uri ~name:"test_synthetic_archive_once" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let s = one_block_scenario "first" in
      let%bind (_ : B.built) = B.materialize s db in
      let%bind.Deferred again = B.materialize s db in
      Alcotest.(check bool)
        "the same scenario twice is refused" true (Result.is_error again) ;
      let%map.Deferred other = B.materialize (one_block_scenario "second") db in
      Alcotest.(check bool)
        "a scenario into an archive with blocks is refused" true
        (Result.is_error other) ;
      Ok () )

(* a callback that raises -- a failed Alcotest check, a loader's ok_exn --
   must not leave its database behind *)
let test_with_fresh_drops_on_raise server_uri () =
  let open Deferred.Let_syntax in
  let name = "test_synthetic_archive_raising" in
  let%bind result =
    B.Db.with_fresh ~server_uri ~name (fun (_ : B.Db.t) ->
        failwith "callback failed" )
  in
  Alcotest.(check bool)
    "the callback's exception comes back as an error" true
    (Result.is_error result) ;
  exists ~connection:(admin server_uri) name
  >>| Or_error.map ~f:(fun still_there ->
          Alcotest.(check bool) "the database was dropped" false still_there )

(* names are identifiers: create and drop act on exactly the name given, not
   on its lower-cased form *)
let test_mixed_case_name server_uri () =
  let open Deferred.Or_error.Let_syntax in
  let connection = admin server_uri in
  let lower = "test_synthetic_archive_mixed" in
  let mixed = "test_Synthetic_Archive_Mixed" in
  let%bind (_ : string) = Psql.drop_db_if_exists ~connection ~db:lower in
  let%bind (_ : string) = Psql.create_empty_db ~connection ~db:lower in
  let%bind db = B.Db.create ~server_uri ~name:mixed () in
  let%bind mixed_there = exists ~connection mixed in
  Alcotest.(check bool) "the mixed-case database exists" true mixed_there ;
  let%bind () = B.Db.drop db in
  let%bind mixed_gone = exists ~connection mixed >>| not in
  let%bind lower_there = exists ~connection lower in
  Alcotest.(check bool) "drop removed the mixed-case database" true mixed_gone ;
  Alcotest.(check bool) "the lower-case database is untouched" true lower_there ;
  Psql.drop_db_if_exists ~connection ~db:lower >>| ignore

(* a connection URI reaches psql whole: no password is required (trust,
   .pgpass) and query parameters such as sslmode survive, also when another
   database is named *)
let test_conn_str_args () =
  let connection =
    Psql.Conn_str "postgres://user@db.example:5433/archive?sslmode=disable"
  in
  Alcotest.(check (list string))
    "the URI as given"
    [ "-d"; "postgres://user@db.example:5433/archive?sslmode=disable" ]
    (Psql.create_credential_arg ~connection ()) ;
  Alcotest.(check (list string))
    "another database on the same server"
    [ "-d"; "postgres://user@db.example:5433/other?sslmode=disable" ]
    (Psql.create_credential_arg ~connection ~db:"other" ())
