open Core
open Rocksdb

module Database_tests = struct
  let bigstring_testable =
    Alcotest.testable
      (fun ppf t -> Fmt.string ppf (Bigstring.to_string t))
      (fun a b -> Bigstring.compare a b = 0)

  let opt_bigstring_testable = Alcotest.(option bigstring_testable)

  let test_get_batch () =
    Alcotest.test_case "get_batch" `Quick (fun () ->
        Async.Thread_safe.block_on_async_exn (fun () ->
            Mina_stdlib_unix.File_system.with_temp_dir "/tmp/mina-rocksdb-test"
              ~f:(fun db_dir ->
                let db = Database.create db_dir in
                let[@warning "-8"] [ key1; key2; key3 ] =
                  List.map ~f:(fun s -> Bigstring.of_string s) [ "a"; "b"; "c" ]
                in
                let data = Bigstring.of_string "test" in
                Database.set db ~key:key1 ~data ;
                Database.set db ~key:key3 ~data ;
                let[@warning "-8"] [ res1; res2; res3 ] =
                  Database.get_batch db ~keys:[ key1; key2; key3 ]
                in
                Alcotest.(check opt_bigstring_testable)
                  "First key is present" (Some data) res1 ;
                Alcotest.(check opt_bigstring_testable)
                  "Second key is not present" None res2 ;
                Alcotest.(check opt_bigstring_testable)
                  "Third key is present" (Some data) res3 ;
                Async.Deferred.unit ) ) )

  let test_to_alist () =
    Alcotest.test_case "to_alist (of_alist l) = l" `Quick (fun () ->
        Async.Thread_safe.block_on_async_exn
        @@ fun () ->
        Async.Quickcheck.async_test ~trials:20
          Quickcheck.Generator.(
            tuple2 String.quickcheck_generator String.quickcheck_generator
            |> list)
          ~f:(fun kvs ->
            match Hashtbl.of_alist (module String) kvs with
            | `Duplicate_key _ ->
                Async.Deferred.unit
            | `Ok _ ->
                Mina_stdlib_unix.File_system.with_temp_dir
                  "/tmp/mina-rocksdb-test" ~f:(fun db_dir ->
                    let sorted =
                      List.sort kvs ~compare:[%compare: string * string]
                      |> List.map ~f:(fun (k, v) ->
                             (Bigstring.of_string k, Bigstring.of_string v) )
                    in
                    let db = Database.create db_dir in
                    List.iter sorted ~f:(fun (key, data) ->
                        Database.set db ~key ~data ) ;
                    let alist =
                      List.sort (Database.to_alist db)
                        ~compare:[%compare: Bigstring.t * Bigstring.t]
                    in
                    Alcotest.(
                      check (list (pair bigstring_testable bigstring_testable)))
                      "to_alist returns the expected list" sorted alist ;
                    Database.close db ;
                    Async.Deferred.unit ) ) )

  let test_checkpoint_read () =
    Alcotest.test_case "checkpoint read" `Quick (fun () ->
        let open Async in
        Thread_safe.block_on_async_exn
        @@ fun () ->
        Quickcheck.async_test ~trials:20
          Quickcheck.Generator.(
            list
            @@ tuple2 String.quickcheck_generator String.quickcheck_generator)
          ~f:(fun kvs ->
            match Hashtbl.of_alist (module String) kvs with
            | `Duplicate_key _ ->
                Deferred.unit
            | `Ok db_hashtbl -> (
                let open Core in
                let cp_hashtbl = Hashtbl.copy db_hashtbl in
                let db_dir = Filename.temp_dir "test_db" "" in
                let cp_dir =
                  Filename.temp_dir_name ^/ "test_cp"
                  ^ String.init 16 ~f:(fun _ ->
                        (Int.to_string (Random.int 10)).[0] )
                in
                let db = Database.create db_dir in
                Hashtbl.iteri db_hashtbl ~f:(fun ~key ~data ->
                    Database.set db ~key:(Bigstring.of_string key)
                      ~data:(Bigstring.of_string data) ) ;
                let cp = Database.create_checkpoint db cp_dir in
                match
                  ( Hashtbl.add db_hashtbl ~key:"db_key" ~data:"db_data"
                  , Hashtbl.add cp_hashtbl ~key:"cp_key" ~data:"cp_data" )
                with
                | `Ok, `Ok ->
                    Database.set db
                      ~key:(Bigstring.of_string "db_key")
                      ~data:(Bigstring.of_string "db_data") ;
                    Database.set cp
                      ~key:(Bigstring.of_string "cp_key")
                      ~data:(Bigstring.of_string "cp_data") ;
                    let db_sorted =
                      List.sort
                        (Hashtbl.to_alist db_hashtbl)
                        ~compare:[%compare: string * string]
                      |> List.map ~f:(fun (k, v) ->
                             (Bigstring.of_string k, Bigstring.of_string v) )
                    in
                    let cp_sorted =
                      List.sort
                        (Hashtbl.to_alist cp_hashtbl)
                        ~compare:[%compare: string * string]
                      |> List.map ~f:(fun (k, v) ->
                             (Bigstring.of_string k, Bigstring.of_string v) )
                    in
                    let db_alist =
                      List.sort (Database.to_alist db)
                        ~compare:[%compare: Bigstring.t * Bigstring.t]
                    in
                    let cp_alist =
                      List.sort (Database.to_alist cp)
                        ~compare:[%compare: Bigstring.t * Bigstring.t]
                    in
                    Alcotest.(
                      check (list (pair bigstring_testable bigstring_testable)))
                      "Database to_alist has expected content" db_sorted
                      db_alist ;
                    Alcotest.(
                      check (list (pair bigstring_testable bigstring_testable)))
                      "Checkpoint to_alist has expected content" cp_sorted
                      cp_alist ;
                    Database.close db ;
                    Database.close cp ;
                    Deferred.unit
                | _ ->
                    Deferred.unit ) ) )

  let all = [ test_get_batch (); test_to_alist (); test_checkpoint_read () ]
end

module Scan_tests = struct
  let length_k = 128

  let length_v = 512

  let rows = 2000

  let random_kvs =
    let open Quickcheck.Generator.Let_syntax in
    let kv_gen =
      let%bind key =
        String.gen_with_length length_k Char.quickcheck_generator
      in
      let%map value =
        String.gen_with_length length_v Char.quickcheck_generator
      in
      (Bigstring.of_string key, Bigstring.of_string value)
    in
    List.gen_with_length rows kv_gen

  let bigstring_testable =
    let pp ppf b = Format.fprintf ppf "%S" (Bigstring.to_string b) in
    Alcotest.testable pp Bigstring.equal

  let with_temp_dir_sync ~f dir =
    let temp_dir = Unix.mkdtemp dir in
    Exn.protect
      ~f:(fun () -> f temp_dir)
      ~finally:(fun () -> Mina_stdlib_unix.File_system.rmrf temp_dir)

  let roundtrip1 ~random () =
    Alcotest.test_case "recovering a dumped kv store gives same data" `Quick
      (fun () ->
        let kvs_to_dump =
          Quickcheck.Generator.generate ~size:10 ~random random_kvs
        in
        with_temp_dir_sync "rocksdb_scan_roundtrip1" ~f:(fun test_dir ->
            let db_to_dump_path =
              let db_path = test_dir ^/ "db_to_dump" in
              let db = Database.create db_path in
              Database.set_batch ?remove_keys:None ~key_data_pairs:kvs_to_dump
                db ;
              Database.close db ;
              db_path
            in
            let dumped_text_file =
              let text_file = test_dir ^/ "text_file.txt" in
              Scan.dump ~db_path:db_to_dump_path ~text_file () ;
              text_file
            in
            let db_recovered_path =
              let db_path = test_dir ^/ "db_recovered" in
              Scan.restore ~db_path ~text_file:dumped_text_file () ;
              db_path
            in
            let kvs_recovered =
              let db = Database.create db_recovered_path in
              let kvs = Database.to_alist db in
              Database.close db ; kvs
            in
            Alcotest.(
              check
                (list (pair bigstring_testable bigstring_testable))
                "dumped & recovered DB stores the same kv pairs" kvs_to_dump
                kvs_recovered) ) )

  let all ~random = [ roundtrip1 ~random () ]
end

let () =
  let random = Splittable_random.State.create Random.State.default in
  Alcotest.run "Rocksdb"
    [ ("database", Database_tests.all); ("scan", Scan_tests.all ~random) ]
