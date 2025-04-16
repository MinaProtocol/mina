open Core_kernel
open Async_kernel

type t [@@deriving sexp_of, to_yojson]

type cache_db

val create_db :
     string
  -> logger:Logger.t
  -> (cache_db, [> `Initialization_error of Error.t ]) Deferred.Result.t

val read_proof_from_disk : t -> Pickles.Proof.Proofs_verified_2.Stable.Latest.t

val write_proof_to_disk :
  cache_db -> Pickles.Proof.Proofs_verified_2.Stable.Latest.t -> t

val create_identity_db : unit -> cache_db

module For_tests : sig
  val create_db : unit -> cache_db
end
