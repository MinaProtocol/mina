open Async_kernel

val debug_assert : (unit -> unit) -> unit

val debug_assert_deferred : (unit -> unit Deferred.t) -> unit Deferred.t
