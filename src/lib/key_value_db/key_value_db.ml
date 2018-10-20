(* key_value_db.ml -- key, value store for Coda *)

open Core

type t = LevelDB.db

(* TODO: are there better names than create and destroy? after all, the on-disk database is persistent, so closing it doesn't destroy it;
   why not the conventional database names open and close?
 *)

let create ~db : t =
  (* TODO: do we want to use any of the options here, like the LRU cache? *)
  LevelDB.open_db db

let destroy ~db = LevelDB.close db

let get db ~key = LevelDB.get db key

let set db ~key ~data = LevelDB.put db key data

let set_batch db ~key_data_pairs =
  let batch = LevelDB.Batch.make () in
  (* write to batch *)
  List.iter key_data_pairs ~f:(fun (key, data) ->
      LevelDB.Batch.put batch key data ) ;
  (* commit batch to db *)
  (* TODO: there's a sync flag available here, default is false; use it? *)
  LevelDB.Batch.write db batch

let delete db ~key = LevelDB.delete db key
