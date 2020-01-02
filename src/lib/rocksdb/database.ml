(* rocksdb.ml -- expose RocksDB operations for Coda *)

open Core

(* Uuid.t deprecates sexp functions; use Uuid.Stable.V1 *)

module T = struct
  type t = {uuid: Uuid.Stable.V1.t; db: Rocks.t sexp_opaque} [@@deriving sexp]
end

include T

let create directory =
  let opts = Rocks.Options.create () in
  Rocks.Options.set_create_if_missing opts true ;
  {uuid= Uuid_unix.create (); db= Rocks.open_db ~opts directory}

let create_checkpoint t dir =
  Rocks.checkpoint_create t.db ~dir ?log_size_for_flush:None

let get_uuid t = t.uuid

let close t = Rocks.close t.db

let get t ~(key : Bigstring.t) : Bigstring.t option =
  Rocks.get ?pos:None ?len:None ?opts:None t.db key

let set t ~(key : Bigstring.t) ~(data : Bigstring.t) : unit =
  Rocks.put ?key_pos:None ?key_len:None ?value_pos:None ?value_len:None
    ?opts:None t.db key data

let set_batch t ?(remove_keys = [])
    ~(key_data_pairs : (Bigstring.t * Bigstring.t) list) : unit =
  let batch = Rocks.WriteBatch.create () in
  (* write to batch *)
  List.iter key_data_pairs ~f:(fun (key, data) ->
      Rocks.WriteBatch.put batch key data ) ;
  (* Delete any key pairs *)
  List.iter remove_keys ~f:(fun key -> Rocks.WriteBatch.delete batch key) ;
  (* commit batch *)
  Rocks.write t.db batch

module Batch = struct
  type t = Rocks.WriteBatch.t

  let remove t ~key = Rocks.WriteBatch.delete t key

  let set t ~key ~data = Rocks.WriteBatch.put t key data

  let with_batch t ~f =
    let batch = Rocks.WriteBatch.create () in
    let result = f batch in
    Rocks.write t.db batch ; result
end

let copy _t = failwith "copy: not implemented"

let remove t ~(key : Bigstring.t) : unit =
  Rocks.delete ?pos:None ?len:None ?opts:None t.db key

let to_alist t : (Bigstring.t * Bigstring.t) list =
  let iterator = Rocks.Iterator.create t.db in
  Rocks.Iterator.seek_to_last iterator ;
  (* iterate backwards and cons, to build list sorted by key *)
  let copy t =
    let tlen = Bigstring.length t in
    let new_t = Bigstring.create tlen in
    Bigstring.blit ~src:t ~dst:new_t ~src_pos:0 ~dst_pos:0 ~len:tlen ;
    new_t
  in
  let rec loop accum =
    if Rocks.Iterator.is_valid iterator then (
      let key = copy (Rocks.Iterator.get_key iterator) in
      let value = copy (Rocks.Iterator.get_value iterator) in
      Rocks.Iterator.prev iterator ;
      loop ((key, value) :: accum) )
    else accum
  in
  loop []

let%test_unit "to_alist (of_alist l) = l" =
  Quickcheck.test
    Quickcheck.Generator.(
      tuple2 String.quickcheck_generator String.quickcheck_generator |> list)
    ~f:(fun kvs ->
      File_system.with_temp_dir "/tmp/coda-test" ~f:(fun directory ->
          let s = Bigstring.of_string in
          let sorted =
            List.sort kvs ~compare:[%compare: string * string]
            |> List.map ~f:(fun (k, v) -> (s k, s v))
          in
          let db = create directory in
          List.iter sorted ~f:(fun (key, data) -> set db ~key ~data) ;
          let alist =
            List.sort (to_alist db)
              ~compare:[%compare: Bigstring.t * Bigstring.t]
          in
          [%test_result: (Bigstring.t * Bigstring.t) list] ~expect:sorted alist ;
          Async.Deferred.unit )
      |> Async.don't_wait_for )

let%test_unit "sanity check" =
  Quickcheck.test
    Quickcheck.Generator.(
      tuple2 String.quickcheck_generator String.quickcheck_generator |> list)
    ~f:(fun kvs ->
      let db_dir = Filename.temp_dir "db_dir" "" in
      let s = Bigstring.of_string in
      let sorted =
        List.sort kvs ~compare:[%compare: string * string]
        |> List.map ~f:(fun (k, v) -> (s k, s v))
      in
      let db = create db_dir in
      List.iter sorted ~f:(fun (key, data) -> set db ~key ~data) ;
      let alist =
        List.sort (to_alist db) ~compare:[%compare: Bigstring.t * Bigstring.t]
      in
      [%test_result: (Bigstring.t * Bigstring.t) list] ~expect:sorted alist ;
      close db )

(*
let%test_unit "checkpoint read test" =
  Quickcheck.test
    Quickcheck.Generator.(
      tuple2 String.quickcheck_generator String.quickcheck_generator |> list)
    ~f:(fun kvs ->
      let db_dir =
        Filename.temp_dir_name
        ^/ String.init 16 ~f:(fun _ -> (Int.to_string (Random.int 10)).[0])
      in
      let cp_dir =
        Filename.temp_dir_name
        ^/ String.init 16 ~f:(fun _ -> (Int.to_string (Random.int 10)).[0])
      in
      let s = Bigstring.of_string in
      let sorted =
        List.sort kvs ~compare:[%compare: string * string]
        |> List.map ~f:(fun (k, v) -> (s k, s v))
      in
      let db = create db_dir in
      List.iter sorted ~f:(fun (key, data) -> set db ~key ~data) ;
      create_checkpoint db cp_dir ;
      let cp = create cp_dir in
      let alist =
        List.sort (to_alist db) ~compare:[%compare: Bigstring.t * Bigstring.t]
      in
      [%test_result: (Bigstring.t * Bigstring.t) list] ~expect:sorted alist ;
      close db ;
      close cp )
*)
