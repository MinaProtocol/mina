open Core
open Async

type t

type cache_db

val create_db :
     string
  -> logger:Logger.t
  -> (cache_db, [> `Initialization_error of Error.t ]) Deferred.Result.t

val read_key_from_disk : cache_db -> t -> Verification_key_wire.t

val write_key_to_disk : cache_db -> Verification_key_wire.t -> t