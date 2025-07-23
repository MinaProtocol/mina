open Async_kernel
open Core_kernel
module Cache = Disk_cache.Make (Pickles.Proof.Proofs_verified_2.Stable.Latest)

type cache_db = Lmdb_cache of Cache.t | Identity_cache

type t =
  | Lmdb of { cache_id : Cache.id; cache_db : Cache.t }
  | Identity of Pickles.Proof.Proofs_verified_2.Stable.Latest.t

(* Sexp serialization is opaque for proof_cache_tag *)
let sexp_of_t _ = Sexp.of_string "proof_cache_tag"

(* JSON serialization is opaque for proof_cache_tag *)
let to_yojson _ = `String "proof_cache_tag"

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

let create_db ~logger ?disk_meta_location path =
  Cache.initialize ~logger ?disk_meta_location path ()
  |> Deferred.Result.map ~f:(fun cache -> Lmdb_cache cache)

let create_identity_db () = Identity_cache

type id = Cache.id [@@deriving bin_io_unversioned]

let cast_id = function
  | Lmdb { cache_id; _ } ->
      cache_id
  | Identity _ ->
      failwith "Can't cast cache tag to underlying ID!"

let cast_of_id ~id ~cache_db =
  match cache_db with
  | Lmdb_cache cache_db ->
      Lmdb { cache_id = id; cache_db }
  | Identity_cache ->
      failwith "Can't cast ID back to proof with identity cache!"

module For_tests = struct
  let create_db = create_identity_db
end
