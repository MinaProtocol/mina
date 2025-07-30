open Async
open Core
module Cache = Disk_cache.Make (Mina_base.Proof.Stable.Latest)

type cache_db = Lmdb_cache of Cache.t | Identity_cache

type t =
  | Lmdb of { cache_id : Cache.id; cache_db : Cache.t }
  | Identity of Mina_base.Proof.t

let read_proof_from_disk = function
  | Lmdb t ->
      Cache.get t.cache_db t.cache_id
  | Identity proof ->
      proof

let write_proof_to_disk db proof =
  match db with
  | Lmdb_cache cache_db ->
      Lmdb { cache_id = Cache.put cache_db proof; cache_db }
  | Identity_cache ->
      Identity proof

let create_db path ~logger =
  Cache.initialize ~logger path
  |> Deferred.Result.map ~f:(fun cache -> Lmdb_cache cache)

let create_identity_db () = Identity_cache

module For_tests = struct
  let create_db = create_identity_db

  let blockchain_dummy =
    Lazy.map
      ~f:(fun dummy -> write_proof_to_disk (create_db ()) dummy)
      Mina_base.Proof.blockchain_dummy

  let transaction_dummy =
    Lazy.map
      ~f:(fun dummy -> write_proof_to_disk (create_db ()) dummy)
      Mina_base.Proof.transaction_dummy
end
