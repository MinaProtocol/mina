type 'a t

val run_in_thread : (unit -> 'a) -> 'a t

val block_on_async_exn : (unit -> 'a t) -> 'a

val upon : 'a t -> ('a -> unit) -> unit

val is_determined : 'a t -> bool

val peek : 'a t -> 'a option

val value_exn : 'a t -> 'a

val create : (('a -> unit) -> unit) -> 'a t

val to_deferred : 'a t -> 'a Async_kernel.Deferred.t

include Base.Monad.S with type 'a t := 'a t
