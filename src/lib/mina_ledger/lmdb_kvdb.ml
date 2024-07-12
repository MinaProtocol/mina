open Core_kernel

module Kvdb = struct
  type t =
    { mutable lmdb :
        ((Bigstring.t, Bigstring.t, [ `Uni ]) Lmdb.Map.t[@sexp.opaque])
    ; path : string
    ; uuid : (Uuid.t[@sexp.opaque])
    }
  [@@deriving sexp]

  let trivial_conv : Bigstring.t Lmdb.Conv.t =
    Lmdb.Conv.make ~serialise:(Fn.const Fn.id) ~deserialise:Fn.id ()

  (* TODO is this good enough? what other data can I use to make it more trustably unique? *)
  let name_to_uuid name =
    Array.init (String.length name) ~f:(fun i ->
        Char.to_int (String.get name i) )
    |> Random.State.make |> Uuid.create_random

  let set_batch t ?(remove_keys = []) ~key_data_pairs =
    Lmdb.Cursor.go Rw t.lmdb
      Lmdb.Cursor.(
        fun cursor ->
          List.iter remove_keys ~f:(fun key ->
              let (_ : Bigstring.t * Bigstring.t) = seek cursor key in
              remove cursor ) ;
          List.iter key_data_pairs ~f:(fun (key, data) -> set cursor key data))

  let create (conf : string) =
    let lmdb =
      (* TODO: make a more educated choice of map_size
          the default is too low, 2^25 is also too low *)
      Lmdb.Map.create Nodup
        (Lmdb.Env.create ~map_size:(Int.shift_left 1 30) Rw conf)
        ~key:trivial_conv ~value:trivial_conv
    in
    let kvdb = { lmdb; path = conf; uuid = name_to_uuid conf } in
    (* load data from any existing rocksdb *)
    set_batch kvdb ?remove_keys:None
      ~key_data_pairs:
        Rocksdb.Database.(
          let rdb = create conf in
          let data = to_alist rdb in
          close rdb ; data) ;
    kvdb

  let close t = Lmdb.Env.close (Lmdb.Map.env t.lmdb)

  let make_checkpoint t name =
    let env = Lmdb.Map.env t.lmdb in
    close t ;
    FileUtil.cp ~recurse:true [ t.path ] name ;
    t.lmdb <-
      Lmdb.Map.open_existing Nodup ~key:trivial_conv ~value:trivial_conv env

  let create_checkpoint t name =
    make_checkpoint t name ;
    let new_db =
      Lmdb.Map.open_existing Nodup ~key:trivial_conv ~value:trivial_conv
        (Lmdb.Env.create Ro name)
    in
    { lmdb = new_db
    ; path = name
    ; uuid =
        name_to_uuid name
        (* Can this be the same, if not what can I use instead of the path? *)
    }

  let get t ~key =
    try Some (Lmdb.Map.get t.lmdb key)
    with (Not_found [@alert "-deprecated"]) -> None

  let set t ~key ~data = Lmdb.Map.set t.lmdb key data

  let get_batch t ~keys =
    Lmdb.Cursor.go Ro t.lmdb
      Lmdb.Cursor.(
        fun cursor ->
          List.map keys ~f:(fun key ->
              try Some (get cursor key)
              with (Not_found [@alert "-deprecated"]) -> None ))

  let remove t ~key =
    try Lmdb.Map.remove t.lmdb key
    with
    | (Not_found
    [@alert "-deprecated"] (* LMDB raises Not_found when the key is absent *)
    )
    ->
      ()

  let to_alist t =
    Lmdb.Cursor.fold_left ~f:(fun xs k v -> List.cons (k, v) xs) [] t.lmdb
  (* TODO this feels like a bad idea performance wise *)

  let foldi t ~init ~f =
    snd
    @@ Lmdb.Cursor.fold_left
         ~f:(fun (i, a) key value -> (i + 1, f i a ~key ~data:value))
         (0, init) t.lmdb

  let fold_until t ~init ~f ~finish =
    Lmdb.Cursor.go Ro t.lmdb
      Lmdb.Cursor.(
        fun cursor ->
          let entry : Bigstring.t * Bigstring.t = first cursor in
          let rec loop acc (key, data) =
            Continue_or_stop.(
              match f acc ~key ~data with
              | Continue acc_new -> (
                  match next cursor with
                  | exception (Not_found [@alert "-deprecated"]) ->
                      finish acc_new
                  | ent ->
                      loop acc_new ent )
              | Stop res ->
                  res)
          in
          loop init entry)

  let get_uuid t = t.uuid
end
