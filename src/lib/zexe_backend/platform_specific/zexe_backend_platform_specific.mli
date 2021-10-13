module type S = sig
  module Store : Key_cache.S with module M := Core_kernel.Or_error

  val store :
       read:(string -> 'a option)
    -> write:('a -> string -> unit)
    -> (string, 'a) Store.Disk_storable.t

  val run_in_thread : (unit -> 'a) -> 'a Async_kernel.Deferred.t
end

val get : unit -> (module S)

val set : (module S) -> unit
