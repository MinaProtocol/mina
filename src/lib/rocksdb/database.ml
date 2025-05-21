(* rocksdb.ml -- expose RocksDB operations for Mina *)

type t = { uuid : Uuid.Stable.V1.t; db : (Rocks.t[@sexp.opaque]) }
[@@deriving sexp]

let create directory =
  let opts = Rocks.Options.create () in
  Rocks.Options.set_create_if_missing opts true ;
  Rocks.Options.set_prefix_extractor opts
    (Rocks.Options.SliceTransform.Noop.create_no_gc ()) ;
  { uuid = Uuid_unix.create (); db = Rocks.open_db ~opts directory }

let create_checkpoint t dir =
  Rocks.checkpoint_create t.db ~dir ?log_size_for_flush:None () ;
  create dir

let make_checkpoint t dir =
  Rocks.checkpoint_create t.db ~dir ?log_size_for_flush:None ()

let get_uuid t = t.uuid

let close t = Rocks.close t.db

let get t ~(key : Bigstring.t) : Bigstring.t option =
  Rocks.get ?pos:None ?len:None ?opts:None t.db key

let get_batch t ~(keys : Bigstring.t list) : Bigstring.t option list =
  Rocks.multi_get t.db keys

let set t ~(key : Bigstring.t) ~(data : Bigstring.t) : unit =
  Rocks.put ?key_pos:None ?key_len:None ?value_pos:None ?value_len:None
    ?opts:None t.db key data

let[@warning "-16"] set_batch t ?(remove_keys : Bigstring.t list = [])
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

let remove t ~(key : Bigstring.t) : unit =
  Rocks.delete ?pos:None ?len:None ?opts:None t.db key

let copy_bigstring t : Bigstring.t =
  let tlen = Bigstring.length t in
  let new_t = Bigstring.create tlen in
  Bigstring.blit ~src:t ~dst:new_t ~src_pos:0 ~dst_pos:0 ~len:tlen ;
  new_t

let to_alist t : (Bigstring.t * Bigstring.t) list =
  let iterator = Rocks.Iterator.create t.db in
  Rocks.Iterator.seek_to_last iterator ;
  (* iterate backwards and cons, to build list sorted by key *)
  let rec loop accum =
    if Rocks.Iterator.is_valid iterator then (
      let key = copy_bigstring (Rocks.Iterator.get_key iterator) in
      let value = copy_bigstring (Rocks.Iterator.get_value iterator) in
      Rocks.Iterator.prev iterator ;
      loop ((key, value) :: accum) )
    else accum
  in
  loop []

let foldi :
       t
    -> init:'a
    -> f:(int -> 'a -> key:Bigstring.t -> data:Bigstring.t -> 'a)
    -> 'a =
 fun t ~init ~f ->
  let iterator = Rocks.Iterator.create t.db in
  Rocks.Iterator.seek_to_first iterator ;
  let rec loop i accum =
    if Rocks.Iterator.is_valid iterator then (
      let key = copy_bigstring (Rocks.Iterator.get_key iterator) in
      let data = copy_bigstring (Rocks.Iterator.get_value iterator) in
      Rocks.Iterator.next iterator ;
      loop (i + 1) (f i accum ~key ~data) )
    else accum
  in
  loop 0 init

let fold_until :
       t
    -> init:'a
    -> f:
         (   'a
          -> key:Bigstring.t
          -> data:Bigstring.t
          -> ('a, 'b) Continue_or_stop.t )
    -> finish:('a -> 'b)
    -> 'b =
 fun t ~init ~f ~finish ->
  let iterator = Rocks.Iterator.create t.db in
  Rocks.Iterator.seek_to_first iterator ;
  let rec loop accum =
    if Rocks.Iterator.is_valid iterator then (
      let key = copy_bigstring (Rocks.Iterator.get_key iterator) in
      let data = copy_bigstring (Rocks.Iterator.get_value iterator) in
      Rocks.Iterator.next iterator ;
      match f accum ~key ~data with Stop _ -> accum | Continue v -> loop v )
    else accum
  in
  finish @@ loop init
