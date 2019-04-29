open Coda_base
open Signature_lib

type t

val create : ?directory_name:string -> unit -> t

val close : t -> unit

val add : t -> Public_key.Compressed.t -> Transaction.t -> unit

val get_transactions : t -> Public_key.Compressed.t -> Transaction.t list
