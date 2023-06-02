open Core_kernel

type 'a t

include Monad.S with type 'a t := 'a t

val fail : string -> _ t

val fail_unless : error:string -> bool -> unit t

val to_result : 'a t -> 'a Or_error.t
