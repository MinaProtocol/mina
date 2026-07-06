open Core
open Lmdb_storage.Generic

module Make () : Common.Database = struct
  module F (Db : Db) = struct
    type holder = (int, string) Db.t

    let mk_maps { Db.create } =
      create Lmdb_storage.Conv.uint32_be Lmdb.Conv.string

    (* Start with 256 MB, LMDB will grow automatically as needed *)
    let config = { default_config with initial_mmap_size = 256 lsl 20 }
  end

  module Rw = Read_write (F)

  type t = { env : Rw.t; db : Rw.holder }

  let name = "lmdb"

  let create directory =
    Unix.mkdir_p directory ;
    let env, db = Rw.create directory in
    { env; db }

  let close t = Rw.close t.env

  let set_block t ~block_num values =
    let start_key = block_num * Common.keys_per_block in
    List.iteri values ~f:(fun i value ->
        let key = start_key + i in
        Rw.set ~env:t.env t.db key value )

  let get t ~key = Rw.get ~env:t.env t.db key

  let remove_block t ~block_num =
    let start_key = block_num * Common.keys_per_block in
    for i = 0 to Common.keys_per_block - 1 do
      let key = start_key + i in
      Rw.remove ~env:t.env t.db key
    done
end
