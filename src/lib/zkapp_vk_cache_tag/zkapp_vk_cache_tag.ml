module Cache = Disk_cache.Make (Mina_base.Verification_key_wire.Stable.Latest)

type cache_db = Lmdb_cache of Cache.t | Identity_cache

type t =
  | Lmdb of { cache_id : Cache.id; cache_db : Cache.t }
  | Identity of Mina_base.Verification_key_wire.t

let read_key_from_disk = function
  | Lmdb t ->
      Cache.get t.cache_db t.cache_id
  | Identity key ->
      key

let write_key_to_disk db key =
  match db with
  | Lmdb_cache cache_db ->
      Lmdb { cache_id = Cache.put cache_db key; cache_db }
  | Identity_cache ->
      Identity key

let create_db path ~logger =
  Cache.initialize ~logger path
  |> Async.Deferred.Result.map ~f:(fun cache -> Lmdb_cache cache)

module For_tests = struct
  let create_db () = Identity_cache
end
