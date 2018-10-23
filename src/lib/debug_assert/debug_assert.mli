open Async_kernel

val debug_assert : (unit -> unit) -> unit

val debug_deferred_assert : (unit -> unit Deferred.t) -> unit Deferred.t
