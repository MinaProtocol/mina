(* rocksdb_database.ml -- expose RocksDB operations for Coda *)

open Core

(* Uuid.t deprecates sexp functions; use Uuid.Stable.V1 *)
type t = {uuid: Uuid.Stable.V1.t; db: Rocks.t sexp_opaque} [@@deriving sexp]

let create ~directory =
  let opts = Rocks.Options.create () in
  Rocks.Options.set_create_if_missing opts true ;
  {uuid= Uuid.create (); db= Rocks.open_db ~opts directory}

let get_uuid t = t.uuid

let destroy t = Rocks.close t.db

let get t ~(key : Bigstring.t) : Bigstring.t option =
  Rocks.get ?pos:None ?len:None ?opts:None t.db key

let set t ~(key : Bigstring.t) ~(data : Bigstring.t) : unit =
  Rocks.put ?key_pos:None ?key_len:None ?value_pos:None ?value_len:None
    ?opts:None t.db key data

let set_batch t ~(key_data_pairs : (Bigstring.t * Bigstring.t) list) : unit =
  let batch = Rocks.WriteBatch.create () in
  (* write to batch *)
  List.iter key_data_pairs ~f:(fun (key, data) ->
      Rocks.WriteBatch.put batch key data ) ;
  (* commit batch *)
  Rocks.write t.db batch

let copy _t = failwith "copy: not implemented"

let delete t ~(key : Bigstring.t) : unit =
  Rocks.delete ?pos:None ?len:None ?opts:None t.db key

let to_alist t : (Bigstring.t * Bigstring.t) list =
  let iterator = Rocks.Iterator.create t.db in
  Rocks.Iterator.seek_to_last iterator ;
  (* iterate backwards and cons, to build list sorted by key *)
  let rec loop accum =
    if Rocks.Iterator.is_valid iterator then (
      let key = Rocks.Iterator.get_key iterator in
      let value = Rocks.Iterator.get_value iterator in
      Rocks.Iterator.prev iterator ;
      loop ((key, value) :: accum) )
    else accum
  in
  loop []
