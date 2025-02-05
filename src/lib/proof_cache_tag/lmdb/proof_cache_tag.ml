open Async
open Core
module Cache = Disk_cache.Make (Pickles.Proof.Proofs_verified_2.Stable.Latest)

type cache_db = Lmdb_cache of Cache.t | Identity_cache

type t =
  | Lmdb of { cache_id : Cache.id; cache_db : cache_db }
  | Identity of Mina_base.Proof.t

let unwrap = function
  | Lmdb t -> (
      match t.cache_db with
      | Identity_cache ->
          failwith
            "internal error for proof cache tag. Identity_cache shouldn't be \
             used in production lmdb implementation"
      | Lmdb_cache cache_db ->
          Cache.get cache_db t.cache_id )
  | Identity proof ->
      proof

let generate db proof =
  match db with
  | Lmdb_cache cache_db ->
      Lmdb
        { cache_id = Cache.put cache_db proof; cache_db = Lmdb_cache cache_db }
  | Identity_cache ->
      Identity proof

let create_db path ~logger =
  Cache.initialize ~logger path
  |> Deferred.Result.map ~f:(fun cache -> Lmdb_cache cache)

module For_tests = struct
  let create_db () = Identity_cache

  let blockchain_dummy =
    Lazy.map
      ~f:(fun dummy -> generate (create_db ()) dummy)
      Mina_base.Proof.blockchain_dummy

  let transaction_dummy =
    Lazy.map
      ~f:(fun dummy -> generate (create_db ()) dummy)
      Mina_base.Proof.transaction_dummy
end
