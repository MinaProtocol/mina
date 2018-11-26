(* rocksdb_database.ml -- expose RocksDB operations for Coda *)

open Core

type t = {rocks: Rocks.t; uuid: Uuid.t}

let create ~directory =
  let opts = Rocks.Options.create () in
  Rocks.Options.set_create_if_missing opts true ;
  {rocks= Rocks.open_db ~opts directory; uuid= Uuid.create ()}

let destroy t = Rocks.close t.rocks

let get t ~(key : Bigstring.t_frozen) : Bigstring.t_frozen option =
  Rocks.get ?pos:None ?len:None ?opts:None t.rocks (Obj.magic key)
  (* TODO: Fix *)
  |> Obj.magic

let get_uuid t = t.uuid

let set t ~(key : Bigstring.t_frozen) ~(data : Bigstring.t_frozen) : unit =
  Rocks.put ?key_pos:None ?key_len:None ?value_pos:None ?value_len:None
    ?opts:None t.rocks (Obj.magic key) (Obj.magic data)

let set_batch t
    ~(key_data_pairs : (Bigstring.t_frozen * Bigstring.t_frozen) list) =
  let batch = Rocks.WriteBatch.create () in
  (* write to batch *)
  List.iter key_data_pairs ~f:(fun (key, data) ->
      Rocks.WriteBatch.put batch (Obj.magic key) (Obj.magic data) ) ;
  (* commit batch *)
  Rocks.write t.rocks batch

let delete t ~(key : Bigstring.t_frozen) =
  Rocks.delete ?pos:None ?len:None ?opts:None t.rocks (Obj.magic key)
