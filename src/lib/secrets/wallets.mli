open Async
open Signature_lib

type t

val load : logger:Logger.t -> disk_location:string -> t Deferred.t

val import_keypair : t -> Keypair.t -> Public_key.Compressed.t Deferred.t

val generate_new : t -> Public_key.Compressed.t Deferred.t

val pks : t -> Public_key.Compressed.t list

val find : t -> needle:Public_key.Compressed.t -> Keypair.t option

val get_path : t -> Public_key.Compressed.t -> string

val delete :
  t -> Public_key.Compressed.t -> (unit, [`Not_found]) Deferred.Result.t
