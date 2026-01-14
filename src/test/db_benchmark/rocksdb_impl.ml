open Core

module Make () : Common.Database = struct
  module Key = struct
    include Int
  end

  module Value = struct
    include String
  end

  module Db = Rocksdb.Serializable.Make (Key) (Value)

  type t = Db.t

  let name = "rocksdb"

  let create directory = Unix.mkdir_p directory ; Db.create directory

  let close db = Db.close db

  let set_block db ~block_num values =
    let start_key = block_num * Common.keys_per_block in
    List.iteri values ~f:(fun i value ->
        let key = start_key + i in
        Db.set db ~key ~data:value )

  let get db ~key = Db.get db ~key

  let remove_block db ~block_num =
    let start_key = block_num * Common.keys_per_block in
    for i = 0 to Common.keys_per_block - 1 do
      let key = start_key + i in
      Db.remove db ~key
    done
end
