(* rocksdb_database.ml -- expose RocksDB operations for Coda *)

open Core

type t = Rocks.t

let create ~directory =
  let opts = Rocks.Options.create () in
  Rocks.Options.set_create_if_missing opts true ;
  Rocks.open_db ~opts directory

let destroy = Rocks.close

let get = Rocks.get ?pos:None ?len:None ?opts:None

let set =
  Rocks.put ?key_pos:None ?key_len:None ?value_pos:None ?value_len:None
    ?opts:None

let set_batch t ~key_data_pairs =
  let batch = Rocks.WriteBatch.create () in
  (* write to batch *)
  List.iter key_data_pairs ~f:(fun (key, data) ->
      Rocks.WriteBatch.put batch key data ) ;
  (* commit batch *)
  Rocks.write t batch

let delete = Rocks.delete ?pos:None ?len:None ?opts:None
