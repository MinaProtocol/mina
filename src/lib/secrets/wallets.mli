open Async
open Signature_lib

type t

val load : logger:Logger.t -> disk_location:string -> t Deferred.t

val generate_new : t -> Keypair.t Deferred.t

val get : t -> Keypair.t list
