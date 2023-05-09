(* database.ml -- expose Key-value operations for Mina *)

open Core
module Rust = Keyvaluedb_rust.Rust

type t = Keyvaluedb_rust.ondisk_database

exception DatabaseException of string

let unwrap (result : ('a, 'e) result) =
  match result with Ok value -> value | Error e -> raise (DatabaseException e)

let create dir = Rust.ondisk_database_create dir |> unwrap

let create_checkpoint t dir =
  Rust.ondisk_database_create_checkpoint t dir |> unwrap

let make_checkpoint t dir = Rust.ondisk_database_make_checkpoint t dir |> unwrap

let get_uuid t = Rust.ondisk_database_get_uuid t |> unwrap |> Uuid.of_string

let close t = Rust.ondisk_database_close t |> unwrap

let get t ~(key : Bigstring.t) : Bigstring.t option =
  Rust.ondisk_database_get t key |> unwrap

let get_batch t ~(keys : Bigstring.t list) : Bigstring.t option list =
  Rust.ondisk_database_get_batch t keys |> unwrap

let set t ~(key : Bigstring.t) ~(data : Bigstring.t) : unit =
  Rust.ondisk_database_set t key data |> unwrap

let set_batch t ?(remove_keys = [])
    ~(key_data_pairs : (Bigstring.t * Bigstring.t) list) : unit =
  Rust.ondisk_database_set_batch t remove_keys key_data_pairs |> unwrap

module Batch = struct
  type t = Keyvaluedb_rust.ondisk_batch

  let remove t ~key = Rust.ondisk_database_batch_remove t key

  let set t ~key ~data = Rust.ondisk_database_batch_set t key data

  let with_batch t ~f =
    let batch = Rust.ondisk_database_batch_create () in
    let result = f batch in
    Rust.ondisk_database_batch_run t batch |> unwrap ;
    result
end

let copy _t = failwith "copy: not implemented"

let remove t ~(key : Bigstring.t) : unit =
  Rust.ondisk_database_remove t key |> unwrap

let to_alist t : (Bigstring.t * Bigstring.t) list =
  Rust.ondisk_database_to_alist t |> unwrap

let gc t : unit = Rust.ondisk_database_gc t |> unwrap

let to_bigstring = Bigstring.of_string

let%test_unit "get_batch" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      File_system.with_temp_dir "/tmp/mina-keyvaluedb-test" ~f:(fun db_dir ->
          let db = create db_dir in
          let[@warning "-8"] [ key1; key2; key3 ] =
            List.map ~f:Bigstring.of_string [ "a"; "b"; "c" ]
          in
          let data = Bigstring.of_string "test" in
          set db ~key:key1 ~data ;
          set db ~key:key3 ~data ;
          let[@warning "-8"] [ res1; res2; res3 ] =
            get_batch db ~keys:[ key1; key2; key3 ]
          in
          assert ([%equal: Bigstring.t option] res1 (Some data)) ;
          assert ([%equal: Bigstring.t option] res2 None) ;
          assert ([%equal: Bigstring.t option] res3 (Some data)) ;
          Async.Deferred.unit ) )

let%test_unit "to_alist (of_alist l) = l" =
  Async.Thread_safe.block_on_async_exn
  @@ fun () ->
  Async.Quickcheck.async_test ~trials:20
    Quickcheck.Generator.(
      tuple2 String.quickcheck_generator String.quickcheck_generator |> list)
    ~f:(fun kvs ->
      match Hashtbl.of_alist (module String) kvs with
      | `Duplicate_key _ ->
          Async.Deferred.unit
      | `Ok _ ->
          File_system.with_temp_dir "/tmp/mina-keyvaluedb-test" ~f:(fun db_dir ->
              let sorted =
                List.sort kvs ~compare:[%compare: string * string]
                |> List.map ~f:(fun (k, v) -> (to_bigstring k, to_bigstring v))
              in
              let db = create db_dir in
              List.iter sorted ~f:(fun (key, data) -> set db ~key ~data) ;
              let alist =
                List.sort (to_alist db)
                  ~compare:[%compare: Bigstring.t * Bigstring.t]
              in
              [%test_result: (Bigstring.t * Bigstring.t) list] ~expect:sorted
                alist ;
              close db ;
              Async.Deferred.unit ) )

let%test_unit "checkpoint read" =
  let open Async in
  Thread_safe.block_on_async_exn
  @@ fun () ->
  Quickcheck.async_test ~trials:20
    Quickcheck.Generator.(
      list @@ tuple2 String.quickcheck_generator String.quickcheck_generator)
    ~f:(fun kvs ->
      match Hashtbl.of_alist (module String) kvs with
      | `Duplicate_key _ ->
          Deferred.unit
      | `Ok db_hashtbl -> (
          let cp_hashtbl = Hashtbl.copy db_hashtbl in
          let db_dir = Filename.temp_dir "test_db" "" in
          let cp_dir =
            Filename.temp_dir_name ^/ "test_cp"
            ^ String.init 16 ~f:(fun _ -> (Int.to_string (Random.int 10)).[0])
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
              set db ~key:(to_bigstring "db_key") ~data:(to_bigstring "db_data") ;
              set cp ~key:(to_bigstring "cp_key") ~data:(to_bigstring "cp_data") ;
              let db_sorted =
                List.sort
                  (Hashtbl.to_alist db_hashtbl)
                  ~compare:[%compare: string * string]
                |> List.map ~f:(fun (k, v) -> (to_bigstring k, to_bigstring v))
              in
              let cp_sorted =
                List.sort
                  (Hashtbl.to_alist cp_hashtbl)
                  ~compare:[%compare: string * string]
                |> List.map ~f:(fun (k, v) -> (to_bigstring k, to_bigstring v))
              in
              let db_alist =
                List.sort (to_alist db)
                  ~compare:[%compare: Bigstring.t * Bigstring.t]
              in
              let cp_alist =
                List.sort (to_alist cp)
                  ~compare:[%compare: Bigstring.t * Bigstring.t]
              in
              [%test_result: (Bigstring.t * Bigstring.t) list] ~expect:db_sorted
                db_alist ;
              [%test_result: (Bigstring.t * Bigstring.t) list] ~expect:cp_sorted
                cp_alist ;
              close db ;
              close cp ;
              Deferred.unit
          | _ ->
              Deferred.unit ) )
