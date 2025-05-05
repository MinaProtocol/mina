open Core
open Rocksdb.Database

let to_bigstring ?pos ?len s = Bigstring.of_string ?pos ?len s

module Tests = struct
  let bigstring_testable =
    Alcotest.testable
      (fun ppf t -> Fmt.string ppf (Bigstring.to_string t))
      (fun a b -> Bigstring.compare a b = 0)

  let opt_bigstring_testable = Alcotest.(option bigstring_testable)

  let test_get_batch () =
    Alcotest.test_case "get_batch" `Quick (fun () ->
        Async.Thread_safe.block_on_async_exn (fun () ->
            File_system.with_temp_dir "/tmp/mina-rocksdb-test" ~f:(fun db_dir ->
                let db = create db_dir in
                let[@warning "-8"] [ key1; key2; key3 ] =
                  List.map ~f:(fun s -> Bigstring.of_string s) [ "a"; "b"; "c" ]
                in
                let data = Bigstring.of_string "test" in
                set db ~key:key1 ~data ;
                set db ~key:key3 ~data ;
                let[@warning "-8"] [ res1; res2; res3 ] =
                  get_batch db ~keys:[ key1; key2; key3 ]
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
                File_system.with_temp_dir "/tmp/mina-rocksdb-test"
                  ~f:(fun db_dir ->
                    let sorted =
                      List.sort kvs ~compare:[%compare: string * string]
                      |> List.map ~f:(fun (k, v) ->
                             (to_bigstring k, to_bigstring v) )
                    in
                    let db = create db_dir in
                    List.iter sorted ~f:(fun (key, data) -> set db ~key ~data) ;
                    let alist =
                      List.sort (to_alist db)
                        ~compare:[%compare: Bigstring.t * Bigstring.t]
                    in
                    Alcotest.(
                      check (list (pair bigstring_testable bigstring_testable)))
                      "to_alist returns the expected list" sorted alist ;
                    close db ;
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
                let db = create db_dir in
                Hashtbl.iteri db_hashtbl ~f:(fun ~key ~data ->
                    set db ~key:(to_bigstring key) ~data:(to_bigstring data) ) ;
                let cp = create_checkpoint db cp_dir in
                match
                  ( Hashtbl.add db_hashtbl ~key:"db_key" ~data:"db_data"
                  , Hashtbl.add cp_hashtbl ~key:"cp_key" ~data:"cp_data" )
                with
                | `Ok, `Ok ->
                    set db ~key:(to_bigstring "db_key")
                      ~data:(to_bigstring "db_data") ;
                    set cp ~key:(to_bigstring "cp_key")
                      ~data:(to_bigstring "cp_data") ;
                    let db_sorted =
                      List.sort
                        (Hashtbl.to_alist db_hashtbl)
                        ~compare:[%compare: string * string]
                      |> List.map ~f:(fun (k, v) ->
                             (to_bigstring k, to_bigstring v) )
                    in
                    let cp_sorted =
                      List.sort
                        (Hashtbl.to_alist cp_hashtbl)
                        ~compare:[%compare: string * string]
                      |> List.map ~f:(fun (k, v) ->
                             (to_bigstring k, to_bigstring v) )
                    in
                    let db_alist =
                      List.sort (to_alist db)
                        ~compare:[%compare: Bigstring.t * Bigstring.t]
                    in
                    let cp_alist =
                      List.sort (to_alist cp)
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
                    close db ;
                    close cp ;
                    Deferred.unit
                | _ ->
                    Deferred.unit ) ) )

  let tests = [ test_get_batch (); test_to_alist (); test_checkpoint_read () ]
end

let () = Alcotest.run "Rocksdb" [ ("database", Tests.tests) ]
