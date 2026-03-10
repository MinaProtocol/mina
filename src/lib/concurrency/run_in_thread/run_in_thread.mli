val run_in_thread : (unit -> 'a) -> 'a Async_kernel.Deferred.t

val block_on_async_exn : (unit -> 'a Async_kernel.Deferred.t) -> 'a
