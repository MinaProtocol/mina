open Core
open Async

type t

type cache_db

val create_db :
     string
  -> logger:Logger.t
  -> (cache_db, [> `Initialization_error of Error.t ]) Deferred.Result.t

val unwrap : t -> Mina_base.Proof.t

val generate : cache_db -> Mina_base.Proof.t -> t

module For_tests : sig
  val blockchain_dummy : t lazy_t

  val transaction_dummy : t lazy_t

  val create_db : unit -> cache_db
end
