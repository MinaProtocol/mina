open Core
open Async

type t

type cache_db

val create_db :
     string
  -> logger:Logger.t
  -> (cache_db, [> `Initialization_error of Error.t ]) Deferred.Result.t

val read_proof_from_disk : t -> Mina_base.Proof.t

val write_proof_to_disk : cache_db -> Mina_base.Proof.t -> t

val create_identity_db : unit -> cache_db

module For_tests : sig
  val blockchain_dummy : t lazy_t

  val transaction_dummy : t lazy_t

  val create_db : unit -> cache_db
end
