open Core

(* returns true if all the dbs are equal as K-V pairs *)
let check_db_equalities db_dirs =
  let dbs = List.map db_dirs ~f:Rocksdb.Database.create in
  let alists = List.map ~f:Rocksdb.Database.to_alist dbs in
  match alists with
  | representative :: rest ->
      List.for_all
        ~f:([%equal: (Bigstring.t * Bigstring.t) list] representative)
        rest
  | [] ->
      failwith "impossible"

let test_db_equality ~modify_fn =
  Async.Thread_safe.block_on_async (fun () ->
      File_system.with_temp_dir "/tmp/kvdb-empty-test" ~f:(fun tempdir ->
          let db1 = Rocksdb.Database.create (tempdir ^/ "a") in
          let db2 = Rocksdb.Database.create (tempdir ^/ "b") in
          modify_fn db1 db2 ;
          Rocksdb.Database.close db1 ;
          Rocksdb.Database.close db2 ;
          Async.Deferred.return
            (check_db_equalities [ tempdir ^/ "a"; tempdir ^/ "b" ]) ) )
  |> Result.ok_exn

let%test "empty DBs are equal" = test_db_equality ~modify_fn:(fun _ _ -> ())

let%test "different DBs are unequal " =
  not
  @@ test_db_equality ~modify_fn:(fun db1 _ ->
         Rocksdb.Database.set db1 ~key:(Bigstring.of_string "a")
           ~data:(Bigstring.of_string "1") )

let cmd =
  let open Command in
  let open Command.Let_syntax in
  basic ~summary:"Compare RocksDB databases for equality"
    (let%map rocksdb_dirs =
       Param.flag "--rocksdb-dir"
         ~doc:"Directory storing a database to compare (need at least 2)"
         Param.(listed string)
     in
     fun () ->
       if List.length rocksdb_dirs < 2 then (
         eprintf
           "Error: need at least 2 occurrences of --rocksdb-dir to compare\n" ;
         exit 1 ) ;
       if check_db_equalities rocksdb_dirs then exit 0 else exit 1 )
